# FS25_StorageAutoDrive

[![Download Latest Release](https://img.shields.io/github/v/release/OPuder/FS25_StorageAutoDrive?label=Download&sort=semver)](https://github.com/OPuder/FS25_StorageAutoDrive/releases/latest)

**[⬇️ Download the latest version](https://github.com/OPuder/FS25_StorageAutoDrive/releases/latest)**

Du wolltest schon immer, dass AutoDrive auch Paletten direkt aus dem Palettenlager abholt? Dann bist du hier genau richtig!

Mit STORAGEAUTODRIVE wird genau das möglich! Die Mod verbindet dein unterstütztes Palettenlager mit AutoDrive und Universal Autoload (UAL), damit deine Fahrer Paletten direkt aus dem Lager abholen können – ganz automatisch.

STORAGEAUTODRIVE erkennt passende AutoDrive-Abholaufträge und stellt die angeforderten Paletten aus dem Lager bereit. Universal Autoload übernimmt anschließend das eigentliche Beladen, während AutoDrive seine gewohnten Aufgaben erledigt.

Weniger manuelles Palettenhandling, mehr Automatisierung und ein weiterer Schritt zu einem vollautomatischen Hof!

Wichtig: STORAGEAUTODRIVE ersetzt oder verändert weder AutoDrive noch Universal Autoload. Die Mod stellt lediglich die Verbindung zum Palettenlager her und überlässt das Beladen den vorhandenen Mods.
## Funktionen

- Erkennt relevante AutoDrive-Abholaufträge am unterstützten Palettenlager.
- Fordert passende Paletten über die Lagerfunktionen an und stellt sie für UAL bereit.
- Berücksichtigt zeitversetzte beziehungsweise asynchrone Palettenausgaben.
- Verwaltet die Vorgänge pro Auftrag in getrennten Sessions.
- Gibt eindeutig von STORAGEAUTODRIVE erzeugte, nicht aufgenommene Paletten nach Möglichkeit an das Lager zurück.
- Speichert Sessioninformationen, damit offene Aufträge nach dem Laden eines Spielstands wieder aufgenommen werden können.

Die tatsächlichen Ladeentscheidungen trifft weiterhin Universal Autoload. STORAGEAUTODRIVE gibt keine feste Paletten-Zielmenge vor und simuliert keinen künstlichen Ladezustand.

## Voraussetzungen

- Farming Simulator 25
- AutoDrive für Farming Simulator 25
- Universal Autoload für Farming Simulator 25
- Ein unterstütztes Palettenlager, das Paletten über die GIANTS-ObjectStorage-Funktionen ausgeben kann

Die benötigten Mods müssen installiert und im Spiel aktiviert sein. Die Kompatibilität kann je nach Spiel-, Mod- und Lager-Version variieren.

## Ablauf

1. AutoDrive fährt einen Abholauftrag am Palettenlager an.
2. STORAGEAUTODRIVE erkennt den relevanten Auftrag.
3. Die Mod fordert passende Paletten aus dem Lager an.
4. Sobald das Spiel die Paletten tatsächlich erzeugt hat, ordnet STORAGEAUTODRIVE sie der richtigen Auftragssession zu.
5. Universal Autoload erkennt und lädt die bereitgestellten Paletten selbstständig.
6. STORAGEAUTODRIVE wartet auf die erforderlichen Vorgänge und räumt nur eindeutig eigene, nicht aufgenommene Paletten auf.
7. Die Session wird abgeschlossen, sobald keine notwendigen eigenen Vorgänge mehr offen sind.

Da die Palettenausgabe asynchron erfolgen kann, kann zwischen einer Anforderung und dem tatsächlichen Erscheinen einer Palette eine Verzögerung liegen.

## Installation

1. Lade die gewünschte Version aus dem Bereich **Releases** dieses GitHub-Repositories herunter.
2. Lege die heruntergeladene ZIP-Datei in den Mods-Ordner von Farming Simulator 25.
3. Entpacke die Mod-ZIP nicht, sofern der jeweilige Release nichts anderes angibt.
4. Aktiviere STORAGEAUTODRIVE sowie die benötigten Mods im Spiel.
5. Starte einen passenden AutoDrive-Abholauftrag am unterstützten Palettenlager.

Es wird empfohlen, vor einem Update eine Sicherung des Spielstands anzulegen.

## Wichtige Hinweise und Einschränkungen

### Palettenlager nicht überfüllen

**Überfülle das Palettenlager nicht.** Eine Überfüllung kann die interne GIANTS-Lagerverwaltung beeinträchtigen und zu Problemen mit Paletten oder deren Sicherung führen. Solche Probleme können außerhalb des Einflussbereichs von STORAGEAUTODRIVE liegen.

### Beladungsprozente und Palettenanzahl

Die prozentuale Beladungsanzeige von AutoDrive ist bei physischen Paletten keine verlässliche Angabe für eine bestimmte Palettenanzahl. Die tatsächliche Anzahl hängt unter anderem vom Anhänger, den Paletten und dem Verhalten von AutoDrive und Universal Autoload ab.

STORAGEAUTODRIVE erzeugt deshalb **keinen künstlichen Füllstand**, keine künstliche Zielmenge und keinen künstlichen Ladezustand. Für Ungenauigkeiten der prozentualen Beladungsanzeige oder für Entscheidungen der normalen AD-/UAL-Logik ist STORAGEAUTODRIVE nicht verantwortlich.

### AutoDrive und Universal Autoload bleiben zuständig

- AutoDrive steuert weiterhin das Fahrzeug und verwaltet seinen Auftrag.
- Universal Autoload erkennt und lädt die bereitgestellten Paletten.
- STORAGEAUTODRIVE manipuliert weder die UAL-Kapazität noch dessen Objektlisten oder Ladezustände.
- Verhalten wie verzögertes rotierendes Beladen oder ein Warten von AutoDrive kann von der eigenen Logik dieser Mods abhängen.

STORAGEAUTODRIVE garantiert daher keine feste Palettenanzahl und erzwingt nicht, dass AD nach einer bestimmten Zeit weiterfährt.

### Nur eigene Paletten werden verwaltet

Die Mod verwaltet nur Paletten, die eindeutig zur jeweiligen STORAGEAUTODRIVE-Session gehören. Bereits vorhandene, manuell abgestellte oder von anderen Sessions erzeugte Paletten dürfen nicht pauschal als eigene Objekte behandelt werden.

## Fehler melden

Wenn ein Auftrag nicht korrekt startet, Paletten nicht erscheinen oder eine Session nach dem Laden eines Spielstands nicht fortgesetzt wird, öffne bitte ein **Issue** in diesem Repository.

Bitte füge möglichst Folgendes hinzu:

- die verwendete STORAGEAUTODRIVE-Version
- die Versionen von Farming Simulator 25, AutoDrive und Universal Autoload
- eine kurze Beschreibung der Schritte, mit denen das Problem auftritt
- den relevanten `log.txt` aus dem Spielordner
- falls relevant, die zugehörige `StorageAutoDriveSessions.xml`

**Bitte Logs nicht in ein ZIP-Archiv packen**, damit sie direkt geprüft werden können. Entferne vor dem Hochladen gegebenenfalls persönliche Informationen aus den Dateien.

## Projektgrundsatz

STORAGEAUTODRIVE ist die Verbindung zwischen Palettenlager/ObjectStorage, AutoDrive und Universal Autoload. Eigene Logik bleibt auf STORAGEAUTODRIVE beschränkt. Fehler werden anhand von Logs analysiert und möglichst mit einer kleinen, gezielten Änderung behoben.

---

# English

**A bridge between pallet storage, AutoDrive and Universal Autoload for Farming Simulator 25.**

STORAGEAUTODRIVE detects relevant AutoDrive pickup jobs at a supported pallet storage and makes requested pallets available for Universal Autoload.

> **Important:** STORAGEAUTODRIVE does not replace or modify AutoDrive or Universal Autoload. It connects the pallet storage to their existing behaviour.

## Features

- Detects relevant AutoDrive pickup jobs at supported pallet storage.
- Requests suitable pallets from storage and makes them available to Universal Autoload.
- Handles asynchronous pallet spawning.
- Keeps each pickup job isolated in its own session.
- Attempts to return clearly identified session-owned pallets that were not loaded.
- Persists session information so open jobs can be reconstructed after loading a savegame.

Universal Autoload remains responsible for loading pallets. STORAGEAUTODRIVE does not define a fixed target quantity or fabricate a loading state.

## Requirements

- Farming Simulator 25
- AutoDrive for Farming Simulator 25
- Universal Autoload for Farming Simulator 25
- A supported pallet storage using GIANTS ObjectStorage functionality

Compatibility may vary depending on game, mod and storage versions.

## How it works

1. AutoDrive approaches a pickup job at the pallet storage.
2. STORAGEAUTODRIVE detects the relevant job.
3. The mod requests suitable pallets from storage.
4. When the game actually spawns a pallet, it is associated with the correct job session.
5. Universal Autoload detects and loads the available pallets.
6. STORAGEAUTODRIVE waits for its outstanding operations and handles only its own uncollected pallets.
7. The session finishes when no required session-owned operations remain.

Pallet spawning is asynchronous, so a delay between a request and the pallet appearing in-game is possible.

## Installation

1. Download the desired version from this repository's **Releases** section.
2. Place the ZIP file in your Farming Simulator 25 mods folder.
3. Keep the mod ZIP compressed unless the release instructions say otherwise.
4. Enable STORAGEAUTODRIVE and its required mods in-game.
5. Start a suitable AutoDrive pickup job at a supported pallet storage.

Back up your savegame before updating.

## Important limitations

### Do not overfill pallet storage

**Do not overfill pallet storage.** Overfilling can interfere with GIANTS' internal storage management and may cause pallet or securing issues. These problems may be outside the scope of STORAGEAUTODRIVE.

### Loading percentages and pallet counts

AutoDrive's percentage-based loading indication is not a reliable measure of a specific number of physical pallets. The actual count depends on factors such as the trailer, pallets, and the behaviour of AutoDrive and Universal Autoload.

STORAGEAUTODRIVE does **not** fabricate fill levels, target quantities or loading states. It is not responsible for inaccuracies in the percentage display or decisions made by the normal AD/UAL logic.

### AutoDrive and Universal Autoload remain in control

- AutoDrive continues to control the vehicle and its job.
- Universal Autoload detects and loads the available pallets.
- STORAGEAUTODRIVE does not manipulate UAL capacity, object collections or loading states.
- Delayed rotating loading or AutoDrive waiting may be caused by the normal logic of those mods.

STORAGEAUTODRIVE does not guarantee a fixed pallet count and does not force AutoDrive to depart after a specific timeout.

### Only session-owned pallets are managed

The mod manages only pallets that can be clearly identified as belonging to its own session. Existing, manually placed or other-session pallets must not be treated as session-owned objects.

## Reporting issues

If a job does not start correctly, pallets fail to appear, or a session is not resumed after loading a savegame, please open an **Issue** in this repository.

Please include, if possible:

- STORAGEAUTODRIVE version
- Farming Simulator 25, AutoDrive and Universal Autoload versions
- steps to reproduce the problem
- the relevant game `log.txt`
- the corresponding `StorageAutoDriveSessions.xml`, if relevant

**Please do not put log files inside a ZIP archive.** Remove personal information from files before uploading them, if necessary.

## Project principle

STORAGEAUTODRIVE connects pallet storage/ObjectStorage, AutoDrive and Universal Autoload. Custom logic remains inside STORAGEAUTODRIVE. Issues should be diagnosed from logs and fixed with the smallest targeted change possible.
