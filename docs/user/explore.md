# Explore

Explore shows species predicted for the current location and season using the BirdNET geo-model.

## How to Open It

Open **Explore** from the Home footer using the :app-searchRounded: button.

## App Bar and Header

### App bar

- :app-refresh: — refresh location and rebuild the predicted species list

### Location header

The header shows:

- current reverse-geocoded place name when available
- coordinates below the place name
- :app-helpOutlineRounded: — open the Explore help sheet

## Species List

Each species card can include:

- bundled species image
- common name
- optional scientific name
- abundance tier chip

Tap a card to open the species details overlay.

### Abundance tiers

Instead of a raw percentage, each card shows an **abundance tier** for the current place and season. The tier chip combines two cues:

- a **circle** that fills from ⅙ to full as the species becomes more likely
- the **first letter** of the tier name (the full name is read aloud by screen readers and shown on the species details overlay)

The chip color follows the app's shared score scale, moving from red (less likely) to green (more likely) as the tier rises.

There are six tiers, from most to least likely:

| Tier | Meaning |
| --- | --- |
| **Abundant** | Among the strongest predictions here |
| **Common** | Very likely |
| **Frequent** | Likely |
| **Uncommon** | Possible |
| **Scarce** | Unlikely |
| **Rare** | Among the weakest predictions here |

Tiers are **relative to the current location**. They adapt to how strongly the geo-model predicts species in this area, so the boundaries shift with the local score distribution: in a place with many confident predictions a species needs a very high score to be *Abundant*, while in an area with weaker predictions the same tier is reached at a lower score. This means the same score can fall into different tiers in different places, which keeps the ranking meaningful everywhere.

## Species Details Overlay

The overlay can show:

- larger image
- image credit
- common and scientific names
- bundled description text when available
- weekly expected-frequency chart
- external links such as eBird, iNaturalist, or Wikipedia when available for that species

## What Explore Is For

Explore is a location-aware reference view inside the app. It helps you compare the app's current location context with the species you might expect to encounter.

It does **not** change saved session data by itself. Detection filtering is controlled separately through [Settings](settings.md).