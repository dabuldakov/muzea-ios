# Деплой iOS-приложения Muzea

Документ описывает полный путь сборки от коммита до установки на iPhone:
что настроено один раз, как выпустить сборку, как проверить её и что делать,
если что-то сломалось.

Коротко: **основной канал — TestFlight**, сборка и загрузка идут через GitHub
Actions (`.github/workflows/testflight.yml`, ручной запуск). Xcode Cloud —
резервный путь, неподписанный `.ipa` — только для локальной отладки.

## 1. Каналы распространения

| Канал | Что это | Кому |
|---|---|---|
| **TestFlight** | подписанная сборка в App Store Connect, установка через приложение TestFlight | тестировщики, текущий основной путь |
| **App Store** | публичный релиз | все пользователи, после ревью Apple |
| **Unsigned `.ipa`** | архив без подписи (job `Release .ipa`) | локальная отладка, Sideloadly; не для пользователей |

## 2. Что настроено один раз

### Apple Developer и App Store Connect

- Apple Developer Program, Team ID **`5HGZ927RW5`**.
- App ID:
  - `com.cyber.muzea` — приложение Muzea, capability **Push Notifications**,
    Associated Domains (`applinks:muzea.su`);
  - `com.cyber.muzea.Share` — Share Extension, push не нужен.
- Приложение в App Store Connect: **Muzea**, Apple ID `6835792727`.
- Сертификат **Apple Distribution** и App Store профили:
  - `Muzea App Store` → `com.cyber.muzea`;
  - `Muzea Share App Store` → `com.cyber.muzea.Share`.
- App Store Connect API key (Issuer ID + Key ID + `.p8`) для `altool` и экспорта.
  Роль ключа — Admin или Developer; для `xcodebuild -exportArchive` с manual
  signing достаточно прав на сертификаты и профили.

### Firebase и push

- Firebase project **`muzea-chat`**, iOS-приложение с bundle ID `com.cyber.muzea`
  (`GOOGLE_APP_ID = 1:852486675776:ios:8005ad41ff5bdfafefeea5`).
- `GoogleService-Info.plist` для этого приложения. В git не хранится: локально
  лежит в `Muzea/Resources/GoogleService-Info.plist`, в CI — в секрете
  `GOOGLE_SERVICE_INFO_PLIST` (base64).
- **APNs Authentication Key** загружен в Firebase → Project settings → Cloud
  Messaging → Apple app configuration, в оба слота (Development и Production).
  Один и тот же ключ работает для sandbox и production, отдельные ключи не нужны.
  Ключ создаётся в developer.apple.com → Certificates, Identifiers & Profiles →
  **Keys** → «+» → Apple Push Notifications service (APNs); роль Account Holder
  или Admin. Ключи App Store Connect API для APNs не подходят.

Подробная диагностика push — в [`PUSH.md`](PUSH.md).

### GitHub Secrets (репозиторий `dabuldakov/muzea-ios`)

| Секрет | Назначение |
|---|---|
| `APPLE_TEAM_ID` | Team ID `5HGZ927RW5` |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID ключа App Store Connect API |
| `APP_STORE_CONNECT_KEY_ID` | Key ID ключа App Store Connect API |
| `APP_STORE_CONNECT_PRIVATE_KEY` | содержимое `AuthKey_<KeyID>.p8` целиком |
| `IOS_DISTRIBUTION_P12` | base64 от distribution `.p12` |
| `IOS_DISTRIBUTION_P12_PASSWORD` | пароль `.p12` |
| `IOS_PROFILE_APP` | base64 App Store профиля `com.cyber.muzea` |
| `IOS_PROFILE_SHARE` | base64 App Store профиля `com.cyber.muzea.Share` |
| `KLIPY_APP_KEY` | ключ Klipy для GIF |
| `GOOGLE_SERVICE_INFO_PLIST` | base64 `GoogleService-Info.plist` |

Проверить, что секреты на месте, можно только косвенно: workflow
`testflight.yml` на первом шаге падает с понятной ошибкой, если не задан один из
четырёх ключевых секретов (`APPLE_TEAM_ID`, issuer, key ID, private key).

## 3. Версии и номера сборок

Версии задаются в `project.yml` для обоих таргетов (`Muzea` и `MuzeaShare`):

```yaml
MARKETING_VERSION: "1.1"        # видимая версия, CFBundleShortVersionString
CURRENT_PROJECT_VERSION: "8"    # номер сборки, CFBundleVersion
```

Правила:

- **`CURRENT_PROJECT_VERSION` увеличивается перед каждой загрузкой в TestFlight.**
  Apple не принимает повторно один и тот же номер сборки для одной версии.
- `MARKETING_VERSION` меняется при заметном релизе; номер сборки — всегда.
- Оба таргета держим синхронно: у приложения и расширения одинаковые значения.
- После изменения `project.yml` нужно перегенерировать проект:

  ```bash
  xcodegen generate
  git add Muzea.xcodeproj project.yml
  ```

## 4. Релиз в TestFlight (основной путь)

### Шаг 1. Pre-flight

1. Убедиться, что `main` зелёный: последний прогон `ios.yml` — Build и Unit tests
   успешны. Если сомневаетесь, запустите вручную (см. раздел 5).
2. Проверить локализацию: `python3 scripts/check_localization.py` (в CI ключи
   проверяются тестами `L10nCoverageTests`).
3. Поднять `CURRENT_PROJECT_VERSION` в `project.yml`, при необходимости —
   `MARKETING_VERSION`.
4. `xcodegen generate`, закоммитить `project.yml` и `Muzea.xcodeproj`, запушить
   в `main`.
5. Убедиться, что APNs-ключ в Firebase действует (см. [`PUSH.md`](PUSH.md)):
   без него сборка загрузится, но push на iOS не пойдут.

### Шаг 2. Запуск workflow

```bash
gh workflow run testflight.yml \
  --repo dabuldakov/muzea-ios \
  --ref main \
  -f changelog="Что проверять в этой сборке"
```

Или в браузере: Actions → **TestFlight** → Run workflow.

Что делает workflow:

1. выбирает Xcode (`latest-stable`) на `macos-15`;
2. проверяет наличие обязательных секретов;
3. декодирует `GoogleService-Info.plist` из секрета;
4. ставит XcodeGen и генерирует проект из `project.yml`;
5. импортирует distribution-сертификат во временный keychain и кладёт профили;
6. делает `xcodebuild archive` (Release, `iphoneos`);
7. экспортирует подписанный `.ipa` с **manual signing**;
8. загружает `.ipa` в TestFlight через `xcrun altool`;
9. сохраняет подписанный `.ipa` артефактом и удаляет keychain.

Ориентировочное время — 15–25 минут, из них большая часть — очередь macOS-раннера
и загрузка.

### Шаг 3. Наблюдение

```bash
gh run list --repo dabuldakov/muzea-ios --workflow=testflight.yml --limit 3
gh run watch <run-id> --repo dabuldakov/muzea-ios
```

Если job долго висит в `queued` и падает с «The job was not acquired by Runner of
type hosted» — это нехватка macOS-раннеров GitHub, а не ошибка кода. Достаточно
перезапустить run:

```bash
gh run rerun <run-id> --repo dabuldakov/muzea-ios
```

### Шаг 4. Проверка в App Store Connect

После обработки сборки (обычно 5–15 минут):

- `processingState = VALID`;
- `buildBetaDetail.internalBuildState = IN_BETA_TESTING` (или
  `READY_FOR_BETA_TESTING`, пока не назначена группа);
- compliance: «используется неисключённое шифрование» — **нет**
  (`ITSAppUsesNonExemptEncryption = false` в `Info.plist`);
- сборка видна внутренним тестировщикам в TestFlight.

Проверить через API можно тем же ключом App Store Connect API (см.
`docs/TESTFLIGHT.md`).

### Шаг 5. Установка и smoke

1. Установить сборку из TestFlight на iPhone.
2. Открыть приложение, разрешить уведомления, войти в аккаунт.
3. Пройти [`SMOKE.md`](SMOKE.md) — минимум auth, чат, медиа, push, ссылки,
   лента/профиль.
4. Для push убедиться, что в `device_tokens` появился свежий iOS-токен, и
   отправить тестовое сообщение с другого аккаунта.

## 5. CI-проверки (`ios.yml`)

Workflow ручной (`workflow_dispatch`), чтобы не тратить macOS-минуты:

1. **Build (iOS Simulator)** — сборка Debug для `iphonesimulator` без подписи.
2. **Unit tests (iOS Simulator)** — `xcodebuild test`, покрытие через
   `scripts/coverage_report.py`, гейты: логика ≥ 83 %, общее ≥ 60 %.
3. **Release .ipa** — запускается только после успешных build и test
   (`needs: [build, test]`), собирает неподписанный архив. На теге `v*`
   публикует `.ipa` в GitHub Release.

Запуск:

```bash
gh workflow run ios.yml --repo dabuldakov/muzea-ios --ref main
```

Публикация неподписанного `.ipa` по тегу:

```bash
git tag v1.1.8 && git push origin v1.1.8
gh workflow run ios.yml --repo dabuldakov/muzea-ios --ref v1.1.8
```

## 6. Xcode Cloud (резервный путь)

Xcode Cloud собирает проект без GitHub macOS-минут: `ci_scripts/ci_post_clone.sh`
ставит XcodeGen и генерирует проект, переменные окружения подставляют Firebase
plist и Klipy-ключ. Настройка и ограничения — в [`XCODE_CLOUD.md`](XCODE_CLOUD.md).

Когда использовать: GitHub-раннеры недоступны или нужен автоматический прогон
после каждого изменения `main`.

## 7. Локальная сборка на Mac

```bash
brew install xcodegen
xcodegen generate
open Muzea.xcodeproj
```

Для установки на устройство: выбрать свою команду в Signing & Capabilities,
подписать и запустить. Для push нужен профиль с `aps-environment`.

Неподписанный архив для Sideloadly:

```bash
xcodebuild archive \
  -project Muzea.xcodeproj -scheme Muzea -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -archivePath build/Muzea.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## 8. Публикация в App Store (когда дойдём)

1. В App Store Connect создать версию, заполнить метаданные: описание, ключевые
   слова, скриншоты (iPhone), возрастной рейтинг, категории.
2. Privacy: политика конфиденциальности, `PrivacyInfo.xcprivacy` уже в проекте,
   ответы про сбор данных.
3. Export compliance: `ITSAppUsesNonExemptEncryption = false`.
4. Учётная запись для ревью: тестовый аккаунт с заполненным профилем (вход по
   email-коду — описать в заметках для ревью, что код приходит на email).
5. Удаление аккаунта: требование Apple 5.1.1(v) выполнено — деактивация с
   сохранением данных и восстановлением через поддержку.
6. Отправить на ревью, после одобрения — поэтапный выпуск (Phased Release).
7. До апреля 2027 сборка должна быть сделана с iOS 27 SDK (Xcode 27), иначе
   App Store Connect начнёт отклонять загрузки (ITMS-90725).

## 9. Откат и хотфикс

- **TestFlight**: старую сборку можно «погасить» (Expire) в App Store Connect;
  исправление — новая сборка с **большим** номером `CURRENT_PROJECT_VERSION`.
  Переиспользовать номер нельзя.
- **App Store**: остановить поэтапный выпуск, выпустить новую версию/сборку.
- **Срочный фикс**: ветка от `main`, минимальные изменения, bump build number,
  прогон `ios.yml`, затем `testflight.yml`.

## 10. Диагностика

| Симптом | Причина | Что делать |
|---|---|---|
| «The job was not acquired by Runner of type hosted» | нет свободных macOS-раннеров | перезапустить run, подождать |
| ITMS-90725 | сборка на старом iOS SDK | перейти на Xcode 27 до апреля 2027 |
| «Missing Compliance» после загрузки | не указан export compliance | `ITSAppUsesNonExemptEncryption = false` в `Info.plist` |
| `THIRD_PARTY_AUTH_ERROR`, `InvalidProviderToken` | в Firebase не APNs-ключ (например, App Store Connect API) | создать APNs Auth Key в developer.apple.com → Keys |
| Push не приходит, токена нет в `device_tokens` | неверный `GoogleService-Info.plist`, не выполнен вход | сверить bundle ID/GOOGLE_APP_ID, войти в аккаунт |
| `Invalid Bundle`, профиль не подходит | не совпадает bundle ID или профиль | проверить `com.cyber.muzea` и `com.cyber.muzea.Share` |
| `altool` не авторизуется | неверные issuer/key ID или `.p8` | проверить секреты App Store Connect API |
| «build number already used» | номер сборки не поднят | увеличить `CURRENT_PROJECT_VERSION` |
| Workflow упал на экспорте | manual signing: нет профиля/сертификата | проверить `IOS_PROFILE_*`, `IOS_DISTRIBUTION_P12*` |

## 11. Чек-лист релиза

- [ ] `main` зелёный (Build + Unit tests);
- [ ] `CURRENT_PROJECT_VERSION` поднят, `project.yml` и `.xcodeproj` закоммичены;
- [ ] `testflight.yml` завершился успешно;
- [ ] сборка в App Store Connect: `VALID`, compliance — «нет»;
- [ ] установлена на iPhone, вход выполнен, уведомления разрешены;
- [ ] smoke по `SMOKE.md` пройден;
- [ ] push проверен, iOS-токен есть в `device_tokens`;
- [ ] changelog в TestFlight заполнен;
- [ ] при публичном релизе — метаданные, скриншоты, ревью.
