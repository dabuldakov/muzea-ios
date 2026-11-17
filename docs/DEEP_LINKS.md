# Deep links и Universal Links

## Схемы

| Ссылка | Куда ведёт | Разбор |
|---|---|---|
| `muzea://chat/{uuid}?title=&avatar=&message=` | чат | `DeepLink.parse` |
| `muzea://news/{id}` | новость | `DeepLink.parse` |
| `muzea://share?text=` | выбор чата для текста | `DeepLink.parse` |
| `https://muzea.su/chat/{uuid}...` | чат | `DeepLink.parse` (Universal Link) |
| `https://muzea.su/news/{id}` | новость | `DeepLink.parse` |
| `https://muzea.su/share?text=` | выбор чата | `DeepLink.parse` |

`muzea://` обрабатывает `.onOpenURL`, HTTPS-ссылки — `.onContinueUserActivity`,
оба ведут в `AppRouter.handleURL`. Push-уведомления приходят через тот же
роутер, поэтому маршрутизация одна.

## Что уже настроено в репозитории

- `Muzea/Resources/Muzea.entitlements` — `applinks:muzea.su`;
- `CODE_SIGN_ENTITLEMENTS` в обеих конфигурациях приложения;
- capability `ASSOCIATED_DOMAINS` включена у bundle ID `com.cyber.muzea`
  в App Store Connect (через API), App Store профиль перевыпущен;
- `docs/aasa/apple-app-site-association` — готовый файл AASA.

## Что нужно выложить на сервер

Файл должен открываться **без редиректов** по адресу:

```
https://muzea.su/.well-known/apple-app-site-association
```

Требования Apple:

- `Content-Type: application/json` (не `text/plain`), HTTPS, без редиректа;
- файл без расширения, доступен без авторизации;
- `appID` = `<TeamID>.<BundleID>` → `5HGZ927RW5.com.cyber.muzea`.

Содержимое — `docs/aasa/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "5HGZ927RW5.com.cyber.muzea",
        "components": [
          { "/": "/chat/*" },
          { "/": "/news/*" },
          { "/": "/share" }
        ]
      }
    ]
  }
}
```

Положить в веб-корень muzea.su в каталог `.well-known/` и добавить файл в
`FILES` в `muzea-legal/deploy.sh`, чтобы он не терялся при выкладке.

## Проверка

1. Apple CDN: `https://app-site-association.cdn-apple.com/a/v1/muzea.su` —
   должен вернуть тот же JSON (кэш обновляется до нескольких часов).
2. На устройстве: открыть `https://muzea.su/chat/<uuid>` в Safari — приложение
   должно открыться без браузера; повторное открытие из одного домена может
   показывать верхнюю плашку Safari (это нормальное поведение iOS).
3. `xcrun simctl openurl booted "https://muzea.su/news/42"`.
4. Проверить, что ссылка на чужой домен остаётся в браузере
   (`https://example.com/chat/1`).

## Откат

Если AASA недоступен, Universal Links не работают, но `muzea://` продолжает
работать. Entitlement без AASA не ломает сборку и не влияет на push/share.
