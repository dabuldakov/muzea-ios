# TestFlight через GitHub Actions

Workflow: `.github/workflows/testflight.yml` (ручной запуск).

```bash
gh workflow run testflight.yml --repo dabuldakov/muzea-ios --ref main \
  -f changelog="What to test"
```

## Secrets

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY` — содержимое `.p8`
- `IOS_DISTRIBUTION_P12` — base64 от distribution `.p12` (legacy-формат)
- `IOS_DISTRIBUTION_P12_PASSWORD`
- `IOS_PROFILE_APP` — base64 App Store профиля `com.cyber.muzea`
- `IOS_PROFILE_SHARE` — base64 App Store профиля `com.cyber.muzea.Share`
- `KLIPY_APP_KEY`
- `GOOGLE_SERVICE_INFO_PLIST` — base64 Firebase plist

## Подпись

Workflow использует **manual signing**:

- distribution-сертификат импортируется во временный keychain;
- профили кладутся в `~/Library/MobileDevice/Provisioning Profiles`;
- `ExportOptions.plist` содержит mapping:
  - `com.cyber.muzea` → `Muzea App Store`;
  - `com.cyber.muzea.Share` → `Muzea Share App Store`.

Почему не automatic signing: API-ключ с ролью App Manager умеет создавать bundle ID
и сертификаты, но `xcodebuild -exportArchive` с cloud signing требует прав Admin.
Manual signing обходит это.

## SDK и предупреждения App Store Connect

Сборка 1.1 (3) прошла доставку с предупреждением **ITMS-90725**: она собрана
с iOS 26.2 SDK. С апреля 2027 Apple требует собирать приложения с iOS 27 SDK
(Xcode 27+). Это не блокирует текущие сборки, но перед дедлайном нужно:

1. убедиться, что в CI стоит Xcode 27 (`setup-xcode` с `latest-stable` подхватит
   его автоматически, когда он станет стабильным);
2. для Xcode Cloud выбрать Xcode 27 в настройках workflow;
3. выпустить сборку с тем же номером версии, но новым build.

## Проверка

- Build в App Store Connect: `processingState = VALID`;
- `buildBetaDetail.internalBuildState = READY_FOR_BETA_TESTING`;
- compliance: `usesNonExemptEncryption = false`;
- внутренняя группа TestFlight получает сборку автоматически.
