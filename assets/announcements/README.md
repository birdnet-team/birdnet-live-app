# Spoken Announcement Templates

This folder holds the sentences BirdNET Live **speaks out loud** when it
detects a species. They are the second translation surface in the app — the
first being the ARB files in `lib/l10n/`.

> **Translating the app? Read this.** A translation pass that only covers
> `lib/l10n/app_<locale>.arb` leaves the announcements speaking English,
> because a missing or incomplete template file silently falls back to
> `templates_en.json`. The UI will look fully localized while the voice is
> not.

## Why these are not in ARB

ARB models *one key → one string per locale*. A template bucket is a *list of
interchangeable variants*, and the engine picks between them with an
anti-repeat ring buffer so the app does not sound like a robot repeating one
sentence. Expressing that in ARB would mean inventing keys like
`annBucketAChatty3`, and the number of variants legitimately differs per
language. Keeping them as JSON also means phrasing can be tuned in a PR
without regenerating l10n or touching any Dart.

Translators are encouraged to **rewrite** for their locale rather than
translate the English line by line — these are spoken sentences, and what
sounds natural in English rarely maps word for word.

## Files

One file per locale, `templates_<locale>.json`. All ten shipped locales must
be present and complete:

`en` · `de` · `cs` · `es` · `fr` · `it` · `pt` · `nl` · `pl` · `ru`

Loaded by
[`TemplateLibrary`](../../lib/features/announcements/phrasing/template_library.dart),
which resolves in this order: exact tag (`de_DE`) → language only (`de`) →
`en` as the always-available fallback.

## File shape

```json
{
  "locale": "en",
  "version": 4,
  "buckets": {
    "A": {
      "balanced": ["There's a {name}.", "That's a {name}."],
      "chatty":   ["There's a {name} calling nearby."]
    }
  },
  "commonness": {
    "rare": ["A real rarity here — nice one!"],
    "seasonalAddendum": ["And a bit out of season, too."]
  }
}
```

- `balanced` is **required** for every bucket. A bucket with an empty or
  missing `balanced` list is dropped at load time and that phrasing is lost.
- `chatty` is optional; when absent or empty the engine falls back to
  `balanced` for that bucket.
- The `minimal` verbosity level uses no templates at all — it speaks the bare
  species name — so there is nothing to translate for it.
- Aim for roughly the same number of variants as the English file. More is
  fine; one or two per bucket will sound repetitive in use.

## The ten buckets

The engine picks a bucket from detection confidence, recency, and how many
species arrived at once. All ten must be present.

| Bucket | When it is spoken | Placeholders |
|---|---|---|
| `A` | High confidence, first time / not heard recently | `{name}` |
| `B` | High confidence, heard again after a gap | `{name}` |
| `C` | High confidence, still calling (streak) | `{name}` |
| `D` | Medium confidence, fresh detection | `{name}` |
| `E` | Medium confidence, heard again after a gap | `{name}` |
| `F` | Low confidence, fresh detection | `{name}` |
| `G` | Low confidence, heard again after a gap | `{name}` |
| `H_two` | Two species at once | `{name1}`, `{name2}` |
| `H_three` | Three species at once | `{name1}`, `{name2}`, `{name3}` |
| `H_many` | Four or more at once (speaks three, implies "and more") | `{name1}`, `{name2}`, `{name3}` |

Confidence should come through in the wording: `A`/`B`/`C` state the species
plainly, `D`/`E` hedge slightly ("sounds like"), `F`/`G` hedge clearly
("might be", "hard to tell"). Keep that gradient — it is the point of the
buckets, and flattening it makes the app sound overconfident about weak
detections.

`H_two` has only two slots on purpose, so the app never speaks a half-filled
"…A, B, and ." phrase.

## Commonness phrases (Chatty only)

Appended the first time a species is announced in a session, when the app
knows how common it is at the user's location. The six bins mirror the
Explore screen's tiers exactly: `rare`, `scarce`, `uncommon`, `frequent`,
`common`, `abundant`.

`seasonalAddendum` is an optional tail added after the commonness phrase when
the species is below its annual peak at that location. Ship an empty list to
opt out; a locale that opts out simply skips the tail.

These phrases must read naturally **after** a bucket sentence, since that is
where they land: *"There's a Robin. A real rarity here — nice one!"*

## Rule: never put an article or demonstrative before `{name}`

This is the single easiest thing to get wrong. Species names carry no
grammatical gender in our data, so the app cannot inflect a determiner to
agree with them — *der Zaunkönig* / *die Amsel* / *das Rotkehlchen*, *un
merle* / *une mésange*, *de roodborst* / *het roodborstje*.

Write around it instead:

```text
✗ "Das ist ein {name}."          ✓ "Da: {name}."
✗ "C'est un {name}."             ✓ "On dirait {name}."
✗ "To jest ten {name}."          ✓ "Słychać: {name}."
```

Slavic locales have no articles, but a **demonstrative** forces the same
agreement (`ten`/`ta`/`to`, `этот`/`эта`/`это`) — avoid those before `{name}`
too. The same applies to past-tense verb forms and case government in `pl`
and `ru`: prefer colon-and-name or nominative constructions that stay valid
whatever the species' gender turns out to be.

A lint test catches gendered determiners automatically
(`test/features/announcements/templates_gender_lint_test.dart`), but it is a
regex and cannot catch case or verb agreement — new lines still need a native
speaker's eye.

## Other conventions

- **Keep it short.** These are spoken while the user is listening to birds.
  One clause is usually right; two is the maximum.
- **Punctuation is for the voice, not the eye.** A period or dash gives the
  TTS engine a pause. Avoid parentheses, quotes, and semicolons — engines
  read them unpredictably.
- **No abbreviations or symbols** (`&`, `approx.`, `#`) — write the word out
  so the engine pronounces it.
- **Match the register the locale uses in the ARB files** (for example: `nl`
  uses *je*, `ru` uses вы). The voice should not be formal where the UI is
  informal.
- **Do not translate `{name}`, `{name1}`, `{name2}`, `{name3}`** — they are
  substituted at speak time.

## Workflow

1. Copy `templates_en.json` to `templates_<locale>.json` if it does not exist,
   set `"locale"`, and rewrite the strings.
2. Run the guard tests:

    ```bash
    flutter test test/features/announcements/
    ```

    These check that every locale defines all ten buckets and all six
    commonness bins, and lint for gendered determiners before `{name}`.
3. Hear it: **Settings → Announcements → Preview** speaks a sample using the
   current phrasing style and voice. Switch the app language first.

Background on the design, bucket routing, and throttling lives in
[`dev/announcements.md`](../../dev/announcements.md) §3.
