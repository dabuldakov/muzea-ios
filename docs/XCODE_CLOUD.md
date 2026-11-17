# Xcode Cloud для Muzea

Основная сборка iOS и загрузка в TestFlight идут через Xcode Cloud, без
macOS-минут GitHub Actions.

## Что уже подготовлено

- `Muzea.xcodeproj` закоммичен, чтобы App Store Connect видел проект при
  первичной настройке;
- `ci_scripts/ci_post_clone.sh` пишет Firebase-конфиг и Klipy-ключ из
  переменных окружения Xcode Cloud;
- Share Extension `MuzeaShare` — отдельный bundle `com.cyber.muzea.Share`;
- GitHub workflow `ios.yml` переведён в ручной режим (`workflow_dispatch`),
  чтобы не тратить лимит.

## Настройка в App Store Connect

1. Apple Developer Program → App Store Connect → **Xcode Cloud** → Get Started.
2. Подключить GitHub-аккаунт и выбрать репозиторий `muzea-ios`, ветку `main`.
3. Выбрать приложение `com.cyber.muzea` (создать App ID, если его нет).
4. Создать Workflow:
   - Scheme: `Muzea`;
   - Environment: Xcode 16/latest;
   - Start Condition: Branch Changes → `main` (или только вручную);
   - Actions:
     - Build;
     - Test → `MuzeaTests` на iPhone Simulator;
     - Archive → TestFlight (Internal Testing).
5. В Environment Variables добавить **секреты**:
   - `GOOGLE_SERVICE_INFO_PLIST` — base64 от `GoogleService-Info.plist`;
   - `KLIPY_APP_KEY` — ключ Klipy.
6. Убедиться, что в App Store Connect созданы bundle ID:
   - `com.cyber.muzea`;
   - `com.cyber.muzea.Share`.
   Подпись Xcode Cloud делает автоматически через Apple ID команды.

## Важные детали

- `GoogleService-Info.plist` не хранится в git; на сборке создаётся из
  `GOOGLE_SERVICE_INFO_PLIST`.
- `KLIPY_APP_KEY` не хранится в git; подставляется в `Info.plist` в
  post-clone.
- Если менялся `project.yml`, нужно перегенерировать проект и закоммитить:

  ```bash
  xcodegen generate
  git add Muzea.xcodeproj
  ```

  Без Mac это можно сделать в Linux-контейнере с XcodeGen; проект уже
  сгенерирован и лежит в репозитории.
- Share Extension требует, чтобы у него был свой App ID и provisioning;
  Xcode Cloud обычно создаёт профиль автоматически при `-allowProvisioningUpdates`.

## Проверка

После первого workflow:
1. дождаться Build + Test;
2. проверить, что Archive появился в TestFlight;
3. установить через TestFlight и пройти smoke:
   - вход по email-коду;
   - список чатов/переписка;
   - push в чат;
   - вложение фото/видео/голосового/кружка;
   - Share Extension.
