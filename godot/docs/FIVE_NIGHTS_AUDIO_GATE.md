# «5 НОЧЕЙ С ПАХАНОМ» — AUDIO QUALITY GATE (P1)

Три звука, у каждого прежний вариант и два новых. Новые собраны только из записей (CC0), без синтеза и без нейросетей.
Статус: **технически проверено, на слух не оценено** — автор сборки звук не слышит; решение принимает владелец после
прослушивания. Остальные звуки игры не тронуты.

## Что было

| звук | чем играл | где запускается | шина | место | повтор и остановка | почему звучит искусственно |
|---|---|---|---|---|---|---|
| скример БАЛОНА | `assets/audio/fn/scream_balon_1..3.wav`, 2,8–3,1 с; синтез `tools/godot-screams.cjs` (формантный «голос», синус 90→35 Гц, шум) | `FNScare._hit` → `FiveNightsRoot.scream("balon")`, в кадр рывка | Horror (ограничитель −1 дБ) → SFX → Master | без места, один проигрыватель | случайный из трёх, подряд не повторяется; доигрывает на экране гибели, обрывается в `clear_transients` (новая ночь, меню) | ровный блок: −14,4 дБ RMS от начала до конца, спектр и громкость не меняются; тембр синтетический |
| переключение камеры | `FNSound._make("cam")`: 0,22 с, 22 кГц; белый шум с затуханием и затухающий синус ≈2,46 кГц | событие `cam` → `sfx2("cam", −12)`; поправка `TRIM` +7 дБ | SFX | без места, свободный из шести проигрывателей | один и тот же при каждом нажатии; быстрые нажатия ложатся друг на друга (до шести слоёв) | шум и тон из генератора, центр спектра 5,3 кГц, каждый раз тот же отсчёт в отсчёт |
| MADK1D в шахте | `FNSound._make("crawl")`: 1,6 с, 22 кГц; четыре одинаковых всплеска шума через 0,385 с, синус 90 Гц и синусы 1340 и 2170 Гц | `FiveNightsRoot._threat_sounds`: пока MADK1D в `duct_*` или `vent_*` | SFX | `AudioStreamPlayer3D` в точке шахты, −12 дБ в шахте и −4 дБ у решётки | не петля, но `if not crawl.playing: crawl.play()` запускает те же 1,6 с снова, пока враг рядом; гаснет за 2 с и останавливается, когда ушёл | метроном 2,6 удара в секунду без единой паузы и без разницы между ударами — отсюда «бесконечный сэмпл» |

Повтор MADK1D — следствие способа воспроизведения, а не только самого звука. Способ остался прежним; новые варианты
обходят его длинными разными дублями с паузами внутри. В ветке P0 (#153, не принята) этот проигрыватель заменён
разовыми событиями — если P0 примут, дубли надо будет нарезать на события той же сборкой (движения в ней уже отдельные).

## Что сделано

Все файлы — `godot/assets/audio/fn/gate/`, сборка — `tools/godot-fn-audio-gate.cjs` (партитура каждого звука записана
там же, по секундам).

**БАЛОН** — баллон со сжатым воздухом, поэтому в обоих вариантах живое горло, воздух под давлением и сталь. Длина 2,9 с:
тряска кадра считается от длины крика (`scream_len * 0.45`), она осталась в прежних пределах.

- `balon_a.wav` — A1 Organic Distortion. Впереди голос: рык с хрипом связок на замедленной ленте (×0,84), под ним второй,
  ниже (×0,667), в начале мокрый горловой спазм; параллельный перегруз; тот же голос, пропущенный через отклик
  захлопнутых железных ворот (свёртка) — «из стального корпуса»; поверх струя сжатого воздуха по алюминию и хлопок шара
  в первый момент. Громче всего в начале, дальше спадает.
- `balon_b.wav` — A2 Physical Impact. Впереди удар: железные ворота захлопываются (×0,79), под ними удар двери машины
  изнутри и выстрел газовой пушки; сразу за ударом выброс сжатого воздуха; листовая сталь падает и дребезжит на 0,44 и
  0,93 с; низ держит раскат грома (ниже 150 Гц); голос слышен только изнутри корпуса и тихо. Спадает быстрее A1.

**Камера** — не длиннее 0,2 с, без тона. У каждого варианта четыре дубля, подряд один и тот же не играет. Вариант играет
одним проигрывателем: при быстрых нажатиях новый щелчок сменяет прежний, слои не копятся.

- `cam_a_1..4.wav` — B1 Analog Relay. Щелчок контакта термостата, сразу за ним клавиша и механизм видеомагнитофона или
  кассетной деки (четыре разных нажатия), низ — тумблер микрофона, на контакте короткая искра сварки (−18 дБ).
- `cam_b_1..4.wav` — B2 Signal Transition. Треск эфира при смене канала на приёмнике (четыре разных места записи,
  0,1 с), в конце тихий щелчок клавиши видеомагнитофона.

**MADK1D** — у каждого варианта три дубля по 10–11 с с паузами до 2 с; когда дубль кончился, игра берёт другой.

- `crawl_a_1..3.ogg` — C1 Heavy Duct Movement. Упор (глухой удар, его низ и контакт с листом), подтягивание (металл
  волокут), упор; иногда сдвигается лист (жестяной шкаф на замедленной ленте). Верх срезан на 3 кГц.
- `crawl_b_1..3.ogg` — C2 Unnatural Crawling. Перебежки из 3–7 мелких касаний с шагом 60–130 мс, замирание, осторожное
  шуршание по стенке, один тихий упор. Суше и ближе, верх до 4,4 кГц.

Оба пропущены через отклик жестяной коробки (свёртка с ударом по шкафу) и короткие отражения 6–31 мс.

## Источники

Все записи — CC0 (общественное достояние); лицензия прочитана на странице каждой записи 2026-11-23/24. Авторство CC0 не
требует, но оно указано. Файлы BigSoundBank — WAV, который отдаёт страница записи без учётной записи; OpenGameArt —
архивы со страниц. Исходники в репозиторий не входят.

| запись | автор | страница | лицензия | куда вошла | что даёт |
|---|---|---|---|---|---|
| Crackling Radio #2 (BigSoundBank #0313) | DenisChardonnet | https://bigsoundbank.com/crackling-radio-2-s0313.html | CC0 (public domain) | cam_b_1..4 | треск эфира |
| Balloon: burst (BigSoundBank #0551) | Joseph SARDIN | https://bigsoundbank.com/balloon-burst-s0551.html | CC0 (public domain) | balon_a | хлопок в первый момент |
| Cassette Player: Cassette (BigSoundBank #0571) | Joseph SARDIN | https://bigsoundbank.com/cassette-player-cassette-s0571.html | CC0 (public domain) | cam_a_1..4, cam_b_1..4 | клавиша кассетной деки |
| Car door (BigSoundBank #0655) | Joseph SARDIN | https://bigsoundbank.com/car-door-s0655.html | CC0 (public domain) | balon_b | низ удара |
| Blow on piece (BigSoundBank #0748) | Joseph SARDIN | https://bigsoundbank.com/blow-on-piece-s0748.html | CC0 (public domain) | balon_a, balon_b | сжатый воздух |
| Metal filing cabinet (BigSoundBank #0773) | Joseph SARDIN | https://bigsoundbank.com/metal-filing-cabinet-s0773.html | CC0 (public domain) | crawl_a_1..3, crawl_b_1..3 | сдвиг листа, упор; отклик жестяной коробки для свёртки |
| Short welds (BigSoundBank #0952) | Joseph SARDIN | https://bigsoundbank.com/short-welds-s0952.html | CC0 (public domain) | cam_a_1..4 | искра на контакте |
| Falling sheet steel bar #3 (BigSoundBank #1773) | Joseph SARDIN | https://bigsoundbank.com/falling-sheet-steel-bar-3-s1773.html | CC0 (public domain) | balon_b | дребезг листовой стали |
| Fall 2 sheet steel bars #2 (BigSoundBank #1777) | Joseph SARDIN | https://bigsoundbank.com/fall-2-sheet-steel-bars-2-s1777.html | CC0 (public domain) | balon_b | дребезг листовой стали |
| Explosion #2 (BigSoundBank #1808) | Joseph SARDIN | https://bigsoundbank.com/explosion-2-s1808.html | CC0 (public domain) | balon_b | низ удара |
| Microphone, switch #1 (BigSoundBank #2026) | Joseph SARDIN | https://bigsoundbank.com/microphone-switch-1-s2026.html | CC0 (public domain) | cam_a_1..4 | низ щелчка |
| Microphone, switch #2 (BigSoundBank #2027) | Joseph SARDIN | https://bigsoundbank.com/microphone-switch-2-s2027.html | CC0 (public domain) | cam_a_1..4 | низ щелчка |
| Microphone, switch #3 (BigSoundBank #2028) | Joseph SARDIN | https://bigsoundbank.com/microphone-switch-3-s2028.html | CC0 (public domain) | cam_a_1..4 | низ щелчка |
| Zombie #2 (BigSoundBank #2107) | Joseph SARDIN | https://bigsoundbank.com/zombie-2-s2107.html | CC0 (public domain) | balon_a | рык, нижний голос |
| Zombie #4 (BigSoundBank #2109) | Joseph SARDIN | https://bigsoundbank.com/zombie-4-s2109.html | CC0 (public domain) | balon_b | долгий рык изнутри корпуса |
| Zombie #5 (BigSoundBank #2110) | Joseph SARDIN | https://bigsoundbank.com/zombie-5-s2110.html | CC0 (public domain) | balon_a | рык, главный голос |
| Zombie #7 (BigSoundBank #2112) | Joseph SARDIN | https://bigsoundbank.com/zombie-7-s2112.html | CC0 (public domain) | balon_a | затухающий рык в конце |
| Thermostat #1 (BigSoundBank #2191) | Joseph SARDIN | https://bigsoundbank.com/thermostat-1-s2191.html | CC0 (public domain) | cam_a_1..4 | щелчок контакта |
| Metal barrier: Closure #3 (BigSoundBank #2360) | Joseph SARDIN | https://bigsoundbank.com/grinding-metal-barrier-closure-3-s2360.html | CC0 (public domain) | balon_a, balon_b | удар железных ворот; он же — отклик корпуса для свёртки |
| Man vomiting #3 (BigSoundBank #2498) | Joseph SARDIN | https://bigsoundbank.com/man-vomiting-3-s2498.html | CC0 (public domain) | balon_a | горловой спазм в начале |
| VHS player (BigSoundBank #2688) | Pierre SIBANARCO | https://bigsoundbank.com/vhs-player-s2688.html | CC0 (public domain) | cam_a_1..4, cam_b_1..4 | клавиши и механизм видеомагнитофона |
| VCR: Cassette Insertion (BigSoundBank #2690) | Pierre SIBANARCO | https://bigsoundbank.com/vcr-cassette-insertion-s2690.html | CC0 (public domain) | cam_a_1..4 | механизм видеомагнитофона |
| Thunder #2 (BigSoundBank #3113) | Joseph SARDIN & Axeline T. | https://bigsoundbank.com/thunder-2-s3113.html | CC0 (public domain) | balon_b | низ хвоста (ниже 150 Гц) |
| 68 Workshop Sounds: «dragging metal» | bart | https://opengameart.org/content/68-workshop-sounds | CC0 | crawl_a_1..3 | волочение |
| 68 Workshop Sounds: «dull hammering» | bart | https://opengameart.org/content/68-workshop-sounds | CC0 | crawl_a_1..3, crawl_b_1..3 | контакт с листом, тихий упор |
| 68 Workshop Sounds: «low hammering» | bart | https://opengameart.org/content/68-workshop-sounds | CC0 | crawl_a_1..3 | глухие удары |
| 68 Workshop Sounds: «lower hammering» | bart | https://opengameart.org/content/68-workshop-sounds | CC0 | crawl_a_1..3 | низ ударов |
| 68 Workshop Sounds: «metal tapping» | bart | https://opengameart.org/content/68-workshop-sounds | CC0 | crawl_b_1..3 | мелкие касания (лента ×0,5) |
| 68 Workshop Sounds: «scrapes» | bart | https://opengameart.org/content/68-workshop-sounds | CC0 | crawl_b_1..3 | шуршание по стенке |

Не использовано, хотя скачивалось: записи с тональным свистом настройки приёмника (BigSoundBank #0310, #0311, #2623 —
это «писки»), записи с клиппингом (#0312, #1490, #0286), пак «100 CC0 metal and wood SFX» (файлы сведены выше 0 дБ).
Freesound не использован: оригиналы там отдаются только после входа.

## Замеры

Автономно (файлы), громкость по EBU R128: M — наибольшая мгновенная (окно 400 мс), I — интегральная.

| файл | длина, с | пик, дБFS | M, LUFS | I, LUFS |
|---|---|---|---|---|
| scream_balon_1.wav (прежний) | 2,8 | −1,0 | −11,2 | −14,4 |
| balon_a.wav | 2,9 | −4,4 | −11,1 | −14,2 |
| balon_b.wav | 2,9 | −1,0 | −11,3 | −15,5 |
| cam (прежний синтез) | 0,22 | −0,3 | −19,2 | — |
| cam_a_1..4.wav | 0,19 | −3,0…−1,5 | −23,0…−21,2 | — |
| cam_b_1..4.wav | 0,20 | −3,8…−1,5 | −21,3…−21,2 | — |
| crawl (прежний, 1,6 с подряд) | — | −2,1 | −20,4 | −22,4 |
| crawl_a_1..3.ogg | 9,9–11,2 | −4,2…−1,5 | −17,9 | −22,9…−22,1 |
| crawl_b_1..3.ogg | 9,8–10,9 | −4,6…−4,0 | −16,4 | −21,7…−20,9 |

- Крик не громче прежнего: та же наибольшая мгновенная громкость, пик не выше −1 дБFS, ограничители шин не тронуты.
- Щелчок камеры на 2 LU тише прежнего при той же громкости вызова (−12 дБ и поправка +7 дБ).
- MADK1D: мгновенная громкость выше прежней на 2,5 LU (C1) и 4 LU (C2), интегральная — та же. Причина — замер в игре:
  при равной мгновенной громкости редкий звук терялся в фоне будки, а его надо слышать, чтобы закрыть заслонку.
- Клиппинга нет: в файлах нет отсчётов выше −1 дБFS.

В игре (запись Movie Maker, уровень по окну 10 мс у решётки, фон будки около −30 дБ): прежний MADK1D — всплески
−13…−16 дБ; C1 — удары −14…−18 дБ; C2 — касания −16…−20 дБ. Щелчок камеры: прежний −17 дБ, B1 −16…−17 дБ, B2 −17…−18 дБ.
Крик в первые 0,25 с: прежний −11 дБ, A1 −12 дБ, A2 −12 дБ.

## Подключение

`FNAudioGate` (`scripts/five_nights/fn_audio_gate.gd`) хранит выбор варианта для трёх звуков; по умолчанию — прежний звук.
В `fn_root.gd` три места: `scream()` берёт вариант вместо прежних записей, событие `cam` играет вариант своим
проигрывателем, `_threat_sounds` перед запуском ставит следующий дубль. Больше ничего: ИИ, маршруты, времена, энергия,
заслонки, `FNScare`, `FNCams` и громкости не менялись. Звук подъёма и опускания планшета (тот же прежний `cam` на другой
высоте) оставлен как был — это отдельная задача P1.

## Как слушать

1. Вне игры: `docs/audio_quality_gate/` — девять WAV (`*_original`, `*_a_*`, `*_b_*`) и три записи из игры
   (`ingame_*.mp4`: подряд ORIGINAL, VARIANT A, VARIANT B в одинаковых условиях).
2. В Godot: открыть `godot/scenes/five_nights/audio_gate.tscn`, нажать F6. Кнопки играют теми же шинами и с той же
   громкостью, что игра. «серия» — восемь быстрых переключений камеры.
3. В игре: в той же сцене кнопка «НОЧЬ В БУДКЕ» — настоящая будка, своя ночь без врагов. F5 / F6 / F7 — вариант БАЛОНА,
   камер, MADK1D; F8 — скример БАЛОНА сейчас; F9 — MADK1D: шахта → решётка → ушёл. Камеры — как в игре: пробел и 1–8.
4. Обычная игра: список «в игре» в той же сцене записывает выбор в `user://fn_audio_gate.json`; ORIGINAL — как было.

Записи из игры сняты так (кадры и звук — из самой игры, звук не подкладывался):
`Godot --path godot --write-movie <файл.avi> --fixed-fps 30 res://scenes/five_nights/audio_gate.tscn -- --clock=30 --fn-gate-capture=balon|cctv|madk1d`

## Чего здесь нет

- Оценки на слух. Проверены длины, уровни, спектр, начало и конец звука, остановка, синхронность с кадром.
- В шахте (до решётки, −12 дБ) и прежний звук, и оба варианта почти тонут в фоне будки. Это громкость воспроизведения,
  её правит P0; здесь она не менялась.
- На экране гибели сразу после крика играют прежние помехи и аккорд (`static` −2 дБ, `sting_lose` −4 дБ): они громче
  хвоста любого из трёх криков. Не менялось.
- Крик `dark` (БАЛОН в темноте) и крики остальных — прежние.
