# Recomendações para o Problema de Hot Plug Detect (HPD) — Alienware AW2725DM

> **Contexto:** Monitor Alienware AW2725DM com falha no sinal HPD (pino 18 do DisplayPort). O monitor não envia sinal de detecção ao GPU quando ligado após o boot, impedindo exibição de imagem no SDDM (Xorg). A sessão KDE Plasma (KWin/Wayland) consegue forçar o link training e mostrar imagem após login.
> 
> **Hardware:** NVIDIA RTX 5070 Ti, Arch Linux (CachyOS Kernel 7.1.3-2-cachyos), SDDM com Xorg no TTY1, KDE Plasma com KWin/Wayland no TTY2.

---

## ⚠️ Nota Importante

Você já tentou `drm.edid_firmware=DP-2:edid/aw2725dm-dp2.bin` + `video=DP-2:e` via parâmetro de kernel. **Isso não funciona com o driver NVIDIA proprietário** porque `drm.edid_firmware` é uma API do subsistema DRM/KMS open-source (`amdgpu`, `i915`, `nouveau`). O driver NVIDIA proprietário possui sua própria implementação de probing de displays e **não honra** esse parâmetro do kernel.

As recomendações abaixo focam em abordagens **diferentes** das que você já tentou, ordenadas do mais promissor ao mais experimental.

---

## 1. `ConnectedMonitor` + `CustomEDID` no xorg.conf (MAIS PROMISSOR)

O driver NVIDIA proprietário possui **sua própria API** para forçar EDID e conector ativo, via configuração do X11. Isso é diferente do `drm.edid_firmware` do kernel.

### Passos:

```bash
sudo mkdir -p /etc/X11/xorg.conf.d
sudo nvim /etc/X11/xorg.conf.d/10-nvidia-dp2.conf
```

### Conteúdo do arquivo:

```conf
Section "Device"
    Identifier     "NVIDIA0"
    Driver         "nvidia"
    Option         "ConnectedMonitor" "DP-2"
    Option         "CustomEDID" "DP-2:/usr/lib/firmware/edid/aw2725dm-dp2.bin"
    Option         "AllowEmptyInitialConfiguration" "true"
EndSection

Section "Monitor"
    Identifier     "DP-2"
    Option         "Enable" "true"
EndSection
```

### Por que isso pode funcionar onde o EDID do kernel falhou:

- O `CustomEDID` da NVIDIA é processado **dentro do driver proprietário** durante o link training.
- Ele pode forçar o driver a tentar negociar o link mesmo sem o sinal HPD.
- O `ConnectedMonitor` força o driver a tratar DP-2 como sempre conectado.

> **Ação:** Regenere o initramfs (`sudo mkinitcpio -P`) e reinicie. Teste ligar o monitor após o SDDM estar rodando.

---

## 2. SDDM rodando em Wayland nativo

Você descobriu que **KWin/Wayland funciona** — quando loga, o KWin faz um modeset e o monitor aparece. O SDDM, porém, está usando **Xorg** no TTY1. SDDM suporta Wayland nativo como backend.

### Passos:

```bash
sudo nvim /etc/sddm.conf
```

### Conteúdo:

```ini
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
```

### Alternativa mais simples (se pacote `sddm-wayland` estiver configurado):

```ini
[General]
DisplayServer=wayland
```

### Por que isso pode funcionar:

- Se o KWin da sua sessão usuário consegue forçar o link training e mostrar imagem, talvez o KWin do greeter também consiga.
- O Xorg do SDDM faz uma única tentativa de probing e desiste. O KWin/Wayland pode ser mais agressivo.

> **Atenção:** Certifique-se de ter o pacote `qt6-wayland` instalado. Faça backup do `sddm.conf` antes.

---

## 3. Polling no `Xsetup` do SDDM

Em vez de restartar o serviço SDDM inteiro (pesado e arriscado), use um **script de polling** dentro do contexto do Xorg do SDDM.

### Passos:

```bash
sudo nvim /usr/share/sddm/scripts/Xsetup
```

### Conteúdo:

```bash
#!/bin/bash
# Polling agressivo por 30 segundos
for i in {1..60}; do
    xrandr --output DP-2 --auto 2>/dev/null
    if xrandr | grep -q "DP-2 connected"; then
        break
    fi
    sleep 0.5
done
```

```bash
sudo chmod +x /usr/share/sddm/scripts/Xsetup
```

### Por que isso pode funcionar:

- O `Xsetup` roda **antes do greeter aparecer**, dentro do mesmo servidor X.
- Se o monitor for ligado durante esse loop, o `xrandr --auto` força um novo link training no momento certo.
- É mais leve que restartar o serviço SDDM inteiro.

---

## 4. `ddcutil` para acordar o receptor DP do monitor

O monitor pode ter o receptor DP em estado de deep-sleep que **não responde a link training** até receber um comando DDC/CI.

### Instalação:

```bash
sudo pacman -S ddcutil
sudo modprobe i2c-dev
```

### Teste manual (quando o monitor estiver ligado mas sem imagem):

```bash
# Lista displays DDC
sudo ddcutil detect

# Força "Power On" via DDC (VCP 0xD6)
sudo ddcutil setvcp 0xD6 0x01 --display 1

# Ou muda input source para DP (0x0F = DisplayPort)
sudo ddcutil setvcp 0x60 0x0F --display 1
```

### Integração no script udev existente:

Adicione ao seu script `/usr/local/bin/wake-monitor.sh` (ou similar):

```bash
#!/bin/bash
sleep 2
# Tenta acordar o receptor DP via DDC
sudo ddcutil setvcp 0xD6 0x01 --display 1 2>/dev/null
sleep 3
# Se não houver sessão ativa, restarta SDDM
if ! loginctl list-sessions --no-legend | awk '{print $5}' | grep -q "active"; then
    systemctl restart sddm
fi
```

> **Nota:** O VCP 0xD6 controla o power state do monitor. Isso pode acordar o receptor DP **antes** do link training do NVIDIA.

---

## 5. Testar com kernel stock Arch Linux

Você está no kernel `7.1.3-2-cachyos`. O CachyOS aplica **patches agressivos** de performance que podem afetar o timing do DRM/KMS e do driver NVIDIA.

### Passos:

```bash
sudo pacman -S linux linux-headers
```

Edite o bootloader para bootar o kernel stock (não precisa desinstalar o CachyOS, só selecionar na entrada do GRUB).

### Objetivo:

- Isolar se patches do CachyOS interferem no timing do modeset.
- Se o problema **sumir ou mudar** no kernel stock, é um patch do CachyOS.
- Se continuar igual, descarta essa variável.

---

## 6. Testar porta HDMI como diagnóstico

Se o AW2725DM tiver porta HDMI:

- HDMI tem HPD no pino 19, com especificação elétrica diferente do DP.
- Se o problema **não ocorrer no HDMI**, isola definitivamente que é a implementação DP do monitor.
- Se ocorrer no HDMI também, é um problema mais profundo de firmware do monitor.

> Isso fortalece seu caso de argumentação com a Dell.

---

## 7. Testar com driver Nouveau (diagnóstico)

Para **confirmar** se a culpa é do driver proprietário da NVIDIA:

### Passos:

1. Adicione ao GRUB:
   ```
   modprobe.blacklist=nvidia,nvidia_drm,nvidia_uvm,nvidia_modeset
   ```
2. Boot com o driver `nouveau` (open-source).
3. Teste o cenário de late hotplug.

### Interpretação:

- Se **funcionar com nouveau** → problema é o driver proprietário não fazer polling.
- Se **não funcionar** → problema é 100% o monitor.

> É só um teste de 10 minutos. Não precisa manter o nouveau.

---

## 8. Forçar DP 1.2 em vez de DP 1.4

O link training do DP 1.4 com DSC/HDR/180Hz é **muito mais complexo** e pode falhar silenciosamente quando o receptor do monitor acorda "tardio".

### Opções:

- No **NVIDIA Settings**, desabilite DSC e force DP 1.2.
- Ou no `xorg.conf`:
  ```conf
  Option "DP-2:DPMS" "false"
  ```

DP 1.2 @ 1440p144Hz é um link training mais simples e pode ser mais tolerante a timing ruim.

---

## 9. Solução de hardware: HPD pull-up / EDID Emulator

Se tudo mais falhar, a solução definitiva é forçar o HPD no nível elétrico.

### Opções comerciais:

| Opção | Descrição | Preço aprox. |
|-------|-----------|-------------|
| **DisplayPort Hotplug Maintainer (NTI)** | Dispositivo comercial que mantém HPD ativo | ~$80 |
| **Cabo DP com HPD forçado** (AliExpress/eBay) | Cabos com resistor pull-up interno | ~$15 |
| **EDID Emulator / Ghost Display** | Usado em setups de VM GPU passthrough | ~$10-30 |

### Solução DIY:

Um resistor de **10kΩ entre o pino 18 (HPD) e o pino 20 (DP_PWR, 3.3V)** no lado do cabo que entra na GPU.

- Corrente: ~0.18mA (sem risco de danos).
- A GPU vê o monitor como sempre conectado.
- O EDID ainda é lido normalmente via AUX channel.

> Você mencionou essa solução no seu README mas não a implementou.

---

## 📋 Resumo — Ordem de tentativa recomendada

| Ordem | Ação | Expectativa |
|-------|------|-------------|
| 1 | `xorg.conf` com `ConnectedMonitor` + `CustomEDID` | **Alta** — atua no driver NVIDIA propriamente dito |
| 2 | SDDM em Wayland nativo | **Alta** — KWin já provou funcionar na sessão usuário |
| 3 | Polling `xrandr` no `Xsetup` | **Média-Alta** — re-probing dentro do mesmo Xorg |
| 4 | `ddcutil setvcp 0xD6 0x01` no script udev | **Média** — pode acordar o receptor DP |
| 5 | Kernel stock Arch Linux | **Diagnóstico** — isola patches do CachyOS |
| 6 | Testar HDMI | **Diagnóstico** — isola problema ao DP |
| 7 | Testar com `nouveau` | **Diagnóstico** — isola culpa do driver proprietário |
| 8 | Forçar DP 1.2 / desabilitar DSC | **Média** — link training mais simples |
| 9 | Cabo/Emulador com HPD pull-up | **Definitiva** — solução de hardware |

---

## 💡 Aposta pessoal

As duas abordagens com maior chance de sucesso são:

1. **`ConnectedMonitor` + `CustomEDID` no xorg.conf** — porque atua exatamente no ponto onde o driver NVIDIA faz o probing, não no kernel DRM genérico.
2. **SDDM em Wayland nativo** — porque você já provou que KWin consegue forçar o link training e mostrar imagem.

Se ambas falharem, o problema é genuinamente no hardware/firmware do monitor e a solução definitiva será a de hardware (HPD pull-up ou EDID emulator).

---

*Documento gerado em 24 de julho de 2026.*
