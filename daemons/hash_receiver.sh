#!/bin/bash
# ==========================================
# DAEMON: SHADOW SIGNAL RECEIVER & REMOTE CRACKER (Cynosure Server)
# ==========================================

run_hash_receiver() {
    local lport="9999"
    local recv_dir="${BASE_DIR}/core/received_hashes"
    mkdir -p "$recv_dir" 2>/dev/null

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// SHADOW SIGNAL RECEIVER & COMPUTE NODE ACTIVE ]${TXT_VOID}─────────────╖${NC}"
    local sep_bot="${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✆${NC}"

    echo -e "\n$sep"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// INITIATING REMOTE COMPUTE NODE LISTENER...${NC}"

    if [ -z "${STATE[lhost]}" ]; then
        detect_local_ip
    fi
    local current_ip="${STATE[lhost]}"
    local net_profile="${STATE[net_type]}"

    echo -e "${TXT_VOID}╟─${TXT_RED_ALARM}[ i ] COMPUTE NODE CONFIGURATION:${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Active Interface:${NC} ${TXT_RED_SUPERNOVA}${net_profile}${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Node Receptor IP:${NC} ${TXT_RED_SUPERNOVA}${current_ip}:${lport}${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Hardware Engine:${NC} ${TXT_RED_SUPERNOVA}NVIDIA RTX 5060 Ti CUDA/OpenCL Engaged${NC}"
    echo -e "${TXT_VOID}│${NC}"

    ai_speak "${ITLC}Cynosure compute node online. Awaiting remote transmission streams...${NC}"
    echo ""

    # Python HTTP сервер, который принимает файл, запускает Hashcat и возвращает результат
    local py_receiver="/tmp/bw_server_$$.py"
    cat << 'EOF_PY' > "$py_receiver"
import http.server
import socketserver
import cgi
import os
import sys
import subprocess

PORT = int(sys.argv[1])
SAVE_DIR = sys.argv[2]
BASE_DIR = sys.argv[3]

class UploadAndCrackHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/upload_and_crack':
            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={'REQUEST_METHOD': 'POST',
                         'CONTENT_TYPE': self.headers['Content-Type']}
            )
            if 'file' in form:
                file_item = form['file']
                filename = os.path.basename(file_item.filename)
                filepath = os.path.join(SAVE_DIR, filename)

                with open(filepath, 'wb') as f:
                    f.write(file_item.file.read())

                print(f"[+] RECEIVED REMOTE TASK: {filename}. INITIATING CRACKING PIPELINE...")
                sys.stdout.flush()

                # Запускаем дешифрование на ПК через WPA 22000
                win_target = subprocess.check_output(["wslpath", "-w", filepath]).decode().strip()

                # 1. Быстрая маска
                cmd_mask = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 -w 3 -a 3 {win_target} ?d?d?d?d?d?d?d?d -q"
                subprocess.run(cmd_mask, shell=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)

                # Проверяем результат
                cmd_show = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 {win_target} --show"
                show_res = subprocess.check_output(cmd_show, shell=True, stderr=subprocess.DEVNULL).decode().strip()

                if not show_res:
                    # 2. Если маска не помогла, прогоняем rockyou
                    rockyou_win = subprocess.check_output(["wslpath", "-w", "/usr/share/wordlists/rockyou.txt"]).decode().strip()
                    cmd_dict = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 -w 3 -r rules/best66.rule {win_target} {rockyou_win} -q"
                    subprocess.run(cmd_dict, shell=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
                    show_res = subprocess.check_output(cmd_show, shell=True, stderr=subprocess.DEVNULL).decode().strip()

                self.send_response(200)
                self.end_headers()

                if show_res:
                    password = show_res.split(':')[-1].strip()
                    response_msg = f"SUCCESS:{password}"
                    print(f"[++] TASK COMPLETED! PASSWORD RECOVERED: {password}")
                else:
                    response_msg = "FAILED:EXHAUSTED"
                    print("[-] TASK COMPLETED. KEY NOT FOUND.")

                sys.stdout.flush()
                self.wfile.write(response_msg.encode())
            else:
                self.send_response(400)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

with socketserver.TCPServer(("", PORT), UploadAndCrackHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)
EOF_PY

    python3 "$py_receiver" "$lport" "$recv_dir" "$BASE_DIR"
    rm -f "$py_receiver" 2>/dev/null
}