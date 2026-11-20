# ГОЛДА 67 — графика от владельца: список и промпты

Правило владельца (2026-11-20): **всю графику делает владелец** — иконки, элементы интерфейса, фоны экранов,
постеры, логотипы, надписи, текстуры. Я определяю, что нужно, и готовлю промпты партиями; изображения сам не
генерирую, чужие и временные картинки как финальные не ставлю, окончательную интеграцию начинаю после получения
файлов. **3D-модели — в `ASSET_REQUESTS.md`; и на 2D, и на 3D промпт — до 1000 символов.**

Куда класть файлы: `godot/assets/golda67/ui/<имя файла>` (имена — в таблицах ниже). До получения файла в игре
стоит значок, нарисованный кодом (`MGIcon`), помеченный как временный.

## 1. Единый стиль

Вырезанная из бумаги наклейка: толстый неровный чёрный контур, рваный бумажный край, грубый полутон точками,
зернистость ксерокса — как рваные плашки главного меню и чёрно-бело-красные карточки обучения. Палитра на один
значок: бумага `#ece6d8`, чёрный `#111111` и **один** акцент. Золото `#e0b040` — награда и «67»; красный
`#d8322c` — бой и опасность; бордовый `#7a1f2b` — Миша; зелёный `#5fd08a` — лечение; бирюзовый `#3fc7c9` —
DJ FLÜRR; песочный `#c9a36b` — КРОТ. Текста на картинках нет (его накладывает игра), кроме «67» на монете и
логотипа.

Технические параметры иконок: PNG, 1024×1024, 1:1, прозрачный фон, объект по центру, поля 8–10% от края.

## 2. Полный список графики этапа ДВОР

### A. Иконки

| Приоритет | Что | Когда промпты | Получено |
|---|---|---|---|
| P0 | 5 фитсов семейства Миши | партия 1 (G67-I01…I05) | нет |
| P0 | 8 типов комнат | партия 1 (G67-I06…I13) | нет |
| P0 | 2 валюты: голда и РЕСПЕКТ | партия 1 (G67-I14, I15) | нет |
| P0 | «КРОТ НАЙДЕН», «НОВЫЙ РАЗГОВОР» | партия 1 (G67-I16, I17) | нет |
| P0 | 18 артефактов | партия 2 | нет |
| P1 | 3 товара «ШАУРМА 67»: шаурма, двойная шаурма, с собой | партия 3 | нет |
| P1 | Рамки редкости: обычный, редкий, событийный (подложка под иконку артефакта и фитса) | партия 3 | нет |
| P1 | Значки состояний: замок «закрыто», «слот артефакта пуст», «улучшение куплено» | партия 3 | нет |

### B. Экраны подъезда

| Приоритет | Что | Когда промпты | Получено |
|---|---|---|---|
| P1 | Доска маршрутов: рисованная схема двора (вид сверху, шесть зон) | партия 4 | нет |
| P1 | «АВТОРИТЕТ РАЙОНА»: разворот тетради в клетку (фон экрана улучшений) | партия 4 | нет |
| P1 | «АРХИВ ПИЗДЕЦА»: картонная папка-скоросшиватель (обложка и фон списка) | партия 4 | нет |
| P1 | Витрина артефактов: полка серванта (фон экрана коллекции) | партия 4 | нет |
| P2 | Доска объявлений: 4–5 листков разного вида (пустые, текст накладывает игра) | партия 5 | нет |
| P2 | Заставка телевизора «ОБЛАКО-ТВ. НОВОСТИ ДВОРА» | партия 5 | нет |

### C. Магазин и забег

| Приоритет | Что | Когда промпты | Получено |
|---|---|---|---|
| P1 | Меню «ШАУРМА 67»: световой короб-меню (фон окна магазина, без текста) | партия 4 | нет |
| P1 | Карточка фитса: подложка семейства Миши (бордовый с золотом) | партия 3 | нет |
| P1 | Плашка выхода босса «МИША МИНАСЯН» (рваная лента под имя, текст накладывает игра) | партия 3 | нет |
| P2 | Экран итогов забега: фон (чек из ларька / протокол) | партия 5 | нет |

### D. Логотипы и надписи

| Приоритет | Что | Когда промпты | Получено |
|---|---|---|---|
| P0 | Логотип «ГОЛДА 67» (карточка режима, заставка входа, итоги) | партия 2 | нет |
| P1 | Эмблема «67» в круге (золотая печать турнира) | партия 2 | нет |
| P2 | Вывеска «ШАУРМА 67» для светового короба ларька | партия 5 | нет |
| P2 | Граффити двора: четыре надписи и секретная «ПАХАН + MADK1D БЫЛИ ТУТ» (сейчас — текстом из кода) | партия 5 | нет |
| P2 | Баннер Миши на борту коробки, афиша турнира «ГОЛДА 67» | партия 5 | нет |

### E. Текстуры двора (этап 5 — полировка)

| Приоритет | Что | Когда промпты | Получено |
|---|---|---|---|
| P2 | Утоптанный снег с грязью (бесшовная, 1024) | партия 6 | нет |
| P2 | Старый асфальт с трещинами и заплатами (бесшовная, 1024) | партия 6 | нет |
| P2 | Колеи и следы шин (полоса с прозрачностью) | партия 6 | нет |
| P2 | Лёд хоккейной коробки с царапинами коньков (бесшовная, 1024) | партия 6 | нет |
| P2 | Пятна: лужа, масло, песок с солью (с прозрачностью) | партия 6 | нет |

Уже есть и заново не нужно: обложка плейлиста «Любимые треки Пахана» (`playlist/cover.webp`), карточка режима
в «ВЫБОРЕ РЕЖИМА» (сцена из настоящих моделей), портреты и карточки стилей боевого HUD.

## 3. Партия 1 — 17 иконок (P0)

Каждый промпт самостоятельный: копируется целиком. Если генератор не умеет прозрачный фон — заменить последнюю
фразу на «Plain flat solid magenta #ff00ff background», фон уберу сам.

### Иконки фитсов (семейство МИША МИНАСЯН)

**G67-I01 · ТЯЖЁЛАЯ РУКА**
- Файл: `icon_fit_heavy_hand.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор фитса, список фитсов в HUD и паузе

```
A huge clenched fist seen from the front wearing a chunky gold signet ring, thick wrist with a tracksuit cuff with three stripes, short impact lines around the knuckles. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color gold #e0b040. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I02 · АВТОРИТЕТ**
- Файл: `icon_fit_authority.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор фитса, список фитсов

```
A flat cap (Soviet-style eight-panel cap) sitting on top of a simple heavy crown, symbol of a neighbourhood boss, sturdy and wide shape. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color gold #e0b040. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I03 · ЦЕПЬ НА УДАЧУ**
- Файл: `icon_fit_gold_chain.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор фитса, список фитсов

```
A thick gold chain necklace forming a closed loop with big chunky links and a round blank medallion hanging at the bottom, two small sparkle marks. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color gold #e0b040. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I04 · ДОБИВАЛА**
- Файл: `icon_fit_finisher.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор фитса, список фитсов

```
A heavy boot stomping down on a cracked asphalt slab, with a small plus-shaped medical cross rising from the crack, meaning health gained from a finishing blow. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color red #d8322c. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I05 · ВТОРОЕ ДЫХАНИЕ (редкий)**
- Файл: `icon_fit_second_wind.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор фитса, список фитсов

```
A pair of stylized lungs with a strong swirl of air blowing upward through them, one small star mark in the corner showing rarity. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color green #5fd08a. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

### Иконки типов комнат

**G67-I06 · БОЙ**
- Файл: `icon_room_battle.png` · PNG 1024×1024, прозрачный фон
- Где используется: ворота выбора маршрута, доска маршрутов, строка HUD

```
Two crossed fists colliding knuckle to knuckle with a jagged impact burst between them. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color red #d8322c. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I07 · ЭЛИТА**
- Файл: `icon_room_elite.png` · PNG 1024×1024, прозрачный фон
- Где используется: ворота выбора, доска маршрутов

```
An angry skull wearing a flat cap with a three-point crown mark above it, heavy brow, tough and dangerous look. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color orange #ff8c26. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I08 · ФИТС**
- Файл: `icon_room_fit.png` · PNG 1024×1024, прозрачный фон
- Где используется: ворота выбора, доска маршрутов

```
A studio condenser microphone with two overlapping sound wave arcs on each side, symbol of a guest feature on a track. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color gold #e0b040. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I09 · КЛАДОВКА**
- Файл: `icon_room_storage.png` · PNG 1024×1024, прозрачный фон
- Где используется: ворота выбора, доска маршрутов

```
A dented old metal storage locker door slightly open with a padlock hanging unlocked and a warm light leaking out of the gap. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color sand brown #c9a36b. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I10 · ЛАРЁК**
- Файл: `icon_room_kiosk.png` · PNG 1024×1024, прозрачный фон
- Где используется: ворота выбора, доска маршрутов

```
A wrapped shawarma roll in paper held upright, steam lines above it, chunky and appetizing, simple shapes. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color orange #ff8c26. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I11 · ПЕРЕДЫШКА**
- Файл: `icon_room_break.png` · PNG 1024×1024, прозрачный фон
- Где используется: ворота выбора, доска маршрутов

```
A simple courtyard bench seen from the front with a small thermos and a steaming cup standing on it. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color green #5fd08a. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I12 · СОБЫТИЕ**
- Файл: `icon_room_event.png` · PNG 1024×1024, прозрачный фон
- Где используется: ворота выбора, доска маршрутов

```
A torn paper notice pinned with a pushpin, with a big bold exclamation-style blot shape made of ink (an abstract mark, not a character) in the middle. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color teal #3fc7c9. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I13 · БОСС**
- Файл: `icon_room_boss.png` · PNG 1024×1024, прозрачный фон
- Где используется: ворота выбора, доска маршрутов

```
A heavy throne made of stacked car tyres and a wooden pallet, with a thick chain draped over the backrest, menacing and wide. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color burgundy #7a1f2b. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

### Валюты и индикаторы

**G67-I14 · ГОЛДА (валюта забега)**
- Файл: `icon_golda.png` · PNG 1024×1024, прозрачный фон
- Где используется: HUD забега, цены в «ШАУРМА 67», награды

```
A thick round gold coin seen straight from the front with a ribbed edge and the number 67 embossed in heavy block digits, one small shine mark. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color gold #e0b040. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers except one bold number 67 embossed in the center. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I15 · РЕСПЕКТ (постоянная валюта)**
- Файл: `icon_respect.png` · PNG 1024×1024, прозрачный фон
- Где используется: итоги забега, экран улучшений «АВТОРИТЕТ РАЙОНА»

```
A strong handshake of two hands seen from the side, one sleeve with three tracksuit stripes, the other in a puffy jacket cuff, solid and symmetrical. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color red #d8322c. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I16 · КРОТ НАЙДЕН**
- Файл: `icon_krot_found.png` · PNG 1024×1024, прозрачный фон
- Где используется: отметка на доске маршрутов и в «АРХИВЕ», всплывающая плашка

```
A round mole head in a knitted beanie wearing small round dark sunglasses, wide friendly snout, poking out of a pile of snow, simple and funny. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color sand brown #c9a36b. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I17 · НОВЫЙ РАЗГОВОР**
- Файл: `icon_new_talk.png` · PNG 1024×1024, прозрачный фон
- Где используется: значок над DJ FLÜRR и у его строки в подъезде

```
A speech bubble with a torn paper edge containing one big over-ear headphone cup, with two short attention lines on the upper right. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color teal #3fc7c9. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

## 4. Статус партий

| Партия | Состав | Промпты | Файлы |
|---|---|---|---|
| 1 | 5 фитсов, 8 комнат, 2 валюты, 2 индикатора | готовы (раздел 3) | 17 из 17 получены 2026-11-20 |
| 2 | 18 артефактов, логотип «ГОЛДА 67», эмблема «67» | готовы (раздел 5) | 0 из 20 |
| 3 | товары ларька, рамки редкости, значки состояний, карточка фитса, плашка босса | — | — |
| 4 | фоны экранов подъезда и меню ларька | — | — |
| 5 | объявления, заставка ТВ, итоги забега, вывеска, граффити, баннеры | — | — |
| 6 | текстуры двора | — | — |

## 5. Партия 2 — 18 артефактов, логотип и эмблема

Артефакты — тот же стиль и формат, что у партии 1 (PNG 1024×1024, прозрачный фон). Числа и правила — `APPROVALS.md`, раздел 2.3.
Файлы класть туда же: `godot/assets/golda67/ui/`. Если генератор не умеет прозрачный фон — фон однотонный, уберу сам.

**G67-A01 · Кассета 2016**
- Файл: `icon_art_cassette_2016.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
An old audio cassette tape seen from the front with a blank paper label, one reel spinning with a loose loop of brown tape pulled out and curling, two short impact marks. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color red #d8322c. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A02 · SIM-карта**
- Файл: `icon_art_sim.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A single SIM card with a cut corner and a big golden contact chip in the middle, three short speed lines behind it as if it is flying fast. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color teal #3fc7c9. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A03 · Золотой браслет 67**
- Файл: `icon_art_bracelet_67.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A thick gold chain bracelet forming a closed loop, with a small hanging tag that has the number 67 stamped on it, two small sparkle marks. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color gold #e0b040. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers except the number 67 where described. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A04 · Наушники с одним рабочим ухом**
- Файл: `icon_art_one_earbud.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A pair of cheap wired earbuds with a tangled cable, one earbud fine, the other one cracked and wrapped with a strip of tape, a tiny sound wave coming only from the good one. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color electric blue #2f6fd8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A05 · Энергетик**
- Файл: `icon_art_energy.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A dented tall energy drink can with a jagged lightning bolt shape on its side, the tab pulled open, a few drops splashing out at the top. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color green #5fd08a. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A06 · Проектная флешка**
- Файл: `icon_art_flash_drive.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A chunky USB flash drive with a gold cap hanging on a short lanyard ring, a small star shape on the body, two short shine marks. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color gold #e0b040. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A07 · Сломанный пульт**
- Файл: `icon_art_broken_remote.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
An old TV remote control with a crack across the body and a strip of tape holding it together, one big round button glowing, a few small round buttons missing. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color teal #3fc7c9. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A08 · Рыночные кроссовки**
- Файл: `icon_art_market_sneakers.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
One cheap knockoff market sneaker in side view with four uneven stripes instead of three, a loose untied lace, short speed lines behind the heel. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color red #d8322c. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A09 · Платиновый значок**
- Файл: `icon_art_platinum_badge.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A shiny pin badge shaped like a five-pointed star inside a round wreath, with a safety pin on the back visible at the top, two sparkle marks. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color platinum silver #c9d2da. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A10 · Телефон с треснутым экраном**
- Файл: `icon_art_cracked_phone.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A smartphone seen from the front with a spider-web crack across the glass screen, the screen glowing with an angry red tint behind the cracks. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color red #d8322c. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A11 · ЧЕСНОЧНАЯ АУРА (событие)**
- Файл: `icon_art_garlic_aura.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A plump garlic bulb with three loose cloves around it, surrounded by two wavy concentric aura rings like a protective field. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color green #5fd08a. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A12 · ХОМЯЧЬЯ АУРА (событие)**
- Файл: `icon_art_hamster_aura.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A chubby hamster sitting upright with full cheeks stuffed with coins, small round coins orbiting around it in a ring, serious face. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color sand brown #c9a36b. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A13 · ОШЕЙНИК 67 (событие)**
- Файл: `icon_art_collar_67.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A studded leather dog collar forming a loop with a round metal tag hanging from the buckle, the tag stamped with the number 67. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color burgundy #7a1f2b. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers except the number 67 where described. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A14 · Шапка-бини**
- Файл: `icon_art_beanie.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A knitted winter beanie hat with a folded cuff and visible ribbed knit lines, a little snow on top, slightly crumpled. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color orange #ff8c26. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A15 · Грилзы**
- Файл: `icon_art_grillz.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A row of shiny gold grillz teeth seen from the front in a wide grin shape, one tooth with a small diamond, two sparkle marks. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color gold #e0b040. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A16 · Синяя изолента**
- Файл: `icon_art_blue_tape.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A roll of electrical insulating tape seen at a slight angle with a short loose strip hanging off and torn at the end. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color electric blue #2f6fd8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A17 · Вторая симка**
- Файл: `icon_art_second_sim.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
Two SIM cards stacked and fanned out, one slightly behind the other, golden contact chips visible on both, a small plus shape between them. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color teal #3fc7c9. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-A18 · Кольцо «Автотюн»**
- Файл: `icon_art_autotune_ring.png` · PNG 1024×1024, прозрачный фон
- Где используется: кладовка (выбор из двух), слоты артефактов в HUD и паузе, коллекция в подъезде

```
A chunky signet ring seen from the front, the flat top engraved with a zigzag sound wave line, two small musical sparkle marks around it. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color violet #8b4dff. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-L01 · Логотип «ГОЛДА 67»**
- Файл: `logo_golda67.png` · PNG 2048×1024 (2:1), прозрачный фон
- Где используется: карточка режима в «ВЫБОРЕ РЕЖИМА», заставка входа в приквел, экран итогов

```
Game logo wordmark that reads exactly ГОЛДА 67 in heavy condensed Cyrillic capital letters, the word ГОЛДА in off-white #ece6d8 and the number 67 big in gold #e0b040, letters cut from paper with thick uneven black ink outline, rough torn paper sticker edge around the whole word, coarse halftone dot shading, gritty photocopy texture, a thin gold chain running under the letters, small sparkle marks. Post-Soviet street rap zine aesthetic, bold and readable. No other text. Flat front view, no 3D, no drop shadow, no gradient background. Transparent background, wide 2:1, 2048x1024 PNG.
```

**G67-L02 · Эмблема «67» в круге**
- Файл: `emblem_67.png` · PNG 1024×1024, прозрачный фон
- Где используется: печать турнира: экран итогов, награда босса, загрузка

```
A round gold seal stamp emblem with the big bold number 67 in the center, a ring of small stars around the edge, a ribbed coin-like rim and two short ribbon tails below, gold #e0b040 with black ink #111111 and off-white paper #ece6d8 only. Thick uneven black ink outline, rough torn paper sticker edge, coarse halftone shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. No other text or letters except 67. Flat front view, no drop shadow, no glow. Transparent background, square 1:1, 1024x1024 PNG.
```
