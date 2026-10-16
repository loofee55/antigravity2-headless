# Antigravity 2.0 Headless (`antigravity2-headless`)

> 🌐 **Language / Ngôn ngữ:** **🇬🇧 English** | [🇻🇳 Tiếng Việt](README.vi.md)

[![Platform: Linux / WSL2](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL2-blue.svg)](https://ubuntu.com/)
[![Runtime: Headless Electron](https://img.shields.io/badge/Runtime-Electron%20Ozone%20Headless-success.svg)](https://electronjs.org)
[![Antigravity: 2.0+](https://img.shields.io/badge/Antigravity-2.0%2B-orange.svg)](https://antigravity.google)
[![Headless Shell: ~180MB PSS](https://img.shields.io/badge/Headless_Shell-~180MB_PSS_(No_VNC_Bloat)-brightgreen?logo=speedtest)](https://github.com/loofee55/antigravity2-headless)
[![Security Audit: 100% Passed](https://img.shields.io/badge/Security_Audit-Trivy_%7C_GitLeaks_%7C_ShellCheck-blueviolet?logo=shield)](https://github.com/loofee55/antigravity2-headless)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready%20%7C%20Compose-2496ED?logo=docker&logoColor=white)](docker-compose.yml)
[![Multi-Account: Supported](https://img.shields.io/badge/Multi--Account-Gemini_%26_Claude-FF6F00?logo=google)](https://github.com/loofee55/antigravity2-headless)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A high-performance, ultra-lightweight, production-grade management toolkit to run **Google Antigravity 2.0** as a native headless background daemon on **Linux servers** and **Windows Subsystem for Linux (WSL2)**.

Eliminates the heavy overhead of full desktop containers (Webtop, KasmVNC, X11, XFCE) while delivering instant **Remote Control**, automatic Google Cloud upstream updates, persistent OAuth authentication, on-demand WSLg GUI inspection, and systemd integration.

---

## 📑 Table of Contents

- [Why Antigravity 2.0 Headless?](#-why-antigravity-20-headless)
- [Architecture & Performance Comparison](#-architecture--performance-comparison)
- [Key Features](#-key-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Command Line Interface (CLI)](#-command-line-interface-cli)
- [Remote Control Guide](#-remote-control-guide)
- [Multi-Account Management & Instant Switching](#-multi-account-management--instant-switching)
- [Fast Quota & Credit Inspection](#-fast-quota--credit-inspection)
- [WSLg Graphical Window on Demand](#-wslg-graphical-window-on-demand)
- [Version Check & Auto-Updates](#-version-check--auto-updates)
- [Systemd Autostart Service](#-systemd-autostart-service)
- [Docker / Container Deployment](#-docker--container-deployment)
- [Configuration Reference (`.env`)](#-configuration-reference-env)
- [Directory Structure](#-directory-structure)
- [Troubleshooting & FAQ](#-troubleshooting--faq)
- [License](#-license)

---

## 💡 Why Antigravity 2.0 Headless?

Google Antigravity is distributed primarily as an Electron application. Traditionally, running Antigravity on a remote Linux server or headless WSL2 instance required heavy, cumbersome workarounds:
- Installing full desktop environments (XFCE, GNOME) and VNC/RDP servers (KasmVNC, Xrdp, Webtop).
- Enduring high memory footprints (**1.5 GB to 3 GB+ RAM** just for the window manager, X11 server, and video streaming encoder).
- Experiencing video streaming lag and unnecessary CPU consumption.

**`antigravity2-headless`** solves this by activating Chromium/Electron's native Headless Ozone platform abstraction (`ELECTRON_OZONE_PLATFORM_HINT=headless` with `--use-gl=disabled`). Instead of wasting gigabytes of memory on a virtual desktop and VNC streamer, the **Electron Headless Shell overhead is reduced to only ~150–180 MB RAM (PSS)**, while the core `language_server` process scales dynamically based solely on your own project size and active agent workload. You retain full support for **24/7 Remote Control** via [`https://antigravity.google.com`](https://antigravity.google.com), **AI Agent & Scheduled Tasks execution**, **on-demand WSLg GUI window**, and **CLI lifecycle, multi-account, and quota management**.

---

## ⚡ Architecture & Performance Comparison

```
Traditional Approach (Webtop / KasmVNC)          antigravity2-headless
┌──────────────────────────────────────┐        ┌──────────────────────────────────────┐
│  Browser / Client (Video Streaming)  │        │  Web / Mobile PWA                    │
│                                      │        │  (https://antigravity.google.com)    │
└──────────────────▲───────────────────┘        └──────────────────▲───────────────────┘
                   │ High latency VNC                      │ Native Cloud Relay / gRPC
┌──────────────────▼───────────────────┐        ┌──────────▼───────────────────────────┐
│  KasmVNC / X11 / XFCE Desktop Env    │        │  Antigravity 2.0 Headless Daemon     │
│  (Desktop Overhead: ~1.5 - 3 GB RAM) │        │  (Shell: ~150-180 MB PSS, Zero VNC)  │
└──────────────────▲───────────────────┘        └──────────────────▲───────────────────┘
                   │                                               │
┌──────────────────▼───────────────────┐        ┌──────────────────▼───────────────────┐
│  Antigravity App + Language Server   │        │  Linux Host / WSL2 Kernel            │
└──────────────────────────────────────┘        └──────────────────────────────────────┘
```

| Metric / Feature | Traditional Desktop Container (Webtop) | `antigravity2-headless` (Native Daemon) |
| :--- | :--- | :--- |
| **Display & Shell Overhead** | ~1,500 MB – 3,000 MB+ RAM (XFCE + X11 + VNC) | **~150 MB – 180 MB RAM (PSS)** (0 MB VNC/Desktop bloat) |
| **Language Server RAM** | Scales with workspace & active agents | **Identical** (Scales dynamically with your projects & tasks) |
| **Startup Time** | 25 – 45 seconds | **< 1.5 seconds** |
| **Display Server Required** | Yes (X11 / Xvfb / KasmVNC) | **None** (Native Electron Headless Ozone) |
| **Control Latency** | Network video streaming latency | **Zero** (Native state sync via Web Dashboard) |
| **Update Mechanism** | Rebuild multi-gigabyte container image | **One command:** `./setup_antigravity.sh update` |
| **WSLg Desktop Support** | Clunky VNC browser window | **Instant native Windows window on demand** |
| **Session Persistence** | Vulnerable to container wipes | **Native host storage (`$HOME` or `~/.gemini`)** |

---

## ✨ Key Features

- **Zero-Display Headless Daemon**: Runs Antigravity 2.0 without virtual displays (Xvfb) or desktop window managers.
- **Automated Upstream Release Discovery**: Connects directly to Google's official release API and Google Cloud Storage bucket (`antigravity-public`) to check for updates and download packages automatically.
- **Automatic Package Provisioning**: Automatically pulls `Antigravity.tar.gz` from Google Cloud Storage if missing—no manual downloading needed.
- **Interactive & Headless Remote Control**: Automatically configures the machine hostname and remote access tokens in Antigravity's internal LevelDB/JSON storage.
- **On-Demand WSLg GUI Window**: Launch a temporary desktop window via Windows WSLg using `./setup_antigravity.sh gui`. Automatically manages the Electron single-instance lock and resumes headless mode upon exit.
- **Seamless Systemd Service**: Complete systemd user unit setup (`./setup_antigravity.sh service`) with autostart across system reboots.
- **Docker Compose Alternative**: Complete `Dockerfile` and `docker-compose.yml` for users who prefer container isolation.
- **Preserved OAuth & Sidecars**: Safe retention of Google OAuth session tokens (`jetski-standalone-oauth-token`), user rules, skills, plugins, and background automations.

---

## 📋 Prerequisites

- **Operating System**: Linux (Ubuntu 22.04+, Debian 12+, Fedora 38+) or **WSL2** (Windows 10 Build 19044+ or Windows 11).
- **Architecture**: `x86_64` (`amd64`).
- **Required Tools**: `bash`, `curl`, `tar`, `python3`, `sudo`.
- *(Optional for GUI inspection)*: WSLg on Windows 11 / Windows 10 for X11/Wayland desktop pass-through.

---

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/loofee55/antigravity2-headless.git
cd antigravity2-headless
```

### 2. Configure Environment
```bash
cp .env.example .env
```
*(The default configuration uses `$HOME` (`/home/user`). You can customize it if desired.)*

### 3. Install Antigravity
Run the automated installer. If `Antigravity.tar.gz` is not found locally, the script automatically fetches the latest release directly from Google Cloud Storage:
```bash
./setup_antigravity.sh install
```

### 4. Start the Headless Daemon
```bash
./setup_antigravity.sh start
```

### 5. Inspect Service Status
```bash
./setup_antigravity.sh status
```

---

## 🛠️ Command Line Interface (CLI)

The `setup_antigravity.sh` management script provides an intuitive, comprehensive set of subcommands:

```
Usage: ./setup_antigravity.sh <command>
```

### Command Reference

| Command | Description |
| :--- | :--- |
| `install` | Verifies system dependencies, downloads package if missing, extracts Antigravity to `/opt/antigravity`, and installs CLI Tab Completion (`ag-headless`). |
| `start` | Launches the headless Antigravity daemon in the background with auto-authentication and Remote Control enabled. |
| `stop` | Gracefully stops the running Antigravity daemon. |
| `restart` | Restarts the background daemon. |
| `status` | Displays running status, process PID, active Google account email, OAuth token auto-rotate health, and Remote Control hostname. |
| `accounts` | Lists all saved Google account profiles with live OAuth token expiry status and highlights the active account. |
| `account-status [email]` | Detailed health check per account: Plan/Credits, OAuth token validity, Auto-Rotate status, Quota summary, and Switch Readiness. |
| `switch-account [email]` | Pre-rotates OAuth token if expired and switches the active Google account (interactive menu if email omitted). |
| `login` | Authenticates with a new Google Account via terminal OAuth and saves it as a profile. |
| `quota [email] [--detail]` | Direct, fast quota and model limit inspection across accounts without opening Antigravity. |
| `remove-account <email>` | Removes a saved Google account profile. |
| `check-version` | Compares the currently installed version against the latest upstream release from Google. |
| `update` | Automatically downloads the latest version and performs an in-place upgrade without losing settings. |
| `download` | Downloads the latest `Antigravity.tar.gz` archive directly from official Google Cloud Storage. |
| `gui` | Opens a temporary visual window (via WSLg) on your Windows desktop. Resumes headless mode upon closing. |
| `auth` | Interactive terminal OAuth flow (alias for initial setup). |
| `remote-on [name]` | Enables Remote Control (supports custom hostname or system hostname). |
| `remote-off` | Disables Remote Control. |
| `service` | Registers and enables a native systemd user service for automated boot startup. |
| `completion [install]` | Installs intelligent `<TAB>` auto-completion for subcommands and saved account emails (Bash & Zsh). |
| `logs` | Streams live Antigravity Language Server logs (`language_server.log`). |

---

## 🌐 Remote Control Guide

Per the official [Google Antigravity Remote Control Documentation](https://antigravity.google/docs/remote-control/), Antigravity 2.0 features built-in **Remote Control**, allowing you to securely connect to and drive your headless instance **online from any web browser** (desktop, laptop, tablet, or smartphone) without needing any local client installation or port forwarding.

```
┌────────────────────────────────────────┐               ┌─────────────────────────────────┐
│  Any Web Browser / Mobile PWA          │               │   antigravity2-headless Host    │
│  https://antigravity.google.com        │               │   (Remote Server / WSL2)        │
│                                        │  Secure Cloud │                                 │
│  Instance Switcher:                    │  Relay / P2P  │   Headless App Daemon Active:   │
│  ● [ my-dev-server ] ──────────────────┼───────────────┼──► Remote Control: ON           │
│  Status: Connected                     │               │   Host: my-dev-server           │
└────────────────────────────────────────┘               └─────────────────────────────────┘
```

### Step 1: Enable Remote Control on Your Headless Host
1. Enable Remote Control (optionally specifying a custom machine nickname):
   ```bash
   ./setup_antigravity.sh remote-on my-dev-server
   ```
2. Start or restart the headless daemon:
   ```bash
   ./setup_antigravity.sh restart
   ```
3. Verify the status and assigned hostname:
   ```bash
   ./setup_antigravity.sh status
   ```
   *You will see `Remote Control: ENABLED (Host: my-dev-server)` and `Web Dashboard: https://antigravity.google.com`.*

### Step 2: Connect from Any Web Browser or Mobile Device
1. Open any web browser on your laptop, PC, tablet, or phone and navigate to the **[Antigravity Remote Control Dashboard (`https://antigravity.google.com`)](https://antigravity.google.com)**.
2. Sign in with the **same Google Account** authenticated on your headless host.
3. In the **instance switcher**, select your machine hostname (e.g. `my-dev-server`).
4. You now have full access to view active conversations, start new agent tasks, review implementation plans, and inspect artifacts in real time.

> 💡 **Mobile & Desktop PWA Tip:** On mobile devices (iOS/Android) or desktop browsers (Chrome/Edge), you can install `https://antigravity.google.com` to your home screen / desktop as a Web App (PWA) to receive **push notifications** when agents complete tasks or request input!

### Why `antigravity2-headless` (App Engine) vs. `agy remote-control` (CLI Daemon)?

Google provides two distinct Remote Control surfaces in `~/.gemini/config/config.json`:
- **Antigravity 2.0 App (`remoteControlHostname`)** — Powered by `antigravity2-headless`
- **Antigravity CLI (`cliRemoteControlHostname`)** — Powered by `agy remote-control start`

| Capability | `antigravity2-headless` (Full App Daemon) | `agy remote-control` (CLI Daemon) |
| :--- | :--- | :--- |
| **Remote Settings Control** | ✅ **Full Settings UI** configurable from browser | ❌ Settings locked in Web UI (must edit via CLI) |
| **Headless Browser (`/browser`)** | ✅ Supported via Headless Chrome (pre-installed in `Dockerfile`) | ⚠️ Terminal TUI surface only |
| **On-Demand Native GUI** | ✅ Instant WSLg / X11 GUI switch (`./setup_antigravity.sh gui`) | ❌ Terminal only |
| **Multi-Account Switcher** | ✅ 1-command account hot-swap (`./setup_antigravity.sh switch`) | ❌ Manual logout/re-login |
| **Fast Multi-Account Quota CLI** | ✅ Inspect all accounts' Gemini & Claude quotas (`quota`) | ❌ Not built-in |

---

## 👥 Multi-Account Management & Instant Switching

`antigravity2-headless` provides native multi-account profile management. You can store multiple Google accounts (e.g. personal, work, client accounts) and swap between them in seconds without re-authenticating every time.

### 1. View Saved Accounts & Live Token Status
```bash
./setup_antigravity.sh accounts
```
*Output:*
```text
==================== GOOGLE ACCOUNTS ====================
  * [1] developer@example.com (ACTIVE) [Token: VALID, expires in 53m]
    [2] work@example.com [Token: VALID, expires in 58m]
=========================================================
```

### 2. Inspect Detailed Health & Switch Readiness per Account
```bash
./setup_antigravity.sh account-status
# Or inspect a specific account by email or number:
./setup_antigravity.sh account-status work@example.com
```
*Output:*
```text
============================== GOOGLE ACCOUNT HEALTH & STATUS ==============================
[1] developer@example.com  [ACTIVE]
    • Plan & Credits   : Google AI Ultra
    • OAuth Token      : VALID (expires in 53m at 2026-10-21 21:08:17 +0700)
    • Auto-Rotate      : ENABLED (Refresh Token: OK | Permission: 0600)
    • Quota Summary    : Gemini [Weekly:  68.0% | 5h: 100.0%]  •  Claude/GPT [Weekly:  66.9% | 5h: 100.0%]
    • Switch Readiness : READY TO SWITCH & USE (All model families available)
--------------------------------------------------------------------------------------------
============================================================================================
```

### 3. Switch Accounts (Interactive or Direct with `<TAB>` Auto-Complete)
To switch interactively from a terminal menu:
```bash
./setup_antigravity.sh switch
```
Or switch directly by email (supports `<TAB>` auto-completion after running `install` or `./setup_antigravity.sh completion install`):
```bash
./setup_antigravity.sh switch work@example.com
```
*The script automatically pre-rotates the target account's OAuth token if expired, stops the daemon, swaps credentials, and restarts the daemon in under 2 seconds.*

### 4. Add a New Google Account
```bash
./setup_antigravity.sh login
```
Visit the printed Google OAuth authorization link in your browser, approve permissions, and the script will automatically resolve your email and save it as a new profile.

### 5. Log Out of Current Account
```bash
./setup_antigravity.sh logout
```
Stops the daemon and clears the active session token, while keeping saved account profiles intact in `~/.gemini/accounts/`. You can switch back or log into a new account at any time.

---

## 📊 Fast Quota & Credit Inspection

Inspect your real-time model quota, weekly request budgets, 5-hour throttles, and tier status across **all saved Google accounts** directly from your terminal in under 2 seconds—**without needing to launch or log into Antigravity**.

**Key highlights:**
- **Zero Antigravity launch overhead**: Direct query to Google's internal Cloud Code PA APIs (`cloudcode-pa.googleapis.com`) using stored tokens.
- **Automatic Silent Token Refresh**: If an account's OAuth token has expired, it is automatically and silently refreshed in the background without browser popups or user intervention.
- **Visual Progress Bars**: Displays remaining fractions as intuitive colored ASCII progress bars with relative countdowns until reset (`in 5d 8h`, `in 2h 10m`).
- **Granular Model Breakdown**: Use `--detail` to inspect individual model limits (Claude Opus/Sonnet, Gemini 2.5/3.x, GPT-OSS).

### Inspect All Accounts
```bash
./setup_antigravity.sh quota
```

*Sample Output:*
```text
============================== GOOGLE ACCOUNTS QUOTA STATUS ==============================
Account: developer@example.com (ACTIVE)  [Google AI Pro]  Available Credits: 18
  Plan Status: You can upgrade to a Google AI Ultra plan to receive higher rate limits.
  ▸ Gemini Models:
    • Weekly Limit Remaining    : [██████████░░░░░░]  60.5%  (Reset: in 5d 8h)
    • Five Hour Limit Remaining : [████████████████] 100.0%  (Reset: in 4h 59m)
  ▸ Claude and GPT models:
    • Weekly Limit Remaining    : [████████░░░░░░░░]  49.7%  (Reset: in 5d 8h)
    • Five Hour Limit Remaining : [████████████████] 100.0%  (Reset: in 4h 59m)
------------------------------------------------------------------------------------------
Account: work@example.com  [Google AI Ultra]
  Plan Status: You are subscribed to the best Google AI plan.
  ▸ Gemini Models:
    • Weekly Limit Remaining    : [████████░░░░░░░░]  52.0%  (Reset: in 6d 11h)
    • Five Hour Limit Remaining : [██░░░░░░░░░░░░░░]  12.4%  (Reset: in 2h 5m)
  ▸ Claude and GPT models:
    • Weekly Limit Remaining    : [████████████████] 100.0%  (Reset: in 6d 23h)
    • Five Hour Limit Remaining : [████████████████] 100.0%  (Reset: in 4h 59m)
------------------------------------------------------------------------------------------
==========================================================================================
```

### Inspect a Specific Account
```bash
./setup_antigravity.sh quota work@example.com
```

### Detailed Per-Model Breakdown
```bash
./setup_antigravity.sh quota --detail
```

---

## 🖥️ WSLg Graphical Window on Demand

When working on WSL2, you may occasionally want to open the graphical user interface for visual settings, browser OAuth confirmation, or manual configuration.

Running a separate instance usually conflicts with Electron's single-instance lock. The `gui` command solves this transparently:

```bash
./setup_antigravity.sh gui
```

### What happens behind the scenes:
1. Detects that the headless background daemon is running.
2. Temporarily pauses the headless daemon.
3. Sets `runInBackground: false` so closing the window cleanly exits Electron.
4. Launches the Antigravity window directly onto your Windows desktop via WSLg.
5. When you close the window or press `Ctrl + C` in your terminal, the script automatically resumes the background headless daemon.

---

## 🔄 Version Check & Auto-Updates

Antigravity upstream releases are published periodically by Google. You don't need to rebuild Docker images or manually check release notes:

### Check Version Status
```bash
./setup_antigravity.sh check-version
```
*Sample Output:*
```
==================== VERSION STATUS ====================
Installed version: 2.24.0
Latest available:  2.24.0
--------------------------------------------------------
Status: Up to date!
========================================================
```

### Perform In-Place Update
If a new version is available:
```bash
./setup_antigravity.sh update
```
The updater automatically:
- Stops the running daemon.
- Downloads the latest release archive from Google Cloud Storage.
- Unpacks the new binaries into `/opt/antigravity`.
- Restarts the headless daemon seamlessly.

---

## ⚙️ Systemd Autostart Service

To ensure Antigravity starts automatically whenever your server or WSL2 machine boots:

```bash
./setup_antigravity.sh service
```

This creates and enables a user-level service at `~/.config/systemd/user/antigravity.service`.

### Manage the Service:
```bash
# Start service
systemctl --user start antigravity

# Stop service
systemctl --user stop antigravity

# View status
systemctl --user status antigravity

# Follow service logs
journalctl --user -u antigravity -f
```

> [!TIP]
> To allow user services to run even when you are not logged in via SSH, enable lingering:
> ```bash
> sudo loginctl enable-linger $USER
> ```

---

## 🐳 Docker / Container Deployment

If you prefer to run Antigravity inside a self-contained Docker container rather than directly on the host:

### 1. Build and Start Container
```bash
docker compose up -d --build
```

### 2. View Logs
```bash
docker compose logs -f
```

### 3. Stop Container
```bash
docker compose down
```

The container runs as a non-root user (`user`, UID/GID 1000) and mounts:
- `${HOST_CONFIG_PATH}` to `/home/user` (preserves OAuth credentials, settings, and sidecars).
- `${HOST_WORK_PATH}` to `/opt/work` (your workspaces and code repositories).

---

## ⚙️ Configuration Reference (`.env`)

Configure settings in `.env`:

```bash
# Primary configuration directory for session data and tokens
# Standard Linux location: /home/user or dedicated data directory (e.g. /opt/antigravity-data)
ANTIGRAVITY_HOME=/home/user

# Target directory where binaries are unpacked
ANTIGRAVITY_INSTALL_DIR=/opt/antigravity

# Archive file name
ANTIGRAVITY_TAR_FILE=Antigravity.tar.gz

# Display mode ('headless' for background daemon, empty or 'x11' for GUI)
ELECTRON_OZONE_PLATFORM_HINT=headless

# System timezone
TZ=Asia/Ho_Chi_Minh

# Docker Compose Host Volume Mounts
HOST_CONFIG_PATH=/home/user
HOST_WORK_PATH=/opt/work
CONTAINER_UID_GID=1000:1000
```

---

## 📁 Directory Structure

```
antigravity2-headless/
├── .env                  # Active environment variables (git-ignored)
├── .env.example          # Sample environment template
├── .gitignore            # Git ignore rules (excludes archives, logs, env)
├── .dockerignore         # Docker build ignore rules
├── Dockerfile            # Minimal Ubuntu 24.04 runtime container
├── docker-compose.yml    # Compose specification for containerized runs
├── setup_antigravity.sh  # Master CLI management script
├── README.md             # Project documentation (English)
└── README.vi.md          # Project documentation (Vietnamese / Tiếng Việt)
```

---

## ❓ Troubleshooting & FAQ

### Q: Does this require an active X11 server or virtual display like Xvfb?
**No.** By setting `ELECTRON_OZONE_PLATFORM_HINT=headless`, Electron bypasses the display server entirely while keeping the background network, Language Server, and Remote Control active.

### Q: Where are my Google credentials stored?
Credentials and OAuth tokens are stored in SQLite and JSON databases inside `$ANTIGRAVITY_HOME/.config/Antigravity/` and `$ANTIGRAVITY_HOME/.gemini/` (defaults to `~/.gemini` and `~/.config/Antigravity`).

### Q: Why do I see a warning about single-instance lock when launching GUI?
Electron allows only one instance of an application using the same data directory. The `./setup_antigravity.sh gui` command automatically pauses the headless daemon, starts the GUI, and resumes the headless daemon when you exit.

### Q: How do I change the Remote Control hostname?
Run:
```bash
./setup_antigravity.sh remote-on [hostname]
```
*(e.g. `./setup_antigravity.sh remote-on my-server` or omit to auto-detect system hostname).*

---

## 📄 License

This project is licensed under the [MIT License](LICENSE). Antigravity is a product developed by Google. This project is an independent community toolkit designed to streamline its headless operation.
