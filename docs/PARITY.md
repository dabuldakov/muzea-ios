# Android → iOS parity matrix

Feature IDs come from the Android `docs/FEATURE_CATALOG.md` (v1.7.40). This file is
the iOS backlog: update the status as work lands. Status values:

- `done` — ported and tested on a device;
- `partial` — basic version exists, parity work remains;
- `missing` — not implemented;
- `n/a` — Android-only / backend-only / not applicable to iOS.

> Rule: a feature is `done` only when it has unit/contract tests and a device smoke
> check. Add the test file names next to the status when you close an item.

## UI

| ID | Feature | iOS | Notes |
|---|---|---|---|
| UI.01 | Theme components | partial | SwiftUI native; need a shared theme/design tokens layer |
| UI.02 | Fonts | partial | system fonts; custom sizes not unified |
| UI.03 | Chat screen, bubbles | partial | text + replies, forwarding, reactions, pins; attachments/media missing |
| UI.04 | Animations | missing | charge button, delete, transitions |
| UI.05 | Haptics | missing | |
| UI.06 | Dark theme | partial | follows system; explicit palette needed |
| UI.07 | Accessibility | missing | labels, dynamic type, contrast |
| UI.08 | Adaptivity | partial | iPhone portrait only |
| UI.09 | Localization | partial | RU strings; EN + pluralization missing |
| UI.10 | 6-line composer | partial | `1...6` implemented; device check pending |
| UI.11 | Hide tab bar in chat | partial | `.toolbar(.hidden, for: .tabBar)`; device check pending |
| UI.12 | Emoji + GIF button | missing | |
| UI.13 | Composer layout | partial | attach button/width |
| UI.14 | Settings screen | missing | |
| UI.15 | Tab order | missing | |
| UI.16 | Insets/keyboard | partial | verify on device |

## MSG — messenger

| ID | Feature | iOS | Notes |
|---|---|---|---|
| MSG.01 | Text engine | done | optimistic send + reducer |
| MSG.02 | Send-button charge | partial | hold-to-charge 0..100, `power` in send body, haptics; tests in `ChatTextParityTests`; device check pending |
| MSG.03 | Cancel mechanics | partial | swipe up/left cancels, red indicator; tests in `ChatTextParityTests`; device check pending |
| MSG.04 | Local cache + outbox | missing | disk outbox, retry, persistence |
| MSG.05 | Replies / edits / forward | partial | reply/edit/delete/forward + comment; tests in `ChatTextParityTests`; device smoke pending |
| MSG.06 | @mentions | partial | composer suggestions from group participants; tests in `ChatTextParityTests` |
| MSG.07 | Multi-select | partial | select, forward, delete; tests in `ChatTextParityTests` |
| MSG.08 | Pinned messages | partial | top bar, pin/unpin, jump; tests in `ChatTextParityTests` |
| MSG.09 | Read receipts | partial | ticks from receipts + group status sheet; tests in `ChatTextParityTests` |
| MSG.10 | Message search | missing | backend has endpoints |
| MSG.11 | Drafts | partial | `UserDefaultsChatDraftStore`; tests in `ChatTextParityTests` |
| MSG.12 | Scroll anchor | partial | verify on device |
| MSG.13 | Group rename | missing | API exists (`PUT /api/chats/{uuid}`) |
| MSG.14 | Remove participant | missing | API exists |
| MSG.15 | Remove contact | missing | API exists |
| MSG.16 | Reactions | partial | toggle + inline chips + menu; full refresh every 15 s (not in `/updated`); tests in `ChatTextParityTests` |
| MSG.17 | Unread in chat list | partial | reload on return from conversation; tests/device check pending |

## MEDIA — chat attachments

| ID | Feature | iOS | Notes |
|---|---|---|---|
| MEDIA.01 | Photos | missing | upload/bind/display |
| MEDIA.02 | Video | missing | chat video; compression/progress |
| MEDIA.03 | Voice messages | missing | AVAudioRecorder + player |
| MEDIA.04 | Video notes (circles) | missing | AVCaptureSession |
| MEDIA.05 | GIF (Klipy) | missing | client-side search + server metadata |
| MEDIA.06 | Documents | missing | PDF/Office download + preview |
| MEDIA.07 | Save to Files/Photos | missing | Files/Share Sheet |
| MEDIA.08 | Upload queue | missing | disk queue, retry on network |
| MEDIA.09 | Open/share after download | missing | |
| MEDIA.10 | GIF cache | missing | |
| MEDIA.12 | Image viewer | missing | |
| MEDIA.13 | Server thumbnails | n/a | backend plan; client just uses URLs |
| MEDIA.14 | CDN/presigned | n/a | backend plan |

## FEED / video / profile

| ID | Feature | iOS | Notes |
|---|---|---|---|
| FEED.01 | News creation | done | image + related video |
| FEED.02 | Feed filter (contacts + self) | done | |
| FEED.03 | Post TTL | n/a | not implemented |
| FEED.04 | Author subscriptions | missing | |
| FEED.05 | Feed periods | missing | |
| FEED.06 | Rename to “Blams” | n/a | product decision |
| — | Video feed/upload/delete/playback | partial | verify live contract; report/block missing |
| — | News report (UGC) | missing | `/api/reports` |
| — | Profile edit/avatar | done | |
| — | Account delete/deactivation | done | deactivation in chat + auth + makeup (SEC.06) |
| — | Cache clear | missing | |
| — | App update check | n/a | no self-update on iOS; link to TestFlight/App Store |

## NET — network, sync, notifications

| ID | Feature | iOS | Notes |
|---|---|---|---|
| NET.01 | Auth | partial | ported to `auth.muzea.su` OTP + refresh (single-flight); device/TestFlight smoke pending |
| NET.02 | Sync | missing | `/after` 3 s, `/updated` 15 s, `/before` |
| NET.03 | Push (FCM/APNs) | partial | token registration only; no routing/local notification |
| NET.04 | Offline + retry | missing | outbox, network banner |
| NET.05 | Invites | n/a | not in code |
| NET.06 | Deep links | missing | push/share → chat/news |
| NET.07 | No-flicker sync | partial | keep cached list while refreshing |
| — | Share extension | missing | iOS target |

## SEC — security/compliance

| ID | Feature | iOS | Notes |
|---|---|---|---|
| SEC.01 | Transport | done | ATS, HTTPS only |
| SEC.02 | Tokens on device | partial | access+refresh in Keychain, no password; legacy purge implemented |
| SEC.03 | Message cache | partial | in-memory; no encryption |
| SEC.04 | Anti-abuse (report/block) | missing | UGC requirement |
| SEC.05 | Admin panel | n/a | web product |
| SEC.06 | Account deletion | done | deactivation in all three services: data kept, login closed, names hidden, private chats read-only, support restore via `X-Support-Token` |

## QA / DIST / OBS

| ID | Feature | iOS | Notes |
|---|---|---|---|
| QA.01 | Unit tests | partial | ~230 vs 1151 on Android; auth/refresh contract tests added |
| QA.02 | Robolectric | n/a | |
| QA.03 | Integration (mock network) | partial | `MockURLProtocol`; add shared fixtures |
| QA.04 | Device tests | missing | XCUITest for 4 critical paths |
| QA.05 | Coverage gate | missing | per-layer targets in CI |
| QA.06 | Mutation testing | n/a | |
| DIST.01 | Signing | missing | TestFlight: cert/profile/App Store Connect key |
| DIST.02 | Self-update | n/a | App Store/TestFlight |
| DIST.03 | Store publishing | planned | TestFlight first |
| DIST.04 | Betas | planned | TestFlight |
| DIST.05 | Changelog | missing | generate from commits |
| DIST.06 | Staged rollout | planned | TestFlight groups |
| OBS.01 | Crash reporting | missing | Firebase Crashlytics or telemetry upload |
| OBS.02 | Product analytics | n/a | not planned |
| OBS.03 | Server metrics | n/a | |

## Platform differences (documented, not bugs)

- **Push**: iOS needs a paid Apple Developer account for production APNs; TestFlight
  distribution is the target (no Sideloadly/site link).
- **Background**: no guaranteed background polling; sync runs in foreground and on
  push. Upload outbox uses background `URLSession` where possible.
- **Self-update**: APK-style update is impossible; link to TestFlight/App Store.
- **Downloads**: Files/Share Sheet instead of MediaStore.
- **Deep links**: Universal Links require an AASA file on the server + entitlements;
  otherwise a custom scheme.
- **Certificate pinning**: Android pins the CA; decide separately for iOS.
- **GIF**: Klipy search must go directly from the device (provider requirement);
  the server stores metadata only.

## Backend fixes worth doing (for the iOS port)

**P0 — blocks parity**

1. **Upload limit**: `chat/deploy/nginx.conf` had `client_max_body_size 8m` while
   the app accepts 220 MB. Raised locally to `220m`; **not deployed**. The outer
   host nginx (outside these repos) must also allow ≥220 MB.
2. **SEC.06 semantics**: done and deployed in all three services (chat
   `5c1a83c`, auth `30b789a`, makeup `27092bd`). Deletion is deactivation: rows,
   messages, news, videos, likes and files stay; login is blocked; names are
   hidden («Удалённый пользователь», `peerDeleted`/`senderDeleted`); private chats
   become read-only; support restores accounts with `X-Support-Token`.

**P1 — makes the port cheaper/safer**

3. OpenAPI snapshot for contract tests: auth exposes `/api-docs` only in dev,
   makeup has none, chat has springdoc. Commit a generated spec or expose staging.
4. Push: FCM is data-only today. Verify `content-available`/APNs behavior if
   background sync is expected; confirm the iOS Firebase app/APNs key.
5. Chat protocol gaps: reactions are not in `/updated`; GIF sends ignore
   `clientMessageId` (not idempotent); `durationSeconds` is always null;
   presigned MinIO URLs may be unreachable from devices (use proxied endpoints).

## Definition of done per feature

1. Contract test(s) for every endpoint used (success + error + 401/refresh).
2. Unit tests for pure logic and ViewModel behavior.
3. Device smoke check (real iPhone via TestFlight build).
4. Status updated in this file + `docs/WORKLOG.md` (create if missing).
5. CI green (build + all tests + release artifact).
