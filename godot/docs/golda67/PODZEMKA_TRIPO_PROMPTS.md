# ПОДЗЕМКА — промпты для Tripo (модели делает владелец)

Решение владельца от 2026-11-23: живые и сложные модели района он генерирует сам в Tripo по этим промптам;
стены, тоннели, турникеты, кассы и прочая «жёсткая» геометрия остаются за Blender-скриптами (`tools/blender/`).
Готовый файл класть в `godot/assets/golda67/podzemka/` под указанным именем (поверх нынешней версии из Blender).
Формат: GLB, PBR-текстуры, 1 = 1 м, низ модели на нуле, лицо вперёд. Персонажи — T-поза и скелет Mixamo, как у
`g67_fortuna.glb` и остальных героев. Общий стиль (дописан в каждый промпт): stylized low-poly 3D game asset,
chunky proportions, hand-painted textures, как у остальных моделей GOD OF GRIMERKA.

| № | Файл | Что это |
|---|---|---|
| 1 | `g67_pz_dog.glb` | собака DOG CASINO 67 |
| 2 | `g67_pz_hamster.glb` | хомяк (окрасы сделаю перекраской) |
| 3 | `g67_pz_hamster_gold.glb` | золотой хомяк в короне |
| 4 | `g67_enemy_controller.glb` | враг КОНТРОЛЁР |
| 5 | `g67_enemy_promoter.glb` | враг ЗАЗЫВАЛА |
| 6 | `g67_enemy_bouncer.glb` | элитный враг ВЫШИБАЛА ТУРНИКЕТА |
| 7 | `g67_pz_shawarma_spit.glb` | вертел с мясом |
| 8 | `g67_pz_shawarma_food.glb` | прилавок шаурмы: еда |
| 9 | `g67_pz_slot_cabinet.glb` | корпус слот-автомата (барабаны и кнопку вставлю сам) |
| 10 | `g67_pz_dog_house.glb` | собачья будка |
| 11 | `g67_pz_socks_display.glb` | витрина носков |
| 12 | `g67_pz_phone_repair.glb` | прилавок ремонта телефонов |
| 13 | `g67_pz_keys_stand.glb` | стенд изготовления ключей |
| 14 | `g67_pz_vending_drinks.glb` | автомат с напитками |
| 15 | `g67_pz_arcade_machine.glb` | игровой автомат |
| 16 | `g67_pz_microwave.glb` | старая микроволновка |

## Промпты

**1. g67_pz_dog** — Stylized cartoon rottweiler dog, sitting, full body. Huge oversized head, massive barrel chest, short thick legs, stubby tail. Dark chocolate-black fur with bright tan markings on muzzle, eyebrow dots, chest and paws. Wide square muzzle, big wet dark nose, hanging jowls. Mouth wide open in a giant goofy happy grin, dark red inside, rows of small white teeth, long pink tongue hanging out to one side. Big round bulging eyes with small brown irises, slightly cross-eyed, silly friendly expression. Small folded triangular ears. Neck folds. Red leather collar with metal cone spikes and a round gold tag with number 67. Stylized low-poly 3D game asset, chunky proportions, hand-painted textures, clean silhouette.

**2. g67_pz_hamster** — Stylized cartoon hamster, standing upright on hind legs, full body. Round chubby pear-shaped body, huge stuffed cheeks, tiny round ears, small pink nose, big shiny black eyes, tiny pink paws held in front of the chest, short stubby tail. Soft fluffy golden-orange fur with white belly and white cheeks. Cute but slightly smug expression. Stylized low-poly 3D game asset, chunky proportions, hand-painted fur texture, clean silhouette, single character, neutral pose.

**3. g67_pz_hamster_gold** — Stylized cartoon hamster king, standing upright, full body. Round chubby body, huge stuffed cheeks, tiny ears, big shiny black eyes, tiny paws on hips, proud arrogant expression. Fur is shiny metallic gold. Wearing a small tilted golden crown with red gems and a tiny red royal cape with white fur trim. Stylized low-poly 3D game asset, chunky proportions, hand-painted textures, clean silhouette, single character.

**4. g67_enemy_controller** — Stylized cartoon human character in T-pose, full body, underground ticket inspector. Middle-aged stern man, thin moustache, tired eyes, peaked uniform cap with badge. Dark green post-Soviet uniform jacket with brass buttons, epaulettes, red armband, dark trousers, worn black boots. Old metal service badge on chest, ticket punch machine and roll of paper tickets on belt, whistle on a cord. Strapped to his left forearm a huge thick grey office folder used as a shield, stuffed with papers, stamped. Bureaucratic, self-important look. Stylized low-poly 3D game asset, chunky proportions, big head, hand-painted textures, symmetrical T-pose, arms straight out, legs apart.

**5. g67_enemy_promoter** — Stylized cartoon human character in T-pose, full body, annoying street promoter. Skinny young man with a huge fake smile, slicked hair, headset microphone. Bright green sleeveless vest covered with yellow sale stickers and price tags over a cheap hoodie, baggy jeans, dirty sneakers. Shoulder bag overflowing with yellow paper flyers, a stack of flyers tucked under the belt, cheap megaphone hanging on a strap. Stylized low-poly 3D game asset, chunky proportions, big head, hand-painted textures, symmetrical T-pose, arms straight out, legs apart.

**6. g67_enemy_bouncer** — Stylized cartoon human character in T-pose, full body, huge heavy security brute. Very wide shoulders, thick neck, small bald head, heavy brow, flat nose, scowl. Black security uniform, tactical vest with a yellow stripe. Massive shoulder armor made of steel subway turnstile gate panels with yellow-black hazard stripes, forearm guards made of bent turnstile tripod bars, heavy boots, thick belt with a ring of keys and a card reader. Intimidating silhouette, almost twice as wide as a normal man. Stylized low-poly 3D game asset, chunky proportions, hand-painted textures, symmetrical T-pose, arms straight out, legs apart.

**7. g67_pz_shawarma_spit** — Stylized 3D game prop: vertical doner kebab shawarma meat on a steel spit. Tall cone of stacked layered roasted meat slices, uneven ragged edges, juicy glossy surface, golden-brown crust with dark charred spots and lighter freshly sliced area on one side showing pink-beige meat layers, drops of fat. A tomato and an onion on top of the spit. Round steel drip tray underneath with sliced meat shavings. Behind it a vertical grill heater with glowing red heating coils in a steel frame. Appetizing, detailed, hand-painted textures, stylized low-poly, chunky proportions.

**8. g67_pz_shawarma_food** — Stylized 3D game prop set on one steel counter tray: street shawarma kiosk food. Row of steel containers with chopped tomatoes, cucumbers, shredded cabbage, sliced onion, grated carrot, pickles. Stack of thin lavash flatbreads with brown toasted spots. Two squeeze bottles with red and white sauce, drips. Three shawarma wraps in paper, one bitten showing meat and vegetables filling. Long kebab knife, napkin holder, small price tags. Appetizing, detailed, hand-painted textures, stylized low-poly, chunky proportions.

**9. g67_pz_slot_cabinet** — Stylized 3D game prop: big cartoon dog-themed casino slot machine cabinet, front view, 2.2 meters tall. Chunky wooden frame with carved bones and paw prints, top shaped like a red-roofed dog house, glossy red, gold, green and purple accents, rows of round light bulbs around the edges, decorative dog collars and bone ornaments, two speakers. Large empty rectangular screen opening in the center (dark recess, no symbols), blank marquee panel on top, small blank display panels, coin tray at the bottom, sloped control deck with an empty round socket for a big button. Polished casino quality, hand-painted textures, stylized low-poly, chunky proportions.

**10. g67_pz_dog_house** — Stylized 3D game prop: cartoon wooden dog house. Red shingled gable roof, cream painted plank walls, arched entrance, a bone-shaped name plate above the door, metal food bowl next to it, a chewed bone, short chain made of glowing party light bulbs, a few casino chips scattered around. Slightly worn, charming. Hand-painted textures, stylized low-poly, chunky proportions.

**11. g67_pz_socks_display** — Stylized 3D game prop: market stall display wall full of socks. Metal grid panel with hooks, dozens of pairs of socks hanging in rows, clearly sock-shaped with heels and ribbed cuffs, many patterns: stripes, dots, argyle, cartoon prints, plain black and white, some in plastic packs, cardboard price tags, a bin of loose socks below. Colorful, slightly messy post-Soviet underground market look. Hand-painted textures, stylized low-poly, chunky proportions.

**12. g67_pz_phone_repair** — Stylized 3D game prop: cluttered phone repair counter. Wooden desk with a glass display case of old mobile phones and smartphones with cracked screens, opened phones with removed back covers and visible circuit boards, soldering iron on a stand, magnifier lamp, tiny screwdrivers, tweezers, tangled chargers and cables, boxes of phone cases, blank hand-written price cards. Post-Soviet underground kiosk look. Hand-painted textures, stylized low-poly, chunky proportions.

**13. g67_pz_keys_stand** — Stylized 3D game prop: key cutting stand. Wooden board with hundreds of blank keys of different shapes hanging on nails in rows, a heavy old key duplicating machine with a vise and a cutting wheel on a small workbench, metal shavings, bunches of keys on rings, padlocks, a few intercom key fobs, small blank sign board. Worn, oily, post-Soviet underground kiosk look. Hand-painted textures, stylized low-poly, chunky proportions.

**14. g67_pz_vending_drinks** — Stylized 3D game prop: old beat-up drink vending machine, 1.9 meters tall. Dented painted steel body, glass front with rows of colorful soda cans and bottles on spiral racks, coin slot, bill acceptor covered with a blank taped paper note, keypad, pickup flap, scratched stickers, rust at the bottom, blank glowing panel on top. Grimy post-Soviet underground passage look. Hand-painted textures, stylized low-poly, chunky proportions.

**15. g67_pz_arcade_machine** — Stylized 3D game prop: old upright arcade gambling machine, 1.8 meters tall. Chunky cabinet with faded side art, dark blank CRT screen, row of big worn buttons, coin slot, ticket dispenser, cigarette burns, scratched plastic, one side panel hanging open with wires sticking out. Grimy post-Soviet underground arcade look. Hand-painted textures, stylized low-poly, chunky proportions.

**16. g67_pz_microwave** — Stylized 3D game prop: old boxy beige microwave oven from the 90s. Yellowed plastic, glass door with a perforated mesh window, round glass turntable plate visible inside, two rotary knobs, greasy fingerprints, a dent on top, power cord. Sitting on a plastic bottle crate. Hand-painted textures, stylized low-poly, chunky proportions.

