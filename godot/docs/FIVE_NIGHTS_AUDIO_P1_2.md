# «5 НОЧЕЙ С ПАХАНОМ» — звук P1.2

Продолжение P1 (`FIVE_NIGHTS_AUDIO_GATE.md`). Утверждённые звуки (A2, B2, C1, планшет) не тронуты и играют по умолчанию.
Скримеры (группа 1) приняты и играют по умолчанию (`FNAudioGate.APPROVED`). Остальные записи P1.2 (оборудование, сигнал камер,
фон здания) лежат в `assets/audio/fn/gate`, но к игре не подключены: там играют прежние звуки.

## Как слушать

- Лаборатория: `Godot --path godot res://scenes/five_nights/audio_gate.tscn` (или открыть сцену и нажать F6).
  Вкладка группы: ORIGINAL / NEW — запись отдельно, «в будке ▶» — настоящая ночь без врагов и это событие,
  «в игре» — что играет обычная игра (выбор лежит в `user://fn_audio_gate.json`).
  В ночи: F10 — какой скример, F12 — ORIGINAL / NEW, F8 — вызвать.
- Обычная игра со всеми новыми звуками на один запуск: `Godot --path godot -- --fnaudio=new`.
- Вне игры: `docs/audio_quality_gate/p1_2/<звук>_old.wav` и `<звук>_new.wav`.

Сборка — `tools/godot-fn-audio-p1.cjs` (общие функции — `tools/fn-audio-lib.cjs`), синтеза нет. Подключение —
`FNAudioGate.TRIAL` (ключ → вариант); после приёмки ключ переносится в `APPROVED`.

## Группа 1 — скримеры

Длина каждого — как у прежних записей (от неё считаются тряска и свет), громкость — не выше прежней, пик ниже −1 дБ.
Играют тем же проигрывателем на шине Horror, что и крик БАЛОНА. Общих голосов между ними нет.

| ключ | файл | длина | из чего |
|---|---|---|---|
| `scream_madk1d` | `gate/scream_madk1d.wav` | 1,9 с | люк срывается; кошачий рёв и вой дерущихся котов из жестяной шахты, под ними визг на замедленной ленте |
| `scream_bot` | `gate/scream_bot.wav` | 2,2 с | голоса нет: удар железа, дуга сварки, очереди гайковёрта, дрель, стон пружины; обрывается остановкой лебёдки и щелчком автомата |
| `scream_clipper` | `gate/scream_clipper.wav` | 1,2 с | клинок по клинку, ножницы, неровные проходы ножа по бруску, мотор машинки для стрижки, звон листовой стали |
| `scream_ghost` | `gate/scream_ghost.wav` | 6,0 с | не крик, а провал пространства: низ раската грома, детский крик на вдвое замедленной ленте и он же задом наперёд, шёпот — через свёртку с раскатом |
| `scream_mod` | `gate/scream_mod.wav` | 2,3 с | автомат щёлкает, модем на линии воет и рвётся, треск эфира, кассета на перемотке, свист настройки; в конце гул и щелчок реле |
| `scream_dark` | `gate/scream_dark.wav` | 3,1 с | нападение после отключения питания: без тока и железа — низкий рык, хрипящие вдохи, воздух, один глухой удар |

**Исправление заодно:** нападение из темноты играло сцену и крик MOD — в `FNScare.play` не было ветки `"dark"`, и
постановка Балона из темноты (глаза в проёме, дыхание, шаги, `scream_dark`) не запускалась вовсе. Ветка добавлена.

## Источники

Все записи — CC0 (общественное достояние); лицензия прочитана на странице каждой записи 2026-11-23/24. Исходники в
репозиторий не входят.

| запись | автор | страница | лицензия | куда вошла |
|---|---|---|---|---|
| Scissors (BigSoundBank #0008) | Joseph SARDIN | https://bigsoundbank.com/scissors-s0008.html | CC0 (public domain) | scream_clipper |
| Sword (BigSoundBank #0129) | Joseph SARDIN | https://bigsoundbank.com/sword-s0129.html | CC0 (public domain) | scream_clipper |
| Internet Connection #2 (BigSoundBank #0158) | Joseph SARDIN | https://bigsoundbank.com/internet-connection-2-s0158.html | CC0 (public domain) | scream_mod |
| Drill (BigSoundBank #0184) | Joseph SARDIN | https://bigsoundbank.com/drill-s0184.html | CC0 (public domain) | scream_bot |
| Large spring (BigSoundBank #0206) | Joseph SARDIN | https://bigsoundbank.com/large-spring-s0206.html | CC0 (public domain) | scream_bot |
| Radio interference #2 (BigSoundBank #0311) | DenisChardonnet | https://bigsoundbank.com/radio-interference-2-s0311.html | CC0 (public domain) | scream_mod |
| Crackling Radio #2 (BigSoundBank #0313) | DenisChardonnet | https://bigsoundbank.com/crackling-radio-2-s0313.html | CC0 (public domain) | scream_mod |
| Car door (BigSoundBank #0655) | Joseph SARDIN | https://bigsoundbank.com/car-door-s0655.html | CC0 (public domain) | scream_bot, scream_dark |
| Little electric winch (BigSoundBank #0708) | Joseph SARDIN | https://bigsoundbank.com/little-electric-winch-s0708.html | CC0 (public domain) | scream_bot |
| Blow on hand (BigSoundBank #0747) | Joseph SARDIN | https://bigsoundbank.com/blow-on-hand-s0747.html | CC0 (public domain) | scream_dark |
| Metal filing cabinet (BigSoundBank #0773) | Joseph SARDIN | https://bigsoundbank.com/metal-filing-cabinet-s0773.html | CC0 (public domain) | scream_madk1d |
| Two Cats Fighting (BigSoundBank #0817) | Joseph SARDIN | https://bigsoundbank.com/two-cats-fighting-s0817.html | CC0 (public domain) | scream_madk1d |
| Whetstone (BigSoundBank #0832) | Joseph SARDIN | https://bigsoundbank.com/whetstone-s0832.html | CC0 (public domain) | scream_clipper |
| Hair clippersin #1 (BigSoundBank #0891) | Joseph SARDIN | https://bigsoundbank.com/hair-clippersin-1-s0891.html | CC0 (public domain) | scream_clipper |
| Short welds (BigSoundBank #0952) | Joseph SARDIN | https://bigsoundbank.com/short-welds-s0952.html | CC0 (public domain) | scream_bot |
| Impact wrench #1 (BigSoundBank #0964) | Joseph SARDIN | https://bigsoundbank.com/impact-wrench-1-s0964.html | CC0 (public domain) | scream_bot |
| Electric circuit breaker (BigSoundBank #1092) | Joseph SARDIN | https://bigsoundbank.com/electric-circuit-breaker-s1092.html | CC0 (public domain) | scream_bot, scream_mod |
| Kids screaming #2 (BigSoundBank #1149) | Joseph SARDIN | https://bigsoundbank.com/kids-scream-2-s1149.html | CC0 (public domain) | scream_madk1d, scream_ghost |
| Donkey, Braying #3 (BigSoundBank #1551) | Joseph SARDIN | https://bigsoundbank.com/donkey-braying-3-s1551.html | CC0 (public domain) | scream_dark |
| Falling sheet steel bar #1 (BigSoundBank #1771) | Joseph SARDIN | https://bigsoundbank.com/falling-sheet-steel-bar-1-s1771.html | CC0 (public domain) | scream_clipper |
| Fall 2 sheet steel bars #2 (BigSoundBank #1777) | Joseph SARDIN | https://bigsoundbank.com/fall-2-sheet-steel-bars-2-s1777.html | CC0 (public domain) | scream_madk1d |
| Explosion #2 (BigSoundBank #1808) | Joseph SARDIN | https://bigsoundbank.com/explosion-2-s1808.html | CC0 (public domain) | scream_dark |
| Cat roar #2 (BigSoundBank #1882) | Joseph SARDIN | https://bigsoundbank.com/cat-roar-2-s1882.html | CC0 (public domain) | scream_clipper |
| Cat roar #3 (BigSoundBank #1883) | Joseph SARDIN | https://bigsoundbank.com/cat-roar-3-s1883.html | CC0 (public domain) | scream_madk1d |
| Zombie #1 (BigSoundBank #2106) | Joseph SARDIN | https://bigsoundbank.com/zombie-1-s2106.html | CC0 (public domain) | scream_dark |
| Neon or transformer #1 (BigSoundBank #2118) | Joseph SARDIN | https://bigsoundbank.com/neon-or-transformer-1-s2118.html | CC0 (public domain) | scream_bot, scream_mod |
| Cassette: Back #4 (BigSoundBank #2157) | Joseph SARDIN | https://bigsoundbank.com/audio-cassette-back-4-s2157.html | CC0 (public domain) | scream_mod |
| Thermostat #1 (BigSoundBank #2191) | Joseph SARDIN | https://bigsoundbank.com/thermostat-1-s2191.html | CC0 (public domain) | scream_mod |
| Metal barrier: Closure #3 (BigSoundBank #2360) | Joseph SARDIN | https://bigsoundbank.com/grinding-metal-barrier-closure-3-s2360.html | CC0 (public domain) | scream_bot |
| Thunder #2 (BigSoundBank #3113) | Joseph SARDIN & Axeline T. | https://bigsoundbank.com/thunder-2-s3113.html | CC0 (public domain) | scream_ghost |
| Whisper #1 (BigSoundBank #3255) | Joseph SARDIN & Axeline T. | https://bigsoundbank.com/whisper-1-s3255.html | CC0 (public domain) | scream_ghost |
| Whisper #2 (BigSoundBank #3256) | Joseph SARDIN & Axeline T. | https://bigsoundbank.com/whisper-2-s3256.html | CC0 (public domain) | scream_ghost |
| 68 Workshop Sounds: «low hammering» | bart | https://opengameart.org/content/68-workshop-sounds | CC0 | scream_madk1d |
