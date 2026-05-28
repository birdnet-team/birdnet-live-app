# BirdNET Live Store Mockup Generator

This folder contains the tracked store screenshot mockup generator for Play Store and App Store assets. The rest of `dev/` stays ignored, except for `dev/sync_version.dart`.

The generator has no npm dependencies and uses a locally installed Chrome, Edge, or Chromium browser for PNG export.

## Preview

Open `preview.html` in a browser to see all mockups at once.

For a working **Render** button in the preview, run the local server from this folder:

```powershell
node server.js
```

Then open:

```text
http://127.0.0.1:4177/preview.html
```

Language can be changed with the dropdown or a URL parameter:

```text
preview.html?lang=en
preview.html?lang=de
preview.html?lang=es
```

## Editing Copy

Edit titles and subtitles for all languages in:

```text
mockups.copy.md
```

Then sync the browser preview:

```powershell
node sync-copy.js
```

The render script also syncs `mockups.copy.md` automatically before exporting.

## Editing Slides

Edit slide order, screenshots, and accent colors in:

```text
mockups.config.js
```

Required source assets:

```text
empty_phone_frame.png
screenshot_live_mode.png
screenshot_main_menu.png
screenshot_explore.png
screenshot_file_analysis.png
screenshot_session_review.png
screenshot_species_overlay.png
```

The screenshots are stretched a little to fill the frame opening. This is intentional so the final store image has a clean App Store / Play portrait aspect ratio.

## Render PNGs

Run from this folder:

```powershell
node render-mockups.js --lang en
```

Render every configured language:

```powershell
node render-mockups.js --all-languages
```

Render one slide only:

```powershell
node render-mockups.js --lang en --slide live
```

Render clean standalone device screenshots with transparent backgrounds:

```powershell
node render-mockups.js --device-screenshots
```

If Chrome or Edge is not found automatically, pass the browser path:

```powershell
node render-mockups.js --browser "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

## Output

Generated files are written to:

```text
output/<language>/<language>-01-menu.png
output/<language>/<language>-02-live.png
output/<language>/<language>-03-review.png
output/<language>/<language>-04-explore.png
output/<language>/<language>-05-species.png
output/<language>/<language>-06-files.png
```

Clean device screenshots are written to:

```text
output/screenshots/01-menu.png
output/screenshots/02-live.png
output/screenshots/03-review.png
output/screenshots/04-explore.png
output/screenshots/05-species.png
output/screenshots/06-files.png
```

Current store mockup canvas size is `1290 x 2796 px`; clean device screenshots are `1592 x 3546 px`. Both are configured in `mockups.config.js`.