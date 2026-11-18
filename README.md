# Muzea iOS

Нативный iOS-клиент Muzea (SwiftUI). Паритет с Android-приложением:
авторизация, экран согласия на обработку персональных данных (ст. 9 ФЗ-152),
новости, видео (включая удаление и превью), личные и групповые чаты, настройки
группы и аватары чатов, контакты со статусом «в сети» и временем последнего
визита, профиль, аватары, push-уведомления и удаление аккаунта (ст. 14 ФЗ-152)
с отзывом согласия. Время с сервера (UTC без зоны) приводится к локальному поясу
устройства.

## Статус и план

Авторизация переведена на единый IdP `auth.muzea.su`: passwordless email-код,
access/refresh в Keychain, single-flight refresh, удаление legacy-пароля и
chat-логина. Следующий шаг — проверка входа на реальном iPhone через TestFlight,
затем текст чата (sync/квитанции/правки/реакции).

- Контракт бэкенда: [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md).
- Матрица паритета с Android (по ID из `FEATURE_CATALOG.md`):
  [`docs/PARITY.md`](docs/PARITY.md).
- Порядок работ: auth ✅ → текст чата → медиа → push/share → лента/профиль.
- Распространение: **TestFlight** (не Sideloadly и не ссылка с сайта).

## Стек

- Swift 5.9, SwiftUI, iOS 16+
- `URLSession` + `async/await` (без сторонних сетевых библиотек)
- Firebase Cloud Messaging (SPM) для пушей
- Keychain для пароля от учётной записи (аналог Android `EncryptedSharedPreferences`)
- XcodeGen — проект генерируется из `project.yml`

## Бэкенды

Приложение использует те же бэкенды, что и Android. Только HTTPS, cleartext
запрещён (ATS включён):

| Сервис | Адрес | Назначение |
|--------|-------|------------|
| IdP (auth-service) | `https://auth.muzea.su` | регистрация, вход по email-коду, access/refresh, сессии, удаление аккаунта |
| makeup | `https://api-muzea.su` | новости, видео, профиль, жалобы |
| chat | `https://chat-muzea.su` | контакты, чаты, сообщения, вложения, аватары, присутствие, FCM |

Один access-токен IdP принимается и `api-muzea.su`, и `chat-muzea.su` (через
JWKS). Отдельного логина в чат по паролю больше нет.

Адреса задаются в `Muzea/Core/Config.swift`, правовые реквизиты и ссылки —
в `Muzea/Core/Legal.swift`.

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
- `LastSeenFormatterTests` — относительные подписи «был(а) N назад», UTC-разбор
  `lastSeenAt`, клампинг будущих меток;
- `FeedFilterTests` — фильтры новостей и видео (аналоги Android-тестов);
- `JWTTests` — извлечение `sub` из chat-токена;
- `TokenStoreTests` — access/refresh в Keychain, миграция legacy-токена, `clearAll`;
- `AuthServiceTests`, `TokenRefresherTests` — контракт IdP (OTP, токены, logout,
  delete) и single-flight refresh без повторного использования refresh-токена;
- `ConsentManagerTests` — версионное согласие на обработку ПДн (ст. 9 ФЗ-152);
- `ConfigurationTests` — HTTPS-адреса бэкендов и правовые реквизиты;
- `DeleteAccountTests` — удаление аккаунта чат → основной сервер, трактовка 401/404;
- `ModelsDecodingTests` — разбор реальных ответов серверов, включая присутствие
  (ключ `online` вместо устаревшего `isOnline`);
- `HTTPClientTests`, `ChatAuthManagerTests`, `RepositoriesTests` — сетевой слой
  через mock `URLProtocol` (заголовки, multipart, 401/retry, batch-присутствие,
  heartbeat, logout, ошибки), а также дедупликация приватных чатов;
- `DomainLogicTests` — чистая логика: `ChatMessageReducer` (порядок сообщений и
  подмена серверного эха без merцания), `OpenPrivateChatUseCase`, in-memory кэши
  и `ChatListViewState`;
- `ViewModelTests` — ViewModel-и на ручных тест-дублях протоколов
  (`MuzeaTests/Support/RepositoryFakes.swift`): оптимистичная отправка, присутствие
  без переупорядочивания, дедупликация чатов, фильтры лент, вход/регистрация;
- `ContractFixtureTests`, `MakeupContractFixtureTests` — общие с Android фикстуры
  `docs/fixtures` (чат, вложения, GIF, статусы, новости, видео, профиль);
- `ViewSmokeTests` — тело каждого SwiftUI-экрана собирается без крашей;
- `LocalizationStoreTests`, `L10nCoverageTests` — переключение языка и все ключи;
- `AuthNoticeTests`, `DTOEdgeCaseTests`, `CoreStorageTests`, `FeedViewModelTests`,
  `ListAndDetailViewModelTests`, `LinkPreviewServiceTests` — новые краевые случаи.

Запуск всех тестов и отчёт покрытия:

```bash
xcodebuild test \
  -project Muzea.xcodeproj \
  -scheme Muzea \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES \
  -resultBundlePath build/TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO

xcrun xccov view --report --json build/TestResults.xcresult > build/coverage.json
python3 scripts/coverage_report.py build/coverage.json --min-logic 83
```

## CI (GitHub Actions)

Workflow `.github/workflows/ios.yml` запускается вручную (`workflow_dispatch`):

1. `macos-15`, Xcode 16 (latest stable)
2. `brew install xcodegen`
3. `xcodegen generate`
4. `xcodebuild` для симулятора без подписи (`CODE_SIGNING_ALLOWED=NO`)
5. job **Unit tests** — `xcodebuild test` на доступном iPhone-симуляторе
6. job **Release .ipa** (конфигурация `Release`) запускается только после успешных
   сборки и всех тестов (`needs: [build, test]`), поэтому релизный артефакт не
   собирается из красного состояния. Триггерится на push в `main`, PR и теги `v*`.

## Распространение: TestFlight

Целевой способ установки — **TestFlight** (тестовый релиз в App Store Connect), а не
Sideloadly и не ссылка с сайта. Для этого нужен Apple Developer Program (есть).

Что настроить один раз:

1. Bundle ID в App Store Connect. Сейчас в `project.yml` —
   `com.cyber.muzea`; для TestFlight лучше задать нормальный (например
   `su.muzea.app`) в `project.yml` и в repository variable `IOS_BUNDLE_ID`.
2. GitHub Secrets:
   - `APPLE_TEAM_ID` — Team ID;
   - `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_ID`,
     `APP_STORE_CONNECT_PRIVATE_KEY` — App Store Connect API key (`.p8` целиком).
3. Workflow **TestFlight** (`.github/workflows/testflight.yml`) запускается вручную:
   Actions → TestFlight → Run workflow. Он делает archive с автоматической
   подписью (`-allowProvisioningUpdates`), export и загрузку через `altool`.
4. Подпись/сертификаты создаются Xcode автоматически по API-ключу; для push нужен
   paid-профиль с `aps-environment`.

Пока CI собирает **неподписанный** `.ipa` (job **Release .ipa**) — он годится для
локальной отладки: [Releases](https://github.com/dabuldakov/muzea-ios/releases) или
артефакт Actions. Локально на Mac: открыть `Muzea.xcodeproj`, выбрать свою команду и
собрать на iPhone; для push нужен paid-профиль с `aps-environment`.

## Push-уведомления

Чтобы пуши заработали:

1. В Firebase Console проекта `muzea-chat` добавь iOS-приложение с bundle id
   `com.cyber.muzea` и скачай `GoogleService-Info.plist`. Старый plist от
   `com.example.muzea` нужно заменить — иначе FCM не инициализируется (сборка
   при этом проходит).
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

## Архитектура

Слоистое MVVM в духе Android-рефакторинга (SRP + протоколы + чистые use-cases):

- **Domain** — контракты репозиториев (`ChatRepository`, `MessageRepository`,
  `ContactRepository`, `AvatarRepository`, `ChatSessionRepository`, `NewsRepository`,
  `VideoRepository`, `UserRepository`, `AuthRepositoryProtocol`), use-case
  `OpenPrivateChatUseCase`, чистая логика `ChatMessageReducer` и `ChatListViewState`.
- **Data (`Core/Repositories`)** — реализации на `URLSession`; бывший god-репозиторий
  `ChatRepository` разбит по зонам ответственности, общая авторизация вынесена в
  `ChatAuthorization`. In-memory кэши — `Core/Cache/MemoryCaches.swift`.
- **Features** — View + `@MainActor ObservableObject` ViewModel с единым immutable
  `*UiState`; зависимости — только протоколы. Навигация — через `Router`
  (`NavigationPath` + `Route`), аналог Android `Navigator`.
- **DI** — `AppContainer` собирает клиенты, репозитории, кэши и use-cases и раздаёт
  их во `environmentObject`; в тестах подменяется ручными дублями.

## Структура

```
Muzea/
├── App/            точка входа, DI-контейнер, Router, таб-бар
├── Domain/
│   ├── Repositories/ протоколы репозиториев
│   ├── Chat/         ChatMessageReducer, статусы, действия, упоминания,
│   │                 черновики, outbox, link previews
│   ├── UseCase/      OpenPrivateChatUseCase
│   └── ViewState/    ChatListUiState/ChatListViewState
├── Core/
│   ├── Models/     Codable-модели (совпадают с Android/Gson) + UploadFile
│   ├── Networking/ HTTPClient, API, ошибки
│   ├── Cache/      in-memory кэши чатов, сообщений, приватных чатов, видео
│   ├── Repositories/ реализации репозиториев (SRP) + ChatAuthManager
│   ├── Push/       FCM
│   └── Util/       AvatarView, JWT, DateTimeFormat, LastSeenFormatter, ConsentManager, PasswordStore
├── Features/
│   ├── Auth/       согласие (ФЗ-152), вход и регистрация (+ AuthViewModel)
│   ├── News/       лента, детали, создание, фильтр
│   ├── Video/      список, детали (удаление), загрузка с превью
│   ├── Chat/       список чатов, переписка (текст, фото, видео, видео-кружки,
│   │               голосовые, GIF, файлы, реакции, закрепы, статусы, outbox)
│   ├── Contact/    контакты
│   └── Profile/    профиль, аватар, оператор ПДн, удаление аккаунта
└── Resources/      Info.plist, Assets

MuzeaShare/          Share Extension: текст/ссылка → выбор чата

docs/
├── API_CONTRACT.md  контракт бэкенда (auth/chat/makeup) для iOS
├── PARITY.md        матрица паритета Android → iOS
├── TRANSFER_GUIDE.md правила переноса фич и слоёв
├── XCODE_CLOUD.md   сборка и TestFlight через Xcode Cloud
├── TESTFLIGHT.md    ручной TestFlight workflow и manual signing
├── SMOKE.md         чек-лист проверки на устройстве
├── DEEP_LINKS.md    Universal Links, AASA и схемы
├── SECURITY.md      транспорт, токены, SSRF, диагностика, приватность
├── PUSH.md          APNs/FCM, токены и диагностика уведомлений
├── fixtures/chat/   общие JSON-фикстуры для Android и iOS тестов
└── fixtures/makeup/ фикстуры новостей, видео и профиля
```

## Присутствие «в сети»

Статус опирается на серверное окно онлайна (TTL ≈ 45 с от последней активности):

- **Heartbeat** — `MainTabView` раз в 15 с шлёт `POST /api/presence/heartbeat`,
  пока приложение активно (`scenePhase == .active`). В фоне цикл снимается, и
  сервер догасает статус сам.
- **Опрос контактов** — `ContactListView` раз в 20 с запрашивает
  `GET /api/presence?userUuids=…` пачками по 100 (см. `Config.presenceBatchSize`)
  и обновляет только поля присутствия, не трогая состав и порядок списка.
- **Подписи** — `LastSeenFormatter`: «в сети» с зелёной точкой, иначе «был(а)
  только что / N мин назад / N ч назад», а старше суток — локальное время визита.
- **Контракт JSON** — бэкенд отдаёт ключ `online` (не `isOnline`); модели
  `ContactResponse` и `ChatUserResponse` маппят его через `CodingKeys`.
- **Разлогин** — `AppContainer.logout()` сначала вызывает `POST /api/auth/logout`
  (пока токен ещё валиден), и лишь затем чистит локальную сессию. Иначе сессия
  осталась бы живой и пользователь «залип» бы в статусе у контактов.

## Персональные данные и правовое соответствие

- **Согласие (ст. 9 ФЗ-152)** — `ConsentManager` + `ConsentView`. Показывается при
  первом запуске и повторно при смене `Legal.consentVersion`. При регистрации —
  обязательная галочка. Пока согласие не принято, остальное приложение недоступно.
- **Сведения об операторе (ч. 1 ст. 19 ФЗ-152)** — экран `OperatorInfoView`,
  доступен из профиля: ФИО, ИНН, адрес, почта, телефон, ссылки на политику и
  пользовательское соглашение.
- **Удаление аккаунта (ст. 14 ФЗ-152)** — профиль → «Удалить аккаунт». Порядок:
  chat → makeup → IdP (`DELETE /auth/me`); локальные данные и согласие очищаются
  только после подтверждения всех сервисов. Удаление — это деактивация (SEC.06):
  вход закрывается, имя/ник скрываются, личные чаты становятся read-only, а
  данные сохраняются и восстанавливаются поддержкой. См. `docs/API_CONTRACT.md`.
- **Секреты**: access + refresh токены в Keychain
  (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), пароль не хранится — вход
  passwordless по email-коду. Legacy-пароль и отдельный chat-токен вычищаются при
  первом запуске.
