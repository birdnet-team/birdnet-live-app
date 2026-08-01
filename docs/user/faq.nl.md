# Veelgestelde vragen

Veelgestelde vragen.

## Algemeen

**V: Heeft BirdNET Live een internetverbinding nodig?**
A: Nee. Alle inferentie draait op het toestel zelf met het ONNX-model. De enige netwerkfuncties zijn optioneel en staan standaard uit: kaarttegels en het opzoeken van plaatsnamen via OpenStreetMap, weermomentopnamen via Open-Meteo, en het ophalen van soortafbeeldingen en -beschrijvingen via de taxonomie-API. Zie [Instellingen → Privacy](settings.md#privacy).

**V: Hoeveel soorten kan de app herkennen?**
A: Het BirdNET+ V3.0-model herkent 9.789 soorten wereldwijd — vogels, amfibieën, zoogdieren en insecten (de taxonomisch afgestemde, gesnoeide doorsnede van de audioclassifier en het geomodel).

**V: Welke platformen worden ondersteund?**
A: Android (8.0+), iOS (15.0+) en Windows (experimenteel).

## Nauwkeurigheid

**V: Waarom laat mijn betrouwbaarheidsdrempel lage scores zien?**
A: Verlaag de betrouwbaarheidsdrempel in de instellingen om meer detecties te zien. Achtergrondgeluid, wind en afstand beïnvloeden de nauwkeurigheid.

**V: Wat doet het soortenfilter?**
A: Het geomodel voorspelt welke soorten waarschijnlijk zijn op jouw GPS-locatie en in deze tijd van het jaar. Zet **Locatiefilter** aan om onwaarschijnlijke soorten te verbergen, of **Locatieweging** om resultaten te wegen op geografische waarschijnlijkheid.

**V: Hoe nauwkeurig is de herkenning?**
A: De nauwkeurigheid hangt af van de opnamekwaliteit, de afstand, het achtergrondgeluid en de soort. Detecties met hoge betrouwbaarheid (>70%) zijn doorgaans betrouwbaar. Controleer zeldzame soorten altijd ook visueel.

## Opnemen

**V: Waar worden opnamen bewaard?**
A: In de documentenmap van de app onder `recordings/<session-id>/`, als WAV of FLAC afhankelijk van **Instellingen → Opname → Formaat**.

**V: Kan ik bestaande opnamen analyseren?**
A: Ja. Open Bestandsanalyse vanaf het startscherm, kies een audiobestand, stel de locatie en parameters in en tik op Analyseren. Ondersteunde formaten zijn onder meer WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA en AMR.

## Point Count

**V: Wat is de Point Count-modus?**
A: Een telmodus op tijd voor formele punttellingen van vogels. Je stelt een vaste duur in (3–20 minuten) en een locatie; de app draait dan doorlopend en stopt automatisch wanneer de klok op nul staat.

**V: Kan ik een punttelling pauzeren?**
A: Nee. Om aan het protocol te voldoen moet er ononderbroken worden opgenomen. Je kunt een telling wel vroegtijdig beëindigen met de stopknop.

**V: Waar komen de resultaten van een punttelling terecht?**
A: Ze verschijnen in de Session-bibliotheek als "Point Count #1", "#2", enzovoort. Je kunt ze net als elke andere Session bekijken, bewerken en exporteren.

## Prestaties

**V: Waarom wordt de app warm / verbruikt die batterij?**
A: Inferentie met het ONNX-model is rekenintensief, en het scherm blijft tijdens live Sessions aan. Dat is normaal voor het in realtime verwerken van een neuraal netwerk.

**V: Het spectrogram lijkt vast te lopen.**
A: Controleer of de machtiging voor de microfoon is verleend en of het opnemen van audio actief is. Ga na dat geen andere app de microfoon gebruikt.
