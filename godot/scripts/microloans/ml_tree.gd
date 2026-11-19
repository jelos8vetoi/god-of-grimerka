## «РАЗВИТИЕ ПАХАНА» — все данные прокачки «Микрозаймов»: пять веток дерева навыков, синергии между ветками, бизнесы,
## снаряжение по качеству, знакомые, вехи и «ЛЕГЕНДА РАЙОНА» (престиж). Логика — ml_career.gd, экран — ml_tree_ui.gd.
## Новый навык, бизнес или веха — только строкой здесь. Эффекты (eff) — ключи, которые читают системы:
##   pay:<работа> — множитель оплаты, xp — множитель опыта, jstress — множитель стресса от работы, actions — +действия,
##   rate / fine / fee — множители процентов, штрафов и комиссий, extend — +дни продления, carry — доля денег в «копилку»,
##   tyaga_* / repair_* / deliv_* / junk_* / sound_* — параметры мини-игр, biz:<id> — открыт бизнес, staff — +места,
##   auto:<id> — автоматизация, bizinc — множитель дохода бизнесов, upkeep — множитель расходов, trust — рост доверия,
##   npc:<кто> — знакомый, talk — новые ответы в звонке, planner — последствия заранее, cushion — подушка на неделю.
class_name MLTree

const BRANCHES := {
	"worker": {"name": "РАБОТЯГА", "icon": "🧹", "col": Color(0.95, 0.75, 0.25), "about": "подработки быстрее, чище и дороже"},
	"master": {"name": "МАСТЕР", "icon": "🔧", "col": Color(0.55, 0.85, 1.0), "about": "снаряжение и своя инфраструктура"},
	"boss": {"name": "ПРЕДПРИНИМАТЕЛЬ", "icon": "🏪", "col": Color(0.5, 1.0, 0.6), "about": "свой бизнес, сотрудники, пассивный доход"},
	"schemes": {"name": "СХЕМЫ", "icon": "📊", "col": Color(1.0, 0.45, 0.4), "about": "кредиты, комиссии, денежный поток"},
	"ties": {"name": "СВЯЗИ", "icon": "🤝", "col": Color(0.8, 0.6, 1.0), "about": "знакомые, доверие, редкие заказы"},
}
const BRANCH_ORDER := ["worker", "master", "boss", "schemes", "ties"]

## узлы: id, ветка, ряд (0 — корень), колонка внутри ветки (−1..1), вид, рангов, цена за ранг (очки), уровень Пахана,
## требования [[узел, ранг]], эффект за ранг, текст
const NODES := [
	# ---------- РАБОТЯГА ----------
	{"id": "w_hands", "b": "worker", "row": 0, "col": 0, "kind": "stat", "max": 3, "cost": 1, "lvl": 1, "req": [], "eff": {"pay:all": 0.1, "xp": 0.06}, "name": "РУКИ ИЗ ПЛЕЧ", "desc": "все подработки платят больше, опыта больше"},
	{"id": "w_suction", "b": "worker", "row": 1, "col": -1, "kind": "stat", "max": 3, "cost": 1, "lvl": 2, "req": [["w_hands", 1]], "eff": {"tyaga_power": 0.2, "tyaga_brush": 0.15, "pay:podezd": 0.12}, "name": "МОЩНОСТЬ ВСАСЫВАНИЯ", "desc": "щётка ТЯГИ шире и тянет сильнее, крупный мусор поддаётся быстрее"},
	{"id": "w_hose", "b": "worker", "row": 2, "col": -1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 4, "req": [["w_suction", 2]], "eff": {"tyaga_hose": 0.4, "tyaga_tangle": -0.4}, "name": "ДЛИННЫЙ ШЛАНГ", "desc": "шланг длиннее, путается реже — достаёшь в углах"},
	{"id": "w_turbo", "b": "worker", "row": 3, "col": -1, "kind": "ability", "max": 1, "cost": 2, "lvl": 6, "req": [["w_hose", 1]], "eff": {"tyaga_turbo": 1.0}, "name": "ТУРБО-ВСАСЫВАНИЕ", "desc": "[Shift] в уборке — 3 с двойной мощности, перезарядка 8 с"},
	{"id": "w_smart", "b": "worker", "row": 3, "col": 0, "kind": "unlock", "max": 1, "cost": 2, "lvl": 7, "req": [["w_suction", 3]], "eff": {"tyaga_smart": 1.0}, "name": "УМНАЯ ЩЁТКА", "desc": "мелкий мусор рядом с маршрутом подбирается сам"},
	{"id": "w_fix", "b": "worker", "row": 1, "col": 0, "kind": "stat", "max": 3, "cost": 1, "lvl": 2, "req": [["w_hands", 1]], "eff": {"repair_diag": 0.25, "pay:repair": 0.12}, "name": "БЫСТРАЯ ДИАГНОСТИКА", "desc": "неисправность находится быстрее, ремонт дороже"},
	{"id": "w_multi", "b": "worker", "row": 2, "col": 0, "kind": "ability", "max": 1, "cost": 2, "lvl": 5, "req": [["w_fix", 2]], "eff": {"repair_multi": 1.0}, "name": "МАСТЕР НА ВСЕ РУКИ", "desc": "в ремонте один винт откручивает все соседние сразу"},
	{"id": "w_legs", "b": "worker", "row": 1, "col": 1, "kind": "stat", "max": 3, "cost": 1, "lvl": 2, "req": [["w_hands", 1]], "eff": {"deliv_speed": 0.12, "pay:deliv": 0.12, "jstress": -0.06}, "name": "КРЕПКИЕ НОГИ", "desc": "в доставке бегаешь быстрее, работа утомляет меньше"},
	{"id": "w_chain", "b": "worker", "row": 2, "col": 1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 5, "req": [["w_legs", 2]], "eff": {"deliv_slots": 1.0, "deliv_chain": 0.15}, "name": "ЦЕПОЧКА ДОСТАВОК", "desc": "+1 посылка за маршрут, бонус за каждую подряд без опоздания"},
	{"id": "w_eye", "b": "worker", "row": 2, "col": -2, "kind": "stat", "max": 2, "cost": 1, "lvl": 3, "req": [["w_suction", 1]], "eff": {"junk_eval": 0.5, "junk_rare": 0.08}, "name": "ГЛАЗ НА ХЛАМ", "desc": "в разборе видно цену вещей точнее, чаще попадаются редкие"},
	{"id": "w_ear", "b": "worker", "row": 2, "col": 2, "kind": "stat", "max": 2, "cost": 1, "lvl": 3, "req": [["w_legs", 1]], "eff": {"sound_precise": 0.25, "pay:sound": 0.08}, "name": "АБСОЛЮТНЫЙ СЛУХ", "desc": "окна уровней шире, звукарь получает больше"},
	{"id": "w_pro", "b": "worker", "row": 4, "col": 0, "kind": "capstone", "max": 1, "cost": 3, "lvl": 10, "req": [["w_smart", 1], ["w_multi", 1], ["w_chain", 1]], "eff": {"pay:all": 0.2, "xp": 0.2, "perfect": 0.25}, "name": "ПРОФЕССИОНАЛ", "desc": "оплата и опыт +20 %, за идеальную работу ещё +25 %"},
	# ---------- МАСТЕР ----------
	{"id": "m_bench", "b": "master", "row": 0, "col": 0, "kind": "unlock", "max": 1, "cost": 1, "lvl": 1, "req": [], "eff": {"eq:repair": 1.0}, "name": "ВЕРСТАК", "desc": "набор инструментов «Улучшенный»: в ремонте появляется пинцет-магнит"},
	{"id": "m_tyaga", "b": "master", "row": 1, "col": -1, "kind": "unlock", "max": 3, "cost": 2, "lvl": 3, "req": [["m_bench", 1]], "eff": {"eq:tyaga": 1.0}, "name": "ТЮНИНГ ТЯГИ", "desc": "ТЯГА-812 на ранг качества выше: быстрее, ёмче, своя насадка на каждом ранге"},
	{"id": "m_kit", "b": "master", "row": 1, "col": 0, "kind": "unlock", "max": 3, "cost": 2, "lvl": 3, "req": [["m_bench", 1]], "eff": {"eq:repair": 1.0, "repair_hard": 1.0}, "name": "ПРОФ. РЕМКОМПЛЕКТ", "desc": "ремонтный набор выше качеством: лупа, тестер, сложные заказы (консоли, ноутбуки)"},
	{"id": "m_rig", "b": "master", "row": 1, "col": 1, "kind": "unlock", "max": 3, "cost": 2, "lvl": 3, "req": [["m_bench", 1]], "eff": {"eq:sound": 1.0, "sound_slots": 1.0}, "name": "СВОЙ АППАРАТ", "desc": "аппаратура звукаря выше качеством: качественные кабели (меньше помех), лишний канал"},
	{"id": "m_bag", "b": "master", "row": 2, "col": 1, "kind": "unlock", "max": 2, "cost": 2, "lvl": 4, "req": [["m_rig", 1]], "eff": {"eq:deliv": 1.0, "deliv_slots": 1.0}, "name": "ТЕРМОРЮКЗАК", "desc": "рюкзак курьера: +слот, посылки бьются меньше"},
	{"id": "m_store", "b": "master", "row": 2, "col": -1, "kind": "stat", "max": 3, "cost": 1, "lvl": 5, "req": [["m_tyaga", 1]], "eff": {"junk_cap": 2.0, "repair_parts": -0.15}, "name": "СКЛАД ЗАПЧАСТЕЙ", "desc": "в разборе больше места, запчасти для ремонта дешевле"},
	{"id": "m_auto", "b": "master", "row": 3, "col": 0, "kind": "unlock", "max": 1, "cost": 3, "lvl": 8, "req": [["m_kit", 2], ["m_store", 1]], "eff": {"auto:service": 1.0}, "name": "АВТОМАТИЧЕСКИЕ ИНСТРУМЕНТЫ", "desc": "оборудование бизнесов обслуживает себя само — не изнашивается"},
	{"id": "m_shop", "b": "master", "row": 4, "col": 0, "kind": "capstone", "max": 1, "cost": 3, "lvl": 11, "req": [["m_auto", 1], ["m_tyaga", 3]], "eff": {"eq:all": 1.0, "bizinc:workshop": 0.5}, "name": "СОБСТВЕННАЯ МАСТЕРСКАЯ", "desc": "всё снаряжение на ранг выше, мастерская приносит в полтора раза больше"},
	# ---------- ПРЕДПРИНИМАТЕЛЬ ----------
	{"id": "b_first", "b": "boss", "row": 0, "col": 0, "kind": "unlock", "max": 1, "cost": 1, "lvl": 2, "req": [], "eff": {"biz:workshop": 1.0}, "name": "МАЛЕНЬКАЯ МАСТЕРСКАЯ", "desc": "можно купить мастерскую: доход каждый вечер"},
	{"id": "b_clean", "b": "boss", "row": 1, "col": -1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 4, "req": [["b_first", 1]], "eff": {"biz:cleaning": 1.0}, "name": "СЛУЖБА УБОРКИ", "desc": "вторая ТЯГА и работники: часть заказов делают без тебя"},
	{"id": "b_deliv", "b": "boss", "row": 1, "col": 1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 4, "req": [["b_first", 1]], "eff": {"biz:delivery": 1.0}, "name": "ДОСТАВКА НА РАЙОНЕ", "desc": "курьеры и транспорт: заказы приходят сами"},
	{"id": "b_staff", "b": "boss", "row": 2, "col": 0, "kind": "stat", "max": 3, "cost": 1, "lvl": 5, "req": [["b_first", 1]], "eff": {"staff": 1.0, "upkeep": -0.08}, "name": "КАДРЫ РЕШАЮТ", "desc": "+1 место сотрудника в каждом бизнесе, расходы ниже"},
	{"id": "b_studio", "b": "boss", "row": 2, "col": 1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 6, "req": [["b_deliv", 1]], "eff": {"biz:studio": 1.0}, "name": "ЗВУКОЗАПИСЫВАЮЩАЯ СТУДИЯ", "desc": "клиенты пишут треки — платят за смены"},
	{"id": "b_store", "b": "boss", "row": 2, "col": -1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 6, "req": [["b_clean", 1]], "eff": {"biz:warehouse": 1.0}, "name": "СКЛАД И ПЕРЕПРОДАЖА", "desc": "покупаешь партии хлама, сортируешь, перепродаёшь"},
	{"id": "b_autosell", "b": "boss", "row": 3, "col": -1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 8, "req": [["b_store", 1]], "eff": {"auto:sell": 1.0, "bizinc:warehouse": 0.25}, "name": "АВТОПРОДАЖА", "desc": "склад продаёт сам: доход стабильнее, вещи не залёживаются"},
	{"id": "b_manager", "b": "boss", "row": 3, "col": 1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 8, "req": [["b_staff", 2]], "eff": {"auto:manage": 1.0, "bizinc": 0.15}, "name": "УПРАВЛЯЮЩИЙ", "desc": "сотрудники работают без простоя: доход всех бизнесов +15 %"},
	{"id": "b_mogul", "b": "boss", "row": 4, "col": 0, "kind": "capstone", "max": 1, "cost": 3, "lvl": 12, "req": [["b_manager", 1], ["b_autosell", 1], ["b_studio", 1]], "eff": {"bizinc": 0.35, "staff": 1.0}, "name": "МЕСТНЫЙ ПРЕДПРИНИМАТЕЛЬ", "desc": "доход бизнесов +35 %, ещё +1 место сотрудника"},
	# ---------- СХЕМЫ ----------
	{"id": "s_haggle", "b": "schemes", "row": 0, "col": 0, "kind": "stat", "max": 3, "cost": 1, "lvl": 1, "req": [], "eff": {"rate": -0.08, "fee": -0.1, "weekdebt": -0.05}, "name": "УМЕНИЕ ТОРГОВАТЬСЯ", "desc": "проценты и комиссии ниже"},
	{"id": "s_read", "b": "schemes", "row": 1, "col": -1, "kind": "unlock", "max": 1, "cost": 1, "lvl": 3, "req": [["s_haggle", 1]], "eff": {"read": 1.0}, "name": "АНАЛИЗ ДОГОВОРОВ", "desc": "мелкий шрифт виден сразу у всех предложений"},
	{"id": "s_talk", "b": "schemes", "row": 1, "col": 1, "kind": "ability", "max": 1, "cost": 2, "lvl": 3, "req": [["s_haggle", 1]], "eff": {"talk": 1.0}, "name": "КРЕДИТНАЯ ХИТРОСТЬ", "desc": "в звонках появляются новые ответы, пауза длиннее"},
	{"id": "s_fine", "b": "schemes", "row": 2, "col": -1, "kind": "stat", "max": 2, "cost": 1, "lvl": 4, "req": [["s_read", 1]], "eff": {"fine": -0.2}, "name": "ЗАЩИТА ОТ ШТРАФОВ", "desc": "штрафы за просрочку ниже"},
	{"id": "s_plan", "b": "schemes", "row": 2, "col": 0, "kind": "unlock", "max": 1, "cost": 2, "lvl": 5, "req": [["s_haggle", 2]], "eff": {"planner": 1.0, "extend": 1.0, "weekdebt": -0.15}, "name": "ПЛАНИРОВЩИК", "desc": "последствия видно заранее, продление на день дольше, новые недели — с меньшими долгами"},
	{"id": "s_cushion", "b": "schemes", "row": 3, "col": -1, "kind": "ability", "max": 1, "cost": 2, "lvl": 7, "req": [["s_fine", 1]], "eff": {"cushion": 1.0, "carry": 0.15}, "name": "ФИНАНСОВАЯ ПОДУШКА", "desc": "раз в неделю непредвиденный расход оплачивается сам; в копилку уходит больше"},
	{"id": "s_refi", "b": "schemes", "row": 3, "col": 1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 7, "req": [["s_talk", 1], ["s_plan", 1]], "eff": {"refi": 1.0, "rate": -0.08, "weekdebt": -0.15}, "name": "РЕФИНАНСИРОВАНИЕ+", "desc": "объединённый займ — под ставку ниже; старые долги переходят в новую неделю дешевле"},
	{"id": "s_opt", "b": "schemes", "row": 4, "col": 0, "kind": "capstone", "max": 1, "cost": 3, "lvl": 11, "req": [["s_cushion", 1], ["s_refi", 1]], "eff": {"opt": 1.0, "carry": 0.15, "rate": -0.1, "weekdebt": -0.25, "bizinc": 0.1}, "name": "ОПТИМИЗАТОР", "desc": "без просрочек бизнесы приносят +20 %, проценты ниже, копилка больше"},
	# ---------- СВЯЗИ ----------
	{"id": "t_hello", "b": "ties", "row": 0, "col": 0, "kind": "stat", "max": 3, "cost": 1, "lvl": 1, "req": [], "eff": {"trust": 0.25, "rep_day": 1.0}, "name": "ЗДОРОВАЕТСЯ СО ВСЕМИ", "desc": "доверие растёт быстрее, репутация понемногу растёт каждый день"},
	{"id": "t_mech", "b": "ties", "row": 1, "col": -1, "kind": "unlock", "max": 1, "cost": 1, "lvl": 3, "req": [["t_hello", 1]], "eff": {"npc:mechanic": 1.0, "repair_parts": -0.25}, "name": "ЗНАКОМЫЙ РЕМОНТНИК", "desc": "Саня с рынка: дешёвые запчасти"},
	{"id": "t_courier", "b": "ties", "row": 1, "col": 1, "kind": "unlock", "max": 1, "cost": 1, "lvl": 3, "req": [["t_hello", 1]], "eff": {"npc:courier": 1.0, "deliv_nav": 1.0}, "name": "ЗНАКОМЫЙ КУРЬЕР", "desc": "Тимур: короткие пути на карте доставки"},
	{"id": "t_owner", "b": "ties", "row": 2, "col": -1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 5, "req": [["t_mech", 1]], "eff": {"npc:owner": 1.0, "pay:repair": 0.15, "bizinc:workshop": 0.2}, "name": "ВЛАДЕЛЕЦ МАСТЕРСКОЙ", "desc": "крупные заказы на ремонт и для мастерской"},
	{"id": "t_dj", "b": "ties", "row": 2, "col": 1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 5, "req": [["t_hello", 2]], "eff": {"npc:dj": 1.0, "sound_hard": 1.0, "pay:sound": 0.15}, "name": "ЗНАКОМЫЙ ЗВУКАРЬ", "desc": "дорогие мероприятия: открывается сложная настройка"},
	{"id": "t_bank", "b": "ties", "row": 3, "col": 0, "kind": "unlock", "max": 1, "cost": 2, "lvl": 7, "req": [["t_owner", 1], ["t_dj", 1]], "eff": {"npc:banker": 1.0, "rate": -0.1, "rep_need": -20}, "name": "СВОЙ ЧЕЛОВЕК В КОНТОРЕ", "desc": "конторы дают раньше и под меньший процент"},
	{"id": "t_rare", "b": "ties", "row": 3, "col": -1, "kind": "unlock", "max": 1, "cost": 2, "lvl": 8, "req": [["t_owner", 1]], "eff": {"rare": 1.0, "junk_rare": 0.12}, "name": "РЕДКИЕ КОНТРАКТЫ", "desc": "иногда приходит редкий заказ: двойная оплата"},
	{"id": "t_legend", "b": "ties", "row": 4, "col": 0, "kind": "capstone", "max": 1, "cost": 3, "lvl": 12, "req": [["t_bank", 1], ["t_rare", 1]], "eff": {"trust": 0.5, "pay:all": 0.15, "bizinc": 0.15}, "name": "ВЕСЬ РАЙОН ЗНАЕТ", "desc": "доверие быстрее, всё платит больше"},
]

## синергии: работают сами, когда выполнены условия сразу в нескольких ветках
## need — [[тип, id, значение]]: node — ранг узла, biz — уровень бизнеса, eq — ранг снаряжения
const SYNERGIES := [
	{"id": "syn_clean", "name": "ТЯГА + СЛУЖБА", "desc": "тюнингованная ТЯГА у сотрудников: служба уборки +35 %", "need": [["eq", "tyaga", 2], ["biz", "cleaning", 2]], "eff": {"bizinc:cleaning": 0.35}},
	{"id": "syn_shop", "name": "МАСТЕРСКАЯ + СХЕМЫ", "desc": "умеешь читать договоры поставщиков: расходы мастерской −30 %", "need": [["biz", "workshop", 2], ["node", "s_haggle", 2]], "eff": {"upkeep:workshop": -0.3, "bizinc:workshop": 0.1}},
	{"id": "syn_route", "name": "ДОСТАВКА + СВЯЗИ", "desc": "Тимур объединяет маршруты: доставка на районе +30 %", "need": [["biz", "delivery", 1], ["node", "t_courier", 1]], "eff": {"bizinc:delivery": 0.3}},
	{"id": "syn_resale", "name": "ХЛАМ + СКЛАД", "desc": "наметанный глаз при перепродаже: склад +40 %", "need": [["node", "w_eye", 2], ["biz", "warehouse", 1]], "eff": {"bizinc:warehouse": 0.4}},
	{"id": "syn_studio", "name": "ЗВУКАРЬ + СТУДИЯ", "desc": "свой аппарат в студии: дорогие клиенты, студия +40 %, звукарь +20 %", "need": [["eq", "sound", 2], ["biz", "studio", 1]], "eff": {"bizinc:studio": 0.4, "pay:sound": 0.2}},
	{"id": "syn_gold", "name": "ЗОЛОТЫЕ РУКИ", "desc": "профессионал с собственной мастерской: подработки ×1,3", "need": [["node", "w_pro", 1], ["node", "m_shop", 1]], "eff": {"pay:all": 0.3, "xp": 0.2}},
	{"id": "syn_mogul", "name": "МАГНАТ РАЙОНА", "desc": "бизнес, схемы и связи на вершине: все бизнесы ×1,5", "need": [["node", "b_mogul", 1], ["node", "s_opt", 1], ["node", "t_legend", 1]], "eff": {"bizinc": 0.5}},
]

## бизнесы: buy — цена открытия, up — цена уровней 2..5, inc — доход в день по уровням, upkeep — расходы в день,
## slots — мест сотрудников по уровням, hire — найм, wage — зарплата в день, k — прибавка дохода за сотрудника
const BUSINESSES := {
	"workshop": {"name": "МАСТЕРСКАЯ", "icon": "🔧", "job": "repair", "buy": 9000, "up": [9000, 17000, 30000, 52000], "inc": [900, 1700, 3000, 5200, 8600], "upkeep": [150, 280, 500, 850, 1300], "slots": [1, 1, 2, 3, 4], "hire": 2500, "wage": 300, "k": 0.45},
	"cleaning": {"name": "СЛУЖБА УБОРКИ", "icon": "🧹", "job": "podezd", "buy": 12000, "up": [12000, 22000, 38000, 62000], "inc": [1100, 2000, 3500, 6000, 9800], "upkeep": [200, 360, 600, 950, 1450], "slots": [1, 2, 2, 3, 4], "hire": 3000, "wage": 380, "k": 0.5},
	"delivery": {"name": "ДОСТАВКА НА РАЙОНЕ", "icon": "📦", "job": "deliv", "buy": 11000, "up": [11000, 20000, 35000, 58000], "inc": [1000, 1900, 3300, 5600, 9200], "upkeep": [220, 380, 650, 1000, 1500], "slots": [1, 2, 3, 3, 4], "hire": 2800, "wage": 350, "k": 0.45},
	"studio": {"name": "СТУДИЯ ЗВУКОЗАПИСИ", "icon": "🎙", "job": "sound", "buy": 16000, "up": [16000, 28000, 46000, 72000], "inc": [1500, 2700, 4600, 7600, 12000], "upkeep": [320, 520, 850, 1300, 1900], "slots": [1, 1, 2, 2, 3], "hire": 4000, "wage": 500, "k": 0.55},
	"warehouse": {"name": "СКЛАД И ПЕРЕПРОДАЖА", "icon": "📦", "job": "junk", "buy": 14000, "up": [14000, 25000, 42000, 66000], "inc": [1300, 2300, 4000, 6800, 10800], "upkeep": [260, 440, 720, 1100, 1650], "slots": [1, 2, 2, 3, 3], "hire": 3200, "wage": 400, "k": 0.4},
}
const BUSINESS_ORDER := ["workshop", "cleaning", "delivery", "studio", "warehouse"]

## качество снаряжения: ранг 0..4
const QUALITY := ["ОБЫЧНОЕ", "УЛУЧШЕННОЕ", "РЕДКОЕ", "ЭЛИТНОЕ", "УНИКАЛЬНОЕ"]
const QUALITY_COL := [Color(0.75, 0.75, 0.75), Color(0.4, 0.9, 0.45), Color(0.35, 0.65, 1.0), Color(0.8, 0.45, 1.0), Color(1.0, 0.7, 0.2)]
## что даёт ранг снаряжения в мини-игре (читает подработка)
const EQUIPMENT := {
	"tyaga": {"name": "ТЯГА-812", "ranks": ["заводская", "фильтр HEPA: ёмкость ×1,5", "насадка «Щель»: мусор в углах", "мотор «Буран»: скорость +25 %", "золотая ТЯГА: всё сразу и турбо дольше"]},
	"repair": {"name": "РЕМОНТНЫЙ НАБОР", "ranks": ["отвёртка", "пинцет-магнит: винты не теряются", "лупа: неисправность подсвечена", "тестер: проверка мгновенная", "станция пайки: любая поломка за ход"]},
	"deliv": {"name": "КУРЬЕРСКИЙ РЮКЗАК", "ranks": ["пакет", "термосумка: посылки не бьются", "рюкзак: +слот", "электросамокат: скорость +30 %", "грузовой самокат: +2 слота"]},
	"sound": {"name": "АППАРАТУРА", "ranks": ["кабели с рынка", "экранированные кабели: меньше помех", "микшер с лампами: окна шире", "свой усилитель: лишний канал", "студийный комплект: ни одного фона"]},
}

## знакомые: имя и что дают (читается по npc:<id>)
const NPCS := {
	"mechanic": {"name": "САНЯ С РЫНКА", "about": "запчасти дешевле на четверть"},
	"courier": {"name": "ТИМУР-КУРЬЕР", "about": "короткие пути на карте доставки, выгодные маршруты"},
	"owner": {"name": "АРКАДИЙ ИЗ «ЭЛЕКТРОНИКИ»", "about": "крупные ремонты и заказы для мастерской"},
	"dj": {"name": "ДИДЖЕЙ СЛАВИК", "about": "дорогие мероприятия для звукаря и студии"},
	"banker": {"name": "СВОЙ ЧЕЛОВЕК В КОНТОРЕ", "about": "займы раньше и дешевле"},
}

## вехи: условие (ключ статистики карьеры ≥ значения), награда
const MILESTONES := [
	{"id": "ms_payoff", "name": "ПЕРВЫЙ ЗАКРЫТЫЙ ДОЛГ", "stat": "closed", "need": 1, "xp": 80, "points": 1, "money": 0},
	{"id": "ms_jobs10", "name": "10 ПОДРАБОТОК", "stat": "jobs", "need": 10, "xp": 120, "points": 1, "money": 1500},
	{"id": "ms_tyaga", "name": "ТЯГА НА РАНГ ВЫШЕ", "stat": "eq_tyaga", "need": 1, "xp": 60, "points": 0, "money": 0},
	{"id": "ms_biz1", "name": "ПЕРВАЯ МАСТЕРСКАЯ", "stat": "biz_count", "need": 1, "xp": 150, "points": 1, "money": 0},
	{"id": "ms_staff1", "name": "ПЕРВЫЙ СОТРУДНИК", "stat": "staff", "need": 1, "xp": 100, "points": 1, "money": 0},
	{"id": "ms_earn100", "name": "100 000 ₽ ЗАРАБОТАНО", "stat": "earned", "need": 100000, "xp": 250, "points": 2, "money": 5000},
	{"id": "ms_biz3", "name": "ТРИ ИСТОЧНИКА ДОХОДА", "stat": "biz_count", "need": 3, "xp": 300, "points": 2, "money": 0},
	{"id": "ms_auto", "name": "ПЕРВЫЙ АВТОМАТИЗИРОВАННЫЙ БИЗНЕС", "stat": "auto", "need": 1, "xp": 250, "points": 1, "money": 0},
	{"id": "ms_week3", "name": "ТРЕТЬЯ НЕДЕЛЯ ПОЗАДИ", "stat": "weeks", "need": 3, "xp": 200, "points": 1, "money": 0},
	{"id": "ms_earn1m", "name": "МИЛЛИОН", "stat": "earned", "need": 1000000, "xp": 600, "points": 3, "money": 20000},
	{"id": "ms_mogul", "name": "МЕСТНЫЙ ПРЕДПРИНИМАТЕЛЬ", "stat": "biz_count", "need": 5, "xp": 500, "points": 2, "money": 0},
]

## ЛЕГЕНДА РАЙОНА: постоянные бонусы за АВТОРИТЕТ (престиж); цена за ранг
const LEGEND := [
	{"id": "L_start", "name": "ЗАНАЧКА", "max": 5, "cost": 1, "eff": {"start_money": 2500}, "desc": "каждая новая неделя начинается с бо́льшими деньгами"},
	{"id": "L_xp", "name": "ОПЫТ ПРОШЛЫХ ЖИЗНЕЙ", "max": 5, "cost": 1, "eff": {"xp": 0.15}, "desc": "опыт +15 % за ранг"},
	{"id": "L_act", "name": "РАННИЙ ПОДЪЁМ", "max": 1, "cost": 4, "eff": {"actions": 1.0}, "desc": "+1 действие каждый день навсегда"},
	{"id": "L_staff", "name": "СВОИ ЛЮДИ", "max": 2, "cost": 3, "eff": {"staff": 1.0}, "desc": "+1 место сотрудника во всех бизнесах"},
	{"id": "L_gold", "name": "ЗОЛОТАЯ ТЯГА", "max": 1, "cost": 5, "eff": {"eq:tyaga": 2.0, "tyaga_turbo": 1.0}, "desc": "ТЯГА сразу на два ранга выше и с турбо"},
	{"id": "L_biz", "name": "ДОБРОЕ ИМЯ", "max": 3, "cost": 2, "eff": {"bizinc": 0.1, "biz_start": 1.0}, "desc": "бизнесы приносят больше; первый бизнес открыт с начала"},
	{"id": "L_rate", "name": "КРЕДИТНАЯ ИСТОРИЯ", "max": 3, "cost": 2, "eff": {"rate": -0.06, "fine": -0.1}, "desc": "проценты и штрафы ниже навсегда"},
	{"id": "L_points", "name": "БЫСТРЫЙ СТАРТ", "max": 3, "cost": 2, "eff": {"start_points": 2.0}, "desc": "+2 очка навыков в начале каждого цикла"},
]
const LEGEND_LEVEL := 15            # с какого уровня открывается престиж
const LEGEND_EARN := 600000         # или сколько заработать за цикл

static func node(id: String) -> Dictionary:
	for n in NODES:
		if String(n["id"]) == id:
			return n
	return {}

static func legend(id: String) -> Dictionary:
	for n in LEGEND:
		if String(n["id"]) == id:
			return n
	return {}
