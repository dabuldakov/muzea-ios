# Muzea iOS

Нативный iOS-клиент Muzea (SwiftUI). Паритет с Android-приложением:
авторизация, экран согласия на обработку персональных данных (ст. 9 ФЗ-152),
новости, видео (включая удаление и превью), личные и групповые чаты, настройки
группы и аватары чатов, контакты со статусом «в сети» и временем последнего
визита, профиль, аватары, push-уведомления и удаление аккаунта (ст. 14 ФЗ-152)
с отзывом согласия. Время с сервера (UTC без зоны) приводится к локальному поясу
устройства.

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
| makeup | `https://api-muzea.su` | авторизация, новости, видео, профиль |
| chat | `https://chat-muzea.su` | контакты, чаты, сообщения, аватары, присутствие, FCM |

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
- `TokenStoreTests` — ключи сессии, deviceId, Keychain-пароль, миграция, `clearAll`;
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
  без переупорядочивания, дедупликация чатов, фильтры лент, вход/регистрация.

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
6. job **Release .ipa** (конфигурация `Release`) запускается только после успешных
   сборки и всех тестов (`needs: [build, test]`), поэтому релизный артефакт не
   собирается из красного состояния. Триггерится на push в `main`, PR и теги `v*`.

Подпись/TestFlight не настроены — для них нужен Apple Developer аккаунт и секреты.

## Установка на iPhone (бесплатный Apple ID + Windows)

CI собирает неподписанный device-`.ipa` (job **Release .ipa**):

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
│   ├── Chat/         ChatMessageReducer
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
│   ├── Chat/       список чатов, переписка, группы, настройки группы
│   ├── Contact/    контакты
│   └── Profile/    профиль, аватар, оператор ПДн, удаление аккаунта
└── Resources/      Info.plist, Assets
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
- **Удаление аккаунта (ст. 14 ФЗ-152)** — профиль → «Удалить аккаунт». Сначала
  удаляется чат-сервер, затем основной; локальные данные и согласие очищаются
  только когда оба подтвердили удаление.
- **Пароль** хранится в Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`),
  а не в `UserDefaults`; устаревший открытый пароль мигрируется при первом запуске.
