#!/usr/bin/env bash
# ==============================================================================
#  IM Engine — Production-Ready Automated Termux Installer
#  Repository: https://github.com/nxalimrans/IM-Engine
#  Installation: bash <(curl -fsSL https://raw.githubusercontent.com/nxalimrans/IM-Engine/main/install.sh)
# ==============================================================================

set -e

# ==================== ANSI Color Codes ====================
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_DIM="\033[2m"

CLR_RED="\033[0;31m"
CLR_GREEN="\033[0;32m"
CLR_YELLOW="\033[0;33m"
CLR_CYAN="\033[0;36m"
CLR_WHITE="\033[0;37m"

CLR_B_GREEN="\033[1;32m"
CLR_B_YELLOW="\033[1;33m"
CLR_B_CYAN="\033[1;36m"
CLR_B_WHITE="\033[1;37m"
CLR_B_RED="\033[1;31m"

# ==================== UI Banners & Helpers ====================
print_banner() {
    clear 2>/dev/null || true
    echo -e "${CLR_B_CYAN}"
    echo "  ███████╗███╗   ███╗   ███████╗███╗   ██╗ ██████╗ ██╗███╗   ██╗███████╗"
    echo "  ██╔════╝████╗ ████║   ██╔════╝████╗  ██║██╔════╝ ██║████╗  ██║██╔════╝"
    echo "  ██║     ██╔████╔██║   █████╗  ██╔██╗ ██║██║  ███╗██║██╔██╗ ██║█████╗  "
    echo "  ██║     ██║╚██╔╝██║   ██╔══╝  ██║╚██╗██║██║   ██║██║██║╚██╗██║██╔══╝  "
    echo "  ███████╗██║ ╚═╝ ██║██╗███████╗██║ ╚████║╚██████╔╝██║██║ ╚████║███████╗"
    echo "  ╚══════╝╚═╝     ╚═╝╚═╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚══════╝"
    echo -e "${CLR_RESET}"
    echo -e "         ${CLR_B_WHITE}IM Engine Runtime Installer for Termux${CLR_RESET}"
    echo -e "       ${CLR_DIM}Author: NX AL IMRAN | Port: 8787 | Entry: main.py${CLR_RESET}"
    echo -e "${CLR_CYAN}  ═════════════════════════════════════════════════════════════════════${CLR_RESET}\n"
}

step_header() {
    echo -e "\n${CLR_B_CYAN}▶ [${1}/${2}] ${CLR_B_WHITE}${3}${CLR_RESET}"
    echo -e "${CLR_DIM}  ─────────────────────────────────────────────────────────${CLR_RESET}"
}

log_info() {
    echo -e "  ${CLR_CYAN}ℹ${CLR_RESET} ${1}"
}

log_success() {
    echo -e "  ${CLR_B_GREEN}✓${CLR_RESET} ${1}"
}

log_warning() {
    echo -e "  ${CLR_B_YELLOW}⚠${CLR_RESET} ${1}"
}

log_error() {
    echo -e "  ${CLR_B_RED}✗${CLR_RESET} ${1}"
}

# ==================== Step 1: Environment Check ====================
check_environment() {
    step_header "1" "4" "Verifying Termux Environment"

    # Termux prefix detection
    if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
        if [ -d "/data/data/com.termux/files/usr" ]; then
            export PREFIX="/data/data/com.termux/files/usr"
            export HOME="/data/data/com.termux/files/home"
            log_success "Termux prefix confirmed at: $PREFIX"
        else
            log_error "Error: This installer must be run inside Termux on Android."
            exit 1
        fi
    else
        log_success "Termux environment verified ($PREFIX)"
    fi
}

# ==================== Step 2: System Packages ====================
install_packages() {
    step_header "2" "4" "Installing Required Dependencies"

    MISSING_DEPS=()
    if ! command -v curl &>/dev/null; then
        MISSING_DEPS+=("curl")
    fi
    if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
        MISSING_DEPS+=("python")
    fi

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        log_success "All core packages are already installed (Python & Curl)."
    else
        log_info "Installing missing dependencies: ${MISSING_DEPS[*]}..."
        pkg update -y
        pkg install -y "${MISSING_DEPS[@]}"
        log_success "Dependencies successfully installed."
    fi

    PY_BIN=$(command -v python3 || command -v python)
    log_success "Using Python: $($PY_BIN --version 2>&1)"
}

# ==================== Step 3: Runtime Server Deployment ====================
deploy_runtime() {
    step_header "3" "4" "Deploying IM Engine Runtime Server"

    RUNTIME_DIR="$HOME/.im_engine"
    TMP_DIR="$RUNTIME_DIR/tmp"
    mkdir -p "$RUNTIME_DIR"
    mkdir -p "$TMP_DIR"

    SERVER_FILE="$RUNTIME_DIR/runtime_server.py"

    cat << 'EOF' > "$SERVER_FILE"
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
IM Engine - Local Runtime Bridge Server (Port 8787)
Listens for Tool ZIPs sent from Android App, extracts them temporarily,
executes main.py, manages dynamic port allocation, and cleans up completely on stop.
"""

import os
import sys
import json
import time
import socket
import shutil
import zipfile
import tempfile
import signal
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

SERVER_HOST = "127.0.0.1"
API_PORT = 8787

RUNTIME_DIR = os.path.expanduser("~/.im_engine")
TMP_BASE_DIR = os.path.join(RUNTIME_DIR, "tmp")

# Active running processes: { session_id: { "proc": Popen, "temp_dir": path, "port": int, "tool_id": str } }
ACTIVE_SESSIONS = {}
SESSIONS_LOCK = threading.Lock()

def get_free_port(start_port=8765):
    """Find an available port starting from start_port."""
    for port in range(start_port, start_port + 200):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind((SERVER_HOST, port))
                return port
            except OSError:
                continue
    return start_port

def cleanup_session(session_id):
    """Kills process and completely deletes temporary folder for the session."""
    with SESSIONS_LOCK:
        session = ACTIVE_SESSIONS.pop(session_id, None)
        if not session:
            return False

    proc = session.get("proc")
    temp_dir = session.get("temp_dir")
    port = session.get("port")

    if proc:
        try:
            proc.terminate()
            proc.wait(timeout=2)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass

    if temp_dir and os.path.exists(temp_dir):
        try:
            shutil.rmtree(temp_dir, ignore_errors=True)
        except Exception:
            pass

    print(f"\033[1;33m[STOPPED]\033[0m Session '{session_id}' terminated. Port {port} freed. Temp folder deleted.")
    return True

def cleanup_all_sessions():
    """Stops all active tools and cleans temporary directory completely."""
    with SESSIONS_LOCK:
        ids = list(ACTIVE_SESSIONS.keys())
    for sid in ids:
        cleanup_session(sid)
    if os.path.exists(TMP_BASE_DIR):
        try:
            shutil.rmtree(TMP_BASE_DIR, ignore_errors=True)
            os.makedirs(TMP_BASE_DIR, exist_ok=True)
        except Exception:
            pass

class RuntimeHTTPHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Clean custom log output
        pass

    def send_json(self, status_code, data):
        response = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(response)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        query = parse_qs(parsed.query)

        if path == "" or path == "/status":
            self.send_json(200, {
                "status": "online",
                "engine": "IM Engine Runtime",
                "version": "1.0.0",
                "port": API_PORT,
                "active_tools": len(ACTIVE_SESSIONS)
            })
            return

        if path == "/stop":
            session_id = query.get("session_id", [None])[0]
            if session_id:
                cleanup_session(session_id)
            else:
                cleanup_all_sessions()
            self.send_json(200, {"status": "stopped"})
            return

        self.send_json(404, {"status": "error", "message": "Endpoint not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        if path == "/stop":
            content_length = int(self.headers.get("Content-Length", 0))
            session_id = None
            if content_length > 0:
                try:
                    body = self.rfile.read(content_length).decode("utf-8")
                    data = json.loads(body)
                    session_id = data.get("session_id")
                except Exception:
                    pass
            if session_id:
                cleanup_session(session_id)
            else:
                cleanup_all_sessions()
            self.send_json(200, {"status": "stopped"})
            return

        if path == "/run":
            # Clean up previous running tool first to prevent port/memory clashes
            cleanup_all_sessions()

            content_length = int(self.headers.get("Content-Length", 0))
            if content_length <= 0:
                self.send_json(400, {"status": "error", "message": "No tool payload received"})
                return

            tool_bytes = self.rfile.read(content_length)
            session_id = f"tool_{int(time.time() * 1000)}"
            session_tmp = os.path.join(TMP_BASE_DIR, session_id)
            os.makedirs(session_tmp, exist_ok=True)

            temp_zip_path = os.path.join(session_tmp, "payload.zip")
            with open(temp_zip_path, "wb") as f:
                f.write(tool_bytes)

            # Extract ZIP
            try:
                with zipfile.ZipFile(temp_zip_path, "r") as zip_ref:
                    zip_ref.extractall(session_tmp)
            except Exception as e:
                shutil.rmtree(session_tmp, ignore_errors=True)
                self.send_json(400, {"status": "error", "message": f"Invalid tool ZIP: {str(e)}"})
                return

            # Remove temporary ZIP file immediately after extraction
            try:
                os.remove(temp_zip_path)
            except Exception:
                pass

            # Search for main.py (in root or first level directory)
            main_py_path = os.path.join(session_tmp, "main.py")
            work_dir = session_tmp
            if not os.path.exists(main_py_path):
                # Check nested folder
                sub_dirs = [d for d in os.listdir(session_tmp) if os.path.isdir(os.path.join(session_tmp, d))]
                for sd in sub_dirs:
                    candidate = os.path.join(session_tmp, sd, "main.py")
                    if os.path.exists(candidate):
                        main_py_path = candidate
                        work_dir = os.path.join(session_tmp, sd)
                        break

            if not os.path.exists(main_py_path):
                shutil.rmtree(session_tmp, ignore_errors=True)
                self.send_json(400, {"status": "error", "message": "main.py entry file not found in package"})
                return

            # Allocate free port
            assigned_port = get_free_port(8765)

            # Environment variables for the tool process
            env = os.environ.copy()
            env["PORT"] = str(assigned_port)
            env["IM_RUNTIME_PORT"] = str(assigned_port)
            env["PYTHONUNBUFFERED"] = "1"

            try:
                proc = subprocess.Popen(
                    [sys.executable, main_py_path, "--port", str(assigned_port)],
                    cwd=work_dir,
                    env=env,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT
                )

                # Store active session
                with SESSIONS_LOCK:
                    ACTIVE_SESSIONS[session_id] = {
                        "proc": proc,
                        "temp_dir": session_tmp,
                        "port": assigned_port
                    }

                print(f"\033[1;32m[LAUNCHED]\033[0m Session '{session_id}' running on http://127.0.0.1:{assigned_port}")

                # Give the script a short moment to start server
                time.sleep(0.5)

                self.send_json(200, {
                    "status": "success",
                    "port": assigned_port,
                    "session_id": session_id
                })
            except Exception as e:
                cleanup_session(session_id)
                self.send_json(500, {"status": "error", "message": f"Failed to execute main.py: {str(e)}"})
            return

        self.send_json(404, {"status": "error", "message": "Unknown endpoint"})

def handle_exit(signum, frame):
    print("\n\033[1;33m[SHUTDOWN]\033[0m Stopping IM Engine Runtime and cleaning temporary files...")
    cleanup_all_sessions()
    sys.exit(0)

def run_server():
    cleanup_all_sessions()
    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)

    server = HTTPServer((SERVER_HOST, API_PORT), RuntimeHTTPHandler)
    print(f"\033[1;36m╔═══════════════════════════════════════════════════════════════╗\033[0m")
    print(f"\033[1;36m║\033[0m  \033[1;32mIM Engine — Python Runtime Active\033[0m                          \033[1;36m║\033[0m")
    print(f"\033[1;36m╠═══════════════════════════════════════════════════════════════╣\033[0m")
    print(f"\033[1;36m║\033[0m  \033[1mAPI Endpoint:\033[0m  \033[1;36mhttp://{SERVER_HOST}:{API_PORT}\033[0m                              \033[1;36m║\033[0m")
    print(f"\033[1;36m║\033[0m  \033[1mStatus:\033[0m        \033[1;32m● ONLINE (Awaiting App Commands)\033[0m               \033[1;36m║\033[0m")
    print(f"\033[1;36m║\033[0m  \033[1mEntry File:\033[0m    \033[1;33mmain.py\033[0m                                        \033[1;36m║\033[0m")
    print(f"\033[1;36m╚═══════════════════════════════════════════════════════════════╝\033[0m")
    print(f"\n\033[2m» Keep this Termux session active while using IM Engine.\033[0m")
    print(f"\033[2m» Press Ctrl+C to safely terminate runtime and clean temporary files.\033[0m\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        handle_exit(None, None)

if __name__ == "__main__":
    run_server()
EOF

    chmod +x "$SERVER_FILE"
    log_success "Runtime server deployed at: $SERVER_FILE"
}

# ==================== Step 4: Create 'im' Command ====================
create_im_command() {
    step_header "4" "4" "Creating 'im' Command"

    BIN_PATH="$PREFIX/bin/im"

    cat << 'EOF' > "$BIN_PATH"
#!/usr/bin/env bash
# IM Engine CLI Launcher

RUNTIME_SERVER="$HOME/.im_engine/runtime_server.py"

if [ ! -f "$RUNTIME_SERVER" ]; then
    echo -e "\033[1;31m[ERROR]\033[0m IM Engine runtime server not found. Re-installing..."
    bash <(curl -fsSL https://raw.githubusercontent.com/nxalimrans/IM-Engine/main/install.sh)
    exit 0
fi

exec python3 "$RUNTIME_SERVER" "$@"
EOF

    chmod +x "$BIN_PATH"
    log_success "Executable command created at: $BIN_PATH"

    echo -e "\n${CLR_B_GREEN}  ═════════════════════════════════════════════════════════════════════${CLR_RESET}"
    echo -e "  ${CLR_B_GREEN}✔ IM ENGINE RUNTIME READY!${CLR_RESET}"
    echo -e "${CLR_B_GREEN}  ═════════════════════════════════════════════════════════════════════${CLR_RESET}"
    echo -e "\n  ${CLR_B_WHITE}To start the runtime now, simply run:${CLR_RESET}\n"
    echo -e "      ${CLR_B_CYAN}im${CLR_RESET}\n"
}

# ==================== Main Execution Flow ====================
main() {
    print_banner
    check_environment
    install_packages
    deploy_runtime
    create_im_command
}

main "$@"
