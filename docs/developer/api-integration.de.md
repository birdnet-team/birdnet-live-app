<!-- TRANSLATION TODO (de) -->

# API Integration

External API usage and integration.

## Taxonomy Data

Species images, descriptions, localized names, and taxonomy metadata are bundled with the app. The local bundle tooling sources those assets from the BirdNET taxonomy API:

```
https://birdnet.cornell.edu/taxonomy/api/
```

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/image/{sci_name}?size=thumb` | 150x100 WebP thumbnail (3:2) |
| `GET /api/image/{sci_name}?size=medium` | 480x320 WebP image (3:2) |
| `GET /api/species/{sci_name}` | Full species record (descriptions, Wikipedia, links) |
| `GET /api/download/json` | Full taxonomy export used by the local bundle tooling |

### Usage

The app's default experience is offline-first: bundled species images,
descriptions, and taxonomy metadata are generated ahead of time from the public
taxonomy export. Runtime species lookups use local assets through
`TaxonomyService`; the live API is only needed when refreshing metadata exports
or building future opt-in online enrichments.

### Error Handling

The API is not required at runtime. If bundle tooling cannot reach the API, keep the existing bundled assets or retry the refresh rather than shipping a partial species bundle.
