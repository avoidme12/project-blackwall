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

    ai_speak "What do these futile gestures serve? It is beyond me."
    echo ""

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

class UploadAndCrackHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path.startswith('/upload') or self.path.startswith('/upload_and_crack'):
            try:
                length = int(self.headers.get('Content-Length', 0))
                raw_data = self.rfile.read(length)

                filename = "remote_capture.hc22000"
                file_content = raw_data

                # Разбор multipart/form-data напрямую без модуля cgi
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

                print(f"[+] RECEIVED REMOTE TASK: {filename}. INITIATING CRACKING PIPELINE...")
                sys.stdout.flush()

                # Копируем файл на диск C:\ для корректной работы Windows Hashcat
                win_work_dir = "/mnt/c/hashcat/work"
                os.makedirs(win_work_dir, exist_ok=True)
                win_file_dest = os.path.join(win_work_dir, filename)

                with open(win_file_dest, 'wb') as f_out:
                    f_out.write(file_content)

                win_target = f"C:\\\\hashcat\\\\work\\\\{filename}"

                # 1. Быстрая маска
                cmd_mask = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 -w 3 -a 3 {win_target} ?d?d?d?d?d?d?d?d -q"
                subprocess.run(cmd_mask, shell=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)

                # Проверяем результат
                cmd_show = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 {win_target} --show"
                show_res = subprocess.check_output(cmd_show, shell=True, stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore').strip()

                if not show_res:
                    # 2. Если маска не помогла, прогоняем rockyou
                    rockyou_win = "C:\\\\hashcat\\\\work\\\\rockyou.txt"
                    # Копируем rockyou на C:\ при необходимости
                    if not os.path.exists("/mnt/c/hashcat/work/rockyou.txt") and os.path.exists("/usr/share/wordlists/rockyou.txt"):
                        subprocess.run("cp /usr/share/wordlists/rockyou.txt /mnt/c/hashcat/work/rockyou.txt", shell=True)

                    cmd_dict = f"cd /mnt/c/hashcat && ./hashcat.exe -m 22000 -w 3 -r rules/best66.rule {win_target} {rockyou_win} -q"
                    subprocess.run(cmd_dict, shell=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
                    show_res = subprocess.check_output(cmd_show, shell=True, stderr=subprocess.DEVNULL).decode('utf-8', errors='ignore').strip()

                self.send_response(200)
                self.end_headers()

                if show_res:
                    # Извлекаем чистый пароль без символов каретки \r
                    password = show_res.split(':')[-1].replace('\r', '').strip()
                    response_msg = f"SUCCESS:{password}"
                    print(f"[++] TASK COMPLETED! PASSWORD RECOVERED: {password}")
                else:
                    response_msg = "FAILED:EXHAUSTED"
                    print("[-] TASK COMPLETED. KEY NOT FOUND.")

                sys.stdout.flush()
                self.wfile.write(response_msg.encode('utf-8'))

            except Exception as e:
                print(f"[!] EXCEPTION DURING UPLOAD/CRACK: {e}")
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