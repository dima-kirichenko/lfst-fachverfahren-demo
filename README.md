# lfst-fachverfahren-demo: Referenzarchitektur für den Betrieb von Steuer-Fachanwendungen

Dieses Repository demonstriert den automatisierten, gehärteten und überwachten Betrieb einer behördlichen Jakarta-EE-Fachanwendung (`steuer-pruefdienst`) auf Basis von Enterprise-Linux, WildFly (dem direkten Upstream von Red Hat JBoss Enterprise Application Platform) sowie einer OpenShift-kompatiblen Kubernetes-Umgebung (k3s / Rootless Podman).

Es verbindet eine lokale Virtualisierungsumgebung (**Proxmox VE** auf GMKtec NucBox G3 Plus, Intel N150) als Staging-System und Self-Hosted CI/CD-Runner mit einem entkoppelten Ziel-Rechenzentrumsknoten (**Oracle Cloud Always Free ARM VPS** auf Enterprise-Linux-Basis).

---

## 1. Architekturübersicht

```text
+-------------------------------------------------------------------------+
| Homelab / Staging-Standort (GMKtec NucBox G3 Plus - Proxmox VE)         |
|                                                                         |
|  +-------------------------------+   +-------------------------------+  |
|  | VM 1: Self-Hosted Runner      |   | VM 2: Staging & Vorabtest     |  |
|  | - GitHub Actions Runner       |   | - Rootless Podman / k3s       |  |
|  | - Maven / Buildah Cache       |   | - WildFly 31 Staging-Instanz  |  |
|  | - OpenTofu & Ansible Control  |   | - Snapshot vor jedem Release  |  |
|  +---------------+---------------+   +-------------------------------+  |
+------------------|------------------------------------------------------+
                   |
                   | Verschlüsselter Rollout (SSH / WireGuard / TLS 1.3)
                   v
+-------------------------------------------------------------------------+
| Ziel-Rechenzentrum (Oracle Cloud Always Free ARM VPS - Linux)           |
|                                                                         |
|  +-------------------------------------------------------------------+  |
|  | Gehärtetes Linux-Basissystem (Ansible Role: linux_hardening)      |  |
|  | - SSH Key-Only, Firewalld/UFW, Kernel-Sysctl, Auditd              |  |
|  +-------------------------------------------------------------------+  |
|  | Container-Plattform (k3s mit PodSecurity Standard "restricted")   |  |
|  |                                                                   |  |
|  |  +-------------------------------------------------------------+  |  |
|  |  | Namespace: fachverfahren-steuer                             |  |  |
|  |  |                                                             |  |  |
|  |  |  [Pod: steuer-pruefdienst (WildFly 31 / Jakarta EE 10)]     |  |  |
|  |  |  - Non-Root Ausführung (UID 10001 / GID 0 OpenShift-ready)  |  |  |
|  |  |  - Read-Only Root-Dateisystem (readOnlyRootFilesystem)      |  |  |
|  |  |  - JBoss CLI Härtung (harden-standalone.cli)                |  |  |
|  |  |  - Readiness & Liveness Probes (/health/ready, /health/live)|  |  |
|  |  +------------------------------+------------------------------+  |  |
|  +---------------------------------|---------------------------------+  |
|                                    | Scrape (:9990/metrics & :8080)     |
|  +---------------------------------v---------------------------------+  |
|  | Monitoring & Betriebsbereitschaft (Prometheus + Grafana)          |  |
|  | - Überwachung von Applikationsserver, JVM-Heap und Fehlerraten    |  |
|  | - Alarmierung über alerts.yml bei Verlust der Betriebsbereitschaft|  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 2. Abdeckung der Anforderungen im Fachverfahrensbetrieb

| Anforderung aus dem Aufgabengebiet | Technische Umsetzung in diesem Repository |
|---|---|
| **1. Bereitstellung von Fachanwendungen auf Basis von Linux-Systemen** | Reproduzierbare Bereitstellung des Jakarta-EE-Fachverfahrens `steuer-pruefdienst` auf gehärtetem Linux mittels Ansible (`infra/ansible/site.yml`) und Container-Rollout (`.github/workflows/deploy-fachverfahren.yml`). |
| **2. Konfiguration und Einrichtung von VM-Umgebungen und Containerumgebungen** | Deklarative VM-Bereitstellung für Proxmox und OCI mittels OpenTofu (`infra/tofu/main.tf`) sowie Einrichtung von k3s und Rootless Podman über Ansible (`infra/ansible/roles/container_runtime`). |
| **3. Monitoring und Überwachung der Betriebsbereitschaft der Applikationsserver** | MicroProfile-Health-Checks (`ReadinessHealthCheck.java`), Prometheus-Scraping des WildFly-Management-Endpunkts (`ops/monitoring/prometheus.yml`), Alarmregeln (`ops/monitoring/alerts.yml`) und Grafana-Dashboard (`ops/monitoring/grafana-dashboard-fachverfahren.json`). |
| **4. Implementierung von Anwendungssicherheit auf Containerbasis, JBoss und EAP** | Automatisierte Härtung von WildFly (Upstream zu JBoss EAP 8) per JBoss-CLI (`app/wildfly/harden-standalone.cli`), Non-Root-Container (`app/Containerfile`), schreibgeschütztes Root-Dateisystem, Entzug aller Linux-Capabilities (`k8s/deployment.yaml`) und strikte Netzwerksegmentierung (`k8s/networkpolicy.yaml`). |
| **5. Erstellung von Konzepten zum Betrieb von Fachverfahren im Rechenzentrum** | Vollständiges Betriebskonzept in `docs/betriebskonzept.md` (SLA, Wartungsfenster, Rollback, Wiederanlauf) und Sicherheitskonzept in `docs/sicherheitskonzept.md`. |
| **6. Mitarbeit in abteilungsübergreifenden Arbeitsgruppen** | Verbindliche Schnittstellenverträge (Health-Probes, Metriken, externe Konfiguration über ConfigMaps/Secrets) zwischen Anwendungsentwicklung, Systembetrieb und Informationssicherheit (siehe `docs/betriebskonzept.md`, Abschnitt 6). |
| **7. Virtuelle Maschinen (Proxmox / Hypervisor)** | Proxmox-VM-Automation für Staging und Self-Hosted Runner inklusive Snapshot-Konzept vor produktiven Freigaben (`infra/tofu/main.tf`). |
| **8. Containertechnologie auf Basis von OpenShift / Kubernetes** | Manifeste in `k8s/` erfüllen den Kubernetes-Standard `restricted` sowie die Anforderungen von Red Hat OpenShift Security Context Constraints (SCC `restricted-v2`: Ausführung unter beliebiger Non-Root-UID mit Gruppenzugehörigkeit `GID 0`). |

---

## 3. Verzeichnisstruktur

- `app/` - Jakarta-EE-10-Fachanwendung (`steuer-pruefdienst`), JBoss-CLI-Härtungsskript und OpenShift-kompatibles `Containerfile`
- `infra/tofu/` - OpenTofu-Definitionen für den Oracle Cloud ARM Rechenzentrumsknoten und die Proxmox-Staging-VM
- `infra/ansible/` - Ansible-Playbooks und Rollen zur Linux-Basishärtung und Laufzeitkonfiguration
- `k8s/` - Gehärtete Kubernetes-Manifeste (Namespace, ConfigMap, Secret-Vorlage, Deployment, Service, NetworkPolicy)
- `ops/monitoring/` - Prometheus-Konfiguration, Alert-Regeln und Grafana-Dashboard für die Betriebsbereitschaft
- `ops/scripts/` - Skript zur automatisierten Prüfung der Betriebsbereitschaft (`verify-readiness.sh`)
- `docs/` - Deutsches Betriebskonzept, Sicherheitskonzept und Interview-Leitfaden

---

## 4. Schnellstart (Kommandos für Nushell)

### Ein-Befehl-Trockenlauf (Kompletter Stack: Gehärteter WildFly + Prometheus + Grafana)

Mit dem Startskript wird die Jakarta-EE-Anwendung gebaut, der gehärtete WildFly-Container (`UID 10001:0`, `read_only: true`, `cap_drop: ALL`) zusammen mit Prometheus und einem voll vorprovisionierten Grafana-Dashboard gestartet und anschließend automatisch durch `verify-readiness.sh` auf Betriebsbereitschaft geprüft:

```nu
cd /home/dima/Documents/lfst-fachverfahren-demo

# 1. Gesamten Demo-Stack bauen, starten und automatisch verifizieren
bash ops/scripts/demo-up.sh

# 2. Live-Konfigurationswechsel im Gespräch simulieren (Veranlagungsjahr 2027, Version 1.1.0)
bash ops/scripts/demo-live-update.sh 2027 1.1.0

# 3. Nach dem Gespräch Stack wieder sauber beenden
bash ops/scripts/demo-down.sh
```

### Manueller Build mit offiziellem Red Hat JBoss EAP 8 Image (über Red Hat Developer Subscription RH00798)

Mit deiner aktiven Red Hat Developer Subscription (`SKU: RH00798`, Account `11925553`, bis zu 16 RHEL-Nodes) kannst du das Fachverfahren direkt auf dem offiziellen **Red Hat JBoss EAP 8.0 (RHEL 9)** Image aus `registry.redhat.io` bauen:

```nu
cd /home/dima/Documents/lfst-fachverfahren-demo/app

# 1.Anmeldung an der Red Hat Container Registry
podman login registry.redhat.io

# 2. Offizielles JBoss-EAP-8-Image auf RHEL-9-Basis mit JBoss-CLI-Härtung bauen
podman build -t localhost/lfst-steuer-pruefdienst-eap8:1.0.0 -f Containerfile.eap8 .
```

### Manueller Build und Einzel-Container-Test (WildFly 31 Upstream / Rootless Podman)

```nu
# 1. In das Anwendungsverzeichnis wechseln und WAR-Artefakt bauen
cd app
mvn clean package -DskipTests

# 2. Gehärtetes WildFly-Container-Image mit Podman erstellen
podman build -t localhost/lfst-steuer-pruefdienst:1.0.0 -f Containerfile .

# 3. Container im Rootless-Modus mit schreibgeschütztem Root-Dateisystem starten
podman run --rm -d --name steuer-pruefdienst -p 8080:8080 -p 9990:9990 --read-only --tmpfs /opt/jboss/wildfly/standalone/tmp:rw,noexec,nosuid,size=64m --tmpfs /opt/jboss/wildfly/standalone/log:rw,noexec,nosuid,size=64m --tmpfs /opt/jboss/wildfly/standalone/data:rw,noexec,nosuid,size=64m localhost/lfst-steuer-pruefdienst:1.0.0

# 4. Betriebsbereitschaft und Fachverfahren-Endpunkt prüfen
http get http://127.0.0.1:8080/api/info
http get http://127.0.0.1:9990/health/ready
```

### Bereitstellung im Kubernetes-Cluster (k3s / OpenShift-kompatibel)

```nu
# 1. Namespace und Konfiguration anwenden
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/networkpolicy.yaml

# 2. Rollout-Status überwachen
kubectl rollout status deployment/steuer-pruefdienst -n fachverfahren-steuer --timeout=60s

# 3. Automatisierte Prüfung der Betriebsbereitschaft ausführen
bash ops/scripts/verify-readiness.sh http://127.0.0.1:8080 http://127.0.0.1:9990
```

---

## 5. Weiterführende Dokumentation

- **Betriebskonzept:** `docs/betriebskonzept.md`
- **Sicherheitskonzept (Linux, Container, WildFly/JBoss EAP):** `docs/sicherheitskonzept.md`
- **5-Minuten Live-Demo Leitfaden:** `docs/interview-demo-leitfaden.md`
