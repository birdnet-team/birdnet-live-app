# API Reference

## Taxonomy API

Species data is provided by the BirdNET taxonomy API hosted at Cornell.

### Base URL

```
https://birdnet.cornell.edu/taxonomy/api
```

### Species Image

```http
GET /api/image/{scientific_name}?size={size}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `scientific_name` | string | Binomial name (e.g., `Turdus merula`) |
| `size` | string | `thumb` (150×100) or `medium` (480×320) |

**Response**: WebP image (4:3 aspect ratio)

### Species Info

```http
GET /api/species/{scientific_name}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `scientific_name` | string | Binomial name |

**Response**: JSON object with species details:

```json
{
  "scientific_name": "Turdus merula",
  "common_name": "Eurasian Blackbird",
  "description": "...",
  "wikipedia_url": "https://en.wikipedia.org/wiki/Common_blackbird",
  "conservation_status": "LC",
  "range": "..."
}
```

## Sync API

Survey data synchronization API.

!!! info "Coming Soon"
    The sync API specification is pending and will be documented when the
    survey sync feature is implemented.
