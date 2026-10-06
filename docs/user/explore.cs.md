# Prozkoumat

Prozkoumat ukazuje druhy předpovězené pro aktuální polohu a roční období pomocí geomodelu BirdNET.

## Jak jej otevřít

Otevřete **Prozkoumat** v zápatí Domů tlačítkem :app-searchRounded:.

## Horní lišta a záhlaví

### Horní lišta

- :app-refresh: — obnoví polohu a znovu sestaví předpovězený seznam druhů

### Záhlaví polohy

V záhlaví se zobrazuje:

- aktuální reverzně geokódovaný název místa, je-li k dispozici
- souřadnice pod názvem místa
- :app-helpOutlineRounded: — otevře panel nápovědy Prozkoumat

## Seznam druhů

Každá karta druhu může obsahovat:

- přibalený obrázek druhu
- běžný název
- volitelný vědecký název
- odznak stupně hojnosti

Klepnutím na kartu otevřete překryvný panel s podrobnostmi o druhu.

### Stupně hojnosti

Místo surové procentní hodnoty zobrazuje každá karta **stupeň hojnosti** pro aktuální místo a roční období. Odznak stupně kombinuje dva prvky:

- **kruh**, který se plní od ⅙ do plného, jak je druh pravděpodobnější
- **první písmeno** názvu stupně (celý název přečtou čtečky obrazovky a zobrazuje se v podrobnostech druhu)

Barva odznaku sleduje sdílenou škálu skóre v aplikaci a posouvá se od červené (méně pravděpodobné) k zelené (pravděpodobnější), jak stupeň roste.

Existuje šest stupňů, od nejpravděpodobnějšího po nejméně pravděpodobný:

| Stupeň | Význam |
| --- | --- |
| **Hojný** | Mezi nejsilnějšími předpověďmi zde |
| **Běžný** | Velmi pravděpodobné |
| **Častý** | Pravděpodobné |
| **Neobvyklý** | Možné |
| **Řídký** | Nepravděpodobné |
| **Vzácný** | Mezi nejslabšími předpověďmi zde |

Stupně jsou **relativní k aktuálnímu místu**. Přizpůsobují se tomu, jak silně geomodel předpovídá druhy v této oblasti, takže se hranice posouvají podle místního rozložení skóre: na místě s mnoha jistými předpověďmi potřebuje druh velmi vysoké skóre, aby byl *Hojný*, zatímco v oblasti se slabšími předpověďmi se stejného stupně dosáhne při nižším skóre. Stejné skóre tak může na různých místech spadat do různých stupňů, což udržuje smysluplnost žebříčku všude.

## Překryvný panel s podrobnostmi o druhu

Překryvný panel může zobrazovat:

- větší obrázek
- autora obrázku
- běžný a vědecký název
- přibalený popisný text, je-li k dispozici
- týdenní graf očekávané četnosti
- externí odkazy jako eBird, iNaturalist nebo Wikipedia, jsou-li pro daný druh k dispozici

## K čemu Prozkoumat slouží

Prozkoumat je referenční zobrazení v aplikaci zohledňující polohu. Pomáhá porovnat aktuální polohový kontext aplikace s druhy, se kterými se můžete setkat.

Samo o sobě **nemění** uložená data session. Filtrování detekcí se ovládá samostatně v [Nastavení](settings.md).
