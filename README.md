# The Display issue after a later power-on of Alienware AW2725DM
Last update: July 17, 2026.

# Disclaimer -> Why this configuration necessary? Where should be applied?

## **TLDR:** 
After long log collecting and tests I discovered that the fault is divided by:
- 70% for Dell, for not following DisplayPort's standards entirely,
- 20% for DisplayPort protocol, due fragile structure.
- 10% for NVIDIA, due Linux driver issues.

I couldn't find a solution, so I had to get a mechanism for the Kernel send a signal via GPU port to warn the Monitor to display the signal, in case if there is a blank screen and a message "*No signal on DisplayPort*".

## Hardware overview

I have an Alienware monitor model AW2725DM, it can show images in 2K (1440p) with 180Hz frequency, DisplayPort 1.4 interface, a 1440p high-end monitor for 2026.
Also in my computer runs Arch Linux, with CachyOS Kernel:

```shell
❯ uname -r
7.1.3-2-cachyos
```

It's important to mention that the GPU Card is a NVIDIA RTX 5070TI, also the processor is AMD Ryzen 7 9800X3D, Motherboard MSI X870 Tomahawk (with updated UEFI firmware), 64GB RAM splitted in 2 sticks model G.Skill Trident Z5 Neo RGB DDR5 - 6000MHz CL30.

```shell
sudo dmidecode -s bios-version
[sudo] password for user: 
1.A82 # Actual firmware version installed for Motherboard's UEFI.
```

I have an annoying issue: the monitor and the desktop have handshake problem via DisplayPort, showing a failure to display image if it the following procedure couldn't be followed:
1) Power on the Alienware AW2725DM monitor.
2) Power on the Desktop.

If I power on the desktop and, for milliseconds later I power on the monitor, it cannot display the image of POST/UEFI, also don't show image during the boot and the login screen, forcing me to power off the desktop and power on again. (Or reboot it)

## Knowing the scenario

In my Arch Linux have both display servers: Xorg and Wayland.
When the SDDM starts, it runs via TTY1, using Xorg. After a successfull login, it switches to TTY2, in which runs a KDE Plasma via Wayland.
For TTY3 to TTY6, is pure terminal.

| VT | Purpose | Display Server | Process |
|----|---------|---------------|---------|
| **tty1** | SDDM greeter (login screen) | **Xorg** (`:0`) | `/usr/lib/Xorg -seat seat0 vt1 -auth /run/sddm/xauth_*` |
| **tty2** | KDE Plasma user session | **Wayland** (KWin) | `kwin_wayland --xwayland` + `Xwayland :1` |
| **tty3-6** | Text terminals | None (fbcon) | `` |

### Evidences of the existence for both display servers in one Linux Installation

#### From 'ps'
```shell
root  /usr/lib/Xorg -seat seat0 vt1 -auth /run/sddm/xauth_xxIFZi -noreset
user  /usr/bin/kwin_wayland --xwayland-display :1 --xwayland-xauthority /run/user/1000/xauth_*
user  /usr/bin/Xwayland :1 -auth /run/user/1000/xauth_* -rootless
```

#### From 'loginctl'
```shell
SESSION  UID USER SEAT  LEADER CLASS   TTY  IDLE SINCE
      2 1000 joao seat0 1242   user    tty3 no   -
      4 1000 joao seat0 2099   user    tty2 no   -  ← KDE Plasma session
```

#### From SDDM logs.
```shell
sddm-helper: Jumping to VT 2
sddm-helper: VT mode didn't need to be fixed
```


## Troubleshoot attempts

At first I suspected that the problem was cold boot issue caused by AMD Expo settings at BIOS, I've made several adjustments, but no success, then I noted that the problem is not with RAM memory, CPU, GPU, etecetera.

Then I checked the GRUB's settings to check if there's a resolution conflict issue, but the file ```/etc/default/grub``` was already properly configured, with following line: 
```GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 rd.udev.log_level=3 pci=noaer nvidia_drm.modeset=1 nvidia_drm.fbdev=1 vt.global_cursor_default=0"```
The UEFI configuration also is properly adjusted:
```
Re-Size BAR support Enabled
Above 4G Memory Enabled
Initiate Graphic Adapter: PEG
HybridGraphics: Disabled
```

I contacted MSI's technical support to check if it was cold boot issue that makes the problem to display video, but after some confirmations, it's ok from motherboard side.

Then I tried to change the GPU's Displayport from DP-1 to DP-2 port, but the problem didn't solved it either.

The next step is to check the monitor's firmware and check if there is an update at Dell webpage.
I had to create a Win10 virtual machine only to download the file ```Alienware_AW2725DM_FWUpdate_M2C103_Windows.exe``` and apply it on monitor. The previous firmware installed on monitor was M2C102. After several minutes the new firmware version M2C103 have been installed successfully, then I restarted the tests, and I noticed that the handshake issue between the monitor and CPU have changed very little: now I can power on the desktop and power on the monitor, **BUT** until the POST finishes the process. If I poweron the monitor after the login screen appears, the monitor cannot display any image yet.

The next step is to run some system info and check system logs and find a root problem for this problem.
```shell
❯ kscreen-doctor -o

Output: 1 DP-2 0c5db3c4-da28-4807-83ce-b1d36e5ff689
        enabled
        connected
        priority 1
        DisplayPort
        replication source:0
        Modes:  1:2560x1440@59.95!  2:2560x1440@179.85*  3:2560x1440@164.96  4:2560x1440@143.97  5:2560x1440@120.00  6:1920x1080@119.88  7:1920x1080@60.00  8:1920x1080@59.94  9:1920x1080@50.00  10:1680x1050@59.95  11:1280x1024@75.03  12:1280x1024@60.02  13:1440x900@59.89  14:1280x960@60.00  15:1280x800@59.81  16:1152x864@75.00  17:1280x720@60.00  18:1280x720@59.94  19:1280x720@50.00  20:1024x768@75.03  21:1024x768@60.00  22:800x600@75.00  23:800x600@60.32  24:720x576@50.00  25:720x480@59.94  26:640x480@75.00  27:640x480@59.94 
        Custom modes: None
        Geometry: 0,0 2560x1440
        Scale: 1
        Rotation: 1
        Overscan: 0
        Vrr: Never
        RgbRange: unknown
        HDR: enabled
                SDR brightness: 210 nits
                SDR gamut wideness: 0%
                Peak brightness: 418 nits, overridden with: 400 nits
                Max average brightness: 418 nits
                Min brightness: 0.1244 nits
                HDR color profile source: EDID
                HDR ICC profile: none
        Wide Color Gamut: enabled
        ICC profile: none
        Color profile source: sRGB
        Color power preference: prefer accuracy
        Brightness control: supported, set to 100% and dimming to 100%
        DDC/CI: allowed
        Color resolution: unknown
        Allow EDR: unsupported
        Sharpness control: unsupported
        Automatic brightness: unsupported
        Auto Rotate Policy: incapable
        Adaptive backlight modulation: unsupported
```

```shell
dmesg -w 
... # several irrevelant info
nvidia 0000:01:00.0: [drm] Cannot find any crtc or sizes
... # more irrelevant info
```

```shell
sudo dmesg -w -T

# About the following result: it confirms that the Linux system detects that the Realtek HID (KVM of Alienware AW2725DM) has powered off and power on,
# confirming that there the Keyboard and mouse connected directly on monitor has been re-detected after the monitor's power on. But there is no line 
# about drm, nvidia, anything else about video display, confirming that the monitor don't send any signal from displayport to the GPU saying that he is 
# on and available to display image.

[seg jul 13 23:09:34 2026] usb 5-2.1: USB disconnect, device number 3
[seg jul 13 23:09:34 2026] usb 5-2.1.1: USB disconnect, device number 5
[seg jul 13 23:09:34 2026] usb 5-2.1.2: USB disconnect, device number 7
[seg jul 13 23:09:34 2026] usb 5-2.1.3: USB disconnect, device number 6
[seg jul 13 23:09:36 2026] usb 5-2.1: new high-speed USB device number 8 using 
xhci_hcd
[seg jul 13 23:09:36 2026] usb 5-2.1: New USB device found, idVendor=0bda, 
idProduct=5409, bcdDevice= 1.30
[seg jul 13 23:09:36 2026] usb 5-2.1: New USB device strings: Mfr=1, Product=2, 
SerialNumber=0
[seg jul 13 23:09:36 2026] usb 5-2.1: Product: USB2.1 Hub
[seg jul 13 23:09:36 2026] usb 5-2.1: Manufacturer: Generic
[seg jul 13 23:09:36 2026] hub 5-2.1:1.0: USB hub found
[seg jul 13 23:09:36 2026] hub 5-2.1:1.0: 3 ports detected
[seg jul 13 23:09:37 2026] usb 5-2.1.1: new full-speed USB device number 9 using 
xhci_hcd
[seg jul 13 23:09:37 2026] usb 5-2.1.1: New USB device found, idVendor=1b1c, 
idProduct=1b75, bcdDevice= 3.14
[seg jul 13 23:09:37 2026] usb 5-2.1.1: New USB device strings: Mfr=1, 
Product=2, SerialNumber=3
[seg jul 13 23:09:37 2026] usb 5-2.1.1: Product: CORSAIR HARPOON RGB PRO Gaming 
Mouse 
[seg jul 13 23:09:37 2026] usb 5-2.1.1: Manufacturer: Corsair
[seg jul 13 23:09:37 2026] usb 5-2.1.1: SerialNumber: 
1002701DAFBC8806633FB238F5001C04
[seg jul 13 23:09:37 2026] input: Corsair CORSAIR HARPOON RGB PRO Gaming Mouse 
as 
/devices/pci0000:00/0000:00:08.1/0000:73:00.3/usb5/5-2/5-2.1/5-2.1.1/5-2.1.1:1.0 
/0003:1B1C:1B75.0011/input/input25
[seg jul 13 23:09:37 2026] input: Corsair CORSAIR HARPOON RGB PRO Gaming Mouse 
as 
/devices/pci0000:00/0000:00:08.1/0000:73:00.3/usb5/5-2/5-2.1/5-2.1.1/5-2.1.1:1.0 
/0003:1B1C:1B75.0011/input/input26
[seg jul 13 23:09:37 2026] input: Corsair CORSAIR HARPOON RGB PRO Gaming Mouse 
as 
/devices/pci0000:00/0000:00:08.1/0000:73:00.3/usb5/5-2/5-2.1/5-2.1.1/5-2.1.1:1.0 
/0003:1B1C:1B75.0011/input/input27
[seg jul 13 23:09:37 2026] hid-generic 0003:1B1C:1B75.0011: 
input,hiddev96,hidraw1: USB HID v1.11 Mouse 
[Corsair CORSAIR HARPOON RGB PRO Gaming Mouse] on 
usb-0000:73:00.3-2.1.1/input0
[seg jul 13 23:09:37 2026] hid-generic 0003:1B1C:1B75.0012: hiddev97,hidraw2: 
USB HID v1.11 Device [Corsair CORSAIR HARPOON RGB PRO Gaming Mouse] on 
usb-0000:73:00.3-2.1.1/input1
[seg jul 13 23:09:37 2026] usb 5-2.1.3: new high-speed USB device number 10 
using xhci_hcd
[seg jul 13 23:09:37 2026] usb 5-2.1.3: New USB device found, idVendor=0bda, 
idProduct=1101, bcdDevice= 1.01
[seg jul 13 23:09:37 2026] usb 5-2.1.3: New USB device strings: Mfr=1, 
Product=2, SerialNumber=0
[seg jul 13 23:09:37 2026] usb 5-2.1.3: Product: HID Device[seg jul 13 23:09:37 
2026] usb 5-2.1.3: Manufacturer: Realtek
[seg jul 13 23:09:37 2026] hid-generic 0003:0BDA:1101.0013: hiddev98,hidraw3: 
USB HID v1.11 Device [Realtek HID Device] on usb-0000:73:00.3-2.1.3/input0
[seg jul 13 23:09:37 2026] usb 5-2.1.2: new full-speed USB device number 11 
using xhci_hcd
[seg jul 13 23:09:37 2026] usb 5-2.1.2: New USB device found, idVendor=1b1c, 
idProduct=1bad, bcdDevice= 4.15
[seg jul 13 23:09:37 2026] usb 5-2.1.2: New USB device strings: Mfr=1, 
Product=2, SerialNumber=3
[seg jul 13 23:09:37 2026] usb 5-2.1.2: Product: CORSAIR K60 RGB PRO Low Profile 
Mechanical Gaming Keyboard
[seg jul 13 23:09:37 2026] usb 5-2.1.2: Manufacturer: Corsair
[seg jul 13 23:09:37 2026] usb 5-2.1.2: SerialNumber: 
14021013AF7BA4C85F7F0F3EF5001BC6
[seg jul 13 23:09:38 2026] input: Corsair CORSAIR K60 RGB PRO Low Profile 
Mechanical Gaming Keyboard as 
/devices/pci0000:00/0000:00:08.1/0000:73:00.3/usb5/5-2/5-2.1/5-2.1.2/5-2.1.2:1.0 
/0003:1B1C:1BAD.0014/input/input28
[seg jul 13 23:09:38 2026] hid-generic 0003:1B1C:1BAD.0014: input,hidraw4: USB 
HID v1.11 Keyboard [Corsair CORSAIR K60 RGB PRO Low Profile Mechanical Gaming 
Keyboard] on usb-0000:73:00.3-2.1.2/input0
[seg jul 13 23:09:38 2026] hid-generic 0003:1B1C:1BAD.0015: hiddev99,hidraw5: 
USB HID v1.11 Device [Corsair CORSAIR K60 RGB PRO Low Profile Mechanical Gaming 
Keyboard] on usb-0000:73:00.3-2.1.2/input1
[seg jul 13 23:09:38 2026] hid-generic 0003:1B1C:1BAD.0016: hiddev100,hidraw6: 
USB HID v1.11 Device [Corsair CORSAIR K60 RGB PRO Low Profile Mechanical Gaming 
Keyboard] on usb-0000:73:00.3-2.1.2/input2
[seg jul 13 23:09:38 2026] input: Corsair CORSAIR K60 RGB PRO Low Profile 
Mechanical Gaming Keyboard as 
/devices/pci0000:00/0000:00:08.1/0000:73:00.3/usb5/5-2/5-2.1/5-2.1.2/5-2.1.2:1.3 
/0003:1B1C:1BAD.0017/input/input29
[seg jul 13 23:09:38 2026] hid-generic 0003:1B1C:1BAD.0017: input,hidraw7: USB 
HID v1.11 Mouse [Corsair CORSAIR K60 RGB PRO Low Profile Mechanical Gaming 
Keyboard] on usb-0000:73:00.3-2.1.2/input3

```

The next process will be really crucial and confirm the real cause of Handshake problem, but since I had to power off both desktop and monitor, then power on the desktop and power on the monitor several minutes later, enough to systemid finishes all the loading of the modules to show up the login screen, I had to access my computer via SSH. So I used the APP Haven from my Android Smartphone to run the command, printing the result not on the screen, since this one will be blank due the problem, but from a file...

```shell
# Via SSH
journalctl -k -b 0 --no-pager > ~/teste-cold-boot-completo.log
wc -l ~/teste-cold-boot-completo.log
grep -iE "hotplug|link.train|EDID|connector|drm.*DP|amdgpu.*DP|nvidia" ~/teste-cold-boot-completo.log
```

I will provide the file ```teste-cold-boot-completo.log``` but I anticipate and confirm that the file don't show any info about ```nvidia, gpu, video```, or monitor/screen related.

## The EDID Override attempt

My last attempt was to configure an EDID override, to manually force the NVIDIA GPU to always assume a monitor is connected on DP-2, regardless of 
the real HPD signal.

### Steps taken

1. Captured the real EDID while the monitor was on:
```shell
sudo cp /sys/class/drm/card1-DP-2/edid /usr/lib/firmware/edid/aw2725dm-dp2.bin
```
2. Added the file to the initramfs via `/etc/mkinitcpio.conf`:
FILES=(/usr/lib/firmware/edid/aw2725dm-dp2.bin)

3. Added the kernel parameter `drm.edid_firmware=DP-2:edid/aw2725dm-dp2.bin` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, then regenerated 
both the initramfs (`mkinitcpio -P`) and the GRUB config (`grub-mkconfig`).

### First obstacle: the parameter never reached the kernel

Even after confirming the file was correctly packed inside the initramfs, since the command `lsinitcpio ... | grep edid` found it, `cat /proc/cmdline` after reboot never showed the parameter. Turns out my system has a custom GRUB script, `/etc/grub.d/06_cachyos_first` (created months earlier to fix an unrelated GRUB kernel-priority bug), which hardcodes its own copy of the kernel command line — completely bypassing `/etc/default/grub`. The EDID 
parameter was landing in the *other* boot entries, not the default one actually being booted. Fixed by editing that script directly, which file is /etc/grub.d/06_cachyos_first.

### Second obstacle: NVIDIA's proprietary driver ignores `drm.edid_firmware` alone

With the parameter confirmed active in `/proc/cmdline`, the monitor still showed no image, and `dmesg` showed no firmware-load message for the EDID 
at all — not even a failure message. This is a known limitation: `drm.edid_firmware` is implemented through the generic `drm_kms_helper` code path used by open-source drivers (`amdgpu`, `nouveau`, `i915`), but NVIDIA's proprietary driver has its own closed connector-probing implementation that doesn't honor it on its own. The fix requires an additional parameter to force the connector enabled: ```video=DP-2:e```

### Final result: still no image on late power-on

With both `drm.edid_firmware=DP-2:edid/aw2725dm-dp2.bin` and `video=DP-2:e` active and confirmed in `/proc/cmdline`, the monitor **still** didn't 
display any image when powered on well after the login screen appeared.

My working theory: an EDID override can convince the *software* that a monitor is present, but it cannot substitute for the physical DisplayPort 
link training process — a real electrical negotiation between the GPU and the monitor's receiver chip. Earlier logs already confirmed my monitor fully cuts power when turned off (the internal USB hub does a full disconnect/reconnect cycle), so there's simply no powered receiver 
on the other end for the GPU to negotiate with, no matter what the kernel is told to assume. This is a hardware-level limitation that no 
software workaround can bypass.

### Decision: reverted

Given the added complexity (a persistent EDID file, an extra kernel parameter, and a workaround-of-a-workaround for NVIDIA) without actually 
solving the late-hotplug scenario, I reverted this configuration. The firmware update (M2C103) already fixed the scenario that mattered most 
to my daily use (cold boot with both devices powered on together); the late-hotplug edge case remains unresolved and is, in my assessment, a 
genuine hardware/firmware defect on Dell's side that no client-side workaround can fully patch.

## Attempt to contact Dell and new discovers.

I tried to contact Dell's offical technical support, but they do a little care about this matter (it was predictable anyway), but at Dell Community the Dell support team tries his best.
At this moment they requested for me to look at monitor's OSD menu something similar for "Deep Sleep", "Auto Source Input" or "Power Saving", but I found only on OSD the path "Menu -> Entry Source -> Auto selection -> Set to off", but it didn't worked. I replied them and I'm awaiting news from their side.

### But something odd happened!

Since after changing the Entry Source as Off didn't give a different result, with the monitor showing no signal, I decide to act different: instead power off and power on again the desktop button, I changed to TTY3, still no image, but I pressed CTRL+ALT+F1 to change to TTY1, and the login screen appared. It make me see this problem with other point-of-view, and started to make new tests. To be honest I don't know exactly how the SDDM appeared, since I just pressed CTRL+ALT+F1 a few times, and I tried to repeat it but the next tests gave me different results.

I made another reboot, turned off the monitor and waited time enough to SDDM (KDE Plasma's Login Screen) start it's service and then power on the monitor, but happened a different behaviour:

#### First behaviour: 
Monitor without image on TTY1, switched to TTY3, still no imagem tried to log in blindly (since AW2725DM cannot show any image), but after a time I could see the screen, but I inputed my password incorrectly 3 times, then Arch Linux blocked my users for a time. After waiting this time expires, I could use ```sudo``` to run ```sudo chvt 1``` to return to TTY1 and see if SDDM is shown to me. Unfortunately no success, I returned to TTY3 and inputed ```reboot```.

#### Second behaviour: 
after the previous failure, I left my monitor powered on. The plan is to remember the keys to select my user and input the password on SDDM to log in even if the monitor is blank. I noticed that pressing 'ENTER' selects my user and I input the password and press 'ENTER' again, so I can log into my desktop. After remembering the process to log in using keyboard only I rebooted, powered off the monitor and powered on after SDDM is running, since the monitor didn't show any image, I used my memory to remember press 'ENTER', input password, press 'ENTER' again, and my desktop is shown. It's good, since I discovered that I don't need anymore to power off and power on the desktop to make the monitor show image: something between SDDM's sucessfull login and the exhibit of KDE's desktop is responsible to refresh the signal to the monitor, making it display the image. Now I need to figure what's the cause.

It oonfirms that the authentication via **Kwin/Wayland compositor** starting up, performing a modeset, changing to TTY1 (SDDM using Xorg Desktop Server) to TTY2 (KDE Plasma using Wayland desktop server).

##### The Steps when SDDM authenticates the user:

1. `sddm-helper` starts the Wayland session (`startplasma-wayland`)
2. `kwin_wayland` launches as the compositor
3. KWin **takes over DRM/KMS** from the SDDM Xorg
4. KWin performs a **modeset** — configuring the display pipeline with the correct resolution, refresh rate, and timings
5. This modeset triggers a **new DisplayPort link training** — which the monitor responds to (it's now powered on)

The key insight: **the monitor doesn't respond to HPD, but it DOES respond to a fresh link training attempt**. KWin's modeset is essentially a "brute force" display reinitialization that bypasses the missing HPD signal.

According to the information I've got, when KDE session assumes the system, it's composition (KWin) makes the modeset and assumes the DRM (Digital Rights Management), but how? If I discover, I can create a mechanism to refresh the signal to SDDM to force the display of the image when I power on the monitor after the login sesession is ready.

Before it I had to make to make more tests and catch logs to figure what's happening.

####  First test
'META+L' with monitor powered on -> Return to SDDM. (It was obvious this result, but I wanna do this test to document it here.)

#### Second test
Open the terminal, run the command ```sleep 1 && loginctl lock-session``` and press 'ENTER', immediately I power off the monitor and wait some seconds, and I power on, the SDDM screen appeared to me.

This second test is odd, when the monitor is powered off: 
- SDDM runs at first time after boot, it don't show image when I power on the monitor after.
- SDDM is shown after 'META+L' since the desktop is running, the monitor can show image.

The difference is the SDDM Greeter looks it makes only one probing, without persistent retries. As evidenced on the message ```[drm] Cannot find any crtc or sizes``` after ran ```dmesg -w```, one attempt, no retry.
So, If SDDM Gretter don't persist to send signal to the monitor, but an opened session can show the monitor's image even I power off and power on, maybe the solution is to restart SDDM daemon, on TTY3, running ```sudo systemctl restart sddm```.
Probably the timing to DP link to stabilize was crucial to show up the screen.
When the screen shows TTY4, `dmesg -w` was running in the background — this doesn't directly affect display, but may have kept the system slightly more active. When it returned to TTY1 automatically there is a chance that SDDM restarted trigger a VT, switching back to tty1, which may have coincided with the new Xorg probe. The key variable is **when the monitor was powered on relative to the SDDM restart**. If the monitor is on and stable before SDDM restarts, the new Xorg probe finds it.

At this moment I will run dmesg with new parameters on TTY3, when I recriate the faulty no-screen scenario:
```sudo dmesg -w -T | tee ~/login-trigger-test.log```, return to TTY1 and find something about ```drm, nvidia, crtc, modeset```.
I've made 3 attempts, each one generating a new log files ```login-trigger-test1.log``` and ```login-trigger-test2.log```, but all these 3 tests I could not see image on TTY1 when I return it, even pressing 'ENTER' and input password.

Then I've made an fourth attempt: rebooted the PC, powered off the monitor, powered on again after SDDM login -> no screen (as expected) -> changed to TTTY3 and login with my user, run the command ```sudo dmesg -w -T | tee ~/login-trigger-test3.log``` (notice the number 3 before the '.log'), opened TTY4, run ```sudo systemctl restart sddm```, returned automatically to TTY1, I've pressed 'ENTER', inputed the password, and pressed 'ENTER' again. It entered on my desktop screen.

This obstacle looks like NVIDIA driver + VT Switching have problem to return the "DRM Master" from different TTYs, which escalates this problem in new ways. But it don't minimize the Dell's product failure to send a signal via PIN_18 on displayport to the GPU (HPD faulty).

### What these behaviours and tests mentioned before revealed?

Restarting SDDM Daemon plus returning to TTY1 logging in blindly gave me some a good trail, also the ```login-trigger-test``` logfiles gave me something important than the previous ```dmesg``` and ```journalctl```, in which there was silence: These workaround between TTYs and attempt to login without screen makes the GPU tries to display video for real.

According to ```login-trigger-test``` logfiles, the NVIDIA driver enters in a loop of recurrent faulty for each 17 ~ 30 seconds, it tries to show image, without success:

```shell
Failed to query display engine channel state # GPU recognize the monitor, even cannot complete the link via Displayport.
Lost display notification
Failed to query default adaptivesync listing for Dell AW2725DM (DP-2) # NOW IT DETECTS THE MONITOR MODEL!!! AN IMPORTANT PROGRESS!!!
Flip event timeout on head 0
nvidia-modeset: WARNING: GPU:0: Failure processing EDID for display device Dell AW2725DM (DP-2). # Now it shows what happened during EDID.
nvidia-modeset: WARNING: GPU:0: Unable to read EDID for display device Dell AW2725DM (DP-2)
nvidia-modeset: ERROR: GPU:0: Failure reading maximum pixel clock value for display device DP-2.
[drm:nv_drm_atomic_commit [nvidia_drm]] *ERROR* [nvidia-drm] [GPU ID 0x00000100] Flip event timeout on head 0 # Video commit timeout happening
Failed detecting connected display devices

```

This issue occurs repeatedly until I run `sudo systemctl restart sddm´.

Now I got an evidence that the Kernel tried a lot of times to display the signal, but since with EDID didn't show up the display, and complete the video flip/commit, there is an unstable eletric link via DisplayPort. Proving that this is not silence from indifference, but a genuine — and inconsistent — hardware negotiation failure: sometimes the link is never attempted, other times it's attempted repeatedly and fails partway through EDID/commit. This intermittency itself points to a marginal electrical link, not a clean software bug.

## Another attempt to find a palliative solution: triggerhappy (thd)

I'll download the package for triggerhappy via ```pacman```, create it's daemon and create a shortcut to send a signal to the video, in case there is no display.

```yay -S triggerhappy```

```sudo nvim /etc/triggerhappy/triggers.d/wake-monitor.conf ```

```wake-monitor.conf content
KEY_F9 1 /usr/local/bin/wake-monitor.sh
```

```sudo nvim /usr/local/bin/wake-monitor.sh```


```wake-monitor.sh content
#!/bin/bash
if ! loginctl list-sessions --no-legend | grep -q "seat0.*active"; then
    systemctl restart sddm
fi
```

```chmod +x /usr/local/bin/wake-monitor.sh```

``sudo systemctl enable --now triggerhappy.service```

### Testing triggerhappy

Now I had to reboot, power off the monitor and power on only the SDDM is up, then I press F9 and see if the screen appears on the monitor. I tested, no success. The monitor still refuses when powered on later.

**Update**: It was noticed that the script ```wake-monitor.sh``` have 1 flaw:

```grep -q "seat0.*active"``` looks for the word "active" in the loginctl output — but ```loginctl list-sessions``` doesn't have an "active" column in its default output. This check would **always fail** (grep finds nothing), meaning the script would **always restart SDDM**, even when the user was logged in.


## Last attempt: wake-monitor script.

Inside this repo there is a folder called *wake-monitor-script*, in which detects automatically if the monitor is power on, check if the USB Hub from AW2725DM is working, using **udev rule**, then runs a script via **systemd** for the monitor shows up the screen 5 seconds later, also checks if users is already logged in or not.
In case is not logged, then SDDM is restarted, run a new Xorg probe and finds the monitor.

The scripts avoids the blind login, also there is no X11 authorization issues, runs automatically.

### How it works.

If monitors power on, then USB hub reconnects, *Realtek HID (0bda:1101)* will be enumerated, then udev rule detect it and triggers the systemd's wake-monitor service, running a script, in which wait 5s, check kwin_wayland and it's TTY2 session is running, then don't restart SDDM session, else if it's on SDDM they try to restart it. (obs: this script have 30s cooldown).

## Results of this attempt

I tried 2 reboots, both of them, when I powered on the monitor when SDDM already running, but didn't showed the screen in both attempts.
I changed to TTY3 and run ```journalctl -t wake-monitor -n 30 --no-pager``` and the script ran well: detected the USB Hub and send the signal properly to the monitor, but yet the screen don't show up.

I left this script on wake-monitor-script/ inside this repo for reference, also there is a document, WAKE-MONITOR.sh, for understand how it works.

## CONCLUSION

During POST, the firmware repeatedly probes the video output in a loop, which is tolerant enough to catch the Hot-Plug Detect (HPD) signal even with imperfect timing. If the monitor is already up, the 'handshake' occurs properly and the screen will be shown to me.
After the AW2725DM's upgrade to version M2C103 it will show during POST as well.
When the Linux system is up and ready to be used, it load the NVIDIA module, probing if there is a monitor powered on the GPU's ports, in negative case the system keeps steady and waiting for a monitor to send a signal to confirm the availability, since the last commands I run, ```sudo dmesg -w -T```, ```journalctl -k -b 0 --no-pager > ~/teste-cold-boot-completo.log```, ```wc -l ~/teste-cold-boot-completo.log```, and ```grep -iE "hotplug|link.train|EDID|connector|drm.*DP|amdgpu.*DP|nvidia" ~/teste-cold-boot-completo.log```, confirm that the monitor **NEVER** send a signal to the GPU, depending only from the goodwill of the Operating System's Driver to call it, the monitor don't show any image, if it don't power on during booting process, one of the major evidences of this issue is the line ```[drm] Cannot find any crtc or sizes``` obtained during ```dmesg -w```.

## Why in MS Windows this problem never occur:

Windows' WDDM (Windows Display Driver Model) has, by its own design, periodic polling of display outputs as a fallback beyond hotplug interrupts — a general defensive behavior that happens to mask this class of hardware/firmware bugs, not a fix built specifically for this matter. This is likely why end users rarely notice HPD reliability issues like this one on Windows.

## So, at this moment, what I can figure?

For my point-of-view and all the troubleshoot attempts, with data collecting from the logs, I can say that the **Dell Technologies** have the big slice of this responsibility, since the monitor **NEVER** send a signal from the DisplayPort to the other-end and establish a 'handshake' between the devices and display the image to the user. They are well comfortable that Microsoft already created a solution from their side called WDDM, ignoring the fact that the monitor is simply sluggish.
According to the DisplayPort Standards, the PIN number 18, also called Hot Plug Detect(HPD), it's used to send signal to the other side to confirm that the monitor is powered and ready to display any image. 
Source: [DisplayPort on Wikipedia](https://en.wikipedia.org/wiki/DisplayPort)

Also on [DisplayPort search results for Alienware monitors](https://www.displayport.org/product-category/monitors-tvs/?ps=alienware), from today, July 14, 2026, there is no **AW2725DM** on the results, suggesting that this monitor (though not conclusively proving) may not be listed on VESA's certified products database since I wrote this README.

Another slice goes to NVIDIA, for the Linux Driver still has issues, as I've discovered and registered in this document. Thanks to understand the issue of the Driver I can figure how to find another palliative solution, since EDID didn't worked. 

### To be clear: Why Dell bears the most responsibility?

Alienware is a released product from the manufacture with defects, from Design, Firmware, and Hardware, as explained on the 6 points below:

1. As I've said before: It's the responsible of the monitor to send the HPD signal via pin 18 to the GPU, but Alienware AW2725DM **NEVER** do this.
2. USB Hub (KVM) works well, AW2725DM's DisplayPort depends to receive the signal from GPU, since the HPD is faulty from this product due the design/firmware problem, not hardware limitation.
3. Upgrading to M2C103 firmware helped a little, since the late hotplug still doesn't work. (when SDDM opens up) Why Dell's engineering team didn't address this properly remains unclear!
4. Windows WDDM do periodic polling, since Microsoft do the job that belongs to Dell, due to the laziness of the second.
5. There is a suspicion (have to be confirmed) that AW2725DM does not appear as a certified product at displayport.org.
6. EDID override + video=DP-2:e didn't worked: even forcing the software displays the image to the monitor when this one is powered later, the link training fails, since the monitor's receptor is not powered. And this item shows a hardware failure.

## And now, how to deal with this problem?

I'm not very confident that Dell will take a real action for my cause, since Linux's marketshare is really tiny and it won't cause any problem on the profits of this manufacturer, so, it was left for me to accept that it's a problem without solution until now. NVIDIA already opened the code of the GPU drivers, so I had to find on the Linux community how to solve in GPU side.

Since I couldn't find any solution, definitive or palliative, for me I must log in blindly on SDDM when I forget to power on the monitor before SDDM appears.
