# FS25_StorageAutoDrive

[![Download Latest Release](https://img.shields.io/github/v/release/OPuder/FS25_StorageAutoDrive?label=Download&sort=semver)](https://github.com/OPuder/FS25_StorageAutoDrive/releases/latest)

**[⬇️ Download the latest version](https://github.com/OPuder/FS25_StorageAutoDrive/releases/latest)**

## Deutsch

**Du möchtest, dass AutoDrive Paletten und Ballen direkt aus einem unterstützten Lager abholt? Dann bist du hier genau richtig!**

Mit **STORAGEAUTODRIVE** verbindet sich ein unterstütztes Paletten- beziehungsweise Ballenlager mit AutoDrive und Universal Autoload (UAL). So können passende Lagerobjekte im Rahmen eines echten AutoDrive-Abholauftrags bereitgestellt werden.

STORAGEAUTODRIVE erkennt passende AutoDrive-Abholaufträge und stellt geeignete, tatsächlich im Lager vorhandene Objekte bereit. Universal Autoload übernimmt anschließend das eigentliche Beladen, während AutoDrive seine gewohnten Aufgaben erledigt.

**Weniger manuelles Palettenhandling, mehr Automatisierung und ein weiterer Schritt zu einem vollautomatischen Hof!**

> **Wichtig:** STORAGEAUTODRIVE ersetzt oder verändert weder AutoDrive noch Universal Autoload. Die Mod stellt die Verbindung zum Palettenlager her und überlässt das eigentliche Beladen den vorhandenen Mods.

### Funktionen

- Erkennt relevante AutoDrive-Abholaufträge an unterstützten Paletten- und Ballenlagern.
- Fordert passende Lagerobjekte über die vorgesehenen GIANTS-ObjectStorage-Funktionen an und stellt sie für UAL bereit.
- Berücksichtigt zeitversetzte beziehungsweise asynchrone Palettenausgaben.
- Verwaltet die Vorgänge pro Auftrag in getrennten Sessions.
- Gibt eindeutig von STORAGEAUTODRIVE erzeugte, nicht aufgenommene Paletten nach Möglichkeit an das Lager zurück.
- Speichert Sessioninformationen, damit offene Aufträge nach dem Laden eines Spielstands wieder aufgenommen werden können.
- Berücksichtigt beim Lagerabruf passende BigBag- und BigBag-Paletten-Dateipfade, um beide Varianten beim gleichen FillType zu unterstützen.
- Unterstützt die Erkennung registrierter Ballentypen anhand der verfügbaren Objekt- und Balleninformationen, einschließlich Rund- und Quaderballen.
- Ergänzt die AutoDrive-Auftragsauswahl derzeit um die Varianten **Stroh – Rundballen** und **Stroh – Quaderballen**.
- Berücksichtigt bei der Ballensuche den tatsächlichen Fülltyp und die konkrete Ballendatei, soweit die Lagerinformationen diese zuverlässig bereitstellen.

Die Ballenunterstützung wird schrittweise getestet. Verfügbarkeit und Ausgabe hängen davon ab, ob der konkrete Ballentyp im verwendeten Lager tatsächlich vorhanden, unterstützt und ausgebbar ist. Nicht jede Ballenart oder Mod-Ballen-XML ist automatisch mit jedem Lager kompatibel.

Die tatsächlichen Ladeentscheidungen trifft weiterhin Universal Autoload. STORAGEAUTODRIVE gibt keine feste Paletten-Zielmenge vor und simuliert keinen künstlichen Ladezustand.

### Voraussetzungen

- Farming Simulator 25
- AutoDrive für Farming Simulator 25
- Universal Autoload für Farming Simulator 25
- Ein unterstütztes Paletten- oder Ballenlager, das die jeweiligen Objekte über die GIANTS-ObjectStorage-Funktionen ausgeben kann

Die benötigten Mods müssen installiert und im Spiel aktiviert sein. Die Kompatibilität kann je nach Spiel-, Mod- und Lager-Version variieren.

### Ablauf

1. AutoDrive fährt einen passenden Abholauftrag am unterstützten Lager an.
2. STORAGEAUTODRIVE erkennt den relevanten Auftrag und wertet die gewählte Auswahl aus.
3. Die Mod prüft den Lagerbestand und fordert passende, tatsächlich ausgebbare Objekte an.
4. Sobald das Spiel ein Objekt tatsächlich erzeugt hat, ordnet STORAGEAUTODRIVE es der richtigen Auftragssession zu.
5. Universal Autoload erkennt und lädt die bereitgestellten Objekte selbstständig.
6. STORAGEAUTODRIVE wartet auf die erforderlichen Vorgänge und kümmert sich nur um eindeutig eigene, nicht aufgenommene Paletten.
7. Die Session wird abgeschlossen, sobald keine notwendigen eigenen Vorgänge mehr offen sind.

Da die Palettenausgabe asynchron erfolgen kann, kann zwischen einer Anforderung und dem tatsächlichen Erscheinen einer Palette eine Verzögerung liegen.

### Installation

1. Lade die gewünschte Version aus dem Bereich **Releases** dieses GitHub-Repositories herunter.
2. Lege die heruntergeladene ZIP-Datei in den Mods-Ordner von Farming Simulator 25.
3. Entpacke die Mod-ZIP nicht, sofern der jeweilige Release nichts anderes angibt.
4. Aktiviere STORAGEAUTODRIVE sowie die benötigten Mods im Spiel.
5. Starte einen passenden AutoDrive-Abholauftrag am unterstützten Palettenlager.

Es wird empfohlen, vor einem Update eine Sicherung des Spielstands anzulegen.
### Diagnosemodus

Für die Fehlersuche können Diagnose-Logs direkt im Spiel ein- und ausgeschaltet werden. Sie sind standardmäßig deaktiviert. Die Standard-Tastenkombination ist **STRG + ALT + F**; die Tastenbelegung kann in den Steuerungseinstellungen angepasst werden.

Bei Fehlern bitte die Diagnose aktivieren, das Problem reproduzieren und anschließend die relevante `log.txt` zusammen mit der verwendeten Mod-Version im Issue bereitstellen.

### Wichtige Hinweise und Einschränkungen

#### Palettenlager nicht überfüllen

**Überfülle das Palettenlager nicht.** Eine Überfüllung kann die interne GIANTS-Lagerverwaltung beeinträchtigen und zu Problemen mit Paletten oder deren Sicherung führen. Solche Probleme können außerhalb des Einflussbereichs von STORAGEAUTODRIVE liegen.

#### Beladungsprozente und Palettenanzahl

Die prozentuale Beladungsanzeige von AutoDrive ist bei physischen Paletten keine verlässliche Angabe für eine bestimmte Palettenanzahl. Die tatsächliche Anzahl hängt unter anderem vom Anhänger, den Paletten und dem Verhalten von AutoDrive und Universal Autoload ab.

STORAGEAUTODRIVE erzeugt deshalb **keinen künstlichen Füllstand**, keine künstliche Zielmenge und keinen künstlichen Ladezustand. Für Ungenauigkeiten der prozentualen Beladungsanzeige oder für Entscheidungen der normalen AD-/UAL-Logik ist STORAGEAUTODRIVE nicht verantwortlich.

#### AutoDrive und Universal Autoload bleiben zuständig

- AutoDrive steuert weiterhin das Fahrzeug und verwaltet seinen Auftrag.
- Universal Autoload erkennt und lädt die bereitgestellten Paletten.
- STORAGEAUTODRIVE manipuliert weder die UAL-Kapazität noch dessen Objektlisten oder Ladezustände.
- Verhalten wie verzögertes rotierendes Beladen oder ein Warten von AutoDrive kann von der eigenen Logik dieser Mods abhängen.

STORAGEAUTODRIVE garantiert daher keine feste Palettenanzahl und erzwingt nicht, dass AD nach einer bestimmten Zeit weiterfährt.

#### Nur eigene Paletten werden verwaltet

Die Mod verwaltet nur Paletten, die eindeutig zur jeweiligen STORAGEAUTODRIVE-Session gehören. Bereits vorhandene, manuell abgestellte oder von anderen Sessions erzeugte Paletten werden nicht pauschal als eigene Sessionobjekte behandelt.

### Fehler melden

Wenn ein Auftrag nicht korrekt startet, Paletten nicht erscheinen oder eine Session nach dem Laden eines Spielstands nicht fortgesetzt wird, öffne bitte ein **Issue** in diesem Repository.

Bitte füge möglichst Folgendes hinzu:

- die verwendete STORAGEAUTODRIVE-Version
- die Versionen von Farming Simulator 25, AutoDrive und Universal Autoload
- eine kurze Beschreibung der Schritte, mit denen das Problem auftritt
- den relevanten `log.txt` aus dem Spielordner
- falls relevant, die zugehörige `StorageAutoDriveSessions.xml`

**Bitte Logs nicht in ein ZIP-Archiv packen**, damit sie direkt geprüft werden können. Entferne vor dem Hochladen gegebenenfalls persönliche Informationen aus den Dateien.

### Projektgrundsatz

STORAGEAUTODRIVE ist die Verbindung zwischen Palettenlager/ObjectStorage, AutoDrive und Universal Autoload. Eigene Logik bleibt auf STORAGEAUTODRIVE beschränkt. Fehler werden anhand von Logs analysiert und möglichst mit einer kleinen, gezielten Änderung behoben.

---

## English

**Want AutoDrive to collect pallets and bales directly from supported storage? Then you're in the right place!** 

With **STORAGEAUTODRIVE**, supported pallet or bale storage can be connected to AutoDrive and Universal Autoload (UAL), allowing suitable stored objects to be made available for real AutoDrive pickup jobs.

STORAGEAUTODRIVE detects relevant AutoDrive pickup jobs and makes suitable objects that actually exist in storage available. Universal Autoload handles the actual loading while AutoDrive continues to do its usual job.

**Less manual pallet handling, more automation, and another step toward a fully automated farm!**

> **Important:** STORAGEAUTODRIVE does not replace or modify AutoDrive or Universal Autoload. It connects pallet storage to their existing functionality and leaves the actual loading to those mods.

### Features

- Detects relevant AutoDrive pickup jobs at supported pallet and bale storage.
- Requests suitable stored objects through the intended GIANTS ObjectStorage functions and makes them available to UAL.
- Handles delayed and asynchronous pallet spawning.
- Keeps each job isolated in its own session.
- Attempts to return clearly identified session-owned pallets that were not loaded.
- Saves session information so open jobs can be reconstructed after loading a savegame.
- Considers matching BigBag and BigBag-pallet file paths when requesting stored pallets, supporting both variants for the same fill type.
- Supports recognition of registered bale types using the available object and bale information, including round and square bales.
- Currently adds **Straw – Round Bale** and **Straw – Square Bale** to the AutoDrive pickup selection.
- Uses the actual fill type and specific bale file for bale matching where the storage information exposes them reliably.

Bale support is being tested incrementally. Availability and output depend on whether the specific bale type is present in, supported by, and retrievable from the selected storage. Not every bale type or modded bale XML is automatically compatible with every storage system.

Universal Autoload remains responsible for loading pallets. STORAGEAUTODRIVE does not define a fixed target quantity or fabricate a loading state.

### Requirements

- Farming Simulator 25
- AutoDrive for Farming Simulator 25
- Universal Autoload for Farming Simulator 25
- Supported pallet or bale storage that can release the relevant objects through GIANTS ObjectStorage functionality

The required mods must be installed and enabled in-game. Compatibility may vary depending on the game, mod and storage versions.

### How it works

1. AutoDrive approaches a suitable pickup job at supported storage.
2. STORAGEAUTODRIVE detects the relevant job and reads the selected option.
3. The mod checks storage and requests suitable objects that can actually be retrieved.
4. When the game actually spawns an object, STORAGEAUTODRIVE associates it with the correct job session.
5. Universal Autoload detects and loads the available objects itself.
6. STORAGEAUTODRIVE waits for required operations and handles only clearly identified session-owned pallets that were not loaded.
7. The session finishes when no required session-owned operations remain.

Pallet spawning is asynchronous, so a delay between a request and the pallet appearing in-game is possible.

### Installation

1. Download the desired version from the **Releases** section of this GitHub repository.
2. Place the downloaded ZIP file in your Farming Simulator 25 mods folder.
3. Do not extract the mod ZIP unless the release instructions say otherwise.
4. Enable STORAGEAUTODRIVE and the required mods in-game.
5. Start a suitable AutoDrive pickup job at supported pallet storage.

Backing up your savegame before updating is recommended.
### Debug Logging

Diagnostic logging can be enabled or disabled directly in-game. It is disabled by default. The default key combination is **CTRL + ALT + F**, and the key binding can be changed in the control settings.

When reporting an issue, enable diagnostic logging, reproduce the problem, and include the relevant `log.txt` and mod version in the issue report.

### Important notes and limitations

#### Do not overfill pallet storage

**Do not overfill pallet storage.** Overfilling can interfere with GIANTS' internal storage management and may cause pallet or securing issues. These problems may be outside the scope of STORAGEAUTODRIVE.

#### Loading percentages and pallet counts

AutoDrive's percentage-based loading indication is not a reliable measure of a specific number of physical pallets. The actual count depends on factors such as the trailer, the pallets, and the behaviour of AutoDrive and Universal Autoload.

STORAGEAUTODRIVE does **not** fabricate fill levels, target quantities or loading states. It is not responsible for inaccuracies in the percentage display or decisions made by the normal AD/UAL logic.

#### AutoDrive and Universal Autoload remain in control

- AutoDrive continues to control the vehicle and manage its job.
- Universal Autoload detects and loads the available pallets.
- STORAGEAUTODRIVE does not manipulate UAL capacity, object collections or loading states.
- Delayed rotating loading or AutoDrive waiting may be caused by the normal logic of those mods.

STORAGEAUTODRIVE does not guarantee a fixed pallet count and does not force AutoDrive to depart after a specific timeout.

#### Only session-owned pallets are managed

The mod manages only pallets that can be clearly identified as belonging to its own STORAGEAUTODRIVE session. Existing, manually placed or other-session pallets are not treated as session-owned objects indiscriminately.

### Reporting issues

If a job does not start correctly, pallets fail to appear, or a session is not resumed after loading a savegame, please open an **Issue** in this repository.

Please include, if possible:

- the STORAGEAUTODRIVE version
- the Farming Simulator 25, AutoDrive and Universal Autoload versions
- a short description of the steps needed to reproduce the problem
- the relevant game `log.txt`
- the corresponding `StorageAutoDriveSessions.xml`, if relevant

**Please do not put log files inside a ZIP archive**, so they can be inspected directly. Remove personal information from files before uploading them, if necessary.

### Project principle

STORAGEAUTODRIVE connects pallet storage/ObjectStorage, AutoDrive and Universal Autoload. Custom logic remains inside STORAGEAUTODRIVE. Issues should be diagnosed from logs and fixed with the smallest targeted change possible.
