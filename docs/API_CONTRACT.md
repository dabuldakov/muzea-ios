# Muzea backend contract (for the iOS client)

Source of truth: backend repos
`/home/dmitry/IdeaProjects/my/{makeup,chat,muzea-auth-service}` (audited 2026-11-16),
cross-checked with the Android client. This document is normative for the iOS
implementation; if it disagrees with old iOS code, this document wins.

> Anything marked **⚠** is a backend quirk the iOS client must handle explicitly.

## Services

| Service | Base URL | Purpose |
|---|---|---|
| IdP | `https://auth.muzea.su` | registration, email OTP, tokens, sessions, account delete |
| Content | `https://api-muzea.su` | news, video, profile (makeup), reports |
| Chat | `https://chat-muzea.su` | chats, messages, attachments, contacts, presence, GIF, push token |

Single identity: the **access JWT** issued by the IdP is accepted by both content
and chat (JWKS at `https://auth.muzea.su/.well-known/jwks.json`). There is no
separate chat login/password anymore.

Timestamps: `LocalDateTime` serialized as `yyyy-MM-dd'T'HH:mm:ss'Z'` (UTC, second
precision). Inputs are truncated to 19 chars — always send UTC with `Z`.
Makeup `VideoResponse.uploadedAt` is the exception: **no `Z`**, variable precision.

---

## 1. auth-service (IdP)

No context path. JSON camelCase. Access JWT **RS256, 15 min**. Refresh token is an
opaque 43-char base64url string, **30 days, rotating**.

### Endpoints

| Method | Path | Auth | Body / result |
|---|---|---|---|
| POST | `/auth/register` | – | `{email,username,displayName?}` → 200 `{"message":"Verification code sent"}` |
| POST | `/auth/verify-email` | – | `{email,code,deviceId?}` → 200 `TokenResponse` |
| POST | `/auth/resend-verification` | – | `{email}` → 200 `{"message":...}` |
| POST | `/auth/otp/request` | – | `{email}` → 200 `{"message":...}` |
| POST | `/auth/otp/verify` | – | `{email,code,deviceId?,deviceName?}` → 200 `TokenResponse` |
| POST | `/auth/token/refresh` | – | `{refreshToken,deviceId?}` → 200 `TokenResponse` |
| POST | `/auth/logout` | – | `{refreshToken}` → 200 |
| POST | `/auth/logout-all` | Bearer | 200 |
| GET | `/auth/me` | Bearer | 200 `{id,email,username,displayName,emailVerified}` |
| DELETE | `/auth/me` | Bearer | 200 **hard delete** |
| GET | `/auth/sessions` | Bearer | 200 `SessionResponse[]` |
| DELETE | `/auth/sessions/{id}` | Bearer | 200 |
| GET | `/.well-known/jwks.json` | – | JWKS |
| GET | `/.well-known/openid-configuration` | – | discovery (no authorization/userinfo endpoints) |

`TokenResponse`:
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "43-char-opaque",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": { "id": "uuid", "email": "a@b.c", "username": "alice",
            "displayName": "Alice", "emailVerified": true }
}
```

Access-token claims: `iss=https://auth.muzea.su`, `sub=<user UUID>`,
`aud=["api-muzea","chat-muzea"]`, `exp`, `iat`, `jti`, `email`, `username`,
`type="access"`. No roles.

### Rules & errors

- OTP: 6 digits (string, leading zeros possible), TTL 600 s, 5 attempts; verify
  order: not found (400 `otp_not_found`) → expired (400 `otp_expired`) → attempts
  (429 `otp_attempts_exceeded`) → mismatch (400 `otp_invalid`).
- Rate limits (per process, in-memory): 60 s cooldown per email+purpose
  (429 `otp_cooldown`), 5 requests/hour per email+purpose (429 `otp_hourly_limit`),
  1 s per IP (429 `ip_cooldown`), 60/h per IP (429 `ip_rate_limit`). The IP
  cooldown is shared across register/verify/resend/otp-request/otp-verify.
- Error envelope: `{"code":"...","message":"..."}`. Security-layer 401 has an
  **empty body** — branch on the status, not the body.
- Common: 409 `email_taken` / `username_taken`; 400 `user_not_found`,
  `validation_error`; 500 `internal_error` (also for malformed JSON / wrong method).
- ⚠ **Refresh is one-time and destructive on reuse.** Two concurrent refreshes (or
  a retry after a lost response) revoke the whole token family and log the user
  out. iOS must do **single-flight refresh**, persist the new refresh token before
  any other request, and treat refresh 401 as “session dead → login”.
- Logout revokes only the refresh token; the access JWT stays valid up to 15 min.
- `deviceId` is free-form (≤128), stored per refresh session, not in the JWT.
  `deviceName` is accepted but ignored.
- OpenAPI is exposed at `/api-docs` in dev only; **disabled in prod**.
- `DELETE /auth/me` currently **hard-deletes** the auth user row and revokes its
  refresh sessions. The target behavior (SEC.06) is soft-delete: keep the row,
  mark it deleted, block login, allow support to restore. This is still an open
  backend item for auth-service.
- ⚠ Account deletion spans three services. **chat is already deactivated**
  (commit `5c1a83c`, deployed): the user is marked `is_deleted`, messages/private
  chats/attachments/contacts/blocks/avatar are kept, groups lose the member,
  private chats become read-only, names are hidden via `peerDeleted` /
  `senderDeleted`. auth-service still hard-deletes and makeup still hard-deletes
  profile/news/videos — those are the remaining SEC.06 work. On iOS call chat →
  makeup → auth last and only clear local data after all three confirm.

---

## 2. chat-service

Base `/api/...`. Bearer access JWT validated against JWKS (`sub` must be UUID,
`aud` must contain `chat-muzea`, `type=access`). No roles/permissions — membership
checks are explicit in services.

Errors: `{"error":"..."}` for 400/403/404/409/429/500; **security 401 is empty**.
⚠ Missing required params / malformed UUID / bad timestamp often become **500**,
not 400 — send required params and well-formed values.

### Chats

| Method | Path | Notes |
|---|---|---|
| GET | `/api/chats` | list, `updatedAt DESC` |
| GET | `/api/chats/{chatUuid}` | details; 403 non-member |
| POST | `/api/chats/private` | `{otherUserUuid}`; idempotent |
| POST | `/api/chats/group` | `{title, memberUuids[]}` |
| PUT | `/api/chats/{chatUuid}` | group+creator only |
| POST | `/api/chats/{chatUuid}/avatar` | multipart `file`; returns plain-text URL |
| DELETE | `/api/chats/{chatUuid}` | creator only |
| POST | `/api/chats/archive/{chatUuid}` · `/unarchive/...` | creator only |
| GET | `/api/chats/{chatUuid}/receipts` | watermarks per participant |
| GET | `/api/chats/unread-count/all` | `{count}` |
| GET | `/api/chats/unread-count/{chatUuid}` | `{count}` (semantics differ from list) |

Private chats rewrite `title`/`avatarUrl` to the other participant. `participantIds`
are user UUIDs. `archived` key is `archived` (not `isArchived`).

### Messages

| Method | Path | Notes |
|---|---|---|
| POST | `/api/messages/{chatUuid}` | send; see DTO below |
| GET | `/api/messages/{chatUuid}?page=0&size=50` | `Page<MessageDto>`, newest first |
| GET | `/api/messages/{chatUuid}/before/{messageUuid}?limit=50` | older page (cursor) |
| GET | `/api/messages/{chatUuid}/after/{timestamp}` | new messages, ASC, hard limit 500 |
| GET | `/api/messages/{chatUuid}/updated/{timestamp}` | edits/pins/deletes window, ASC, limit 500 |
| GET | `/api/messages/by-uuid/{messageUuid}` | single |
| PUT | `/api/messages/{messageUuid}` | `{text}` (edit) |
| DELETE | `/api/messages/{messageUuid}?hardDelete=false` | soft delete by default |
| POST | `/api/messages/{messageUuid}/reactions` | `{emoji}` — **toggles**; returns aggregated list |
| POST | `/api/messages/forward` | `{messageUuid, targetChatUuid}` |
| POST | `/api/messages/{chatUuid}/read?upToMessageUuid=` | advances read+delivered |
| POST | `/api/messages/{chatUuid}/delivered?upToMessageUuid=` | delivered only |
| GET | `/api/messages/{chatUuid}/status/{messageUuid}` | per-user status list |
| GET/DELETE | `/api/messages/{chatUuid}/pin/{messageUuid}` | **GET is mutating** |
| GET | `/api/messages/{chatUuid}/pinned` | pinned list |
| GET | `/api/messages/search?query=` | global search |
| GET | `/api/messages/{chatUuid}/search?query=` | chat search |

`MessageDto` (important fields):
```json
{
  "messageUuid": "...", "messageId": 1042, "chatUuid": null,
  "senderId": 7, "senderUuid": "...", "senderName": "Alice", "senderAvatar": "/api/avatars/...",
  "text": "hello", "messageType": "TEXT",
  "replyToMessageUuid": null,
  "forwardedFromMessageUuid": null, "forwardedFromUserUuid": null,
  "isEdited": false, "isDeleted": false, "isPinned": false,
  "createdAt": "...Z", "updatedAt": "...Z",
  "attachments": null, "status": null,
  "reactions": [], "power": 0, "damage": 0
}
```
- `messageId` is a global monotonic BIGSERIAL; use it for receipt watermarks and
  as a tiebreaker, `createdAt` for UI order.
- `chatUuid`, `forwardedFrom*`, `status` are always `null` (DTO gaps).
- `attachments` = null or array; `reactions` = [] (never null).
- `messageType` ∈ `TEXT, IMAGE, VIDEO, GIF, AUDIO, FILE, VOICE, VIDEO_NOTE,
  LOCATION, CONTACT, SYSTEM, DELETE`.
- Send body supports `text`, `messageType`, `replyToMessageUuid`,
  `clientMessageId` (idempotency), `attachments` (UUIDs), `power`, `gif`.
- ⚠ **Idempotency**: `clientMessageId` dedupes text/attachment sends; **GIF sends
  bypass it** — retrying a GIF creates a duplicate. Reconcile echoes by
  `messageUuid`/`messageId`; correlate optimistic bubbles by `clientMessageId`
  (the server does not echo it).

### Sync semantics (critical)

- `/after/{ts}` and `/updated/{ts}` are **strict `>`** on second-granular
  timestamps, ASC, hard limit **500**, no `limit` param.
- Two messages in the same second (or a repeated fetch) must be deduped by
  `messageUuid`/`messageId` on the client.
- Advance the watermark using the **max `createdAt` actually returned**, with
  `messageId` as tiebreaker — not the local clock.
- Soft deletes are not tombstoned: a deleted message simply disappears from
  `/after` and `/updated`. The client must refresh or merge conservatively.
- `/updated` carries edits, pins, and `damage` changes, but **not reactions**.
  Reactions only arrive on a full message refetch. Plan a periodic/full refresh or
  refresh reactions when the chat becomes visible.
- Poll cadence (Android parity): `/after` every 3 s while the chat is visible;
  `/updated` every 15 s; full page only on first open/return.

### Receipts

`GET /api/chats/{chatUuid}/receipts` → one row per participant:
`userUuid, username, fullName, avatarUrl, joinedAt, lastDeliveredMessageId,
lastDeliveredAt, lastReadMessageId, lastReadAt`. Compare with `messageId`:
`<= lastRead` → read; else `<= lastDelivered` → delivered; else sent.
`GET .../status/{messageUuid}` returns `{userId, status, deliveredAt, readAt}` where
`userId` is the **numeric** id (map via participants/receipts). Sender is always
“read” for own messages; times are watermark times, not per-message times.

### Attachments

Upload (orphan first, bind later):
`POST /api/attachments/upload?chatUuid=...&width=&height=&duration=` with multipart
`file` (+ optional `thumbnail` for images) → `AttachmentDto` with `fileUrl` =
**MinIO key**, not a URL. Then send a message with `attachments:["<uuid>"]`
(max 10, same chat, same uploader, not already bound).

Allowed types/limits (extension + magic bytes): images jpg/png/webp 50 MB; video
mp4/mov 200 MB; audio mp3/m4a/aac/ogg/opus/wav 50 MB; docs pdf/txt/csv/doc(x)/
xls(x)/ppt(x)/apk 100 MB; thumbnail 5 MB. ⚠ bundled nginx used to cap the request
at **8 MB**; the local `chat/deploy/nginx.conf` is raised to `220m` (not deployed
yet), and the outer host nginx must allow the same.

Download: `GET /api/attachments/{uuid}` streams bytes through the app (no redirect),
supports `Range` (206/416), requires chat membership. Use it for AVPlayer. Preview:
`GET .../preview` (image original, otherwise thumbnail) — ⚠ a video thumbnail may be
labelled `video/mp4`; sniff bytes.

### GIF / Klipy

The server never calls Klipy and has no key. The **client** searches Klipy directly
and sends the chosen GIF metadata in the message body (`messageType="GIF"`,
`gif:{provider,providerGifId,title,url,previewUrl,mp4Url,width,height,rating}`).
`GET /api/gifs/recent` and `/api/gifs/chat/{chatUuid}` return stored metadata
(`gifUuid, provider, providerGifId, title, url, previewUrl, mp4Url, width, height,
rating`). Render `mp4Url` with `previewUrl` as placeholder. GIF sends are not
idempotent (see above).

### Presence

`POST /api/presence/heartbeat` → **204**, every ~15 s while foreground; online TTL
45 s; no explicit offline endpoint. `GET /api/presence?userUuids=...` (repeatable or
comma-separated, ≤200) → `[{userUuid,online,lastSeenAt}]`. Visibility is limited to
users sharing a chat (others appear offline/null).

### Contacts, blocked, reports, telemetry

- Contacts: `GET /api/contacts`, `/page`, `/search?query`, `/api/contacts/{uuid}`,
  `POST /api/contacts {contactUserUuid,contactName?}`, `DELETE .../{uuid}`,
  `PATCH .../{uuid}/name?name=`.
- Blocked: `GET /api/blocked`, `/page`, `/search`, `/api/blocked/{uuid}`,
  `POST /api/blocked {blockUserUuid,reason?}`, `DELETE /api/blocked/{uuid}`,
  `DELETE /api/blocked` (all), `GET /api/blocked/check/{userUuid}` →
  `{blocked,blockedBy,mutual}`. Blocking removes the contact and blocks private
  sends (`403 "Cannot send message to this user"`).
- Reports: `POST /api/reports` →
  `{contentType:"MESSAGE|USER|CHAT", contentUuid, reason:"SPAM|ABUSE|VIOLENCE|ADULT|ILLEGAL|OTHER", comment?}`
  → **201** `{reportUuid,contentType,status:"NEW",createdAt}`.
- Telemetry: `POST /api/telemetry/errors`
  `{overflowed, events:[{eventId,time,level,tag,message,stack,appVersion,versionCode,buildType,device,os}]}`
  (≤100 events) → `{accepted:n}`.

### Account deactivation (SEC.06, chat — deployed)

`DELETE /api/users/me` on chat **deactivates** the account (commit `5c1a83c`):

- `users.is_deleted=true`, `deleted_at` set; the row is hidden by
  `@SQLRestriction`, and the JWT filter rejects its tokens
  (`AccountDeletedException` → 401). Login is impossible until support restores.
- Messages, private chats, attachments, contacts, blocked users and the avatar
  **remain**; the user is removed from groups (ownership transferred) but their
  group messages stay; FCM device tokens are deleted.
- Private chats with the deactivated user remain, but sending returns
  `400 {"error":"Получатель удалён"}`.
- Chat list: `peerDeleted=true`, `title=null`, `avatarUrl=null` for that private
  chat; `MessageDto.senderDeleted=true` when the sender is hidden. Clients must
  render «Удалённый пользователь» and disable the composer.
- Support restore: `SupportAccountController` under `/api/support/**` (service
  token required).

### Push

FCM only (APNs is reached through FCM). Register the **FCM** token:
`PUT /api/users/me/fcm-token {token, deviceId}`. ⚠ There is **no `deviceType`
field** and `"IOS"` is not a value anymore — do not send it. The message push is
**data-only** (no `notification` block); iOS must build the local notification.
Payload data: `title, body, type:"MESSAGE", senderId, senderName, messageText,
chatUuid, messageUuid, chatTitle, senderUuid, senderAvatar, chatAvatar`.

---

## 3. makeup-service (content)

Base `https://api-muzea.su`. Bearer access JWT (`aud` must contain `api-muzea`).
⚠ Unauthenticated requests are **403**, not 401. Handled errors:
`{timestamp,message,status}`; security denials are empty 403. Catch-all turns many
bad requests into **500**.

### News

| Method | Path | Notes |
|---|---|---|
| GET | `/api/news?page&size` | public; Spring `Page` (`content`, `totalElements`, …) |
| GET | `/api/news/{id}` | public |
| POST | `/api/news` | multipart `title`, `content`, `videoId?`, `image?` → **200** full news |
| DELETE | `/api/news/{id}` | author only → 204 (soft delete) |
| GET | `/api/news/image/{fileName}` | image bytes |

`imageUrl` is absolute (`app.public-base-url`), `relatedVideo.url` is relative.

### Video

| Method | Path | Notes |
|---|---|---|
| GET | `/api/videos` | public; **plain array** (no totals) |
| GET | `/api/videos/{id}` | public-ish; ⚠ anonymous call currently 500 → always send a token |
| POST | `/api/videos/upload` | multipart `file`, `title`, `description?`, `thumbnail?` → 200 |
| POST/DELETE | `/api/videos/{id}/like` | **both are toggles**; response `{liked,likes}` |
| GET | `/api/videos/stream/{fileName}` | Range 200/206/416; use for AVPlayer |
| GET | `/api/videos/thumbnail/{fileName}` | JPEG |
| GET | `/api/videos/url/{fileName}` · `/thumbnail/url/{fileName}` | presigned, short-lived; ⚠ may be unreachable — prefer proxied endpoints |
| DELETE | `/api/videos/{id}` | uploader only → 204 |

`VideoResponse`: `id,title,description,url,thumbnailUrl,fileSize,durationSeconds,
views,likes,likedByMe,uploadedBy,uploadedAt`. ⚠ `durationSeconds` is always null;
`uploadedAt` has **no `Z`**. `GET /{id}` increments views.

### Profile, reports, account

- `GET /api/users/me` → `{id,userName,fullName,avatarUrl,role,createdAt,enabled}`.
  ⚠ key is `userName` (capital N); email is not part of the makeup model — take it
  from auth-service `/auth/me`.
- `PUT /api/users/{id}` → `{fullName?,avatarUrl?}`; self only.
- `DELETE /api/users/{id}` → 204; **hard delete** (also deletes news/videos/likes).
  ⚠ Same “deactivation vs hard delete” discrepancy as auth-service; see the note
  in §1 — the backend currently hard-deletes.
- `POST /api/reports` →
  `{contentType:"NEWS|VIDEO", contentId, reason:"SPAM|ABUSE|VIOLENCE|ADULT|ILLEGAL|OTHER", comment?}`
  → **201** `{reportUuid,contentType,status,createdAt}`. Repeated report returns the
  same report.

---

## 4. Cross-cutting client rules

1. **Two error envelopes**: `{"code","message"}` (auth), `{"error"}` (chat),
   `{timestamp,message,status}` (makeup). Branch on HTTP status first.
2. **401 vs 403**: auth and chat return 401 for missing/expired tokens (empty body);
   makeup returns 403. Treat 401 (auth/chat) and 403-on-protected (makeup) as
   “refresh once, then logout”.
3. **Single-flight refresh**: only one refresh request at a time; persist the new
   refresh token before resuming queued requests. Never retry a refresh blindly.
4. **Timestamps**: UTC second precision in chat/auth; makeup video `uploadedAt`
   has no zone. Use two parsers.
5. **Pagination**: chat messages/contacts/blocked = Spring `Page`; makeup news =
   `Page`; makeup videos = bare array. Don’t assume one shape.
6. **500 quirks**: malformed JSON / missing params / bad UUID / bad timestamp may
   return 500. Validate client-side.
7. **No deviceType**: push registration is `{token, deviceId}` only.
8. **Media URLs**: chat `fileUrl` is a MinIO key → download via
   `/api/attachments/{uuid}`; makeup videos → `/api/videos/stream/{key}`. Do not
   build MinIO URLs on the client.
9. **Reactions are not in `/updated`** — refresh them explicitly.
10. **GIF sends are not idempotent** — never auto-retry a GIF send.
