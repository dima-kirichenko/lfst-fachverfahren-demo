# Host-Haertung pve-n150 (Stand: 2026-11-25, umgesetzt per SSH)

## Durchgefuehrte Massnahmen (PVE-Host)

- Paketquellen: `pve-enterprise.sources` + `ceph.sources` deaktiviert (kein Enterprise-Key),
  `pve-no-subscription.list` aktiv. `apt-get full-upgrade` ausgefuehrt, keine offenen Updates.
- `unattended-upgrades` + `fail2ban` installiert und aktiviert.
- SSH: `PermitRootLogin prohibit-password`, `PasswordAuthentication no`.
  Key-Only-Zugang verifiziert (4 Admin-Keys aus Cloud-Init/answer.toml).
- PVE-Firewall: Datacenter + Node (`pve-n150`) aktiviert.
  Regeln (Cluster-Ebene): ACCEPT `tcp/8006` und `tcp/22` aus `192.168.178.0/24`.
  Erreichbarkeit von SSH + Web-UI nach Aktivierung erneut verifiziert.
- Backup-Job: woechentlich So 02:00, Modus `snapshot`, `zstd`, Ziel `local`, VMs 244+245.
- API-Token `tofu@pve!automation` (Rolle `TofuProvisioner`, `privsep=0`, ohne Ablaufdatum).

## Durchgefuehrte Massnahmen (VMs 244/245, Debian 13)

- `qemu-guest-agent` + `fail2ban` installiert und aktiv (`qm agent <id> ping` = exit 0).
- SSH bereits ab Image keys-only (`PasswordAuthentication no`), `unattended-upgrades` aktiv.

## Bewusst offen gelassen

- Secure Boot: aus (Talos-Vorgeschichte). Aktivierung braucht BIOS-Zugriff + Key-Enroll.
- Plattenverschluesselung: keine (ext4 plain). Nachruestung nur per Neuinstallation.
- 2FA (TOTP) fuer `root@pam`: nicht konfiguriert.
- PVE-Zertifikat: selbstsigniert (Browser-Warnung beim ersten Aufruf bestaetigen).
- Enterprise-Repo-Dateien liegen als `*.disabled` unter `/etc/apt/sources.list.d/`.
