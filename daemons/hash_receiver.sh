#!/bin/bash
# ==========================================
# DAEMON: SHADOW SIGNAL RECEIVER & REMOTE CRACKER (Cynosure Server)
# ==========================================

run_hash_receiver() {
    local lport="9999"
    local recv_dir="${BASE_DIR}/core/received_hashes"
    mkdir -p "$recv_dir" 2>/dev/null

    ai_speak "What do these futile gestures serve?"
    sleep 0.5s
    ai_speak "It is beyond me."
    echo ""

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
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}Hardware Engine:${NC} ${TXT_RED_SUPERNOVA}NVIDIA RTX 5060 Ti CUDA Engaged${NC}"
    echo -e "${TXT_VOID}│${NC}"

    local py_receiver="/tmp/bw_server_$$.py"
    cat << 'EOF_PY' > "$py_receiver"
import http.server
import socketserver
import os
import sys
import subprocess

PORT = int(sys.argv[1])
SAVE_DIR = sys.argv[2]
BASE_DIR = sys.argv[3]

TXT_VOID = "\033[38;2;60;10;15m"
TXT_RED_PLASMA = "\033[38;2;255;0;0m"
TXT_RED_SUPERNOVA = "\033[38;2;255;180;180m"
TXT_RED_HELLFIRE = "\033[38;2;255;0;55m"
TXT_SCARLET = "\033[38;2;255;80;80m"
TXT_B_ALARM = "\033[1;38;2;255;65;0m"
NC = "\033[0m\033[38;2;130;20;30m"

# Разрешаем повторное мгновенное использование порта 9999 при перезапусках
class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

class UploadAndCrackHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_POST(self):
        if self.path.startswith('/upload') or self.path.startswith('/upload_and_crack'):
            try:
                length = int(self.headers.get('Content-Length', 0))
                raw_data = self.rfile.read(length)

                filename = "remote_capture.hc22000"
                file_content = raw_data

                boundary = self.headers.get_boundary()
                if boundary:
                    b_boundary = boundary.encode('utf-8')
                    parts = raw_data.split(b_boundary)
                    for part in parts:
                        if b'filename="' in part:
                            header_part, content = part.split(b'\r\n\r\n', 1)
                            content = content.rsplit(b'\r\n', 1)[0]
                            for line in header_part.split(b'\r\n'):
                                if b'filename="' in line:
                                    fn = line.split(b'filename="')[1].split(b'"')[0].decode('utf-8', errors='ignore')
                                    if fn:
                                        filename = os.path.basename(fn)
                            file_content = content
                            break

                filepath = os.path.join(SAVE_DIR, filename)
                with open(filepath, 'wb') as f:
                    f.write(file_content)

                print(f"{TXT_VOID}├─{TXT_B_ALARM}[ ++ ] REMOTE TASK INGESTED:{NC} {TXT_RED_SUPERNOVA}{filename}{NC}")
                print(f"{TXT_VOID}║   {TXT_RED_PLASMA}MX:// EXECUTING 6-STAGE PIPELINE VIA CYNOSURE DAEMON...{NC}")
                sys.stdout.flush()

                bash_cmd = f"stdbuf -oL -eL bash -c 'source \"{BASE_DIR}/core/colors.sh\" && source \"{BASE_DIR}/core/ui.sh\" && source \"{BASE_DIR}/core/state.sh\" && source \"{BASE_DIR}/daemons/wifi_cracker.sh\" && run_wifi_crack_pipeline \"{filepath}\"'"
                # Исправление warning Python 3.14+: текстовый режим с буферизацией строк (text=True, bufsize=1)
                pipe = subprocess.Popen(bash_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)

                self.send_response(200)
                self.send_header('Content-Type', 'text/plain; charset=utf-8')
                self.end_headers()

                recovered_password = None

                # Стримим телеметрию клиенту и одновременно ищем результат дешифрования
                for line in iter(pipe.stdout.readline, ''):
                    line_clean = line.strip()
                    if "SUCCESS:" in line_clean:
                        recovered_password = line_clean.split("SUCCESS:")[-1].strip()

                    # Пересылаем строчку клиенту (ноутбуку/телефону)
                    self.wfile.write(line.encode('utf-8'))
                    self.wfile.flush()

                pipe.stdout.close()
                pipe.wait()

                # Вывод найденного пароля в консоль сервера ПК
                if recovered_password:
                    response_msg = f"SUCCESS:{recovered_password}\n"
                    print(f"{TXT_VOID}├─{TXT_SCARLET}[ STAGE 6/6 ] REMOTE NODE SUCCESS: RECOVERED WIRELESS KEY:{NC}")
                    print(f"{TXT_VOID}║   {TXT_RED_SUPERNOVA}PASSWORD -> [ {recovered_password} ]{NC}\n")
                else:
                    response_msg = "FAILED:EXHAUSTED\n"
                    print(f"{TXT_VOID}├─{TXT_RED_HELLFIRE}[ - ] REMOTE DECRYPTION EXHAUSTED. Key not found.{NC}\n")

                sys.stdout.flush()
                self.wfile.write(response_msg.encode('utf-8'))

            except Exception as e:
                print(f"{TXT_VOID}║   {TXT_RED_HELLFIRE}[ ! ] EXCEPTION DURING PROCESS: {e}{NC}")
                sys.stdout.flush()
                self.send_response(500)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

with ReusableTCPServer(("", PORT), UploadAndCrackHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)
EOF_PY

    python3 "$py_receiver" "$lport" "$recv_dir" "$BASE_DIR"
    rm -f "$py_receiver" 2>/dev/null
}