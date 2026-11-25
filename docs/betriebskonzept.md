# Betriebskonzept: Fachverfahren Steuer-Prüfdienst (`steuer-pruefdienst`)

**Dokumentenstatus:** Freigegebene Referenzarchitektur  
**Zielumgebung:** Linux-basierte VM-Umgebungen und Containerumgebungen (k3s / OpenShift-kompatibel)  
**Applikationsserver:** WildFly 31 (Upstream-Referenz für Red Hat JBoss EAP 8)  

---

## 1. Zielsetzung und Geltungsbereich

Dieses Betriebskonzept regelt den zuverlässigen, sicheren und nachvollziehbaren Betrieb der Fachanwendung `steuer-pruefdienst` im Rechenzentrum. Es beschreibt die Systemarchitektur, die Bereitstellungsprozesse, die Überwachung der Betriebsbereitschaft, das Störungsmanagement sowie die Verfahren zur Datensicherung und zum geordneten Wiederanlauf nach Störungen.

Ziel ist die Sicherstellung einer hohen Verfügbarkeit für die nachgelagerten Dienststellen (Finanzämter) bei gleichzeitiger Einhaltung strenger Vorgaben an die Informationssicherheit und Nachvollziehbarkeit aller Betriebsänderungen.

---

## 2. Systemarchitektur und Umgebungsmodell

Der Betrieb erfolgt strikt getrennt nach einer zweistufigen Topologie (Staging und Produktion), wobei sämtliche Infrastrukturkomponenten deklarativ als Code (Infrastructure as Code) verwaltet werden:

1. **Vorproduktionsumgebung und Integrationsumgebung (Staging / Homelab Proxmox VE):**
   - **Hardwarebasis:** GMKtec NucBox G3 Plus (Intel N150, Proxmox Virtual Environment).
   - **Funktion:** Durchführung von Vorabtests, Validierung von Betriebssystem-Patches, Ausführung des Self-Hosted CI/CD-Runners sowie Erstellung von VM-Snapshots vor jedem Release.
2. **Produktionsnahe Rechenzentrumsumgebung (Oracle Cloud ARM VPS):**
   - **Hardwarebasis:** ARM64-Serverinstanz unter Enterprise-Linux (RHEL-kompatibel bzw. Ubuntu LTS).
   - **Funktion:** Gehärteter Zielknoten für die Ausführung der containerisierten Fachanwendung unter k3s sowie der Überwachungskomponenten (Prometheus und Grafana).

### Schichtentrennung
- **Betriebssystemschicht:** Gehärtetes Linux-System, verwaltet durch die Ansible-Rolle `linux_hardening`.
- **Orchestrierungsschicht:** Leichtgewichtiges Kubernetes (k3s) mit erzwungenem Pod-Sicherheitsstandard `restricted` (kompatibel zu Red Hat OpenShift Security Context Constraints).
- **Laufzeitschicht (Applikationsserver):** Gehärteter WildFly-Applikationsserver (Jakarta EE 10) mit strikter Trennung zwischen Anwendungsport (`8080`) und internem Managementport bzw. Metrikport (`9990`).

---

## 3. Standardisierte Bereitstellung und Änderungsmanagement (Release-Management)

Manuelle Eingriffe auf den Produktivsystemen per interaktiver SSH-Sitzung sind im Regelbetrieb ausgeschlossen. Jede Änderung durchläuft einen automatisierten, vierstufigen Prozess über `.github/workflows/deploy-fachverfahren.yml`:

1. **Vorabprüfung und Paketerstellung:**
   - Kompilierung der Jakarta-EE-Anwendung über Maven.
   - Erstellung des Container-Images nach dem Prinzip der minimalen Angriffsfläche (Multi-Stage Build) und Ausführung des JBoss-CLI-Härtungsskripts `app/wildfly/harden-standalone.cli` zur Build-Zeit.
2. **Konfigurationsinjektion:**
   - Umgebungsspezifische Parameter (z. B. das aktive Veranlagungsjahr `APP_TARIFF_YEAR` oder Wartungsfenster-Kennungen) werden ausschließlich über `k8s/configmap.yaml` und `k8s/secret.yaml` eingebunden. Das Container-Image selbst bleibt über alle Umgebungen hinweg unverändert (Immutable Artifact).
3. **Unterbrechungsfreier Rollout (Zero-Downtime Rolling Update):**
   - Das Kubernetes-Deployment (`k8s/deployment.yaml`) startet zunächst die neue Instanz (`maxSurge: 1`, `maxUnavailable: 0`).
   - Der Datenverkehr wird erst dann auf den neuen Pod geschaltet, wenn die Readiness-Probe (`/health/ready` auf Port `9990`) den vollständigen Start des WildFly-Servers und der Fachanwendung bestätigt.
4. **Automatisierte Abnahmeprüfung und Rollback:**
   - Unmittelbar nach dem Rollout prüft das Skript `ops/scripts/verify-readiness.sh` die fachliche und technische Betriebsbereitschaft.
   - Schlägt diese Prüfung fehl, führt die Pipeline automatisch ein `kubectl rollout undo` auf die letzte als stabil bestätigte Version durch.

---

## 4. Monitoring und Überwachung der Betriebsbereitschaft

Die Überwachung der Betriebsbereitschaft erfolgt kontinuierlich auf drei Ebenen:

| Überwachungsebene | Datenquelle / Endpunkt | Schwellenwert / Alarmbedingung (`ops/monitoring/alerts.yml`) |
|---|---|---|
| **Infrastruktur & Linux-Host** | Node Exporter / Systemmetriken | CPU-Dauerlast > 85 %, freier Massenspeicher < 15 % |
| **Applikationsserver (WildFly / JBoss)** | Management-Schnittstelle `:9990/metrics` & `:9990/health/live` | JVM Heap-Auslastung > 85 % über 2 Minuten, Garbage-Collection-Stalls, Prozessausfall |
| **Fachanwendung (`steuer-pruefdienst`)** | `:9990/health/ready` & `:8080/api/validate` | Readiness-Status != `UP`, HTTP-5xx-Fehlerquote > 1 %, Antwortzeit (p95) > 500 ms |

### Selbstheilung (Self-Healing)
- **Liveness-Probe (`/health/live`):** Erkennt festgefahrene Applikationsserver-Prozesse (Deadlocks) und veranlasst einen automatischen Neustart des Containers.
- **Readiness-Probe (`/health/ready`):** Nimmt eine überlastete oder in Initialisierung befindliche Instanz sofort aus der Lastverteilung des Kubernetes-Service, ohne bestehende Verbindungen abrupt abzubrechen.

---

## 5. Störungsmanagement, Datensicherung und Wiederanlauf (Disaster Recovery)

### 5.1 Klassifizierung und Reaktionsablauf bei Störungen
1. **Erkennung:** Alarmierung durch Prometheus Alertmanager bzw. Sichtprüfung im Grafana-Dashboard `Fachverfahren Betriebsbereitschaft`.
2. **Erstdiagnose (Isolierung):**
   - Prüfung des Pod-Zustands und der letzten Ereignisse (`kubectl describe pod`).
   - Auswertung der strukturierten WildFly-Serverprotokolle (`kubectl logs`).
3. **Wiederherstellung der Betriebsbereitschaft:**
   - Grundsatz im Rechenzentrumsbetrieb: **Stabilisierung vor Ursachenforschung**.
   - Bei fehlerhaftem Release: Sofortiger Rollback per `kubectl rollout undo deployment/steuer-pruefdienst -n fachverfahren-steuer`.
   - Bei Host-Störung: Bereitstellung des Knoten-Zustands über OpenTofu und Ansible oder Rücksicherung des letzten Proxmox-VM-Snapshots.

### 5.2 Wiederanlaufparameter (RTO / RPO)
- **Recovery Time Objective (RTO):**
  - Container-Neustart / Rollback auf dem bestehenden Knoten: **< 60 Sekunden**.
  - Kompletter Neuaufbau des Linux-Zielknotens per OpenTofu und Ansible: **< 15 Minuten**.
- **Recovery Point Objective (RPO):**
  - Für die zustandslose Applikationsserver-Schicht (WildFly): **0 Sekunden** (vollständig in Git versioniert).
  - Für Konfigurationsstände und VM-Snapshots vor Wartungsfenstern: Stand unmittelbar vor Beginn des Wartungsfensters.

---

## 6. Zusammenarbeit in abteilungsübergreifenden Arbeitsgruppen

Der erweiterte Betrieb von Fachverfahren im Umfeld der Steuerverwaltung erfordert eine klare Aufgabenabgrenzung und verbindliche Schnittstellen zwischen verschiedenen Organisationseinheiten:

1. **Schnittstelle zur Anwendungsentwicklung (Fachverfahren-Entwicklung):**
   - Die Entwicklung liefert standardisierte Artefakte (WAR) und implementiert verpflichtend die MicroProfile-Health-Endpunkte (`/health/live`, `/health/ready`).
   - Der Betrieb stellt sicher, dass alle Umgebungsvariablen und Ressourcenlimits dokumentiert über `k8s/configmap.yaml` bereitgestellt werden.
2. **Schnittstelle zur Informationssicherheit (IT-Sicherheitsbeauftragte):**
   - Abstimmung und Nachweisführung der Härtungsmaßnahmen anhand von `docs/sicherheitskonzept.md` (Non-Root-Pflicht, Patch-Management, Netzwerksegmentierung).
3. **Schnittstelle zum zentralen Infrastrukturbetrieb (Netzwerk, Storage, Datenbanken):**
   - Festlegung der Freischaltungen in `k8s/networkpolicy.yaml` und der Firewall-Regeln in `infra/ansible/roles/linux_hardening/tasks/main.yml`.
   - Koordination länderübergreifender oder abteilungsübergreifender Wartungsfenster für Betriebssystem-Upgrades und Applikationsserver-Aktualisierungen.
