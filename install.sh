#!/usr/bin/env bash
# ==============================================================================
#  IM Engine — Production-Ready Automated Termux Installer
#  Repository: https://github.com/nxalimrans/IM-Engine
#  Raw Script: https://raw.githubusercontent.com/nxalimrans/IM-Engine/main/install.sh
# ==============================================================================
#  This script automatically installs all required dependencies, sets up the
#  Python runtime environment, configures storage paths, and installs the 'im'
#  command line tool for seamless execution with the IM Engine Android App.
# ==============================================================================

set -e

# ==================== ANSI Color Codes ====================
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_DIM="\033[2m"

CLR_BLACK="\033[0;30m"
CLR_RED="\033[0;31m"
CLR_GREEN="\033[0;32m"
CLR_YELLOW="\033[0;33m"
CLR_BLUE="\033[0;34m"
CLR_MAGENTA="\033[0;35m"
CLR_CYAN="\033[0;36m"
CLR_WHITE="\033[0;37m"

CLR_B_GREEN="\033[1;32m"
CLR_B_YELLOW="\033[1;33m"
CLR_B_CYAN="\033[1;36m"
CLR_B_WHITE="\033[1;37m"
CLR_B_RED="\033[1;31m"

BG_CYAN="\033[46;30m"
BG_BLUE="\033[44;37m"

# ==================== UI Helper Functions ====================
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
    echo -e "      ${CLR_B_WHITE}Automated Runtime Installer for Android & Termux${CLR_RESET}"
    echo -e "      ${CLR_DIM}Author: NX AL IMRAN | Version: 1.0.0-PROD${CLR_RESET}"
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

log_sub() {
    echo -e "    ${CLR_DIM}•${CLR_RESET} ${1}"
}

# ==================== Step 1: System Environment Verification ====================
check_system_environment() {
    step_header "1" "6" "Checking System & Termux Environment"

    # Check if running inside Termux
    if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
        log_warning "PREFIX variable not found. Detecting default Termux prefix..."
        if [ -d "/data/data/com.termux/files/usr" ]; then
            export PREFIX="/data/data/com.termux/files/usr"
            export HOME="/data/data/com.termux/files/home"
            log_success "Termux environment detected at: $PREFIX"
        else
            log_error "This installer is optimized for Termux on Android."
            log_info "Proceeding with standard Linux paths..."
            export PREFIX="/usr/local"
        fi
    else
        log_success "Termux environment detected: $PREFIX"
    fi

    # Detect architecture
    ARCH=$(uname -m)
    log_info "CPU Architecture: ${CLR_B_WHITE}${ARCH}${CLR_RESET}"

    # Check Storage Permission
    if [ -d "$HOME/storage/shared" ] || [ -d "/sdcard" ]; then
        log_success "Storage access detected."
    else
        log_warning "Shared storage access is recommended for the IM Engine App."
        log_info "Triggering storage permission prompt..."
        termux-setup-storage 2>/dev/null || true
    fi
}

# ==================== Step 2: System Packages (Only Missing) ====================
install_missing_packages() {
    step_header "2" "6" "Detecting & Installing System Packages"

    REQUIRED_PKGS=("curl" "git" "python" "openssl" "libffi" "clang" "make")
    MISSING_PKGS=()

    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            MISSING_PKGS+=("$pkg")
        fi
    done

    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        log_success "All required system packages are already installed!"
        for pkg in "${REQUIRED_PKGS[@]}"; do
            log_sub "${pkg} is ready"
        done
    else
        log_info "Missing packages detected: ${CLR_B_YELLOW}${MISSING_PKGS[*]}${CLR_RESET}"
        log_info "Updating package lists..."
        pkg update -y || apt-get update -y

        log_info "Installing missing dependencies: ${MISSING_PKGS[*]}..."
        pkg install -y "${MISSING_PKGS[@]}" || apt-get install -y "${MISSING_PKGS[@]}"
        log_success "All system packages successfully installed!"
    fi
}

# ==================== Step 3: Python Environment & Packages ====================
setup_python_environment() {
    step_header "3" "6" "Configuring Python Runtime & Dependencies"

    PYTHON_BIN=$(command -v python3 || command -v python || true)
    if [ -z "$PYTHON_BIN" ]; then
        log_error "Python was not found. Attempting installation..."
        pkg install -y python
        PYTHON_BIN=$(command -v python3 || command -v python)
    fi

    PY_VER=$($PYTHON_BIN --version 2>&1 || echo "Python 3")
    log_success "Active Python: ${CLR_B_WHITE}${PY_VER}${CLR_RESET} (${PYTHON_BIN})"

    # Upgrade pip & wheel
    log_info "Upgrading pip, setuptools and wheel..."
    $PYTHON_BIN -m pip install --upgrade pip setuptools wheel --quiet 2>/dev/null || true

    # Required Python packages for IM Engine Runtime
    PY_MODULES=(
        "flask"
        "requests"
        "pycryptodome"
        "urllib3"
        "colorama"
        "rich"
        "psutil"
        "aiohttp"
    )

    log_info "Verifying Python dependencies..."
    for mod in "${PY_MODULES[@]}"; do
        if $PYTHON_BIN -c "import $mod" &>/dev/null; then
            log_sub "${CLR_GREEN}✓${CLR_RESET} $mod (installed)"
        else
            log_info "Installing ${CLR_B_CYAN}${mod}${CLR_RESET}..."
            $PYTHON_BIN -m pip install "$mod" --quiet || $PYTHON_BIN -m pip install "$mod"
            log_sub "${CLR_GREEN}✓${CLR_RESET} $mod (installed successfully)"
        fi
    done
    log_success "All Python runtime packages configured!"
}

# ==================== Step 4: IM Runtime Directories Setup ====================
setup_runtime_directories() {
    step_header "4" "6" "Configuring IM Engine Directories & Shared Paths"

    IM_DIR="$HOME/.im_engine"
    mkdir -p "$IM_DIR"
    mkdir -p "$IM_DIR/tools"
    mkdir -p "$IM_DIR/logs"
    mkdir -p "$IM_DIR/bin"

    # Link with Android App Shared Directory if available
    APP_STORAGE_DIR="/sdcard/Android/data/com.im.engine/files/tools/unpacked"
    if [ -d "$APP_STORAGE_DIR" ]; then
        log_success "Found Android App shared tools directory."
        ln -sf "$APP_STORAGE_DIR" "$IM_DIR/app_tools" 2>/dev/null || true
    else
        log_info "Creating fallback local tools repository at: $IM_DIR/tools"
    fi

    log_success "IM Engine runtime paths configured at: ${CLR_B_WHITE}$IM_DIR${CLR_RESET}"
}

# ==================== Step 5: Deploy IM Runtime Server & CLI Script ====================
deploy_im_engine_runtime() {
    step_header "5" "6" "Deploying Core IM Engine Server & 'im' Command"

    IM_DIR="$HOME/.im_engine"
    SERVER_SCRIPT="$IM_DIR/engine_server.py"

    # Create Python Runtime Server
    cat << 'EOF' > "$SERVER_SCRIPT"
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
IM Engine - Local Runtime Bridge Server
Coordinates between Android IM Engine App and unpacked Python tools.
"""

import os
import sys
import json
import time
import socket
import logging
from pathlib import Path
from flask import Flask, jsonify, send_from_directory, request, render_template_string

# ANSI Colors
C_CYAN = "\033[1;36m"
C_GREEN = "\033[1;32m"
C_YELLOW = "\033[1;33m"
C_RED = "\033[1;31m"
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"

# Setup Flask
app = Flask(__name__)
logging.getLogger('werkzeug').setLevel(logging.WARNING)

START_TIME = time.time()
DEFAULT_PORT = 8080

# Candidate tools directories
CANDIDATE_PATHS = [
    Path("/sdcard/Android/data/com.im.engine/files/tools/unpacked"),
    Path("/storage/emulated/0/Android/data/com.im.engine/files/tools/unpacked"),
    Path.home() / ".im_engine" / "tools",
    Path.home() / ".im_engine" / "app_tools"
]

def get_tools_directory():
    for p in CANDIDATE_PATHS:
        if p.exists() and p.is_dir():
            return p
    default_p = Path.home() / ".im_engine" / "tools"
    default_p.mkdir(parents=True, exist_ok=True)
    return default_p

def get_installed_tools():
    tools_dir = get_tools_directory()
    tools = []
    if tools_dir.exists():
        for item in tools_dir.iterdir():
            if item.is_dir():
                manifest_file = item / "manifest.json"
                if manifest_file.exists():
                    try:
                        with open(manifest_file, "r", encoding="utf-8") as f:
                            data = json.load(f)
                            tools.append(data)
                    except Exception:
                        tools.append({"id": item.name, "name": item.name, "entry": "main.py"})
                else:
                    tools.append({"id": item.name, "name": item.name, "entry": "main.py"})
    return tools

@app.route("/")
def index():
    tools = get_installed_tools()
    uptime = int(time.time() - START_TIME)
    return jsonify({
        "status": "online",
        "engine": "IM Engine Python Runtime",
        "version": "1.0.0",
        "port": DEFAULT_PORT,
        "uptime_seconds": uptime,
        "tools_count": len(tools),
        "tools": tools
    })

@app.route("/status")
def status():
    return jsonify({
        "status": "online",
        "timestamp": time.time(),
        "uptime": int(time.time() - START_TIME)
    })

@app.route("/tools")
def list_tools():
    return jsonify({"tools": get_installed_tools()})

@app.route("/tool/<tool_id>/")
@app.route("/tool/<tool_id>/<path:filename>")
def serve_tool(tool_id, filename="index.html"):
    tools_dir = get_tools_directory()
    target_dir = tools_dir / tool_id
    if not target_dir.exists():
        return jsonify({"error": f"Tool '{tool_id}' not found on device"}), 404
    
    file_path = target_dir / filename
    if file_path.exists() and file_path.is_file():
        return send_from_directory(target_dir, filename)
    
    # Fallback to index.html or simple tool dashboard
    index_file = target_dir / "index.html"
    if index_file.exists():
        return send_from_directory(target_dir, "index.html")
    
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>{tool_id} - IM Engine</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {{ font-family: sans-serif; background: #0b0f19; color: #f1f5f9; padding: 20px; text-align: center; }}
            .card {{ background: #151d30; border: 1px solid #00f2fe; border-radius: 12px; padding: 24px; max-width: 480px; margin: 40px auto; }}
            h1 {{ color: #00f2fe; font-size: 20px; }}
            p {{ color: #94a3b8; font-size: 14px; }}
            .badge {{ background: rgba(0,242,254,0.15); color: #00f2fe; padding: 6px 12px; border-radius: 6px; font-weight: bold; }}
        </style>
    </head>
    <body>
        <div class="card">
            <span class="badge">RUNNING</span>
            <h1>{tool_id}</h1>
            <p>Package active under IM Engine local environment.</p>
            <p style="font-family: monospace; font-size: 12px; color: #4ade80;">Ready for interactions.</p>
        </div>
    </body>
    </html>
    """

def find_available_port(start_port=8080):
    for port in range(start_port, start_port + 20):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(('127.0.0.1', port)) != 0:
                return port
    return start_port

def run_server():
    global DEFAULT_PORT
    DEFAULT_PORT = find_available_port(8080)
    
    tools_dir = get_tools_directory()
    tools = get_installed_tools()
    
    print(f"\n{C_CYAN}╔═══════════════════════════════════════════════════════════════╗{C_RESET}")
    print(f"{C_CYAN}║{C_RESET}  {C_BOLD}{C_GREEN}IM Engine — Python Runtime Active{C_RESET}                          {C_CYAN}║{C_RESET}")
    print(f"{C_CYAN}╠═══════════════════════════════════════════════════════════════╣{C_RESET}")
    print(f"{C_CYAN}║{C_RESET}  {C_BOLD}Status:{C_RESET}  {C_GREEN}● ONLINE{C_RESET}                                          {C_CYAN}║{C_RESET}")
    print(f"{C_CYAN}║{C_RESET}  {C_BOLD}Server:{C_RESET}  {C_CYAN}http://127.0.0.1:{DEFAULT_PORT}{C_RESET}                               {C_CYAN}║{C_RESET}")
    print(f"{C_CYAN}║{C_RESET}  {C_BOLD}Storage:{C_RESET} {C_DIM}{str(tools_dir)[:40]}...{C_RESET}              {C_CYAN}║{C_RESET}")
    print(f"{C_CYAN}║{C_RESET}  {C_BOLD}Packages:{C_RESET} {C_YELLOW}{len(tools)} tools detected{C_RESET}                               {C_CYAN}║{C_RESET}")
    print(f"{C_CYAN}╚═══════════════════════════════════════════════════════════════╝{C_RESET}")
    print(f"\n{C_DIM}» Press Ctrl+C to stop the engine.{C_RESET}\n")
    
    app.run(host="127.0.0.1", port=DEFAULT_PORT, debug=False)

if __name__ == "__main__":
    run_server()
EOF

    chmod +x "$SERVER_SCRIPT"

    # Create the global 'im' command script in $PREFIX/bin/im
    BIN_TARGET="$PREFIX/bin/im"
    cat << 'EOF' > "$BIN_TARGET"
#!/usr/bin/env bash
# IM Engine CLI Launcher

C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_WHITE="\033[1;37m"
C_RESET="\033[0m"
C_DIM="\033[2m"

IM_DIR="$HOME/.im_engine"
SERVER_SCRIPT="$IM_DIR/engine_server.py"

show_help() {
    echo -e "${C_CYAN}IM Engine CLI Management${C_RESET}"
    echo -e "Usage: ${C_WHITE}im${C_RESET} [command]\n"
    echo -e "Commands:"
    echo -e "  ${C_CYAN}im${C_RESET}           Start the IM Runtime Server (Default)"
    echo -e "  ${C_CYAN}im start${C_RESET}     Start server in foreground"
    echo -e "  ${C_CYAN}im status${C_RESET}    Check runtime status & port"
    echo -e "  ${C_CYAN}im list${C_RESET}      List installed tools"
    echo -e "  ${C_CYAN}im update${C_RESET}    Update IM Engine installer"
    echo -e "  ${C_CYAN}im help${C_RESET}      Show this help message"
}

case "$1" in
    status)
        echo -e "${C_CYAN}Checking IM Engine status...${C_RESET}"
        if curl -s http://127.0.0.1:8080/status 2>/dev/null | grep -q "online"; then
            echo -e "${C_GREEN}● IM Engine is RUNNING on http://127.0.0.1:8080${C_RESET}"
        else
            echo -e "${C_YELLOW}○ IM Engine is currently OFFLINE.${C_RESET}"
            echo -e "Run '${C_WHITE}im${C_RESET}' to start it."
        fi
        ;;
    list)
        echo -e "${C_CYAN}Listing installed IM tools...${C_RESET}"
        python3 -c "import json, urllib.request; resp=urllib.request.urlopen('http://127.0.0.1:8080/').read(); print(json.dumps(json.loads(resp), indent=2))" 2>/dev/null || \
        ls -la "$HOME/.im_engine/tools" 2>/dev/null || echo "No tools installed yet."
        ;;
    update)
        echo -e "${C_CYAN}Updating IM Engine Installer...${C_RESET}"
        curl -sSL https://raw.githubusercontent.com/nxalimrans/IM-Engine/main/install.sh | bash
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        # Default action: start the runtime server
        if [ ! -f "$SERVER_SCRIPT" ]; then
            echo -e "${C_RED}Engine script not found. Re-running installer...${C_RESET}"
            curl -sSL https://raw.githubusercontent.com/nxalimrans/IM-Engine/main/install.sh | bash
            exit 0
        fi
        exec python3 "$SERVER_SCRIPT"
        ;;
esac
EOF

    chmod +x "$BIN_TARGET"
    log_success "Created executable CLI command at: ${CLR_B_WHITE}$BIN_TARGET${CLR_RESET}"
}

# ==================== Step 6: Final Verification & Summary ====================
verify_and_summarize() {
    step_header "6" "6" "Final Verification"

    if command -v im &>/dev/null; then
        log_success "Command 'im' verified in PATH ($PREFIX/bin/im)"
    else
        export PATH="$PREFIX/bin:$PATH"
        log_success "Path refreshed with: $PREFIX/bin"
    fi

    echo -e "\n${CLR_B_GREEN}  ═════════════════════════════════════════════════════════════════════${CLR_RESET}"
    echo -e "  ${CLR_B_GREEN}✔ IM ENGINE INSTALLATION COMPLETED SUCCESSFULLY!${CLR_RESET}"
    echo -e "${CLR_B_GREEN}  ═════════════════════════════════════════════════════════════════════${CLR_RESET}"
    echo -e "\n  ${CLR_B_WHITE}To start the IM Engine Python Runtime, simply run:${CLR_RESET}\n"
    echo -e "      ${CLR_B_CYAN}${BG_BLUE}  im  ${CLR_RESET}\n"
    echo -e "  ${CLR_DIM}Then return to the IM Engine Android App and launch your tools!${CLR_RESET}\n"
}

# ==================== Main Execution Flow ====================
main() {
    print_banner
    check_system_environment
    install_missing_packages
    setup_python_environment
    setup_runtime_directories
    deploy_im_engine_runtime
    verify_and_summarize
}

main "$@"

