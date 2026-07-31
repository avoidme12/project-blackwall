#!/bin/bash
# ==========================================
# DAEMON: SHADOW SIGNAL RECEIVER & REMOTE CRACKER (Cynosure Color Server)
# ==========================================

run_hash_receiver() {
    local lport="9999"
    local recv_dir="${BASE_DIR}/core/received_hashes"
    mkdir -p "$recv_dir" 2>/dev/null

    ai_speak "What do these futile gestures serve?"
    sleep 1s
    ai_speak "It is beyond me..."
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
    echo -e "${TXT_VOID}│${NC}"

    # Python HTTP Сервер с раскраской вывода и подавлением лишних HTTP логов
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

# ANSI-палитра Cynosure для Python
TXT_VOID = "\033[38;2;60;10;15m"
TXT_RED_PLASMA = "\033[38;2;255;0;0m"
TXT_RED_SUPERNOVA = "\033[38;2;255;180;180m"
TXT_RED_MAGMA = "\033[38;2;255;130;130m"
TXT_RED_HELLFIRE = "\033[38;2;255;0;55m"
TXT_SCARLET = "\033[38;2;255;80;80m"
TXT_B_ALARM = "\033[1;38;2;255;65;0m"
NC = "\033[0m\033[38;2;130;20;30m"

class UploadAndCrackHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Отключаем стандартный спам логов HTTP запросов (например: "POST /upload_and_crack HTTP/1.1 200")
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
                print(f"{TXT_VOID}║   {TXT_RED_PLASMA}MX:// INITIATING HARDWARE DECRYPTION PIPELINE...{NC}")
                sys.stdout.flush()

                win_work_dir = "/mnt/c/hashcat/work"
                os.makedirs(win_work_dir, exist_ok=True)
                win_file_dest = os.path.join(win_work_dir, filename)

                with open(win_file_dest, 'wb') as f_out:
                    f_out.write(file_content)

                win_target = f"C:\\\\hashcat\\\\work\\\\{filename}"

                # 1. Быстрая маска
                cmd_mask = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 -w 3 -a 3 {win_target} ?d?d?d?d?d?d?d?d -q"
                subprocess.run(cmd_mask, shell=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)

                cmd_show = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 {win_target} --show"
                show_res = subprocess.check_output(cmd_show, shell=True, stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore').strip()

                if not show_res:
                    # 2. Если маска не помогла, прогоняем rockyou
                    rockyou_win = "C:\\\\hashcat\\\\work\\\\rockyou.txt"
                    if not os.path.exists("/mnt/c/hashcat/work/rockyou.txt") and os.path.exists("/usr/share/wordlists/rockyou.txt"):
                        subprocess.run("cp /usr/share/wordlists/rockyou.txt /mnt/c/hashcat/work/rockyou.txt", shell=True)

                    cmd_dict = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 -w 3 -r rules/best66.rule {win_target} {rockyou_win} -q"
                    subprocess.run(cmd_dict, shell=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
                    show_res = subprocess.check_output(cmd_show, shell=True, stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore').strip()

                self.send_response(200)
                self.end_headers()

                if show_res:
                    password = show_res.split(':')[-1].replace('\r', '').strip()
                    response_msg = f"SUCCESS:{password}"
                    print(f"{TXT_VOID}├─{TXT_SCARLET}[ STAGE 6/6 ] REMOTE NODE SUCCESS: RECOVERED WIRELESS KEY:{NC}")
                    print(f"{TXT_VOID}║   {TXT_RED_SUPERNOVA}PASSWORD -> [ {password} ]{NC}\n")
                else:
                    response_msg = "FAILED:EXHAUSTED"
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

with socketserver.TCPServer(("", PORT), UploadAndCrackHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)
EOF_PY

    python3 "$py_receiver" "$lport" "$recv_dir" "$BASE_DIR"
    rm -f "$py_receiver" 2>/dev/null
}