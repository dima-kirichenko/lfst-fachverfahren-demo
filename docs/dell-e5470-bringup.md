# Dell Latitude E5470 Bring-up (pve-dell) — 27./28.11.2026

Zweiter Homelab-Knoten neben `pve-n150` (`.26`). Enthält alle Irrwege,
damit keine Session sie wiederholt. Stand: Debian 13 (trixie) installiert,
bootet von SSD, SSH als root. Proxmox VE on top + statische `.29` noch offen.

## 1. Hardware-Fakten (verifiziert, nicht raten)

| Punkt | Befund |
|---|---|
| Modell / CPU | Latitude E5470, i5-6300U (Skylake), vPro |
| RAM | 16 GB (ePSA Extended grün, 21 Min) |
| NIC | Intel I219-LM (kabelgebunden), 1 Gbit/s an FritzBox LAN 2 |
| **Platte** | **NVMe `/dev/nvme0n1`, 465,8 GB** (`CT500T500SSD8`) — **kein SATA-Laufwerk verbaut!** (`SATA-0 = (none)`, 2,5"-Schacht leer) |
| BIOS | 1.34.3 (Dez 2022) = **neueste Version**, kein Update verfügbar |
| SATA-Modus | AHCI (ab Werk, nie ändern) |
| Display | internes Panel ab Kernel-Start defekt (Streifen/Müll) bei Proxmox-9.3-Kernel UND Debian-Installer-Framebuffer; installiertes Debian lesbar. Externes HDMI bleibt dunkel (kein Signal). |
| ePSA | Full Diagnostics grün (RAM inkl.), Storage-Thorough steht aus |

Konsequenz: **Jede `sda`-Annahme ist falsch.** Antwortdateien/Preseeds brauchen
`disk-list = ["nvme0n1"]` bzw. `partman-auto/disk` + `grub-installer/bootdev` auf `nvme0n1`.

## 2. Netzwerk-Fakten

- FritzBox `.1`, DHCP-Pool dynamisch. **`.29` ist NICHT reserviert** (Checkbox aus!):
  Der Dell bekam `.33/.35/.36/.37/.39/.40/.41/.42/.44/.46/.50`. Für Serverbetrieb
  statisch konfigurieren (geplant: `.29`).
- Laptop (NixOS `nixos`) ist dual-homed: WLAN `wlp0s20f3` = `.32`,
  Kabel `enp0s31f6` = `.43`, **gleiches Subnetz**. Das erzeugte ARP-Flux
  (zwei MACs für `.32`), der den simplen UEFI-Netzwerkstack des Dells
  verwirrte (RX-Fehlerflut). Lehre: **nie beide gleichzeitig für PXE nutzen.**
- NixOS-Firewall blockt default: benötigte Ports explizit öffnen
  (TCP 16000, 10809; UDP 67, 68, 69, 4011; UDP 6666 für Netconsole). Nur Runtime
  (`iptables -I nixos-fw ...`), kein Rebuild nötig.

## 3. Boot-Infrastruktur (alles lokal, keine Cloud)

| Dienst | Was / Wo | Start |
|---|---|---|
| dnsmasq (ProxyDHCP+TFTP) | Container `lfst-proxmox-pxe` (`--network host`), Config auf `wlp0s20f3`, bootet `snponly.efi` → `http://192.168.178.32:8000/pxe/boot.ipxe` | `docker start lfst-proxmox-pxe` |
| Datei-/Webhook-Server | `/tmp/opencode/pve-webhook/server.py` (Python, Port 8000, 0.0.0.0). **MUSS ThreadingHTTPServer sein** (single-threaded hängt sich am ersten langsamen Client auf!) | `cd /tmp/opencode/pve-webhook && python3 server.py` (Background) |
| Antwortdateien | `/tmp/opencode/pve-iso/answer-dell.toml` (Proxmox, nvme0n1!), `/tmp/opencode/pve-iso/debian-preseed-dell.cfg` (Debian, nvme0n1, ftp-Mirror) | — |
| PXE-Dateien | `/tmp/opencode/pve-iso/pxe-out/` (`boot.ipxe`, `vmlinuz-deb13`, `initrd-deb13.gz`, Preseed-Kopie) | werden per HTTP aus `pxe-out/` serviert |
| iVentoy 1.0.50 | `/home/dima/Downloads/iventoy-1.0.50-linux-x86_64-free/iventoy/` (`sudo bash iventoy.sh start`, WebUI `:26000`) | aktuell **gestoppt** (Konflikt mit dnsmasq vermeiden). Älteres 1.0.38 liegt daneben, ungenutzt. |
| ISOs | `/tmp/opencode/pve-iso/` (Basis + Builds) und `iventoy/iso/` (derzeit: `debian-13.8.0-auto-dell`, `dell29-auto`, `PRISTINE`) | — |

Secrets (Passwörter/Keys/Tokens) stehen **nur** in gitignorierten lokalen Dateien
(`/tmp/opencode/pve-iso/*.toml|*.cfg`, `authorized_keys`) und in der GitHub-Secrets-UI.
Niemals in Chat, Repo oder History (einmal passiert → per `git-filter-repo` purgiert).

## 4. Failure-Log (jede Zeile einmal bezahlt)

1. **Abgeschnittenes PXE-ISO** (`*-auto-from-iso.iso`, 1,6 statt 1,8 GB, El-Torito zeigt
   über Dateiende) → `grub>`-Rescue beim ISO-Boot. Ursache: `--pxe`/`from-iso`-Build.
   Fix: Standard-`prepare-iso --fetch-from iso` (Katalog sauber verifiziert).
2. **Proxmox 9.3 bootet nicht auf dem E5470**: Kernel startet, Netz oben, dann Hang
   vor Installer-Start — über PXE-direkt UND iVentoy-ISO, pristine UND modifiziert,
   alle Menüeinträge, `nomodeset`/`intel_iommu=off` wirkungslos. Kernel/Hardware-Kombi
   ungeklärt. **Proxmox-8.4-ISO liegt in `/tmp/opencode/pve-iso/` als Fallback.**
3. **`sda` statt `nvme0n1`** in Proxmox-Antwort + Debian-Preseed (+ GRUB-`bootdev`) →
   „Kein Root-Dateisystem" / GRUB-Install-Fehlschlag. Fix: Auto-Erkennung per
   `partman/early_command` (`list-devices` → `debconf-set`) + statisch `nvme0n1`.
4. **Eigenes Webhook ohne Content-Length** ließ Installer-`wget`-POSTs ewig hängen
   (alle „0 %-für-immer"-Phasen!). Fix: `Content-Length: 3` + ThreadingHTTPServer.
   Diagnose erfolgte live per SSH im Installer (Netzwerk-Konsole).
5. **Lahme Mirror-Downloads** → `ipv6.disable=1` (Kernel-Cmdline) + Mirror `ftp.de.debian.org`.
6. **Display-Müll** ist (fast) immer Kosmetik: Fortschritt an HDD-LED, FritzBox-Liste,
   Webhook-Posts und SSH messen, nie am Bildschirm.

## 5. Funktionierendes Rezept (27.11. abends verifiziert)

PXE-Netboot Debian trixie: dnsmasq → iPXE → `boot.ipxe` (Kernel-Cmdline:
`auto=true priority=critical preseed/url=.../debian-preseed-dell.cfg
vga=normal fb=false ipv6.disable=1 nvme_core.default_ps_max_latency_us=0`)
→ Preseed (deutsch, DHCP, atomic auf nvme0n1, SSH-Server + Keys per `late_command`
von `:8000/keys/authorized_keys`) → Reboot → Debian 13 mit SSH.

## 6. Erledigt (28.11., verifiziert)

- [x] Statische `.29` (`/etc/network/interfaces`, DHCP-Rest per Reboot weg)
- [x] Debian-Härten: `unattended-upgrades` + `fail2ban`, SSH key-only
      (`PermitRootLogin prohibit-password`, `PasswordAuthentication no`)
- [x] Proxmox VE 9.3.1 auf Debian trixie (Kernel `7.0.14-30-pve`, UI `:8006` = 200)
- [x] Deckel-Verhalten: `HandleLidSwitch*=ignore` (bleibt wach bei Deckel zu)
- [x] PVE-Firewall (DC + Node an; ACCEPT 22/8006 aus LAN; SSH+UI danach verifiziert)
- [x] API: Rolle `TofuProvisioner` + User `tofu@pve` + Token `automation`
      (unbefristet, privsep 0; Secret in `infra/tofu/terraform.dell.tfvars`, gitignoriert)
- [x] Ansible-Inventar: `[dell_proxmox]` mit `pve-dell` (ansible als root)
- [ ] Backup-Job: entfällt (keine VMs/kein Storage auf dem Dell)
- [ ] Tofu-Provider für Dell: bewusst nicht verdrahtet (keine VMs geplant)
- [ ] Proxmox-8.4-Fallback-ISO in `/tmp` kann weg (ungenutzt, 1,6 GB)
- [ ] ePSA-Speichertest gründlich für M.2-Langzeitbefund (optional)
