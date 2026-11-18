# Shared API fixtures (Android + iOS)

Один и тот же JSON используется тестами Android и iOS. Это контракт между
клиентами и бэкендом, а не «тестовые модели»: поля повторяют реальные ответы
chat-service.

Правила:

- фикстуры не содержат клиентских полей (`peerDeleted`, локальные статусы);
- при изменении API сначала обновляется `docs/API_CONTRACT.md` и фикстура,
  затем контрактные тесты на обеих платформах;
- Android читает этот каталог из своего репозитория (копия/симлинк в
  `app/src/test/resources/fixtures`), iOS — через `#filePath` в
  `MuzeaTests/ContractFixtureTests.swift`;
- доменные модели платформ называются одинаково (`Chat`, `ChatMessage`,
  `ChatAttachment`, `ChatReceipt`), поэтому перенос тестов и логики
  механический.

Файлы:

- `chat/chats.json` — список чатов;
- `chat/messages_page.json` — страница сообщений с текстом, медиа, реакциями,
  `senderDeleted` и `power`;
- `chat/receipts.json` — водяные знаки участников;
- `chat/message_statuses.json` — точные статусы по сообщению;
- `chat/attachment.json` — ответ загрузки вложения;
- `chat/message_gif.json` — GIF-сообщение с `gifKey`, `mp4Url` и размерами;
- `chat/chat_peer_deleted.json` — личный чат с деактивированным собеседником;
- `chat/participants.json` — участники группы;
- `chat/media_types.json` — golden-таблица типов/лимитов вложений (все
  расширения из `AttachmentPolicy`);
- `chat/gif_search.json` — ответ Klipy;
- `makeup/news_page.json`, `news.json`, `videos.json`, `user.json`,
  `news_created.json` — ответы makeup/feed/profile.
