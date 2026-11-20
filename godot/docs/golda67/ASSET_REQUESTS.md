# ГОЛДА 67 — запросы на модели

Все 3D-модели генерирует владелец. Здесь — готовые промпты и статус каждой модели. Полный список с назначением
и приоритетами — `ASSET_MANIFEST.md`; стиль — `ART_DIRECTION.md`.

**Статусы:** требуется → промпт выдан → генерируется → получена → интегрирована.
Статус «получена» ставится только после того, как владелец сообщил, что файл лежит в проекте.

## Как пользоваться

- Один промпт — одна модель. Блок копируется целиком: стиль уже внутри. Каждый промпт **не длиннее 1000
  символов** с пробелами; фактическая длина указана в заголовке блока и посчитана скриптом.
- Скачивать в **GLB** и класть под указанным именем в `godot/assets/golda67/` (папку создать). Если удобнее
  прислать файлы из «Загрузок» как есть — тоже подойдёт, переименую и облегчу сам (`glbslim.gd`).
- Негативный промпт (если есть поле): `photorealistic, photo scan, blurry, noisy mesh, readable text, letters, logos, brand names, watermark, multiple separate objects, floor plane, background scenery`.
- **Персонажи — T-поза, без авторига.** Скелет ставится скриптом `tools/rig-horror.py`.
- Надписей на моделях нет намеренно: цифры «67», цены, названия и плакаты накладываются в игре.
- Ориентация: лицом по +Z; файлы с сайта обычно приходят лицом по +X — это учитывается в коде.
- Масштаб не важен: размер задаётся в игре по габаритам из описания.
- Режим Tripo: персонажи и боссы — Text to 3D, HD model; пропсы и модули — standard.

## Порядок партий

| Партия | Что | Моделей | Статус |
|---|---|---|---|
| **P0** | хаб, район ДВОР, Миша Минасян, КРОТ, dj flürr, базовые враги, двери и награды, ведущий новостей и его стол | 22 | **все 22 модели получены 2026-11-20; одна требует замены (см. «Приёмка P0»)** |
| P1 | боссы 2–4, враги трёх районов, животные, ПОДЗЕМКА, ЛЕНТА, БОТОФЕРМА, события первой линии | 50 | требуется (промпты — после ответа владельца по P0) |
| P2 | WHYOUSOLONELY, ИЗНАНКА, СТУДИЯ, Mogging Challenge, Anime Room | 20 | требуется |
| P3 | декор | 8 | требуется |

## Партия P0 — вертикальный срез (20 моделей)

Максимальная длина промпта в партии — 981 символов (предел 1000). Длина считается скриптом по полному тексту блока, со стилем и пробелами.

| № | id | Модель | Файл | Длина | Статус |
|---|---|---|---|---|---|
| 1 | G67-C01 | Миша Минасян | `godot/assets/golda67/g67_misha.glb` | 978 | получена |
| 2 | G67-C02 | КРОТ | `godot/assets/golda67/g67_krot.glb` | 981 | получена |
| 3 | G67-C03 | dj flürr | `godot/assets/golda67/g67_dj_flurr.glb` | 979 | получена |
| 4 | G67-C04 | Шестёрка | `godot/assets/golda67/g67_enemy_shestyorka.glb` | 915 | получена |
| 5 | G67-C05 | Семечник | `godot/assets/golda67/g67_enemy_semechnik.glb` | 933 | получена |
| 6 | G67-C06 | Смотрящий | `godot/assets/golda67/g67_enemy_smotryashchiy.glb` | 904 | получена (вторая модель), скелет стоит |
| 7 | G67-H01 | Стойка выбора стилей | `godot/assets/golda67/g67_style_rack.glb` | 858 | получена |
| 8 | G67-H02 | Сервант для артефактов | `godot/assets/golda67/g67_artifact_cabinet.glb` | 813 | получена |
| 9 | G67-H03 | Карта маршрутов | `godot/assets/golda67/g67_route_board.glb` | 855 | получена |
| 10 | G67-H04 | Почтовые ящики | `godot/assets/golda67/g67_mailboxes.glb` | 755 | получена |
| 11 | G67-H05 | Доска объявлений | `godot/assets/golda67/g67_notice_board.glb` | 750 | получена |
| 12 | G67-H06 | Скрытая дверь «колясочная» | `godot/assets/golda67/g67_service_door.glb` | 812 | получена |
| 13 | G67-E01 | Стена подъезда (модуль) | `godot/assets/golda67/g67_podezd_wall.glb` | 855 | получена |
| 14 | G67-E02 | Лестничный марш (модуль) | `godot/assets/golda67/g67_stair_flight.glb` | 754 | получена |
| 15 | G67-E05 | Дверь выбора комнаты | `godot/assets/golda67/g67_room_gate.glb` | 865 | получена |
| 16 | G67-E06 | Турник и брусья | `godot/assets/golda67/g67_workout_bars.glb` | 782 | получена |
| 17 | G67-E07 | Стенд турнирного плаката | `godot/assets/golda67/g67_poster_stand.glb` | 807 | получена |
| 18 | G67-E09 | Вход в подъезд | `godot/assets/golda67/g67_podezd_entrance.glb` | 859 | получена |
| 19 | G67-I01 | Монета голды | `godot/assets/golda67/g67_golda_coin.glb` | 715 | получена |
| 20 | G67-I02 | Фитс (вешалка-награда) | `godot/assets/golda67/g67_fit_hanger.glb` | 780 | получена |

### 1. G67-C01 — Миша Минасян

- **Назначение:** Босс района ДВОР; ролики V00, AD01, CL01, NEWS01, STORY03; сидит на лавке после поражения.
- **Поза / ракурс:** T-поза, вид спереди, в полный рост. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Гуманоид: T-поза, без авторига. Скелет Mixamo поставлю сам (`tools/rig-horror.py`, шаблон `pahan`). Клипы — кодом. Уникальные клипы: проход «авторитет», зацеп цепи, захват, контратака.
- **Имя файла:** `g67_misha.glb`
- **Путь:** `godot/assets/golda67/g67_misha.glb`
- **Статус:** получена 2026-11-20
- **Промпт (978 символов):**

```text
Mikhail, a vain local courtyard boss in his thirties, stocky and broad-shouldered with a proud chest. Burgundy tracksuit with three white stripes on sleeves and trousers, jacket zipped halfway over a white tank top, a thick heavy gold chain hanging on the chest as the main silhouette detail, gold watch, gold signet ring, oversized expensive snow-white chunky sneakers. Short black hair with a sharp fade, thick black eyebrows, short trimmed black beard, smug confident face, dark sunglasses pushed up on the forehead. The chain ends above the belt and does not touch the arms. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold readable silhouette, hand-painted textures, muted post-soviet colours with one bright accent. Full body, strict T-pose, arms straight out to the sides, legs apart, fingers simplified, clothes not fused to arms or between legs, clean topology at joints, no rig. Single character, centered, no ground, no background.
```

### 2. G67-C02 — КРОТ

- **Назначение:** Повторяющийся секретный персонаж: десять встреч, ролик EXTRA01. Не враг.
- **Поза / ракурс:** T-поза, вид спереди, в полный рост. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Гуманоид: T-поза, без авторига. Скелет Mixamo поставлю сам (`tools/rig-horror.py`, шаблон `pahan`). Клипы — кодом. Клипы: стоит с люстрой, кормит голубей, петля «NPC», сидит на полу, кивок.
- **Имя файла:** `g67_krot.glb`
- **Путь:** `godot/assets/golda67/g67_krot.glb`
- **Статус:** получена 2026-11-20
- **Промпт (981 символов):**

```text
A strange short stocky man nicknamed Mole, absolutely serious deadpan face. Round pudgy body, very short legs, slightly hunched. Old brown quilted work jacket (vatnik) buttoned up, dark grey knitted beanie pulled low, tiny round pitch-black welder glasses hiding the eyes, big pink nose, grey stubble, thick dark mittens that make the hands look like digging paws, baggy grey trousers tucked into heavy felt boots with rubber galoshes. A crumpled plastic bag handle sticking out of one pocket. Earthy brown and grey colours, one small yellow button as accent. Human, not an animal. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold readable silhouette, hand-painted textures, muted post-soviet colours with one bright accent. Full body, strict T-pose, arms straight out to the sides, legs apart, fingers simplified, clothes not fused to arms or between legs, clean topology at joints, no rig. Single character, centered, no ground, no background.
```

### 3. G67-C03 — dj flürr

- **Назначение:** Персонаж хаба: сидит на лавочке у подъезда, рассказывает истории и даёт советы.
- **Поза / ракурс:** T-поза, вид спереди, в полный рост (в игре сидит — позу сделаю клипом). Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Гуманоид: T-поза, без авторига. Скелет Mixamo поставлю сам (`tools/rig-horror.py`, шаблон `pahan`). Клипы — кодом. Клипы: сидит на лавке, жест «слушай сюда», наливает из термоса.
- **Имя файла:** `g67_dj_flurr.glb`
- **Путь:** `godot/assets/golda67/g67_dj_flurr.glb`
- **Статус:** получена 2026-11-20
- **Промпт (979 символов):**

```text
A tall thin eccentric street storyteller of unclear age. Long faded turquoise wool coat down to the knees, open, worn over a dark blue tracksuit; old brown fur ushanka hat with ear flaps tied on top; round yellow-tinted glasses; a long thin moustache; huge vintage headphones around the neck with only one ear cup, the other side is a bare wire; fingerless gloves; pointed old leather shoes. A small cassette tape hanging on a string as a pendant. Relaxed knowing smile. The coat hem is split at the back and does not join between the legs. Turquoise is the single bright accent. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold readable silhouette, hand-painted textures, muted post-soviet colours with one bright accent. Full body, strict T-pose, arms straight out to the sides, legs apart, fingers simplified, clothes not fused to arms or between legs, clean topology at joints, no rig. Single character, centered, no ground, no background.
```

### 4. G67-C04 — Шестёрка

- **Назначение:** Обычный враг района ДВОР (ближний бой), свита Миши Минасяна.
- **Поза / ракурс:** T-поза, вид спереди. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Гуманоид: T-поза, без авторига. Скелет Mixamo поставлю сам (`tools/rig-horror.py`, шаблон `pahan`). Клипы — кодом. Использует общие клипы врагов.
- **Имя файла:** `g67_enemy_shestyorka.glb`
- **Путь:** `godot/assets/golda67/g67_enemy_shestyorka.glb`
- **Статус:** получена 2026-11-20
- **Промпт (915 символов):**

```text
A skinny young courtyard thug, a boss henchman. Black tracksuit with three white stripes, jacket zipped to the chin, flat black cap pulled low over the eyes, sharp cheekbones, shaved head under the cap, mean squint, a sunflower seed husk stuck on the lower lip. Hands bare with scraped knuckles. Worn black sneakers with white soles, white socks pulled over the trouser cuffs. A small burgundy armband on the left sleeve as the only colour accent, marking the gang. Narrow shoulders, long neck, slightly bent knees. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold readable silhouette, hand-painted textures, muted post-soviet colours with one bright accent. Full body, strict T-pose, arms straight out to the sides, legs apart, fingers simplified, clothes not fused to arms or between legs, clean topology at joints, no rig. Single character, centered, no ground, no background.
```

### 5. G67-C05 — Семечник

- **Назначение:** Обычный враг района ДВОР (дальний бой: плюётся шелухой, держит дистанцию).
- **Поза / ракурс:** T-поза, вид спереди. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Гуманоид: T-поза, без авторига. Скелет Mixamo поставлю сам (`tools/rig-horror.py`, шаблон `pahan`). Клипы — кодом. Использует общие клипы врагов (стрелок).
- **Имя файла:** `g67_enemy_semechnik.glb`
- **Путь:** `godot/assets/golda67/g67_enemy_semechnik.glb`
- **Статус:** получена 2026-11-20
- **Промпт (933 символов):**

```text
A chubby lazy courtyard guy who spits sunflower seeds at enemies. Puffy grey down jacket unzipped over a striped navy sailor shirt, loose blue track pants with white side stripes, black rubber slippers worn over thick wool socks. Round face with puffed cheeks full of seeds, small eyes, a short buzz cut, a knitted burgundy beanie perched on top of the head. A big paper cone bag of sunflower seeds strapped to the belt on the right hip, seeds visible on top. Round belly, short thick legs. Burgundy beanie is the only bright accent. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold readable silhouette, hand-painted textures, muted post-soviet colours with one bright accent. Full body, strict T-pose, arms straight out to the sides, legs apart, fingers simplified, clothes not fused to arms or between legs, clean topology at joints, no rig. Single character, centered, no ground, no background.
```

### 6. G67-C06 — Смотрящий

- **Назначение:** Элитный враг района ДВОР: медленный, тяжёлые удары по площади, захват.
- **Поза / ракурс:** T-поза, вид спереди. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Гуманоид: T-поза, без авторига. Скелет Mixamo поставлю сам (`tools/rig-horror.py`, шаблон `pahan`). Клипы — кодом. Общие клипы тяжёлого врага + захват.
- **Имя файла:** `g67_enemy_smotryashchiy.glb`
- **Путь:** `godot/assets/golda67/g67_enemy_smotryashchiy.glb`
- **Статус:** получена 2026-11-20
- **Промпт (904 символов):**

```text
A huge heavy courtyard enforcer, twice as wide as a normal man. Enormous shoulders and arms, small head, no neck. Tight burgundy tracksuit jacket that barely closes over a barrel chest, black track pants, a thin gold chain, a black leather flat cap, broken flat nose, heavy jaw, tiny angry eyes, cauliflower ears. Giant fists wrapped in dirty white hand wraps. Heavy black boots. A whistle on a cord around the neck. Massive top-heavy triangle silhouette with short thick legs. Burgundy and gold accents. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold readable silhouette, hand-painted textures, muted post-soviet colours with one bright accent. Full body, strict T-pose, arms straight out to the sides, legs apart, fingers simplified, clothes not fused to arms or between legs, clean topology at joints, no rig. Single character, centered, no ground, no background.
```

### 7. G67-H01 — Стойка выбора стилей

- **Назначение:** Хаб: предмет, у которого игрок выбирает стартовый боевой стиль (оружие героев вешается на стойку в игре).
- **Поза / ракурс:** Стоит на полу, вид спереди; точка опоры — центр основания. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_style_rack.glb`
- **Путь:** `godot/assets/golda67/g67_style_rack.glb`
- **Статус:** получена 2026-11-20
- **Промпт (858 символов):**

```text
An improvised weapon rack for an apartment stairwell, welded from old water pipes and a rusty bed frame headboard. Upright frame about two metres wide and 1.8 metres tall on two flat feet, three empty pairs of padded hooks at different heights, an empty wire basket at the bottom, a bare shelf plank on top, a strip of blue electrical tape wrapped around one pipe, a small empty metal number plate riveted in the middle of the top bar. Nothing hanging on it. Front side with hooks clearly different from the plain back. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 8. G67-H02 — Сервант для артефактов

- **Назначение:** Хаб, второй этаж: коллекция найденных артефактов (предметы ставятся на полки в игре).
- **Поза / ракурс:** Стоит на полу, вид спереди; точка опоры — центр основания. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_artifact_cabinet.glb`
- **Путь:** `godot/assets/golda67/g67_artifact_cabinet.glb`
- **Статус:** получена 2026-11-20
- **Промпт (813 символов):**

```text
An old soviet glass display sideboard (servant) carried out onto a stairwell landing. Dark lacquered brown wood, about 1.6 metres wide and 1.9 metres tall, upper part with two sliding glass doors and three empty glass shelves backed by a mirror, lower part with two wooden doors and brass handles, short tapered legs. Glass slightly dusty and open at the front so the empty shelves are clearly visible. A lace doily on the top and a chipped corner. Shelves completely empty. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 9. G67-H03 — Карта маршрутов

- **Назначение:** Хаб: у выхода — доска с картой районов (схема рисуется поверх в игре).
- **Поза / ракурс:** Настенный объект, вид спереди; точка опоры — центр задней плоскости. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_route_board.glb`
- **Путь:** `godot/assets/golda67/g67_route_board.glb`
- **Статус:** получена 2026-11-20
- **Промпт (855 символов):**

```text
A wall-mounted evacuation plan board from a soviet apartment block, reused as a route map. Wide plywood board about 1.6 by 1.1 metres in a chipped red wooden frame, covered with a large blank faded paper sheet held by rusty pushpins, coloured strings stretched between several pushpins, a few small blank paper notes and one blank photo pinned at the corners, a pencil hanging on a string, a small metal lamp on a bent arm fixed above the board. Paper sheet is empty with no drawing. Flat back for hanging on a wall. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 10. G67-H04 — Почтовые ящики

- **Назначение:** Хаб: секция почтовых ящиков подъезда (листовки и секреты; номера накладываются в игре).
- **Поза / ракурс:** Настенный объект, вид спереди; точка опоры — центр задней плоскости. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_mailboxes.glb`
- **Путь:** `godot/assets/golda67/g67_mailboxes.glb`
- **Статус:** получена 2026-11-20
- **Промпт (755 символов):**

```text
A wall-mounted block of old soviet apartment mailboxes: two rows of four small metal boxes, about 1.4 metres wide and 0.7 metres tall, painted peeling blue, each with a narrow slot, a row of round holes and a tiny lock, blank number plates. One door bent and hanging open, one box stuffed with blank paper flyers sticking out, scorch marks and scratches, a blank sticker on one door. Flat back for hanging on a wall. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 11. G67-H05 — Доска объявлений

- **Назначение:** Хаб и районы: доска, на которую в игре клеятся листовки турнира и объявления.
- **Поза / ракурс:** Настенный объект, вид спереди; точка опоры — центр задней плоскости. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_notice_board.glb`
- **Путь:** `godot/assets/golda67/g67_notice_board.glb`
- **Статус:** получена 2026-11-20
- **Промпт (750 символов):**

```text
A battered apartment entrance notice board. Rectangular plywood panel about 1.2 by 0.9 metres in a dented aluminium frame with a small sloped metal roof strip on top, the surface covered with layers of torn blank paper scraps, glue stains, tape remains and staples, leaving a large clean empty area in the middle. Two blank tear-off flyers with fringe strips at the bottom edge. Flat back for hanging on a wall. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 12. G67-H06 — Скрытая дверь «колясочная»

- **Назначение:** Хаб: дверь под лестницей. До первой концовки завалена и заколочена, после — вход в служебный маршрут.
- **Поза / ракурс:** Стоит на полу, вид спереди, дверь закрыта; точка опоры — центр нижнего края. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен. Желательно, чтобы полотно двери было отдельной частью от рамы (открою поворотом узла).
- **Имя файла:** `g67_service_door.glb`
- **Путь:** `godot/assets/golda67/g67_service_door.glb`
- **Статус:** получена 2026-11-20
- **Промпт (812 символов):**

```text
A low heavy metal service door in a concrete frame, the kind found under a staircase in a soviet apartment block. Door leaf about 1 metre wide and 1.8 metres tall, painted dark green with rust along the bottom, a big padlock hasp, a small barred vent at the top, a blank metal plate at eye level, two rough wooden planks nailed across it in an X. A thick black cable wrapped with gold tape runs out from under the door. Door leaf modelled as a separate part from the frame. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 13. G67-E01 — Стена подъезда (модуль)

- **Назначение:** Хаб и комнаты-подъезды: стеновой модуль 4×3 м, ставится в ряд.
- **Поза / ракурс:** Плоская панель, вид спереди; точка опоры — центр нижнего края. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_podezd_wall.glb`
- **Путь:** `godot/assets/golda67/g67_podezd_wall.glb`
- **Статус:** получена 2026-11-20
- **Промпт (855 символов):**

```text
A straight wall segment of a soviet apartment stairwell, 4 metres wide, 3 metres tall, 0.2 metres thick. Lower half painted glossy dark green with chips and scratches, a thin darker stripe on top of the paint line, upper half and edge whitewashed and yellowed with stains and cracks, a concrete skirting at the floor. A cast iron radiator under a bundle of two vertical pipes on the right side, an old round light switch, a few scratched marks. Back side plain grey concrete. Left and right edges perfectly flat and vertical. Stylized low-poly 3D modular environment piece for a game, gritty post-soviet Russian style: chunky proportions, clean low-poly faces, hand-painted textures, worn paint and grime, muted colours. Flat straight side edges so copies tile side by side. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 14. G67-E02 — Лестничный марш (модуль)

- **Назначение:** Хаб: пролёт между первым и вторым этажом; служебные лестницы районов.
- **Поза / ракурс:** Вид сбоку-спереди; точка опоры — нижний край первой ступени по центру. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_stair_flight.glb`
- **Путь:** `godot/assets/golda67/g67_stair_flight.glb`
- **Статус:** получена 2026-11-20
- **Промпт (754 символов):**

```text
One straight flight of concrete stairs from a soviet apartment block: nine wide worn steps, 1.2 metres wide, rising 1.5 metres over 2.7 metres of length, solid concrete underside. Steps grey with a painted dark red stripe along both sides and chipped edges. A metal railing on one side only, made of thin square bars painted peeling brown with a worn wooden handrail on top. Top and bottom ends cut flat to join floor slabs. Stylized low-poly 3D modular environment piece for a game, gritty post-soviet Russian style: chunky proportions, clean low-poly faces, hand-painted textures, worn paint and grime, muted colours. Flat straight side edges so copies tile side by side. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 15. G67-E05 — Дверь выбора комнаты

- **Назначение:** Главный объект забега: после боя открываются 2–3 такие двери; над каждой в игре висит значок следующей комнаты и награды.
- **Поза / ракурс:** Стоит на полу, вид спереди, створки закрыты; точка опоры — центр нижнего края. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен. Две створки — отдельными частями от рамы (открываю поворотом узлов).
- **Имя файла:** `g67_room_gate.glb`
- **Путь:** `godot/assets/golda67/g67_room_gate.glb`
- **Статус:** получена 2026-11-20
- **Промпт (865 символов):**

```text
A freestanding double gate used as a level exit, built like soviet garage doors. Heavy welded steel frame about 2.6 metres wide and 2.8 metres tall, two riveted metal door leaves painted worn dark red with rust streaks, a horizontal locking bar across the middle, a thick chain with an open padlock. Above the frame a wide blank rectangular sign box with a small lamp on each side and a round empty bracket for hanging an icon. Two short concrete posts at the sides. Both door leaves modelled as separate parts from the frame. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 16. G67-E06 — Турник и брусья

- **Назначение:** Район ДВОР: спортплощадка и арена Миши Минасяна (препятствие; в фазе 3 босс срывает перекладину).
- **Поза / ракурс:** Стоит на земле, вид спереди-сбоку; точка опоры — центр основания. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен. Желательно: верхняя перекладина турника — отдельной частью.
- **Имя файла:** `g67_workout_bars.glb`
- **Путь:** `godot/assets/golda67/g67_workout_bars.glb`
- **Статус:** получена 2026-11-20
- **Промпт (782 символов):**

```text
An old outdoor courtyard workout set welded from thick steel pipes, painted in peeling yellow and blue. A tall pull-up bar about 2.4 metres high and 1.6 metres wide joined on one side to a pair of parallel bars about 1.3 metres high and 2 metres long, sharing one post. Round concrete footings at the base of each post, worn bare metal where hands grip, a strip of old cloth tied on the top bar. Top horizontal bar modelled as a separate part. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 17. G67-E07 — Стенд турнирного плаката

- **Назначение:** Все районы и ролики AD01, V00: рекламный стенд, плакат «ТУРНИР 67» накладывается в игре.
- **Поза / ракурс:** Стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_poster_stand.glb`
- **Путь:** `godot/assets/golda67/g67_poster_stand.glb`
- **Статус:** получена 2026-11-20
- **Промпт (807 символов):**

```text
A cheap street advertising stand for a local tournament. Vertical lightbox panel about 1.2 metres wide and 2 metres tall on two rusty square legs with a heavy concrete base, a dented golden-yellow painted metal frame, a completely blank white poster face behind scratched plexiglass, a row of small round bulbs along the top edge, some burnt out, a loop of black cable on the back, golden tinsel taped around one leg. Poster face empty and flat. Back side plain metal. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 18. G67-E09 — Вход в подъезд

- **Назначение:** Хаб (крыльцо) и район ДВОР: дверь подъезда с козырьком; ролик V00 (Миша выходит, цепь цепляется за ручку).
- **Поза / ракурс:** Стоит на земле, вид спереди, дверь закрыта; точка опоры — центр нижнего края. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен. Полотно двери — отдельной частью от рамы.
- **Имя файла:** `g67_podezd_entrance.glb`
- **Путь:** `godot/assets/golda67/g67_podezd_entrance.glb`
- **Статус:** получена 2026-11-20
- **Промпт (859 символов):**

```text
A soviet apartment block entrance porch as one freestanding piece. Heavy brown steel door about 1 metre wide and 2.1 metres tall with a long vertical pull handle and a blank intercom panel beside it, set in a grey concrete frame section 3 metres wide and 3 metres tall, a flat concrete canopy slab above on two thin steel posts, a bare bulb lamp under the canopy, three low concrete steps in front, a small blank number plate above the door, snow on the canopy edge. Door leaf modelled as a separate part from the frame. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 19. G67-I01 — Монета голды

- **Назначение:** Валюта забега: выпадает из врагов, лежит в комнатах; падает в кадр в трейлере V00.
- **Поза / ракурс:** Стоит на ребре, вид спереди; точка опоры — центр. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_golda_coin.glb`
- **Путь:** `godot/assets/golda67/g67_golda_coin.glb`
- **Статус:** получена 2026-11-20
- **Промпт (715 символов):**

```text
A single big chunky gold game coin, thick like a hockey puck, about 30 centimetres across. Bright warm gold with a raised smooth rim, both faces showing a simple embossed laurel wreath around a flat empty round centre, small dents and scratches, a slightly darker worn edge with coarse ridges. Toy-like and instantly readable from far away. Faces identical, centre left blank. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### 20. G67-I02 — Фитс (вешалка-награда)

- **Назначение:** Награда комнаты FIT и BATTLE: висит в центре комнаты, игрок подходит и выбирает усиление. Цвет чехла в игре перекрашивается под семейство фитса.
- **Поза / ракурс:** Висит, вид спереди; точка опоры — крючок вешалки сверху. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_fit_hanger.glb`
- **Путь:** `godot/assets/golda67/g67_fit_hanger.glb`
- **Статус:** получена 2026-11-20
- **Промпт (780 символов):**

```text
A reward pickup shaped like an outfit on a hanger: a thick wire coat hanger with a big hook on top, holding a puffy short garment bag made of plain light-grey fabric with a zip down the middle, the bag bulging as if a jacket is inside, a blank round paper tag on a string at the hook, a strip of gold tape around the hanger neck. Simple, rounded, toy-like, about 0.9 metres tall. The bag surface is a single plain colour so it can be tinted. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

## Дополнение к P0 от 2026-11-20 — ведущий новостей в кадре

Владелец решил, что ведущий «РАЙОННОГО ВЕСТНИКА 67» нужен в кадре. Ролик NEWS01 входит в вертикальный срез,
поэтому обе модели идут в P0.

| № | id | Модель | Файл | Длина | Статус |
|---|---|---|---|---|---|
| 21 | G67-C23 | Ведущий «РАЙОННОГО ВЕСТНИКА 67» | `godot/assets/golda67/g67_news_anchor.glb` | 984 | получена |
| 22 | G67-D08 | Новостной стол | `godot/assets/golda67/g67_news_desk.glb` | 934 | получена |

### 21. G67-C23 — Ведущий «РАЙОННОГО ВЕСТНИКА 67»

- **Назначение:** Ведущий новостей в кадре: ролики NEWS01–NEWS04 (сидит за столом, говорит максимально серьёзно).
- **Поза / ракурс:** T-поза, вид спереди, в полный рост (в игре сидит за столом — позу сделаю клипом). Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Гуманоид: T-поза, без авторига. Скелет Mixamo поставлю сам (`tools/rig-horror.py`, шаблон `pahan`). Клипы: сидит за столом, перекладывает листы, поворот к экрану, драматическая пауза.
- **Имя файла:** `g67_news_anchor.glb`
- **Путь:** `godot/assets/golda67/g67_news_anchor.glb`
- **Статус:** получена 2026-11-20
- **Промпт (984 символов):**

```text
A deadly serious local TV news anchor of a tiny district channel, a man in his fifties. Old-fashioned boxy mustard-brown suit jacket one size too big with wide lapels, pale blue shirt, a wide dark red tie with a big knot, a small round gold pin on the lapel. Below the jacket, hidden by the desk on air, grey track pants with white side stripes and felt house slippers. Neat grey side-parted hair stiff with hairspray, thick grey moustache, heavy square glasses, stern frowning eyebrows, tired bags under the eyes, straight proud posture. The dark red tie is the single bright accent. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold readable silhouette, hand-painted textures, muted post-soviet colours with one bright accent. Full body, strict T-pose, arms straight out to the sides, legs apart, fingers simplified, clothes not fused to arms or between legs, clean topology at joints, no rig. Single character, centered, no ground, no background.
```

### 22. G67-D08 — Новостной стол

- **Назначение:** Стол ведущего в роликах NEWS01–NEWS04 (логотип «РАЙОННЫЙ ВЕСТНИК 67» накладывается в игре на переднюю панель).
- **Поза / ракурс:** Стоит на полу, вид спереди; точка опоры — центр основания. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Риг не нужен (статичный объект).
- **Имя файла:** `g67_news_desk.glb`
- **Путь:** `godot/assets/golda67/g67_news_desk.glb`
- **Статус:** получена 2026-11-20
- **Промпт (934 символов):**

```text
A cheap homemade TV news desk of a tiny district channel. A curved front desk about 2.2 metres wide and 1 metre tall built from laminated chipboard, the front covered with a glossy dark blue panel with a wide blank lighter rectangle in the middle for a logo and a golden-yellow trim strip along the top edge, chipped corners showing raw chipboard, the back side open with a shelf holding a tangle of cables and an extension cord. On the desktop: a stack of blank paper sheets, a glass of tea in a metal holder, an old desk microphone on a short stand. Front clearly different from the open back. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

## Приёмка P0 — 2026-11-20

Владелец прислал все 22 модели. Каждая облегчена (`glbslim.gd`: текстуры 4096 → 1024, вместе 320 МБ → 58 МБ),
переименована, импортирована (`compress/mode=2`, `process/size_limit=1024`) и просмотрена с четырёх сторон.

- **Лицом по +Z** — все 22 (в этот раз не по +X): доворот в коде не нужен.
- **Персонажи в T-позе**, без скелета — как просили. Скелет ещё не ставился.
- Каждая модель — одна цельная сетка: створки дверей и перекладина турника **не отдельные части**. Двери
  открываются иначе (уезжают или заменяются проёмом), перекладину в фазе 3 босса показываем эффектом.
- 55–100 тысяч треугольников на модель — тяжелее, чем у пропсов гонок; на вертикальном срезе замерить кадр.

| id | Замечание |
|---|---|
| G67-C06 Смотрящий | Первая модель вышла с четырьмя руками; владелец в тот же день прислал **вторую модель** (две руки, боксёрская стойка вместо T-позы) — в проекте лежит она. Скелет стоит, руки оставлены близко к вылепленной стойке |
| G67-C01 Миша Минасян | Модель не по промпту: чёрная футболка, борода, кудри; **нет спортивного костюма и золотой цепи**. По ТЗ цепь — главный реквизит (цепляется в V00, AD01, CL01; «поправляет цепь» в NEWS01). **Решение владельца: оставить как есть** |
| G67-C02 КРОТ | Модель не по промпту (длинные чёрные волосы, красный свитшот, сигарета) — принят как образ владельца |
| G67-C03 dj flürr | Модель не по промпту (кудри, серая жилетка-худи, бордовые рукава) — принят как образ владельца; на рукаве читается «77» |
| G67-H06 Скрытая дверь | Только полотно, без рамы; стоит с наклоном — выровняю при установке, проём сделаю в стене |
| G67-H05 Доска объявлений | Не настенная, а на ножках с козырьком — подходит и для двора, и для подъезда |
| G67-E06 Турник и брусья | Получились две П-образные рамы разной высоты — как турник годится |
| остальные | без замечаний |

## Скелеты персонажей — 2026-11-20

Всем семи персонажам P0 поставлен скелет Mixamo от Пахана (`tools/rig-horror.py`, записи `g67_*` в таблице `RIGS`;
разметка суставов снята с видов спереди и сбоку с сеткой). Проверено пробной позой: рука вниз, рука вверх с
согнутым локтем, шаг, поворот корпуса и головы.

| Модель | Команда | Итог |
|---|---|---|
| Миша Минасян, КРОТ, dj flürr, Шестёрка, ведущий новостей | `python tools/rig-horror.py g67_<имя> <вход> <выход>` | гнутся чисто |
| Смотрящий | то же; руки остаются почти как вылеплены (`align arm 0.15`) | гнётся; стойка с кулаками перед собой — его поза покоя |
| Семечник | то же; кулёк с семечками жёстко на тазе | гнётся; **на пуховике у плеч видны тонкие швы** при поднятой руке — довести, когда появятся настоящие анимации |

Исходники без скелета — файлы владельца в «Загрузках»; в проекте лежат уже со скелетом. Статус персонажей —
«получена, скелет стоит»; «интегрирована» будет после появления в игре.

## Партия ДВОР (Y) — 2026-11-20: чего не хватает двору

Двор собран из имеющихся моделей (хрущёвка, девятиэтажка, гаражи, ларёк, остановка, площадка, беседка и др.).
Эти двенадцать моделей закрывают места, где сейчас стоит замена: борта и мачты арены, машина и трон Миши,
сугробы, второй тип дома, арка, жилые детали. Игра работает и без них; с ними двор станет заметно богаче.
Порядок важности: Y01–Y05 (арена босса), Y10–Y11 (силуэт двора), остальные.

| № | id | Модель | Файл | Длина | Статус |
|---|---|---|---|---|---|
| 1 | G67-Y01 | Борт хоккейной коробки | `godot/assets/golda67/g67_court_board.glb` | 845 | интегрирована 2026-11-20 |
| 2 | G67-Y02 | Калитка коробки | `godot/assets/golda67/g67_court_gate.glb` | 808 | интегрирована 2026-11-20 |
| 3 | G67-Y03 | Машина Миши Минасяна | `godot/assets/golda67/g67_misha_car.glb` | 902 | интегрирована 2026-11-20 |
| 4 | G67-Y04 | Трон Миши | `godot/assets/golda67/g67_misha_throne.glb` | 797 | интегрирована 2026-11-20 |
| 5 | G67-Y05 | Мачта с прожекторами | `godot/assets/golda67/g67_floodlight_mast.glb` | 756 | интегрирована 2026-11-20 |
| 6 | G67-Y06 | Сугроб | `godot/assets/golda67/g67_snowdrift.glb` | 774 | интегрирована 2026-11-20 |
| 7 | G67-Y07 | Ковровыбивалка с ковром | `godot/assets/golda67/g67_carpet_rack.glb` | 756 | интегрирована 2026-11-20 |
| 8 | G67-Y08 | Сушилка с бельём | `godot/assets/golda67/g67_laundry_lines.glb` | 743 | интегрирована 2026-11-20 |
| 9 | G67-Y09 | Бетонная урна | `godot/assets/golda67/g67_urn.glb` | 692 | интегрирована 2026-11-20 |
| 10 | G67-Y10 | Кирпичная пятиэтажка | `godot/assets/golda67/g67_brick_house.glb` | 878 | интегрирована 2026-11-20 |
| 11 | G67-Y11 | Секция дома с аркой | `godot/assets/golda67/g67_house_arch.glb` | 847 | интегрирована 2026-11-20 |
| 12 | G67-Y12 | Открытый гараж с верстаком | `godot/assets/golda67/g67_garage_open.glb` | 768 | интегрирована 2026-11-20 |

### G67-Y01 — Борт хоккейной коробки

- **Назначение:** Арена Миши Минасяна: борта по периметру площадки (сейчас вместо них — секции декоративного забора).
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_court_board.glb`
- **Путь:** `godot/assets/golda67/g67_court_board.glb`
- **Статус:** промпт выдан
- **Промпт (845 символов):**

```text
A straight section of an old soviet courtyard hockey rink wall, 4 metres long. Lower part: a 1.1 metre high wooden board fence made of horizontal planks, painted peeling white with a wide blue stripe along the top edge and a red kick stripe at the bottom, scuffed by pucks and boots. Upper part: a 2 metre high chain-link mesh in a rusty welded steel frame with two square posts at the ends. A few dents, old sticker remains, snow lying on the top rail. Both ends cut flat and vertical so sections join into a rink. Stylized low-poly 3D modular environment piece for a game, gritty post-soviet Russian style: chunky proportions, clean low-poly faces, hand-painted textures, worn paint and grime, muted colours. Flat straight side edges so copies tile side by side. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y02 — Калитка коробки

- **Назначение:** Вход на арену Миши: проём в борту с открытой калиткой.
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_court_gate.glb`
- **Путь:** `godot/assets/golda67/g67_court_gate.glb`
- **Статус:** промпт выдан
- **Промпт (808 символов):**

```text
An entrance gate section of an old courtyard hockey rink. A 4 metre wide wall section like the rink boards (white planks with a blue top stripe, chain-link mesh above in a rusty steel frame) with a 1.4 metre wide doorway in the middle, the door leaf made of planks and mesh swung open outward at 90 degrees, a rusty hinge and a bent latch, a worn threshold beam. Two taller steel posts beside the doorway joined by a bar on top where a banner could hang. Ends cut flat. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y03 — Машина Миши Минасяна

- **Назначение:** «Трон» босса и шутки роликов (садится на капот, цепь цепляется за зеркало). Сейчас — перекрашенная соседская машина.
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_misha_car.glb`
- **Путь:** `godot/assets/golda67/g67_misha_car.glb`
- **Статус:** промпт выдан
- **Промпт (902 символов):**

```text
A flashy old soviet-era hatchback tuned by a courtyard boss who thinks it is a luxury car. Boxy 1990s three-door body painted glossy black with a matte gold bonnet stripe, lowered suspension, oversized gold alloy wheels with thin tyres, fully tinted dark windows, a big plastic rear spoiler, a furry dashboard cover visible through the windscreen, fuzzy dice, two extra fog lamps, a chrome exhaust tip, a blank licence plate frame. Clean and polished but with rust peeking at the wheel arches. Side mirrors clearly sticking out. Front clearly different from back. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y04 — Трон Миши

- **Назначение:** Место босса в дальнем конце арены: отсюда он встаёт в постановке выхода.
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_misha_throne.glb`
- **Путь:** `godot/assets/golda67/g67_misha_throne.glb`
- **Статус:** промпт выдан
- **Промпт (797 символов):**

```text
A makeshift throne of a courtyard boss built outdoors. An old fat brown leather armchair with cracked upholstery standing on two wooden shipping pallets, a red patterned soviet wall carpet draped over the high back and hanging down behind, golden tinsel wound around the armrests, a crate used as a side table with a thermos and a blank trophy cup on it, a small red rug under the feet. Pompous and shabby at the same time. Front clearly different from back. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y05 — Мачта с прожекторами

- **Назначение:** Освещение арены: четыре мачты по углам коробки (сейчас — увеличенные уличные фонари).
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_floodlight_mast.glb`
- **Путь:** `godot/assets/golda67/g67_floodlight_mast.glb`
- **Статус:** промпт выдан
- **Промпт (756 символов):**

```text
A tall courtyard sports floodlight mast, about 8 metres high. A slender rusty lattice steel tower narrowing to the top, standing on a concrete footing block, with a short crossbar at the top holding three old rectangular floodlight lamps tilted downward, each with a dented metal hood and a glass face, a loose black cable running down the mast into a grey electrical box bolted at chest height. Snow on the crossbar. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y06 — Сугроб

- **Назначение:** Сугробы вдоль проездов и под деревьями (сейчас собраны из простых форм).
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_snowdrift.glb`
- **Путь:** `godot/assets/golda67/g67_snowdrift.glb`
- **Статус:** промпт выдан
- **Промпт (774 символов):**

```text
A long ploughed snowbank pushed to the side of a courtyard road, about 5 metres long, 1.6 metres wide and 0.9 metres high. Lumpy irregular shape with a steep dirty side facing the road, grey-brown grit and tyre spray along the lower edge, clean white rounded top with wind-blown ridges, a few chunks of broken ice, one half-buried piece of a wooden plank and a cigarette pack sticking out. Soft blue shadows painted in. Flat underside. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y07 — Ковровыбивалка с ковром

- **Назначение:** Жилая деталь двора у детской площадки; укрытие в бою.
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_carpet_rack.glb`
- **Путь:** `godot/assets/golda67/g67_carpet_rack.glb`
- **Статус:** промпт выдан
- **Промпт (756 символов):**

```text
A soviet courtyard carpet-beating rack. A sturdy welded steel frame like a wide low goalpost, about 2.6 metres wide and 2 metres tall, painted peeling green, on two posts set in concrete, with a heavy red patterned soviet carpet thrown over the top bar and hanging down on both sides almost to the ground, snow on the upper fold, a plastic carpet beater hanging on a hook on one post. Front and back both show carpet. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y08 — Сушилка с бельём

- **Назначение:** Жилая деталь двора между домом и площадкой.
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_laundry_lines.glb`
- **Путь:** `godot/assets/golda67/g67_laundry_lines.glb`
- **Статус:** промпт выдан
- **Промпт (743 символов):**

```text
A soviet courtyard laundry drying stand: two T-shaped steel posts about 2.2 metres tall and 4 metres apart, painted peeling blue, joined by four sagging ropes. On the ropes hang frozen stiff laundry: a white bed sheet, a striped towel, a pair of blue track pants with white stripes, two shirts and a row of socks, held by wooden clothespins, edges frosted with snow. Posts set in small concrete footings. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y09 — Бетонная урна

- **Назначение:** Урны у подъезда, у ларька и у лавок (сейчас вместо них бочки).
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_urn.glb`
- **Путь:** `godot/assets/golda67/g67_urn.glb`
- **Статус:** промпт выдан
- **Промпт (692 символов):**

```text
A small soviet concrete street litter bin, about 0.7 metres tall. A chunky hexagonal vase-shaped concrete body with chipped edges and a pebble texture, painted in flaking pale green, a dented galvanised metal bucket insert inside, overflowing with crumpled paper, a bottle and sunflower seed husks, cigarette burns on the rim, a little snow on one side. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y10 — Кирпичная пятиэтажка

- **Назначение:** Второй тип дома: сейчас весь двор окружён одной моделью хрущёвки и одной девятиэтажкой.
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_brick_house.glb`
- **Путь:** `godot/assets/golda67/g67_brick_house.glb`
- **Статус:** промпт выдан
- **Промпт (878 символов):**

```text
A five-storey soviet brick apartment block, a long building about four times longer than deep. Dark red-brown brick walls with lighter brick patterns between floors, a pitched grey slate roof with chimneys and TV antennas, small balconies with mismatched glazing and laundry, three entrance porches with concrete canopies and steel doors on the front side, drainpipes at the corners, air conditioner boxes, some windows glowing warm yellow and some dark, a satellite dish. Back side with fewer balconies. Front clearly different from back. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y11 — Секция дома с аркой

- **Назначение:** Арка-проезд из двора: здесь будет переход в район ПОДЗЕМКА и растяжка турнира над ней.
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_house_arch.glb`
- **Путь:** `godot/assets/golda67/g67_house_arch.glb`
- **Статус:** промпт выдан
- **Промпт (847 символов):**

```text
A section of a five-storey soviet panel apartment block with a tall drive-through archway at ground level. Grey concrete panel walls with visible seams, an arch passage about 4 metres wide and 4.5 metres tall cutting straight through the building, dark inside with a bare bulb lamp, graffiti remains on the arch walls, windows and small balconies on the four floors above, a few lit yellow, a blank banner stretched across above the arch on two ropes. Both side walls cut flat to join neighbouring buildings. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-Y12 — Открытый гараж с верстаком

- **Назначение:** Гаражи: один бокс открыт — видно, что там живут своей жизнью (сейчас все гаражи одной модели, только разного оттенка).
- **Поза / ракурс:** стоит на земле, вид спереди; точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_garage_open.glb`
- **Путь:** `godot/assets/golda67/g67_garage_open.glb`
- **Статус:** промпт выдан
- **Промпт (768 символов):**

```text
An open soviet metal garage box seen from the front, about 3.5 metres wide and 2.8 metres tall. Corrugated rusty steel walls and roof, both door leaves swung wide open, inside a workbench with a vice and tools, shelves with jars and oil cans, a hanging bare bulb with warm light, a stack of winter tyres, an old stool, a blank poster on the back wall, a kettle on a crate. Snow on the roof. Back and sides plain corrugated metal. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

## Партия КРОТ — 2026-11-20: две модели для его встреч

Встреча 1 («ДРУЗЬЯ ИЗ FORBES») уже в игре. Встречи 2 и 3 написаны и ждут только этих моделей: как только файл
появится в папке, КРОТ сам встанет на своё место.

| № | id | Модель | Файл | Длина | Статус |
|---|---|---|---|---|---|
| 1 | G67-S10 | Люстра | `godot/assets/golda67/g67_chandelier.glb` | 776 | интегрирована 2026-11-20 |
| 2 | G67-A01 | Голубь | `godot/assets/golda67/g67_pigeon.glb` | 745 | интегрирована 2026-11-20 |

### G67-S10 — Люстра

- **Назначение:** Встреча КРОТА 2 «ЛЮСТРА»: он стоит в подъезде с люстрой в руках и уходит с ней. Без этой модели встреча не появляется.
- **Поза / ракурс:** вид спереди. Формат GLB.
- **Риг и анимации:** Риг не нужен. Точка опоры — крюк сверху.
- **Имя файла:** `g67_chandelier.glb`
- **Путь:** `godot/assets/golda67/g67_chandelier.glb`
- **Статус:** промпт выдан
- **Промпт (776 символов):**

```text
An old soviet apartment ceiling chandelier that someone has just taken down and is carrying. A brass-coloured metal body with five curved arms, each ending in a frosted glass tulip shade, rows of dangling plastic crystal pendants, a short chain and a ceiling cup at the top with a torn piece of white wire sticking out, one shade cracked, dust and a cobweb. About 0.7 metres wide and 0.6 metres tall. Slightly pompous, slightly pathetic. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

### G67-A01 — Голубь

- **Назначение:** Встреча КРОТА 3 «ГОЛУБИНОЕ ПРАВИТЕЛЬСТВО»: он кормит голубей на детской площадке. Без этой модели встреча не появляется.
- **Поза / ракурс:** вид спереди. Формат GLB.
- **Риг и анимации:** Риг не нужен: голуби двигаются простым кодом. Стоит на двух лапах, лицом вперёд.
- **Имя файла:** `g67_pigeon.glb`
- **Путь:** `godot/assets/golda67/g67_pigeon.glb`
- **Статус:** промпт выдан
- **Промпт (745 символов):**

```text
A fat grumpy city pigeon standing on the ground, a self-important little bird. Round chunky grey body, darker wings with two black bars, a shimmering green and purple neck patch, small head with a suspicious orange eye, short beak, pink scaly legs with spread toes, tail feathers slightly ruffled, chest puffed out like an official. Wings folded. About 0.3 metres tall. Legs clearly separate from the body. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

## Шаурмичная — 2026-11-20

Владелец попросил настоящую шаурмичную для первой встречи КРОТА. Сейчас на её месте стоит обычный ларёк с вывеской.

| id | Модель | Файл | Длина | Статус |
|---|---|---|---|---|
| G67-Y13 | Шаурмичная «ШАУРМА 67» | `godot/assets/golda67/g67_shawarma_kiosk.glb` | 975 | интегрирована 2026-11-20 |

### G67-Y13 — Шаурмичная «ШАУРМА 67»

- **Назначение:** ларёк, у которого КРОТ стоит в очереди на первой встрече («ДРУЗЬЯ ИЗ FORBES»); позже — комната KIOSK (покупки за голду).
- **Поза / ракурс:** стоит на земле, вид спереди (окно выдачи); точка опоры — центр основания. Формат GLB.
- **Риг и анимации:** не нужны.
- **Имя файла:** `g67_shawarma_kiosk.glb`
- **Путь:** `godot/assets/golda67/g67_shawarma_kiosk.glb`
- **Статус:** промпт выдан
- **Промпт (975 символов):**

```text
A small street shawarma kiosk in a post-soviet courtyard at night. A boxy metal stall about 3 metres wide, 2.4 metres deep and 3 metres tall, painted peeling red and yellow, with a wide serving window on the front: inside a vertical rotating meat spit glowing warm orange, a steel counter with sauce bottles, a stack of flatbreads, a cutting board. A striped awning over the window, a blank lightbox sign on the roof, a blank menu board beside the window, a small shelf for customers, a gas cylinder at the side, a tin chimney pipe with a cap, steam vents, snow on the roof, a napkin holder. Front clearly different from the plain back. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

## Партии P1–P3 — статус «требуется»

Промпты для этих моделей будут выданы следующими партиями, после ответа владельца по P0. Список — в
`ASSET_MANIFEST.md`, раздел 2.

| Партия | id | Статус |
|---|---|---|
| P1 | G67-C07, C08, C09 (боссы 2–4); G67-C10, C12, C13, C14 (враги) | требуется |
| P1 | G67-A01 … G67-A03 (голубь, хомяк, собака) | требуется |
| P1 | G67-E03, E04, E08, E10, E11, E12; G67-I03, I04 | требуется |
| P1 | G67-U01 … G67-U09 (ПОДЗЕМКА) | требуется |
| P1 | G67-L01 … G67-L07 (ЛЕНТА) | требуется |
| P1 | G67-F01 … G67-F07 (БОТОФЕРМА) | требуется |
| P1 | G67-S01 … G67-S10 (события) | требуется |
| P2 | G67-C18, C19, C21, C22 | требуется |
| P2 | G67-S11, S12; G67-B01 … G67-B14 | требуется |
| P3 | G67-D01 … G67-D10, кроме D08 (перенесён в P0) | требуется |

## Журнал

| Дата | Что |
|---|---|
| 2026-11-20 | Выдана партия P0 (20 промптов). Ни одна модель не получена. |
| 2026-11-20 | Выдан промпт шаурмичной (G67-Y13). КРОТ на первой встрече перенесён к ларьку, встреча гарантирована маршрутом. |
| 2026-11-20 | Получены и поставлены в игру все 12 моделей двора (Y01–Y12), голубь и люстра. Все смотрят лицом как ожидалось; тяжёлые (50–120 тыс. треугольников), кадр держится. Встречи КРОТА 2 и 3 включились. |
| 2026-11-20 | КРОТ: встреча 1 в игре; выданы промпты люстры (G67-S10) и голубя (G67-A01) для встреч 2 и 3. |
| 2026-11-20 | Выдана партия ДВОР (Y01–Y12): модели для арены босса и для разнообразия двора. |
| 2026-11-20 | Смотрящий заменён второй моделью владельца. Всем семи персонажам поставлен скелет. Миша Минасян, КРОТ и dj flürr приняты в виде владельца. |
| 2026-11-20 | Получены все 22 модели P0, лежат в `godot/assets/golda67/`. Смотрящий (G67-C06) — на замену. Скелеты не ставились, в игру не интегрированы. |
| 2026-11-20 | Ведущий новостей нужен в кадре: в P0 добавлены G67-C23 и G67-D08 (всего в P0 22 промпта). |
| 2026-11-20 | Решение владельца: уникальных моделей врагов — восемь; сняты с заказа G67-C11, C15, C16, C17, C20. |
