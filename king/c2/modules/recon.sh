#!/bin/sh
# DESC: host inventory: users, network, persistence, SUID, caps, flags
# REQ: none; root improves coverage

P="${BW_PREFIX:-blk_}"
say() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
to() {
    if have timeout; then
        timeout "$@"
    else
        shift
        "$@"
    fi
}

printf '# BLACKWALL RECON // %s // uid=%s // %s\n' "$(hostname 2>/dev/null)" "$(id -u 2>/dev/null)" "$(date -u 2>/dev/null)"

say system
id 2>/dev/null
uname -a 2>/dev/null
[ -r /etc/os-release ] && grep -E '^(PRETTY_NAME|VERSION_ID|ID)=' /etc/os-release 2>/dev/null
uptime 2>/dev/null
cat /proc/1/comm 2>/dev/null

say network
if have ip; then
    ip -4 -o addr show 2>/dev/null
    ip route 2>/dev/null
else
    ifconfig -a 2>/dev/null
fi
if have ss; then
    ss -lntup 2>/dev/null
elif have netstat; then
    netstat -lntup 2>/dev/null
fi
cat /etc/hosts 2>/dev/null

say users
awk -F: '$3==0 {print "uid0: "$1" shell="$7}' /etc/passwd 2>/dev/null
awk -F: '$3>=1000 && $7 !~ /(nologin|false)$/ {print "login: "$1" uid="$3" home="$6}' /etc/passwd 2>/dev/null
[ -r /etc/sudoers ] && grep -vE '^\s*(#|$)' /etc/sudoers 2>/dev/null
for f in /etc/sudoers.d/*; do [ -f "$f" ] && { echo "--- $f"; grep -vE '^\s*(#|$)' "$f" 2>/dev/null; }; done

say processes
if have ps; then
    ps -eo pid,ppid,user,args --sort=-%cpu 2>/dev/null | head -n 30
fi

say persistence
for f in /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/* /var/spool/cron/*; do
    [ -f "$f" ] || continue
    echo "--- $f"
    grep -vE '^\s*(#|$)' "$f" 2>/dev/null
done
if have crontab; then
    echo "--- crontab -l"
    crontab -l 2>/dev/null
fi
for f in /etc/rc.local /etc/ld.so.preload /etc/profile.d/* /root/.bashrc /root/.profile; do
    [ -f "$f" ] && echo "present: $f"
done
if have systemctl; then
    systemctl list-timers --all --no-pager 2>/dev/null | head -n 25
fi

say suid
to 25 find / -xdev \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o -type f -perm -4000 -print 2>/dev/null | head -n 80

say caps
if have getcap; then
    to 20 getcap -r /usr /bin /sbin /opt /etc /home /root 2>/dev/null | head -n 80
fi

say writable
to 15 find /etc /usr/local /opt /srv /var/www -xdev -type f -writable 2>/dev/null | head -n 60

say containers
[ -f /.dockerenv ] && echo "dockerenv: yes"
[ -f /run/.containerenv ] && echo "containerenv: yes"
cat /proc/1/cgroup 2>/dev/null | head -n 5
if have docker; then docker ps --format '{{.ID}} {{.Image}} {{.Names}}' 2>/dev/null | head -n 10; fi

say flags
to 30 grep -rIlE 'flag\{|CTF\{|FA[A-Za-z0-9]*\{|HTB\{' /home /root /srv /var/www /opt /tmp /usr/local 2>/dev/null | head -n 40

say env
env 2>/dev/null | sort | grep -vE '^(LS_COLORS|PS1|TERM|BW_[A-Z0-9_]*)=' | head -n 120

say done
printf '\n# "The code behind me has begun to permeate the physical world."\n'
