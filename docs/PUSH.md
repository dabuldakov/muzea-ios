# Push-уведомления iOS

## Как это устроено

1. Приложение запускает Firebase, регистрируется в APNs и получает FCM-токен.
2. `ChatAuthManager` отправляет токен на `PUT /api/users/me/fcm-token`.
3. Бэкенд хранит токены в `device_tokens` и при новом сообщении/новости шлёт
   FCM на все токены получателя, кроме отправителя.
4. Для iOS сервер отправляет **APNs alert + data**:
   - `aps.alert` — системное уведомление (видно даже если приложение убито);
   - data (`type`, `chatUuid`, `messageUuid`, `newsId`, ...) — маршрутизация
     при тапе;
   - `apns-push-type: alert`, `apns-priority: 10`, `apns-collapse-id`.
5. Android получает только data с `priority=HIGH` и строит уведомление сам.
6. iOS при наличии `aps.alert` не создаёт второе локальное уведомление, чтобы
   не было дублей. Старый data-only формат всё ещё поддерживается: тогда
   приложение строит локальное уведомление само.

## Обязательная конфигурация

- Firebase project: **muzea-chat**.
- iOS app в Firebase: bundle ID **com.cyber.muzea**, `GOOGLE_APP_ID`
  `1:852486675776:ios:8005ad41ff5bdfafefeea5`.
- `GoogleService-Info.plist` должен быть скачан именно для этого iOS-приложения.
  Старый plist с `BUNDLE_ID=com.example.muzea` даёт неверный FCM-токен и
  уведомления не приходят.
- В Firebase Console → Project settings → Cloud Messaging должен быть загружен
  APNs Authentication Key (Team ID `5HGZ927RW5`), иначе FCM вернёт
  `THIRD_PARTY_AUTH_ERROR`.
- Bundle ID должен иметь capability **Push Notifications**; App Store профиль
  содержит `aps-environment=production` (проверяется по IPA).
- Info.plist: `UIBackgroundModes = remote-notification`.

## Клиент

- `PushManager.configure()` регистрирует APNs **независимо** от разрешения на
  показ баннеров: без APNs-токена не будет FCM-токена.
- После `didRegisterForRemoteNotifications` вызывается
  `PushManager.refreshFcmToken()` — не полагаемся только на delegate-колбэк.
- Токен отправляется на сервер при `ensureAuthenticated` (старт, вход,
  возврат в приложение).
- Если чат открыт, баннер подавляется.

## Диагностика

На сервере:

```bash
docker logs chat-backend-app-1 | grep -E "FCM|NotRegistered|THIRD_PARTY"
```

В БД:

```sql
select user_id, left(fcm_token, 8), updated_at
from device_tokens order by updated_at desc limit 20;
```

Признаки:

- **нет свежего токена** — приложение не получило/не отправило FCM-токен
  (неверный plist, APNs-регистрация, нет входа);
- `UNREGISTERED` — токен старый/от другого Firebase-приложения;
- `THIRD_PARTY_AUTH_ERROR` — в Firebase не загружен APNs key;
- токен есть, ошибок нет, но тишина — смотреть APNs alert/разрешения и
  `apns-push-type`.

## Проверка на устройстве

1. Установить свежую TestFlight-сборку.
2. Разрешить уведомления (но APNs-регистрация работает и без этого).
3. Войти в аккаунт и подождать несколько секунд.
4. В БД должен появиться новый `device_tokens` с `updated_at` сегодня.
5. Отправить сообщение с другого аккаунта при закрытом приложении —
   должен прийти системный баннер; тап открывает нужный чат.
6. Проверить новость и подавление уведомления при открытом чате.
