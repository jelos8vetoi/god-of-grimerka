# Итоговый отчёт: переработка игрового процесса и подачи — 2026-11-20

Четыре направления: «5 ночей с Паханом», трасса «КРЫШИ ТОМСКА», подработки «Микрозаймов», главное меню
«ОБЛАКО-ТВ». Кампания, бой, обучение, сюжетное сохранение и физика ТЯГИ-812 в кампании не трогались.

**Как проверялось и чего нельзя утверждать.** Игра запускалась из меню, ввод — настоящие события клавиш и мыши,
снимки просмотрены глазами. Руками в реальном времени не играл ни человек, ни помощник: гонки вёл скрипт-водитель,
подработки — встроенный бот. Оценка «весело или нет» — за человеком.

## 1. Pull Request'ы

| PR | Что |
|---|---|
| [#86](https://github.com/jelos8vetoi/god-of-grimerka/pull/86) | 5 ночей: крики, мёртвая тишина, привычки игрока, будка по ночам, события часов |
| [#87](https://github.com/jelos8vetoi/god-of-grimerka/pull/87) | Гонки: «КРЫШИ ТОМСКА», зимний облик, видимое полотно дороги |
| [#88](https://github.com/jelos8vetoi/god-of-grimerka/pull/88) | Микрозаймы: вторая механика в каждой подработке |
| [#89](https://github.com/jelos8vetoi/god-of-grimerka/pull/89) | Главное меню: телестудия «ОБЛАКО-ТВ» |

## 2. Что изменилось для игрока

**5 ночей с Паханом**
- У каждого из восьми скримеров свой крик в трёх вариантах; начало крика совпадает с кадром удара.
- Мёртвая тишина перед частью скримеров (0,15–0,35 с): всё, только фон, только звуки будки или без тишины.
- Отдельная настройка громкости скримеров.
- Обитатели подстраиваются под привычки: Балон идёт стороной, где дверь закрывают реже; MADK1D — шахтой, чью
  заслонку трогают реже; CLIPPER не даёт держать себя камерой дольше 9 с; GHOST приходит в угол будки, если
  избегать его камер; MOD морозит камеру, с которой не сводят глаз.
- Будка меняется по ночам (зарубки, царапины, бумаги, тревожная лампа с четвёртой ночи); события в 2, 3, 4 и 5 AM.

**Гонки**
- Трасса «КРЫШИ ТОМСКА», круг 921 м: проспект → дворы и гаражи → подъём по лесам → три крыши с двумя прыжками
  через провалы → спуск.
- Свой облик: зимний вечер, снег, сугробы, снегопад, тёплые фонари; метель вместо пыльной бури.
- 12 томских достопримечательностей и 18 щитов с местными шутками.
- На всех трассах появились асфальт, обочины, бордюры и разметка.

**Микрозаймы — подработки**
- Уборка: пятна и две насадки (щётка / мойка). Ремонт: пыльные детали и продувка. Доставка: свободный порядок и
  срочные посылки с чаевыми. Хлам: тайники и «потрясти». Звукарь: бит из четырёх фраз и серия попаданий.

**Главное меню**
- 3D-телестудия: пять кинескопных телевизоров — пункты меню, у каждого свой канал; вывеска, табло «В ЭФИРЕ»,
  камера, софиты, Пахан перед экранами. Мышь нажимает на экран телевизора.

## 3. Новые механики (где в коде)

| Механика | Код |
|---|---|
| Привычки игрока и адаптация врагов | `FNNight.hab` / `habit()` / `cam_share()` / `top_cam()`, событие `adapt` |
| Мёртвая тишина | `FNScare.HUSH`, `root.hush_begin` / `hush_end`, `audio.hush(amb, mus)` |
| Будка по ночам, события часов | `FNOffice.dress(n)`, `root._hour_event(h)` |
| Высота трассы, провалы, возврат с разбегом | `RaceTrack`: 4-е число точки, `gaps`, `road_y`, `in_gap`, `ramp_near` |
| Зимний облик трассы | `look["winter"]`, `RaceTrack.winter()`, `_snowfall`, `_street_lights` |
| Пятна и насадки | `MLJobPodezd.wash`, `set_nozzle()`, `_wash()` |
| Пыль и продувка | `MLJobRepair.blow()`, `comps[..]["dust"]` |
| Свободный маршрут, срочные | `MLJobDeliv._pick()`, `due`, `tips` |
| Тайники | `MLJobJunk.shake()`, `stash` |
| Фразы бита | `MLJobSound.PHRASES`, `streak` |
| Телевизоры-пункты меню | `MenuStudio` (`menu_studio.gd`): `select`, `flash`, `screen_rect` |

## 4. Модели

Кредитов Tripo — 70 при цене 30 и запасе 40, поэтому **ни одна модель не сгенерирована**. Всё новое собрано кодом
из простых деталей; файл с нужным именем подхватится сам.

| Что | Как сделано сейчас | Файл, который заменит |
|---|---|---|
| 12 достопримечательностей Томска | сборка кодом (`race_tomsk.gd`) | `assets/racing/tomsk_<вид>.glb` |
| Дома под крышами, леса, щиты | сборка кодом (`RaceTrack._decks`, `_signs`) | — |
| Телевизоры, камера, софиты студии | сборка кодом (`menu_studio.gd`) | — (подхват не сделан) |
| Пятна, пыль, столбы-метки | сборка кодом | — |

Из готовых моделей владельца в студии меню стоят колонка, старый телевизор и усилитель.

## 5. Звуки

- 24 файла криков `assets/audio/fn/scream_<кто>_<1..3>.wav` — синтез `tools/godot-screams.cjs` (удар, формантный
  голос, низ, искажение, эхо; пик −1 дБ). Сторонних записей нет.
- Замеры: синхронизация крика с кадром 3–4 мс, пики шины `Horror` −1,7…−5,7 дБ, тишина 168–361 мс, фон
  возвращается.
- Новых звуков у подработок, трассы и меню нет — используются существующие наборы.

## 6. Найденные и исправленные баги

| Где | Баг | Статус |
|---|---|---|
| Гонки, все трассы | полотно дороги не рисовалось: треугольники изнанкой вверх | исправлено |
| Гонки | уклон дороги засчитывался как трамплин (29 ложных «трюков» за заезд) | исправлено |
| Гонки | крыша закрывала разметку и бордюры | исправлено |
| 5 ночей | лицо Балона уходило из кадра во время крика | исправлено |
| 5 ночей | пульт оставался на экране во время скримера | исправлено |
| 5 ночей | проверка честности считала 24 прогона — порог 95 % решал случай | 72 прогона |
| Уборка | бот кружил над пятном и мотал шланг | исправлено |

## 7. Проверки (последние прогоны)

| Проверка | Итог |
|---|---|
| `--fivenightscheck` | 152 пункта, ошибок 0 |
| `--playtest-race --pt-track=tomsk_roofs` (4 заезда) | 3 круга = 2 780 м, 112–128 с, падений в провалы нет |
| `--racecheck` | 97 пунктов, ошибок 0 |
| `--weathercheck`, `--race-netcheck` | ok |
| `--microloanscheck` | ошибок 0 |
| `--uicheck` (`fn`, `jobs`) | замечаний 0 |
| `--modecheck`, `--uiqa`, `--soundcheck` | ok |

Честность ночей: «безупречный» игрок в симуляции — 100 / 100 / 100 / 98 / 95 % на ночах 1–5; на 150 прогонах —
97–99 % и с адаптацией, и без неё.

## 8. Что осталось — не сделано

1. **5 ночей:** свой визуальный характер у каждой камеры, новые постановки скримеров, проход по позиционному
   звуку, уникальные концовки ночей, доработка Night 6 и Custom Night.
2. **Гонки:** своих динамических событий у «Крыш Томска» нет; достопримечательности — простые формы; соперники
   на этой трассе слабее игрока на обычном уровне (отрыв 6–17 с); полировка старых трасс не делалась.
3. **Микрозаймы:** новых подработок нет; оплата и прокачка не менялись («прогресс должен ощущаться» не закрыт);
   аккуратный бот в уборке по-прежнему путает шланг 4–8 раз за заказ.
4. **Меню:** экран выбора режима остался в прежнем чёрно-белом стиле; превью режимов на экранах телевизоров нет.
5. **Модели:** ничего не сгенерировано (раздел 9).
6. **Плейтест человеком** — не проводился ни по одному направлению.

## 9. Модели для Tripo (сгенерировать, когда будут кредиты)

Режим — text-to-model, один предмет на промпт, английский, до 1000 символов. Общий стиль в конце каждого:
`stylized low-poly game asset, hand-painted textures, single object, centered, no ground plane, no text`.

| Файл | Промпт |
|---|---|
| `racing/tomsk_wooden_tent.glb` | Two-storey Siberian wooden merchant house, dark log walls, tall pointed tent-shaped corner tower with spire, carved white window frames, snow on the roof |
| `racing/tomsk_wooden_dragons.glb` | Two-storey Siberian wooden house, dark timber, blue-green pediments, carved dragon heads on the roof brackets, corner turret with sharp spire, snow on the roof |
| `racing/tomsk_wooden_firebirds.glb` | Ornate Siberian wooden mansion, carved firebird ornaments on the gables, lace-like white fretwork, small balcony, snow on the roof |
| `racing/tomsk_tsu.glb` | Classical white university main building, two storeys, central portico with columns and pediment, long symmetrical wings, green roof with snow |
| `racing/tomsk_kalancha.glb` | Old red-brick fire watchtower with observation gallery on top, attached two-storey fire station with arched gates |
| `racing/tomsk_tv_tower.glb` | Tall steel lattice television tower, red and white painted sections, antennas on top |
| `racing/tomsk_gres.glb` | Soviet power station, boxy industrial hall, two tall red-and-white striped chimneys |
| `racing/tomsk_chekhov.glb` | Humorous bronze statue of a barefoot man in a long coat, crooked hat and round glasses, on a low stone base |
| `racing/tomsk_ruble.glb` | Giant wooden one-ruble coin monument standing on its edge on a small pedestal, carved wood grain |
| `racing/tomsk_paz.glb` | Small old Soviet city bus, rounded body, white with blue stripe, dirty, snow on the roof |
| `racing/tomsk_tram.glb` | Old Soviet tram car, red and cream paint, pantograph on the roof, worn and rusty |
| `racing/tomsk_bridge.glb` | Long concrete road bridge segment with arches and street lamps along the railing |
| `minigames/menu_crt_tv.glb` | Bulky 1980s CRT television, beige plastic body, curved dark glass screen, two round knobs, rabbit-ear antenna |
| `minigames/menu_studio_camera.glb` | Vintage broadcast studio camera on a wheeled tripod, big lens hood, viewfinder box, red tally lamp |
| `minigames/menu_spotlight.glb` | Studio fresnel spotlight on a tall stand, barn doors, black metal, cable hanging down |
| `minigames/ml_job_stain_set.glb` | Set of three flat floor dirt stains: mud, spilled oil, dried paint, irregular shapes, very thin |

Уже готовый каталог из 30 промптов по геймплею — `TRIPO_PROMPTS_GAMEPLAY.md`.

## 10. Снимки

Снимки делаются проверками во временную папку (в репозиторий не кладутся). Владельцу отправлены: зимняя трасса
(кадр из заезда и вид на проспект) и новое главное меню. Повторить: `--playtest-race=<папка> --pt-track=tomsk_roofs`,
`--modecheck=<папка>`, `--fivenightscheck=<папка>`, `--microloanscheck=<папка>`.
