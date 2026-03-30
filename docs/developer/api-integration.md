# API Integration

External API usage and integration.

## Taxonomy API

Species images and descriptions come from the BirdNET taxonomy API:

```
https://birdnet.cornell.edu/taxonomy/api/
```

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/image/{sci_name}?size=thumb` | 150×100 WebP thumbnail (4:3) |
| `GET /api/image/{sci_name}?size=medium` | 480×320 WebP image (4:3) |
| `GET /api/species/{sci_name}` | Full species record (descriptions, Wikipedia, links) |

### Usage

Images are loaded via `cached_network_image` for automatic caching. Species info is fetched on-demand when the user taps a detection.

### Error Handling

The API is optional — the app works fully offline. Network failures show placeholder images and a "No description available" message.
