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
| UI.01 | Theme components | partial | `Theme` tokens: spacing, radius, palette, outgoing gradient |
| UI.02 | Fonts | partial | system fonts; custom sizes not unified |
| UI.03 | Chat screen, bubbles | partial | text + replies, reactions, pins, link previews; attachments/media missing |
| UI.04 | Animations | partial | заряд, появление/удаление сообщений, панели выбора и закрепов; переходы экранов pending |
| UI.05 | Haptics | partial | `Haptics`: заряд, запись/отмена, реакции, отправка, сохранение фото |
| UI.06 | Dark theme | partial | follows system; explicit palette needed |
| UI.07 | Accessibility | partial | labels/hints в чате, галерее и композере; dynamic type/contrast pending |
| UI.08 | Adaptivity | partial | iPhone portrait only |
| UI.09 | Localization | partial | весь UI и согласие через `L10n`, RU/EN + переключатель языка в профиле, guard-скрипт в CI; плюрализации нет |
| UI.10 | 6-line composer | partial | UIViewRepresentable editor, 1...6 lines, cursor-aware; device check pending |
| UI.11 | Hide tab bar in chat | partial | `.toolbar(.hidden, for: .tabBar)`; device check pending |
| UI.12 | Emoji + GIF button | partial | emoji grid + GIF search sheet; device check pending |
| UI.13 | Composer layout | partial | paperclip + emoji/GIF + attachment chips; device check pending |
| UI.14 | Settings screen | missing | planned и в Android |
| UI.15 | Tab order | missing | planned и в Android |
| UI.16 | Insets/keyboard | partial | verify on device |

## MSG — messenger

| ID | Feature | iOS | Notes |
|---|---|---|---|
| MSG.01 | Text engine | done | optimistic send + reducer |
| MSG.02 | Send-button charge | partial | hold-to-charge 0..100, `power` in send body, haptics; tests in `ChatTextParityTests`; device check pending |
| MSG.03 | Cancel mechanics | partial | swipe up/left cancels, red indicator; tests in `ChatTextParityTests`; device check pending |
| MSG.04 | Local cache + outbox | partial | disk `chat-outbox.json`, same `clientMessageId` on retry, auto-retry every 15 s; no network monitor |
| MSG.05 | Replies / edits / forward | partial | reply/edit/forward + comment, действия из галереи фото; multi-select/device smoke pending |
| MSG.06 | @mentions | partial | cursor-aware suggestions in any text position; tests in `ChatTextParityTests` |
| MSG.07 | Multi-select | partial | select, forward, delete; tests in `ChatTextParityTests` |
| MSG.08 | Pinned messages | partial | top bar, pin/unpin, jump; tests in `ChatTextParityTests` |
| MSG.09 | Read receipts | partial | exact `/status/{messageUuid}` times + read-on-scroll; tests in `ChatTextParityTests` |
| MSG.10 | Message search | missing | planned и в Android (эндпоинты есть) |
| MSG.11 | Drafts | partial | `UserDefaultsChatDraftStore`; tests in `ChatTextParityTests` |
| MSG.12 | Scroll anchor | partial | verify on device |
| MSG.13 | Group rename | missing | planned и в Android (API есть) |
| MSG.14 | Remove participant | missing | planned и в Android (API есть) |
| MSG.15 | Remove contact | missing | planned и в Android (API есть) |
| MSG.16 | Reactions | partial | 24 emoji, recent history, picker sheet, authors in details; full refresh every 15 s; tests in `ChatTextParityTests` |
| MSG.17 | Unread in chat list | partial | reload on return from conversation; tests/device check pending |
| — | Link previews (Open Graph) | partial | first URL, og/twitter/title parse, 24h cache, SSRF guard; tests in `ChatTextParityTests` |

## MEDIA — chat attachments

| ID | Feature | iOS | Notes |
|---|---|---|---|
| MEDIA.01 | Photos | partial | multi-select до 10, JPEG 2048px, upload, grid, gallery; device smoke pending |
| MEDIA.02 | Video | partial | upload с миниатюрой/размерами/длительностью, AVPlayer, cache; device smoke pending |
| MEDIA.03 | Voice messages | partial | запись, waveform из реальных пиков, прогресс, длительность файлов, кэш; device smoke pending |
| MEDIA.04 | Video notes (circles) | partial | AVCaptureSession, 60s, round preview/recorder, VIDEO_NOTE, thumbnail; device check pending |
| MEDIA.05 | GIF (Klipy) | partial | поиск + «Мои»/«Этот чат» с сервера, диск cache, looping MP4; device smoke pending |
| MEDIA.06 | Documents | partial | классификация по расширению (фото/видео/аудио/файл), QuickLook, share; device check pending |
| MEDIA.07 | Save to Files/Photos | partial | Save to Photos for photo/video, Files через share; device check pending |
| MEDIA.08 | Upload queue | partial | disk queue files+thumbs, restore/retry, прогресс и ошибка по каждому файлу, retry тапом |
| MEDIA.09 | Open/share after download | partial | QuickLook, video player, share sheet; device check pending |
| MEDIA.10 | GIF cache | partial | first page on disk, TTL 30 min, stale fallback |
| MEDIA.12 | Image viewer | partial | swipe gallery, author/date, reply/forward/share/save; device check pending |
| MEDIA.13 | Server thumbnails | n/a | backend plan; client just uses URLs |
| MEDIA.14 | CDN/presigned | n/a | backend plan |

## FEED / video / profile

| ID | Feature | iOS | Notes |
|---|---|---|---|
| FEED.01 | News creation | done | image + related video |
| FEED.02 | Feed filter (contacts + self) | done | |
| FEED.03 | Post TTL | n/a | not implemented |
| FEED.04 | Author subscriptions | missing | planned и в Android |
| FEED.05 | Feed periods | missing | planned и в Android |
| FEED.06 | Rename to “Blams” | n/a | product decision |
| — | Video feed/upload/delete/playback | partial | upload/delete/playback/report; block UI и device smoke pending |
| — | News report (UGC) | done | `/api/reports`, кнопка в деталях новости |
| — | Profile edit/avatar | done | |
| — | Account delete/deactivation | done | deactivation in chat + auth + makeup (SEC.06) |
| — | Cache clear | done | размер и очистка кэша в профиле |
| — | App update check | n/a | no self-update on iOS; link to TestFlight/App Store |

## NET — network, sync, notifications

| ID | Feature | iOS | Notes |
|---|---|---|---|
| NET.01 | Auth | partial | passwordless OTP + refresh; `SENT/NOT_FOUND/UNVERIFIED/DELETED` показываются в UI; device smoke pending |
| NET.02 | Sync | partial | `/after` 3 s, full 15 s, `/before` догрузка истории вверх; background sync pending |
| NET.03 | Push (FCM/APNs) | partial | data-only FCM, локальные уведомления, чат/новость, подавление открытого чата; APNs background задеплоен; device smoke pending |
| NET.04 | Offline + retry | partial | disk outbox, вложения, офлайн-баннер, retry при возврате сети; background sync pending |
| NET.05 | Invites | n/a | not in code |
| NET.06 | Deep links | partial | muzea:// и https://muzea.su/...; AASA выложен, Apple CDN видит JSON; device smoke pending |
| NET.07 | No-flicker sync | partial | keep cached list while refreshing |
| — | Share extension | partial | MuzeaShare text/URL → выбор чата; device smoke pending |

## SEC — security/compliance

| ID | Feature | iOS | Notes |
|---|---|---|---|
| SEC.01 | Transport | done | ATS, HTTPS only + SPKI-пиннинг CA как в Android |
| SEC.02 | Tokens on device | partial | access+refresh in Keychain, no password; legacy purge implemented |
| SEC.03 | Message cache | partial | память + file protection для очередей; шифрования БД нет |
| SEC.04 | Anti-abuse (report/block) | partial | report чата/новости/видео + block в чате; block UI для контента pending |
| — | Privacy manifest | done | `PrivacyInfo.xcprivacy`, required-reason API, RU/EN InfoPlist.strings |
| — | SSRF/OG hardening | done | private/mapped IPv6, DNS-проверка, потоковый лимит, безопасный og:image |
| SEC.05 | Admin panel | n/a | web product |
| SEC.06 | Account deletion | done | deactivation in all three services: data kept, login closed, names hidden, private chats read-only, support restore via `X-Support-Token` |

## QA / DIST / OBS

| ID | Feature | iOS | Notes |
|---|---|---|---|
| QA.01 | Unit tests | partial | 460 тестов в 37 файлах; логика 86.1% (Android 82.4%), общее 69.9% с рендером вью; device tests pending |
| QA.02 | Robolectric | n/a | |
| QA.03 | Integration (mock network) | partial | `MockURLProtocol`: репозитории, загрузки, история, GIF, OG-превью; очередь вложений |
| QA.04 | Device tests | missing | XCUITest на 4 пути; в Android `androidTest` тоже planned |
| QA.05 | Coverage gate | done | гейт логики 83% и общего 60% в `ios.yml`; отчёт `scripts/coverage_report.py` |
| QA.06 | Mutation testing | n/a | |
| DIST.01 | Signing | done | distribution cert, App Store profiles, signed TestFlight build 1.1 (2) |
| DIST.02 | Self-update | n/a | App Store/TestFlight |
| DIST.03 | Store publishing | partial | TestFlight build загружен; App Store review не запускался |
| DIST.04 | Betas | partial | внутренняя группа TestFlight получает сборки |
| DIST.05 | Changelog | missing | generate from commits |
| — | SDK deadline | watch | ITMS-90725: с апреля 2027 нужен Xcode 27/iOS 27 SDK; CI на `latest-stable` |
| DIST.06 | Staged rollout | planned | TestFlight groups |
| OBS.01 | Crash reporting | partial | как Android: диск-буфер, `logCaught`, NSException + фатальные сигналы, отправка `/api/telemetry/errors` при старте/входе; стек сигналов не пишется |
| OBS.02 | Product analytics | n/a | not planned |
| OBS.03 | Server metrics | n/a | |

## Platform differences (documented, not bugs)

- **Push**: iOS needs a paid Apple Developer account for production APNs; TestFlight
  distribution is the target (no Sideloadly/site link).
- **Background**: no guaranteed background polling; sync runs in foreground and on
  push. Upload outbox uses background `URLSession` where possible.
- **Self-update**: APK-style update is impossible; link to TestFlight/App Store.
- **Downloads**: Files/Share Sheet instead of MediaStore.
- **Deep links**: Universal Links готовы на клиенте (entitlement + capability);
  до выкладки AASA работает `muzea://` (см. `DEEP_LINKS.md`).
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
5. Chat protocol gaps: реакции не приходят в `/updated`; отправка GIF без
   `clientMessageId` (не идемпотентна); presigned MinIO URL могут быть
   недоступны с устройств (используем прокси-эндпоинты).

## Definition of done per feature

1. Contract test(s) for every endpoint used (success + error + 401/refresh).
2. Unit tests for pure logic and ViewModel behavior.
3. Device smoke check (real iPhone via TestFlight build).
4. Status updated in this file + `docs/WORKLOG.md` (create if missing).
5. CI green (build + all tests + release artifact).
