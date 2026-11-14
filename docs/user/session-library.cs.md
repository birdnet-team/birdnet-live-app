# Knihovna Sessions

Knihovna Sessions je archiv uložených Sessions a zpracovaných souborů.

## Jak ji otevřít

Použijte tlačítko :app-libraryMusic: v zápatí Domů.

## Co knihovna zobrazuje

Každý záznam Session shrnuje uloženou sadu výsledků, včetně typu, data, doby trvání, počtu druhů a počtu detekcí.

Typy Sessions používají stejné ikony jako domovská obrazovka:

- :app-micRounded: — Live Session
- :app-audioFileRounded: — Session Analýzy souborů
- :app-locationOnRounded: — Session Point Count
- :app-routeRounded: — Session Survey

## Ovládací prvky horní lišty

- :app-searchRounded: — vyhledávání podle data, typu Session, názvu místa, souřadnic, běžného nebo vědeckého názvu
- nabídka režimu zobrazení — přepínání mezi **Podrobný**, **Kompaktní** a **Podle druhu**
- :app-filterList: — změna pořadí řazení

## Režimy zobrazení

### Podrobný

Zobrazuje úplné karty Session s více metadaty.

### Kompaktní

Zobrazuje sevřenější řádky pro rychlejší procházení. Každý řádek má vpravo tlačítko :app-expandMore:, které řádek na místě rozbalí do plné karty podrobného zobrazení — hodí se, když chcete rychle nahlédnout na statistiky jedné konkrétní Session, aniž byste ztratili pozici posuvníku.

### Podle druhu

Seskupuje Sessions podle druhu a rozbalí se na Sessions, které daný druh obsahují.

## Řazení

Seřaďte Sessions podle **data** (od nejnovějších nebo od nejstarších), **názvu** (A–Z nebo Z–A) nebo **doby trvání** (od nejdelších nebo od nejkratších). Řazení podle doby trvání se hodí, když chcete najít nejdelší Survey týdne nebo nejkratší 30sekundový test, který jste omylem uložili.

Když jsou Sessions seskupené podle dne, řádek záhlaví každého dne ukazuje nejprve nabídku tří teček (:app-moreVert:) pro akce pro celý den a šipku rozbalení/sbalení na konci řádku. Šipka je *poslední* prvek — stejně jako u každého jiného rozbalitelného seznamu v aplikaci — takže klepnutí u pravého okraje vždy přepne skupinu.

## Místní čas

Každý časový údaj v Knihovně Sessions — řádky seznamu, záhlaví denních skupin, odznaky „začátek“ / „konec“ — se vykresluje v *aktuálním* místním časovém pásmu vašeho telefonu. Časové údaje Session se ukládají v UTC, takže Session, kterou jste pořídili v Berlíně a poté otevřeli v New Yorku, se prostě zobrazí o pět (nebo šest) hodin dříve — data na disku se nemění. Při cestování během dlouhé Survey zobrazený čas sleduje zařízení.

## Akce řádku

S každým řádkem Session lze pracovat dvěma způsoby:

- **Nabídka tří teček** (:app-moreVert:) vpravo na každé kartě otevře malou nabídku s položkami **Otevřít**, **Sdílet** a **Smazat**. Sdílení otevře dialog, jehož volby **Zvuk** a **Metadata** jsou předvyplněné podle Nastavení → Export a synchronizace a platí jen pro toto sdílení, a poté systémovou nabídku sdílení — není nutné nejprve otevírat Přehled Session, abyste Session poslali kolegovi.
- **Přejetí** řádku doleva nebo doprava jej smaže. Před odstraněním se stále zobrazí potvrzovací dialog, takže náhodné přejetí lze vrátit.

## Co následuje

Klepnutím na kteroukoli Session otevřete [Přehled Session](session-review.md).
