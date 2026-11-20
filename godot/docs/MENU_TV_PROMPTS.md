# Главное меню «ОБЛАКО-ТВ» — пять разных телевизоров (промпты для Tripo)

Пять экранов меню — пять разных настоящих телевизоров. Сейчас все пять собраны в коде из одинаковых коробок.
Экран в каждой модели должен быть **пустым тёмным стеклом**: картинку на нём рисует игра (свой шейдер поверх
стекла). Режим Tripo: HD model, текстуры 2K. Модель — одна вещь, по центру, лицом к зрителю, без подставки и фона.
**Получены 2026-11-20 и стоят в меню**: облегчены (`glbslim`, текстуры 1024), лежат в `godot/assets/minigames/`
(`menu_tv_*.glb`, грузит `MGModels`), лицом по +Z. Стекло экрана каждой модели измерено снимком спереди и лучом —
`MenuStudio.TV_SCREEN` (центр, ширина, высота, глубина стекла, скругление углов); картинка канала ложится на стекло,
углы срезает шейдер (`corner`). Телевизор вписан в габарит прежней коробки и стоит на своей полке. Новая модель с
другим экраном — перемерить `TV_SCREEN`.

| Пункт меню | Файл | Какой телевизор |
|---|---|---|
| CONTINUE | `menu_tv_continue.glb` | советский цветной ламповый в деревянном корпусе |
| PLAY (большой, по центру) | `menu_tv_play.glb` | большой чёрный кинескоп 90-х |
| SETTINGS | `menu_tv_settings.glb` | маленький переносной чёрно-белый с ручкой и антенной |
| EXTRAS | `menu_tv_extras.glb` | серебристый пластиковый кинескоп 2000-х |
| EXIT | `menu_tv_exit.glb` | металлический монитор охраны / студийный контрольный |

---

**MT-1 · CONTINUE — `menu_tv_continue.glb`**
```
A 1980s Soviet colour CRT television set in a walnut wood veneer cabinet, boxy and heavy, slightly convex rectangular screen with rounded corners set in a dark brown plastic front frame, a vertical control panel on the right side with two large silver rotary knobs, a row of six small cream piano-key channel buttons and a fabric speaker grille under them, thin brass trim line around the front, wood grain with worn varnish, small scratches and dust on the top, back casing tapering toward a ventilated brown back. The screen is plain dark blue-grey glass, completely blank, no image, no reflections painted on it. Realistic proportions and materials, physically based textures, believable wear, no text, no logos, no brand names. Single object, front three-quarter view, centered, no stand, no table, no background.
```

**MT-2 · PLAY — `menu_tv_play.glb`**
```
A large late-1990s black CRT television, 29-inch class, deep and heavy box with a gently curved glass screen, wide matte black plastic bezel with softly rounded edges, two long horizontal speaker grilles under the screen with fine perforation, a small red standby LED and a row of tiny flush buttons on the lower right, a thin silver accent line along the bottom edge, ventilation slots on the top, the back housing tapering into a deep tube cover. Slight dust, fingerprints and a few scuffs on the glossy black plastic. The screen is plain dark grey glass, completely blank, no image. Realistic proportions and materials, physically based textures, no text, no logos, no brand names. Single object, front view slightly from the side, centered, no stand, no cabinet, no background.
```

**MT-3 · SETTINGS — `menu_tv_settings.glb`**
```
A small portable 1970s black-and-white television, about 12 inches, ivory-cream plastic body with a dark charcoal front panel, a fold-down chrome carrying handle on top, a telescopic two-rod rabbit-ears antenna on the top rear, small square screen with strongly rounded corners, a column of three ribbed rotary knobs and a round speaker grille on the right of the screen, tiny rubber feet. Yellowed plastic, small cracks, a strip of old masking tape on the side, chrome slightly pitted. The screen is plain dark grey glass, completely blank, no image. Realistic proportions and materials, physically based textures, no text, no logos, no brand names. Single object, front three-quarter view, centered, no table, no background.
```

**MT-4 · EXTRAS — `menu_tv_extras.glb`**
```
An early-2000s silver plastic CRT television, 21-inch class, rounded bubbly body, flat-faced square screen in a two-tone bezel (metallic silver frame with a dark grey inner ring), an oval speaker grille on each side of the screen, a slim row of soft-touch buttons and a blue power LED under the screen, a slightly darker grey rounded back. Faded silver paint worn off on the edges, a small sticker residue mark on the bezel corner, light scratches. The screen is plain dark grey glass, completely blank, no image. Realistic proportions and materials, physically based textures, no text, no logos, no brand names. Single object, front three-quarter view, centered, no stand, no table, no background.
```

**MT-5 · EXIT — `menu_tv_exit.glb`**
```
An old security and broadcast control monitor in a steel box housing, grey hammer-paint finish, square screen with a thick black rubber bezel, two rack-mount ears with screw holes on the sides, a lower panel with four small black knobs, two toggle switches and a green power lamp, a perforated steel cover on top, chipped paint showing bare metal on corners, rust spots near the screws, a short coiled cable on the back. Industrial, heavy and utilitarian. The screen is plain dark grey glass, completely blank, no image. Realistic proportions and materials, physically based textures, no text, no logos, no brand names. Single object, front view slightly from the side, centered, no rack, no table, no background.
```
