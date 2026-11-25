# Sicherheitskonzept: Härtung von Linux, Containerplattform und WildFly / JBoss EAP

**Geltungsbereich:** Fachverfahren `steuer-pruefdienst`  
**Orientierungsrahmen:** BSI IT-Grundschutz (SYS.1.3 Server unter Linux und Unix, SYS.1.6 Containerisierung, APP.3.2 Webserver / Applikationsserver)  
**Sicherheitsanforderung der Stelle:** Implementierung von Anwendungssicherheit auf Containerbasis, JBoss und EAP (unter Berücksichtigung von Art. 10 BaySÜG)

---

## 1. Verteidigung in der Tiefe (Defense-in-Depth)

Die Sicherheitsarchitektur des Fachverfahrens verlässt sich nicht auf eine einzelne Schutzmaßnahme, sondern staffelt die Sicherheitskontrollen über vier Ebenen:

1. **Ebene 1: Linux-Basissystem (Host-Härtung)**
2. **Ebene 2: Container-Laufzeitumgebung & Kubernetes / OpenShift-Richtlinien**
3. **Ebene 3: Applikationsserver (WildFly / JBoss EAP)**
4. **Ebene 4: Fachanwendung & CI/CD-Lieferkette**

---

## 2. Ebene 1: Härtung des Linux-Basissystems (`infra/ansible/roles/linux_hardening`)

Die Konfiguration des darunterliegenden Linux-Servers im Rechenzentrum erfolgt automatisiert und idempotent durch Ansible:

- **Zugriffskontrolle (SSH-Härtung):**
  - Deaktivierung der Passwort-Authentifizierung (`PasswordAuthentication no`).
  - Deaktivierung des direkten Root-Logins (`PermitRootLogin no`).
  - Beschränkung auf kryptografisch starke Schlüsselverfahren (Ed25519 / RSA >= 4096 Bit).
- **Netzwerkfilterung am Host:**
  - Grundsatz `Default Deny` für alle eingehenden Verbindungen.
  - Freigabe ausschließlich für die administrativen Zugänge (über definierte Quellnetze) sowie die vorgesehenen Ingress-Ports der Container-Plattform.
- **Kernel-Härtung (`sysctl`):**
  - Deaktivierung von IP-Forwarding auf Nicht-Routing-Schnittstellen, Schutz vor SYN-Floods (`net.ipv4.tcp_syncookies = 1`), Unterbindung von ICMP-Redirects und Aktivierung von Address Space Layout Randomization (`kernel.randomize_va_space = 2`).
- **Nachvollziehbarkeit und Patch-Management:**
  - Aktivierung von `auditd` zur Protokollierung sicherheitsrelevanter Systemaufrufe.
  - Automatisierte Sicherheitsaktualisierungen bzw. geplanter Patch-Rollout über Staging (Proxmox) auf Produktion (OCI).

---

## 3. Ebene 2: Container-Sicherheit auf Basis von Kubernetes und OpenShift (`k8s/` & `app/Containerfile`)

Die Containerisierung des Fachverfahrens ist so aufgebaut, dass sie sowohl auf Standard-Kubernetes (k3s) mit dem Pod-Sicherheitsstandard `restricted` als auch unverändert unter **Red Hat OpenShift (Security Context Constraints `restricted-v2`)** lauffähig ist:

- **Striktes Non-Root-Prinzip:**
  - Im `app/Containerfile` wird ein dedizierter Systembenutzer mit der UID `10001` und der primären Gruppe `GID 0` (Root-Gruppe ohne Root-Rechte, Standardvorgabe für OpenShift Arbitrary UIDs) angelegt.
  - Im Manifest `k8s/deployment.yaml` erzwingt `runAsNonRoot: true` und `allowPrivilegeEscalation: false`, dass der Prozess niemals erhöhte Rechte erlangen kann.
- **Schreibgeschütztes Root-Dateisystem (`readOnlyRootFilesystem: true`):**
  - Das gesamte Wurzeldateisystem des Containers inklusive der WildFly-Binärdateien und der ausgerollten `steuer-pruefdienst.war` ist zur Laufzeit unveränderlich.
  - Ein Angreifer kann selbst bei einer Schwachstelle in der Webanwendung keine Schadsoftware im Container-Dateisystem ablegen oder Startskripte manipulieren.
  - Schreibzugriffe sind ausschließlich auf drei flüchtige, mit `noexec` und `nosuid` eingehängte Speicherbereiche (`emptyDir`) beschränkt:
    - `/opt/jboss/wildfly/standalone/tmp`
    - `/opt/jboss/wildfly/standalone/log`
    - `/opt/jboss/wildfly/standalone/data`
- **Entzug sämtlicher Linux-Capabilities:**
  - Über `capabilities: { drop: ["ALL"] }` werden dem Container alle Kernel-Sonderrechte (wie `NET_RAW` für Paket-Sniffing oder `SYS_ADMIN`) entzogen.
- **Netzwerksegmentierung (`k8s/networkpolicy.yaml`):**
  - Eine strikte Kubernetes `NetworkPolicy` isoliert den Namespace `fachverfahren-steuer`.
  - Eingehender Datenverkehr auf den Anwendungsport `8080` ist nur für den vorgesehenen Ingress/Gateway erlaubt.
  - Eingehender Datenverkehr auf den Managementport und Metrikport `9990` ist ausschließlich für den Prometheus-Überwachungsdienst innerhalb des Rechenzentrums zugelassen.

---

## 4. Ebene 3: Härtung von WildFly / JBoss EAP (`app/wildfly/harden-standalone.cli`)

Statt einer fehleranfälligen manuellen Bearbeitung von XML-Konfigurationsdateien (`standalone.xml`) erfolgt die Härtung des Applikationsservers deterministisch während des Image-Builds über das JBoss-CLI-Skript `app/wildfly/harden-standalone.cli`:

1. **Trennung von Anwendungsschnittstelle und Administrationsschnittstelle:**
   - Der öffentliche HTTP-Listener (`8080`) stellt ausschließlich die Fachanwendung bereit.
   - Die Management-Schnittstelle (`9990`) bedient nur die internen Health-Endpunkte (`/health/live`, `/health/ready`) und Metrik-Endpunkte (`/metrics`) und ist über die `NetworkPolicy` von außen unerreichbar.
2. **Entfernung verräterischer Server-Header (Information Disclosure Prevention):**
   - Im Subsystem `undertow` werden die Standard-Header `Server` und `X-Powered-By` entfernt bzw. neutralisiert, damit externe Clients keine Rückschlüsse auf die eingesetzte Patchversion von WildFly oder JBoss EAP ziehen können.
3. **Deaktivierung nicht benötigter Beispielinhalte und Standardinhalte:**
   - Die `welcome-content`-Anwendung sowie unnötige Standard-Deployments werden im Subsystem `undertow` vollständig entfernt.
4. **Geheimnisverwaltung (Secrets Management):**
   - Keine Ablage von Passwörtern oder Zugangsdaten im Klartext in der `standalone.xml`.
   - Sensible Parameter werden zur Laufzeit aus Kubernetes-Secrets (`k8s/secret.yaml.example`) über Umgebungsvariablen bzw. gemountete Dateien mit restriktiven Dateirechten (`0400`) übergeben.
5. **Ressourcenbegrenzung gegen Denial-of-Service:**
   - Begrenzung der maximalen Größe eingehender HTTP-POST-Anfragen (`max-post-size`) im Undertow-Listener sowie feste JVM-Speichergrenzen (`MaxRAMPercentage=75.0`).

---

## 5. Sicherheits-Checkliste vor Produktivsetzung (Abnahmeprotokoll)

| Prüfgegenstand | Prüfkriterium | Nachweis im Repository | Status |
|---|---|---|---|
| **Linux-Host** | SSH-Passwort-Login und Root-Login deaktiviert | `infra/ansible/roles/linux_hardening/tasks/main.yml` | [x] |
| **Container-Benutzer** | Prozess läuft unter UID >= 10000, `runAsNonRoot: true` | `app/Containerfile`, `k8s/deployment.yaml` | [x] |
| **Dateisystemschutz** | `readOnlyRootFilesystem: true` aktiv | `k8s/deployment.yaml` | [x] |
| **Kernel-Rechte** | `capabilities.drop: ["ALL"]` und `seccompProfile: RuntimeDefault` | `k8s/deployment.yaml` | [x] |
| **JBoss / WildFly** | Undertow Server-Header entfernt, Welcome-Content deaktiviert | `app/wildfly/harden-standalone.cli` | [x] |
| **Management-Port** | Port `9990` durch NetworkPolicy vor öffentlichem Zugriff geschützt | `k8s/networkpolicy.yaml` | [x] |
| **Verfügbarkeit** | Liveness-Probes und Readiness-Probes sowie Prometheus-Alerts aktiv | `k8s/deployment.yaml`, `ops/monitoring/alerts.yml` | [x] |
