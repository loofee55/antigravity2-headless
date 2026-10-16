# Antigravity 2.0 Headless (`antigravity2-headless`)

> 🌐 **Ngôn ngữ / Language:** [🇬🇧 English](README.md) | **🇻🇳 Tiếng Việt**

[![Platform: Linux / WSL2](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL2-blue.svg)](https://ubuntu.com/)
[![Runtime: Headless Electron](https://img.shields.io/badge/Runtime-Electron%20Ozone%20Headless-success.svg)](https://electronjs.org)
[![Antigravity: 2.0+](https://img.shields.io/badge/Antigravity-2.0%2B-orange.svg)](https://antigravity.google)
[![Headless Shell: ~180MB PSS](https://img.shields.io/badge/Headless_Shell-~180MB_PSS_(No_VNC_Bloat)-brightgreen?logo=speedtest)](https://github.com/loofee55/antigravity2-headless)
[![Security Audit: 100% Passed](https://img.shields.io/badge/Security_Audit-Trivy_%7C_GitLeaks_%7C_ShellCheck-blueviolet?logo=shield)](https://github.com/loofee55/antigravity2-headless)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready%20%7C%20Compose-2496ED?logo=docker&logoColor=white)](docker-compose.yml)
[![Multi-Account: Supported](https://img.shields.io/badge/Multi--Account-Gemini_%26_Claude-FF6F00?logo=google)](https://github.com/loofee55/antigravity2-headless)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Bộ công cụ quản lý hiệu năng cao, siêu nhẹ, chuẩn Production giúp vận hành **Google Antigravity 2.0** dưới dạng tiến trình nền không giao diện (Native Headless Background Daemon) trên **máy chủ Linux (VPS, Dedicated, Homelab)**, **Windows Subsystem for Linux (WSL2)** và **Docker**.

Loại bỏ hoàn toàn gánh nặng của các container giả lập màn hình Desktop cồng kềnh (Webtop, KasmVNC, X11, XFCE), đồng thời cung cấp kết nối **Remote Control 24/7** qua trình duyệt web tại [`https://antigravity.google.com`](https://antigravity.google.com), tự động tải và cập nhật bản phát hành mới nhất từ Google Cloud, quản lý chuyển đổi nóng đa tài khoản (Multi-Account Switcher), tra cứu Quota thời gian thực trên Terminal, bật tắt cửa sổ GUI WSLg theo yêu cầu và tích hợp Systemd khởi động cùng hệ thống.

---

## 📑 Mục lục

- [Tại sao nên dùng Antigravity 2.0 Headless?](#-tại-sao-nên-dùng-antigravity-20-headless)
- [So sánh Kiến trúc & Hiệu năng](#-so-sánh-kiến-trúc--hiệu-năng)
- [Tính năng Nổi bật](#-tính-năng-nổi-bật)
- [Yêu cầu Hệ thống](#-yêu-cầu-hệ-thống)
- [Bắt đầu Nhanh (Quick Start)](#-bắt-đầu-nhanh-quick-start)
- [Giao diện Dòng lệnh (CLI Reference)](#-giao-diện-dòng-lệnh-cli-reference)
- [Hướng dẫn Điều khiển Từ xa (Remote Control Online)](#-hướng-dẫn-điều-khiển-từ-xa-remote-control-online)
- [Quản lý Đa tài khoản & Chuyển đổi Tức thì](#-quản-lý-đa-tài-khoản--chuyển-đổi-tức-thì)
- [Kiểm tra Nhanh Quota & Hạn mức Model](#-kiểm-tra-nhanh-quota--hạn-mức-model)
- [Mở Cửa sổ Đồ họa GUI theo Yêu cầu (WSLg)](#-mở-cửa-sổ-đồ-họa-gui-theo-yêu-cầu-wslg)
- [Kiểm tra Phiên bản & Tự động Cập nhật](#-kiểm-tra-phiên-bản--tự-động-cập-nhật)
- [Dịch vụ Tự khởi động Systemd](#-dịch-vụ-tự-khởi-động-systemd)
- [Triển khai bằng Docker / Container](#-triển-khai-bằng-docker--container)
- [Tham chiếu Cấu hình (`.env`)](#-tham-chiếu-cấu-hình-env)
- [Cấu trúc Thư mục](#-cấu-trúc-thư-mục)
- [Xử lý Sự cố & Câu hỏi Thường gặp (FAQ)](#-xử-lý-sự-cố--câu-hỏi-thường-gặp-faq)
- [Giấy phép (License)](#-giấy-phép-license)

---

## 💡 Tại sao nên dùng Antigravity 2.0 Headless?

Google Antigravity 2.0 được phân phối dưới dạng ứng dụng Desktop Electron. Thông thường, để chạy Antigravity 24/7 trên máy chủ Linux từ xa (VPS) hoặc môi trường WSL2 không màn hình, người dùng phải sử dụng các giải pháp cồng kềnh:
- Cài đặt nguyên môi trường Desktop (XFCE, GNOME, KDE) kèm máy chủ VNC/RDP (KasmVNC, Xrdp, Webtop).
- Tiêu tốn lượng bộ nhớ khổng lồ (từ **1.5 GB đến hơn 3 GB RAM** chỉ để nuôi trình quản lý cửa sổ, X11 server và truyền phát video qua trình duyệt).
- Gặp hiện tượng trễ hình ảnh (streaming lag) và ngốn CPU liên tục.

**`antigravity2-headless`** giải quyết triệt để vấn đề này bằng cách kích hoạt tầng trừu tượng hóa nền tảng Headless Ozone nguyên bản của Chromium/Electron (`ELECTRON_OZONE_PLATFORM_HINT=headless` kết hợp `--use-gl=disabled`). Thay vì tốn hàng GB RAM cho màn hình ảo Desktop và bộ mã hóa video VNC, phần **vỏ ứng dụng Electron Headless chỉ tiêu thụ ~150–180 MB RAM (PSS)**, trong khi tiến trình lõi `language_server` co giãn tự nhiên tùy theo quy mô dự án và khối lượng tác vụ Agent thực tế của mỗi người dùng. Hệ thống giữ trọn vẹn các tính năng thiết yếu: kết nối **Remote Control 24/7** qua [`https://antigravity.google.com`](https://antigravity.google.com), thực thi **AI Agent & tác vụ hẹn giờ (Scheduled Tasks)**, mở cửa sổ **GUI WSLg theo yêu cầu**, cùng bộ CLI quản lý **đa tài khoản, tra cứu Quota và tự động cập nhật**.

---

## ⚡ So sánh Kiến trúc & Hiệu năng

```
Cách truyền thống (Webtop / KasmVNC)            antigravity2-headless
┌──────────────────────────────────────┐        ┌──────────────────────────────────────┐
│  Trình duyệt (Stream Video VNC)      │        │  Web / Mobile PWA                    │
│                                      │        │  (https://antigravity.google.com)    │
└──────────────────▲───────────────────┘        └──────────────────▲───────────────────┘
                   │ Độ trễ cao (VNC)                              │ Native Cloud Relay / gRPC
┌──────────────────▼───────────────────┐        ┌──────────▼───────────────────────────┐
│  KasmVNC / X11 / XFCE Desktop Env    │        │  Antigravity 2.0 Headless Daemon     │
│  (Tầng Desktop: ~1.5 GB - 3 GB RAM)  │        │  (Vỏ Shell: ~150-180 MB PSS, 0 VNC)  │
└──────────────────▲───────────────────┘        └──────────────────▲───────────────────┘
                   │                                               │
┌──────────────────▼───────────────────┐        ┌──────────────────▼───────────────────┐
│  Antigravity App + Language Server   │        │  Linux Host / WSL2 Kernel            │
└──────────────────────────────────────┘        └──────────────────────────────────────┘
```

| Chỉ số / Tính năng | Container Desktop Truyền thống (Webtop) | `antigravity2-headless` (Native Daemon) |
| :--- | :--- | :--- |
| **RAM tầng Hiển thị & Vỏ Shell** | ~1,500 MB – 3,000 MB+ RAM (XFCE + X11 + VNC) | **~150 MB – 180 MB RAM (PSS)** (0 MB VNC/Desktop ảo) |
| **RAM tiến trình Language Server** | Tùy thuộc quy mô dự án & số tác vụ Agent | **Tương đương** (Co giãn tự nhiên theo dự án & tác vụ của bạn) |
| **Thời gian khởi động** | 25 – 45 giây | **< 1.5 giây** |
| **Yêu cầu Display Server** | Có (X11 / Xvfb / KasmVNC) | **Không** (Native Electron Headless Ozone) |
| **Độ trễ điều khiển** | Trễ do nén và truyền tải video mạng | **Bằng 0** (Đồng bộ trạng thái gốc qua Web Dashboard) |
| **Cơ chế cập nhật** | Phải build lại Docker image hàng chục GB | **1 lệnh duy nhất:** `./setup_antigravity.sh update` |
| **Hỗ trợ cửa sổ GUI WSLg** | Xem qua khung VNC giật cục | **Bật cửa sổ Windows mượt mà ngay khi cần** |
| **Lưu trữ phiên làm việc** | Dễ mất khi xóa container | **Lưu trữ trực tiếp trên Host (`$HOME` / `~/.gemini`)** |

---

## ✨ Tính năng Nổi bật

- **Daemon Headless Không Cần Màn Hình**: Chạy Antigravity 2.0 trực tiếp không cần Xvfb hay trình quản lý cửa sổ Desktop.
- **Tự Động Tải & Cập Nhật Chính Hãng**: Kết nối trực tiếp tới API phát hành của Google và Google Cloud Storage (`antigravity-public`) để kiểm tra phiên bản mới và tải gói cài đặt tự động.
- **Cài Đặt Tự Động Từ A–Z**: Tự động kiểm tra các thư viện hệ thống cần thiết và tải gói `Antigravity.tar.gz` nếu trên máy chưa có sẵn.
- **Remote Control Online 24/7**: Tự động cấu hình hostname và kết nối máy chủ lên bảng điều khiển trực tuyến [`https://antigravity.google.com`](https://antigravity.google.com).
- **Quản Lý Đa Tài Khoản & Kiểm Tra Quota Nhanh**: Lưu trữ nhiều hồ sơ tài khoản Google, chuyển đổi nóng chỉ trong 1 giây và kiểm tra hạn mức Quota (Gemini 2.5/3.x, Claude Opus/Sonnet, GPT) trực tiếp trên Terminal mà không cần mở giao diện.
- **Mở Cửa Sổ GUI Theo Yêu Cầu (WSLg)**: Chạy `./setup_antigravity.sh gui` để mở cửa sổ đồ họa trực tiếp trên màn hình Windows (qua WSLg); tự động tạm dừng và khôi phục headless daemon khi đóng cửa sổ.
- **Tích Hợp Dịch Vụ Systemd**: Cài đặt user service (`./setup_antigravity.sh service`) để tự động chạy ngầm ngay khi máy chủ khởi động.
- **Hỗ Trợ Docker Compose**: Đi kèm `Dockerfile` (đạt 100% chuẩn bảo mật Aqua Trivy) và `docker-compose.yml` cho môi trường container cô lập.
- **Đã Kiểm Định Bảo Mật (100% Passed)**: Mã nguồn được kiểm định nghiêm ngặt với **ShellCheck**, **GitLeaks** và **Aqua Trivy** (chống Code Injection, Path Traversal, khóa quyền `0600` trên mọi file token).

---

## 📋 Yêu cầu Hệ thống

- **Hệ điều hành**: Linux (Ubuntu 22.04+, Debian 12+, Fedora 38+) hoặc **WSL2** (Windows 10 Build 19044+ hoặc Windows 11).
- **Kiến trúc CPU**: `x86_64` (`amd64`).
- **Công cụ cơ bản**: `bash`, `curl`, `tar`, `python3`, `sudo` (tự động nhận diện nếu chạy dưới quyền `root`).
- *(Tùy chọn cho chế độ GUI)*: WSLg trên Windows 11 / Windows 10 hoặc X11/Wayland trên Linux Desktop.

---

## 🚀 Bắt đầu Nhanh (Quick Start)

### 1. Clone Repository
```bash
git clone https://github.com/loofee55/antigravity2-headless.git
cd antigravity2-headless
```

### 2. Khởi tạo File Cấu hình Môi trường
```bash
cp .env.example .env
```
*(Mặc định hệ thống sử dụng thư mục `$HOME` hiện tại của bạn. Bạn có thể tùy chỉnh trong `.env` nếu muốn).*

### 3. Cài đặt Antigravity
Chạy lệnh cài đặt tự động. Nếu chưa có file `Antigravity.tar.gz`, script sẽ tự động tải bản mới nhất từ Google Cloud Storage:
```bash
./setup_antigravity.sh install
```

### 4. Đăng nhập Tài khoản Google & Bật Remote Control
```bash
# Đăng nhập tài khoản Google qua Terminal (mở URL trên trình duyệt bất kỳ và dán mã xác thực)
./setup_antigravity.sh login

# Bật tính năng điều khiển từ xa (có thể đặt tên máy tùy ý)
./setup_antigravity.sh remote-on my-dev-server
```

### 5. Khởi chạy Headless Daemon & Kiểm tra Trạng thái
```bash
./setup_antigravity.sh start
./setup_antigravity.sh status
```

---

## 🛠️ Giao diện Dòng lệnh (CLI Reference)

Kịch bản `setup_antigravity.sh` cung cấp đầy đủ các lệnh quản trị vòng đời ứng dụng:

```bash
Usage: ./setup_antigravity.sh <command>
```

### Bảng Tham Chiếu Lệnh

| Lệnh | Mô tả chức năng |
| :--- | :--- |
| `install` | Cài đặt thư viện hệ thống, tự động tải gói cài đặt (nếu thiếu), giải nén vào `/opt/antigravity` và cài đặt Tab Completion (`ag-headless`). |
| `start` | Khởi chạy Antigravity Headless Daemon chạy ngầm (tự động kiểm tra/xoay vòng OAuth token và bật Remote Control). |
| `stop` | Dừng tiến trình Antigravity Daemon một cách an toàn. |
| `restart` | Khởi động lại tiến trình chạy ngầm. |
| `status [--ps]` | Hiển thị trạng thái Daemon, PID, Uptime, tài khoản Google, hạn OAuth Token Auto-Rotate, Hostname Remote Control và link Web Dashboard. |
| `accounts` | Liệt kê tất cả các tài khoản Google đã lưu kèm trạng thái hạn OAuth Token trực tiếp và đánh dấu tài khoản `ACTIVE`. |
| `account-status [email\|số]` | Kiểm tra chi tiết sức khỏe từng tài khoản: Gói cước/Credits, hạn OAuth Token, Auto-Rotate, tóm tắt Quota và độ sẵn sàng chuyển đổi (`Switch Readiness`). |
| `switch-account [email\|số]` | Tự động làm mới OAuth token (nếu hết hạn) và chuyển đổi tức thì sang tài khoản Google khác (hiển thị menu chọn nếu bỏ trống tham số). |
| `login` | Đăng nhập thêm tài khoản Google mới qua Terminal OAuth và tự động lưu vào danh sách hồ sơ. |
| `logout` | Đăng xuất khỏi tài khoản hiện tại và dừng daemon (vẫn giữ nguyên các hồ sơ đã lưu trong `~/.gemini/accounts/`). |
| `quota [email] [--detail]` | Kiểm tra nhanh phần trăm Quota, gói cước (`Pro`/`Ultra`/`Free`) và thời gian reset của các tài khoản (thêm `--detail` để xem chi tiết từng model). |
| `remove-account <email>` | Xóa một hồ sơ tài khoản Google đã lưu. |
| `check-version` | So sánh phiên bản đang cài trên máy với phiên bản mới nhất trên máy chủ Google. |
| `update` | Tự động tải phiên bản mới nhất và nâng cấp tại chỗ (in-place upgrade) không làm mất cấu hình. |
| `download` | Tải gói `Antigravity.tar.gz` chính thức mới nhất từ Google Cloud Storage. |
| `gui` | Mở cửa sổ đồ họa trực tiếp (qua WSLg / X11). Tự động quay lại chế độ chạy ngầm headless khi đóng cửa sổ. |
| `remote-on [tên-máy]` | Bật Remote Control (hỗ trợ đặt tên máy tùy chỉnh hoặc tự lấy hostname hệ thống). |
| `remote-off` | Tắt tính năng Remote Control. |
| `service` | Đăng ký và kích hoạt dịch vụ `systemd` để tự động chạy ngầm khi khởi động máy. |
| `completion [install]` | Cài đặt tính năng nhấn phím `<TAB>` tự động gợi ý lệnh và email tài khoản cho Bash & Zsh. |
| `logs` | Xem trực tiếp luồng log thời gian thực của Language Server (`language_server.log`). |

---

## 🌐 Hướng dẫn Điều khiển Từ xa (Remote Control Online)

Theo [Tài liệu Chính thức về Google Antigravity Remote Control](https://antigravity.google/docs/remote-control/), Antigravity 2.0 tích hợp sẵn tính năng **Remote Control**, cho phép bạn kết nối bảo mật và điều khiển máy chủ headless này **trực tuyến từ bất kỳ trình duyệt web nào** (máy tính bàn, laptop, máy tính bảng iPad/Android, hoặc điện thoại thông minh) mà không cần mở port hay cài đặt phần mềm client.

```
┌────────────────────────────────────────┐               ┌─────────────────────────────────┐
│  Trình duyệt Web / Mobile PWA          │               │   antigravity2-headless Host    │
│  https://antigravity.google.com        │               │   (Remote Linux Server / WSL2)  │
│                                        │  Kết nối Đám  │                                 │
│  Bộ chọn máy (Instance Switcher):      │  mây Bảo mật  │   Headless App Daemon Đang Chạy:│
│  ● [ my-dev-server ] ──────────────────┼───────────────┼──► Remote Control: ON           │
│  Trạng thái: Đã kết nối                │               │   Host: my-dev-server           │
└────────────────────────────────────────┘               └─────────────────────────────────┘
```

### Bước 1: Bật Remote Control trên Máy chủ Headless
1. Kích hoạt Remote Control (có thể đặt biệt danh dễ nhớ cho máy chủ):
   ```bash
   ./setup_antigravity.sh remote-on my-dev-server
   ```
2. Khởi động hoặc khởi động lại daemon để áp dụng:
   ```bash
   ./setup_antigravity.sh restart
   ```
3. Kiểm tra trạng thái hoạt động:
   ```bash
   ./setup_antigravity.sh status
   ```
   *Kết quả hiển thị:*
   ```text
   ==================== ANTIGRAVITY STATUS ====================
   Daemon Status:           RUNNING (PID: 2142770, Uptime: 06:36:12)
   Language Server:         ACTIVE (PID: 2142858)
   Google Auth:             AUTHENTICATED (developer@example.com)
   Remote Control:          ENABLED (Host: my-dev-server)
   Web Dashboard:           https://antigravity.google.com
   Data directory (HOME):   /home/user
   Language Server Log:     /home/user/.config/Antigravity/logs/language_server.log
   ============================================================
   ```

### Bước 2: Truy cập Online từ Trình duyệt Web hoặc Điện thoại
1. Mở trình duyệt web bất kỳ trên laptop, PC, máy tính bảng hoặc điện thoại và truy cập vào **[Antigravity Remote Control Dashboard (`https://antigravity.google.com`)](https://antigravity.google.com)**.
2. Đăng nhập bằng **cùng tài khoản Google** đang xác thực trên máy chủ headless.
3. Tại menu chuyển đổi máy (**Instance Switcher**), chọn tên máy chủ của bạn (ví dụ: `my-dev-server`).
4. Ngay lập tức, toàn bộ giao diện Antigravity 2.0 sẽ hiển thị trên trình duyệt: bạn có thể xem các cuộc hội thoại đang chạy, giao việc mới cho Agent, duyệt kế hoạch (Implementation Plan), xem Artifacts và chạy lệnh terminal theo thời gian thực!

> 💡 **Mẹo cài đặt Web App (PWA) trên Điện thoại & Máy tính:** Trên thiết bị di động (iOS/Android) hoặc trình duyệt Chrome/Edge máy tính, bạn có thể chọn **"Thêm vào màn hình chính" (Install App / Add to Home Screen)** tại trang `https://antigravity.google.com` để nhận **thông báo đẩy (Push Notifications)** ngay khi Agent hoàn thành tác vụ dài hoặc cần bạn phê duyệt!

### Sự khác biệt giữa `antigravity2-headless` (App Engine) và `agy remote-control` (CLI Daemon)

Trong tệp `~/.gemini/config/config.json`, Google phân chia 2 chế độ Remote Control riêng biệt:
- **Antigravity 2.0 App (`remoteControlHostname`)** — Được vận hành bởi `antigravity2-headless`.
- **Antigravity CLI (`cliRemoteControlHostname`)** — Được vận hành bởi lệnh `agy remote-control start` của bản CLI.

| Tính năng | `antigravity2-headless` (Full App Daemon) | `agy remote-control` (CLI Daemon) |
| :--- | :--- | :--- |
| **Chỉnh Settings từ Web UI** | ✅ **Mở khóa 100% bảng Settings** ngay trên trình duyệt | ❌ Bị khóa trên Web UI (bắt buộc phải sửa từ CLI) |
| **Trình duyệt Tự động (`/browser`)** | ✅ Hỗ trợ qua Headless Chrome (tích hợp sẵn trong `Dockerfile`) | ⚠️ Chỉ giới hạn ở bề mặt Terminal TUI |
| **Mở cửa sổ GUI khi cần** | ✅ Bật cửa sổ GUI WSLg / X11 tức thì (`./setup_antigravity.sh gui`) | ❌ Chỉ có dòng lệnh |
| **Chuyển đổi Đa tài khoản** | ✅ Chuyển đổi nóng bằng 1 lệnh (`./setup_antigravity.sh switch`) | ❌ Phải đăng xuất / đăng nhập thủ công |
| **Kiểm tra Quota Đa tài khoản** | ✅ Xem biểu đồ Quota Gemini & Claude của mọi tài khoản (`quota`) | ❌ Không hỗ trợ sẵn |

---

## 👥 Quản lý Đa tài khoản & Chuyển đổi Tức thì

`antigravity2-headless` tích hợp sẵn bộ quản lý nhiều hồ sơ tài khoản Google (Multi-Account Profile Manager). Bạn có thể đăng nhập sẵn nhiều tài khoản (cá nhân, công việc, dự án) và chuyển đổi qua lại chỉ trong chưa đầy 2 giây mà không cần phải xác thực lại từ đầu.

### 1. Xem Danh sách Tài khoản & Hạn Token Trực tiếp
```bash
./setup_antigravity.sh accounts
```
*Kết quả mẫu:*
```text
==================== GOOGLE ACCOUNTS ====================
  * [1] developer@example.com (ACTIVE) [Token: VALID, expires in 53m]
    [2] work@example.com [Token: VALID, expires in 58m]
=========================================================
```

### 2. Kiểm tra Chi tiết Sức khỏe & Độ sẵn sàng từng Tài khoản (`account-status`)
```bash
./setup_antigravity.sh account-status
# Hoặc kiểm tra riêng 1 tài khoản theo số thứ tự / email:
./setup_antigravity.sh account-status work@example.com
```
*Kết quả mẫu:*
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

### 3. Chuyển đổi Tài khoản (Qua Menu hoặc Gõ `<TAB>` Tự động Gợi ý)
Mở menu chọn tài khoản tương tác theo số thứ tự:
```bash
./setup_antigravity.sh switch
```
Hoặc chuyển trực tiếp bằng số thứ tự / địa chỉ email (hỗ trợ nhấn phím `<TAB>` tự động điền lệnh và email sau khi chạy `install` hoặc `./setup_antigravity.sh completion install`):
```bash
./setup_antigravity.sh switch 2
# hoặc
./setup_antigravity.sh switch work@example.com
```
*Script sẽ tự động kiểm tra và làm mới OAuth token của tài khoản đích (nếu hết hạn), dừng daemon, hoán đổi OAuth token bảo mật (`chmod 600`) và khởi động lại daemon với tài khoản mới trong chưa đầy 2 giây.*

### 4. Thêm Tài khoản Google Mới
```bash
./setup_antigravity.sh login
```
Mở đường dẫn Google OAuth in trên màn hình bằng trình duyệt bất kỳ, cấp quyền, dán mã xác thực vào terminal. Script sẽ tự động lấy địa chỉ email, lưu thành hồ sơ riêng và khởi chạy lại daemon.

### 5. Đăng xuất Tài khoản Hiện tại
```bash
./setup_antigravity.sh logout
```
Dừng daemon và gỡ phiên làm việc hiện tại nhưng vẫn bảo toàn các hồ sơ đã lưu trong `~/.gemini/accounts/` để bạn chuyển lại bất cứ lúc nào.

---

## 📊 Kiểm tra Nhanh Quota & Hạn mức Model

Tra cứu trực tiếp hạn mức sử dụng (Quota), ngân sách tuần (Weekly Limit), hạn mức 5 giờ (Five-Hour Limit), số lượng Credits và gói dịch vụ (`Free Tier`, `Google AI Pro`, `Google AI Ultra`) của **tất cả các tài khoản đã lưu** ngay trên Terminal chỉ trong 1–2 giây — **không cần mở giao diện Antigravity**.

**Điểm nổi bật:**
- **Không tốn tài nguyên khởi chạy UI**: Truy vấn trực tiếp tới API của Google Cloud Code kết hợp với Language Server cục bộ.
- **Tự động làm mới Token ngầm (Silent Token Refresh)**: Nếu OAuth token của tài khoản nào đã hết hạn (sau 1 giờ), script tự động dùng `refresh_token` để lấy `access_token` mới trong nền mà không cần đăng nhập lại.
- **Thanh tiến trình trực quan**: Hiển thị phần trăm còn lại kèm màu sắc cảnh báo (Xanh / Vàng / Đỏ) và đồng hồ đếm ngược thời điểm reset (`in 5d 8h`, `in 2h 10m`).
- **Chi tiết tới từng Model (`--detail`)**: Xem hạn mức riêng của từng dòng model Claude Opus/Sonnet, Gemini 2.5/3.x, GPT-OSS.

### Kiểm tra Tất cả Tài khoản
```bash
./setup_antigravity.sh quota
```

*Kết quả mẫu:*
```text
============================== GOOGLE ACCOUNTS QUOTA STATUS ==============================
Account: developer@example.com (ACTIVE)  [Google AI Pro]  Available Credits: 18
  Plan Status: You can upgrade to a Google AI Ultra plan to receive higher rate limits.
  ▸ Gemini Models:
    • Weekly Limit Remaining      : [██████████░░░░░░]  60.5%  (Reset: in 5d 8h)
    • Five Hour Limit Remaining   : [████████████████] 100.0%  (Reset: in 4h 59m)
  ▸ Claude and GPT models:
    • Weekly Limit Remaining      : [████████░░░░░░░░]  49.7%  (Reset: in 5d 8h)
    • Five Hour Limit Remaining   : [████████████████] 100.0%  (Reset: in 4h 59m)
------------------------------------------------------------------------------------------
Account: work@example.com  [Google AI Ultra]
  Plan Status: You are subscribed to the best Google AI plan.
  ▸ Gemini Models:
    • Weekly Limit Remaining      : [███████████░░░░░]  68.0%  (Reset: in 4d 17h)
    • Five Hour Limit Remaining   : [██████████████░░]  84.5%  (Reset: in 1h 32m)
  ▸ Claude and GPT models:
    • Weekly Limit Remaining      : [███████████░░░░░]  66.9%  (Reset: in 5d 22h)
    • Five Hour Limit Remaining   : [████████████████] 100.0%  (Reset: in 4h 47m)
------------------------------------------------------------------------------------------
==========================================================================================
```

### Kiểm tra Một Tài khoản Cụ thể kèm Chi tiết Từng Model
```bash
./setup_antigravity.sh quota work@example.com --detail
```

---

## 🖥️ Mở Cửa sổ Đồ họa GUI theo Yêu cầu (WSLg)

Khi sử dụng trên WSL2 (Windows 10/11) hoặc Linux có màn hình, đôi khi bạn muốn mở trực tiếp cửa sổ đồ họa của Antigravity ngay trên máy.

Thông thường, việc mở thêm một tiến trình mới sẽ bị chặn bởi khóa đơn phiên bản (single-instance lock) của Electron. Lệnh `gui` xử lý tự động toàn bộ quy trình này:

```bash
./setup_antigravity.sh gui
```

### Quy trình tự động diễn ra phía sau:
1. Phát hiện tiến trình headless daemon đang chạy ngầm và tạm dừng an toàn để nhường khóa hiển thị.
2. Thiết lập `runInBackground: false` để khi bạn đóng cửa sổ, ứng dụng sẽ thoát sạch.
3. Mở cửa sổ đồ họa Antigravity trực tiếp lên màn hình Windows của bạn thông qua WSLg.
4. Ngay khi bạn đóng cửa sổ GUI (hoặc nhấn `Ctrl + C` trên terminal), script **tự động khởi chạy lại chế độ chạy ngầm headless** để giữ kết nối Remote Control không bị gián đoạn.

---

## 🔄 Kiểm tra Phiên bản & Tự động Cập nhật

Google phát hành các bản cập nhật Antigravity thường xuyên. Bạn không cần phải tải thủ công hay build lại image phức tạp:

### Kiểm tra Phiên bản Hiện tại
```bash
./setup_antigravity.sh check-version
```
*Kết quả mẫu:*
```text
==================== VERSION STATUS ====================
Installed version: 2.24.0
Latest available:  2.24.0
--------------------------------------------------------
Status: Up to date!
========================================================
```

### Nâng cấp Tự động (In-Place Update)
Khi có phiên bản mới:
```bash
./setup_antigravity.sh update
```
Script sẽ tự động:
- Tạm dừng daemon đang chạy.
- Tải gói phát hành chính thức mới nhất từ Google Cloud Storage.
- Giải nén và cập nhật mã nguồn vào `/opt/antigravity`.
- Khởi động lại headless daemon với nguyên vẹn toàn bộ cấu hình và tài khoản của bạn.

---

## ⚙️ Dịch vụ Tự khởi động Systemd

Để Antigravity tự động chạy ngầm mỗi khi máy chủ Linux hoặc WSL2 khởi động:

```bash
./setup_antigravity.sh service
```

Lệnh này tạo và kích hoạt dịch vụ systemd cấp người dùng tại `~/.config/systemd/user/antigravity.service`.

### Các lệnh quản lý dịch vụ Systemd:
```bash
# Khởi chạy dịch vụ
systemctl --user start antigravity

# Dừng dịch vụ
systemctl --user stop antigravity

# Kiểm tra trạng thái dịch vụ
systemctl --user status antigravity

# Xem log trực tiếp
journalctl --user -u antigravity -f
```

> [!TIP]
> Trên máy chủ Linux (VPS), để dịch vụ người dùng tự chạy ngay cả khi bạn đã thoát phiên SSH, hãy bật chế độ `linger`:
> ```bash
> sudo loginctl enable-linger $USER
> ```

---

## 🐳 Triển khai bằng Docker / Container

Nếu bạn muốn chạy Antigravity bên trong một Docker container cô lập hoàn toàn với hệ điều hành máy chủ:

### 1. Build và Khởi chạy Container
```bash
docker compose up -d --build
```

### 2. Theo dõi Logs
```bash
docker compose logs -f
```

### 3. Dừng Container
```bash
docker compose down
```

Container được thiết kế chạy dưới quyền người dùng không phải root (`user`, UID/GID `1000`), tích hợp sẵn `HEALTHCHECK` tự động và ánh xạ (mount) dữ liệu bền vững:
- `${HOST_CONFIG_PATH}` vào `/home/user` (lưu giữ vĩnh viễn OAuth token, danh sách tài khoản, cấu hình, skills và plugins).
- `${HOST_WORK_PATH}` vào `/opt/work` (thư mục chứa source code và dự án của bạn).

---

## ⚙️ Tham chiếu Cấu hình (`.env`)

Tùy chỉnh các biến môi trường trong tệp `.env`:

```bash
# Thư mục gốc lưu trữ cấu hình, phiên đăng nhập và OAuth token
# Mặc định sử dụng $HOME hiện tại (ví dụ: /home/user)
ANTIGRAVITY_HOME=/home/user

# Thư mục cài đặt bộ thực thi Antigravity
ANTIGRAVITY_INSTALL_DIR=/opt/antigravity

# Tên tệp nén gói cài đặt
ANTIGRAVITY_TAR_FILE=Antigravity.tar.gz

# Chế độ hiển thị ('headless' cho daemon chạy ngầm, để trống hoặc 'x11' cho GUI)
ELECTRON_OZONE_PLATFORM_HINT=headless

# Múi giờ hệ thống
TZ=Asia/Ho_Chi_Minh

# Đường dẫn Mount Volume khi dùng Docker Compose
HOST_CONFIG_PATH=/home/user
HOST_WORK_PATH=/opt/work
CONTAINER_UID_GID=1000:1000
```

---

## 📁 Cấu trúc Thư mục

```
antigravity2-headless/
├── .env                  # Biến môi trường thực tế của máy (được git-ignore bảo vệ)
├── .env.example          # Tệp mẫu cấu hình môi trường
├── .gitignore            # Quy tắc loại trừ của Git (chặn token, .env, logs, archives)
├── .dockerignore         # Quy tắc loại trừ khi build Docker
├── Dockerfile            # Cấu hình đóng gói Container Ubuntu 24.04 tối giản & an toàn
├── docker-compose.yml    # Định nghĩa dịch vụ Docker Compose
├── setup_antigravity.sh  # Kịch bản CLI quản trị trung tâm
├── README.md             # Tài liệu hướng dẫn tiếng Anh (English Documentation)
└── README.vi.md          # Tài liệu hướng dẫn chi tiết tiếng Việt (Vietnamese Documentation)
```

---

## ❓ Xử lý Sự cố & Câu hỏi Thường gặp (FAQ)

### Hỏi: Công cụ này có cần cài X11 server hay màn hình ảo như Xvfb không?
**Không.** Nhờ thiết lập `ELECTRON_OZONE_PLATFORM_HINT=headless`, Electron bỏ qua hoàn toàn tầng hiển thị đồ họa nhưng vẫn duy trì toàn bộ dịch vụ mạng, Language Server và kết nối Remote Control.

### Hỏi: Thông tin đăng nhập và OAuth token của tôi được lưu ở đâu? Có an toàn không?
Tất cả thông tin xác thực được lưu cục bộ trên máy chủ của bạn tại `$ANTIGRAVITY_HOME/.gemini/` và `$ANTIGRAVITY_HOME/.config/Antigravity/`. Mọi tệp OAuth token đều được khóa quyền truy cập `chmod 600` (chỉ tài khoản người dùng của bạn mới đọc được) và thư mục hồ sơ đa tài khoản `~/.gemini/accounts/` được bảo vệ ở mức `chmod 700`.

### Hỏi: Làm sao để đổi tên máy hiển thị trên trang điều khiển từ xa `https://antigravity.google.com`?
Bạn chỉ cần chạy lệnh:
```bash
./setup_antigravity.sh remote-on ten-server-moi
./setup_antigravity.sh restart
```

### Hỏi: Khi mạng chập chờn hoặc tôi đóng trình duyệt trên điện thoại thì tác vụ Agent đang chạy có bị dừng không?
**Không.** Toàn bộ tiến trình Agent, subagents và lệnh terminal thực thi trực tiếp trên máy chủ Headless của bạn. Khi bạn mở lại [`https://antigravity.google.com`](https://antigravity.google.com), giao diện web sẽ tự động đồng bộ lại luồng công việc đang diễn ra.

---

## 📄 Giấy phép (License)

Dự án này được phát hành dưới [Giấy phép MIT (MIT License)](LICENSE). Antigravity là sản phẩm thuộc bản quyền của Google. Đây là bộ công cụ mã nguồn mở độc lập từ cộng đồng nhằm tối ưu hóa việc triển khai và vận hành Antigravity trong môi trường Headless Server / Container.
