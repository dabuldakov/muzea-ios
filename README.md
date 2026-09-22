# Muzea iOS

Нативный iOS-клиент Muzea (SwiftUI). Паритет с Android-приложением:
авторизация, новости, видео (включая удаление и превью), личные и групповые чаты,
настройки группы и аватары чатов, контакты, профиль, аватары и push-уведомления.
Время с сервера (UTC без зоны) приводится к локальному поясу устройства.

## Стек

- Swift 5.9, SwiftUI, iOS 16+
- `URLSession` + `async/await` (без сторонних сетевых библиотек)
- Firebase Cloud Messaging (SPM) для пушей
- XcodeGen — проект генерируется из `project.yml`

## Бэкенды

Приложение использует те же бэкенды, что и Android:

| Сервис | Адрес | Назначение |
|--------|-------|------------|
| makeup | `http://90.188.89.63:8085` | авторизация, новости, видео, профиль |
| chat | `http://90.188.89.63:8086` | контакты, чаты, сообщения, аватары, FCM |

Адреса задаются в `Muzea/Core/Config.swift`.

## Сборка локально (только macOS)

```bash
brew install xcodegen
xcodegen generate
open Muzea.xcodeproj
```

Либо из командной строки:

```bash
xcodebuild \
  -project Muzea.xcodeproj \
  -scheme Muzea \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Тесты

Юнит-тесты лежат в `MuzeaTests` (target `MuzeaTests`, `xcodebuild test` на симуляторе):

- `DateTimeFormatTests`, `ImageURLTests` — форматирование времени и медиа-URL;
- `FeedFilterTests` — фильтры новостей и видео (аналоги Android-тестов);
- `JWTTests` — извлечение `sub` из chat-токена;
- `TokenStoreTests` — ключи сессии, deviceId, logout;
- `ModelsDecodingTests` — разбор реальных ответов серверов;
- `HTTPClientTests`, `ChatAuthManagerTests`, `RepositoriesTests` — сетевой слой
  через mock `URLProtocol` (заголовки, multipart, 401/retry, ошибки).

Запуск всех тестов из командной строки:

```bash
xcodebuild test \
  -project Muzea.xcodeproj \
  -scheme Muzea \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## CI (GitHub Actions)

Workflow `.github/workflows/ios.yml` на каждый push/PR:

1. `macos-15`, Xcode 16 (latest stable)
2. `brew install xcodegen`
3. `xcodegen generate`
4. `xcodebuild` для симулятора без подписи (`CODE_SIGNING_ALLOWED=NO`)
5. job **Unit tests** — `xcodebuild test` на доступном iPhone-симуляторе

Подпись/TestFlight не настроены — для них нужен Apple Developer аккаунт и секреты.

## Установка на iPhone (бесплатный Apple ID + Windows)

CI собирает неподписанный device-`.ipa` (job **Unsigned device .ipa**):

1. Actions → последний run → блок **Artifacts** → скачай `Muzea-unsigned-ipa`.
2. На Windows установи [Sideloadly](https://sideloadly.io) и iTunes (для драйверов iPhone).
3. Подключи iPhone кабелем и доверься компьютеру.
4. В Sideloadly выбери `.ipa`, укажи свой Apple ID и нажми Start.
5. На iPhone: Настройки → Основные → VPN и управление устройством → доверься профилю разработчика.

Ограничения бесплатной подписи:

- подпись живёт **7 дней**, затем повторить установку;
- до 3 приложений на аккаунт;
- **push-уведомления не работают** (нет entitlement `aps-environment` у бесплатного профиля).

## Push-уведомления

Чтобы пуши заработали:

1. В Firebase Console проекта `muzea-chat` добавь iOS-приложение с bundle id
   `com.example.muzea` и скачай `GoogleService-Info.plist`.
2. Положи файл в `Muzea/Resources/GoogleService-Info.plist` (он в `.gitignore`,
   в репозиторий не коммитится).
3. Включи APNs-ключ в Firebase (Project settings → Cloud Messaging).

Без файла приложение собирается и работает, но FCM отключается (в лог пишется
предупреждение), push-токен не регистрируется.

### Файл в CI

`GoogleService-Info.plist` не коммитится. Чтобы сборка получала конфиг, добавь
GitHub-секрет `GOOGLE_SERVICE_INFO_PLIST` со значением файла в base64:

```bash
base64 -i Muzea/Resources/GoogleService-Info.plist | pbcopy   # macOS
base64 -w0 Muzea/Resources/GoogleService-Info.plist           # Linux
```

Workflow декодирует секрет в `Muzea/Resources/GoogleService-Info.plist` перед
генерацией проекта. Если секрет не задан, шаг пропускается, сборка проходит без FCM.

## Структура

```
Muzea/
├── App/            точка входа, DI-контейнер, таб-бар
├── Core/
│   ├── Models/     Codable-модели (совпадают с Android/Gson)
│   ├── Networking/ HTTPClient, API, ошибки
│   ├── Repositories/ auth/news/video/chat
│   ├── Push/       FCM
│   └── Util/       AvatarView, JWT, DateTimeFormat
├── Features/
│   ├── Auth/       вход и регистрация
│   ├── News/       лента, детали, создание, фильтр
│   ├── Video/      список, детали (удаление), загрузка с превью
│   ├── Chat/       список чатов, переписка, группы, настройки группы
│   ├── Contact/    контакты
│   └── Profile/    профиль и аватар
└── Resources/      Info.plist, Assets
```
