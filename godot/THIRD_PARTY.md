# Сторонние компоненты Godot-сборки

Что из чужого входит в игру или используется ею, и на каких условиях.

| Что | Где | Лицензия / условия |
|---|---|---|
| Движок Godot 4.7.2 | вся сборка | MIT, © Juan Linietsky, Ariel Manzur и участники Godot Engine |
| Kenney Particle Pack | `godot/assets/fx` | CC0 (общественное достояние) |
| Шрифт Russo One | `godot/assets/fonts/RussoOne-Regular.ttf` | SIL Open Font License 1.1 |
| Модели персонажей и оружия | `godot/assets/models` | сгенерированы в Tripo AI владельцем проекта |
| Голоса | `godot/assets/voice` | Fish Audio, по ключу владельца проекта |
| Музыка и треки | `godot/assets/audio`, `godot/assets/music` | права у владельца проекта; музыка локаций синтезируется `tools/godot-music.cjs` |

## Декодирование музыки в iPod

Форматы M4A (AAC, ALAC), M4B, FLAC и сжатый WAV игра **не декодирует своим кодом и не несёт чужих кодеков**:
их перекодирует сама Windows — Media Foundation через WinRT `MediaTranscoder`, который вызывает встроенный
в систему `powershell.exe` (скрипт игра пишет сама, см. `godot/docs/IPOD_AUDIO_FORMATS.md`).
Ничего не скачивается и не устанавливается; кодеки — часть Windows и лицензированы вместе с ней.
Разбор контейнеров (MP4-атомы, AIFF, FLAC-метаданные, теги) и перевод AIFF в WAV — собственный код проекта
(`godot/scripts/audio_import.gd`, `godot/scripts/id3.gd`).

Защищённые файлы (iTunes M4P, Audible AA/AAX, любые с DRM внутри) игра не открывает и защиту не обходит.
