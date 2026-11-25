# Discord Rich Presence

## Подключение

1. Создайте приложение `GOD OF GRIMERKA` в [Discord Developer Portal](https://discord.com/developers/applications). Скопируйте **Application ID** из **General Information** в `application_id` под `[discord_presence]` в `godot/project.godot`. Оставьте кавычки вокруг числа.
2. Откройте **Rich Presence → Art Assets** того же приложения и загрузите изображения с ключами из таблицы.
3. Перезапустите игру или пересоберите Windows-экспорт после изменения ID. В игре включите **Настройки → Discord → Discord Rich Presence**.

| Ключ | Изображение |
|---|---|
| `logo` | Логотип для малого значка и большого изображения меню, тренировки, гонок и микрозаймов |
| `story` | Обложка сюжетного режима |
| `golda67` | Обложка «ГОЛДА 67» |
| `five_nights` | Обложка «5 НОЧЕЙ С ПАХАНОМ» |
| `survival` | Обложка Endless Survival |

Discord рекомендует квадратные изображения 1024 × 1024. [Руководство по изображениям](https://docs.discord.com/developers/discord-social-sdk/development-guides/setting-rich-presence#setting-assets)

## Проверка

Откройте настольный Discord с включённым показом игровой активности. Запустите игру из Godot или Windows-экспорта, откройте выбор режима и начните игру. Между отправками статуса проходит не менее пяти секунд. Перезапустите Discord, пока игра открыта, и дождитесь появления статуса. Для восстановления статуса после перезапуска сервис повторяет текущую карточку раз в 30 секунд. Затем выключите настройку в игре и проверьте, что карточка исчезла. Кнопка «Скачать игру» видна другим пользователям на карточке профиля. [Справка Discord о кнопках](https://docs.discord.com/developers/discord-social-sdk/development-guides/setting-rich-presence#setting-buttons)

Настройка по умолчанию выключена. Интеграция использует только отображаемое состояние режима и время начала сессии. Пустой ID оставляет сервис неактивным.

Если карточка не появилась, найдите строки `[DiscordRPC]` в панели **Вывод** Godot. Стартовый журнал показывает прочитанный ID, состояние переключателя, загрузку расширения и регистрацию классов SDK. После отправки сервис пишет результат callback с кодом и описанием или сообщает, что время ожидания истекло. При запуске через F5 включённая игра с подтверждённым RPC отображается в разделе **Активность** профиля под названием приложения Discord.

## Зависимость

Windows x86-64 использует [GDExtension Discord Social SDK 5.0.2 от ThiagoLA92](https://github.com/thiagola92/discord-social-sdk/releases/tag/5.0.2) и библиотеку Discord из [Godot Asset Store](https://store.godotengine.org/asset/thiagola92/discord-social-sdk/). В каталоге аддона приложены MIT-лицензия обёртки и уведомления SDK. [Условия Discord Social SDK](https://support-dev.discord.com/hc/en-us/articles/30225844245271-Discord-Social-SDK-Terms)
