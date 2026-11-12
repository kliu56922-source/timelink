extends Node
class_name CardLibrary

const CardDataClass = preload("res://core/card/card_data.gd")
const ODEffectClass = preload("res://core/effect/od_effect.gd")
const EnemyODEffectClass = preload("res://core/effect/enemy_od_effect.gd")
const ShieldEffectClass = preload("res://core/effect/shield_effect.gd")
const DamageEffectClass = preload("res://core/effect/damage_effect.gd")
const DrawEffectClass = preload("res://core/effect/draw_effect.gd")
const SelfDamageEffectClass = preload("res://core/effect/self_damage_effect.gd")
const ConditionalDamageEffectClass = preload("res://core/effect/conditional_damage_effect.gd")
const CardCatalogLoaderClass = preload("res://core/deck/card_catalog_loader.gd")

var all_cards: Array = []


func _ready():
	if all_cards.is_empty():
		generate_cards()


func _set_card_keywords(card: CardData, values: Array) -> void:
	card.keywords.clear()
	for v in values:
		card.keywords.append(str(v))


## 快速设置牌桌归属字段
func _apply_zone(card: CardData, zone: int, dtype: int) -> void:
	card.board_zone = zone
	card.display_type = dtype


## 设置持续后场卡字段
func _apply_sustain(card: CardData, duration: int, effect_id: String) -> void:
	card.is_continuous = true
	card.continuous_duration = duration
	card.on_field_effect = effect_id


## Phase 27I-R0: 设置固定棋子身份（legacy fallback 与 JSON 保持同一契约）
func _apply_piece_identity(card: CardData, piece_type: String, enabled: bool, profile_id: String, payload_id: String) -> void:
	card.piece_type = StringName(piece_type)
	card.piece_enabled = enabled
	card.piece_effect_profile_id = StringName(profile_id)
	card.piece_payload_id = StringName(payload_id)


## Phase 5A 卡牌身份统一入口
func _apply_phase5_identity(
	card: CardData,
	card_id: String,
	display_name: String,
	family: String,
	role: int,
	condition_text: String = "",
	od_interface: String = "",
	charge_text: String = "",
	resonance_text: String = "",
	risk_text: String = ""
) -> void:
	card.card_id = card_id
	card.display_name = display_name
	card.english_name = card.card_name
	card.card_family = family
	card.archetype_role = role
	card.activation_condition_text = condition_text
	card.od_interface_text = od_interface
	card.building_charge_text = charge_text
	card.building_resonance_text = resonance_text
	card.risk_text = risk_text
	if not card.card_name in card.legacy_names:
		card.legacy_names.append(card.card_name)

	# 建筑卡统一设置
	if family == "building":
		card.card_type = CardData.CardType.TRAP
		card.board_zone = CardData.BoardZone.BACK_ROW
		card.display_type = CardData.DisplayType.SUSTAIN
		card.is_continuous = true
		if card.continuous_duration <= 0:
			card.continuous_duration = 99

	# 反制卡统一设置
	if family == "counter":
		card.card_type = CardData.CardType.TRAP
		card.board_zone = CardData.BoardZone.BACK_ROW
		card.display_type = CardData.DisplayType.TRAP
		card.is_continuous = false

	# 怪兽卡统一设置
	if family == "monster":
		card.card_type = CardData.CardType.UNIT
		card.board_zone = CardData.BoardZone.FRONT_ROW
		card.display_type = CardData.DisplayType.UNIT

	# 魔法卡统一设置
	if family == "spell":
		card.card_type = CardData.CardType.SPELL
		card.board_zone = CardData.BoardZone.INSTANT
		card.display_type = CardData.DisplayType.NONE


## 旧卡名到新卡名的兼容映射
## 返回匹配的新 card_name，如果不匹配则返回空
func resolve_legacy_name(legacy_name: String) -> String:
	match legacy_name:
		"Warm Up": return "Warm-Up Rite"
		"Spark Ignition": return "Ember Familiar"
		"Blazing Soldier": return "Spark Vanguard"
		"Route Spark": return "Signal Tripwire"
		"Quick Boost": return "Emergency Vent"
		"Heat Shield": return "Thermal Bulwark"
		"Thermal Lance": return "Heat Channeler"
		"Rising Heat": return "Overclock Pulse"
		"Overclock": return "Overclock Pulse"
		"Flame Channeler": return "Chain Conductor"
		"Pressure Loop": return "Pressure Relay"
		"Signal Relay": return "Reactor Foundation"
		"Overload Disrupt": return "Chain Breaker"
		"Nova Burst": return "Overdrive Eruption"
	return ""


# =====================================================================
# Phase 5A — 正式 20 张基础卡牌库
# =====================================================================

func _own_templates() -> void:
	for card in all_cards:
		if is_instance_valid(card) and card.get_parent() == null:
			add_child(card)


func generate_cards():
	# Only dispose definitions owned by this library, never borrowed/reparented cards.
	for child in get_children():
		if child is CardData:
			child.free()
	all_cards.clear()
	# Phase 5C-2: 优先从 JSON 加载，失败则 fallback 到硬编码
	var loader := CardCatalogLoaderClass.new()
	var json_cards := loader.load_player_cards()
	if json_cards.size() >= 20:
		all_cards = json_cards
		_apply_json_cards_metadata()
		# Phase 13C: 并行加载 Arsenal 卡（不影响主卡组）
		loader.load_arsenal_cards()
		for unused in loader.get_arsenal_cards():
			unused.free()
		loader.free()
		_own_templates()
		print("[CardLibrary] Phase 5C — Loaded %d cards from JSON." % all_cards.size())
		return
	# Fallback
	push_warning("[CardLibrary] JSON load failed (%d cards) — using hardcoded fallback." % json_cards.size())
	for unused in json_cards:
		unused.free()
	loader.free()
	_generate_cards_legacy()
	_own_templates()
	print("[CardLibrary] Phase 5A fallback — Generated %d cards from hardcoded." % all_cards.size())

	# =====================================================================

func _generate_cards_legacy():
	all_cards.clear()

	# STARTER — 5 张 (P01-P05)
	# =====================================================================

	# ── P01 预热仪式 / Warm-Up Rite — 魔法 ──
	var p01 := CardDataClass.new()
	p01.card_name = "Warm-Up Rite"
	p01.card_id = "P01"
	p01.display_name = "预热仪式"
	p01.english_name = "Warm-Up Rite"
	p01.card_family = "spell"
	p01.archetype_role = CardData.ArchetypeRole.STARTER
	p01.rarity = CardData.CardRarity.COMMON
	p01.od_cost = 0
	p01.load_cost = 1
	p01.require_od = 0
	p01.short_description = "低OD抽牌 高OD强化"
	p01.description = "基础：抽1张，自身OD+1。Heated：再使1只友方怪兽+1 ATK。Overdrive：下一张怪兽Load -1，Depth +1。"
	p01.calm_text = "基础：抽1张，自身OD+1。"
	p01.heated_text = "追加：使1只友方怪兽+1 ATK。"
	p01.overdrive_text = "追加：下一张怪兽Load -1；Depth +1。"
	p01.route_id = "heat_route"
	p01.route_step = 1
	p01.next_cards = ["Ignite Blade", "Heat Channeler"]
	p01.combo_reward_text = "Final Slash 额外触发一次"
	p01.combo_hint = "Heat Route 起点 → Ignite Blade"
	p01.legacy_names = ["Warm Up", "Warm-Up Rite"]
	p01.art_id = "warm_up_rite"
	p01.color_theme = "blue"
	p01.flavor_text = "「预热不是浪费时间，是积蓄力量。」"
	p01.art_path = "res://assets/cards/thumbs/card_p01_warm_up_rite.png"
	_apply_zone(p01, CardData.BoardZone.INSTANT, CardData.DisplayType.NONE)
	var p01_od := ODEffectClass.new(); p01_od.amount = 1
	var p01_draw := DrawEffectClass.new(); p01_draw.amount = 1
	p01.effects = [p01_od, p01_draw]
	_set_card_keywords(p01, ["overload"])
	_apply_piece_identity(p01, "pawn", true, "pawn_anchor_fan", "p01_formation_shield")
	all_cards.append(p01)

	# ── P02 燃芯使魔 / Ember Familiar — 怪兽 ──
	var p02 := CardDataClass.new()
	p02.card_name = "Ember Familiar"
	p02.card_id = "P02"
	p02.display_name = "燃芯使魔"
	p02.english_name = "Ember Familiar"
	p02.card_family = "monster"
	p02.archetype_role = CardData.ArchetypeRole.STARTER
	p02.rarity = CardData.CardRarity.COMMON
	p02.od_cost = 0
	p02.load_cost = 1
	p02.require_od = 0
	p02.unit_power = 1
	p02.unit_defense = 3
	p02.unit_description = "ATK:1 DEF:3"
	p02.short_description = "前场小怪 OD启动"
	p02.description = "基础：前场怪兽，入场自身OD+1。Heated：获得+1 ATK。Overdrive：如果控制建筑，入场再获得护盾+1。"
	p02.calm_text = "基础：入场自身OD+1。"
	p02.heated_text = "追加：本体+1 ATK。"
	p02.overdrive_text = "建筑共鸣：若控制建筑，护盾+1。"
	p02.route_id = "heat_route"
	p02.route_step = 1
	p02.next_cards = ["Ignite Blade", "Heat Channeler"]
	p02.combo_reward_text = "Final Slash 额外触发一次"
	p02.combo_hint = "Heat Route 起点 → Ignite Blade"
	p02.legacy_names = ["Spark Ignition", "Ember Familiar"]
	p02.art_id = "ember_familiar"
	p02.color_theme = "blue"
	p02.flavor_text = "「一粒火花足以点燃整个反应堆。」"
	p02.art_path = "res://assets/cards/thumbs/card_p02_ember_familiar.png"
	_apply_zone(p02, CardData.BoardZone.FRONT_ROW, CardData.DisplayType.UNIT)
	p02.on_field_effect = "starter_od_anchor"
	var p02_od := ODEffectClass.new(); p02_od.amount = 1
	p02.effects = [p02_od]
	_set_card_keywords(p02, ["overload"])
	_apply_piece_identity(p02, "knight", true, "knight_unit", "p02_knight_action")
	all_cards.append(p02)

	# ── P03 火花先锋 / Spark Vanguard — 怪兽 ──
	var p03 := CardDataClass.new()
	p03.card_name = "Spark Vanguard"
	p03.card_id = "P03"
	p03.display_name = "火花先锋"
	p03.english_name = "Spark Vanguard"
	p03.card_family = "monster"
	p03.archetype_role = CardData.ArchetypeRole.STARTER
	p03.rarity = CardData.CardRarity.COMMON
	p03.od_cost = 0
	p03.load_cost = 1
	p03.require_od = 0
	p03.unit_power = 2
	p03.unit_defense = 2
	p03.unit_description = "ATK:2 DEF:2"
	p03.short_description = "Heated突击怪兽"
	p03.description = "基础：前场怪兽，入场造成2点伤害。Heated：额外+1伤害。Overdrive：本体+1 ATK，但Depth +1。"
	p03.calm_text = "基础：入场造成2点伤害。"
	p03.heated_text = "追加：伤害+1。"
	p03.overdrive_text = "追加：ATK +1；Depth +1。"
	p03.route_id = "overdrive_route"
	p03.route_step = 1
	p03.next_cards = ["Overclock Pulse"]
	p03.combo_reward_text = "Overdrive Eruption 伤害+4"
	p03.combo_hint = "Overdrive Route 起点 → Overclock Pulse"
	p03.legacy_names = ["Blazing Soldier", "Spark Vanguard"]
	p03.art_id = "spark_vanguard"
	p03.color_theme = "orange"
	p03.flavor_text = "「燃烧自己，照亮战场。」"
	p03.art_path = "res://assets/cards/thumbs/card_p03_spark_vanguard.png"
	_apply_zone(p03, CardData.BoardZone.FRONT_ROW, CardData.DisplayType.UNIT)
	p03.on_field_effect = "heated_attacker"
	var p03_dmg := DamageEffectClass.new(); p03_dmg.base_damage = 2
	p03.effects = [p03_dmg]
	_set_card_keywords(p03, [])
	_apply_piece_identity(p03, "pawn", true, "pawn_unit", "p03_vanguard_formation")
	all_cards.append(p03)

	# ── P04 断频伏线 / Signal Tripwire — 反制 ──
	var p04 := CardDataClass.new()
	p04.card_name = "Signal Tripwire"
	p04.card_id = "P04"
	p04.display_name = "断频伏线"
	p04.english_name = "Signal Tripwire"
	p04.card_family = "counter"
	p04.archetype_role = CardData.ArchetypeRole.STARTER
	p04.rarity = CardData.CardRarity.COMMON
	p04.od_cost = 0
	p04.load_cost = 1
	p04.require_od = 0
	p04.short_description = "路线启动 OD伏线"
	p04.description = "反制。Boss OD增长时触发：Boss OD -2，自身OD+1。Heated：护盾+2。Overdrive：若控制建筑，抽1张。"
	p04.calm_text = "基础：Boss OD增长时阻断-2，自身OD+1。"
	p04.heated_text = "追加：护盾+2。"
	p04.overdrive_text = "建筑共鸣：若控制建筑，抽1张。"
	p04.route_id = "control_route"
	p04.route_step = 1
	p04.next_cards = ["Jam Signal", "Cooldown"]
	p04.combo_reward_text = "Chain Breaker 额外 Boss OD -2"
	p04.combo_hint = "Control Route 起点 → Jam Signal"
	p04.legacy_names = ["Route Spark", "Signal Tripwire"]
	p04.art_id = "signal_tripwire"
	p04.color_theme = "blue"
	p04.flavor_text = "「方向比速度更重要。」"
	p04.art_path = "res://assets/cards/thumbs/card_p04_signal_tripwire.png"
	_apply_zone(p04, CardData.BoardZone.BACK_ROW, CardData.DisplayType.TRAP)
	p04.on_field_effect = "signal_tripwire"
	var p04_od := ODEffectClass.new(); p04_od.amount = 1
	var p04_eod := EnemyODEffectClass.new(); p04_eod.amount = -2
	p04.effects = [p04_od, p04_eod]
	_set_card_keywords(p04, ["jam"])
	_apply_piece_identity(p04, "pawn", true, "pawn_counter_watch", "p04_tripwire_watch")
	all_cards.append(p04)

	# ── P05 炉基座 / Reactor Foundation — 建筑 ──
	var p05 := CardDataClass.new()
	p05.card_name = "Reactor Foundation"
	p05.card_id = "P05"
	p05.display_name = "炉基座"
	p05.english_name = "Reactor Foundation"
	p05.card_family = "building"
	p05.archetype_role = CardData.ArchetypeRole.STARTER
	p05.rarity = CardData.CardRarity.COMMON
	p05.od_cost = 0
	p05.load_cost = 1
	p05.require_od = 0
	p05.short_description = "基础建筑 OD接口"
	p05.description = "建筑。入场OD+1，护盾+2。持续提供OD接口：消耗OD强化怪兽或抵抗Depth。"
	p05.calm_text = "基础：入场OD+1，护盾+2；防止首次Depth增加。"
	p05.heated_text = "解锁：消耗OD/充能强化怪兽+1/+1。"
	p05.overdrive_text = "追加：1只休眠怪兽保持行动；OD接口费用-1。"
	p05.activation_condition_text = "本局已获得≥2点OD，或Depth>=2。"
	p05.od_interface_text = "每回合一次，消耗2 OD或2层充能使1只怪兽+1/+1；或消耗1 OD使下次Depth增加-1。"
	p05.building_charge_text = "每获得OD，获得1层炉基充能，每回合最多2层，上限4层。"
	p05.building_resonance_text = "若炉基充能>=3，防止Depth时额外护盾+1。"
	p05.route_id = "control_route"
	p05.route_step = 1
	p05.next_cards = ["Heat Sink", "Cooldown"]
	p05.combo_reward_text = "Chain Breaker 额外 Boss OD -2"
	p05.combo_hint = "Control Route 起点 → Heat Sink"
	p05.legacy_names = ["Signal Relay", "Reactor Foundation"]
	p05.art_id = "reactor_foundation"
	p05.color_theme = "blue"
	p05.flavor_text = "「信号不止于传递——它本身就是力量。」"
	p05.art_path = "res://assets/cards/thumbs/card_p05_reactor_foundation.png"
	_apply_zone(p05, CardData.BoardZone.BACK_ROW, CardData.DisplayType.SUSTAIN)
	_apply_sustain(p05, 99, "reactor_foundation")
	var p05_od := ODEffectClass.new(); p05_od.amount = 1
	var p05_shield := ShieldEffectClass.new(); p05_shield.amount = 2
	p05.effects = [p05_od, p05_shield]
	_set_card_keywords(p05, [])
	_apply_piece_identity(p05, "pawn", true, "pawn_building_aura", "p05_foundation_guard")
	all_cards.append(p05)

	# =====================================================================
	# EXTENDER — 5 张 (P06-P10)
	# =====================================================================

	# ── P06 点火刃 / Ignite Blade — 魔法 ──
	var p06 := CardDataClass.new()
	p06.card_name = "Ignite Blade"
	p06.card_id = "P06"
	p06.display_name = "点火刃"
	p06.english_name = "Ignite Blade"
	p06.card_family = "spell"
	p06.archetype_role = CardData.ArchetypeRole.EXTENDER
	p06.rarity = CardData.CardRarity.COMMON
	p06.od_cost = 0
	p06.load_cost = 1
	p06.require_od = 0
	p06.short_description = "怪兽强化 场面斩击"
	p06.description = "基础：造成2点场面伤害。前场有怪兽时追加1点。Heated：目标友方怪兽+2 ATK。Overdrive：可消耗2 OD再触发一次强化。"
	p06.calm_text = "基础：造成2点伤害，有怪兽则+1。"
	p06.heated_text = "追加：1只友方怪兽+2 ATK。"
	p06.overdrive_text = "OD接口：消耗2 OD，再触发一次强化。"
	p06.route_id = "heat_route"
	p06.route_step = 2
	p06.next_cards = ["Pressure Relay", "Final Slash"]
	p06.combo_reward_text = "Final Slash 额外触发一次"
	p06.combo_hint = "Heat Route Step2 → Pressure Relay"
	p06.legacy_names = ["Ignite Blade"]
	p06.art_id = "ignite_blade"
	p06.color_theme = "orange"
	p06.flavor_text = "「每一把剑都在等待属于自己的火焰。」"
	p06.art_path = "res://assets/cards/thumbs/card_p06_ignite_blade.png"
	_apply_zone(p06, CardData.BoardZone.INSTANT, CardData.DisplayType.NONE)
	var p06_dmg := DamageEffectClass.new(); p06_dmg.base_damage = 2
	p06.effects = [p06_dmg]
	_set_card_keywords(p06, [])
	all_cards.append(p06)

	# ── P07 热流导体 / Heat Channeler — 怪兽 ──
	var p07 := CardDataClass.new()
	p07.card_name = "Heat Channeler"
	p07.card_id = "P07"
	p07.display_name = "热流导体"
	p07.english_name = "Heat Channeler"
	p07.card_family = "monster"
	p07.archetype_role = CardData.ArchetypeRole.EXTENDER
	p07.rarity = CardData.CardRarity.COMMON
	p07.od_cost = 0
	p07.load_cost = 2
	p07.require_od = 0
	p07.unit_power = 2
	p07.unit_defense = 4
	p07.unit_description = "ATK:2 DEF:4"
	p07.short_description = "OD转场面压力"
	p07.description = "基础：前场怪兽，造成2点伤害。获得OD时本回合+1 ATK。Heated：进场本回合额外+1 ATK。Overdrive：首次获得OD时对1只敌方怪兽造成1点伤害。"
	p07.calm_text = "基础：2/4身材，获得OD时+1 ATK。"
	p07.heated_text = "追加：进场本回合+1 ATK。"
	p07.overdrive_text = "追加：首次获得OD时对敌方怪兽造成1点伤害。"
	p07.route_id = "heat_route"
	p07.route_step = 2
	p07.next_cards = ["Pressure Relay", "Final Slash"]
	p07.combo_reward_text = "Final Slash 额外触发一次"
	p07.combo_hint = "Heat Route Step2 → Pressure Relay"
	p07.legacy_names = ["Thermal Lance", "Heat Channeler"]
	p07.art_id = "heat_channeler"
	p07.color_theme = "orange"
	p07.flavor_text = "「从精准到毁灭，只需要足够的热量。」"
	p07.art_path = "res://assets/cards/thumbs/card_p07_heat_channeler.png"
	_apply_zone(p07, CardData.BoardZone.FRONT_ROW, CardData.DisplayType.UNIT)
	p07.on_field_effect = "heat_channeler"
	var p07_dmg := DamageEffectClass.new(); p07_dmg.base_damage = 2
	p07.effects = [p07_dmg]
	_set_card_keywords(p07, [])
	all_cards.append(p07)

	# ── P08 压力继电塔 / Pressure Relay — 建筑 ──
	var p08 := CardDataClass.new()
	p08.card_name = "Pressure Relay"
	p08.card_id = "P08"
	p08.display_name = "压力继电塔"
	p08.english_name = "Pressure Relay"
	p08.card_family = "building"
	p08.archetype_role = CardData.ArchetypeRole.EXTENDER
	p08.rarity = CardData.CardRarity.COMMON
	p08.od_cost = 0
	p08.load_cost = 2
	p08.require_od = 4
	p08.short_description = "建筑引擎 Heat充能"
	p08.description = "建筑。入场OD+1，护盾+2。打出魔法后获得热量计数。Heated：进场自带1个计数。Overdrive：阈值奖励额外OD+1。"
	p08.calm_text = "基础：入场OD+1，护盾+2；可储存热量。"
	p08.heated_text = "追加：进场自带1热量计数。"
	p08.overdrive_text = "OD接口：阈值奖励额外OD+1。"
	p08.activation_condition_text = "当前OD>=4。"
	p08.od_interface_text = "每回合一次，若本回合已打出2张牌，消耗1 OD使1只怪兽+1/+1。"
	p08.building_charge_text = "每打出第2张牌，获得1层压力充能。"
	p08.building_resonance_text = "Heat Route推进时，压力充能可视为额外热量。"
	p08.route_id = "heat_route"
	p08.route_step = 3
	p08.next_cards = ["Final Slash"]
	p08.combo_reward_text = "Final Slash 额外触发一次"
	p08.combo_hint = "Heat Route Step3 → Final Slash"
	p08.legacy_names = ["Pressure Loop", "Pressure Relay"]
	p08.art_id = "pressure_relay"
	p08.color_theme = "orange"
	p08.flavor_text = "「压力不是问题——它是动力。」"
	p08.art_path = "res://assets/cards/thumbs/card_p08_pressure_relay.png"
	_apply_zone(p08, CardData.BoardZone.BACK_ROW, CardData.DisplayType.SUSTAIN)
	_apply_sustain(p08, 99, "pressure_relay")
	var p08_od := ODEffectClass.new(); p08_od.amount = 1
	var p08_shield := ShieldEffectClass.new(); p08_shield.amount = 2
	p08.effects = [p08_od, p08_shield]
	_set_card_keywords(p08, [])
	all_cards.append(p08)

	# ── P09 超频脉冲 / Overclock Pulse — 魔法 ──
	var p09 := CardDataClass.new()
	p09.card_name = "Overclock Pulse"
	p09.card_id = "P09"
	p09.display_name = "超频脉冲"
	p09.english_name = "Overclock Pulse"
	p09.card_family = "spell"
	p09.archetype_role = CardData.ArchetypeRole.EXTENDER
	p09.rarity = CardData.CardRarity.COMMON
	p09.od_cost = 2
	p09.load_cost = 1
	p09.require_od = 2
	p09.short_description = "OD推进 高OD冲击"
	p09.description = "基础：自身OD+2，抽1张。Heated：下一张怪兽获得+1 ATK。Overdrive：可消耗2 OD，对敌方前场造成2点伤害，Depth +1。"
	p09.calm_text = "基础：自身OD+2，抽1张。"
	p09.heated_text = "追加：下一张怪兽+1 ATK。"
	p09.overdrive_text = "OD接口：消耗2 OD，对敌方前场造成2点伤害；Depth +1。"
	p09.od_interface_text = "可消耗或推动OD来制造场面冲击。"
	p09.risk_text = "高OD使用会推高Depth。"
	p09.route_id = "overdrive_route"
	p09.route_step = 2
	p09.next_cards = ["Chain Conductor", "Overdrive Eruption"]
	p09.combo_reward_text = "Overdrive Eruption 伤害+4"
	p09.combo_hint = "Overdrive Route Step2 → Chain Conductor"
	p09.legacy_names = ["Overclock", "Rising Heat", "Overclock Pulse"]
	p09.art_id = "overclock_pulse"
	p09.color_theme = "red"
	p09.flavor_text = "「限制器？那只是建议。」"
	p09.art_path = "res://assets/cards/thumbs/card_p09_overclock_pulse.png"
	_apply_zone(p09, CardData.BoardZone.INSTANT, CardData.DisplayType.NONE)
	var p09_od := ODEffectClass.new(); p09_od.amount = 2
	var p09_draw := DrawEffectClass.new(); p09_draw.amount = 1
	p09.effects = [p09_od, p09_draw]
	_set_card_keywords(p09, ["overload"])
	all_cards.append(p09)

	# ── P10 连锁导体 / Chain Conductor — 怪兽 ──
	var p10 := CardDataClass.new()
	p10.card_name = "Chain Conductor"
	p10.card_id = "P10"
	p10.display_name = "连锁导体"
	p10.english_name = "Chain Conductor"
	p10.card_family = "monster"
	p10.archetype_role = CardData.ArchetypeRole.EXTENDER
	p10.rarity = CardData.CardRarity.COMMON
	p10.od_cost = 0
	p10.load_cost = 2
	p10.require_od = 0
	p10.unit_power = 3
	p10.unit_defense = 3
	p10.unit_description = "ATK:3 DEF:3"
	p10.short_description = "路线导体 抽牌"
	p10.description = "基础：前场怪兽，造成1点伤害并抽1张。推进路线时抽1张。Heated：护盾+2。Overdrive：本回合下次Depth增加-1。"
	p10.calm_text = "基础：造成1点伤害，抽1张；路线推进时再抽1张。"
	p10.heated_text = "追加：护盾+2。"
	p10.overdrive_text = "追加：下次Depth增加-1。"
	p10.route_id = "overdrive_route"
	p10.route_step = 3
	p10.next_cards = ["Overdrive Eruption"]
	p10.combo_reward_text = "Overdrive Eruption 伤害+4"
	p10.combo_hint = "Overdrive Route Step3 → Overdrive Eruption"
	p10.legacy_names = ["Flame Channeler", "Chain Conductor"]
	p10.art_id = "chain_conductor"
	p10.color_theme = "orange"
	p10.flavor_text = "「通道已经打开，能量正在汇聚。」"
	p10.art_path = "res://assets/cards/thumbs/card_p10_chain_conductor.png"
	_apply_zone(p10, CardData.BoardZone.FRONT_ROW, CardData.DisplayType.UNIT)
	p10.on_field_effect = "chain_channel"
	var p10_dmg := DamageEffectClass.new(); p10_dmg.base_damage = 1
	var p10_draw := DrawEffectClass.new(); p10_draw.amount = 1
	p10.effects = [p10_dmg, p10_draw]
	_set_card_keywords(p10, [])
	all_cards.append(p10)

	# =====================================================================
	# CONTROL — 4 张 (P11-P14)
	# =====================================================================

	# ── P11 冷却回路 / Cooldown — 魔法 ──
	var p11 := CardDataClass.new()
	p11.card_name = "Cooldown"
	p11.card_id = "P11"
	p11.display_name = "冷却回路"
	p11.english_name = "Cooldown"
	p11.card_family = "spell"
	p11.archetype_role = CardData.ArchetypeRole.CONTROL
	p11.rarity = CardData.CardRarity.COMMON
	p11.od_cost = 0
	p11.load_cost = 1
	p11.require_od = 0
	p11.short_description = "Depth恢复 Abyss刹车"
	p11.description = "基础：Depth -3，自身OD -2，护盾+2。Heated：Boss OD -2。Overdrive：解除Abyss Lock后抽1张。"
	p11.calm_text = "基础：Depth -3，自身OD -2，护盾+2。"
	p11.heated_text = "追加：Boss OD -2。"
	p11.overdrive_text = "若解除Abyss Lock：抽1张。"
	p11.route_id = "control_route"
	p11.route_step = 2
	p11.next_cards = ["Chain Breaker"]
	p11.combo_reward_text = "Chain Breaker 额外 Boss OD -2"
	p11.combo_hint = "Control Route Step2 → Chain Breaker"
	p11.legacy_names = ["Cooldown"]
	p11.art_id = "cooldown"
	p11.color_theme = "blue"
	p11.flavor_text = "「热到极致之后，是绝对零度。」"
	p11.art_path = "res://assets/cards/thumbs/card_p11_cooldown.png"
	_apply_zone(p11, CardData.BoardZone.INSTANT, CardData.DisplayType.NONE)
	var p11_od := ODEffectClass.new(); p11_od.amount = -2
	var p11_shield := ShieldEffectClass.new(); p11_shield.amount = 2
	p11.effects = [p11_od, p11_shield]
	_set_card_keywords(p11, [])
	all_cards.append(p11)

	# ── P12 干扰信号 / Jam Signal — 反制 ──
	var p12 := CardDataClass.new()
	p12.card_name = "Jam Signal"
	p12.card_id = "P12"
	p12.display_name = "干扰信号"
	p12.english_name = "Jam Signal"
	p12.card_family = "counter"
	p12.archetype_role = CardData.ArchetypeRole.CONTROL
	p12.rarity = CardData.CardRarity.COMMON
	p12.od_cost = 0
	p12.load_cost = 1
	p12.require_od = 0
	p12.short_description = "反制 Boss OD"
	p12.description = "反制。Boss OD增长时触发：Boss OD -2。Heated：护盾+2。Overdrive：额外Depth -1。"
	p12.calm_text = "基础：Boss OD增长时，Boss OD -2。"
	p12.heated_text = "追加：护盾+2。"
	p12.overdrive_text = "追加：Depth -1。"
	p12.route_id = "control_route"
	p12.route_step = 1
	p12.next_cards = ["Cooldown"]
	p12.combo_reward_text = "Chain Breaker 额外 Boss OD -2"
	p12.combo_hint = "Control Route Step1 → Cooldown"
	p12.legacy_names = ["Jam Signal"]
	p12.art_id = "jam_signal"
	p12.color_theme = "blue"
	p12.flavor_text = "「在信息战中，沉默是最强的武器。」"
	p12.art_path = "res://assets/cards/thumbs/card_p12_jam_signal.png"
	_apply_zone(p12, CardData.BoardZone.BACK_ROW, CardData.DisplayType.TRAP)
	p12.on_field_effect = "jam_signal"
	var p12_eod := EnemyODEffectClass.new(); p12_eod.amount = -2
	p12.effects = [p12_eod]
	_set_card_keywords(p12, ["jam"])
	all_cards.append(p12)

	# ── P13 热沉装置 / Heat Sink — 建筑 ──
	var p13 := CardDataClass.new()
	p13.card_name = "Heat Sink"
	p13.card_id = "P13"
	p13.display_name = "热沉装置"
	p13.english_name = "Heat Sink"
	p13.card_family = "building"
	p13.archetype_role = CardData.ArchetypeRole.CONTROL
	p13.rarity = CardData.CardRarity.COMMON
	p13.od_cost = 0
	p13.load_cost = 2
	p13.require_od = 0
	p13.short_description = "建筑冷却 Depth抵抗"
	p13.description = "建筑。入场护盾+3。Depth>=3时Depth -1；Depth>=6时额外护盾+2。Overdrive：OD接口费用-1。"
	p13.calm_text = "基础：护盾+3。"
	p13.heated_text = "若Depth>=3：Depth -1。"
	p13.overdrive_text = "若Depth>=6：额外护盾+2；OD接口费用-1。"
	p13.activation_condition_text = "任意Depth；Depth越高越强。"
	p13.od_interface_text = "每回合一次，消耗1 OD使下一次Depth增加-1。"
	p13.building_charge_text = "每当Depth被降低，本建筑获得1层冷却充能。"
	p13.building_resonance_text = "冷却充能可转化为护盾。"
	p13.route_id = "control_route"
	p13.route_step = 2
	p13.next_cards = ["Chain Breaker"]
	p13.combo_reward_text = "Chain Breaker 额外 Boss OD -2"
	p13.combo_hint = "Control Route Step2 → Chain Breaker"
	p13.legacy_names = ["Heat Sink"]
	p13.art_id = "heat_sink"
	p13.color_theme = "blue"
	p13.flavor_text = "「真正的坚壁，连太阳的热量都能吸收。」"
	p13.art_path = "res://assets/cards/thumbs/card_p13_heat_sink.png"
	_apply_zone(p13, CardData.BoardZone.BACK_ROW, CardData.DisplayType.SUSTAIN)
	_apply_sustain(p13, 99, "heat_sink_building")
	var p13_shield := ShieldEffectClass.new(); p13_shield.amount = 3
	p13.effects = [p13_shield]
	_set_card_keywords(p13, ["shield"])
	all_cards.append(p13)

	# ── P14 连锁断路器 / Chain Breaker — 反制 ──
	var p14 := CardDataClass.new()
	p14.card_name = "Chain Breaker"
	p14.card_id = "P14"
	p14.display_name = "连锁断路器"
	p14.english_name = "Chain Breaker"
	p14.card_family = "counter"
	p14.archetype_role = CardData.ArchetypeRole.CONTROL
	p14.rarity = CardData.CardRarity.RARE
	p14.od_cost = 0
	p14.load_cost = 2
	p14.require_od = 0
	p14.short_description = "Control终点 BossOD断路"
	p14.description = "反制。Boss高危行动时触发：Boss OD -4。完成Control Route时额外Boss OD -2（总计-6）。"
	p14.calm_text = "基础：Boss高危行动时Boss OD -4。"
	p14.heated_text = "Control Route完成：额外Boss OD -2。"
	p14.overdrive_text = "建筑共鸣：触发后Depth -1。"
	p14.route_id = "control_route"
	p14.route_step = 3
	p14.next_cards = []
	p14.combo_reward_text = "Chain Breaker 额外 Boss OD -2"
	p14.combo_hint = "Control Route终点——需要Cooldown/Heat Sink铺垫"
	p14.legacy_names = ["Chain Breaker", "Overload Disrupt"]
	p14.art_id = "chain_breaker"
	p14.color_theme = "red"
	p14.flavor_text = "「连破坏本身，也可以被破坏。」"
	p14.art_path = "res://assets/cards/thumbs/card_p14_chain_breaker.png"
	_apply_zone(p14, CardData.BoardZone.BACK_ROW, CardData.DisplayType.TRAP)
	p14.on_field_effect = "chain_breaker"
	var p14_eod := EnemyODEffectClass.new(); p14_eod.amount = -4
	p14.effects = [p14_eod]
	_set_card_keywords(p14, ["jam"])
	all_cards.append(p14)

	# =====================================================================
	# DEFENSE — 3 张 (P15-P17)
	# =====================================================================

	# ── P15 热压壁垒兽 / Thermal Bulwark — 怪兽 ──
	var p15 := CardDataClass.new()
	p15.card_name = "Thermal Bulwark"
	p15.card_id = "P15"
	p15.display_name = "热压壁垒兽"
	p15.english_name = "Thermal Bulwark"
	p15.card_family = "monster"
	p15.archetype_role = CardData.ArchetypeRole.DEFENSE
	p15.rarity = CardData.CardRarity.COMMON
	p15.od_cost = 0
	p15.load_cost = 2
	p15.require_od = 0
	p15.unit_power = 1
	p15.unit_defense = 6
	p15.unit_description = "ATK:1 DEF:6"
	p15.short_description = "防御怪兽 护盾"
	p15.description = "基础：前场防御怪兽，入场护盾+3。Heated：DEF +1。Overdrive：首次将被破坏时，消耗2 OD保留1 DEF。"
	p15.calm_text = "基础：入场护盾+3。"
	p15.heated_text = "追加：DEF +1。"
	p15.overdrive_text = "OD接口：消耗2 OD，抵抗一次破坏。"
	p15.od_interface_text = "Overdrive时可消耗2 OD抵抗一次破坏。"
	p15.route_id = ""
	p15.route_step = 0
	p15.next_cards = []
	p15.combo_reward_text = ""
	p15.combo_hint = "独立防御单位，保护前场"
	p15.legacy_names = ["Heat Shield", "Thermal Bulwark"]
	p15.art_id = "thermal_bulwark"
	p15.color_theme = "blue"
	p15.flavor_text = "「最好的防御，是把攻击变成燃料。」"
	p15.art_path = "res://assets/cards/thumbs/card_p15_thermal_bulwark.png"
	_apply_zone(p15, CardData.BoardZone.FRONT_ROW, CardData.DisplayType.UNIT)
	p15.on_field_effect = "guard_anchor"
	var p15_shield := ShieldEffectClass.new(); p15_shield.amount = 3
	p15.effects = [p15_shield]
	_set_card_keywords(p15, ["shield"])
	all_cards.append(p15)

	# ── P16 封压壁 / Containment Wall — 建筑 ──
	var p16 := CardDataClass.new()
	p16.card_name = "Containment Wall"
	p16.card_id = "P16"
	p16.display_name = "封压壁"
	p16.english_name = "Containment Wall"
	p16.card_family = "building"
	p16.archetype_role = CardData.ArchetypeRole.DEFENSE
	p16.rarity = CardData.CardRarity.COMMON
	p16.od_cost = 0
	p16.load_cost = 2
	p16.require_od = 0
	p16.short_description = "防破坏 保护建筑"
	p16.description = "建筑。入场护盾+3。防止一次友方怪兽或建筑被破坏。Heated：被保护怪兽恢复+2 DEF。Overdrive：触发后Depth -1。"
	p16.calm_text = "基础：护盾+3，防一次破坏。"
	p16.heated_text = "追加：被保护怪兽恢复+2 DEF。"
	p16.overdrive_text = "追加：触发后Depth -1。"
	p16.activation_condition_text = "任意OD阶段均可设置。"
	p16.od_interface_text = "被破坏时可消耗1 OD换取护盾+2。"
	p16.route_id = ""
	p16.route_step = 0
	p16.next_cards = []
	p16.combo_reward_text = ""
	p16.combo_hint = "保险建筑，防止关键怪兽被破坏"
	p16.legacy_names = ["Containment Wall"]
	p16.art_id = "containment_wall"
	p16.color_theme = "blue"
	p16.flavor_text = "「有些墙不只是墙，是最后的防线。」"
	p16.art_path = "res://assets/cards/thumbs/card_p16_containment_wall.png"
	_apply_zone(p16, CardData.BoardZone.BACK_ROW, CardData.DisplayType.SUSTAIN)
	_apply_sustain(p16, 99, "containment_wall")
	p16.continuous_duration = 1  # 触发一次后消失
	var p16_shield := ShieldEffectClass.new(); p16_shield.amount = 3
	p16.effects = [p16_shield]
	_set_card_keywords(p16, ["shield"])
	all_cards.append(p16)

	# ── P17 紧急泄压 / Emergency Vent — 魔法 ──
	var p17 := CardDataClass.new()
	p17.card_name = "Emergency Vent"
	p17.card_id = "P17"
	p17.display_name = "紧急泄压"
	p17.english_name = "Emergency Vent"
	p17.card_family = "spell"
	p17.archetype_role = CardData.ArchetypeRole.DEFENSE
	p17.rarity = CardData.CardRarity.COMMON
	p17.od_cost = 0
	p17.load_cost = 1
	p17.require_od = 0
	p17.short_description = "抽牌护盾 高Depth恢复"
	p17.description = "基础：抽1张，获得2点护盾。Heated：额外护盾+1。Overdrive：若Depth>=6，Depth -2。"
	p17.calm_text = "基础：抽1张，护盾+2。"
	p17.heated_text = "追加：护盾+1。"
	p17.overdrive_text = "若Depth>=6：Depth -2。"
	p17.route_id = ""
	p17.route_step = 0
	p17.next_cards = []
	p17.combo_reward_text = ""
	p17.combo_hint = "紧急按钮，高Depth时更强"
	p17.legacy_names = ["Quick Boost", "Emergency Vent"]
	p17.art_id = "emergency_vent"
	p17.color_theme = "blue"
	p17.flavor_text = "「速度即是力量——但别忘了刹车。」"
	p17.art_path = "res://assets/cards/thumbs/card_p17_emergency_vent.png"
	_apply_zone(p17, CardData.BoardZone.INSTANT, CardData.DisplayType.NONE)
	var p17_draw := DrawEffectClass.new(); p17_draw.amount = 1
	var p17_shield := ShieldEffectClass.new(); p17_shield.amount = 2
	p17.effects = [p17_draw, p17_shield]
	_set_card_keywords(p17, ["rapid"])
	all_cards.append(p17)

	# =====================================================================
	# FINISHER — 3 张 (P18-P20)
	# =====================================================================

	# ── P18 终端斩击 / Final Slash — 魔法 ──
	var p18 := CardDataClass.new()
	p18.card_name = "Final Slash"
	p18.card_id = "P18"
	p18.display_name = "终端斩击"
	p18.english_name = "Final Slash"
	p18.card_family = "spell"
	p18.archetype_role = CardData.ArchetypeRole.FINISHER
	p18.rarity = CardData.CardRarity.SUPER
	p18.od_cost = 0
	p18.load_cost = 2
	p18.require_od = 4
	p18.short_description = "Heat终结 场面爆发"
	p18.description = "终结。造成12点伤害。完成Heat Route时额外触发一次。Overdrive：额外+5。需要OD>=4铺垫。"
	p18.calm_text = "不能发挥完整威力。"
	p18.heated_text = "Heat Route完成时额外触发一次。"
	p18.overdrive_text = "追加：伤害+5。"
	p18.route_id = "heat_route"
	p18.route_step = 4
	p18.next_cards = []
	p18.combo_reward_text = "Final Slash 额外触发一次"
	p18.combo_hint = "Heat Route终点——需要Pressure Relay铺垫"
	p18.legacy_names = ["Final Slash"]
	p18.art_id = "final_slash"
	p18.color_theme = "red"
	p18.flavor_text = "「这一剑，是整场战斗的句号。」"
	p18.art_path = "res://assets/cards/thumbs/card_p18_final_slash.png"
	_apply_zone(p18, CardData.BoardZone.INSTANT, CardData.DisplayType.NONE)
	var p18_dmg := DamageEffectClass.new(); p18_dmg.base_damage = 12
	p18.effects = [p18_dmg]
	_set_card_keywords(p18, [])
	all_cards.append(p18)

	# ── P19 炉心圣堂 / Core Cathedral — 建筑 ──
	var p19 := CardDataClass.new()
	p19.card_name = "Core Cathedral"
	p19.card_id = "P19"
	p19.display_name = "炉心圣堂"
	p19.english_name = "Core Cathedral"
	p19.card_family = "building"
	p19.archetype_role = CardData.ArchetypeRole.FINISHER
	p19.rarity = CardData.CardRarity.SUPER
	p19.od_cost = 0
	p19.load_cost = 3
	p19.require_od = 8
	p19.short_description = "OD高潮奇观 全局加成"
	p19.description = "建筑。不能用于Calm/Heated。Overdrive：完整生效。每回合忽略第一次Depth增加。OD为10时怪兽+1 ATK。"
	p19.calm_text = "不能使用。"
	p19.heated_text = "不能使用（除非其他效果允许）。"
	p19.overdrive_text = "完整生效：忽略Depth增加，怪兽ATK+1。"
	p19.activation_condition_text = "OD>=8。Overdrive阶段可用。"
	p19.od_interface_text = "OD为10时可消耗2 OD使1只怪兽获得+2 ATK。"
	p19.building_charge_text = "本建筑在场上时，每次OD增长获得1层圣堂充能。"
	p19.building_resonance_text = "Overdrive Route完成时消耗全部圣堂充能，每层充能给怪兽+1 ATK。"
	p19.route_id = "overdrive_route"
	p19.route_step = 4
	p19.next_cards = []
	p19.combo_reward_text = "Overdrive Eruption 伤害+4"
	p19.combo_hint = "Overdrive Route奇观——OD=8+才能使用"
	p19.legacy_names = ["Core Cathedral"]
	p19.art_id = "core_cathedral"
	p19.color_theme = "red"
	p19.flavor_text = "「在深渊之上，圣堂即是力量。」"
	p19.art_path = "res://assets/cards/thumbs/card_p19_core_cathedral.png"
	_apply_zone(p19, CardData.BoardZone.BACK_ROW, CardData.DisplayType.SUSTAIN)
	_apply_sustain(p19, 99, "core_cathedral")
	var p19_shield := ShieldEffectClass.new(); p19_shield.amount = 3
	p19.effects = [p19_shield]
	_set_card_keywords(p19, [])
	all_cards.append(p19)

	# ── P20 过载喷发 / Overdrive Eruption — 魔法 ──
	var p20 := CardDataClass.new()
	p20.card_name = "Overdrive Eruption"
	p20.card_id = "P20"
	p20.display_name = "过载喷发"
	p20.english_name = "Overdrive Eruption"
	p20.card_family = "spell"
	p20.archetype_role = CardData.ArchetypeRole.FINISHER
	p20.rarity = CardData.CardRarity.SUPER
	p20.od_cost = 10
	p20.load_cost = 3
	p20.require_od = 10
	p20.require_awaken = true
	p20.short_description = "满OD终结"
	p20.description = "终结。需要觉醒+OD满。造成20点伤害，自身反噬3。Overdrive Route完成时额外+4。OD清零。"
	p20.calm_text = "不能使用。"
	p20.heated_text = "不能使用。"
	p20.overdrive_text = "消耗满OD，释放终结喷发。"
	p20.activation_condition_text = "觉醒 + OD满。"
	p20.od_interface_text = "消耗全部OD，将场上怪兽转化为终结打击。"
	p20.risk_text = "Depth +3，自身反噬3。"
	p20.overdrive_damage_bonus = 8
	p20.overdrive_self_damage = 3
	p20.route_id = "overdrive_route"
	p20.route_step = 4
	p20.next_cards = []
	p20.combo_reward_text = "Overdrive Eruption 伤害+4"
	p20.combo_hint = "Overdrive Route终点——需要觉醒+OD满"
	p20.legacy_names = ["Overdrive Eruption", "Nova Burst"]
	p20.art_id = "overdrive_eruption"
	p20.color_theme = "red"
	p20.flavor_text = "「将所有限制抛诸脑后，让能量决定一切。」"
	p20.art_path = "res://assets/cards/thumbs/card_p20_overdrive_eruption.png"
	_apply_zone(p20, CardData.BoardZone.INSTANT, CardData.DisplayType.NONE)
	var p20_dmg := DamageEffectClass.new(); p20_dmg.base_damage = 20
	var p20_self := SelfDamageEffectClass.new(); p20_self.amount = 3
	p20.effects = [p20_dmg, p20_self]
	_set_card_keywords(p20, ["overload"])
	all_cards.append(p20)

	# ===== 最终验证 =====
	print("[CardLibrary] Phase 5A — Generated %d cards ready for battle." % all_cards.size())


## Phase 5C: 对 JSON 加载的卡牌应用额外的 Phase 5A 元数据
func _apply_json_cards_metadata() -> void:
	for card in all_cards:
		match card.card_name:
			"Reactor Foundation":
				card.activation_condition_text = "本局已获得>=2点OD，或Depth>=2。"
				card.od_interface_text = "每回合一次，消耗2 OD或2层充能使1只怪兽+1/+1；或消耗1 OD使下次Depth增加-1。"
				card.building_charge_text = "每获得OD，获得1层炉基充能，每回合最多2层，上限4层。"
				card.building_resonance_text = "若炉基充能>=3，防止Depth时额外护盾+1。"
			"Pressure Relay":
				card.activation_condition_text = "当前OD>=4。"
				card.od_interface_text = "每回合一次，若本回合已打出2张牌，消耗1 OD使1只怪兽+1/+1。"
				card.building_charge_text = "每打出第2张牌，获得1层压力充能。"
				card.building_resonance_text = "Heat Route推进时，压力充能可视为额外热量。"
			"Heat Sink":
				card.activation_condition_text = "任意Depth；Depth越高越强。"
				card.od_interface_text = "每回合一次，消耗1 OD使下一次Depth增加-1。"
				card.building_charge_text = "每当Depth被降低，本建筑获得1层冷却充能。"
				card.building_resonance_text = "冷却充能可转化为护盾。"
			"Containment Wall":
				card.activation_condition_text = "任意OD阶段均可设置。"
				card.od_interface_text = "被破坏时可消耗1 OD换取护盾+2。"
			"Core Cathedral":
				card.activation_condition_text = "OD>=8。Overdrive阶段可用。"
				card.od_interface_text = "OD为10时可消耗2 OD使1只怪兽获得+2 ATK。"
				card.building_charge_text = "本建筑在场上时，每次OD增长获得1层圣堂充能。"
				card.building_resonance_text = "Overdrive Route完成时消耗全部圣堂充能，每层充能给怪兽+1 ATK。"
				card.risk_text = "Depth +1（每次使用接口）。"
			"Overclock Pulse":
				card.od_interface_text = "可消耗或推动OD来制造场面冲击。"
				card.risk_text = "高OD使用会推高Depth。"
			"Overdrive Eruption":
				card.activation_condition_text = "觉醒 + OD满。"
				card.od_interface_text = "消耗全部OD，将场上怪兽转化为终结打击。"
				card.risk_text = "Depth +3，自身反噬3。"
	assert(all_cards.size() == 20, "[CardLibrary] ERROR: Expected 20 cards, got %d!" % all_cards.size())
