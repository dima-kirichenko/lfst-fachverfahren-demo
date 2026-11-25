# Interview-Leitfaden: 5-Minuten Live-Demo (LfSt Bayern - ID 244)

**Termin:** 30.11.2026, 08:00 Uhr (Online-Vorstellungsgespräch)  
**Stelle:** IT-Mitarbeiter im Fachverfahrensbetrieb Steuer - ID 244 (Bayerisches Landesamt für Steuern, Nürnberg)  
**Zweck:** Gezielter Praxisnachweis für die drei im Lebenslauf noch offenen Schwerpunkte (**JBoss/EAP-Anwendungssicherheit**, **Containerbetrieb unter OpenShift/Kubernetes** und **Monitoring der Betriebsbereitschaft**) auf Basis deiner vorhandenen Stärken (**Proxmox, Linux, OpenTofu/Terraform, Ansible, Java-Hintergrund, Dokumentation**).

---

## 1. Vorbereitung 15 Minuten vor Gesprächsbeginn (07:45 Uhr)

Öffne vier Browser-Tabs in genau dieser Reihenfolge, damit du während des Gesprächs nicht suchen musst:

1. **Tab 1 (Architektur & Konzepte):** GitHub-Ansicht dieses Repositories (`README.md` und `docs/betriebskonzept.md`).
2. **Tab 2 (Anwendungssicherheit JBoss/WildFly & Kubernetes):** Geöffnete Dateien `app/wildfly/harden-standalone.cli` und `k8s/deployment.yaml`.
3. **Tab 3 (CI/CD & Live-Endpunkt):** GitHub Actions Workflow `Deploy Fachverfahren` (`.github/workflows/deploy-fachverfahren.yml`) + daneben der JSON-Endpunkt `/api/info` der laufenden Anwendung.
4. **Tab 4 (Monitoring & Betriebsbereitschaft):** Grafana-Dashboard (`ops/monitoring/grafana-dashboard-fachverfahren.json`) bzw. die Prometheus-Alarmregeln (`ops/monitoring/alerts.yml`).

### Schneller Vorab-Start im Terminal (Nushell)

Mit einem einzigen Befehl startest du 15 Minuten vor dem Gespräch den gesamten Stack (gehärteter WildFly-Container + Prometheus + vorprovisioniertes Grafana-Dashboard inklusive Auto-Login) und führst die automatische Readiness-Prüfung aus:

```nu
cd /home/dima/Documents/lfst-fachverfahren-demo
bash ops/scripts/demo-up.sh
```

Falls du den Konfigurationswechsel auf das Veranlagungsjahr `2027` während des Gesprächs direkt lokal statt über GitHub Actions vorführen möchtest:

```nu
bash ops/scripts/demo-live-update.sh 2027 1.1.0
```

---

## 2. Der Einstiegssatz im Gespräch (Wann und wie anbieten?)

Sobald die Sprache auf **fehlende Produktionserfahrung mit JBoss/EAP oder OpenShift** kommt (oder bei der Frage, wie du dich in neue Fachverfahren einarbeitest), antwortest du ruhig und ehrlich:

> *„Im produktiven Alltag bei Key-Work lag mein Schwerpunkt auf Proxmox-Virtualisierung, Linux, Infrastructure as Code mit Terraform und Ansible sowie Java/Spring. JBoss EAP und OpenShift hatte ich dort nicht im Produktivbetrieb. Weil diese beiden Punkte zusammen mit dem Monitoring für Ihre Stelle zentral sind, habe ich mir zur Vorbereitung auf unser heutiges Gespräch eine kleine Referenzumgebung für ein Steuer-Fachverfahren aufgebaut: auf meinem lokalen Proxmox-Server als Staging-Knoten und einem Linux-Server in der Oracle Cloud als Ziel-Rechenzentrum. Wenn Sie möchten, zeige ich Ihnen in drei bis vier Minuten meinen Bildschirm."*

---

## 3. Das 5-Minuten-Storyboard (Schritt für Schritt)

### Minute 0:00 - 1:00 | Tab 1: Architektur & Betriebskonzept (Anforderungen 1, 2, 5, 7)

- **Zeigen:** `README.md` (Architekturschaubild) und `docs/betriebskonzept.md`.
- **Sagen:**
  - *„Ich habe die Umgebung zweistufig aufgebaut: Lokal auf meinem Proxmox-Server läuft der Staging-Knoten und ein eigener CI/CD-Runner, und als Ziel-Rechenzentrum dient eine ARM-Linux-Instanz in der Oracle Cloud."*
  - *„Die Bereitstellung und Grundhärtung des Linux-Systems erfolgt vollständig automatisiert über OpenTofu und Ansible. Dazu habe ich ein kurzes Betriebskonzept verfasst, das Bereitstellung, Überwachung, Rollback und die Schnittstellen zu angrenzenden Teams regelt."*

### Minute 1:00 - 2:15 | Tab 2: Anwendungssicherheit auf Containerbasis, JBoss und EAP (Anforderungen 4, 8)

- **Zeigen:** `app/Containerfile.eap8`, `app/wildfly/harden-standalone.cli`, `k8s/deployment.yaml` und `k8s/openshift-route.yaml`.
- **Sagen:**
  - *„Über meine aktive Red Hat Developer Subscription (SKU RH00798 für bis zu 16 Nodes) habe ich Zugriff auf RHEL 9, die offiziellen JBoss-EAP-8-Container-Images aus `registry.redhat.io` (`app/Containerfile.eap8`) sowie für schnelle lokale Offline-Builds auf das direkte Upstream-Image WildFly 31 (`app/Containerfile`)."*
  - *„Mir war wichtig, die Härtung nicht von Hand in der XML-Datei zu machen, sondern reproduzierbar über ein JBoss-CLI-Skript (`harden-standalone.cli`): Der Standard-Welcome-Content wird entfernt, verräterische Server-Header in Undertow werden abgeschaltet, und der Management-Port 9990 ist strikt vom Anwendungsport 8080 getrennt."*
  - *„Im Kubernetes-Deployment (`k8s/deployment.yaml`) setze ich genau die Restriktionen um, die auch Red Hat OpenShift über seine Security Context Constraints (`restricted-v2`) erzwingt: Der Container läuft strikt als Non-Root mit UID 10001 und Gruppe 0, das Root-Dateisystem ist schreibgeschützt (`readOnlyRootFilesystem: true`), alle Linux-Capabilities sind entzogen (`drop: ALL`), eine `NetworkPolicy` erlaubt den Zugriff auf den Management-Port nur für Prometheus, und für OpenShift bzw. MicroShift liegt in `k8s/openshift-route.yaml` eine TLS-gesicherte Route mit HSTS-Header bereit."*

### Minute 2:15 - 3:30 | Tab 3: Unterbrechungsfreies Release in < 60 Sekunden (Anforderungen 1, 2, 6)

- **Zeigen:** `/api/info` (zeigt `tariffYear: "2026"`) und den GitHub-Actions-Workflow `.github/workflows/deploy-fachverfahren.yml`.
- **Aktion:** Starte den Workflow per `Run workflow` mit dem Parameter `tariff_year: 2027` (oder zeige den gerade in ~30 Sekunden durchgelaufenen Run).
- **Sagen:**
  - *„Wenn ein neues Steuerjahr oder ein Patch ausgerollt wird, darf das Fachverfahren für die Finanzämter nicht stehen bleiben. Die Pipeline aktualisiert die Konfiguration und stößt ein Rolling Update an."*
  - *„Kubernetes schaltet den Verkehr erst auf den neuen Pod, wenn WildFly über `/health/ready` meldet, dass der Applikationsserver und die Fachanwendung bereit sind. Danach prüft `verify-readiness.sh` den Endpunkt fachlich. Würde dieser Test fehlschlagen, führt die Pipeline automatisch ein `kubectl rollout undo` auf die vorherige Version aus."*

### Minute 3:30 - 5:00 | Tab 4: Monitoring der Betriebsbereitschaft (Anforderungen 3, 5, 6)

- **Zeigen:** Grafana-Dashboard bzw. `ops/monitoring/alerts.yml`.
- **Sagen:**
  - *„Für die Überwachung der Betriebsbereitschaft liest Prometheus die Metriken und Health-Checks des WildFly-Servers aus. In `alerts.yml` habe ich drei typische Betriebsalarmierungen hinterlegt: Ausfall der Readiness-Probe, erhöhte HTTP-5xx-Fehlerrate und JVM-Heap-Auslastung über 85 Prozent."*
  - *„Gerade für die Mitarbeit in abteilungsübergreifenden Arbeitsgruppen hilft diese Struktur sehr: Die Entwicklung liefert gegen einen klaren Vertrag (`/health/ready`, `/metrics`), die IT-Sicherheit prüft gegen das Sicherheitskonzept, und der Betrieb hat ein verlässliches Runbook für Störungen."*

---

## 4. Rückfallplan (Falls Bildschirmteilen nicht gewünscht oder Verbindung langsam ist)

Falls das Gremium sagt *„Wir haben im Zeitplan keinen Slot für Screen-Sharing, erzählen Sie es uns kurz mündlich"*, fasst du das Projekt in **45 Sekunden** zusammen:

> *„Kein Problem, ich fasse es in drei Sätzen zusammen: Ich habe zur Vorbereitung ein Jakarta-EE-Fachverfahren auf WildFly - dem Upstream von JBoss EAP - in einem gehärteten Container aufgesetzt. Dabei habe ich die Härtung über ein JBoss-CLI-Skript automatisiert und den Container nach OpenShift-Regeln als Non-Root mit schreibgeschütztem Dateisystem und NetworkPolicy abgesichert. Über meinen lokalen Proxmox-Runner rolle ich Updates ohne Ausfallzeit auf einen Linux-Knoten in der Oracle Cloud aus und überwache die Betriebsbereitschaft mit Prometheus-Readiness-Probes und automatischem Rollback."*

---

## 5. Spickzettel für gezielte technische Nachfragen des Fachbereichs (Herr Wittig / Herr Wittler)

- **Frage:** *„Was ist der Unterschied zwischen einer Liveness-Probe und einer Readiness-Probe beim Applikationsserver?"*
  - **Antwort:** *„Die Liveness-Probe (`/health/live`) prüft, ob der WildFly-Prozess selbst noch lebt oder z. B. in einem Deadlock hängt - schlägt sie fehl, startet Kubernetes den Container neu. Die Readiness-Probe (`/health/ready`) prüft, ob das Fachverfahren fertig geladen ist und Anfragen verarbeiten kann - schlägt sie fehl, wird der Pod nur aus dem Loadbalancer genommen, ohne ihn sofort abzuschießen."*
- **Frage:** *„Warum braucht man bei `readOnlyRootFilesystem: true` in WildFly trotzdem `emptyDir`-Mounts?"*
  - **Antwort:** *„Weil WildFly zur Laufzeit temporäre Deployment-Artefakte, Transaktionsdaten und Logs nach `standalone/tmp`, `standalone/data` und `standalone/log` schreibt. Diese drei Pfade mounte ich als flüchtige `emptyDir`-Volumes mit `noexec`, während alle Programmdateien und das WAR-Archiv schreibgeschützt bleiben."*
- **Frage:** *„Warum Gruppe 0 (`GID 0`) im Containerfile, wenn es doch Non-Root sein soll?"*
  - **Antwort:** *„Red Hat OpenShift startet Container standardmäßig mit einer zufällig zugewiesenen, hohen User-ID, weist dem Prozess aber immer die Gruppe 0 zu. Wenn die Verzeichnisse für die Gruppe 0 schreibbar sind, läuft der Container unter jeder beliebigen Non-Root-UID auf OpenShift genauso sauber wie auf Standard-Kubernetes."*
