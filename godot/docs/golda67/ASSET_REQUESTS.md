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
| **P0** | хаб, район ДВОР, Миша Минасян, КРОТ, dj flürr, базовые враги, двери и награды | 20 | **промпты выданы, жду модели** |
| P1 | боссы 2–4, враги трёх районов, животные, ПОДЗЕМКА, ЛЕНТА, БОТОФЕРМА, события первой линии | 54 | требуется (промпты — после ответа владельца по P0) |
| P2 | WHYOUSOLONELY, ИЗНАНКА, СТУДИЯ, Mogging Challenge, Anime Room | 21 | требуется |
| P3 | декор | 9 | требуется |

## Партия P0 — вертикальный срез (20 моделей)

Максимальная длина промпта в партии — 981 символов (предел 1000). Длина считается скриптом по полному тексту блока, со стилем и пробелами.

| № | id | Модель | Файл | Длина | Статус |
|---|---|---|---|---|---|
| 1 | G67-C01 | Миша Минасян | `godot/assets/golda67/g67_misha.glb` | 978 | промпт выдан |
| 2 | G67-C02 | КРОТ | `godot/assets/golda67/g67_krot.glb` | 981 | промпт выдан |
| 3 | G67-C03 | dj flürr | `godot/assets/golda67/g67_dj_flurr.glb` | 979 | промпт выдан |
| 4 | G67-C04 | Шестёрка | `godot/assets/golda67/g67_enemy_shestyorka.glb` | 915 | промпт выдан |
| 5 | G67-C05 | Семечник | `godot/assets/golda67/g67_enemy_semechnik.glb` | 933 | промпт выдан |
| 6 | G67-C06 | Смотрящий | `godot/assets/golda67/g67_enemy_smotryashchiy.glb` | 904 | промпт выдан |
| 7 | G67-H01 | Стойка выбора стилей | `godot/assets/golda67/g67_style_rack.glb` | 858 | промпт выдан |
| 8 | G67-H02 | Сервант для артефактов | `godot/assets/golda67/g67_artifact_cabinet.glb` | 813 | промпт выдан |
| 9 | G67-H03 | Карта маршрутов | `godot/assets/golda67/g67_route_board.glb` | 855 | промпт выдан |
| 10 | G67-H04 | Почтовые ящики | `godot/assets/golda67/g67_mailboxes.glb` | 755 | промпт выдан |
| 11 | G67-H05 | Доска объявлений | `godot/assets/golda67/g67_notice_board.glb` | 750 | промпт выдан |
| 12 | G67-H06 | Скрытая дверь «колясочная» | `godot/assets/golda67/g67_service_door.glb` | 812 | промпт выдан |
| 13 | G67-E01 | Стена подъезда (модуль) | `godot/assets/golda67/g67_podezd_wall.glb` | 855 | промпт выдан |
| 14 | G67-E02 | Лестничный марш (модуль) | `godot/assets/golda67/g67_stair_flight.glb` | 754 | промпт выдан |
| 15 | G67-E05 | Дверь выбора комнаты | `godot/assets/golda67/g67_room_gate.glb` | 865 | промпт выдан |
| 16 | G67-E06 | Турник и брусья | `godot/assets/golda67/g67_workout_bars.glb` | 782 | промпт выдан |
| 17 | G67-E07 | Стенд турнирного плаката | `godot/assets/golda67/g67_poster_stand.glb` | 807 | промпт выдан |
| 18 | G67-E09 | Вход в подъезд | `godot/assets/golda67/g67_podezd_entrance.glb` | 859 | промпт выдан |
| 19 | G67-I01 | Монета голды | `godot/assets/golda67/g67_golda_coin.glb` | 715 | промпт выдан |
| 20 | G67-I02 | Фитс (вешалка-награда) | `godot/assets/golda67/g67_fit_hanger.glb` | 780 | промпт выдан |

### 1. G67-C01 — Миша Минасян

- **Назначение:** Босс района ДВОР; ролики V00, AD01, CL01, NEWS01, STORY03; сидит на лавке после поражения.
- **Поза / ракурс:** T-поза, вид спереди, в полный рост. Формат GLB, лицом по +Z (если выйдет по +X — довернём в коде).
- **Риг и анимации:** Гуманоид: T-поза, без авторига. Скелет Mixamo поставлю сам (`tools/rig-horror.py`, шаблон `pahan`). Клипы — кодом. Уникальные клипы: проход «авторитет», зацеп цепи, захват, контратака.
- **Имя файла:** `g67_misha.glb`
- **Путь:** `godot/assets/golda67/g67_misha.glb`
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
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
- **Статус:** промпт выдан
- **Промпт (780 символов):**

```text
A reward pickup shaped like an outfit on a hanger: a thick wire coat hanger with a big hook on top, holding a puffy short garment bag made of plain light-grey fabric with a zip down the middle, the bag bulging as if a jacket is inside, a blank round paper tag on a string at the hook, a strip of gold tape around the hanger neck. Simple, rounded, toy-like, about 0.9 metres tall. The bag surface is a single plain colour so it can be tinted. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright accents. No readable text. Single object, centered, no ground, no background, game-ready.
```

## Партии P1–P3 — статус «требуется»

Промпты для этих моделей будут выданы следующими партиями, после ответа владельца по P0. Список — в
`ASSET_MANIFEST.md`, раздел 2.

| Партия | id | Статус |
|---|---|---|
| P1 | G67-C07 … G67-C17 (боссы 2–4 и враги) | требуется |
| P1 | G67-A01 … G67-A03 (голубь, хомяк, собака) | требуется |
| P1 | G67-E03, E04, E08, E10, E11, E12; G67-I03, I04 | требуется |
| P1 | G67-U01 … G67-U09 (ПОДЗЕМКА) | требуется |
| P1 | G67-L01 … G67-L07 (ЛЕНТА) | требуется |
| P1 | G67-F01 … G67-F07 (БОТОФЕРМА) | требуется |
| P1 | G67-S01 … G67-S10 (события) | требуется |
| P2 | G67-C18 … G67-C22 | требуется |
| P2 | G67-S11, S12; G67-B01 … G67-B14 | требуется |
| P3 | G67-D01 … G67-D10 | требуется |

## Журнал

| Дата | Что |
|---|---|
| 2026-11-20 | Выдана партия P0 (20 промптов). Ни одна модель не получена. |
