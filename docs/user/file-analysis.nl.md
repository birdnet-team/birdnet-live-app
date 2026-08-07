# Bestandsanalyse

Bestandsanalyse verwerkt een bestaande opname via dezelfde BirdNET-pijplijn die ook de live workflows aandrijft.

## Zo open je de modus

Tik op het startscherm op de kaart **Bestandsanalyse** met het pictogram :material-file-music:.

## Appbalk

- :material-tune: — de instellingen voor Bestandsanalyse openen
- :material-close: — een lopende analyse annuleren

## Ondersteunde invoer

De huidige bestandskiezer accepteert:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Wizard in vier stappen

### 1. Bestand kiezen

Kies een bestand en bekijk de metadatakaart:

- bestandsnaam
- formaat
- duur
- bestandsgrootte
- samplefrequentie

### 2. Locatie en datum

Je kunt:

- de huidige GPS-positie gebruiken
- coördinaten handmatig invoeren
- de locatie overslaan
- een punt op de kaart kiezen
- optioneel een opnamedatum instellen

### 3. Parameters

De wizard biedt:

- vensterduur
- overlap
- gevoeligheid
- betrouwbaarheidsdrempel
- modus van het soortenfilter

Overlap bepaalt hoe ver elk analysevenster opschuift en is specifiek voor de
bestandsanalyse: het hele bestand wordt altijd onderzocht, en meer overlap
onderzoekt het alleen fijner. De live modi gebruiken in plaats daarvan een
inferentiesnelheid, omdat die moeten bepalen hoe vaak ze op binnenkomende
audio draaien en niet hoe fijn ze een vaststaande opname afdekken.

Hoe de bestandsanalyse ook aan haar vensters komt, ze maakt er detecties van
met dezelfde regels als de Live-modus, Point Count en Survey: een detectie
begint bij haar vroegste ondersteunende venster, draagt de sterkste
ondersteunde score en eindigt aan het einde van het laatste ondersteunende
venster.

### 4. Analyseren

Het voortgangsscherm toont:

- verwerkte vensters
- gevonden detecties
- gevonden soorten
- annuleerknop

## Resultaat

Wanneer de analyse klaar is, zet BirdNET Live de uitvoer om in een opgeslagen Session en opent het [Session-overzicht](session-review.md).
