# Каталог моделей для Tripo AI: игровой процесс

Кредитов на аккаунте Tripo на момент аудита — **70** при цене 30 за модель и запасе 40, то есть фактически на одну
модель. Поэтому ничего не сгенерировано: ниже — готовые промпты, а в игре на этих местах стоят либо уже имеющиеся
модели, либо модели, собранные кодом из деталей (у каждой свой силуэт — это не кубы, но и не замена настоящей модели).

**Статус на 2026-11-20 (вечер):** владелец сгенерировал на сайте Tripo 40 моделей по этому каталогу и по разделу 9
отчёта `OVERHAUL_REPORT.md` — все стоят в игре. **Не сгенерированы:** пять пылесосов соперников (`vac_*`, решено не
делать) и стеллаж `ml_job_shelf_rack`. Файлы с сайта смотрят лицом по +X (а не +Z) — это учтено в коде.

**Как пользоваться**

- Один промпт — одна модель. Блок копируется целиком: стиль уже внутри. Каждый промпт — не длиннее 1000 символов
  с пробелами (длина указана).
- Скачивать в **GLB** и класть под именем из заголовка в указанную папку. Код менять не нужно:
  - `godot/assets/racing/item_<id>.glb` — предмет гонки (`RaceItems.model` берёт файл, если он есть);
  - `godot/assets/racing/vac_<гонщик>.glb` — пылесос соперника (`RaceVisual`);
  - остальное ставится по имени, как прежние модели (`RaceProps`, `MGModels`).
- Негативный промпт (если есть поле): `photorealistic, photo scan, blurry, noisy mesh, readable text, letters, logos, brand names, watermark, multiple separate objects, floor plane, background scenery`.
- Персонажам нужен скелет Mixamo — без него модель не оживёт. Если Tripo отдаёт без скелета, присылай как есть:
  скелет поставлю скриптом, как хоррор-обитателям.
- Тем же списком владеет `tools/tripo-gameplay.json`: когда кредиты появятся —
  `node tools/tripo-gen.cjs --config=tools/tripo-gameplay.json item_missile` (имя — какие именно).

**Приоритет:** A — без модели место заметно страдает (сейчас там сборка из деталей); B — улучшение и живой мир.

| # | Файл | Для чего | Приоритет | Режим Tripo | Длина |
|---|---|---|---|---|---|
| 1 | `racing/item_turbo_balloon.glb` | VACUUM RACING — предмет ТУРБО-БАЛЛОН (в руках, HUD, пламя при использовании) | A | Text to 3D, standard | 548 |
| 2 | `racing/item_dust_bomb.glb` | VACUUM RACING — предмет ПЫЛЕВОЙ ВЗРЫВ (мешок падает на дорогу и лопается) | A | Text to 3D, standard | 576 |
| 3 | `racing/item_super_suck.glb` | VACUUM RACING — предмет СУПЕР-ВСАСЫВАНИЕ (тянет к сопернику) | A | Text to 3D, standard | 563 |
| 4 | `racing/item_soap.glb` | VACUUM RACING — предмет МЫЛЬНАЯ ЛУЖА (флакон, лежит в луже на дороге) | A | Text to 3D, standard | 520 |
| 5 | `racing/item_filter.glb` | VACUUM RACING — предмет ЗАЩИТНЫЙ ФИЛЬТР (три таких кружат вокруг гонщика) | A | Text to 3D, standard | 567 |
| 6 | `racing/item_air_blast.glb` | VACUUM RACING — предмет ВЫБРОС ВОЗДУХА (гудок на баллончике) | A | Text to 3D, standard | 529 |
| 7 | `racing/item_missile.glb` | VACUUM RACING — предмет ЖЕЛЕЗЯКА (летит по трассе за соперником) | A | Text to 3D, standard | 559 |
| 8 | `racing/item_overclock.glb` | VACUUM RACING — предмет РАЗГОН МОТОРА | A | Text to 3D, standard | 619 |
| 9 | `racing/vac_madk1d.glb` | VACUUM RACING — пылесос MADK1D (мастер заноса) | B | Text to 3D, HD model | 670 |
| 10 | `racing/vac_clipper.glb` | VACUUM RACING — пылесос КЛИППЕРА (таран) | B | Text to 3D, HD model | 655 |
| 11 | `racing/vac_hater.glb` | VACUUM RACING — пылесос ХЕЙТЕРА (пакостник) | B | Text to 3D, HD model | 658 |
| 12 | `racing/vac_bot.glb` | VACUUM RACING — пылесос БОТА-812 (педант) | B | Text to 3D, HD model | 676 |
| 13 | `racing/vac_drey.glb` | VACUUM RACING — пылесос ДРЕЯ (срезает) | B | Text to 3D, HD model | 654 |
| 14 | `racing/race_trick_ring.glb` | VACUUM RACING — кольцо для трюков над трамплином | A | Text to 3D, standard | 587 |
| 15 | `racing/race_grandstand.glb` | VACUUM RACING — трибуна у старта (на неё ставятся зрители) | B | Text to 3D, standard | 562 |
| 16 | `racing/npc_spectator.glb` | VACUUM RACING — зритель на трибуне и у трассы (машет, прыгает) | B | Text to 3D, HD model, для rigging | 549 |
| 17 | `racing/race_start_lights.glb` | VACUUM RACING — светофор старта над чертой | B | Text to 3D, standard | 518 |
| 18 | `minigames/ml_phone.glb` | МИКРОЗАЙМЫ — телефон Пахана на столе (экран светится от уведомлений) | A | Text to 3D, standard | 528 |
| 19 | `minigames/ml_cash_stack.glb` | МИКРОЗАЙМЫ — пачка денег на столе | B | Text to 3D, standard | 507 |
| 20 | `minigames/ml_job_trash_set.glb` | МИКРОЗАЙМЫ — уборка: кучка мусора для всасывания | B | Text to 3D, standard | 512 |
| 21 | `minigames/ml_job_phone_open.glb` | МИКРОЗАЙМЫ — ремонт: разобранный смартфон (сейчас детали — цветные плашки) | A | Text to 3D, HD model | 605 |
| 22 | `minigames/ml_job_part_battery.glb` | МИКРОЗАЙМЫ — ремонт: аккумулятор (деталь на замену) | A | Text to 3D, standard | 529 |
| 23 | `minigames/ml_job_part_speaker.glb` | МИКРОЗАЙМЫ — ремонт: динамик (деталь на замену) | A | Text to 3D, standard | 490 |
| 24 | `minigames/ml_job_part_flex.glb` | МИКРОЗАЙМЫ — ремонт: шлейф экрана (деталь на замену) | A | Text to 3D, standard | 503 |
| 25 | `minigames/ml_job_parcel_box.glb` | МИКРОЗАЙМЫ — доставка: посылка в руках курьера | B | Text to 3D, standard | 504 |
| 26 | `minigames/ml_job_car_dirty.glb` | МИКРОЗАЙМЫ — новая подработка МОЙКА МАШИН | B | Text to 3D, HD model | 604 |
| 27 | `minigames/ml_job_shelf_rack.glb` | МИКРОЗАЙМЫ — склад: стеллаж для сортировки | B | Text to 3D, standard | 509 |
| 28 | `minigames/npc_neighbor.glb` | МИКРОЗАЙМЫ — сосед в подъезде и заказчик в подработках | B | Text to 3D, HD model, для rigging | 544 |
| 29 | `minigames/npc_customer.glb` | МИКРОЗАЙМЫ — заказчик (ремонт, доставка, звук) | B | Text to 3D, HD model, для rigging | 522 |
| 30 | `minigames/fn_door_panel.glb` | 5 НОЧЕЙ — панель у проёма с двумя кнопками (дверь и свет) | B | Text to 3D, standard | 558 |

## ГОНКИ — предметы из коробок

### `item_turbo_balloon.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — предмет ТУРБО-БАЛЛОН (в руках, HUD, пламя при использовании)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.5 × 0.9 × 0.5 м (ширина × высота × длина)
- **Дополнительно:** Пламя — отдельным конусом снизу; стоять вертикально.
- **Промпт (548 символов):**

```text
A small red compressed-gas cylinder used as a rocket booster: domed top with a round hand-wheel valve, a yellow warning band around the middle, a short black nozzle at the bottom with a bright orange flame cone coming out. Standing upright. Stylized low-poly 3D pickup item for an arcade kart racer, gritty post-soviet garage style: toy-like chunky proportions, instantly readable silhouette from far away, clean low-poly faces, hand-painted textures, saturated colour with worn edges. Single object, centered, no ground, no background, game-ready.
```

### `item_dust_bomb.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — предмет ПЫЛЕВОЙ ВЗРЫВ (мешок падает на дорогу и лопается)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.7 × 0.8 × 0.7 м (ширина × высота × длина)
- **Дополнительно:** Круглый силуэт с узлом сверху.
- **Промпт (576 символов):**

```text
A fat overstuffed vacuum-cleaner dust bag used as a bomb: round bulging brown burlap sack, neck tied tight with a red rope, a short black fuse sticking up with a glowing spark at its tip, one sewn square patch on the side, a few grey dust puffs leaking from the seams. Stylized low-poly 3D pickup item for an arcade kart racer, gritty post-soviet garage style: toy-like chunky proportions, instantly readable silhouette from far away, clean low-poly faces, hand-painted textures, saturated colour with worn edges. Single object, centered, no ground, no background, game-ready.
```

### `item_super_suck.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — предмет СУПЕР-ВСАСЫВАНИЕ (тянет к сопернику)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.7 × 0.6 × 0.9 м (ширина × высота × длина)
- **Дополнительно:** Раструб смотрит вперёд (вдоль длинной оси).
- **Промпт (563 символов):**

```text
A huge vacuum-cleaner nozzle used as a tractor beam: wide blue trumpet-shaped mouth with a steel rim and a dark hollow inside, a short black ribbed corrugated hose behind it, a pistol grip handle underneath, a thin glowing cyan ring in front of the mouth. Stylized low-poly 3D pickup item for an arcade kart racer, gritty post-soviet garage style: toy-like chunky proportions, instantly readable silhouette from far away, clean low-poly faces, hand-painted textures, saturated colour with worn edges. Single object, centered, no ground, no background, game-ready.
```

### `item_soap.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — предмет МЫЛЬНАЯ ЛУЖА (флакон, лежит в луже на дороге)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.45 × 0.85 × 0.45 м (ширина × высота × длина)
- **Дополнительно:** Пузыри — отдельными шариками рядом.
- **Промпт (520 символов):**

```text
A squeezable dish-soap bottle: translucent green plastic body with soft shoulders, red flip cap with a white nozzle tip, a blank cream label with one red stripe, three shiny soap bubbles floating next to the cap. Stylized low-poly 3D pickup item for an arcade kart racer, gritty post-soviet garage style: toy-like chunky proportions, instantly readable silhouette from far away, clean low-poly faces, hand-painted textures, saturated colour with worn edges. Single object, centered, no ground, no background, game-ready.
```

### `item_filter.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — предмет ЗАЩИТНЫЙ ФИЛЬТР (три таких кружат вокруг гонщика)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.85 × 0.85 × 0.2 м (ширина × высота × длина)
- **Дополнительно:** Плоский шестигранник, лицом вперёд.
- **Промпт (567 символов):**

```text
A hexagonal vacuum-cleaner HEPA filter used as a shield: thick green plastic hexagon frame, cream pleated paper filter inside with visible folds, six small steel clips on the corners, a thin glowing green outline. Flat disc standing upright facing the viewer. Stylized low-poly 3D pickup item for an arcade kart racer, gritty post-soviet garage style: toy-like chunky proportions, instantly readable silhouette from far away, clean low-poly faces, hand-painted textures, saturated colour with worn edges. Single object, centered, no ground, no background, game-ready.
```

### `item_air_blast.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — предмет ВЫБРОС ВОЗДУХА (гудок на баллончике)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.6 × 0.6 × 0.9 м (ширина × высота × длина)
- **Дополнительно:** Раструб смотрит вперёд.
- **Промпт (529 символов):**

```text
A hand-held air horn: a red plastic trumpet bell with a white rim mounted on top of a small white compressed-air can with a blue stripe and a red push button, three thin white ring-shaped sound waves in front of the bell. Stylized low-poly 3D pickup item for an arcade kart racer, gritty post-soviet garage style: toy-like chunky proportions, instantly readable silhouette from far away, clean low-poly faces, hand-painted textures, saturated colour with worn edges. Single object, centered, no ground, no background, game-ready.
```

### `item_missile.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — предмет ЖЕЛЕЗЯКА (летит по трассе за соперником)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.5 × 0.5 × 1.0 м (ширина × высота × длина)
- **Дополнительно:** Нос — вдоль длинной оси, пламя сзади.
- **Промпт (559 символов):**

```text
A homemade junk rocket: body made of a rusty steel pipe with three bolted hose clamps, a dented red cone nose, four crooked sheet-metal fins of different sizes at the back, a strip of grey duct tape on top, a black exhaust nozzle with an orange flame. Stylized low-poly 3D pickup item for an arcade kart racer, gritty post-soviet garage style: toy-like chunky proportions, instantly readable silhouette from far away, clean low-poly faces, hand-painted textures, saturated colour with worn edges. Single object, centered, no ground, no background, game-ready.
```

### `item_overclock.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — предмет РАЗГОН МОТОРА
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.9 × 0.7 × 0.6 м (ширина × высота × длина)
- **Дополнительно:** Молния — отдельной деталью.
- **Промпт (619 символов):**

```text
A small electric vacuum-cleaner motor used as a power-up: dark steel cylinder body with five round cooling fins, exposed copper coil winding at one end, a short steel shaft with a small cog, a terminal box on top with one red and one blue screw terminal, a glowing cyan lightning bolt symbol floating beside it. Stylized low-poly 3D pickup item for an arcade kart racer, gritty post-soviet garage style: toy-like chunky proportions, instantly readable silhouette from far away, clean low-poly faces, hand-painted textures, saturated colour with worn edges. Single object, centered, no ground, no background, game-ready.
```

## ГОНКИ — пылесосы соперников (пять разных силуэтов)

### `vac_madk1d.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — пылесос MADK1D (мастер заноса)
- **Приоритет:** B · **режим:** Text to 3D, HD model · **размер в игре:** 1.0 × 0.7 × 1.6 м (ширина × высота × длина)
- **Дополнительно:** Колёса отдельно от корпуса; перед — щётка на трубе.
- **Промпт (670 символов):**

```text
A low sleek canister vacuum cleaner turned into a drift racing kart: light blue shell shaped like a wedge, wide slick rear wheels and small front wheels, a skateboard deck bolted on top as the seat, a curved chrome hose with a floor brush as the steering column, sticker-bombed sides. Stylized low-poly 3D rideable vehicle for an arcade racer, gritty post-soviet garage style: chunky exaggerated proportions, bold readable silhouette, hand-painted textures, worn paint, scratches. Wheels as separate round parts not fused to the body, a flat seat on top for a small rider, front clearly different from back. Single object, centered, no ground, no background, game-ready.
```

### `vac_clipper.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — пылесос КЛИППЕРА (таран)
- **Приоритет:** B · **режим:** Text to 3D, HD model · **размер в игре:** 1.1 × 0.8 × 1.6 м (ширина × высота × длина)
- **Дополнительно:** Бампер-таран спереди; колёса отдельно.
- **Промпт (655 символов):**

```text
A heavy industrial wet-and-dry shop vacuum turned into a ramming kart: tall red steel drum body on four fat rubber wheels, a welded steel bull bar with two spikes on the front, a metal tractor seat on top, a thick black hose coiled on the side, dents and scraped paint. Stylized low-poly 3D rideable vehicle for an arcade racer, gritty post-soviet garage style: chunky exaggerated proportions, bold readable silhouette, hand-painted textures, worn paint, scratches. Wheels as separate round parts not fused to the body, a flat seat on top for a small rider, front clearly different from back. Single object, centered, no ground, no background, game-ready.
```

### `vac_hater.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — пылесос ХЕЙТЕРА (пакостник)
- **Приоритет:** B · **режим:** Text to 3D, HD model · **размер в игре:** 0.9 × 0.8 × 1.5 м (ширина × высота × длина)
- **Дополнительно:** Три колеса; сзади багажник с мелочью.
- **Промпт (658 символов):**

```text
A purple upright stick vacuum cleaner converted into a three-wheeled scooter kart: tall thin body leaning forward, clear dust bin full of grey junk, two small wheels behind and one in front, a plastic stool seat, a rack on the back holding a spray can, a bottle and a bag. Stylized low-poly 3D rideable vehicle for an arcade racer, gritty post-soviet garage style: chunky exaggerated proportions, bold readable silhouette, hand-painted textures, worn paint, scratches. Wheels as separate round parts not fused to the body, a flat seat on top for a small rider, front clearly different from back. Single object, centered, no ground, no background, game-ready.
```

### `vac_bot.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — пылесос БОТА-812 (педант)
- **Приоритет:** B · **режим:** Text to 3D, HD model · **размер в игре:** 1.2 × 0.6 × 1.2 м (ширина × высота × длина)
- **Дополнительно:** Диск; щётки спереди — отдельными деталями.
- **Промпт (676 символов):**

```text
A big round robot vacuum cleaner used as a hover kart: flat green disc body with a raised bumper ring, a small dome sensor on top, two side brushes sticking out in front, a simple square cushion seat in the middle, four tiny wheels underneath, a strip of status lights along the front edge. Stylized low-poly 3D rideable vehicle for an arcade racer, gritty post-soviet garage style: chunky exaggerated proportions, bold readable silhouette, hand-painted textures, worn paint, scratches. Wheels as separate round parts not fused to the body, a flat seat on top for a small rider, front clearly different from back. Single object, centered, no ground, no background, game-ready.
```

### `vac_drey.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — пылесос ДРЕЯ (срезает)
- **Приоритет:** B · **режим:** Text to 3D, HD model · **размер в игре:** 1.0 × 0.8 × 1.7 м (ширина × высота × длина)
- **Дополнительно:** Зубастые колёса отдельно; фара спереди.
- **Промпт (654 символов):**

```text
A soviet cylinder vacuum cleaner on a go-kart frame built for off-road shortcuts: long yellow torpedo-shaped metal body with chrome end caps, knobby tractor tyres, a raised welded tube frame, a bicycle saddle on top, a headlight on the nose, mud splashes on the sides. Stylized low-poly 3D rideable vehicle for an arcade racer, gritty post-soviet garage style: chunky exaggerated proportions, bold readable silhouette, hand-painted textures, worn paint, scratches. Wheels as separate round parts not fused to the body, a flat seat on top for a small rider, front clearly different from back. Single object, centered, no ground, no background, game-ready.
```

## ГОНКИ — трасса и живой мир

### `race_trick_ring.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — кольцо для трюков над трамплином
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 3.4 × 3.4 × 0.4 м (ширина × высота × длина)
- **Дополнительно:** Отверстие сквозное и пустое.
- **Промпт (587 символов):**

```text
A large stunt hoop for jumping through: a ring welded from old truck tyres and steel pipe, painted in red and white stripes, a row of round light bulbs around the front face, two short steel mounting brackets at the bottom. Standing upright, the hole fully open. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `race_grandstand.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — трибуна у старта (на неё ставятся зрители)
- **Приоритет:** B · **режим:** Text to 3D, standard · **размер в игре:** 8.0 × 3.2 × 3.0 м (ширина × высота × длина)
- **Дополнительно:** Скамьи пустые (люди — отдельные модели).
- **Промпт (562 символов):**

```text
A small homemade spectator grandstand: three stepped rows of wooden plank benches on a rusty welded steel frame, a corrugated metal roof on thin posts, a string of triangular flags along the front, an empty banner board on the back rail. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `npc_spectator.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — зритель на трибуне и у трассы (машет, прыгает)
- **Приоритет:** B · **режим:** Text to 3D, HD model, для rigging · **размер в игре:** 0.6 × 1.5 × 0.4 м (ширина × высота × длина)
- **Дополнительно:** Нужен скелет (Mixamo): A-поза, руки в стороны. Одна модель — в игре перекрашивается.
- **Промпт (549 символов):**

```text
A cheerful courtyard spectator: a teenager in a puffy winter jacket, tracksuit trousers and a knitted hat with a pom-pom, holding nothing, mouth open in a shout. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold silhouette, hand-painted textures, muted post-soviet colours with one red accent. Full body, A-pose, arms away from the torso, legs apart, fingers simplified, clean topology at shoulders, elbows, hips and knees for rigging with a humanoid skeleton. Single character, centered, no ground, no background.
```

### `race_start_lights.glb` → `godot/assets/racing/`

- **Для чего:** VACUUM RACING — светофор старта над чертой
- **Приоритет:** B · **режим:** Text to 3D, standard · **размер в игре:** 5.0 × 1.2 × 0.6 м (ширина × высота × длина)
- **Дополнительно:** Пять ламп — отдельными кругами.
- **Промпт (518 символов):**

```text
A racing start light gantry: a horizontal steel truss beam with five big round lamps in black housings in a row, cables hanging between them, two loudspeaker horns on the ends, weathered paint. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

## МИКРОЗАЙМЫ

### `ml_phone.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — телефон Пахана на столе (экран светится от уведомлений)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.08 × 0.012 × 0.16 м (ширина × высота × длина)
- **Дополнительно:** Экран — ровная плоскость сверху (на неё кладётся светящаяся накладка).
- **Промпт (528 символов):**

```text
An old cheap smartphone lying flat: black plastic body with rounded corners, a cracked glass screen with a spider-web crack in one corner, a thick scratched bumper case, a single camera lens on the back. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `ml_cash_stack.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — пачка денег на столе
- **Приоритет:** B · **режим:** Text to 3D, standard · **размер в игре:** 0.16 × 0.05 × 0.08 м (ширина × высота × длина)
- **Дополнительно:** Без цифр и лиц на купюрах.
- **Промпт (507 символов):**

```text
A small stack of worn paper banknotes held together with a rubber band: slightly fanned edges, a few bent corners, greenish-grey colour, blank faces without any numbers or portraits. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `ml_job_trash_set.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — уборка: кучка мусора для всасывания
- **Приоритет:** B · **режим:** Text to 3D, standard · **размер в игре:** 0.5 × 0.25 × 0.5 м (ширина × высота × длина)
- **Дополнительно:** Низкая кучка; предметы различимы.
- **Промпт (512 символов):**

```text
A small pile of stairwell rubbish: crumpled paper cups, cigarette-pack shaped boxes, sunflower seed husks, a squashed drink can, torn flyers and grey dust clumps, loosely heaped together. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `ml_job_phone_open.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — ремонт: разобранный смартфон (сейчас детали — цветные плашки)
- **Приоритет:** A · **режим:** Text to 3D, HD model · **размер в игре:** 0.3 × 0.05 × 0.16 м (ширина × высота × длина)
- **Дополнительно:** Гнёзда пустые: аккумулятор, динамик и шлейф — отдельными моделями ниже.
- **Промпт (605 символов):**

```text
An opened smartphone lying face down with the back cover removed: a dark plastic frame with four tiny screw posts in the corners, a green circuit board, an empty rectangular battery bay, an empty round speaker socket, thin flat ribbon cable sockets, visible but simple components. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `ml_job_part_battery.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — ремонт: аккумулятор (деталь на замену)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.07 × 0.01 × 0.09 м (ширина × высота × длина)
- **Дополнительно:** Плоский прямоугольник.
- **Промпт (529 символов):**

```text
A flat rectangular phone battery: silver foil pouch with a black plastic strip along one short edge, a small gold connector tab, a yellow warning stripe, slightly puffed surface, blank label without text. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `ml_job_part_speaker.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — ремонт: динамик (деталь на замену)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.03 × 0.01 × 0.03 м (ширина × высота × длина)
- **Дополнительно:** Круглая таблетка с хвостиком-шлейфом.
- **Промпт (490 символов):**

```text
A tiny round phone loudspeaker module: a black plastic ring with a fine metal mesh grille in the middle, a short flat orange cable with a gold connector on the side. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `ml_job_part_flex.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — ремонт: шлейф экрана (деталь на замену)
- **Приоритет:** A · **режим:** Text to 3D, standard · **размер в игре:** 0.02 × 0.005 × 0.1 м (ширина × высота × длина)
- **Дополнительно:** Тонкая лента с двумя разъёмами.
- **Промпт (503 символов):**

```text
A flat flexible ribbon cable for a phone screen: a thin orange strip with fine parallel copper traces, an L-shaped bend, a small black connector block with gold pins on each end. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `ml_job_parcel_box.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — доставка: посылка в руках курьера
- **Приоритет:** B · **режим:** Text to 3D, standard · **размер в игре:** 0.4 × 0.3 × 0.3 м (ширина × высота × длина)
- **Дополнительно:** Наклейки без текста.
- **Промпт (504 символов):**

```text
A cardboard delivery parcel: a slightly crushed brown box wrapped with clear tape, a red FRAGILE-style sticker shape without text, a blank white shipping label, one dented corner. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `ml_job_car_dirty.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — новая подработка МОЙКА МАШИН
- **Приоритет:** B · **режим:** Text to 3D, HD model · **размер в игре:** 1.7 × 1.4 × 4.0 м (ширина × высота × длина)
- **Дополнительно:** Обычная легковая машина (сиденье сверху не нужно); грязь — в текстуре.
- **Промпт (604 символов):**

```text
A boxy old soviet-style family sedan covered in dried mud: square headlights, chrome bumpers, thin pillars, steel wheels with small hubcaps, splashes of brown dirt along the sills, wheel arches and rear, dusty windows. Stylized low-poly 3D rideable vehicle for an arcade racer, gritty post-soviet garage style: chunky exaggerated proportions, bold readable silhouette, hand-painted textures, worn paint, scratches. Wheels as separate round parts not fused to the body, a flat seat on top for a small rider, front clearly different from back. Single object, centered, no ground, no background, game-ready.
```

### `ml_job_shelf_rack.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — склад: стеллаж для сортировки
- **Приоритет:** B · **режим:** Text to 3D, standard · **размер в игре:** 1.8 × 2.0 × 0.5 м (ширина × высота × длина)
- **Дополнительно:** Полки пустые.
- **Промпт (509 символов):**

```text
A warehouse storage rack: four steel uprights with punched holes, four plywood shelves, empty, a few scuffs and paint chips, one small blank cardboard tag hanging from each shelf edge. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```

### `npc_neighbor.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — сосед в подъезде и заказчик в подработках
- **Приоритет:** B · **режим:** Text to 3D, HD model, для rigging · **размер в игре:** 0.6 × 1.5 × 0.4 м (ширина × высота × длина)
- **Дополнительно:** Нужен скелет (Mixamo): A-поза.
- **Промпт (544 символов):**

```text
A grumpy stairwell neighbour: an older woman in a flowery housecoat, wool cardigan, thick socks and slippers, a headscarf, round glasses, arms slightly out. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold silhouette, hand-painted textures, muted post-soviet colours with one red accent. Full body, A-pose, arms away from the torso, legs apart, fingers simplified, clean topology at shoulders, elbows, hips and knees for rigging with a humanoid skeleton. Single character, centered, no ground, no background.
```

### `npc_customer.glb` → `godot/assets/minigames/`

- **Для чего:** МИКРОЗАЙМЫ — заказчик (ремонт, доставка, звук)
- **Приоритет:** B · **режим:** Text to 3D, HD model, для rigging · **размер в игре:** 0.6 × 1.5 × 0.4 м (ширина × высота × длина)
- **Дополнительно:** Нужен скелет (Mixamo): A-поза.
- **Промпт (522 символов):**

```text
An impatient customer: a young man in an oversized hoodie, baggy jeans and white sneakers, a cap worn backwards, a small shoulder bag. Stylized low-poly 3D game character, chibi proportions (big head, short limbs), bold silhouette, hand-painted textures, muted post-soviet colours with one red accent. Full body, A-pose, arms away from the torso, legs apart, fingers simplified, clean topology at shoulders, elbows, hips and knees for rigging with a humanoid skeleton. Single character, centered, no ground, no background.
```

## 5 НОЧЕЙ С ПАХАНОМ

### `fn_door_panel.glb` → `godot/assets/minigames/`

- **Для чего:** 5 НОЧЕЙ — панель у проёма с двумя кнопками (дверь и свет)
- **Приоритет:** B · **режим:** Text to 3D, standard · **размер в игре:** 0.3 × 0.7 × 0.1 м (ширина × высота × длина)
- **Дополнительно:** Две кнопки — отдельными выпуклыми деталями.
- **Промпт (558 символов):**

```text
A wall-mounted industrial control box: grey steel housing with rounded corners, one big red mushroom push button on top and one big white round button below, two small indicator lamps, a thick cable conduit going down, chipped paint. Stylized low-poly 3D game asset, gritty post-soviet Russian courtyard style: chunky exaggerated proportions, bold readable silhouette, clean low-poly faces, hand-painted textures, worn paint, rust and grime, muted greys and browns with a few bright red accents. Single object, centered, no ground, no background, game-ready.
```
