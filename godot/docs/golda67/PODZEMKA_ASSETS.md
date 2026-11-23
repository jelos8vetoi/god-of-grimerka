# ПОДЗЕМКА: модели Blender (этап 2)

Исходники — `godot/assets/golda67/blender_source/podzemka/<id>.blend` (папка с `.gdignore`), экспорт — `godot/assets/golda67/podzemka/<id>.glb`. Скрипты — `tools/blender/g67_pz_*.py` (`G67_PZ=1 blender --background --python …`). Рендеры — `Desktop/GOLDA67_PLAYTEST_DEVIN/blender_renders/podzemka/`.

**Состояние: первый проход.** Второй проход «рендер → посмотрел → исправил» сделан только для собаки, ларька шаурмы (мясо) и стен (полоса кафеля); остальные не прошли второй проход и слабы (см. столбец).

| id | .blend | .glb | треугольники | состояние / слабое |
|---|---|---|---|---|
| `g67_pz_arcade_a` | `blender_source/podzemka/g67_pz_arcade_a.blend` | `podzemka/g67_pz_arcade_a.glb` | 948 | первый проход |
| `g67_pz_arcade_b` | `blender_source/podzemka/g67_pz_arcade_b.blend` | `podzemka/g67_pz_arcade_b.glb` | 900 | первый проход |
| `g67_pz_arch` | `blender_source/podzemka/g67_pz_arch.blend` | `podzemka/g67_pz_arch.glb` | 744 | арка-проём с кромкой |
| `g67_pz_arrow_sign` | `blender_source/podzemka/g67_pz_arrow_sign.blend` | `podzemka/g67_pz_arrow_sign.glb` | 1131 | первый проход |
| `g67_pz_bench` | `blender_source/podzemka/g67_pz_bench.blend` | `podzemka/g67_pz_bench.glb` | 432 | первый проход |
| `g67_pz_bin` | `blender_source/podzemka/g67_pz_bin.blend` | `podzemka/g67_pz_bin.glb` | 368 | первый проход |
| `g67_pz_booth` | `blender_source/podzemka/g67_pz_booth.blend` | `podzemka/g67_pz_booth.glb` | 1481 | будка; слабое: плоская |
| `g67_pz_bottle_1` | `blender_source/podzemka/g67_pz_bottle_1.blend` | `podzemka/g67_pz_bottle_1.glb` | 512 | первый проход |
| `g67_pz_bottle_2` | `blender_source/podzemka/g67_pz_bottle_2.blend` | `podzemka/g67_pz_bottle_2.glb` | 512 | первый проход |
| `g67_pz_bottle_3` | `blender_source/podzemka/g67_pz_bottle_3.blend` | `podzemka/g67_pz_bottle_3.glb` | 512 | первый проход |
| `g67_pz_bottle_4` | `blender_source/podzemka/g67_pz_bottle_4.blend` | `podzemka/g67_pz_bottle_4.glb` | 632 | первый проход |
| `g67_pz_bottle_5` | `blender_source/podzemka/g67_pz_bottle_5.blend` | `podzemka/g67_pz_bottle_5.glb` | 460 | первый проход |
| `g67_pz_cash_shield` | `blender_source/podzemka/g67_pz_cash_shield.blend` | `podzemka/g67_pz_cash_shield.glb` | 4414 | касса-щит 8 окон; слабое: плоская |
| `g67_pz_ceil_beam` | `blender_source/podzemka/g67_pz_ceil_beam.blend` | `podzemka/g67_pz_ceil_beam.glb` | 228 | потолок с балкой |
| `g67_pz_ceil_lamp` | `blender_source/podzemka/g67_pz_ceil_lamp.blend` | `podzemka/g67_pz_ceil_lamp.glb` | 400 | потолок с лампой в решётке |
| `g67_pz_ceil_pipes` | `blender_source/podzemka/g67_pz_ceil_pipes.blend` | `podzemka/g67_pz_ceil_pipes.glb` | 1944 | потолок с трубами и лотком |
| `g67_pz_ceil_vent` | `blender_source/podzemka/g67_pz_ceil_vent.blend` | `podzemka/g67_pz_ceil_vent.glb` | 536 | потолок с вентрешёткой |
| `g67_pz_chess` | `blender_source/podzemka/g67_pz_chess.blend` | `podzemka/g67_pz_chess.glb` | 5204 | первый проход |
| `g67_pz_collar67` | `blender_source/podzemka/g67_pz_collar67.blend` | `podzemka/g67_pz_collar67.glb` | 1156 | первый проход |
| `g67_pz_column` | `blender_source/podzemka/g67_pz_column.blend` | `podzemka/g67_pz_column.glb` | 488 | колонна кафель/побелка/отбойник; слабое: простая |
| `g67_pz_corner_in` | `blender_source/podzemka/g67_pz_corner_in.blend` | `podzemka/g67_pz_corner_in.glb` | 152 | внутренний угол; слабое: простая форма |
| `g67_pz_corner_out` | `blender_source/podzemka/g67_pz_corner_out.blend` | `podzemka/g67_pz_corner_out.glb` | 260 | внешний угол с уголком; слабое: простая форма |
| `g67_pz_cross_green` | `blender_source/podzemka/g67_pz_cross_green.blend` | `podzemka/g67_pz_cross_green.glb` | 304 | первый проход |
| `g67_pz_dog` | `blender_source/podzemka/g67_pz_dog.blend` | `podzemka/g67_pz_dog.glb` | 12972 | метабол-ротвейлер, пасть и язык; слабое: хвост, форма морды ещё не как референс |
| `g67_pz_door_tech` | `blender_source/podzemka/g67_pz_door_tech.blend` | `podzemka/g67_pz_door_tech.glb` | 841 | стальная дверь; слабое: плоская, нет вмятин |
| `g67_pz_emergency_pack` | `blender_source/podzemka/g67_pz_emergency_pack.blend` | `podzemka/g67_pz_emergency_pack.glb` | 787 | первый проход |
| `g67_pz_floor_dry` | `blender_source/podzemka/g67_pz_floor_dry.blend` | `podzemka/g67_pz_floor_dry.glb` | 264 | бетонный пол со швом; слабое: однообразен |
| `g67_pz_floor_hatch` | `blender_source/podzemka/g67_pz_floor_hatch.blend` | `podzemka/g67_pz_floor_hatch.glb` | 728 | пол с люком; слабое: простой люк |
| `g67_pz_floor_toll` | `blender_source/podzemka/g67_pz_floor_toll.blend` | `podzemka/g67_pz_floor_toll.glb` | 435 | пол с жёлтой разметкой; слабое: разметка чистая |
| `g67_pz_floor_wet` | `blender_source/podzemka/g67_pz_floor_wet.blend` | `podzemka/g67_pz_floor_wet.glb` | 252 | пол с лужей (глянец); слабое: лужа — плоский диск |
| `g67_pz_fortuna_wheel` | `blender_source/podzemka/g67_pz_fortuna_wheel.blend` | `podzemka/g67_pz_fortuna_wheel.glb` | 5290 | колесо с лампочками; слабое: простое |
| `g67_pz_gas_balloon` | `blender_source/podzemka/g67_pz_gas_balloon.blend` | `podzemka/g67_pz_gas_balloon.glb` | 1783 | первый проход |
| `g67_pz_grille` | `blender_source/podzemka/g67_pz_grille.blend` | `podzemka/g67_pz_grille.glb` | 928 | решётка; слабое: простые прутья |
| `g67_pz_hamster_a` | `blender_source/podzemka/g67_pz_hamster_a.blend` | `podzemka/g67_pz_hamster_a.glb` | 1756 | первый проход |
| `g67_pz_hamster_b` | `blender_source/podzemka/g67_pz_hamster_b.blend` | `podzemka/g67_pz_hamster_b.glb` | 1756 | первый проход |
| `g67_pz_hamster_c` | `blender_source/podzemka/g67_pz_hamster_c.blend` | `podzemka/g67_pz_hamster_c.glb` | 1756 | первый проход |
| `g67_pz_hamster_gold` | `blender_source/podzemka/g67_pz_hamster_gold.blend` | `podzemka/g67_pz_hamster_gold.glb` | 2008 | первый проход |
| `g67_pz_hamster_props` | `blender_source/podzemka/g67_pz_hamster_props.blend` | `podzemka/g67_pz_hamster_props.glb` | 3328 | первый проход |
| `g67_pz_hamster_wall` | `blender_source/podzemka/g67_pz_hamster_wall.blend` | `podzemka/g67_pz_hamster_wall.glb` | 10554 | первый проход |
| `g67_pz_kennel` | `blender_source/podzemka/g67_pz_kennel.blend` | `podzemka/g67_pz_kennel.glb` | 1377 | первый проход |
| `g67_pz_kiosk_exchange` | `blender_source/podzemka/g67_pz_kiosk_exchange.blend` | `podzemka/g67_pz_kiosk_exchange.glb` | 2642 | первый проход |
| `g67_pz_kiosk_keys` | `blender_source/podzemka/g67_pz_kiosk_keys.blend` | `podzemka/g67_pz_kiosk_keys.glb` | 4081 | первый проход |
| `g67_pz_kiosk_odds` | `blender_source/podzemka/g67_pz_kiosk_odds.blend` | `podzemka/g67_pz_kiosk_odds.glb` | 4344 | первый проход |
| `g67_pz_kiosk_phones` | `blender_source/podzemka/g67_pz_kiosk_phones.blend` | `podzemka/g67_pz_kiosk_phones.glb` | 3270 | первый проход |
| `g67_pz_kiosk_shawarma` | `blender_source/podzemka/g67_pz_kiosk_shawarma.blend` | `podzemka/g67_pz_kiosk_shawarma.glb` | 22453 | ларёк шаурмы, мясо — слоёные пласты; слабое: мясо всё ещё стилизованное, не фотореалистично |
| `g67_pz_kiosk_socks` | `blender_source/podzemka/g67_pz_kiosk_socks.blend` | `podzemka/g67_pz_kiosk_socks.glb` | 6580 | первый проход |
| `g67_pz_microwave` | `blender_source/podzemka/g67_pz_microwave.blend` | `podzemka/g67_pz_microwave.glb` | 656 | первый проход |
| `g67_pz_queue_stand` | `blender_source/podzemka/g67_pz_queue_stand.blend` | `podzemka/g67_pz_queue_stand.glb` | 332 | стойка с лентой |
| `g67_pz_receipt_printer` | `blender_source/podzemka/g67_pz_receipt_printer.blend` | `podzemka/g67_pz_receipt_printer.glb` | 412 | принтер; слабое: простой |
| `g67_pz_shutter` | `blender_source/podzemka/g67_pz_shutter.blend` | `podzemka/g67_pz_shutter.glb` | 1400 | рольставня (полотно отдельно); слабое: простая |
| `g67_pz_slot_machine` | `blender_source/podzemka/g67_pz_slot_machine.blend` | `podzemka/g67_pz_slot_machine.glb` | 13529 | первый проход |
| `g67_pz_stairs` | `blender_source/podzemka/g67_pz_stairs.blend` | `podzemka/g67_pz_stairs.glb` | 3076 | лестничный марш с перилами; слабое: перила простые |
| `g67_pz_storage` | `blender_source/podzemka/g67_pz_storage.blend` | `podzemka/g67_pz_storage.glb` | 5003 | камера хранения; слабое: простая |
| `g67_pz_tariff_board` | `blender_source/podzemka/g67_pz_tariff_board.blend` | `podzemka/g67_pz_tariff_board.glb` | 1939 | табло; слабое: простое |
| `g67_pz_tunnel` | `blender_source/podzemka/g67_pz_tunnel.blend` | `podzemka/g67_pz_tunnel.glb` | 2708 | тоннельная секция: трубы, лоток, плафон; слабое: стены однообразны |
| `g67_pz_turnstile` | `blender_source/podzemka/g67_pz_turnstile.blend` | `podzemka/g67_pz_turnstile.glb` | 984 | турникет; слабое: створки плоские, форма упрощена, не принят |
| `g67_pz_vend_broken` | `blender_source/podzemka/g67_pz_vend_broken.blend` | `podzemka/g67_pz_vend_broken.glb` | 944 | первый проход |
| `g67_pz_vend_change` | `blender_source/podzemka/g67_pz_vend_change.blend` | `podzemka/g67_pz_vend_change.glb` | 1357 | первый проход |
| `g67_pz_vend_drinks` | `blender_source/podzemka/g67_pz_vend_drinks.blend` | `podzemka/g67_pz_vend_drinks.glb` | 2154 | первый проход |
| `g67_pz_vend_snacks` | `blender_source/podzemka/g67_pz_vend_snacks.blend` | `podzemka/g67_pz_vend_snacks.glb` | 2869 | первый проход |
| `g67_pz_wall_a` | `blender_source/podzemka/g67_pz_wall_a.blend` | `podzemka/g67_pz_wall_a.glb` | 408 | кафель «кабанчик» с зелёной полосой, сколами, подтёками; слабое: пятна грязи крупные, плитка без глянца-бликов |
| `g67_pz_wall_b` | `blender_source/podzemka/g67_pz_wall_b.blend` | `podzemka/g67_pz_wall_b.glb` | 1209 | то же + световой короб; слабое: короб плоский |
| `g67_pz_wall_c` | `blender_source/podzemka/g67_pz_wall_c.blend` | `podzemka/g67_pz_wall_c.glb` | 1103 | то же + техдверь в нише; слабое: дверь плоская |
| `g67_pz_wall_conc` | `blender_source/podzemka/g67_pz_wall_conc.blend` | `podzemka/g67_pz_wall_conc.glb` | 236 | бетонная плита со стыками; слабое: однообразна |
| `g67_pz_wall_d` | `blender_source/podzemka/g67_pz_wall_d.blend` | `podzemka/g67_pz_wall_d.glb` | 720 | то же + ниша с полкой; слабое: ниша мелкая |

## Ассеты Sketchfab (передача 45; лицензии CC0 / CC-BY, полная таблица — `godot/docs/CREDITS_SKETCHFAB.md`)

Обработка — `tools/blender/g67_sf_prep.py`, скачивание — `tools/sketchfab-get.cjs`, перекодирование текстур — `tools/g67_glb_fixtex.py`. Исходники — `blender_source/sketchfab_src/`.

| Позиция | Файл в игре | Оригинал (автор) | Треугольники | Экземпляров | В игре |
|---|---|---|---|---|---|
| турникет | `sf_turnstile` | Retro Turnstile (1PathFinder) | 5970 → 2500 | 22 | зелёная тумба с трипод-рычагом, читается; створки не отдельным узлом |
| ларёк (мелочи, обмен, ключи) | `sf_kiosk_a` | Ice Cream Stall (Ivan-Kanaev) | 191 | 3 | русский ларёк с витриной; на вывеске «МОРОЖЕНОЕ» (запечено в модели) |
| ларёк (носки) | `sf_kiosk_b` | Fruit and Vegetable Store (Elena.An) | 9711 → 6000 | 2 | яркий павильон с постером ягод, не по стилю зоны |
| автомат напитков | `sf_vend_a` | Vending machine - Blue cow (tboiston) | 2268 | 1 | читается |
| автомат снеков | `sf_vend_b` | psx vending machine (Brainsick Games) | 44 | 1 | читается |
| автомат размена | `sf_vend_c` | Plussy vending machine (Rusty-exe) | 1182 | 1 | жёлтый, читается |
| сломанный автомат | `sf_vend_d` | Rusty Old Newspaper Vending Machine (chrisg4919) | 872 | 1 | ржавый синий шкаф |
| игровой автомат | `sf_arcade_a` | Arcade machine (ion_omat) | 1530 | 6 | старый жёлтый |
| игровой автомат | `sf_arcade_b` | arcade machine (joindead) | 3069 | 6 | цветной, экран пустой |
| кассовая будка | `sf_booth` | Ticket Booth (daedaljs) | 367 | 1 | красно-белая |
| камера хранения | `sf_lockers` | Locker (neverfollow81) | 1670 | 1 | синие шкафчики |
| скамья | `sf_bench` | Wooden Park Bench (TheMadraver) | 714 | 2 | простая деревянная |

Не нашли годного / оставлено нашим: ларёк шаурмы и телефонов (наши вывески и наполнение), касса-щит, табло, колесо, хомячья стена, тоннель, быт комнаты персонала. Заменённые Blender-версии удалены из `assets/golda67/podzemka/`.

## Передача 46: художественный проход (наполнение, свет)

Новые модели Sketchfab (все CC-BY; в таблице авторство — см. `godot/docs/CREDITS_SKETCHFAB.md`): `sf_stall` Vietnamese Meat Market stall (Khoa Nguyen, 3689 тр.), `sf_boxes` CC0 Cardboard Box Closed (plaggy, 180), `sf_pallet` Wooden pallet (BlackMike, 304), `sf_extinguisher` psx fire extinguisher (Brainsick Games, 214), `sf_trash` Old Soviet Trash Can (Unka II, 116), `sf_hamster` Hamster (myuseum3, 660), `sf_sofa` Dream On low poly sofa (L_Krajewski, 1876), `sf_mop` Mop with Bucket (BrightMoon, 464). Фруктовый павильон, стойка с вешалками, панель и «трубы» удалены (не подошли). Ларёк `sf_kiosk_a` — без надписи над крышей; турникет `sf_turnstile` — трипод отдельным узлом `turnstile_arm` (3,5 тыс. тр. с рычагом).

Экземпляры: ларьки в галерее 24 (плотный ряд обеих сторон), игровые автоматы 24 (два острова спина к спине), турникеты 22, паллеты 10, коробки 18, мусорки 6, хомяки 6, прочее по 1–3.
