# Томск · трамвайное депо

Участок от 36 м перед стартовой чертой до 232 м после неё. План квартала, кузов трамвая, депо, башня, переход, остановки и уличные детали собраны программной геометрией в `race_depot.gd`. Внешние модели использованы для растительности.

Все семь внешних исходников выпущены Poly Haven под [CC0 1.0](https://polyhaven.com/license). Ссылки в таблице ведут на страницы конкретных материалов. У файлов при скачивании сверены MD5 из официального API.

| Исходник | Авторы | Игровой ресурс и применение |
|---|---|---|
| [Brick Wall 001](https://polyhaven.com/a/brick_wall_001) | Dimitrios Savva, Rob Tuytel | Три карты 1K для цехов, башни и труб. Масштаб повторения 2,93 м. |
| [Corrugated Iron 02](https://polyhaven.com/a/corrugated_iron_02) | Sergej Majboroda, Jenelle van Heerden | Цвет и OpenGL normal 1K для фальцованных и профилированных покрытий депо. |
| [Tree Small 02](https://polyhaven.com/a/tree_small_02) | Rico Cilliers | Упрощённый ствол и шесть неподвижных сечений кроны с атласом, запечённым из исходной геометрии. |
| [Shrub 02](https://polyhaven.com/a/shrub_02) | Rico Cilliers | Один облегчённый вариант куста и 512-пиксельная карта с маской листьев. |
| [Grass Medium 01](https://polyhaven.com/a/grass_medium_01) | Rob Tuytel, Rico Cilliers | Одна куртина с настоящим силуэтом травинок и картой с альфа-маской 512 px. |
| [Kloofendal 48d Partly Cloudy (Pure Sky)](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) | Greg Zaal, Jarod Guest | Дневная сферическая HDR-панорама 2K. |
| [Overcast Soil (Pure Sky)](https://polyhaven.com/a/overcast_soil_puresky) | Sergej Majboroda, Jarod Guest | Сферическая HDR-панорама 2K для дождливого заезда. |

Дорожное полотно, гравий и бетон используют [общую библиотеку поверхностей Томска](../surfaces/SOURCES.md). Обработка зелени выполнена в Blender, ImageMagick и Node.js. Исходники инструментов подготовки лежат в `tools/racing-depot/`. Во время игры модели загружаются из готовых ресурсов.
