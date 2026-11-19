# Промпты для Tripo AI: модели мини-игр

Готовые к копированию промпты для всех моделей «5 НОЧЕЙ С ПАХАНОМ» и «ПАХАН НАБРАЛ МИКРОЗАЙМОВ».
Сейчас на их месте стоят модели, собранные кодом. Игра сама подхватит файл владельца: положи `.glb` с именем из
таблицы в `godot/assets/minigames/` — код менять не нужно (`MGModels.spawn`: модель вписывается в нужный размер и
доворачивается лицом).

## Как генерировать

- Один промпт — одна модель. Копировать блок целиком (в нём уже есть общий стиль).
- Настройки Tripo: текстуры включены (PBR), детализация обычная, около 6 000 полигонов на предмет
  (персонажам — до 12 000). Больше не нужно: в кадре они мелкие или в темноте.
- Скачивать в **GLB**. Имя файла — ровно как в заголовке (`fn_arcade_cabinet.glb`).
- В поле «негативный промпт» (если есть) — строка из раздела «Чего не должно быть».
- Предметы: один объект в кадре, без пола и фона. Лицевая сторона — куда «смотрит» модель в окне Tripo
  (игра сама повернёт).
- **Персонажи-хорроры** (шесть штук): нужны руки и ноги и **скелет Mixamo** (кости `mixamorig:*`) — как у моделей
  героев и врагов в `godot/assets/models/`. Поза при генерации — A-поза. Без скелета модель не оживёт: анимации
  «5 ночей» ставятся на кости Mixamo.
- Не нравится результат — перегенерируй тот же промпт: имя файла то же, игра возьмёт новый.

### Чего не должно быть (негативный промпт)

```
photorealistic, photo scan, realistic photograph, blurry, noisy mesh, readable text, letters, logos, brand names, watermark, multiple separate objects, floor plane, background scenery
```

## Порядок

1. **Сначала** (сильнее всего меняют картинку): `fn_arcade_cabinet`, `fn_server_rack`, `fn_mascot_shelf`,
   `fn_generator`, шесть `fn_horror_*`, `ml_desk`, `ml_armchair`, `ml_laptop`.
2. **Потом**: `fn_party_table`, `fn_stage_speaker`, `fn_prize_counter`, `ml_wardrobe`, `ml_fridge`,
   `ml_job_console`, `ml_job_mixer`.
3. **Вторая очередь** (слота в игре ещё нет — подключу, когда пришлёшь): `fn_security_desk`, `ml_sofa_bed`,
   `ml_job_amp`, `ml_job_parcel_cart`, `ml_job_old_tv`, `ml_job_radio`, `ml_job_junk_crate`.

---

## «5 НОЧЕЙ С ПАХАНОМ» — помещения

### `fn_arcade_cabinet.glb` — игровой автомат (0,8 × 1,9 × 0,9 м), игровая зона

```
A battered upright retro arcade cabinet from a run-down 1990s family entertainment center. Tall boxy wooden body with a slanted top marquee, a deep-set dark CRT screen with a thick plastic bezel, a slanted control panel with one ball-top joystick and six round buttons, two coin slots and a dented coin door at the bottom, side panels covered in chipped paint and half-peeled faded stickers, cigarette burns on the control panel, scuffed black kick plate, dust in the corners. The screen is switched off and reflects nothing. Colors: black and dirty off-white body, grey metal, a few strong red accents on the buttons and marquee stripe. Stylized low-poly 3D game asset for a dark manga-grunge horror game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint, scratches and grime, game-ready, single object centered on its own, no ground, no background.
```

### `fn_server_rack.glb` — серверная стойка (0,7 × 2,1 × 1,0 м), серверная

```
A tall black server rack cabinet from an old data room. Heavy steel frame on four small leveling feet, a perforated metal front door with a cracked smoked-glass window standing slightly ajar, eight stacked rack-mounted servers with rows of tiny square indicator lights, drive bays and ventilation slots, a patch panel near the top with a messy bundle of red and grey cables spilling out and hanging down one side, a side panel with a peeling warning triangle sticker, dust on the top, a strip of old yellowed tape. Colors: matte black and dark grey metal, off-white cables, small red indicator accents. Stylized low-poly 3D game asset for a dark manga-grunge horror game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint, scratches and grime, game-ready, single object centered on its own, no ground, no background.
```

### `fn_mascot_shelf.glb` — стеллаж с головами маскотов (2,2 × 2,0 × 0,7 м), склад

```
A wide industrial metal storage shelf unit with four shelves, packed with discarded cartoon mascot costume parts from a closed children's entertainment center. On the shelves: five oversized empty mascot heads with big round hollow eye holes and frozen wide grins (a bear, a rabbit, a cat, a round-headed boy and a robot), a pile of detached plush arms and gloved hands, a limp fur costume torso folded over the edge, a cardboard box of spare eyes and noses, a coiled extension cord, a dusty spare party hat. One head is turned so that it faces straight forward. Everything is dusty, faded and slightly stained, some fur is matted and torn. Colors: grey metal shelf, off-white and dirty beige costumes, black eye holes, a few red bow ties and noses. Stylized low-poly 3D game asset for a dark manga-grunge horror game: chunky slightly exaggerated chibi-friendly proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint, scratches and grime, game-ready, single object centered on its own, no ground, no background.
```

### `fn_generator.glb` — генератор со щитком (1,4 × 1,3 × 0,9 м), комната питания

```
An old industrial backup power generator combined with a wall-style fuse box on a single welded steel skid frame. Left side: a heavy engine block with cooling fins, a round fuel tank on top with a screw cap, an exhaust pipe with a small muffler, a pull-start handle on a cord and a large hand crank wheel on the front. Right side: a tall grey electrical cabinet with its door hanging open, rows of chunky ceramic fuses and knife switches inside, one big red main lever, an analog voltage gauge with a cracked glass, thick black cables running from the engine into the cabinet. Oil stains, rust streaks, chipped paint, a rag hanging off the frame. Colors: dark grey and black metal, off-white cabinet interior, red lever and red warning stripe. Stylized low-poly 3D game asset for a dark manga-grunge horror game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint, scratches and grime, game-ready, single object centered on its own, no ground, no background.
```

### `fn_party_table.glb` — стол праздника (2,0 × 0,9 × 1,0 м), главный зал

```
A long rectangular children's party table abandoned mid-celebration. Folding table with thin metal legs, covered with a stained paper tablecloth hanging unevenly over the edges. On the table: a half-eaten round birthday cake on a cardboard base with one slice missing and five burnt-down candles, seven cone-shaped paper party hats (two knocked over), paper plates with dried crumbs, plastic cups, a spilled cup with a dried puddle, a few curled party streamers, two half-deflated balloons tied to the table edge and sagging down. Everything looks like it has been left untouched for years: dusty, faded, slightly yellowed. Colors: off-white tablecloth, grey dust, black table legs, red party hats and red cake icing. Stylized low-poly 3D game asset for a dark manga-grunge horror game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint, scratches and grime, game-ready, single object centered on its own, no ground, no background.
```

### `fn_stage_speaker.glb` — сценическая колонка (0,8 × 1,6 × 0,6 м), главный зал

```
A tall worn stage loudspeaker cabinet mounted on a black tripod speaker stand. Trapezoid-shaped wooden cabinet covered in scuffed black vinyl with metal corner protectors, a large round woofer and a horn tweeter behind a torn grille cloth that hangs loose at one corner, a recessed carrying handle on the side, a back panel with two round jack sockets and a volume knob, a thick black cable dangling from the back and coiled once around the stand, strips of old gaffer tape, a dent on the top edge. Colors: black cabinet, dark grey metal stand, off-white dusty speaker cone, one red indicator dot. Stylized low-poly 3D game asset for a dark manga-grunge horror game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint, scratches and grime, game-ready, single object centered on its own, no ground, no background.
```

### `fn_prize_counter.glb` — прилавок призов с задней стенкой (2,3 × 2,2 × 0,8 м), игровая зона

```
A prize redemption counter from a shabby arcade. A long waist-high counter with a scratched glass display front and a laminate top, inside the glass case three shelves of cheap dusty prizes: small plush toys, plastic rings, bouncy balls, toy cars, a row of rubber ducks. On top of the counter: an old ticket-eating machine with a slot, a roll of paper tickets unspooling over the edge, a small bell, a jar of lollipops. Behind the counter rises a tall back wall panel (the whole piece is about as tall as it is wide) with pegs and two shelves holding large sad-looking plush toys, three of them hanging by their necks. Chipped corners, yellowed plastic, tape repairs, dust. Colors: black and dirty off-white counter, grey metal trim, faded toys with a few red ones standing out. Stylized low-poly 3D game asset for a dark manga-grunge horror game: chunky slightly exaggerated chibi-friendly proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint, scratches and grime, game-ready, single object centered on its own, no ground, no background.
```

### `fn_security_desk.glb` — пульт охранника (2,4 × 1,1 × 1,0 м), будка — вторая очередь

```
A cluttered night-guard security desk from a cheap entertainment center. A thick dented metal desk with a drawer pedestal on one side, on top of it two bulky beige CRT monitors of different sizes sitting on yellowed plastic bases, a chunky mechanical keyboard with a missing key, a small oscillating desk fan with a wire cage, an old rotary telephone with a coiled cord, three stained coffee cups, an overflowing ashtray, scattered loose papers and a clipboard, a ring of keys, and a control panel with rows of toggle switches and one large red emergency mushroom button under a flip-up cover. Cables hang down behind the desk. Colors: grey metal desk, dirty off-white plastic, black cables, red button and red phone. Stylized low-poly 3D game asset for a dark manga-grunge horror game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint, scratches and grime, game-ready, single object centered on its own, no ground, no background.
```

---

## «5 НОЧЕЙ С ПАХАНОМ» — хоррор-версии обитателей

Всем: A-поза, руки и ноги есть, один персонаж в кадре, потом — скелет Mixamo. Рост в игре — около 1,6–1,7 м
(БАЛОН — 1,4 м). Общий стиль уже вписан в каждый промпт.

### `fn_horror_balon.glb` — БАЛОН VOZDUH, лицо «Облака»

```
A horror animatronic mascot built around a tall black pressurized gas cylinder as its body and head in one piece. The cylinder has a crude hand-painted white cartoon face on its upper part: two round uneven eyes with tiny pinpoint pupils and a too-wide smile with individually painted teeth, the paint is cracked and dripping. A brass valve with a red hand wheel sits on top like a hat, thin white vapor leaks from it. Short jointed mechanical arms with three-fingered metal claw hands are bolted to the sides, and two stubby mechanical legs with heavy flat feet are bolted underneath. Dents, rust rings, scratched warning stripes, a frayed party bow tie tied around the "neck". It stands unnaturally still. Colors: black cylinder, off-white face paint, grey bare metal joints, red valve wheel and red bow tie. Stylized low-poly horror game character in a dark manga-grunge style: chibi proportions pushed into something wrong, cracked paint, exposed wires and bolts, glossy dead eyes, unsettling but still readable silhouette, humanoid with two arms and two legs, standing in a stiff A-pose, game-ready, single character centered, no ground, no background.
```

### `fn_horror_madk1d.glb` — MADK1D, ползает по вентиляции

```
A horror animatronic version of a chibi teenage rapper. Oversized head with a huge messy black curly hair wig that is slipping off to one side and reveals a cracked plastic skull plate with a seam and screws underneath. One eye is a glossy cartoon eye stuck staring straight ahead, the other is a cracked camera lens with a faint red glow. The lower jaw hangs open on a broken hinge showing a dark speaker grille inside the mouth. Thin body in a torn oversized black hoodie and baggy shorts, the fabric ripped at the elbows and knees to show metal joints and bundles of red and black wires, long thin arms that reach below the knees with dirty white gloves, scuffed chunky sneakers. Dust and cobwebs on the shoulders as if it has been crawling through vents. Colors: black hoodie and hair, dirty off-white plastic face and gloves, grey metal, red wires and red lens glow. Stylized low-poly horror game character in a dark manga-grunge style: chibi proportions pushed into something wrong, cracked plastic and torn fabric, exposed wires and stitches, glossy dead eyes, unsettling but still readable silhouette, humanoid with two arms and two legs, standing in a stiff A-pose, game-ready, single character centered, no ground, no background.
```

### `fn_horror_bot.glb` — BOT, требует ответа на пинг

```
A horror robot mascot with an old boxy CRT television for a head. The screen shows a fixed simple smiling face made of thick glowing lines on a static-noise background, the smile slightly too wide, the glass cracked from one corner. Two bent rabbit-ear antennas on top, a dangling power cord with a plug trailing from the back of the head like a tail. A long thin black neck made of a bundle of cables, narrow shoulders in a stained off-white button-up work shirt with a crooked name badge and a loose black tie, long skinny arms ending in rubber-gloved hands with too-long fingers, thin legs in black trousers and scuffed office shoes. One shoulder sits lower than the other, the posture is polite and wrong. Colors: black cables and trousers, yellowed off-white TV plastic and shirt, grey static screen, red indicator light on the TV and a red stain on the cuff. Stylized low-poly horror game character in a dark manga-grunge style: chibi proportions pushed into something wrong, cracked plastic and torn fabric, exposed wires and stitches, unsettling but still readable silhouette, humanoid with two arms and two legs, standing in a stiff A-pose, game-ready, single character centered, no ground, no background.
```

### `fn_horror_clipper.glb` — CLIPPER, самый быстрый

```
A horror stylized service robot built to cut and trim. A narrow wedge-shaped head with a single large round camera lens for a face, the lens ringed with scratches and glowing dull red in the center, two small side sensors like extra eyes. A lean hunched torso made of ribbed black plating with exposed red cables running along the limbs like veins. The right arm ends in long blade-like scissor fingers, each as long as its forearm, slightly open; the left arm is a normal three-fingered mechanical hand twitching half closed. Digitigrade-looking but still humanoid legs with spring pistons and narrow clawed feet built for sprinting. Dried dark stains on the blades, hazard stripes worn off the shoulders, a cracked chest panel with a small fan behind it. Colors: matte black plating, grey bare steel blades, off-white worn hazard paint, red cables and red lens. Stylized low-poly horror game character in a dark manga-grunge style: wrong elongated proportions, cracked plating, exposed wires, unsettling but still readable silhouette, humanoid with two arms and two legs, standing in a stiff A-pose, game-ready, single character centered, no ground, no background.
```

### `fn_horror_ghost.glb` — GHOST, не любит, когда на него смотрят

```
A horror skeletal ghost figure in a torn oversized black hoodie. The hood is up and deep; inside it a cracked bone-white skull face with empty dark eye sockets holding two tiny glowing pinpoint lights, a long vertical crack running from the forehead through one socket, the jaw slightly dislocated to one side in a silent scream. The hoodie hangs in long ragged strips at the hem and sleeves as if dissolving, the ribcage is visible through a tear in the chest. Thin skeletal hands with long finger bones hang out of the sleeves, thin bone legs in shredded black trousers, bare bone feet. Faint wisps of smoke shapes trail off the shoulders and the hem. The whole figure leans a little forward. Colors: black fabric, bone off-white, grey shadows, faint red glow deep in the eye sockets. Stylized low-poly horror game character in a dark manga-grunge style: chibi proportions pushed into something wrong, cracked bone and torn fabric, unsettling but still readable silhouette, humanoid with two arms and two legs, standing in a stiff A-pose, game-ready, single character centered, no ground, no background.
```

### `fn_horror_mod.glb` — MOD, ломает систему

```
A horror chat moderator mascot from a dead online service. A large perfectly round glossy plastic head with a flat painted face: two small square eyes and a thin straight mouth, one eye flickering like a broken pixel, a big crude red hammer symbol painted across the forehead with paint running down over one eye. A hairline crack splits the head from top to chin and a strip of grey tape holds it together. Stocky body in an off-white short-sleeved uniform shirt with a black armband and a lanyard with a blank badge, black trousers with a heavy key ring. In one hand it holds an oversized cartoonish judge's mallet with a red head, chipped and stained; the other hand is a white cartoon glove with only four fingers pointing accusingly. Thick short legs, heavy black boots. Colors: off-white plastic and shirt, black trousers and boots, grey tape, red hammer symbol and red mallet. Stylized low-poly horror game character in a dark manga-grunge style: chibi proportions pushed into something wrong, cracked plastic, glossy dead eyes, unsettling but still readable silhouette, humanoid with two arms and two legs, standing in a stiff A-pose, game-ready, single character centered, no ground, no background.
```

---

## «ПАХАН НАБРАЛ МИКРОЗАЙМОВ» — комната

### `ml_desk.glb` — письменный стол (1,6 × 0,8 × 0,8 м)

```
A worn wooden writing desk from a cramped post-soviet apartment. Thick rectangular tabletop with rounded worn edges, a pedestal with three drawers on the right side (the middle drawer slightly open), plain square legs on the left, a kick-scuffed front panel. Scratched and peeling lacquer, ring stains from cups, a burn mark, old stickers and a strip of tape on the side panel, a wobbly leg propped with a folded piece of cardboard. The tabletop is empty and flat so that other objects can be placed on it. Colors: warm brown worn wood, darker edges, grey metal drawer handles, one red sticker. Stylized low-poly 3D game asset of a cramped post-soviet Russian apartment: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, warm worn wood, scuffed surfaces, cosy but messy, game-ready, single object centered on its own, no ground, no background.
```

### `ml_armchair.glb` — кресло (0,9 × 1,0 × 0,9 м)

```
An old soft armchair from a post-soviet apartment. Low wide boxy shape with thick rounded padded armrests and a tall slightly reclined back, short dark wooden legs. Faded checkered upholstery worn shiny on the armrests, a large stitched patch on the seat cushion, a sagging dent where someone always sits, a crocheted blanket thrown over the back and hanging down one side, a small round cushion tucked in the corner, loose threads and one visible spring poking the fabric near the bottom. Colors: faded brown and beige check, grey blanket, dark wood legs, a red patch and red blanket border. Stylized low-poly 3D game asset of a cramped post-soviet Russian apartment: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, faded fabric, cosy but messy, game-ready, single object centered on its own, no ground, no background.
```

### `ml_laptop.glb` — ноутбук (0,36 × 0,25 × 0,26 м)

```
An old chunky budget laptop opened at about 110 degrees. Thick black plastic body with rounded corners, a wide bezel around a plain dark flat screen (the screen surface must be flat and empty, without any picture), a full keyboard with one missing keycap and worn shiny keys, a small trackpad with two buttons, side ports and a bulky hinge. The lid back is covered with overlapping half-peeled stickers, one corner is cracked and held with tape, a charger plug sticks out of the side with a short piece of cable. Greasy fingerprints and dust between the keys. Colors: scratched black plastic, grey keyboard wear, off-white tape, a couple of red stickers. Stylized low-poly 3D game asset of a cramped post-soviet Russian apartment: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, scuffed plastic, game-ready, single object centered on its own, no ground, no background.
```

### `ml_wardrobe.glb` — шкаф (1,2 × 2,0 × 0,6 м)

```
A tall soviet lacquered wardrobe with two doors. Glossy dark brown veneer with visible wood grain and worn edges, a tall narrow mirror on the left door with a spotted tarnished surface, small round brass knobs, a low plinth base. The right door stands slightly open and a sleeve of a black tracksuit jacket and a hanger stick out. On top of the wardrobe: two old suitcases stacked, a cardboard box tied with string and a rolled-up carpet. A calendar page and a couple of stickers are stuck on the side, the lacquer is chipped near the bottom. Colors: dark warm brown lacquer, grey dull mirror, beige suitcases, a red sticker and a red stripe on the jacket sleeve. Stylized low-poly 3D game asset of a cramped post-soviet Russian apartment: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, warm worn wood, cosy but messy, game-ready, single object centered on its own, no ground, no background.
```

### `ml_fridge.glb` — холодильник (0,6 × 1,5 × 0,6 м)

```
A small old soviet-era refrigerator with strongly rounded corners. One large door and a small freezer door on top, a long chrome pull handle, a chrome badge plate without any text, short black feet. Yellowed off-white enamel with chips and rust spots along the bottom edge, a dent on the side, the door covered with colourful fridge magnets, a sticky note, a child's drawing held by a magnet and a paper bill pinned under another. On top of the fridge: a small potted cactus, a jar and a folded newspaper. Colors: yellowed off-white enamel, chrome grey handle, black feet, red and a few other small bright magnets. Stylized low-poly 3D game asset of a cramped post-soviet Russian apartment: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, scuffed enamel, cosy but messy, game-ready, single object centered on its own, no ground, no background.
```

### `ml_sofa_bed.glb` — диван-кровать (1,9 × 0,9 × 0,9 м) — вторая очередь

```
A folding sofa bed from a post-soviet one-room apartment, unfolded halfway into a bed. Boxy wooden armrests with worn lacquer, thick seat and back cushions in worn brown ribbed fabric with a sagging middle, a crumpled grey blanket half pulled off, a flattened pillow in a striped pillowcase, a phone charger cable lying on the armrest, a sock on the floor edge of the frame, one cushion corner torn with yellow foam showing. Colors: worn brown fabric, grey blanket, off-white pillow, dark wood armrests, one red stripe on the blanket. Stylized low-poly 3D game asset of a cramped post-soviet Russian apartment: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, faded fabric, cosy but messy, game-ready, single object centered on its own, no ground, no background.
```

---

## «ПАХАН НАБРАЛ МИКРОЗАЙМОВ» — подработки

### `ml_job_console.glb` — разобранная приставка (0,32 × 0,08 × 0,22 м), ремонт

```
A home video game console lying flat with its top cover removed, seen as a repair job on a workbench. Low rectangular black plastic case with rounded corners and ventilation slots on the sides, the open top showing a green circuit board with clearly separated chunky parts: a round cooling fan, a finned metal heatsink, a rectangular optical drive, a flat ribbon cable, a power supply block and a row of ports at the back. Four screw posts in the corners, a little dust and a burnt dark spot near one capacitor. Parts are large and readable, not tiny. Colors: black case, dark green board, grey metal heatsink and drive, off-white ribbon cable, one red wire. Stylized low-poly 3D game asset for a dark manga-grunge game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, scuffed plastic, game-ready, single object centered on its own, no ground, no background.
```

### `ml_job_mixer.glb` — микшерный пульт (0,6 × 0,12 × 0,45 м), звукарь

```
A compact analog audio mixing console for small live events. A slanted wedge-shaped metal body with wooden side cheeks, six channel strips each with a row of four coloured rotary knobs, a mute button and a long vertical fader with a chunky cap, a master section on the right with two big faders and two analog VU meters with needles, a row of round input jack sockets and XLR sockets along the back edge. Worn paint around the faders, strips of masking tape under the channels for labels (blank, no text), a coffee ring, one knob cap missing. Colors: black and dark grey metal, warm brown wooden sides, off-white tape and fader caps, red master fader caps and red peak lights. Stylized low-poly 3D game asset for a dark manga-grunge game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint and scratches, game-ready, single object centered on its own, no ground, no background.
```

### `ml_job_amp.glb` — комбо-усилитель (0,5 × 0,45 × 0,3 м), звукарь — вторая очередь

```
A small guitar amplifier combo from a rehearsal basement. Boxy cabinet covered in scuffed black vinyl with metal corner protectors, a front grille cloth with a woven pattern and a small tear, a top control panel with six chunky chicken-head knobs, an input jack and a red jewel power light, a thick leather carrying handle on top, rubber feet, a power cable wrapped around the back. Stickers half peeled off the side, a cigarette burn on the top. Colors: black vinyl, grey-beige grille cloth, chrome grey panel, off-white knobs, red power light. Stylized low-poly 3D game asset for a dark manga-grunge game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint and scratches, game-ready, single object centered on its own, no ground, no background.
```

### `ml_job_parcel_cart.glb` — тележка курьера (0,6 × 1,1 × 0,5 м), доставка — вторая очередь

```
A courier hand truck (two-wheeled upright trolley) loaded with parcels. A tubular steel frame with two rubber wheels and a flat toe plate, three taped cardboard boxes of different sizes stacked on it and held with a stretched bungee cord with hooks, the top box slightly crushed at one corner, fragile-style arrow marks and blank shipping labels on the boxes (no readable text), a roll of packing tape hanging on the handle, mud splashes on the wheels. Colors: grey scratched steel frame, brown cardboard, black rubber wheels, off-white labels, red bungee cord and red tape stripes. Stylized low-poly 3D game asset for a dark manga-grunge game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint and scratches, game-ready, single object centered on its own, no ground, no background.
```

### `ml_job_old_tv.glb` — старый телевизор (0,55 × 0,45 × 0,45 м), ремонт и хлам — вторая очередь

```
An old wooden-case CRT television set from a soviet apartment. A boxy cabinet with wood veneer sides, a strongly curved grey glass screen with a thick rounded plastic frame, a control strip on the right with two large rotary channel knobs, three small knobs and a speaker grille, bent rabbit-ear antennas on top with a piece of foil wrapped around one, a lace doily under a small ceramic figurine on the top, four short tapered legs. Scratches, a chipped corner, dust on the screen. The screen is off. Colors: warm brown veneer, grey screen, off-white doily, black knobs, one red indicator dot. Stylized low-poly 3D game asset for a dark manga-grunge game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, warm worn wood, scuffed plastic, game-ready, single object centered on its own, no ground, no background.
```

### `ml_job_radio.glb` — кассетный магнитофон (0,45 × 0,3 × 0,15 м), хлам — вторая очередь

```
A retro soviet portable radio cassette player. A wide horizontal body with a folding carrying handle, two large round speaker grilles with chrome rings, a cassette door in the center with a small window, a row of six chunky piano-style buttons under it, a tuning dial with a scale strip (marks only, no readable numbers), two sliders, a telescopic antenna pulled out at an angle. Scuffed corners, a cracked cassette window, a missing button cap, a strap of tape holding the battery cover. Colors: black and dark grey plastic, chrome grey rings, off-white dial strip, red tuning needle and red record button. Stylized low-poly 3D game asset for a dark manga-grunge game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, scuffed plastic, game-ready, single object centered on its own, no ground, no background.
```

### `ml_job_junk_crate.glb` — ящик с хламом (0,6 × 0,45 × 0,45 м), хлам — вторая очередь

```
A rough wooden crate overflowing with household junk. Slatted plank sides with rope handles and bent nails, inside a jumble of clearly separate chunky items: a nest of tangled cables, an old push-button phone, a broken plastic toy robot, a dented electric kettle, a stack of magazines tied with string, a desk lamp with a bent neck sticking out, a single boot, a small radio speaker. Items poke out above the rim so the silhouette is uneven. Dust, cobwebs in one corner, a damp stain on one plank. Colors: grey-brown worn wood, black cables, off-white plastic junk, one red toy and a red kettle lid. Stylized low-poly 3D game asset for a dark manga-grunge game: chunky slightly exaggerated proportions, bold readable silhouette, clean low-poly faces with hand-painted textures, worn paint and grime, game-ready, single object centered on its own, no ground, no background.
```

---

## Когда модели готовы

1. Положить файлы в `godot/assets/minigames/` (имена — как в заголовках).
2. Прислать или закоммитить — я проверю импорт (сжатие текстур VRAM, предел 1024), посадку по размеру, поворот и
   вид в комнатах на снимках (`--fivenightscheck`, `--microloanscheck`, `--uicheck`), подключу модели второй очереди.
3. Хоррор-персонажам проверю кости Mixamo и позы (крадётся, рывок у двери, скример).

Тот же список в машинном виде (для генерации скриптом по ключу) — `tools/tripo-minigames.json`.
