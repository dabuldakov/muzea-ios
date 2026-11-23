# Git flow и запуск сборок

Как изменения проходят путь от коммита до TestFlight и GitHub Release.
Про сам деплой и подпись — в [`DEPLOY.md`](DEPLOY.md), детали TestFlight —
в [`TESTFLIGHT.md`](TESTFLIGHT.md).

## Ветки

- **`main`** — единственная долгоживущая ветка, из неё собираются все релизы.
- **`feature/<кратко>`**, `fix/<кратко>` — рабочие ветки под задачу; вливаются
  в `main` через pull request.
- **Теги `v<версия>`** — отметка релиза. Пуш тега запускает сборку
  неподписанного `.ipa` и публикацию GitHub Release.

Прямые пуши в `main` допустимы для мелких правок, но перед релизом важно, чтобы
`main` был зелёным.

## Что запускается автоматически

| Событие | Workflow | Где | Что делает |
|---|---|---|---|
| push в `main` (код, тесты, скрипты) | **Checks** (`checks.yml`) | Ubuntu + macOS | ключи локализации, `check_release.py`, `swiftc -parse`, SwiftLint по `.swiftlint.yml` |
| любой pull request | **Checks** | Ubuntu + macOS | то же самое |
| push тега `v*` | **iOS CI** (`ios.yml`) | macOS | build, тесты, неподписанный `.ipa`, публикация в GitHub Release |
| вручную | **iOS CI** | macOS | build + тесты + покрытие + неподписанный `.ipa` |
| вручную | **TestFlight** (`testflight.yml`) | macOS | подписанный archive, проверка entitlement, загрузка в TestFlight |

macOS-сборки **не запускаются на каждый push**, чтобы не тратить ограниченные
macOS-раннеры. `ios.yml` и `testflight.yml` используют общий
`concurrency`-group `ios-macos-<ref>`: одновременно выполняется только один
macOS-прогон, остальные ждут в очереди. В `ios.yml` тесты идут после сборки
(`needs: build`), чтобы хватало одного раннера.

## Релиз iOS: пошагово

1. **Изменения и проверки**
   ```bash
   git switch -c feature/my-change
   # правки
   xcodegen generate        # если менялся project.yml или добавлялись файлы
   git add -A && git commit -m "feat: ..."
   git push -u origin feature/my-change
   ```
   Открыть PR → дождаться зелёного **Checks** → влить в `main`.

2. **Поднять номер сборки** в `project.yml` (`CURRENT_PROJECT_VERSION`) и
   перегенерировать проект:
   ```bash
   # project.yml: CURRENT_PROJECT_VERSION: "21"
   xcodegen generate
   git add project.yml Muzea.xcodeproj
   git commit -m "build: 1.1 (21)"
   git push origin main
   ```

3. **Прогнать iOS CI** (build + все тесты + гейты покрытия):
   ```bash
   gh workflow run ios.yml --repo dabuldakov/muzea-ios --ref main
   gh run watch --repo dabuldakov/muzea-ios
   ```

4. **Собрать и загрузить TestFlight**:
   ```bash
   gh workflow run testflight.yml --repo dabuldakov/muzea-ios --ref main \
     -f changelog="Что проверять в этой сборке"
   ```
   Workflow сам:
   - проверяет entitlements (`scripts/check_entitlements.py`);
   - собирает Release archive с manual signing;
   - проверяет `aps-environment=production` в готовом `.ipa`;
   - загружает сборку через `altool`.

5. **Проверить App Store Connect**: `processingState = VALID`,
   `internalBuildState = IN_BETA_TESTING`, compliance «нет». Установить
   из TestFlight и пройти [`SMOKE.md`](SMOKE.md).

6. **Отметить релиз тегом** (после успешной проверки):
   ```bash
   git tag v1.1.21
   git push origin v1.1.21
   ```
   Тег запускает `ios.yml`: собирает неподписанный `.ipa` и публикует его
   в GitHub Release. Подписанная сборка в TestFlight при этом не пересобирается —
   она уже загружена шагом 4.

## Hotfix

1. Ветка `fix/<кратко>` от `main`, минимальные изменения.
2. PR → Checks → merge.
3. Поднять `CURRENT_PROJECT_VERSION`, запустить `ios.yml`, затем
   `testflight.yml` с новым номером сборки.
4. После проверки — новый тег `v<версия>`.

Номер сборки (`CURRENT_PROJECT_VERSION`) **нельзя переиспользовать**: Apple
отклонит повторную загрузку с тем же номером для той же версии.

## Локальные команды

```bash
xcodegen generate
xcodebuild -project Muzea.xcodeproj -scheme Muzea \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild test -project Muzea.xcodeproj -scheme Muzea \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

Перед пушем полезно прогнать быстрые проверки без macOS:

```bash
python3 scripts/check_localization.py
python3 scripts/check_release.py
python3 scripts/check_entitlements.py
```

## Android (для сверки)

Android-релизы живут в отдельном репозитории (`dabuldakov/muzea`):

- **CI** (`ci.yml`) — на push/PR: unit-тесты и отчёт покрытия;
- **Release** (`release.yml`) — по тегу `v*`: проверяет, что `versionName`
  совпадает с тегом, собирает `.apk`/`.aab` и публикует GitHub Release;
- сайт `muzea.su` автоматически показывает последний Android-релиз через
  GitHub API, поэтому версия на кнопке обновляется без правок HTML.

iOS и Android версионируются независимо: iOS — `MARKETING_VERSION` +
`CURRENT_PROJECT_VERSION`, Android — `versionName`/`versionCode`.


## SwiftLint

Правила — в `.swiftlint.yml` (в корне репозитория). Сейчас `force_cast`,
`force_try` и `force_unwrapping` — предупреждения: сначала убираем опасные
места, затем переводим в ошибки и включаем `--strict`. Запуск: job
**SwiftLint** в `Checks`, локально — `swiftlint lint --config .swiftlint.yml`.
