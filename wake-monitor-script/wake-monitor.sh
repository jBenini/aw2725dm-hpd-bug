#!/bin/bash
# wake-monitor.sh — Force SDDM restart when AW2725DM monitor powers on late.
#
# Triggered by udev rule 99-wake-monitor.rules when the monitor's internal
# USB hub (Realtek HID 0bda:1101) reconnects.
#
# Logic:
#   1. Cooldown (30s) — prevents multiple triggers from USB enumeration
#   2. Wait 5s — DisplayPort link electrical stabilization
#   3. Check: is there an active graphical session on seat0 (not tty1)?
#      - YES → user is already logged in → do nothing (monitor flickered)
#      - NO  → stuck at SDDM greeter → restart SDDM to force reprobe
#
# Why this works:
#   The SDDM greeter probes the display ONCE on startup and never retries.
#   If the monitor isn't on at that moment, the screen stays blank forever.
#   Restarting SDDM spawns a new Xorg instance that probes again — this
#   time the monitor is powered on and link training succeeds.
#
# Author: joao (documented in /home/joao/git_repo/aw2725dm-hpd-bug/README.md)

set -uo pipefail

LOG_TAG="wake-monitor"
COOLDOWN_FILE="/tmp/.wake-monitor-last-run"
COOLDOWN_SECS=30
STABILIZE_SECS=5

log() {
    logger -t "$LOG_TAG" "$1"
    echo "[$(date '+%H:%M:%S')] [$LOG_TAG] $1"
}

# --- Cooldown ---
# The USB hub enumerates 4 devices in sequence (hub, mouse, keyboard, HID).
# Without cooldown, the script fires once per device. We only want one run.
if [[ -f "$COOLDOWN_FILE" ]]; then
    last_run=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    elapsed=$(( now - last_run ))
    if (( elapsed < COOLDOWN_SECS )); then
        log "Cooldown active (${elapsed}s ago). Skipping."
        exit 0
    fi
fi
date +%s > "$COOLDOWN_FILE"

# --- Stabilization ---
# DisplayPort link training needs time after the monitor powers on.
# 5 seconds is enough for the AW2725DM's receiver chip to be ready.
log "Waiting ${STABILIZE_SECS}s for DP link stabilization..."
sleep "$STABILIZE_SECS"

# --- Check for active graphical session ---
# If the user is already logged into KDE Plasma, we do NOT want to restart
# SDDM — that would kill their session. We only restart when there's no
# active graphical session, meaning we're stuck at the greeter.
#
# How we detect it (two complementary checks):
#   1. Process check: kwin_wayland running = KDE Plasma session active
#   2. Session check: loginctl shows a seat0 session on tty2 (not tty1/greeter)
#
# Why not just loginctl? Because tty3/tty4 etc. are text TTYs, not graphical.
# The greeter runs on tty1, the user session on tty2. But checking kwin_wayland
# is more reliable — it's the actual compositor process.

# Check 1: kwin_wayland process (most reliable)
if pgrep -u joao kwin_wayland >/dev/null 2>&1; then
    log "kwin_wayland process found. KDE Plasma session is active. Not restarting SDDM."
    exit 0
fi

# Check 2: loginctl session on tty2 (fallback)
graphical_session=$(loginctl list-sessions --no-legend 2>/dev/null \
    | awk '$2 >= 1000 && $4 == "seat0" && $7 == "tty2" {print; exit}')

if [[ -n "$graphical_session" ]]; then
    session_user=$(echo "$graphical_session" | awk '{print $3}')
    session_tty=$(echo "$graphical_session" | awk '{print $7}')
    log "Active graphical session found: user='$session_user' tty=$session_tty. Not restarting SDDM."
    exit 0
fi

# --- Restart SDDM ---
# No graphical session = we're at the SDDM greeter with a blank screen.
# Restart SDDM to spawn a new Xorg that probes the display again.
log "No active graphical session. Restarting SDDM to force display reprobe..."
systemctl restart sddm
log "SDDM restarted. New Xorg should detect the monitor."
