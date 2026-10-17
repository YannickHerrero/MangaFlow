# API v1

All routes start with `/api/v1`. JSON field names match the Swift `Codable` models in `MangaFlow/Remote/RemoteModels.swift`. Manga and chapter IDs are opaque strings; they only travel in JSON bodies, never as route segments.

Except `health` and `pair/exchange`, every route and artifact download requires `Authorization: Bearer <device token>`. Errors are `{ "error": { "code": "…", "message": "…" } }` with an appropriate non-2xx status. No permanent token is included in pairing QR payloads.

| Method | Route | Purpose |
|---|---|---|
| GET | `/health` | Public API version and server identity |
| POST | `/pair/exchange` | Consume `{secret, serverID, deviceName}` once; return `{deviceID, token, serverID}` |
| DELETE | `/device` | Revoke this device |
| GET | `/server` | Active engine version and update state/error |
| GET | `/sources?q=&language=` | Enabled sources, languages, tags, capabilities, availability and catalog status |
| GET | `/catalog?sourceID=&q=&offset=&limit=` | Search last valid local catalog; 50 items default, 100 maximum |
| POST | `/catalog/sync` | `{sourceID}` → 202 catalog job |
| POST | `/chapters` | `{sourceID,manga:{id}}` → 202 chapter listing job |
| POST | `/downloads` | `{sourceID,manga:{id},chapter:{id}}` → 202 download job |
| GET | `/jobs` | Current device’s most recent jobs |
| GET | `/jobs/:uuid` | One job, including progress/error/result/artifact ID |
| POST | `/jobs/:uuid/cancel` | Cancel queued/running job |
| GET | `/artifacts/:uuid` | CBZ metadata: filename, byte size, SHA-256, expiry |
| GET | `/artifacts/:uuid/file` | Authenticated complete CBZ; includes Content-Length and X-Content-SHA256 |

Long operations return a durable job immediately. Poll `/jobs` every four seconds while foregrounded; completed chapter jobs expose `result.chapters`. Downloads expose `artifactID` only after all expected pages and the final ZIP have been validated and atomically published. `Idempotency-Key` is optional for task creation. The server validates manga IDs against the catalog and chapter IDs against connector results.

Stable error codes include `pairing_invalid`, `authentication_invalid`, `source_unavailable`, `connector_incompatible`, `connector_broken`, `catalog_not_synced`, `network_failed`, `chapter_unavailable`, `image_unavailable`, `rate_limited` and `not_found`. `server_unreachable` is a mobile-side connection error, not an HTTP response from an unreachable server.

Catalog status includes `syncedAt` (last successful update), `state` and `lastError`. A failed synchronization does not erase a prior successful catalog. Sources without a complete catalog advertise `capabilities.catalog = false` and an explanation.
