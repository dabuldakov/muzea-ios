# Перенос функционала Android → iOS

Цель: переносить фичи механически, а не «по памяти». Для этого одинаковые
доменные имена, общие API-фикстуры и предсказуемые тесты.

## Слои

1. **DTO** — `Muzea/Core/Models/ChatDTOs.swift` (iOS) и `data/model` (Android).
   - повторяют JSON один в один;
   - только `Decodable`/`Encodable`, без UI-полей;
   - используются сетевым слоем и контрактными тестами.
2. **Домен** — `Chat`, `ChatMessage`, `ChatAttachment`, `ChatReceipt`,
   `ChatParticipant`, `Gif` и т.д., как в Android `domain/model`.
   - UI/ViewModel работают только с ними;
   - DTO → домен маппится в репозитории (`toDomain()`).
3. **Чистая логика** — `MessageStatusCalculator`, `AttachmentPolicy`,
   `MessageActionsBuilder`, `MentionSuggestions`, `ChargeCalculator`,
   `DurationFormatter`, `GifSearchViewModel`.
   - без UIKit/сети, поэтому тестируется одинаково на обеих платформах.

## Общие фикстуры

`docs/fixtures/chat/*.json` — единый источник для Android и iOS тестов.
При изменении API:

1. обновить `docs/API_CONTRACT.md`;
2. обновить фикстуру;
3. прогнать `ContractFixtureTests` (iOS) и соответствующий contract test
   (Android);
4. только потом менять DTO/мапперы.


## Локализация и тема

- Все строки интерфейса — только через `L10n` (`Muzea/Core/Localization/L10n.swift`).
  В вью не должно быть русских литералов.
- Таблицы: `Muzea/Resources/ru.lproj/Localizable.strings` и `en.lproj`.
- Новая строка = ключ в `L10n` + значение в обеих таблицах. Проверка:

  ```bash
  python3 scripts/check_localization.py
  ```

  Скрипт падает, если ключ забыт в одном языке, плейсхолдеры не совпадают
  или в `Muzea/Features`, `App`, `Core`, `Domain` появилась кириллица в литерале
  (кроме строк с `// l10n:ignore`). Он же крутится
  в `.github/workflows/checks.yml` на каждый push.
- Размеры и цвета — из `Theme` (`Muzea/Design/Theme.swift`), а не числами
  по месту. Палитра повторяет Android `colors.xml` (исходящий пузырь —
  градиент `#6200EE → #7F39FB`, входящий — `secondarySystemBackground`).
- Тесты не сравнивают локализованный текст с литералом: ожидание берётся
  из `L10n` (`XCTAssertEqual(state.notice, L10n.noticeBlocked)`).

## Чек-лист новой фичи

- [ ] ID из Android `docs/FEATURE_CATALOG.md` в сообщении коммита.
- [ ] DTO повторяет JSON, домен не знает о сети.
- [ ] Чистая логика вынесена из View/ViewModel.
- [ ] Есть unit-тест на логику и contract-тест при изменении API.
- [ ] iOS-строка добавлена в `docs/PARITY.md`.
- [ ] Новые строки добавлены в `L10n` и обе таблицы.
- [ ] Одинаковые имена полей/методов с Android, где это возможно.
- [ ] Device smoke на TestFlight перед статусом `done`.

## Запрещено

- декодировать JSON прямо в доменную модель;
- добавлять в DTO клиентские поля вроде `peerDeleted`;
- копировать серверные quirks в UI;
- использовать разные названия для одной сущности на Android и iOS.
