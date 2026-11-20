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
| 1 | 5 фитсов, 8 комнат, 2 валюты, 2 индикатора | готовы (раздел 3) | 0 из 17 |
| 2 | 18 артефактов, логотип «ГОЛДА 67», эмблема «67» | следующая | — |
| 3 | товары ларька, рамки редкости, значки состояний, карточка фитса, плашка босса | — | — |
| 4 | фоны экранов подъезда и меню ларька | — | — |
| 5 | объявления, заставка ТВ, итоги забега, вывеска, граффити, баннеры | — | — |
| 6 | текстуры двора | — | — |
