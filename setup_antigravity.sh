#!/usr/bin/env bash
# ==============================================================================
# Antigravity 2.0 Headless Manager for Linux / WSL2
# Features:
#   - Automated dependency resolution & package installer
#   - Automatic upstream release fetching & download from Google Cloud Storage
#   - Version inspection & one-command in-place updater
#   - Headless background daemon with auto-authentication & Remote Control
#   - Seamless WSLg GUI window launch with auto-resume to headless
#   - Native systemd user service integration for boot autostart
# ==============================================================================

set -euo pipefail

SCRIPT_SOURCE="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# 1. Load environment configuration from .env if present
if [ -f "${ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
fi

# 2. Configuration parameters with robust fallbacks
INSTALL_DIR="${ANTIGRAVITY_INSTALL_DIR:-/opt/antigravity}"
TAR_FILE="${ANTIGRAVITY_TAR_FILE:-Antigravity.tar.gz}"
BIN_PATH="${INSTALL_DIR}/antigravity"
PID_FILE="/tmp/antigravity_${UID:-$(id -u)}.pid"
RELEASES_API="https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases"

# 3. Resolve persistent data directory (prioritizes .env -> $HOME)
if [ -z "${ANTIGRAVITY_HOME:-}" ]; then
    ANTIGRAVITY_HOME="${HOME:-/home/${USER:-user}}"
fi

LOG_DIR="${ANTIGRAVITY_HOME}/.config/Antigravity/logs"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

run_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

check_home_permission() {
    if [ ! -w "${ANTIGRAVITY_HOME}" ]; then
        warn "Current user lacks write permissions to ${ANTIGRAVITY_HOME}. Fixing ownership..."
        run_sudo chown -R "${USER:-$(id -un)}:${USER:-$(id -gn)}" "${ANTIGRAVITY_HOME}"
    fi
}

validate_account_id() {
    local id="${1:-}"
    if [ -z "${id}" ] || [[ "${id}" == *"/"* ]] || [[ "${id}" == *".."* ]] || [[ "${id}" =~ [[:cntrl:][:space:]\'\"\\] ]]; then
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Fetch Latest Upstream Release Metadata
# ------------------------------------------------------------------------------
fetch_latest_metadata() {
    python3 -c '
import urllib.request, json, sys

api_url = sys.argv[1]
try:
    req = urllib.request.Request(api_url, headers={"User-Agent": "Antigravity2-Headless/1.0"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        if not data or not isinstance(data, list):
            sys.exit(1)
        latest = data[0]
        ver = latest.get("version", "")
        exec_id = latest.get("execution_id", "")
        dl_url = f"https://storage.googleapis.com/antigravity-public/antigravity-hub/{ver}-{exec_id}/unsigned/Antigravity-x64.tar.gz"
        print(f"{ver}|{exec_id}|{dl_url}")
except Exception as e:
    sys.stderr.write(str(e))
    sys.exit(1)
' "${RELEASES_API}"
}

get_installed_version() {
    if [ -f "${BIN_PATH}" ] && [ -f "${INSTALL_DIR}/resources/app.asar" ]; then
        ELECTRON_RUN_AS_NODE=1 "${BIN_PATH}" -e '
try {
    const pkg = require(process.argv[1] + "/resources/app.asar/package.json");
    console.log(pkg.version || "unknown");
} catch (e) {
    console.log("unknown");
}
' "${INSTALL_DIR}" 2>/dev/null || echo "unknown"
    else
        echo "none"
    fi
}

# ------------------------------------------------------------------------------
# 1. Install System Dependencies
# ------------------------------------------------------------------------------
install_deps() {
    info "Verifying and installing system runtime dependencies..."
    run_sudo apt-get update -qq

    local packages=(
        ca-certificates curl wget rsync tar gzip procps python3 sqlite3
        libnss3 libgbm1 libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2
        libxtst6 libxss1 fonts-liberation xdg-utils
    )

    if apt-cache show libasound2t64 >/dev/null 2>&1; then
        packages+=(libasound2t64 libgtk-3-0t64)
    else
        packages+=(libasound2 libgtk-3-0)
    fi

    run_sudo apt-get install -y --no-install-recommends "${packages[@]}"
    success "System dependencies successfully installed!"
}

# ------------------------------------------------------------------------------
# 2. Download Antigravity Archive (if missing)
# ------------------------------------------------------------------------------
download_archive() {
    local target_path="${SCRIPT_DIR}/${TAR_FILE}"
    info "Querying latest official Antigravity release from Google updater API..."
    
    local meta
    if ! meta=$(fetch_latest_metadata); then
        error "Failed to retrieve release metadata from ${RELEASES_API}. Please check your internet connection."
        exit 1
    fi

    local ver exec_id dl_url
    ver=$(echo "${meta}" | cut -d'|' -f1)
    exec_id=$(echo "${meta}" | cut -d'|' -f2)
    dl_url=$(echo "${meta}" | cut -d'|' -f3)

    info "Found latest release: ${BOLD}v${ver}${NC} (Build ID: ${exec_id})"
    info "Downloading package from: ${dl_url}"
    
    curl -fL --progress-bar -o "${target_path}" "${dl_url}"
    success "Successfully downloaded Antigravity v${ver} to ${target_path}!"
}

# ------------------------------------------------------------------------------
# 3. Extract and Setup Antigravity
# ------------------------------------------------------------------------------
install_antigravity() {
    install_deps

    local source_tar="${SCRIPT_DIR}/${TAR_FILE}"
    if [ ! -f "${source_tar}" ]; then
        if [ -f "${TAR_FILE}" ]; then
            source_tar="${TAR_FILE}"
        else
            warn "Installation package '${TAR_FILE}' not found locally."
            download_archive
            source_tar="${SCRIPT_DIR}/${TAR_FILE}"
        fi
    fi

    info "Extracting ${source_tar} into /opt..."
    run_sudo mkdir -p /opt
    run_sudo tar -xzf "${source_tar}" -C /opt/
    
    if [ -d "/opt/Antigravity-x64" ]; then
        run_sudo rm -rf "${INSTALL_DIR}"
        run_sudo mv /opt/Antigravity-x64 "${INSTALL_DIR}"
    fi

    run_sudo chown -R "${USER:-$(id -un)}:${USER:-$(id -gn)}" "${INSTALL_DIR}"
    chmod +x "${BIN_PATH}"

    run_sudo ln -sf "${BIN_PATH}" /usr/local/bin/antigravity
    run_sudo ln -sf "${SCRIPT_DIR}/setup_antigravity.sh" /usr/local/bin/ag-headless
    setup_completion install
    local ver
    ver=$(get_installed_version)
    success "Antigravity v${ver} successfully installed at: ${BIN_PATH}"
}

# ------------------------------------------------------------------------------
# 4. Version Check
# ------------------------------------------------------------------------------
check_version() {
    info "Checking Antigravity version status..."
    local current_ver
    current_ver=$(get_installed_version)

    local meta
    if ! meta=$(fetch_latest_metadata); then
        error "Unable to reach official release server."
        echo -e "Installed version: ${BOLD}${current_ver}${NC}"
        return 1
    fi

    local latest_ver
    latest_ver=$(echo "${meta}" | cut -d'|' -f1)

    echo "==================== VERSION STATUS ===================="
    echo -e "Installed version: ${BOLD}${current_ver}${NC}"
    echo -e "Latest available:  ${BOLD}${latest_ver}${NC}"
    echo "--------------------------------------------------------"

    if [ "${current_ver}" = "none" ]; then
        echo -e "Status: ${YELLOW}Not installed${NC} (Run: '$0 install')"
    elif [ "${current_ver}" = "${latest_ver}" ]; then
        echo -e "Status: ${GREEN}Up to date!${NC}"
    else
        echo -e "Status: ${YELLOW}Update available!${NC} (${current_ver} -> ${latest_ver})"
        echo -e "Run '${BOLD}$0 update${NC}' to automatically upgrade."
    fi
    echo "========================================================"
}

# ------------------------------------------------------------------------------
# 5. In-Place Update
# ------------------------------------------------------------------------------
update_app() {
    info "Starting Antigravity upgrade routine..."
    local was_running=false
    if check_running; then
        info "Active instance detected. Gracefully stopping daemon..."
        stop_app
        was_running=true
        sleep 1
    fi

    download_archive
    install_antigravity

    if [ "${was_running}" = true ]; then
        info "Restarting Antigravity daemon..."
        start_headless
    fi
    success "Update completed successfully!"
}

# ------------------------------------------------------------------------------
# 6. Start Headless Daemon (Primary Daily Command)
# ------------------------------------------------------------------------------
start_headless() {
    check_home_permission

    if [ ! -f "${BIN_PATH}" ]; then
        warn "Antigravity binary not found. Initiating first-time installation..."
        install_antigravity
    fi

    if check_running; then
        warn "Antigravity is already running (PID: $(cat "${PID_FILE}" 2>/dev/null || pgrep -f "${INSTALL_DIR}/antigravity" | head -n1))."
        return 0
    fi

    mkdir -p "${LOG_DIR}"
    if [ -f "${ANTIGRAVITY_HOME}/.gemini/jetski-standalone-oauth-token" ]; then
        ensure_valid_token "${ANTIGRAVITY_HOME}/.gemini/jetski-standalone-oauth-token" "true" >/dev/null 2>&1 || true
    fi
    info "Starting Antigravity in headless background mode..."

    export HOME="${ANTIGRAVITY_HOME}"
    export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-headless}"
    export TZ="${TZ:-Asia/Ho_Chi_Minh}"
    nohup "${BIN_PATH}" --no-sandbox > "${LOG_DIR}/headless_stdout.log" 2>&1 &
    local pid=$!
    echo "${pid}" > "${PID_FILE}"

    sleep 3
    if kill -0 "${pid}" 2>/dev/null; then
        success "Antigravity Headless daemon started successfully (PID: ${pid})!"
        info "Configuration directory: ${ANTIGRAVITY_HOME}"
        info "Language server log:     ${LOG_DIR}/language_server.log"
    else
        error "Startup failed. Inspect logs at: ${LOG_DIR}/headless_stdout.log"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# 7. Open Graphical GUI Window (via WSLg)
# ------------------------------------------------------------------------------
open_gui() {
    check_home_permission

    if [ ! -f "${BIN_PATH}" ]; then
        warn "Antigravity binary not found. Initiating installation..."
        install_antigravity
    fi

    local was_running=false
    if check_running; then
        info "Headless background daemon detected."
        info "Pausing background daemon to claim single instance display lock..."
        stop_app
        was_running=true
        sleep 1
    fi

    # Set runInBackground=false so window close triggers clean exit
    local storage_file="${ANTIGRAVITY_HOME}/.config/Antigravity/app_storage.json"
    if [ -f "${storage_file}" ]; then
        python3 -c '
import json, sys
p = sys.argv[1]
try:
    with open(p, "r", encoding="utf-8") as f:
        d = json.load(f)
    d["runInBackground"] = "false"
    with open(p, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2)
except Exception:
    pass
' "${storage_file}" 2>/dev/null || true
    fi

    info "Launching Antigravity GUI window (via WSLg on Windows desktop)..."
    info "-> Close window or press Ctrl+C in this terminal when finished."
    echo "------------------------------------------------------------"
    
    unset ELECTRON_OZONE_PLATFORM_HINT
    export HOME="${ANTIGRAVITY_HOME}"
    export DISPLAY="${DISPLAY:-:0}"
    if [ -d "/mnt/wslg" ]; then
        export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
        export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/mnt/wslg/runtime-dir}"
        export PULSE_SERVER="${PULSE_SERVER:-/mnt/wslg/PulseServer}"
    fi

    cleanup_gui_and_resume() {
        echo ""
        info "Received exit signal (Ctrl+C). Closing GUI..."
        stop_app
        info "Resuming Antigravity in headless background mode..."
        start_headless
        exit 0
    }
    trap cleanup_gui_and_resume INT TERM

    "${BIN_PATH}" --no-sandbox || true

    trap - INT TERM
    echo ""
    info "GUI window closed."
    stop_app
    info "Resuming Antigravity in headless background mode..."
    start_headless
}

# ------------------------------------------------------------------------------
# 8. Interactive Terminal OAuth Login (Headless Auth)
# ------------------------------------------------------------------------------
auth_terminal() {
    check_home_permission
    info "Opening interactive headless OAuth terminal session..."
    info "-> Visit the printed OAuth authorization URL in your local browser."
    info "-> After approving, paste the authorization code below."
    echo "------------------------------------------------------------"
    export HOME="${ANTIGRAVITY_HOME}"
    export ELECTRON_OZONE_PLATFORM_HINT=headless
    "${BIN_PATH}" --no-sandbox
}

# ------------------------------------------------------------------------------
# 9. Multi-Account Management, Token Auto-Rotation & Profile Switching
# ------------------------------------------------------------------------------
ensure_valid_token() {
    local t_path="${1:-}"
    local sync_active="${2:-false}"
    if [ -z "${t_path}" ] || [ ! -f "${t_path}" ]; then
        return 1
    fi
    python3 -c '
import os, sys, json, re, datetime, urllib.request, urllib.parse

token_path = sys.argv[1]
sync_active = sys.argv[2].lower() == "true"
install_dir = sys.argv[3]
home_dir = sys.argv[4]

def get_credentials():
    cid = os.environ.get("ANTIGRAVITY_CLIENT_ID")
    csec = os.environ.get("ANTIGRAVITY_CLIENT_SECRET")
    if cid and csec:
        return cid, csec
    for base_dir in [install_dir, "/opt/antigravity", "/usr/local/antigravity"]:
        bin_path = os.path.join(base_dir, "resources", "bin", "language_server")
        if os.path.isfile(bin_path):
            try:
                with open(bin_path, "rb") as f:
                    content = f.read()
                if not cid:
                    m_cid = re.search(rb"(1071006060591-[a-z0-9_]+\.apps\.googleusercontent\.com)", content)
                    if m_cid:
                        cid = m_cid.group(1).decode("utf-8")
                if not csec:
                    m_csec = re.search(rb"(GOCSPX-K58FWR[a-zA-Z0-9_-]{22})", content)
                    if m_csec:
                        csec = m_csec.group(1).decode("utf-8")
                if cid and csec:
                    break
            except Exception:
                pass
    return cid, csec

def parse_rfc3339(ts_str):
    if not ts_str:
        return None
    s = ts_str.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    s = re.sub(r"\.(\d{6})\d+([+-]\d{2}:\d{2})$", r".\1\2", s)
    s = re.sub(r"\.(\d+)(?=[+-]\d{2}:\d{2}$)", lambda m: "." + m.group(1).ljust(6, "0")[:6], s)
    dt = datetime.datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    return dt.astimezone(datetime.timezone.utc)

try:
    with open(token_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    token_obj = data.get("token", {})
    refresh_tok = token_obj.get("refresh_token")
    expiry_str = token_obj.get("expiry", "")
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    exp_dt = parse_rfc3339(expiry_str)

    is_expired = True
    if exp_dt and now_utc < (exp_dt - datetime.timedelta(minutes=5)):
        is_expired = False

    status_tag = "VALID"
    if is_expired:
        if not refresh_tok:
            print("EXPIRED|No refresh_token")
            sys.exit(1)
        cid, csec = get_credentials()
        if not cid or not csec:
            print("ERROR|Missing OAuth client credentials")
            sys.exit(1)
        payload = urllib.parse.urlencode({
            "client_id": cid,
            "client_secret": csec,
            "refresh_token": refresh_tok,
            "grant_type": "refresh_token"
        }).encode("utf-8")
        req = urllib.request.Request("https://oauth2.googleapis.com/token", data=payload, method="POST")
        with urllib.request.urlopen(req, timeout=10) as resp:
            refreshed = json.loads(resp.read().decode("utf-8"))
        data["token"]["access_token"] = refreshed["access_token"]
        if refreshed.get("refresh_token"):
            data["token"]["refresh_token"] = refreshed["refresh_token"]
        if refreshed.get("id_token"):
            data["id_token"] = refreshed["id_token"]
        expires_in = int(refreshed.get("expires_in", 3600))
        local_exp = datetime.datetime.now().astimezone() + datetime.timedelta(seconds=expires_in)
        data["token"]["expiry"] = local_exp.isoformat()
        exp_dt = local_exp.astimezone(datetime.timezone.utc)
        with open(token_path, "w", encoding="utf-8") as out:
            json.dump(data, out, indent=2)
        os.chmod(token_path, 0o600)
        if sync_active:
            cur_file = os.path.join(home_dir, ".gemini", "jetski-standalone-oauth-token")
            if os.path.abspath(token_path) != os.path.abspath(cur_file):
                with open(cur_file, "w", encoding="utf-8") as out:
                    json.dump(data, out, indent=2)
                os.chmod(cur_file, 0o600)
        status_tag = "ROTATED"

    rem_min = max(0, int((exp_dt - now_utc).total_seconds() // 60)) if exp_dt else 0
    print(f"{status_tag}|expires in {rem_min}m (Auto-Rotate Active)")
except Exception as e:
    print(f"ERROR|{e}")
    sys.exit(1)
' "${t_path}" "${sync_active}" "${INSTALL_DIR}" "${ANTIGRAVITY_HOME}"
}

get_token_email() {
    local t_path="$1"
    if [ ! -f "${t_path}" ]; then
        echo "unknown"
        return 0
    fi
    python3 -c '
import json, base64, urllib.request, time, sys

t_path = sys.argv[1]
email = "unknown"
for attempt in range(5):
    try:
        with open(t_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        # 1. Decode id_token (top-level or nested under token)
        id_tok = data.get("id_token") or data.get("token", {}).get("id_token")
        if id_tok and "." in id_tok:
            try:
                payload = id_tok.split(".")[1]
                payload += "=" * ((4 - len(payload) % 4) % 4)
                info = json.loads(base64.urlsafe_b64decode(payload.encode("utf-8")).decode("utf-8", errors="ignore"))
                em = info.get("email")
                if em and "@" in em:
                    email = em
                    break
            except Exception:
                pass

        # 2. Fallback: Query Google userinfo API using access_token
        access_tok = data.get("token", {}).get("access_token") or data.get("access_token")
        if access_tok:
            try:
                req = urllib.request.Request("https://www.googleapis.com/oauth2/v3/userinfo", headers={"Authorization": f"Bearer {access_tok}"})
                with urllib.request.urlopen(req, timeout=4) as resp:
                    uinfo = json.loads(resp.read().decode("utf-8"))
                    em = uinfo.get("email")
                    if em and "@" in em:
                        email = em
                        break
            except Exception:
                pass
    except Exception:
        time.sleep(0.5)

print(email)
' "${t_path}" 2>/dev/null || echo "unknown"
}

save_current_account() {
    local token_file="${ANTIGRAVITY_HOME}/.gemini/jetski-standalone-oauth-token"
    if [ -f "${token_file}" ]; then
        chmod 600 "${token_file}" 2>/dev/null || true
        ensure_valid_token "${token_file}" "false" >/dev/null 2>&1 || true
        local email
        email=$(get_token_email "${token_file}")
        if [ -n "${email}" ] && [ "${email}" != "unknown" ] && validate_account_id "${email}"; then
            local acct_dir="${ANTIGRAVITY_HOME}/.gemini/accounts/${email}"
            mkdir -p "${acct_dir}"
            chmod 700 "${ANTIGRAVITY_HOME}/.gemini/accounts" "${acct_dir}" 2>/dev/null || true
            cp "${token_file}" "${acct_dir}/jetski-standalone-oauth-token"
            chmod 600 "${acct_dir}/jetski-standalone-oauth-token"
        fi
    fi
}

list_accounts() {
    if [ "${1:-}" = "--status" ] || [ "${1:-}" = "-s" ] || [ "${1:-}" = "status" ]; then
        shift
        check_account_status "$@"
        return $?
    fi
    save_current_account
    local current_token="${ANTIGRAVITY_HOME}/.gemini/jetski-standalone-oauth-token"
    local current_email="none"
    if [ -f "${current_token}" ]; then
        current_email=$(get_token_email "${current_token}")
    fi

    local acct_base="${ANTIGRAVITY_HOME}/.gemini/accounts"
    mkdir -p "${acct_base}"
    chmod 700 "${acct_base}" 2>/dev/null || true

    echo "==================== GOOGLE ACCOUNTS ===================="
    local count=0
    local found=false
    for d in "${acct_base}"/*; do
        if [ -d "${d}" ] && [ -f "${d}/jetski-standalone-oauth-token" ]; then
            local email
            email=$(basename "${d}")
            count=$((count + 1))
            local tok_state=""
            local tok_badge=""
            if tok_state=$(ensure_valid_token "${d}/jetski-standalone-oauth-token" "false" 2>/dev/null); then
                local st="${tok_state%%|*}"
                local rem="${tok_state#*|}"
                rem="${rem%% (*}"
                tok_badge=" ${CYAN}[Token: ${st}, ${rem}]${NC}"
            else
                tok_badge=" ${RED}[Token: EXPIRED/REVOKED]${NC}"
            fi
            if [ "${email}" = "${current_email}" ]; then
                echo -e "  * [${count}] ${BOLD}${GREEN}${email}${NC} (ACTIVE)${tok_badge}"
            else
                echo -e "    [${count}] ${email}${tok_badge}"
            fi
            found=true
        fi
    done

    if [ "${found}" = false ]; then
        if [ "${current_email}" != "none" ] && [ "${current_email}" != "unknown" ]; then
            echo -e "  * [1] ${BOLD}${GREEN}${current_email}${NC} (ACTIVE)"
        else
            echo "  No saved Google accounts found."
            echo "  Run '$0 login' to authenticate with Google."
        fi
    fi
    echo "========================================================="
    echo -e "${CYAN}Tip:${NC} Run '$0 account-status [email|number]' to inspect health & switch readiness, or '$0 quota' for full bars."
}

check_account_status() {
    save_current_account
    local target="${1:-}"
    export ANTIGRAVITY_HOME="${ANTIGRAVITY_HOME}"
    export INSTALL_DIR="${INSTALL_DIR}"

    python3 -c '
import os, sys, json, re, datetime, urllib.request, urllib.parse

target = sys.argv[1].strip() if len(sys.argv) > 1 else ""
home_dir = os.environ.get("ANTIGRAVITY_HOME") or os.path.expanduser("~")
install_dir = os.environ.get("INSTALL_DIR", "/opt/antigravity")
accounts_dir = os.path.join(home_dir, ".gemini", "accounts")
current_token_file = os.path.join(home_dir, ".gemini", "jetski-standalone-oauth-token")
cloudcode_api = "https://daily-cloudcode-pa.googleapis.com"

C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_GREEN = "\033[0;32m"
C_YELLOW = "\033[1;33m"
C_RED = "\033[0;31m"
C_CYAN = "\033[0;36m"
C_BLUE = "\033[0;34m"
C_MAGENTA = "\033[0;35m"
C_GRAY = "\033[0;90m"

def get_credentials():
    cid = os.environ.get("ANTIGRAVITY_CLIENT_ID")
    csec = os.environ.get("ANTIGRAVITY_CLIENT_SECRET")
    if cid and csec:
        return cid, csec
    for base_dir in [install_dir, "/opt/antigravity", "/usr/local/antigravity"]:
        bin_path = os.path.join(base_dir, "resources", "bin", "language_server")
        if os.path.isfile(bin_path):
            try:
                with open(bin_path, "rb") as f:
                    content = f.read()
                if not cid:
                    m_cid = re.search(rb"(1071006060591-[a-z0-9_]+\.apps\.googleusercontent\.com)", content)
                    if m_cid:
                        cid = m_cid.group(1).decode("utf-8")
                if not csec:
                    m_csec = re.search(rb"(GOCSPX-K58FWR[a-zA-Z0-9_-]{22})", content)
                    if m_csec:
                        csec = m_csec.group(1).decode("utf-8")
                if cid and csec:
                    break
            except Exception:
                pass
    return cid, csec

def parse_rfc3339(ts_str):
    if not ts_str:
        return None
    s = ts_str.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    s = re.sub(r"\.(\d{6})\d+([+-]\d{2}:\d{2})$", r".\1\2", s)
    s = re.sub(r"\.(\d+)(?=[+-]\d{2}:\d{2}$)", lambda m: "." + m.group(1).ljust(6, "0")[:6], s)
    dt = datetime.datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    return dt.astimezone(datetime.timezone.utc)

def format_rel_time(reset_str):
    if not reset_str:
        return "N/A"
    try:
        dt = parse_rfc3339(reset_str)
        if not dt:
            return reset_str
        diff = int((dt - datetime.datetime.now(datetime.timezone.utc)).total_seconds())
        if diff <= 0:
            return "now"
        d, h, m = diff // 86400, (diff % 86400) // 3600, (diff % 3600) // 60
        if d > 0:
            return f"in {d}d {h}h"
        if h > 0:
            return f"in {h}h {m}m"
        return f"in {m}m"
    except Exception:
        return reset_str

def get_current_email():
    if not os.path.isfile(current_token_file):
        return None
    try:
        import base64
        with open(current_token_file, "r", encoding="utf-8") as f:
            d = json.load(f)
        id_tok = d.get("id_token") or d.get("token", {}).get("id_token")
        if id_tok and "." in id_tok:
            p = id_tok.split(".")[1]
            p += "=" * ((4 - len(p) % 4) % 4)
            info = json.loads(base64.urlsafe_b64decode(p).decode("utf-8", errors="ignore"))
            return info.get("email")
    except Exception:
        pass
    return None

cid, csec = get_credentials()
current_active = get_current_email()

all_accounts = []
if os.path.isdir(accounts_dir):
    for idx, d in enumerate(sorted(os.listdir(accounts_dir)), start=1):
        tp = os.path.join(accounts_dir, d, "jetski-standalone-oauth-token")
        if os.path.isfile(tp):
            all_accounts.append((idx, d, tp))

if not all_accounts and os.path.isfile(current_token_file):
    all_accounts.append((1, current_active or "active-account", current_token_file))

if not all_accounts:
    print(f"{C_YELLOW}[WARN] No saved Google accounts found.{C_RESET}")
    sys.exit(0)

selected = all_accounts
if target:
    if target.isdigit() and 1 <= int(target) <= len(all_accounts):
        selected = [all_accounts[int(target) - 1]]
    else:
        exact = [x for x in all_accounts if x[1].lower() == target.lower()]
        selected = exact if exact else [x for x in all_accounts if target.lower() in x[1].lower()]
    if not selected:
        print(f"{C_RED}[ERROR] Account matching \"{target}\" not found.{C_RESET}")
        sys.exit(1)

print(f"{C_BOLD}============================== GOOGLE ACCOUNT HEALTH & STATUS =============================={C_RESET}")
for idx, email, tp in selected:
    is_active = (email == current_active)
    role_tag = f"{C_GREEN}{C_BOLD}ACTIVE{C_RESET}" if is_active else f"{C_GRAY}STANDBY{C_RESET}"
    fmode = oct(os.stat(tp).st_mode)[-4:]

    try:
        with open(tp, "r", encoding="utf-8") as f:
            data = json.load(f)
        tok_obj = data.get("token", {})
        access_tok = tok_obj.get("access_token")
        refresh_tok = tok_obj.get("refresh_token")
        expiry_str = tok_obj.get("expiry", "")
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        exp_dt = parse_rfc3339(expiry_str)

        is_expired = True
        if exp_dt and now_utc < (exp_dt - datetime.timedelta(minutes=5)):
            is_expired = False

        tok_action = "VALID"
        if is_expired:
            if not refresh_tok:
                raise RuntimeError("Missing refresh_token")
            payload = urllib.parse.urlencode({
                "client_id": cid,
                "client_secret": csec,
                "refresh_token": refresh_tok,
                "grant_type": "refresh_token"
            }).encode("utf-8")
            req = urllib.request.Request("https://oauth2.googleapis.com/token", data=payload, method="POST")
            with urllib.request.urlopen(req, timeout=10) as resp:
                refreshed = json.loads(resp.read().decode("utf-8"))
            access_tok = refreshed["access_token"]
            data["token"]["access_token"] = access_tok
            if refreshed.get("refresh_token"):
                data["token"]["refresh_token"] = refreshed["refresh_token"]
            if refreshed.get("id_token"):
                data["id_token"] = refreshed["id_token"]
            expires_in = int(refreshed.get("expires_in", 3600))
            local_exp = datetime.datetime.now().astimezone() + datetime.timedelta(seconds=expires_in)
            data["token"]["expiry"] = local_exp.isoformat()
            exp_dt = local_exp.astimezone(datetime.timezone.utc)
            with open(tp, "w", encoding="utf-8") as out:
                json.dump(data, out, indent=2)
            os.chmod(tp, 0o600)
            if is_active and os.path.isfile(current_token_file):
                with open(current_token_file, "w", encoding="utf-8") as out:
                    json.dump(data, out, indent=2)
                os.chmod(current_token_file, 0o600)
            tok_action = "AUTO-ROTATED"

        rem_min = max(0, int((exp_dt - now_utc).total_seconds() // 60)) if exp_dt else 0
        local_exp_str = exp_dt.astimezone().strftime("%Y-%m-%d %H:%M:%S %z") if exp_dt else "N/A"

        headers = {
            "Authorization": f"Bearer {access_tok}",
            "Content-Type": "application/json",
            "User-Agent": "antigravity/2.24.0"
        }

        tier_str = f"{C_GRAY}Free Tier{C_RESET}"
        credits_info = ""
        try:
            req_t = urllib.request.Request(f"{cloudcode_api}/v1internal:loadCodeAssist", data=b"{}", headers=headers, method="POST")
            with urllib.request.urlopen(req_t, timeout=10) as resp:
                td = json.loads(resp.read().decode("utf-8"))
                if td.get("paidTier"):
                    pt = td["paidTier"]
                    tname = pt.get("name") or pt.get("description") or "Paid Plan"
                    tid = pt.get("id", "")
                    if "ultra" in tid.lower() or "ultra" in tname.lower():
                        tier_str = f"{C_MAGENTA}{C_BOLD}Google AI Ultra{C_RESET}"
                    elif "pro" in tid.lower() or "pro" in tname.lower():
                        tier_str = f"{C_CYAN}{C_BOLD}Google AI Pro{C_RESET}"
                    else:
                        tier_str = f"{C_BLUE}{C_BOLD}{tname}{C_RESET}"
                    for cr in pt.get("availableCredits", []):
                        amt = cr.get("creditAmount")
                        if amt:
                            credits_info = f"  (Available Credits: {C_YELLOW}{C_BOLD}{amt}{C_RESET})"
        except Exception:
            pass

        gem_w, gem_5h, gem_rst = 1.0, 1.0, ""
        cld_w, cld_5h, cld_rst = 1.0, 1.0, ""
        try:
            req_q = urllib.request.Request(f"{cloudcode_api}/v1internal:retrieveUserQuotaSummary", data=b"{}", headers=headers, method="POST")
            with urllib.request.urlopen(req_q, timeout=10) as resp:
                qd = json.loads(resp.read().decode("utf-8"))
                for g in qd.get("groups", []):
                    gname = g.get("displayName", "").lower()
                    for b in g.get("buckets", []):
                        bname = b.get("displayName", "").lower()
                        frac = float(b.get("remainingFraction", 1.0))
                        rst = format_rel_time(b.get("resetTime", ""))
                        if "gemini" in gname:
                            if "weekly" in bname:
                                gem_w, gem_rst = frac, rst
                            elif "five" in bname or "hour" in bname:
                                gem_5h = frac
                        elif "claude" in gname or "gpt" in gname:
                            if "weekly" in bname:
                                cld_w, cld_rst = frac, rst
                            elif "five" in bname or "hour" in bname:
                                cld_5h = frac
        except Exception:
            pass

        gem_eff = min(gem_w, gem_5h)
        cld_eff = min(cld_w, cld_5h)

        if gem_eff > 0 and cld_eff > 0:
            ready_str = f"{C_GREEN}{C_BOLD}READY TO SWITCH & USE{C_RESET} (All model families available)"
        elif gem_eff > 0 and cld_eff <= 0:
            ready_str = f"{C_YELLOW}{C_BOLD}PARTIAL QUOTA{C_RESET} (Gemini ready {gem_w*100:.1f}%; Claude/GPT resets {cld_rst})"
        elif gem_eff <= 0 and cld_eff > 0:
            ready_str = f"{C_YELLOW}{C_BOLD}PARTIAL QUOTA{C_RESET} (Claude/GPT ready {cld_w*100:.1f}%; Gemini resets {gem_rst})"
        else:
            ready_str = f"{C_RED}{C_BOLD}QUOTA EXHAUSTED{C_RESET} (Token valid, but Gemini resets {gem_rst} & Claude resets {cld_rst})"

        def fmt_pct(val):
            c = C_GREEN if val > 0.5 else (C_YELLOW if val > 0.0 else C_RED)
            return f"{c}{val*100:5.1f}%{C_RESET}"

        print(f"{C_BOLD}[{idx}] {C_CYAN}{email}{C_RESET}  [{role_tag}]")
        print(f"    • Plan & Credits   : {tier_str}{credits_info}")
        print(f"    • OAuth Token      : {C_GREEN}{tok_action}{C_RESET} (expires in {rem_min}m at {local_exp_str})")
        print(f"    • Auto-Rotate      : {C_GREEN}ENABLED{C_RESET} (Refresh Token: OK | Permission: {fmode})")
        print(f"    • Quota Summary    : Gemini [Weekly: {fmt_pct(gem_w)} | 5h: {fmt_pct(gem_5h)}]  •  Claude/GPT [Weekly: {fmt_pct(cld_w)} | 5h: {fmt_pct(cld_5h)}]")
        print(f"    • Switch Readiness : {ready_str}")
        print(f"{C_GRAY}--------------------------------------------------------------------------------------------{C_RESET}")
    except Exception as e:
        print(f"{C_BOLD}[{idx}] {C_CYAN}{email}{C_RESET}  [{role_tag}]")
        print(f"    • OAuth Token      : {C_RED}INVALID / REVOKED ({e}){C_RESET}")
        print(f"    • Switch Readiness : {C_RED}{C_BOLD}RE-LOGIN REQUIRED{C_RESET} (Run: ./setup_antigravity.sh login)")
        print(f"{C_GRAY}--------------------------------------------------------------------------------------------{C_RESET}")
print(f"{C_BOLD}============================================================================================{C_RESET}")
' "${target}"
}

switch_account() {
    save_current_account
    local target="${1:-}"
    local acct_base="${ANTIGRAVITY_HOME}/.gemini/accounts"
    local current_token="${ANTIGRAVITY_HOME}/.gemini/jetski-standalone-oauth-token"
    local current_email="none"
    if [ -f "${current_token}" ]; then
        current_email=$(get_token_email "${current_token}")
    fi

    local accounts=()
    for d in "${acct_base}"/*; do
        if [ -d "${d}" ] && [ -f "${d}/jetski-standalone-oauth-token" ]; then
            accounts+=("$(basename "${d}")")
        fi
    done

    # If no target specified, show interactive selection menu
    if [ -z "${target}" ]; then
        list_accounts
        local total=${#accounts[@]}
        echo ""
        echo -e "  ${CYAN}[+] [n] Login to a new Google Account${NC}"
        echo -e "  ${YELLOW}[-] [q] Cancel / Quit${NC}"
        echo ""
        read -r -p "Select account number [1-${total}, n, q]: " choice

        case "${choice}" in
            q|Q|"")
                info "Cancelled."
                return 0
                ;;
            n|N)
                login_account
                return 0
                ;;
            *)
                if [[ "${choice}" =~ ^[0-9]+$ ]] && [ "${choice}" -ge 1 ] && [ "${choice}" -le "${total}" ]; then
                    target="${accounts[$((choice - 1))]}"
                else
                    error "Invalid selection: ${choice}"
                    return 1
                fi
                ;;
        esac
    fi

    # Resolve numeric index or partial email match if passed as argument
    if [[ "${target}" =~ ^[0-9]+$ ]] && [ "${target}" -ge 1 ] && [ "${target}" -le "${#accounts[@]}" ]; then
        target="${accounts[$((target - 1))]}"
    else
        if ! validate_account_id "${target}"; then
            error "Invalid account identifier: Path traversal or unsafe characters are not permitted."
            return 1
        fi
        if [ ! -f "${acct_base}/${target}/jetski-standalone-oauth-token" ]; then
            for a in "${accounts[@]}"; do
                if [[ "${a,,}" == *"${target,,}"* ]]; then
                    target="${a}"
                    break
                fi
            done
        fi
    fi

    if ! validate_account_id "${target}"; then
        error "Invalid account identifier: Path traversal or unsafe characters are not permitted."
        return 1
    fi

    # Verify target account exists
    local target_token="${acct_base}/${target}/jetski-standalone-oauth-token"
    if [ ! -f "${target_token}" ]; then
        error "Account '${target}' not found in saved profiles."
        info "Use '$0 accounts' to see saved accounts or '$0 login' to add a new account."
        return 1
    fi

    if [ "${target}" = "${current_email}" ]; then
        warn "Account '${target}' is already the active account."
        return 0
    fi

    info "Switching active Google account to: ${BOLD}${target}${NC}..."
    local tok_state=""
    if tok_state=$(ensure_valid_token "${target_token}" "false" 2>/dev/null); then
        local tok_status="${tok_state%%|*}"
        if [ "${tok_status}" = "ROTATED" ]; then
            info "Auto-rotated expired OAuth token for ${target} (${tok_state#*|})."
        fi
    else
        warn "Could not pre-refresh OAuth token for ${target}; proceeding with stored token."
    fi

    local was_running=false
    if check_running; then
        was_running=true
        stop_app
        sleep 1
    fi

    cp "${target_token}" "${current_token}"
    chmod 600 "${current_token}"

    local app_storage="${ANTIGRAVITY_HOME}/.config/Antigravity/app_storage.json"
    if [ -f "${app_storage}" ]; then
        python3 -c '
import json, sys
p, target_email = sys.argv[1], sys.argv[2]
try:
    with open(p, "r", encoding="utf-8") as f: d = json.load(f)
    d["jetski.onboarding.lastLoginUsername"] = target_email
    with open(p, "w", encoding="utf-8") as f: json.dump(d, f, indent=2)
except Exception: pass
' "${app_storage}" "${target}" 2>/dev/null || true
    fi

    success "Successfully switched active Google account to: ${BOLD}${GREEN}${target}${NC}!"

    if [ "${was_running}" = true ]; then
        info "Restarting Antigravity daemon with new account..."
        start_headless
    fi
}

logout_account() {
    save_current_account
    local current_token="${ANTIGRAVITY_HOME}/.gemini/jetski-standalone-oauth-token"
    local current_email="none"
    if [ -f "${current_token}" ]; then
        current_email=$(get_token_email "${current_token}")
    fi

    info "Logging out of Google Antigravity..."
    if check_running; then
        stop_app
        sleep 1
    fi

    if [ -f "${current_token}" ]; then
        rm -f "${current_token}"
    fi

    if [ -f "/config/.gemini/jetski-standalone-oauth-token" ]; then
        rm -f "/config/.gemini/jetski-standalone-oauth-token"
    fi

    success "Logged out successfully from: ${BOLD}${current_email}${NC}"
    info "Saved account profiles are preserved in ${ANTIGRAVITY_HOME}/.gemini/accounts/"
    info "Run '$0 login' to authenticate a new account or '$0 switch <account>' to switch."
}

login_account() {
    save_current_account
    local current_token="${ANTIGRAVITY_HOME}/.gemini/jetski-standalone-oauth-token"
    local tmp_dir
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/antigravity_auth.XXXXXXXXXX")
    chmod 700 "${tmp_dir}"
    local backup_token="${tmp_dir}/token.bak"

    local was_running=false
    if check_running; then
        was_running=true
        stop_app
        sleep 1
    fi

    if [ -f "${current_token}" ]; then
        mv "${current_token}" "${backup_token}"
    fi

    info "Starting new Google OAuth login session..."
    info "-> Visit the printed authorization URL in your browser and approve."
    info "-> Paste the authorization code below and press Enter."
    echo "------------------------------------------------------------"

    export HOME="${ANTIGRAVITY_HOME}"
    export ELECTRON_OZONE_PLATFORM_HINT=headless

    local watcher_pid=""
    cleanup_login() {
        if [ -n "${watcher_pid}" ]; then
            kill "${watcher_pid}" 2>/dev/null || true
        fi
        pkill -f "${INSTALL_DIR}/antigravity" 2>/dev/null || true
        if [ ! -f "${current_token}" ] && [ -f "${backup_token}" ]; then
            mv "${backup_token}" "${current_token}"
            info "Restored previous account token."
        fi
        rm -rf "${tmp_dir}"
        if [ "${was_running}" = true ]; then
            start_headless
        fi
        exit 1
    }
    trap cleanup_login INT TERM

    # Background watcher: monitors for token generation, then cleanly terminates auth process
    (
        local elapsed=0
        while true; do
            sleep 0.5
            elapsed=$((elapsed + 1))
            if [ $elapsed -ge 600 ]; then
                exit 0
            fi
            if [ -f "${current_token}" ] && [ -s "${current_token}" ]; then
                # Ensure token has valid access_token before terminating
                if python3 -c 'import json, sys; d=json.load(open(sys.argv[1], encoding="utf-8")); exit(0 if d.get("token",{}).get("access_token") or d.get("access_token") else 1)' "${current_token}" 2>/dev/null; then
                    sleep 1
                    local main_pid
                    main_pid=$(pgrep -f -o "${INSTALL_DIR}/antigravity" 2>/dev/null)
                    if [ -n "${main_pid}" ]; then
                        kill -TERM "${main_pid}" 2>/dev/null || true
                        sleep 1
                        if kill -0 "${main_pid}" 2>/dev/null; then
                            kill -9 "${main_pid}" 2>/dev/null || true
                        fi
                    fi
                    pkill -f "${INSTALL_DIR}/antigravity" 2>/dev/null || true
                    break
                fi
            fi
        done
    ) &
    watcher_pid=$!

    login_stream_filter() {
        while IFS= read -r line; do
            if [[ "${line}" =~ AutoUpdater|APPIMAGE|DevTools\ listening|Power\ save\ blocker|Starting\ app|Host\ bridge|Auto-Restart|Local:\ https|LS\ Logs|Electron\ Logs|ERROR:content|FATAL:content|Failed\ to\ send|GPU\ process|Network\ service\ crashed|zygote|Trace/breakpoint ]]; then
                continue
            fi
            echo "${line}"
            if [[ "${line}" =~ "Forwarded input to Language Server" ]]; then
                echo -e "  ${CYAN}${BOLD}[INFO] Code received! Contacting Google OAuth servers... Please wait...${NC}"
            fi
        done
    }

    # Run authentication in subshell with job control disabled to silence SIGTRAP messages
    (
        set +m
        "${BIN_PATH}" --no-sandbox 2>&1
    ) | login_stream_filter || true

    kill "${watcher_pid}" 2>/dev/null || true
    wait "${watcher_pid}" 2>/dev/null || true
    trap - INT TERM

    echo "------------------------------------------------------------"
    if [ -f "${current_token}" ]; then
        local new_email="unknown"
        for _r in {1..5}; do
            new_email=$(get_token_email "${current_token}")
            if [ -n "${new_email}" ] && [ "${new_email}" != "unknown" ]; then
                break
            fi
            sleep 1
        done

        if [ -z "${new_email}" ] || [ "${new_email}" = "unknown" ]; then
            echo ""
            read -r -p "Please enter the Google email for this account (e.g. user@example.com): " manual_email
            if [ -n "${manual_email}" ]; then
                new_email="${manual_email}"
            fi
        fi

        if [ -n "${new_email}" ] && [ "${new_email}" != "unknown" ] && validate_account_id "${new_email}"; then
            local acct_dir="${ANTIGRAVITY_HOME}/.gemini/accounts/${new_email}"
            mkdir -p "${acct_dir}"
            chmod 700 "${ANTIGRAVITY_HOME}/.gemini/accounts" "${acct_dir}" 2>/dev/null || true
            cp "${current_token}" "${acct_dir}/jetski-standalone-oauth-token"
            chmod 600 "${acct_dir}/jetski-standalone-oauth-token"
            chmod 600 "${current_token}"

            local app_storage="${ANTIGRAVITY_HOME}/.config/Antigravity/app_storage.json"
            if [ -f "${app_storage}" ]; then
                python3 -c '
import json, sys
p, target_email = sys.argv[1], sys.argv[2]
try:
    with open(p, "r", encoding="utf-8") as f: d = json.load(f)
    d["jetski.onboarding.lastLoginUsername"] = target_email
    with open(p, "w", encoding="utf-8") as f: json.dump(d, f, indent=2)
except Exception: pass
' "${app_storage}" "${new_email}" 2>/dev/null || true
            fi

            success "Successfully authenticated and saved profile for: ${BOLD}${GREEN}${new_email}${NC}!"
            rm -rf "${tmp_dir}"
        else
            warn "OAuth token created but could not register account profile (invalid or missing email)."
            rm -rf "${tmp_dir}"
        fi
    else
        warn "Login was cancelled or failed. Restoring previous account..."
        if [ -f "${backup_token}" ]; then
            mv "${backup_token}" "${current_token}"
        fi
        rm -rf "${tmp_dir}"
    fi

    if [ "${was_running}" = true ]; then
        start_headless
    fi
}

remove_account() {
    local target="${1:-}"
    if [ -z "${target}" ]; then
        error "Please specify the email of the account to remove. Example: $0 remove-account user@example.com"
        return 1
    fi

    if ! validate_account_id "${target}"; then
        error "Invalid account identifier: Path traversal or unsafe characters are not permitted."
        return 1
    fi

    local acct_dir="${ANTIGRAVITY_HOME}/.gemini/accounts/${target}"
    if [ ! -d "${acct_dir}" ]; then
        error "Account profile '${target}' does not exist."
        return 1
    fi

    rm -rf "${acct_dir}"
    success "Removed account profile: ${target}"
}

# ------------------------------------------------------------------------------
# 8b. Check Account Quotas and Model Limits (Direct API Inspection)
# ------------------------------------------------------------------------------
check_quota() {
    save_current_account
    local target=""
    local detail="false"

    for arg in "$@"; do
        case "${arg}" in
            --detail|--models|-v)
                detail="true"
                ;;
            *)
                if [ -z "${target}" ]; then
                    target="${arg}"
                fi
                ;;
        esac
    done

    export ANTIGRAVITY_HOME="${ANTIGRAVITY_HOME}"
    export CHECK_QUOTA_TARGET="${target}"
    export CHECK_QUOTA_DETAIL="${detail}"

    python3 -c "
import os, sys, json, urllib.request, urllib.parse, datetime, base64

# Resolve Google Antigravity OAuth Client Credentials dynamically from installed binary
def _get_credentials():
    cid = os.environ.get('ANTIGRAVITY_CLIENT_ID')
    csec = os.environ.get('ANTIGRAVITY_CLIENT_SECRET')
    if cid and csec:
        return cid, csec

    for base_dir in [os.environ.get('INSTALL_DIR', '/opt/antigravity'), '/opt/antigravity', '/usr/local/antigravity']:
        bin_path = os.path.join(base_dir, 'resources', 'bin', 'language_server')
        if os.path.isfile(bin_path):
            try:
                with open(bin_path, 'rb') as f:
                    content = f.read()
                import re
                if not cid:
                    m_cid = re.search(rb'(1071006060591-[a-z0-9_]+\.apps\.googleusercontent\.com)', content)
                    if m_cid:
                        cid = m_cid.group(1).decode('utf-8')
                if not csec:
                    m_csec = re.search(rb'(GOCSPX-K58FWR[a-zA-Z0-9_-]{22})', content)
                    if m_csec:
                        csec = m_csec.group(1).decode('utf-8')
                if cid and csec:
                    break
            except Exception:
                pass
    return cid, csec

CLIENT_ID, CLIENT_SECRET = _get_credentials()
HOME_DIR = os.environ.get('ANTIGRAVITY_HOME') or os.path.expanduser('~')
ACCOUNTS_DIR = os.path.join(HOME_DIR, '.gemini', 'accounts')
CURRENT_TOKEN_FILE = os.path.join(HOME_DIR, '.gemini', 'jetski-standalone-oauth-token')
CLOUDCODE_API = 'https://daily-cloudcode-pa.googleapis.com'
TARGET = os.environ.get('CHECK_QUOTA_TARGET', '').strip()
SHOW_DETAIL = os.environ.get('CHECK_QUOTA_DETAIL', 'false').lower() == 'true'

C_RESET = '\033[0m'
C_BOLD = '\033[1m'
C_GREEN = '\033[0;32m'
C_YELLOW = '\033[1;33m'
C_RED = '\033[0;31m'
C_CYAN = '\033[0;36m'
C_BLUE = '\033[0;34m'
C_MAGENTA = '\033[0;35m'
C_GRAY = '\033[0;90m'

def get_current_email():
    if not os.path.isfile(CURRENT_TOKEN_FILE):
        return None
    try:
        with open(CURRENT_TOKEN_FILE, 'r', encoding='utf-8') as f:
            d = json.load(f)
        id_tok = d.get('id_token')
        if id_tok and '.' in id_tok:
            import base64
            p = id_tok.split('.')[1]
            p += '=' * ((4 - len(p) % 4) % 4)
            info = json.loads(base64.urlsafe_b64decode(p).decode('utf-8'))
            return info.get('email')
    except Exception:
        pass
    return None

def progress_bar(fraction, width=16):
    pct = max(0.0, min(1.0, fraction))
    filled = int(round(width * pct))
    bar = '█' * filled + '░' * (width - filled)
    pct_str = f'{pct * 100:5.1f}%'
    if pct > 0.5:
        color = C_GREEN
    elif pct > 0.2:
        color = C_YELLOW
    else:
        color = C_RED
    return f'{color}[{bar}] {pct_str}{C_RESET}'

def format_relative_time(reset_time_str):
    if not reset_time_str or reset_time_str == 'N/A':
        return 'N/A'
    try:
        rt = reset_time_str.replace('Z', '+00:00')
        dt = datetime.datetime.fromisoformat(rt)
        now = datetime.datetime.now(datetime.timezone.utc)
        diff = dt - now
        total_sec = int(diff.total_seconds())
        if total_sec <= 0:
            return 'Refreshing now'
        days = total_sec // 86400
        hours = (total_sec % 86400) // 3600
        minutes = (total_sec % 3600) // 60
        if days > 0:
            return f'in {days}d {hours}h'
        elif hours > 0:
            return f'in {hours}h {minutes}m'
        else:
            return f'in {minutes}m'
    except Exception:
        return reset_time_str

def refresh_token(token_path, is_active):
    import re
    with open(token_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    token_obj = data.get('token', {})
    access_token = token_obj.get('access_token')
    refresh_token_val = token_obj.get('refresh_token')
    expiry_str = token_obj.get('expiry')

    is_expired = True
    if expiry_str:
        try:
            s = expiry_str.strip()
            if s.endswith('Z'):
                s = s[:-1] + '+00:00'
            s = re.sub(r'\.(\d{6})\d+([+-]\d{2}:\d{2})$', r'.\1\2', s)
            s = re.sub(r'\.(\d+)(?=[+-]\d{2}:\d{2}$)', lambda m: '.' + m.group(1).ljust(6, '0')[:6], s)
            exp_dt = datetime.datetime.fromisoformat(s)
            if exp_dt.tzinfo is None:
                exp_dt = exp_dt.replace(tzinfo=datetime.timezone.utc)
            exp_dt = exp_dt.astimezone(datetime.timezone.utc)
            now = datetime.datetime.now(datetime.timezone.utc)
            if now < exp_dt - datetime.timedelta(minutes=5):
                is_expired = False
        except Exception:
            pass

    if is_expired and refresh_token_val:
        payload = urllib.parse.urlencode({
            'client_id': CLIENT_ID,
            'client_secret': CLIENT_SECRET,
            'refresh_token': refresh_token_val,
            'grant_type': 'refresh_token'
        }).encode('utf-8')
        req = urllib.request.Request('https://oauth2.googleapis.com/token', data=payload, method='POST')
        with urllib.request.urlopen(req, timeout=10) as resp:
            refreshed = json.loads(resp.read().decode('utf-8'))
            access_token = refreshed['access_token']
            data['token']['access_token'] = access_token
            if refreshed.get('refresh_token'):
                data['token']['refresh_token'] = refreshed['refresh_token']
            if refreshed.get('id_token'):
                data['id_token'] = refreshed['id_token']
            expires_in = int(refreshed.get('expires_in', 3600))
            new_exp = (datetime.datetime.now().astimezone() + datetime.timedelta(seconds=expires_in)).isoformat()
            data['token']['expiry'] = new_exp
            with open(token_path, 'w', encoding='utf-8') as out:
                json.dump(data, out, indent=2)
            os.chmod(token_path, 0o600)
            if is_active and os.path.isfile(CURRENT_TOKEN_FILE):
                with open(CURRENT_TOKEN_FILE, 'w', encoding='utf-8') as out:
                    json.dump(data, out, indent=2)
                os.chmod(CURRENT_TOKEN_FILE, 0o600)

    return access_token

def get_active_ls_quota():
    try:
        import subprocess, ssl, re
        out = subprocess.check_output(['ps', '-ef'], text=True)
        ls_line = None
        for l in out.splitlines():
            if 'language_server' in l and '--csrf_token' in l and '--standalone' in l:
                ls_line = l
                break
        if not ls_line:
            return None
        m_csrf = re.search(r'--csrf_token\s+([a-zA-Z0-9-]+)', ls_line)
        if not m_csrf:
            return None
        csrf = m_csrf.group(1)

        log_path = os.path.expanduser('~/.config/Antigravity/logs/language_server.log')
        if not os.path.isfile(log_path):
            return None
        port = None
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                if 'Language server listening on random port at' in line and 'for HTTPS' in line:
                    m = re.search(r'at\s+(\d+)\s+for HTTPS', line)
                    if m:
                        port = int(m.group(1))
        if not port:
            return None

        ctx = ssl._create_unverified_context()
        url = f'https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary'
        headers = {'Content-Type': 'application/json', 'x-codeium-csrf-token': csrf}
        req = urllib.request.Request(url, data=b'{}', headers=headers, method='POST')
        with urllib.request.urlopen(req, context=ctx, timeout=3) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            return data.get('response', {})
    except Exception:
        return None

current_active = get_current_email()
candidate_accounts = []
if os.path.isdir(ACCOUNTS_DIR):
    for d in sorted(os.listdir(ACCOUNTS_DIR)):
        tp = os.path.join(ACCOUNTS_DIR, d, 'jetski-standalone-oauth-token')
        if os.path.isfile(tp):
            candidate_accounts.append((d, tp))

if not candidate_accounts and os.path.isfile(CURRENT_TOKEN_FILE):
    act_email = current_active or 'active-account'
    candidate_accounts.append((act_email, CURRENT_TOKEN_FILE))

if TARGET:
    exact = [item for item in candidate_accounts if TARGET.lower() == item[0].lower()]
    if exact:
        candidate_accounts = exact
    else:
        candidate_accounts = [item for item in candidate_accounts if TARGET.lower() in item[0].lower()]
    if not candidate_accounts:
        print(f'{C_RED}[ERROR] No saved account matching \"{TARGET}\" was found.{C_RESET}')
        print(f'Use \"./setup_antigravity.sh accounts\" to view all registered accounts.')
        sys.exit(1)

if not candidate_accounts:
    print(f'{C_YELLOW}[WARN] No saved Google accounts found.{C_RESET}')
    print(f'Run \"./setup_antigravity.sh login\" to register an account.')
    sys.exit(0)

print(f'{C_BOLD}============================== GOOGLE ACCOUNTS QUOTA STATUS =============================={C_RESET}')
for acc_name, acc_path in candidate_accounts:
    is_active = (acc_name == current_active)
    active_tag = f' {C_GREEN}(ACTIVE){C_RESET}' if is_active else ''
    
    try:
        tok = refresh_token(acc_path, is_active)
        headers = {
            'Authorization': f'Bearer {tok}',
            'Content-Type': 'application/json',
            'User-Agent': 'antigravity/2.24.0'
        }
        
        tier_badge = f'{C_GRAY}[Free Tier]{C_RESET}'
        credits_str = ''
        plan_note = ''

        try:
            req_tier = urllib.request.Request(f'{CLOUDCODE_API}/v1internal:loadCodeAssist', data=b'{}', headers=headers, method='POST')
            with urllib.request.urlopen(req_tier, timeout=10) as resp:
                tdata = json.loads(resp.read().decode('utf-8'))
                if tdata.get('paidTier'):
                    pt = tdata['paidTier']
                    t_name = pt.get('name') or pt.get('description') or 'Paid Plan'
                    t_id = pt.get('id', '')
                    if 'ultra' in t_id.lower() or 'ultra' in t_name.lower():
                        tier_badge = f'{C_BOLD}{C_MAGENTA}[Google AI Ultra]{C_RESET}'
                    elif 'pro' in t_id.lower() or 'pro' in t_name.lower():
                        tier_badge = f'{C_BOLD}{C_CYAN}[Google AI Pro]{C_RESET}'
                    else:
                        tier_badge = f'{C_BOLD}{C_BLUE}[{t_name}]{C_RESET}'

                    cr_list = pt.get('availableCredits', [])
                    for cr in cr_list:
                        amt = cr.get('creditAmount')
                        if amt:
                            credits_str = f'  Available Credits: {C_YELLOW}{C_BOLD}{amt}{C_RESET}'

                    plan_note = pt.get('upgradeSubscriptionText', '')
                elif tdata.get('currentTier'):
                    ct = tdata['currentTier']
                    tier_badge = f\"{C_GRAY}[{ct.get('name', 'Antigravity')} ({ct.get('id', 'free-tier')})]{C_RESET}\"
        except Exception:
            pass

        print(f'{C_BOLD}Account: {C_CYAN}{acc_name}{C_RESET}{active_tag}  {tier_badge}{credits_str}')
        if plan_note:
            print(f'  {C_GRAY}Plan Status: {plan_note}{C_RESET}')

        qdata = None
        if is_active:
            qdata = get_active_ls_quota()

        if not qdata:
            req_q = urllib.request.Request(f'{CLOUDCODE_API}/v1internal:retrieveUserQuotaSummary', data=b'{}', headers=headers, method='POST')
            with urllib.request.urlopen(req_q, timeout=10) as resp:
                qdata = json.loads(resp.read().decode('utf-8'))

        groups = qdata.get('groups', [])
        for g in groups:
            g_title = g.get('displayName', 'Group')
            print(f'  {C_BOLD}▸ {g_title}:{C_RESET}')
            for b in g.get('buckets', []):
                b_name = b.get('displayName', b.get('bucketId', 'Limit'))
                frac = b.get('remainingFraction', 1.0)
                reset_raw = b.get('resetTime', '')
                rel_time = format_relative_time(reset_raw)
                desc = b.get('description', '')
                bar = progress_bar(frac, width=16)
                print(f'    • {b_name:<28}: {bar}  {C_GRAY}(Reset: {rel_time}){C_RESET}')
                if desc and frac < 0.2:
                    print(f'      {C_YELLOW}↳ {desc}{C_RESET}')

        if SHOW_DETAIL:
            try:
                req_d = urllib.request.Request(f'{CLOUDCODE_API}/v1internal:retrieveUserQuota', data=b'{}', headers=headers, method='POST')
                with urllib.request.urlopen(req_d, timeout=10) as resp:
                    ddata = json.loads(resp.read().decode('utf-8'))
                    families = {'Claude': [], 'Gemini': [], 'GPT': [], 'Other': []}
                    for b in ddata.get('buckets', []):
                        mid = b.get('modelId', '')
                        if 'claude' in mid:
                            families['Claude'].append(b)
                        elif 'gemini' in mid:
                            families['Gemini'].append(b)
                        elif 'gpt' in mid:
                            families['GPT'].append(b)
                        else:
                            families['Other'].append(b)

                    print(f'  {C_BOLD}▸ Model-level Breakdown:{C_RESET}')
                    for fam, items in families.items():
                        if not items: continue
                        print(f'    {C_CYAN}[{fam} Family]{C_RESET}')
                        for b in items:
                            mid = b.get('modelId', '')
                            frac = b.get('remainingFraction', 1.0)
                            reset_raw = b.get('resetTime', '')
                            rel_time = format_relative_time(reset_raw) if reset_raw else '-'
                            bar = progress_bar(frac, width=12)
                            print(f'      • {mid:<28}: {bar}  {C_GRAY}(Reset: {rel_time}){C_RESET}')
            except Exception as e:
                print(f'  {C_YELLOW}[!] Could not fetch model-level details: {e}{C_RESET}')

        print(f'{C_GRAY}------------------------------------------------------------------------------------------{C_RESET}')
    except Exception as e:
        print(f'{C_BOLD}Account: {C_CYAN}{acc_name}{C_RESET}{active_tag}  [{C_RED}ERROR / REVOKED: {e}{C_RESET}]')
        print(f'{C_GRAY}------------------------------------------------------------------------------------------{C_RESET}')

print(f'{C_BOLD}=========================================================================================={C_RESET}')
"
}

# ------------------------------------------------------------------------------
# 9. Stop Process
# ------------------------------------------------------------------------------
stop_app() {
    local stopped=false
    if [ -f "${PID_FILE}" ]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            info "Stopping Antigravity daemon (PID: ${pid})..."
            kill "${pid}" || true
            sleep 2
            if kill -0 "${pid}" 2>/dev/null; then
                kill -9 "${pid}" 2>/dev/null || true
            fi
            stopped=true
        fi
        rm -f "${PID_FILE}"
    fi

    if pgrep -f "${INSTALL_DIR}/antigravity" >/dev/null 2>&1; then
        info "Terminating lingering Antigravity processes..."
        pkill -f "${INSTALL_DIR}/antigravity" 2>/dev/null || true
        stopped=true
    fi

    if [ "${stopped}" = true ]; then
        success "Antigravity stopped successfully."
    else
        info "No active Antigravity process found."
    fi
}

check_running() {
    if [ -f "${PID_FILE}" ]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            return 0
        fi
    fi
    if pgrep -f "${INSTALL_DIR}/antigravity" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# 10. Status Inspection
# ------------------------------------------------------------------------------
status_app() {
    echo "==================== ANTIGRAVITY STATUS ===================="
    local show_ps=false
    for arg in "$@"; do
        if [ "${arg}" = "--ps" ] || [ "${arg}" = "-v" ] || [ "${arg}" = "--processes" ]; then
            show_ps=true
        fi
    done

    if check_running; then
        local pid=""
        if [ -f "${PID_FILE}" ]; then
            pid=$(cat "${PID_FILE}" 2>/dev/null)
        fi
        if [ -z "${pid}" ] || ! kill -0 "${pid}" 2>/dev/null; then
            pid=$(pgrep -f -o "${INSTALL_DIR}/antigravity" 2>/dev/null | head -n1)
        fi

        local uptime=""
        if [ -n "${pid}" ]; then
            uptime=$(ps -p "${pid}" -o etime= 2>/dev/null | tr -d ' ')
        fi

        echo -e "Daemon Status:           ${GREEN}RUNNING${NC} (PID: ${pid}${uptime:+, Uptime: ${uptime}})"

        local ls_pid
        ls_pid=$(pgrep -f "language_server.*--standalone" 2>/dev/null | head -n1)
        if [ -n "${ls_pid}" ]; then
            echo -e "Language Server:         ${GREEN}ACTIVE${NC} (PID: ${ls_pid})"
        fi
    else
        echo -e "Daemon Status:           ${RED}STOPPED${NC}"
    fi

    local config_file="${ANTIGRAVITY_HOME}/.gemini/config/config.json"
    local token_file="${ANTIGRAVITY_HOME}/.gemini/jetski-standalone-oauth-token"

    if [ -f "${token_file}" ]; then
        local tok_info=""
        tok_info=$(ensure_valid_token "${token_file}" "false" 2>/dev/null || true)
        save_current_account
        local user_email
        user_email=$(get_token_email "${token_file}")
        if [ -n "${user_email}" ] && [ "${user_email}" != "unknown" ]; then
            echo -e "Google Auth:             ${GREEN}AUTHENTICATED (${user_email})${NC}"
        else
            echo -e "Google Auth:             ${GREEN}AUTHENTICATED (Token active)${NC}"
        fi
        if [ -n "${tok_info}" ] && [[ "${tok_info}" == VALID* || "${tok_info}" == ROTATED* ]]; then
            echo -e "OAuth Token:             ${GREEN}${tok_info%%|*}${NC} (${tok_info#*|})"
        fi
    else
        echo -e "Google Auth:             ${YELLOW}NOT LOGGED IN${NC} (Run '$0 login' or '$0 gui')"
    fi

    if [ -f "${config_file}" ]; then
        local rc_enabled rc_hostname
        rc_enabled=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        d = json.load(f)
    print(d.get("userSettings", {}).get("remoteControlEnabled", False))
except Exception:
    print(False)
' "${config_file}")
        rc_hostname=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        d = json.load(f)
    print(d.get("userSettings", {}).get("remoteControlHostname", "Not set"))
except Exception:
    print("Not set")
' "${config_file}")
        if [ "${rc_enabled}" = "True" ]; then
            echo -e "Remote Control:          ${GREEN}ENABLED${NC} (Host: ${CYAN}${rc_hostname}${NC})"
            echo -e "Web Dashboard:           ${CYAN}https://antigravity.google.com${NC}"
        else
            echo -e "Remote Control:          ${YELLOW}DISABLED${NC} (Enable via: '$0 remote-on')"
        fi
    fi

    echo -e "Data directory (HOME):   ${BLUE}${ANTIGRAVITY_HOME}${NC}"
    echo -e "Language Server Log:     ${LOG_DIR}/language_server.log"

    if [ "${show_ps}" = true ] && check_running; then
        echo "------------------------------------------------------------"
        echo "Process Tree:"
        # shellcheck disable=SC2009
        ps -ef | grep -E "${INSTALL_DIR}/antigravity|language_server" | grep -v grep || true
    fi
    echo "============================================================"
}

# ------------------------------------------------------------------------------
# 11. Remote Control Toggle (Custom or Automated Hostname)
# ------------------------------------------------------------------------------
enable_remote() {
    local custom_host="${1:-}"
    if [ -n "${custom_host}" ] && ! validate_account_id "${custom_host}"; then
        error "Invalid hostname: Only alphanumeric characters, hyphens, dots, and underscores are allowed."
        return 1
    fi

    local config_file="${ANTIGRAVITY_HOME}/.gemini/config/config.json"
    mkdir -p "$(dirname "${config_file}")"

    info "Enabling Remote Control..."
    local detected_host
    detected_host=$(python3 -c '
import json, os, socket, sys

path = sys.argv[1]
custom = sys.argv[2].strip() if len(sys.argv) > 2 else ""
data = {}
if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = {}

if "userSettings" not in data:
    data["userSettings"] = {}

if custom:
    host = custom
else:
    host = data["userSettings"].get("remoteControlHostname")
    if not host or host == "Not set":
        host = socket.gethostname().lower()

data["userSettings"]["remoteControlEnabled"] = True
data["userSettings"]["remoteControlHostname"] = host

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(host)
' "${config_file}" "${custom_host}")
    success "Remote Control enabled! Assigned Hostname: ${CYAN}${detected_host}${NC}"
    info "Access online from any browser or mobile device at: ${BOLD}${CYAN}https://antigravity.google.com${NC}"
    if check_running; then
        info "Restarting Antigravity daemon to apply changes: $0 restart"
    fi
}

disable_remote() {
    local config_file="${ANTIGRAVITY_HOME}/.gemini/config/config.json"
    if [ -f "${config_file}" ]; then
        python3 -c '
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
if "userSettings" in data:
    data["userSettings"]["remoteControlEnabled"] = False
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
' "${config_file}"
        success "Remote Control disabled in ${config_file}."
        if check_running; then
            info "Restarting Antigravity daemon to apply changes: $0 restart"
        fi
    fi
}

# ------------------------------------------------------------------------------
# 12. Setup Systemd Service (Autostart on Boot)
# ------------------------------------------------------------------------------
setup_service() {
    info "Configuring systemd user service with HOME=${ANTIGRAVITY_HOME}..."
    local service_dir="${HOME}/.config/systemd/user"
    mkdir -p "${service_dir}"

    cat <<EOF > "${service_dir}/antigravity.service"
[Unit]
Description=Antigravity 2.0 Headless Background Daemon
After=network.target

[Service]
Type=simple
Environment=HOME=${ANTIGRAVITY_HOME}
Environment=ELECTRON_OZONE_PLATFORM_HINT=${ELECTRON_OZONE_PLATFORM_HINT:-headless}
Environment=TZ=${TZ:-Asia/Ho_Chi_Minh}
Environment=PATH=${ANTIGRAVITY_HOME}/.gemini/antigravity/bin:${ANTIGRAVITY_HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${BIN_PATH} --no-sandbox
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable antigravity.service
    success "Systemd user service installed and enabled!"
    echo "  - Start:  systemctl --user start antigravity"
    echo "  - Stop:   systemctl --user stop antigravity"
    echo "  - Logs:   journalctl --user -u antigravity -f"
}

# ------------------------------------------------------------------------------
# 13. Shell Tab Completion (Bash & Zsh)
# ------------------------------------------------------------------------------
emit_completion_script() {
    cat <<'EOF'
# antigravity2-headless Tab Completion (Bash & Zsh compatible)
if [ -n "${ZSH_VERSION:-}" ]; then
    autoload -U +X bashcompinit && bashcompinit 2>/dev/null || true
elif [ -n "${BASH_VERSION:-}" ]; then
    COMP_WORDBREAKS="${COMP_WORDBREAKS//@/}"
fi

_antigravity2_headless_completions() {
    local cur prev words cword
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="install start stop restart status accounts account-status switch-account switch login logout quota remove-account check-version update download gui remote-on remote-off service completion logs"

    if [ "${COMP_CWORD}" -eq 1 ]; then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )
        return 0
    fi

    local acct_dir="${ANTIGRAVITY_HOME:-${HOME}}/.gemini/accounts"
    local saved_emails=""
    if [ -d "${acct_dir}" ]; then
        saved_emails=$(find "${acct_dir}" -mindepth 1 -maxdepth 1 -type d -printf "%f " 2>/dev/null || true)
    fi

    case "${COMP_WORDS[1]}" in
        switch|switch-account|account-status|accounts-status|status-account|check-account|remove-account)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "${saved_emails}" -- "${cur}") )
            fi
            ;;
        quota|check-quota)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "${saved_emails} --detail" -- "${cur}") )
            ;;
        accounts|account|list-accounts)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "--status ${saved_emails}" -- "${cur}") )
            fi
            ;;
        status)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "--ps --processes" -- "${cur}") )
            fi
            ;;
        completion|completions)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "install bash zsh" -- "${cur}") )
            fi
            ;;
        remote-on|enable-remote)
            if [ "${COMP_CWORD}" -eq 2 ]; then
                # shellcheck disable=SC2207
                COMPREPLY=( $(compgen -W "$(hostname 2>/dev/null || echo 'my-dev-server')" -- "${cur}") )
            fi
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
    return 0
}

complete -F _antigravity2_headless_completions setup_antigravity.sh ./setup_antigravity.sh ag-headless
EOF
}

setup_completion() {
    local subcmd="${1:-install}"
    case "${subcmd}" in
        bash|zsh|print|show)
            emit_completion_script
            return 0
            ;;
        install|"")
            info "Installing CLI Tab Completion for Bash & Zsh..."
            local user_comp_dir="${HOME}/.local/share/bash-completion/completions"
            mkdir -p "${user_comp_dir}"
            local comp_file="${user_comp_dir}/setup_antigravity.sh"
            emit_completion_script > "${comp_file}"
            cp "${comp_file}" "${user_comp_dir}/ag-headless"

            if [ -d "/etc/bash_completion.d" ]; then
                if [ -w "/etc/bash_completion.d" ] || command -v sudo >/dev/null 2>&1; then
                    run_sudo cp "${comp_file}" /etc/bash_completion.d/antigravity2-headless 2>/dev/null || true
                fi
            fi

            run_sudo ln -sf "${SCRIPT_DIR}/setup_antigravity.sh" /usr/local/bin/ag-headless 2>/dev/null || true

            for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
                if [ -f "${rc}" ]; then
                    if ! grep -q "antigravity2-headless Tab Completion" "${rc}" 2>/dev/null; then
                        {
                            echo ""
                            echo "# antigravity2-headless Tab Completion"
                            echo "[ -f \"${comp_file}\" ] && source \"${comp_file}\""
                        } >> "${rc}"
                    fi
                fi
            done

            success "Tab completion installed for './setup_antigravity.sh' and global 'ag-headless' CLI!"
            info "Run 'source ~/.bashrc' (or open a new terminal) to activate <TAB> auto-complete immediately."
            ;;
        *)
            error "Unknown completion option: ${subcmd}. Use: '$0 completion [install|bash|zsh]'"
            return 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# CLI Dispatcher
# ------------------------------------------------------------------------------
usage() {
    echo "Usage: $0 {install|start|stop|restart|status|accounts|account-status|switch-account|login|logout|quota|check-version|update|download|gui|remote-on|service|completion|logs}"
    echo ""
    echo -e "${GREEN}Primary Daily Commands:${NC}"
    echo "  start                   : Launch Antigravity headless daemon in background (auto-login, auto-remote)"
    echo "  stop                    : Stop the running headless daemon"
    echo "  restart                 : Restart the headless daemon"
    echo "  status                  : Inspect daemon status, PID, active Google Account, and Remote Control host"
    echo ""
    echo -e "${CYAN}Google Account Management:${NC}"
    echo "  accounts                : List all saved Google accounts with live OAuth token status"
    echo "  account-status [email]  : Detailed health, OAuth auto-rotate & switch-readiness check per account"
    echo "  switch-account [email]  : Switch active account (or interactive menu if email is omitted)"
    echo "  login                   : Authenticate and register a new Google account profile"
    echo "  logout                  : Log out of current active account and stop daemon safely"
    echo "  quota [email] [--detail]: Direct fast quota & credit inspection across accounts (no login required)"
    echo "  remove-account <email>  : Remove a saved account profile"
    echo ""
    echo -e "${CYAN}Version & Lifecycle Management:${NC}"
    echo "  check-version           : Compare local installed version with latest upstream Google release"
    echo "  update                  : Download and in-place upgrade Antigravity to the latest release"
    echo "  download                : Download the latest official Antigravity.tar.gz archive from Google Cloud"
    echo ""
    echo -e "${YELLOW}Configuration & Interactive Tools:${NC}"
    echo "  gui                     : Open native desktop GUI window (WSLg) for visual inspection"
    echo "  remote-on [name]        : Enable Remote Control (supports custom hostname or system hostname)"
    echo "  remote-off              : Disable Remote Control"
    echo "  install                 : Install OS dependencies, unpack Antigravity & enable Tab Completion"
    echo "  service                 : Register systemd user service for automated boot startup"
    echo "  completion [install]    : Install intelligent <TAB> auto-completion for commands & emails"
    echo "  logs                    : Follow live Language Server logs"
    exit 1
}

case "${1:-}" in
    start)
        start_headless
        ;;
    stop)
        stop_app
        ;;
    restart)
        stop_app
        sleep 1
        start_headless
        ;;
    status)
        shift
        status_app "$@"
        ;;
    accounts|account|list-accounts)
        shift
        list_accounts "$@"
        ;;
    account-status|accounts-status|status-account|status-accounts|check-account|check-accounts)
        shift
        check_account_status "$@"
        ;;
    switch-account|switch)
        switch_account "${2:-}"
        ;;
    login|add-account)
        login_account
        ;;
    logout|signout)
        logout_account
        ;;
    quota|check-quota)
        shift
        check_quota "$@"
        ;;
    remove-account)
        remove_account "${2:-}"
        ;;
    check-version|version)
        check_version
        ;;
    update)
        update_app
        ;;
    download)
        download_archive
        ;;
    gui|open-gui|open)
        open_gui
        ;;
    auth)
        auth_terminal
        ;;
    remote-on|enable-remote)
        enable_remote "${2:-}"
        ;;
    remote-off|disable-remote)
        disable_remote
        ;;
    install)
        install_antigravity
        ;;
    service)
        setup_service
        ;;
    completion|completions)
        shift
        setup_completion "$@"
        ;;
    logs)
        tail -f "${LOG_DIR}/language_server.log"
        ;;
    *)
        usage
        ;;
esac
