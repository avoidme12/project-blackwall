#!/bin/bash

kc_style() {
    printf '[CHECK] %s\n' "$1"
}

kc_scan_mounts() {
    local out
    out="$(timeout 20 find / -xdev \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \( -perm -4000 -o -perm -2000 \) -type f -print 2>/dev/null)"
    if [ -n "$out" ]; then
        kc_style "SUID/SGID binaries:"
        printf '%s\n' "$out" | sed 's/^/  /'
    else
        kc_style "No SUID/SGID binaries found on /."
    fi
}

kc_scan_cron() {
    local f
    for f in /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/* /var/spool/cron/*; do
        [ -f "$f" ] || continue
        kc_style "cron: $f"
        grep -vE '^\s*#' "$f" 2>/dev/null | grep -vE '^\s*$' | sed 's/^/  /'
    done
}

kc_scan_writable_etc() {
    local out
    out="$(timeout 10 find /etc -type f -writable 2>/dev/null)"
    if [ -n "$out" ]; then
        kc_style "writable files under /etc (backdoor opportunity, not flag-relevant):"
        printf '%s\n' "$out" | sed 's/^/  /'
    fi
}

kc_scan_caps() {
    local out
    command -v getcap >/dev/null 2>&1 || return 0
    out="$(timeout 15 getcap -r /usr /bin /sbin /opt /etc /home /root 2>/dev/null)"
    if [ -n "$out" ]; then
        kc_style "binaries with capabilities:"
        printf '%s\n' "$out" | sed 's/^/  /'
    fi
}

kc_scan_sudo() {
    local out
    command -v sudo >/dev/null 2>&1 || return 0
    out="$(sudo -n -l 2>/dev/null)"
    if [ -n "$out" ]; then
        kc_style "sudo -n -l:"
        printf '%s\n' "$out" | sed 's/^/  /'
    fi
}

kc_scan_uid0() {
    local out
    out="$(awk -F: '$3==0{print $1}' /etc/passwd 2>/dev/null)"
    [ -n "$out" ] && { kc_style "UID 0 accounts:"; printf '%s\n' "$out" | sed 's/^/  /'; }
}

kc_scan_env() {
    [ -f /proc/1/environ ] && {
        kc_style "/proc/1/environ (NUL split):"
        tr '\0' '\n' </proc/1/environ 2>/dev/null | sed 's/^/  /'
    }
}

kc_find_flags() {
    local out
    out="$(timeout 45 grep -rIlE 'FA[A-Za-z0-9]*\{|CTF\{|flag\{' \
        /home /root /srv /var /opt /tmp /usr/local 2>/dev/null \
        | grep -vE '/(proc|sys|dev|node_modules|\.git)/' \
        | head -n 40)"
    if [ -n "$out" ]; then
        kc_style "candidate flag files:"
        printf '%s\n' "$out" | sed 's/^/  /'
    else
        kc_style "no flag-like files matched (widen scope or check service DB)"
    fi
}

# usage: kc_run_root <log_file>
# Prints a checklist of the highest-value places to look AFTER getting root.
kc_run_root() {
    local log_file="${1:-/dev/null}"
    {
        kc_style "=== can-i-root checklist ==="
        kc_scan_uid0
        kc_scan_sudo
        kc_scan_mounts
        kc_scan_caps
        kc_scan_cron
        kc_scan_writable_etc
        kc_scan_env
        kc_style "=== flag hunt ==="
        kc_find_flags
    } 2>/dev/null | tee -a "$log_file"
}