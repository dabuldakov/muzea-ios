# Публикация в App Store

Документ описывает публичный релиз iOS-приложения Muzea: версию, сборку,
демо-аккаунт для ревью, скриншоты и ручные шаги в App Store Connect.

## 1. Реквизиты

| Параметр | Значение |
|---|---|
| App Store Connect app id | `6835792727` |
| Bundle ID | `com.cyber.muzea` |
| SKU | `muzea-ios` |
| Team ID | `5HGZ927RW5` |
| Версия | `1.3` |
| Build | `30` (синхронизация лайков новостей), загружен 28.11.2026 |
| Категории | Основная — «Новости», дополнительная — «Социальные сети» |
| Цена | Бесплатно |
| Возрастной рейтинг | 12+ (пользовательский контент и чаты, модерация есть) |

Название в App Store: `Muzea — новости и видео` (ru), `Muzea: news and video` (en).
Просто `Muzea` занято другим аккаунтом, поэтому используется уточнение.

## 2. Демо-аккаунт для App Review

App Review не может получить письмо с кодом, поэтому для демо-аккаунта
настроен фиксированный код на стороне auth-сервиса.

| Поле | Значение |
|---|---|
| Email | `demo@muzea.su` |
| Код | `246810` |
| Username | `muzea_demo` |
| Отображаемое имя | `Команда музея` |

Инструкция для ревьюера (продублирована в App Store Connect → App Review
Information → Notes):

1. Ввести `demo@muzea.su` и нажать «Получить код».
2. Ввести `246810` и нажать «Войти».
3. Письмо не отправляется; код действует постоянно.

### Как это устроено на сервере

В `muzea-auth-service` добавлена env-конфигурация:

```dotenv
AUTH_DEMO_EMAIL=demo@muzea.su
AUTH_DEMO_CODE=246810
AUTH_DEMO_TTL_SECONDS=7776000
```

`EmailCodeService.issue` для этого email сохраняет фиксированный код и не
отправляет письмо. Остальные аккаунты работают как раньше. Чтобы отключить
демо-доступ, достаточно убрать `AUTH_DEMO_EMAIL`/`AUTH_DEMO_CODE` и
перезапустить auth-сервис.

Демо-данные в chat-БД:

- личный чат с Анной;
- группа «Друзья музея» (4 участника, закреплённое сообщение, реакции);
- группа «Выставка «Свет»».

## 3. Скриншоты

Скриншоты снимаются в CI на симуляторе iPhone Pro Max (6.9", 1320×2868):

- workflow: `.github/workflows/screenshots.yml`;
- скрипт: `scripts/capture_screenshots.sh`;
- запуск: вручную (`workflow_dispatch`) или push в ветку `screenshots/ios-1`;
- результат: artifact `app-store-screenshots` с JPEG для ru и en.

Workflow сам логинится демо-аккаунтом через `/auth/otp/request` и
`/auth/otp/verify`, поэтому секреты не нужны. Для съёмки используются
DEBUG-аргументы запуска `-MUZEA_SCREENSHOT_ACCESS`,
`-MUZEA_SCREENSHOT_REFRESH`, `-MUZEA_SCREENSHOT_TAB`,
`-MUZEA_SCREENSHOT_USERNAME` и `-MUZEA_SCREENSHOT_NEWS/CHAT`; в Release-сборку
этот код не попадает (`#if DEBUG`).

Комплект: новости, карточка новости, список чатов, переписка, видео, профиль.

## 4. App Privacy (ручной шаг)

Публичного API для App Privacy в App Store Connect нет — раздел заполняется в
веб-интерфейсе. Ответы для Muzea:

| Категория | Тип данных | Связано с пользователем | Для отслеживания | Назначение |
|---|---|---|---|---|
| Contact Info | Email address | Да | Нет | App Functionality |
| Contact Info | Name | Да | Нет | App Functionality |
| User Content | Photos or Videos | Да | Нет | App Functionality |
| User Content | Audio Data | Да | Нет | App Functionality |
| User Content | Other User Content (сообщения, новости, комментарии) | Да | Нет | App Functionality |
| Identifiers | User ID | Да | Нет | App Functionality |
| Identifiers | Device ID (device_id, FCM token) | Да | Нет | App Functionality |
| Diagnostics | Crash Data | Да | Нет | App Functionality |
| Diagnostics | Other Diagnostic Data | Да | Нет | App Functionality |
| Search History | Поиск по GIF и пользователям | Да | Нет | App Functionality |
| Usage Data | Other Usage Data | Да | Нет | App Functionality |

Не заявляем: точную/приблизительную геолокацию, контакты телефонной книги,
историю браузера, покупки, здоровье, финансовые данные, рекламные данные.
Доступа к галерее и телефонной книге нет: используются системные Photos Picker
и file importer, камера/микрофон — только при записи.

Порядок в веб-интерфейсе:

1. App Store Connect → приложение Muzea → **App Privacy** → **Get Started**.
2. Ответить **Yes, we collect data from this app**.
3. Добавить типы из таблицы; для каждого выбрать **App Functionality**,
   **Data linked to the user** = Yes, **Tracking** = No.
4. **Publish** — без публикации App Review не примет версию.

## 5. Текущий статус

- Версия `1.3` (build `29`) отправлена на App Review 28.11.2026,
  состояние `WAITING_FOR_REVIEW`. В ней единый стиль экранов входа,
  регистрации и кода, локализация RU/EN и актуальные домены.
- Отправка `1.2` (build `28`) была отозвана из ревью, чтобы выпустить
  актуальный дизайн в `1.3`. Более ранние `1.1` (build `24`) и промежуточные
  `1.2` (build `25`–`27`) также отзывались.
- App Privacy опубликован, скриншоты 6.9" загружены для `ru` и `en-US`.
- После одобрения версия выйдет автоматически (`releaseType = AFTER_APPROVAL`);
  поэтапный выпуск можно включить в App Store Connect.

## 6. Порядок релиза

1. Поднять `CURRENT_PROJECT_VERSION` в `project.yml`, собрать и загрузить
   сборку:

   ```bash
   git flow ...           # см. docs/GIT_FLOW.md
   gh workflow run testflight.yml
   ```

   Или тегом: `git tag v1.2.26 && git push origin v1.2.26` — `ios.yml`
   соберёт unsigned IPA и GitHub Release, `testflight.yml` загрузит подписанную
   сборку.

2. Дождаться `processingState = VALID` в App Store Connect.
3. Привязать сборку к версии, заполнить локализации, категории, возрастной
   рейтинг, App Privacy, скриншоты и демо-аккаунт.
4. Отправить версию на ревью.
5. После одобрения включить поэтапный выпуск (7 дней) и следить за отзывами.

## 7. Ограничения и напоминания

- ITMS-90725: Apple требует собирать релизы на Xcode 27 / iOS 27 SDK с апреля
  2027. До этого перевести CI на новый Xcode и проверить предупреждения.
- App Store Connect API-ключ `9S9CQWQFKM` используется только для загрузки
  сборок. Для метаданных нужен ключ с ролью App Manager (например,
  `HZ79VT8M22`).
- App Privacy и финальная кнопка «Submit for Review» требуют входа в
  веб-интерфейс App Store Connect под Apple ID команды.
