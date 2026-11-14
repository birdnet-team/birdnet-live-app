# Režim ARU

!!! note "Předběžná implementace"
    Režim ARU nyní průběžně ukládá naplánované nasazení, nahrává plánované cykly, spouští živou inferenci během aktivních cyklů, ukládá klipy detekcí při zvoleném režimu nahrávání a zobrazuje ovládání oznámení na popředí v Androidu. Chování na pozadí v iOS je ještě třeba ověřit v terénu.

Režim ARU (Autonomous Recording Unit) je pracovní postup pro plánovaná akustická nasazení na pevném stanovišti.

## Aktuální postup nastavení

- **Podrobnosti a nastavení analýzy**:
    - **Metadata**: Zadejte název nasazení, ID ARU/stanice a jméno pozorovatele.
    - **Poloha**: Zadejte souřadnice místa pomocí automatického určení polohy GPS, ručního zadání zeměpisné šířky a délky, nebo nastavení polohy přeskočte. Zeměpisná šířka a délka jsou vyžadovány, pokud používáte plánování vázané na polohu slunce. Ikony: GPS :app-myLocation:, ruční souřadnice :app-editLocationAlt:, přeskočení polohy :app-locationOff: a výběr na mapě :app-mapSheet:.
    - **Analýza**: Vyberte mikrofon, frekvenci inference, práh spolehlivosti a citlivost.
    - **Formát nahrávek**: Zvolte mezi formáty FLAC (komprimovaný bezztrátový) a WAV (nekomprimovaný).
    - **Nahrávání**:
        - *Úplné*: Nahrává celou dobu trvání každého aktivního cyklu.
        - *Jen klipy*: Ukládá krátké zvukové klipy kolem detekovaných ptačích hlasů. Můžete si přizpůsobit kontext klipu (přidat 0 až 5 sekund zvuku před detekcí a po ní) a vybrat způsob vzorkování (*Všechny*, *Top N* nebo *Smart* pro omezení spotřeby úložiště).
        - *Vypnuto*: Spouští inferenci v reálném čase během cyklů a zaznamenává detekce, ale neukládá žádné zvukové soubory.
- **Plán**:
    - **Doba trvání a opakování**: Zvolte, jak dlouho každý aktivní nahrávací cyklus trvá a jak často se opakuje.
    - **Okno nahrávání (denní doba)**: Zvolte nepřetržité nahrávání (*Nepřetržitě*) nebo omezte cykly na *Ve dne*, *V noci* nebo na okna *Kolem východu slunce*, *Kolem západu slunce* nebo *Kolem východu a západu slunce*. Okna východu/západu slunce se počítají dynamicky na základě souřadnic nasazení.
    - **Konec nasazení**: Zvolte, zda chcete nasazení zastavit ručně, zastavit po pevném počtu dokončených cyklů, nebo zastavit automaticky v určený den a čas.
    - **Správa baterie**: Nastavte práh slabé baterie (0–50 %), pod kterým se nahrávání pozastaví, aby se baterie úplně nevybila. Je-li nastaven, můžete zvolit i práh, při kterém nahrávací cykly automaticky pokračují, jakmile se baterie znovu dobije (např. ze solárního panelu).
    - **Testovací cyklus**: Volitelný jednominutový testovací cyklus je ve výchozím nastavení povolen pro okamžité ověření vstupu mikrofonu a inference po spuštění, aniž by se započítával do limitu plánovaných cyklů.
    - **Seskupení**: Nakonfigurujte, zda se má každý cyklus ukládat jako samostatná Session (doporučeno pro rychlejší načítání a modulární prohlížení), nebo zda se mají všechny cykly sloučit do jediné vícesegmentové Session.
- **Připraveno**: Zkontrolujte plán, odhad potřebného úložiště a omezení denní doby a poté spusťte nasazení.

Ovládací prvky nastavení používají stejné ikony jako ostatní průvodci: :app-micRounded: mikrofon, :app-speedRounded: frekvence inference, :app-verifiedRounded: spolehlivost, :app-hearing: citlivost, :app-fiberManualRecordRounded: režim nahrávání, :app-timerOutlined: kontext klipu a délka cyklu, :app-filterAltRounded: vzorkování detekcí a :app-formatListNumberedRounded: limit klipů na druh. Interval opakování používá :app-repeatRounded:, prahy slabé baterie :app-batteryAlert: a :app-batteryChargingFull:, testovací cyklus a seskupení Sessions :app-scienceRounded: a :app-libraryBooks:. Klepnutím na tlačítko :app-helpOutline: vedle ovládacího prvku zobrazíte jeho vysvětlení.

Při spuštění se okamžitě uloží `SessionType.aru` Session s metadaty plánu ARU. Nahrávací cykly se navíc ukládají každých 30 sekund, včetně cyklů bez detekcí. Po pádu aplikace nebo výpadku napájení se poslední uložené nasazení objeví v Knihovně Sessions jako ukončená Session; nahrávání se znovu nespustí. Data od posledního uložení mohou být ztracena.

Exporty JSON a ZIP obsahují metadata nasazení ARU. Exporty ZIP přibalí uložené nahrávky jednotlivých cyklů pod `aru_cycles/`.

## Aktivní nasazení

Aktivní obrazovka ARU ukazuje, zda nasazení čeká, nahrává nebo je dokončeno. Rozložení používá čtyři karty:
- **Stav**: Zobrazuje aktuální stav nasazení, aktivní časovač plánu a seznam detekcí v reálném čase.
- **Audio**: Zobrazuje živě se posouvající spektrogram pro ověření zvukového vstupu s detekcemi pod ním.
- **Plán**: Zobrazuje dalších 10 plánovaných časů cyklů s vyznačením zarovnání k východu/západu slunce, pokud je aktivní omezení denní doby.
- **Souhrn**: Shrnuje uplynulý čas, celkovou dobu nahraného zvuku a statistiky detekcí.

Na Androidu aktivní nasazení zobrazují oznámení na popředí s akcemi Zastavit a Otevřít.

Zastavení nasazení otevře Přehled Session. Pokud byly cykly seskupeny do jedné Session, otevře se tato kombinovaná Session; pokud byly uloženy jako samostatné Sessions, otevře se nejnovější dokončená Session cyklu.

V iOS zatím počítejte s tím, že nasazení funguje jen s aplikací v popředí, dokud nebude plánované nahrávání na pozadí ověřeno v terénu.

## Stále v plánu

- Terénní ověření chování na pozadí v iOS.
- Plná podpora přehrávání a spektrogramu v Přehledu Session pro segmentované nahrávky ARU.
