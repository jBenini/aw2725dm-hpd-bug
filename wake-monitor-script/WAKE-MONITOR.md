# Wake-Monitor: Automatic SDDM Restart for AW2725DM HPD Bug

## What this does

Automatically restarts SDDM when the Alienware AW2725DM monitor is powered on **after** the login screen has already loaded. This solves the "No Signal" blank screen scenario without requiring a blind login (Enter → password → Enter).

---

## The Problem (recap)

The AW2725DM has a firmware defect: it **never** sends the HPD (Hot Plug Detect) signal on DisplayPort PIN 18 when powered on after the GPU has completed its initial probe. The GPU waits forever for HPD; the monitor shows "No Signal on DisplayPort."

The SDDM greeter probes the display **once** at startup. If the monitor isn't on at that exact moment, the screen stays blank forever — no retry, no fallback.

---

## The Solution

The monitor's internal USB hub **does** reconnect when powered on. We use this as a proxy trigger:

```
Monitor powers on
    │
    ▼
USB hub reconnects → Realtek HID (0bda:1101) enumerates
    │
    ▼
udev rule detects → fires systemd service
    │
    ▼
Script: cooldown → wait 5s → check kwin_wayland → check tty2 session → restart SDDM
    │
    ▼
New Xorg probes display → finds monitor → login screen appears ✓
```

---

## Files

### 1. `99-wake-monitor.rules`

**Location:** `/etc/udev/rules.d/99-wake-monitor.rules`

**What it does:** Tells udev to fire `wake-monitor.service` when the Realtek HID device (`0bda:1101`) appears on the USB bus.

**Key line:**
```udev
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="1101", ENV{SYSTEMD_WANTS}+="wake-monitor.service"
```

- `ACTION=="add"` — triggers when device is plugged in / enumerates
- `idVendor` / `idProduct` — matches the monitor's internal USB hub (Realtek HID)
- `ENV{SYSTEMD_WANTS}` — modern way to fire systemd services from udev (preferred over `RUN+=` because udev shouldn't run long scripts directly)

---

### 2. `wake-monitor.service`

**Location:** `/etc/systemd/system/wake-monitor.service`

**What it does:** Defines the systemd oneshot service that runs the recovery script.

**Key sections:**
```ini
[Unit]
Description=Restart SDDM when AW2725DM monitor powers on late
After=graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wake-monitor.sh
StandardOutput=journal
StandardError=journal
```

- `Type=oneshot` — runs once, exits
- `After=graphical.target` — ensures graphical stack is up before running
- `StandardOutput=journal` — logs go to `journalctl -u wake-monitor.service`

---

### 3. `wake-monitor.sh`

**Location:** `/usr/local/bin/wake-monitor.sh`

**What it does:** The actual recovery logic.

**Flow:**

| Step | What happens | Why |
|------|-----------|-----|
| 1. Cooldown | Checks `/tmp/.wake-monitor-last-run`, skips if <30s | USB hub enumerates 4 devices; prevents 4x firings |
| 2. Stabilize | `sleep 5` | DP link training needs time after monitor powers on |
| 3. Check kwin_wayland | `pgrep -u joao kwin_wayland` | If KWin is running, user is logged in → DON'T restart SDDM |
| 4. Check tty2 session | `loginctl list-sessions` looks for `seat0` + `tty2` | Fallback check for graphical session |
| 5. Restart SDDM | `systemctl restart sddm` | New Xorg probes display again, finds monitor |

**Critical checks:**

```bash
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

# No graphical session → stuck at SDDM → restart
systemctl restart sddm
```

**Why two checks?**

- `kwin_wayland` is the actual compositor process — most reliable indicator of an active KDE session
- `loginctl` with `tty2` is a fallback — but careful: `tty3`, `tty4` etc. are **text TTYs**, not graphical sessions. The original script checked `!= "tty1"` which gave false positives when the user had a text TTY open. The fix checks `== "tty2"` specifically.

---

## Installation

```bash
# 1. Copy files (from the repo)
sudo cp 99-wake-monitor.rules /etc/udev/rules.d/
sudo cp wake-monitor.service /etc/systemd/system/
sudo cp wake-monitor.sh /usr/local/bin/

# 2. Set permissions
sudo chmod 644 /etc/udev/rules.d/99-wake-monitor.rules
sudo chmod 644 /etc/systemd/system/wake-monitor.service
sudo chmod 755 /usr/local/bin/wake-monitor.sh

# 3. Reload
sudo udevadm control --reload-rules
sudo systemctl daemon-reload
```

---

## Testing

### Quick test (while logged in)

If you're already in a KDE session, the script should **not** restart SDDM:

```bash
# Unplug and replug the monitor's USB cable (or power cycle the monitor)
# Then check logs:
journalctl -u wake-monitor.service -n 20
```

Expected output:
```
[wake-monitor] kwin_wayland process found. KDE Plasma session is active. Not restarting SDDM.
```

### Full test (the real scenario)

1. **Reboot** the PC
2. At the SDDM login screen, **power off the monitor**
3. Wait 10 seconds
4. **Power on the monitor**
5. Wait ~10 seconds → login screen should appear automatically

---

## Debugging

### View logs

```bash
# Service logs
journalctl -u wake-monitor.service -f

# Script logs (via logger)
journalctl -t wake-monitor -f

# All together
journalctl -u wake-monitor.service -t wake-monitor -f
```

### Check if udev rule matches

```bash
# Find the Realtek HID device path
udevadm info --attribute-walk -n /dev/bus/usb/005/010 | grep -E "idVendor|idProduct"

# Test the rule (dry run)
udevadm test --action=add /sys/bus/usb/devices/5-2.1.3 2>&1 | grep SYSTEMD_WANTS
```

Expected: `SYSTEMD_WANTS=wake-monitor.service`

### Manual trigger

```bash
# Run the script manually to test
sudo /usr/local/bin/wake-monitor.sh

# Check exit code
echo $?
```

### Common issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Nothing happens | udev rule not matching | Check `lsusb` for `0bda:1101`; verify rule syntax with `udevadm verify` |
| "kwin_wayland process found" but I'm at SDDM | kwin_wayland still running from crashed session | Wait for session to fully terminate, or manually `pkill kwin_wayland` |
| "Active graphical session" on tty3/tty4 | Text TTY falsely detected as graphical | **Fixed in v2**: script now checks `tty2` specifically, not `!= tty1` |
| SDDM restarts but no image | Monitor not fully stabilized | Increase `STABILIZE_SECS` from 5 to 10 |
| Multiple restarts | Cooldown not working | Check `/tmp/.wake-monitor-last-run` exists and is writable |
| "Authorization required" / "Can't open display" | Old script version with xrandr/xdotool | **Fixed in v2**: removed all X11 tool dependencies |

---

## Removal

```bash
sudo rm /etc/udev/rules.d/99-wake-monitor.rules
sudo rm /etc/systemd/system/wake-monitor.service
sudo rm /usr/local/bin/wake-monitor.sh
sudo udevadm control --reload-rules
sudo systemctl daemon-reload
```

---

## Why this works (technical)

The AW2725DM's firmware bug is electrical: no HPD signal = no link training = no image. This is a **hardware defect** that cannot be fixed in software.

However, the monitor **does** power on its internal USB hub. The USB subsystem is independent of DisplayPort — it works even when DP is silent. By using USB enumeration as a proxy for "monitor is now on," we can trigger a display reprobe at the right moment.

The SDDM greeter's single-probe behavior is the second half of the problem. Restarting SDDM forces a fresh Xorg instance with a fresh probe — this time the monitor is actually ready.

---

## Limitations

- **Does not fix the root cause** — Dell firmware still doesn't send HPD
- **Does not work if monitor is on before boot** — that's already working (POST probing)
- **Does not work if USB hub is disabled in monitor OSD** — check monitor settings
- **kwin_wayland check assumes user `joao`** — if running under a different user, adjust the `pgrep -u` argument
- **tty2 check is a heuristic** — if SDDM is configured to use a different VT for user sessions, adjust the awk filter


## Log catching
   Se quiser acompanhar os logs em tempo real durante o teste (via SSH do celular ou outro PC):
    
    bash
    journalctl -t wake-monitor -f
    
    
    Ou depois do teste:
    
    bash
    journalctl -u wake-monitor.service -n 30 --no-pager
    journalctl -t wake-monitor -n 30 --no-pager
    

---

## Changelog

### v2 — July 17, 2026
- **Removed** all X11 tool dependencies (`xrandr`, `chvt`, `xdotool`) — they caused "Authorization required" errors when running as root from udev
- **Added** `pgrep -u joao kwin_wayland` as primary session detection (more reliable than `loginctl`)
- **Fixed** `loginctl` check: changed from `!= "tty1"` (false positives on text TTYs) to `== "tty2"` (specific to graphical session)
- **Simplified** to single action: `systemctl restart sddm` — no more escalation ladder

### v1 — July 17, 2026
- Initial version with escalation: xrandr → TTY switch → SDDM restart
- Failed due to X11 authorization issues in udev context

---

## References

- [DisplayPort HPD on Wikipedia](https://en.wikipedia.org/wiki/DisplayPort)
- [Full bug analysis README](/home/joao/git_repo/aw2725dm-hpd-bug/README.md)
- Monitor firmware: M2C103 (updated via Dell tool on Windows VM)
