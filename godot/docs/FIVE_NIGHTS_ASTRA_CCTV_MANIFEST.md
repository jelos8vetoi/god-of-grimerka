# ОБЛАКО · интерьеры камер 1, 2, 3, 6 и 8

База сравнения — 1d859cc, ветка второго этапа. [Инструкция по интеграции](FIVE_NIGHTS_ASTRA_CCTV_HANDOFF.md) · [Источники новых моделей](../assets/fn_curated/phase3/licenses/CREDITS.md).

Общая сцена — [cctv_environment_showcase.tscn](../scenes/fn_curated/phase3/cctv_environment_showcase.tscn). Загрузчик держит в дереве одну художественную комнату. В режиме CCTV используется FNCams с собственным SubViewport 480 × 270 и штатным окружением камеры. Кадры 1280 × 720 получены из Godot 4.7.2 Forward+, Vulkan, Radeon RX 7800 XT.

| CAM | Помещение, X × Y × Z (м) | Узлы¹ | Меши | Материалы² | Свет | Треугольники² |
|---|---|---:|---:|---:|---:|---:|
| 1 | stage · 14 × 4.2 × 12 | 94 | 54 | 13 | 4 | 257362 |
| 2 | arcade · 12 × 3.4 × 10 | 78 | 41 | 21 | 5 | 188579 |
| 3 | storage · 10 × 3.2 × 9 | 99 | 59 | 13 | 3 | 253212 |
| 6 | server · 10 × 3 × 9 | 128 | 66 | 16 | 3 | 46924 |
| 8 | power · 9 × 3 × 8 | 114 | 66 | 14 | 3 | 206415 |

¹ Потомки RoomRoot без актёра и интерфейса. ² Разные активные ресурсы материалов на поверхностях MeshInstance3D и сумма геометрии верхнего LOD по экземплярам. Надписи, отсечение, теневые проходы и автоматический LOD меняют фактический объём работы GPU. Это не измерение FPS. Габариты взяты из аргументов FNFacility._shell.

## Кадры и привязки

Исходные кадры сняты до сборки предложений вызовом пяти оригинальных построителей FNFacility с настоящим FNOffice и окружением камеры планшета, без шума интерфейса. Для каждого предложения сохранены дневной и ночной обзор с пустой комнатой и ночной CCTV-кадр с противником в Pose0. Числа в маркерах ниже — локальные X, Y, Z и yaw в радианах. Камера указана в виде «позиция → цель».

### CAM 1 · stage

[Сцена](../scenes/fn_curated/phase3/cam1_stage_proposal.tscn) · [До](../assets/fn_curated/phase3/previews/stage_before.jpg) · [Обычный свет](../assets/fn_curated/phase3/previews/stage_normal.jpg) · [Ночной свет](../assets/fn_curated/phase3/previews/stage_night.jpg) · [CCTV + IR](../assets/fn_curated/phase3/previews/stage_cctv.jpg)

- Начало FNFacility (60,0,0). Камера (6.4,3.9,5.4) → (-0.5,1,-3), FOV 64°, sway 7°.
- Позы 0 (0,0.9,-4.3,0), 1 (-2.2,0.9,-4.6,0.3), 2 (1.8,0,2.2,-0.6). Figure (-6.2,0,-5.2,0.6).
- Модели: `assets/fn_curated/phase3/models/painted_wooden_chair_01/painted_wooden_chair_01.gltf`, `assets/minigames/fn_stage_speaker.glb`, `assets/minigames/fn_party_table.glb`, `assets/fn_curated/models/vintage_radio_transceiver/vintage_radio_transceiver.gltf`, `assets/fn_curated/models/metal_toolbox/metal_toolbox.gltf`, `assets/fn_curated/phase2/models/service_door.glb`, `assets/fn_curated/models/hanging_industrial_lamp/hanging_industrial_lamp.gltf`.
- Отделка: wood, chalk, lime, oxblood, chalk.

### CAM 2 · arcade

[Сцена](../scenes/fn_curated/phase3/cam2_arcade_proposal.tscn) · [До](../assets/fn_curated/phase3/previews/arcade_before.jpg) · [Обычный свет](../assets/fn_curated/phase3/previews/arcade_normal.jpg) · [Ночной свет](../assets/fn_curated/phase3/previews/arcade_night.jpg) · [CCTV + IR](../assets/fn_curated/phase3/previews/arcade_cctv.jpg)

- Начало FNFacility (85,0,0). Камера (-5.5,3.1,4.4) → (0.5,0.9,-1), FOV 66°, sway 6°.
- Позы 0 (-1.6,0,-1,0.6), 1 (0.8,0,3,2.6), 2 (3.6,0,-0.6,-1.4). Figure (-5.4,0,-4.2,0.5).
- Модели: `assets/fn_curated/phase3/models/painted_wooden_chair_01/painted_wooden_chair_01.gltf`, `assets/fn_curated/phase3/models/cardboard_box_01/cardboard_box_01.gltf`, `assets/minigames/fn_arcade_cabinet.glb`, `assets/fn_curated/phase2/models/arcade.glb`, `assets/minigames/fn_prize_counter.glb`, `assets/fn_curated/models/utility_box_01/utility_box_01.gltf`, `assets/fn_curated/phase2/models/service_door.glb`, `assets/fn_curated/models/hanging_industrial_lamp/hanging_industrial_lamp.gltf`.
- Отделка: lino, chalk, slate.

### CAM 3 · storage

[Сцена](../scenes/fn_curated/phase3/cam3_storage_proposal.tscn) · [До](../assets/fn_curated/phase3/previews/storage_before.jpg) · [Обычный свет](../assets/fn_curated/phase3/previews/storage_normal.jpg) · [Ночной свет](../assets/fn_curated/phase3/previews/storage_night.jpg) · [CCTV + IR](../assets/fn_curated/phase3/previews/storage_cctv.jpg)

- Начало FNFacility (110,0,0). Камера (4.4,2.9,4) → (-1,0.8,-1.5), FOV 64°, sway 5°.
- Позы 0 (-1.5,0,0.5,0.8), 1 (1,0,-2.6,0.2), 2 (-3,0,2.4,1.6). Figure (-4.4,0,3.6,2.2). Дополнительно ghost_storage (2.6, 0, −2.9, 0.6).
- Модели: `assets/minigames/fn_mascot_shelf.glb`, `assets/fn_curated/models/drawer_cabinet/drawer_cabinet.gltf`, `assets/fn_curated/phase3/models/cardboard_box_01/cardboard_box_01.gltf`, `assets/fn_curated/models/metal_office_desk/metal_office_desk.gltf`, `assets/fn_curated/models/metal_toolbox/metal_toolbox.gltf`, `assets/fn_curated/models/utility_box_01/utility_box_01.gltf`, `assets/fn_curated/phase2/models/service_door.glb`, `assets/fn_curated/models/hanging_industrial_lamp/hanging_industrial_lamp.gltf`.
- Отделка: concrete, chalk, lime, jade, chalk.

### CAM 6 · server

[Сцена](../scenes/fn_curated/phase3/cam6_server_proposal.tscn) · [До](../assets/fn_curated/phase3/previews/server_before.jpg) · [Обычный свет](../assets/fn_curated/phase3/previews/server_normal.jpg) · [Ночной свет](../assets/fn_curated/phase3/previews/server_night.jpg) · [CCTV + IR](../assets/fn_curated/phase3/previews/server_cctv.jpg)

- Начало FNFacility (135,0,0). Камера (4.4,2.7,3.8) → (-1,0.9,-0.5), FOV 64°, sway 5°.
- Позы 0 (0,0,0,-0.9), 1 (-2,0,0,0.5), 2 (2,0,3.2,2.8). Figure (-4.3,0,3.8,2.4).
- Модели: `assets/fn_curated/phase2/models/rack_console.glb`, `assets/fn_curated/models/metal_office_desk/metal_office_desk.gltf`, `assets/fn_curated/phase3/models/painted_wooden_chair_01/painted_wooden_chair_01.gltf`, `assets/fn_curated/phase2/models/wiring/cable_straight_long.gltf`, `assets/fn_curated/models/television_02/television_02.gltf`, `assets/fn_curated/models/utility_box_01/utility_box_01.gltf`, `assets/fn_curated/phase2/models/ducts/straight.gltf`, `assets/fn_curated/phase2/models/ducts/flange_thin.gltf`, `assets/fn_curated/models/hanging_industrial_lamp/hanging_industrial_lamp.gltf`.
- Отделка: rubber, chalk, slate.

### CAM 8 · power

[Сцена](../scenes/fn_curated/phase3/cam8_power_proposal.tscn) · [До](../assets/fn_curated/phase3/previews/power_before.jpg) · [Обычный свет](../assets/fn_curated/phase3/previews/power_normal.jpg) · [Ночной свет](../assets/fn_curated/phase3/previews/power_night.jpg) · [CCTV + IR](../assets/fn_curated/phase3/previews/power_cctv.jpg)

- Начало FNFacility (185,0,0). Камера (3.8,2.7,3.4) → (-0.5,0.9,-1.5), FOV 64°, sway 5°.
- Позы 0 (0.2,0,-1.2,0.3), 1 (-1.4,0,1,0.9), 2 (2.5,0,0.6,-0.6). Figure (4,0,-3.4,-0.6).
- Модели: `assets/minigames/fn_generator.glb`, `assets/fn_curated/models/utility_box_01/utility_box_01.gltf`, `assets/fn_curated/models/power_box_01/power_box_01.gltf`, `assets/fn_curated/phase2/models/wiring/cable_straight_long.gltf`, `assets/fn_curated/phase3/models/cardboard_box_01/cardboard_box_01.gltf`, `assets/fn_curated/models/metal_office_desk/metal_office_desk.gltf`, `assets/fn_curated/models/metal_toolbox/metal_toolbox.gltf`, `assets/fn_curated/phase2/models/pipes/pipe01.gltf`, `assets/fn_curated/phase2/models/metal_door.glb`, `assets/fn_curated/models/hanging_industrial_lamp/hanging_industrial_lamp.gltf`.
- Отделка: paint, chalk, jade.

## Источники и техническая подготовка

Добавлены два glTF с UV, нормалями и картами albedo, normal OpenGL и ARM размером 1K. Остальные модели загружаются из библиотеки Astra и игровых путей. Новые .tres в finishes используют карты первого этапа с мировым трипланарным масштабом. Светящиеся дисплеи используют существующий шейдер booth_crt.

| Новый ресурс | Автор | Треугольники | Размер с зависимостями |
|---|---|---:|---:|
| [Painted Wooden Chair 01](https://polyhaven.com/a/painted_wooden_chair_01) · CC0 | Kuutti Siitonen | 724 | 492550 Б |
| [Cardboard Box 01](https://polyhaven.com/a/cardboard_box_01) · CC0 | Rahul Chaudhary | 5594 | 1916732 Б |

У коробки уменьшена сетка с 16 952 до 5 594 треугольников. Несколько экземпляров переиспользуют один меш и те же карты. На складе оставлены два исходных стеллажа с маскотами, между ними размещена картотека. Для серверной выбран облегчённый комплект второго этапа.

Лицензии переиспользованных открытых ресурсов указаны в [таблице первого этапа](../assets/fn_curated/licenses/CREDITS.md) и [таблице второго этапа](../assets/fn_curated/phase2/licenses/CREDITS.md). Права на существующие игровые файлы остаются в рамках проекта.

## Проверки

Сверены позиции, направления взгляда, FOV и sway всех камер, пять Figure и 16 мировых преобразований поз относительно экземпляра исходного FNFacility. Расхождений в пределах точности Godot не обнаружено. Каждый интерьер загружен и снят повторно после правок. Для проверки использованы штатные риги BALON, CLIPPER, BOT, MOD и отдельная позиция GHOST. Поворот камеры, реакция на действия игрока и полный игровой цикл относятся к интеграционной проверке.
