# ДВОР — значки девяти новых бафов

Состояние: **промпты готовы, самих картинок нет.** Графику в проекте делает владелец по промптам (`GRAPHICS_REQUESTS.md`); я изображения не генерирую.
Пока файла нет, игра показывает баф текстом без значка — так уже работает `G67Icons.fit(id)` (нет файла — `null`).

## Стандарт

Изучен существующий набор: `godot/assets/golda67/ui/icon_fit_*.png` (пять бафов Миши) и промпты партии 1 в `GRAPHICS_REQUESTS.md`.
Новые девять сделаны по тому же шаблону слово в слово, поэтому встанут в один ряд со старыми:

- один предмет по центру, плоская «наклейка», толстый неровный чёрный контур, рваный бумажный край, крупный полутон, фактура ксерокопии;
- палитра из трёх цветов: бумага `#ece6d8`, тушь `#111111` и один акцент;
- акцент семейства «ДВОР» — ледяной голубой `#7fb4d8` (у семейства Миши — золото `#e0b040`); у редких — красный `#d83a2e`, как знак редкости;
- без текста, цифр и букв; читается в 48 пикселей;
- PNG 1024 × 1024, прозрачный фон; если генератор не умеет прозрачность — заменить последнюю фразу на «Plain flat solid magenta #ff00ff background», фон уберу сам;
- приёмка — как в `GRAPHICS_REQUESTS.md`: убрать «шахматку», положить в `godot/assets/golda67/ui/`, импорт `compress/mode=1`.

Имя файла — `icon_fit_<код>.png`; код совпадает с кодом бафа в данных игры.

| № | Баф | Файл | Редкость | Акцент | Силуэт |
|---|---|---|---|---|---|
| G67-I31 | ДЕДОВСКАЯ КУРТКА | `icon_fit_ded_jacket.png` | обычный | ice blue #7fb4d8 | широкий ватник на гвозде: трапеция с воротником |
| G67-I32 | БАНКА ИЗ ЛАРЬКА | `icon_fit_kiosk_can.png` | обычный | ice blue #7fb4d8 | высокая мятая банка с молнией |
| G67-I33 | СКОЛЬЗКИЕ ПОДОШВЫ | `icon_fit_slick_soles.png` | обычный | ice blue #7fb4d8 | кед в профиль над полосами льда |
| G67-I34 | ГАРАЖНЫЙ КЛЮЧ | `icon_fit_garage_key.png` | обычный | ice blue #7fb4d8 | рожковый ключ по диагонали |
| G67-I35 | ПЕРВЫЙ УДАР | `icon_fit_first_strike.png` | редкий | hot red #d83a2e | кулак в профиль и одна ударная звезда |
| G67-I36 | СЕМКИ | `icon_fit_semki.png` | обычный | ice blue #7fb4d8 | газетный кулёк с семечками |
| G67-I37 | СВОЙ ЧЕЛОВЕК | `icon_fit_own_man.png` | обычный | ice blue #7fb4d8 | рукопожатие двух рук |
| G67-I38 | РАЙОН ПОМНИТ | `icon_fit_district_remembers.png` | редкий | hot red #d83a2e | окно панельки с силуэтом |
| G67-I39 | ТЁПЛЫЙ ПОДЪЕЗД | `icon_fit_warm_entrance.png` | обычный | ice blue #7fb4d8 | чугунная батарея с варежкой |

## Промпты

Каждый самостоятельный: копируется целиком.

**G67-I31 · ДЕДОВСКАЯ КУРТКА**
- Файл: `icon_fit_ded_jacket.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
A thick quilted padded workman jacket (vatnik) hanging on a single bent nail, front view, diamond quilting stitches, big collar, one patch on the elbow, sleeves hanging straight down. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color ice blue #7fb4d8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I32 · БАНКА ИЗ ЛАРЬКА**
- Файл: `icon_fit_kiosk_can.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
A tall dented aluminium drink can seen from the front, crushed slightly in the middle, pull tab opened, a single jagged lightning bolt shape on its side, two small drops flying off the top. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color ice blue #7fb4d8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I33 · СКОЛЬЗКИЕ ПОДОШВЫ**
- Файл: `icon_fit_slick_soles.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
A worn high-top sneaker seen from the side sliding to the right, sole lifted at the heel, three horizontal speed streaks behind it and a cracked ice patch under the toe. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color ice blue #7fb4d8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I34 · ГАРАЖНЫЙ КЛЮЧ**
- Файл: `icon_fit_garage_key.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
A heavy open-end steel wrench placed diagonally, oily fingerprints and scratches on the handle, a small cracked bolt head next to its jaw, short impact lines at the jaw. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color ice blue #7fb4d8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I35 · ПЕРВЫЙ УДАР**
- Файл: `icon_fit_first_strike.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
A clenched fist seen from the side punching to the right, a single large angular impact star at the knuckles, the forearm wrapped in a rolled tracksuit sleeve. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color hot red #d83a2e. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I36 · СЕМКИ**
- Файл: `icon_fit_semki.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
A cone twisted from old newspaper filled to the top with sunflower seeds, a few seeds and empty shells falling out to the side, the newspaper shown only as grey blocks without readable print. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color ice blue #7fb4d8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I37 · СВОЙ ЧЕЛОВЕК**
- Файл: `icon_fit_own_man.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
Two hands in a firm handshake seen from the front, one hand in a knitted fingerless glove, the other bare with a small ring, short lines radiating from the grip. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color ice blue #7fb4d8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I38 · РАЙОН ПОМНИТ**
- Файл: `icon_fit_district_remembers.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
A single apartment window of a panel building seen from outside, wooden frame with a small vent pane, a dark silhouette of a person watching from behind a lace curtain, icicles on the sill. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color hot red #d83a2e. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```

**G67-I39 · ТЁПЛЫЙ ПОДЪЕЗД**
- Файл: `icon_fit_warm_entrance.png` · PNG 1024×1024, прозрачный фон
- Где используется: выбор бафа, список бафов в HUD и паузе, прилавки Петровича и Жоры

```
An old cast-iron ribbed radiator seen from the front with a single knitted mitten drying on top of it, three wavy heat lines rising above. Game UI icon, single centered object, bold flat sticker illustration, thick uneven black ink outline, rough hand-cut torn paper edge around the shape, coarse halftone dot shading, gritty photocopy texture, post-Soviet street rap zine aesthetic. Strict limited palette: off-white paper #ece6d8, black ink #111111, and one accent color ice blue #7fb4d8. Flat front view, no perspective, no drop shadow, no glow, no gradient background. No text, no letters, no numbers. Reads clearly at 48 pixels. Transparent background, square 1:1, 1024x1024 PNG.
```
