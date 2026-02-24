## 1.0.1

- Changed license from MIT to BSD-3-Clause.

## 1.0.0

- Initial public release.
- Abstract `ChatApi` interface for platform-agnostic messaging.
- `ChatMessage`, `ChatReceiver`, `ChatResponse`, `ChatSettings` data models.
- Telegram implementation via `TelegramChat` with polling-based message reception.
- Support for text messages, photos, documents, audio, video, and voice attachments.
- `ChatConfig` and `TelegramChatConfig` for platform-specific configuration.
