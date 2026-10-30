# Nahrávání

Nahrávání odesílá dokončené Sessions z mnoha telefonů do jedné projektové složky. Vedoucí projektu složku jednou nastaví a rozdá odkaz nebo QR kód; každý přispěvatel ho vloží nebo naskenuje a od té chvíle lze kteroukoli Session odeslat do této složky dvěma klepnutími z dialogu Sdílet. Nasazení ARU mohou odesílat každou dokončenou Session sama.

Nahrávání je jednosměrné. Aplikace do projektové složky soubory zapisuje a nikdy v ní nic nečte, nevypisuje ani nemaže. Smazání Session v telefonu ponechá nahranou kopii nedotčenou a nic se nikdy nenahraje, pokud jste nezaškrtli cíl nebo nezapnuli automatické nahrávání ARU.

## Jak to funguje

**Cíl** je složka WebDAV, do které aplikace může zapisovat. Bez dalšího nastavování fungují tři druhy:

- sdílení **Nextcloud File Drop**, doporučená volba pro většinu projektů;
- libovolná **adresa WebDAV** s uživatelským jménem a heslem, například složka ve vašem vlastním cloudovém účtu nebo na institucionálním serveru;
- **referenční drop server**, který je součástí BirdNET Live, pro vedoucí, kteří chtějí tokeny pro jednotlivé přispěvatele a hotový export CSV (viz [Příručka pro vývojáře](../developer/upload-drop-server.md)).

Každé nahrání je **jeden soubor ZIP na Session**, pojmenovaný stejně jako export Sdílení, například `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. Vždy obsahuje záznam JSON dané Session a podle toho, co zaškrtnete, také zvuk, tabulky detekcí, HTML zprávu a soubor metadat aplikace. ZIP se uloží do složky pojmenované vaším **ID pro nahrávání**, osmimístným kódem, který aplikace odvozuje z náhodné identity uchovávané pro tuto instalaci. Složka vedoucího projektu tedy vypadá takto:

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

Složka `.birdnet-live` obsahuje jeden malý registrační soubor na zařízení, zapsaný testem připojení. Nextcloud ji skrývá, pokud není zapnuto „Zobrazit skryté soubory“. Nese ID pro nahrávání, verzi aplikace, platformu a nepovinný **identifikátor účastníka** (jméno, e-mail nebo číslo účastníka), který přispěvatel zadal, takže vedoucí pozná, kdo za kterým kódem stojí, aniž by se jakékoli jméno kdy stalo názvem složky. Stejný identifikátor se zapisuje do záznamu JSON každé nahrané Session.

## Pro vedoucí projektů

### Možnost A: Nextcloud File Drop

1. V Nextcloudu vytvořte složku pro projekt, například `Spring Survey 2027`.
2. Otevřete její panel sdílení, vytvořte **odkaz pro sdílení** a nastavte jeho oprávnění na **Odevzdávání souborů (pouze nahrávání)**. Přispěvatelé pak mohou soubory přidávat, ale nikdy nevidí, co odeslali ostatní.
3. Nastavte na odkaz **heslo**. Bez něj může do složky nahrávat každý, kdo odkaz najde. File Drop ani tak nelze číst, takže chybějící heslo je volba, kterou aplikace přijme bez námitek.
4. Volitelně nastavte datum vypršení platnosti na konec projektu.
5. Zkopírujte odkaz pro sdílení. Vypadá takto: `https://cloud.example.org/s/AbCdEf123456`.

Aplikace si tento odkaz sama převede na koncový bod WebDAV daného sdílení; přispěvatelé adresu WebDAV nikdy nevidí. File Drop nikdy nepřepisuje: když přispěvatel nahraje stejnou Session znovu, Nextcloud ponechá starší kopii pod očíslovaným názvem, takže nejnovější soubor je ten bez čísla.

Fungují také sdílení Nextcloud s oprávněním **nahrávání a úpravy**, aplikace však přispěvatele upozorní, že přihlašovací údaje mohou vypsat obsah složky, protože každý s odkazem pak může číst data všech ostatních. Sdílení jen pro čtení test připojení odmítne.

### Možnost B: vlastní složka WebDAV

Funguje libovolný server WebDAV: složka v osobním cloudovém účtu, institucionální souborový server, ownCloud nebo Nextcloud s běžným účtem. Přispěvatelé při připojování zadají adresu spolu s uživatelským jménem a heslem pod **Rozšířené**. U účtu Nextcloud nebo ownCloud použijte **heslo aplikace** z nastavení zabezpečení účtu, nikdy přihlašovací heslo; je-li zadán jen název hostitele, aplikace na něm zkusí i obvyklá umístění Nextcloudu a ownCloudu.

Takové přihlašovací údaje obvykle složku mohou číst, test připojení proto zobrazí varování. Pokud přispěvatelé nejsou všichni z jednoho týmu, dejte přednost nastavení jen pro zápis.

### Možnost C: referenční drop server

`tools/webdav_drop_server` ve zdrojovém repozitáři je malý server v Pythonu s tokeny pro jednotlivé přispěvatele, které můžete odvolat, příkazem `collect`, který sloučí každý nahraný záznam JSON do souborů `sessions.csv`, `detections.csv` a `species_summary.csv`, a příkazem `invite`, který vypíše odkaz pro připojení a QR kód. Nastavení a nasazení popisuje [Příručka pro vývojáře](../developer/upload-drop-server.md).

### Vytvoření odkazu pro připojení a QR kódu

Odkaz pro připojení nese vše, co přispěvatel potřebuje, v jednom kuse: cíl, přihlašovací údaje, název projektu a vámi navržené výchozí hodnoty. Otevřete [stránku pro připojení](../join.md) na tomto webu a vyplňte:

- **Share link or WebDAV address**: odkaz pro sdílení Nextcloud z předchozího kroku, nebo adresa složky WebDAV.
- **User name**: u odkazu pro sdílení Nextcloud ponechte prázdné.
- **Share password or token**: heslo sdílení, nebo tajný údaj účtu či token.
- **Project name shown in the app**: co přispěvatelé uvidí jako název cíle. Mohou ho přejmenovat, ale toto je výchozí hodnota.
- **Suggest including audio** a **Suggest Wi-Fi only**: výchozí hodnoty přepínačů cíle.

Stiskněte **Build link and QR code**. Vše proběhne ve vašem prohlížeči; nikam se nic neodesílá. Tajný údaj je v části odkazu za `#`, kterou prohlížeče nikdy nepřenášejí webovému serveru, jenž stránku hostuje.

Případně se k cíli nejprve připojte na vlastním telefonu (viz níže), poté cíl otevřete v **Nastavení → Export a synchronizace → Cíle nahrávání** a klepněte na **Zobrazit kód pro připojení**. Aplikace zobrazí stejný druh QR kódu s tlačítkem **Kopírovat odkaz**.

### Předání přispěvatelům

QR kód vytiskněte na terénní formulář, ukažte ho na obrazovce při instruktáži nebo pošlete odkaz zprávou. **S odkazem i kódem zacházejte jako s heslem**: kdokoli ho má, může nahrávat do vašeho projektu. Pokud unikne, změňte heslo sdílení nebo odvolejte token a rozdejte nový kód.

Když přispěvatel naskenuje kód fotoaparátem telefonu, prohlížeč otevře malou úvodní stránku s tlačítkem **Open in BirdNET Live**, které ho přenese na obrazovku Přidat cíl v aplikaci s již vyplněným odkazem. Přímé vložení odkazu na tuto obrazovku funguje úplně stejně.

### Co uvidíte

Jednu složku na zařízení, jeden ZIP na Session a skryté registrace `.birdnet-live`. Po otevření ZIPu najdete záznam JSON (vždy přítomný) a tabulky, zprávu a zvuk, které se přispěvatel rozhodl zahrnout. Chcete-li zjistit, která osoba stojí za ID pro nahrávání, přečtěte si registrační soubor pro daný kód nebo pole `meta.participant` v kterémkoli z jeho záznamů JSON. U referenčního drop serveru to za vás udělá `collect` a zapíše sloupec `participant`.

## Pro přispěvatele

### Připojení k cíli

1. Otevřete **Nastavení → Export a synchronizace → Cíle nahrávání** a klepněte na **Přidat cíl**. Naskenování QR kódu projektu fotoaparátem nebo klepnutí na obdržený odkaz pro připojení vás přenese na stejnou obrazovku s již vyplněným odkazem.
2. Vložte odkaz pro připojení, odkaz pro sdílení Nextcloud nebo adresu WebDAV do pole **Odkaz pro připojení nebo adresa serveru**. Tlačítko **Vložit** ho převezme ze schránky.
3. Volitelně vyplňte pole **ID účastníka, jméno nebo e-mail (nepovinné)**. Ukládá se s každým nahráním, aby vedoucí projektu věděl, kdo ho poslal, a nikdy se neobjeví v názvech složek. Pod polem aplikace zobrazuje **Vaše ID pro nahrávání**, složku, do které budou vaše nahrání ukládána.
4. U běžné adresy WebDAV otevřete **Rozšířené** a zadejte **Uživatelské jméno** a **Heslo nebo token**. Odkaz pro sdílení Nextcloud nepotřebuje ani jedno; má-li sdílení heslo, zadejte ho jako heslo.
5. Klepněte na **Otestovat připojení**. Aplikace kontaktuje server, vytvoří skrytou registrační složku, zkontroluje, zda přihlašovací údaje mohou vypsat obsah složky, a zapíše váš registrační soubor. Výsledkem je jedna věta: **Připojení funguje**, varování, které byste si měli přečíst, nebo selhání s pravděpodobnou nápravou.
6. Zadejte cíli **Název cíle** (předvyplněný z odkazu pro připojení), rozhodněte, zda **Nahrávat pouze přes Wi-Fi**, a klepněte na **Uložit cíl**.

Dokud test neprojde, nic se neuloží. Přihlašovací údaje se ukládají do klíčenky zařízení, nikdy do exportovaných dat.

Varování, kterým stojí za to porozumět:

- **Tyto přihlašovací údaje mohou vypsat obsah cíle** znamená, že sdílení nebo účet může číst data ostatních přispěvatelů. Nahrávání funguje, ale pokud se projektu účastní lidé mimo váš tým, požádejte vedoucího o File Drop nebo token jen pro zápis.
- **Toto sdílení nemá heslo a lze jej vypsat** spojuje obě rizika: každý, kdo má odkaz, může číst vše. Požádejte vedoucího, aby nastavil heslo nebo použil File Drop.
- **Tento server nepovoluje složky** je pouze informativní: nahrávání používá ploché názvy souborů, například `4ee91c8f__BirdNET_Live_….zip`, místo složky.

### Obrazovka cíle

Klepnutím na cíl v seznamu otevřete jeho obrazovku s adresou serveru, údaji o tom, kdy byl přidán a naposledy použit, a těmito ovládacími prvky:

- **Přejmenovat** (tužka v horní liště aplikace) změní název zobrazený v aplikaci.
- **Nahrávat pouze přes Wi-Fi** pozdrží nahrávání, dokud je telefon na mobilních datech.
- **Nahrávat všechny Sessions automaticky** zařadí každou dokončenou Session z libovolného režimu do fronty pro tento cíl bez dotazu, s výchozími hodnotami Export a synchronizace pro Zvuk a Metadata. Dokud je tato možnost zapnutá, zůstává zapnutá i **Nahrávat ARU Sessions automaticky**. Pokud Session následně v Session Review zahodíte, nahrávání, které ještě nezačalo, se zruší, ale to, co už bylo odesláno, zůstane na serveru.
- **Nahrávat ARU Sessions automaticky** zařadí každou dokončenou ARU Session do fronty pro tento cíl bez dotazu (viz níže).
- **Otestovat připojení** zopakuje test připojení, například po tom, co vedoucí změnil heslo.
- **Zobrazit kód pro připojení** zobrazí QR kód spolu s **Kopírovat odkaz**, aby se k témuž cíli mohl připojit druhý telefon.
- **Odebrat cíl** zapomene cíl i jeho přihlašovací údaje a zahodí čekající nahrání do něj. Již nahrané Sessions zůstanou na serveru.

Prvním záznamem seznamu cílů je **Vaše ID pro nahrávání** s identifikátorem účastníka pod ním; klepnutím na něj identifikátor změníte. Jeho změna na serveru nic nepřesune, protože složky jsou pojmenovány podle ID.

### Nahrání Session

Nahrávání se spouští stejnou akcí **Sdílet**, kterou už používáte, na třech místech:

- **nabídka se třemi tečkami** (:app-moreVert:) na kartě Session v Knihovně Sessions;
- tlačítko **Sdílet** po výběru několika Sessions v Knihovně Sessions;
- ikona **Sdílet** (:app-share:) na panelu nástrojů Přehledu Session.

Jakmile existuje alespoň jeden cíl, má dialog Sdílet dvě karty:

- **Obsah** určuje, co export obsahuje: **Zvuk** (celou nahrávku, nebo klipy detekcí, pokud byly uchovány jen klipy) a **Metadata** (tabulky, zprávu a soubor metadat aplikace zapnuté v Export a synchronizace). Políčka na začátku odpovídají vašim nastavením a platí jen pro toto sdílení.
- **Odeslat do** uvádí **Dialog sdílení** (jiné aplikace, soubory, zprávy) a jedno políčko pro každý cíl. Odznak na kartě počítá zaškrtnuté cíle. Cíle zaškrtnuté minule jsou předem zaškrtnuté, kromě těch, do kterých tato Session už byla odeslána: ty začínají nezaškrtnuté a zobrazují **Nahráno** s datem a **Zaškrtněte pro opětovné nahrání**. Při otevření dialogu aplikace každý cíl tiše zkontroluje; pokud server oznámí, že by nahrání odmítl, například protože se změnilo heslo nebo bylo sdílení odstraněno, řádek zčervená a zobrazí důvod.

Odškrtněte **Dialog sdílení** a tlačítko bude znít **Nahrát**; s obojím zaškrtnutým zní **Sdílet a nahrát**. Snackbar potvrdí, kolik Sessions bylo zařazeno do fronty. Session jde vždy nejprve do fronty a nahrává se na pozadí, takže můžete dál pracovat.

### Sledování nahrávání

Karta Session v Knihovně Sessions zobrazuje stav jako první řádek pod názvem Session: **Ve frontě**, **Čeká na Wi-Fi**, **Čeká na připojení k síti**, **Nahrává se…**, **Nahráno** s datem, nebo selhání. Klepnutím na řádek otevřete seznam podle cílů s **Zkusit znovu nyní** a **Odebrat z fronty**. Přehled Session zobrazuje stejný stav jako ikonu mraku v horní liště aplikace; klepnutí na ni otevře stejný seznam.

Neúspěšná nahrání se opakují sama s rostoucími prodlevami, až šest hodin od sebe, nejvýše třicetkrát. **Selhalo, zkusí se znovu** znamená, že se aplikace pokusí znovu. **Nahrání se nezdařilo. Zkontrolujte nastavení cíle.** znamená, že server odmítl a opakování nepomůže: změnilo se heslo, nahrávání bylo vypnuto nebo byl cíl odstraněn. Otevřete cíl, spusťte **Otestovat připojení** a pokud se přihlašovací údaje změnily, cíl odeberte a přidejte znovu.

Řádek i ikona se zobrazují jen tehdy, dokud alespoň jeden cíl, do kterého byla Session odeslána, v Nastavení stále existuje. Odeberte cíl a zmizí, protože „nahráno“ už není skutečností o žádném cíli, který máte.

### Co běží na pozadí

Nahrání ve frontě běží, dokud je aplikace otevřená, a vždy, když se vrátí do popředí. Na Androidu běží i při zavřené aplikaci: systém je spustí, jakmile je k dispozici vhodná síť — Wi-Fi, pokud to cíl vyžaduje —, a opakuje pokusy, dokud fronta není prázdná. Na iOS nahrávání běží, dokud je aplikace otevřená.

### Opětovné nahrání Session

Opětovné nahrání téže Session, například po opravě detekcí v Přehledu Session, zapíše stejný název souboru do stejné složky. Servery, které to umožňují, soubor nahradí; Nextcloud File Drop místo toho ponechá starší kopii pod očíslovaným názvem. V obou případech dostane vedoucí projektu nejnovější verzi a nic se nemaže.

## Režim ARU

Terénní nasazení vytvářejí mnoho Sessions, často když u telefonu nikdo není. Zapněte u cíle **Nahrávat ARU Sessions automaticky** a každá dokončená ARU Session se pro něj zařadí do fronty bez dialogu, s výchozími hodnotami Export a synchronizace pro Zvuk a Metadata. Nasazení, které ukládá každý cyklus jako samostatnou Session, nahrává cyklus po cyklu; sloučená Session nasazení se nenahrává dvakrát.

U stanice na mobilním tarifu ponechte **Nahrávat pouze přes Wi-Fi** zapnuté, pokud tarif zvuk neunese, a zvažte nahrávání **Jen detekce** nebo **Vypnuto**, když by byl zvuk k odeslání příliš velký. Nahrání pak odtékají, kdykoli telefon vidí vhodnou síť, na Androidu i tehdy, když je aplikace na pozadí.

## Dva příklady z praxe

### Víkendová survey s Nextcloud File Drop

Vedoucí vytvoří v univerzitním Nextcloudu složku `Birdathon 2027`, nasdílí ji jako File Drop s heslem, vloží odkaz pro sdílení a heslo na stránku pro připojení, pojmenuje projekt a vytiskne QR kód na instruktážní list. Dvacet dobrovolníků ho v sobotu ráno naskenuje, zadá své jméno jako identifikátor účastníka, projde testem připojení a uloží.

V neděli večer každý dobrovolník otevře Knihovnu Sessions, vybere víkendové Sessions, klepne na Sdílet, ponechá projekt zaškrtnutý pod Odeslat do a klepne na **Nahrát**. Nahrání počkají na domácí Wi-Fi a dokončí se přes noc. V pondělí vedoucí najde dvacet složek pojmenovaných podle ID pro nahrávání, každou s několika ZIPy, a jména dobrovolníků si přečte ze skrytých registračních souborů nebo z pole `meta.participant` v záznamech JSON.

### Opravy v Přehledu Session, poté stanice ARU

Přispěvatel zkontroluje Session, odstraní dvě falešné detekce, ručně přidá druh a uloží. Ikona mraku v horní liště Přehledu Session ukazuje, že Session byla nahrána v sobotu. Klepne na ikonu Sdílet na panelu nástrojů, zaškrtne projekt pod Odeslat do, kde začíná nezaškrtnutý a uvádí **Nahráno** s datem, a stiskne **Nahrát**. Opravený ZIP nahradí ten dřívější, nebo na File Drop přistane vedle něj pod očíslovaným názvem.

Tentýž přispěvatel nechá telefon jako stanici ARU u rákosiny s Wi-Fi hotspotem v chatě. Na tomto telefonu se připojí k cíli projektu, zapne **Nahrávat ARU Sessions automaticky** a ponechá zapnuté **Nahrávat pouze přes Wi-Fi**. Každé ráno se dokončené noční cykly zařadí do fronty a nahrají, zatímco stanice nečinně čeká; vedoucí vidí, jak se pod ID pro nahrávání tohoto telefonu objevují nové ZIPy, aniž by na něj kdokoli sáhl.

## Soukromí a odpovědnost

Cíle nahrávání provozují organizátoři projektů, nikoli tým BirdNET. Složka, server, kdo ji může číst a jak dlouho jsou data uchovávána, se řídí vlastními pravidly organizátora pro ochranu soukromí a zabezpečení; než se připojíte, požádejte ho o podrobnosti. BirdNET Live zapisuje jen to, co jste se rozhodli odeslat, a přihlašovací údaje uchovává v klíčence vašeho zařízení.

Nahrání obsahuje to, co by obsahovalo Sdílení: záznam JSON Session s detekcemi, časy, souřadnicemi, jménem pozorovatele a názvem místa, jsou-li nastaveny, ID pro nahrávání zařízení, vámi zadaný identifikátor účastníka a verzi aplikace; plus zvuk, tabulky a zprávu, které jste zaškrtli. Před odesláním zkontrolujte kartu Obsah a vynechte zvuk, pokud nahrávka může obsahovat hlasy nebo cokoli jiného, co byste projektu nepředali. **Za to, co nahráváte, odpovídáte vy.** Nenahrávejte ani nesdílejte data, která považujete za soukromá nebo důvěrná, a nenahrávejte nahrávky, které nesmíte předávat dál.

## Řešení problémů

| Zpráva | Co znamená | Co dělat |
| --- | --- | --- |
| Toto nevypadá jako odkaz ani adresa serveru. | Text není URL. | Vložte celý odkaz pro připojení, odkaz pro sdílení nebo adresu `https://`. |
| Server odmítl přihlašovací údaje. | Špatné nebo chybějící heslo, nebo odstraněné sdílení. Nextcloud takto odpovídá i u smazaných sdílení. | Použijte heslo sdílení nebo heslo aplikace; zeptejte se vedoucího, zda sdílení stále existuje. |
| Tato adresa není koncový bod WebDAV. | Vložili jste webovou stránku složky, nikoli odkaz pro sdílení nebo adresu WebDAV. | Vložte odkaz pro sdílení (`…/s/…`) nebo adresu WebDAV. |
| Nahrávání sem není povoleno. | Sdílení je jen pro čtení. | Požádejte vedoucího o File Drop nebo oprávnění k nahrávání. |
| Složka na serveru neexistuje. | Adresa neukazuje na nic, nebo byla složka smazána. | Ověřte adresu u vedoucího. |
| Certifikát serveru se nepodařilo ověřit. | Certifikát podepsaný svým držitelem nebo rozbité TLS. | Požádejte vedoucího o adresu s platným certifikátem. |
| Tato adresa používá nešifrované HTTP. | Nešifrované připojení mimo vaši místní síť. | Použijte adresu `https://`. |
| Čeká na Wi-Fi | Cíl je nastaven pouze na Wi-Fi a telefon je na mobilních datech. | Počkejte, nebo u cíle vypněte přepínač pouze přes Wi-Fi. |
| Selhalo, zkusí se znovu | Dočasný problém, například přerušené připojení nebo chyba serveru. | Nic; aplikace to zkusí znovu sama. **Zkusit znovu nyní** vynutí pokus. |
| Nahrání se nezdařilo. Zkontrolujte nastavení cíle. | Server odmítl z důvodu, který opakování nevyřeší. | Otevřete cíl, spusťte **Otestovat připojení** a pokud se přihlašovací údaje změnily, cíl odeberte a přidejte znovu. |
| Přihlašovací údaje k tomuto cíli v klíčence zařízení chybí. | Záznam v klíčence byl ztracen, například po obnovení do nového telefonu. | Odeberte cíl a přidejte ho znovu. |

Viz také nastavení [Cíle nahrávání](settings.md#cíle-nahrávání) a příručky [Knihovna Sessions](session-library.md) a [Přehled Session](session-review.md).
