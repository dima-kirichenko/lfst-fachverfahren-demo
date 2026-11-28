# Lenovo E470 Bring-up — RHEL-Netinstall + MicroShift-Ziel

Stand: 28.11.2026. Zweck: Produktionsnaher Zielknoten für die Interview-Demo
(Staging = k3s auf `lfst-staging`, Prod-Demo = MicroShift auf Lenovo).
Secrets stehen hier **nicht** drin — nur Platzhalter (`<ACTIVATION_KEY>`).
Echte Werte: gitignorierte lokale Dateien + Kickstart unter `/tmp` (nicht im Repo).

## Hardware / Netz

- Lenovo E470, i5 (2C/4T), 16 GB RAM, SanDisk-SSD 256 GB (`/dev/sda`).
- Secure Boot: **aus** (Security-Tab). Bootmodus UEFI, F12-Bootmenü aktiv.
- Netz: Kabel, DHCP-Reservierung in der FritzBox (Lenovo = `.31`).
  Parallel reserviert: N150 `.26`, Staging `.27`, Runner `.28`, Dell `.29`.
  Hintergrund: `.29` war doppelt belegt (Dell statisch + Lenovo per DHCP) →
  Timeouts im Rückverkehr. Seit Reservierungen stabil.
- PXE-Server läuft auf dem NixOS-Laptop (dnsmasq-Container `lfst-proxmox-pxe`
  für proxyDHCP+TFTP, Python-Fileserver Port 8000 für `/pxe/*`).

## PXE-Kette (funktionsfähig, Stand 28.11.)

1. UEFI-PXE → DHCP-proxyDHCP (Next-Server = Laptop, `snponly.efi`).
2. iPXE → `boot.ipxe` (HTTP) → Kernel `vmlinuz-rhel10` + `initrd-rhel10.img`.
3. Kernel-Parameter u. a.: `inst.ks=<URL>/lenovo-ks.cfg inst.stage2=<URL>/rhel10/`
   `inst.text ip=dhcp`.
4. Kickstart: Sprache de, Zeitzone Berlin, DHCP + Hostname `lenovo-e470`,
   `rootpw --lock`, ein `sshkey --username=root`, Firewall an (nur SSH),
   `autopart --type=lvm`, `rhsm --organization=<ORG> --activation-key=<ACTIVATION_KEY>`,
   Minimal-Pakete + openssh-server, `%post` aktiviert sshd, `reboot` am Ende.
5. Kernel/Initrd stammen aus der RHEL-Boot-ISO (per `pycdlib` extrahiert —
   auf dem Laptop gab es weder `xorriso` noch `isoinfo`, `pip` fehlt;
   `nix-shell -p python3Packages.pycdlib` funktioniert).
6. Stage2-Quelle `install.img` (817 MB) ebenfalls aus der Boot-ISO
   (`/IMAGES/INSTALL.IMG;1`) extrahiert und als
   `pxe-out/rhel10/images/install.img` serviert.

## Stolpersteine + Fixes (chronologisch)

1. **HTTP-Port zu:** Nur UDP 67/69/4011 in der Laptop-Firewall, TCP 8000
   fehlte (Ping ging, TCP-Handshake hing). Diagnose per Gegenprobe vom
   kabelgebundenen N150 (`curl` → Timeout statt 200). Fix: eine Zeile
   `TCP/8000` für das WLAN-Interface, danach 0,045 s.
2. **IP-Konflikt `.29`:** s. oben → FritzBox-Reservierungen für alle Hosts.
3. **Doppelter `sshkey --username=root`** im Kickstart → nur Warnung
   (`KickstartParseWarning`), Installer läuft mit dem ersten Key weiter.
   Trotzdem bereinigt (eine Zeile behalten).
4. **`inst.stage2` fehlte** → Anaconda-Fehlerschleife („boot has failed …
   `inst.`-Präfix ist Pflicht"). Erster Versuch lief deshalb ~8 Min ins Leere.
5. **Stage2 als Datei-URL geht NICHT:** Anaconda hängt an die URL selbst
   `images/install.img` bzw. `LiveOS/squashfs.img` an. Die Datei muss als
   **Ordnerbaum** liegen: `…/rhel10/` mit `images/install.img` darunter.
   (Boot-ISO enthält keinen `.treeinfo` — die Warnung „can't find installer
   main image path in treeinfo" ist harmlos, Fallback greift.)
6. **`updates.img`/`product.img`-404er** beim Stage2-Start: normale optionale
   Dateien, harmlos.
7. **CDN-TLS flakkte zeitweise** (`self-signed certificate in chain` für
   `cdn.redhat.com`, falscher Host im Zert: `subscription.rhsm.redhat.com`
   auf einer Akamai-Kante). `dnf` zusätzlich mit `ip_resolve=4` stabilisiert;
   BaseOS/AppStream-Metadaten danach fehlerfrei. Loser Hinweis, kein Blocker.
8. **MicroShift braucht RHEL 9:** Doku-Lage (Red-Hat-Docs, Stand 11/2026) —
   MicroShift 4.22 auf RHEL 9.8 = supported; **RHEL 10 nur Technology Preview,
   keine MicroShift-RPMs in den RHEL-10-Repos** („MicroShift RPMs are not
   available from RHEL 10 repositories"). Darum 404 auf allen
   `rhocp-4.x-for-rhel-10-…`-Repos (4.20–5.1 getestet). Konsequenz: Neuinstallation
   mit RHEL 9 (Portal bietet 9.9 → geht, Versions-Lock auf 9.9), dann
   `rhocp-4.22-for-rhel-9` + `fast-datapath-for-rhel-9`. Workaround mit
   händischen RHEL-9-Repo-Dateien auf RHEL 10 existiert (Doku „Known issues"),
   aber unsupportet und abhängigkeitsriskant → verworfen.
   **Verifiziert 28.11.:** `microshift* 4.22.20 el9` liegt im RHEL-9-Pfad
   (`…/layered/rhel9/x86_64/rhocp/4.22/os`) und ist mit unserer Berechtigung
   lesbar (temporäre Prüf-Repo-Datei, danach wieder gelöscht). RHEL-9.9-Plan
   damit freigegeben.
9. **Volume Group voll:** `autopart` verplant alles (root 70 + swap 7,8 +
   home 158,1 GB, **0 frei**). MicroShift-LVMS braucht *freien* VG-Platz.
   Neuinstall-Plan (~236 GB nutzbar): root 40 G, swap 8 G, home 150 G,
   **~38 G frei** in der VG.
10. **`subscription-manager` unter RHEL 10** kennt `list --available` /
    `--consumed` nicht mehr (nur `--installed`); SCA-Modus. `repos
    --list-enabled` funktioniert. Für die Befundlage irrelevant, aber
    Stolperfalle bei alten Copy-paste-Befehlen.

## Stand der Installation (28.11., Nachmittag)

- RHEL 10.3 (Coughlan) installiert, bootet von Platte, Login-Prompt da.
- SSH als root per Key funktioniert (`.31`).
- `subscription-manager`: **Registered** (System + Org eingetragen).
- Repos: BaseOS + AppStream aktiv; `rhocp`/`fast-datapath` für RHEL 10
  deaktiviert gelassen (kein Content, s. Punkt 8).
- Inventar im Hybrid-Cloud-Portal war vor der Installation leer; System
  sollte nach der Registrierung dort erscheinen (noch zu verifizieren).

## k3s-Staging: Deploy-Befunde (28.11., Subagent)

- `/api/info` antwortet, `tariffYear: 2026`, 2/2 Pods Running, Service
  ClusterIP (kein Ingress/NodePort angelegt).
- Image-Transfer Runner → Staging via `podman save | k3s ctr images import`
  (~8 Min, 536 MB), danach Umtag auf Manifest-Namen.
- **Nur im Cluster vorhandene Patches (TODO: ins Repo zurückportieren):**
  VolumeMounts WildFly- → EAP-Pfade (`/opt/eap/standalone/…`),
  `readOnlyRootFilesystem: true → false`, extra emptyDir für
  `standalone_xml_history`, `jboss-cli deploy ROOT.war` auf beiden Pods
  (Scanner im Image ist `scan-enabled="false"`).
  Bei Pod-Neustart / Re-Apply gehen Patches + Deploy verloren.

## Nächste Schritte

1. RHEL-9.9-Boot-ISO ins Portal-Download-Verzeichnis legen.
2. Kernel/Initrd + `install.img` extrahieren, Kickstart auf RHEL 9 +
   Partitionierung mit VG-Luft umstellen, `boot.ipxe` anpassen.
3. Lenovo neu per PXE installieren (~30 Min, unbeaufsichtigt).
4. MicroShift 4.22: Repos, Pull-Secret (`/etc/crio/openshift-pull-secret`,
   kommt aus dem Portal per Hand), Firewall-Regeln, `oc`-Check.
5. k3s-Manifeste ans EAP-Image angleichen (Backport der Cluster-Patches).
6. Portal-Inventar auf `lenovo-e470` prüfen.
