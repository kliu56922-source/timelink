extends Node
class_name BossCardDeck

## BossCardDeck — Boss 卡组与 OD Zone 池管理 (v2.0 MVP)
## 7 张 Boss 卡，3 个 Zone 池，每回合抽 1 张打出

signal intent_updated(card: CardData, danger: String)
signal boss_reaction_triggered(card: CardData, shield_amount: int)

const SUPPORTED_CARD_IDS: Array[String] = [
	"B-01", "B-02", "B-03", "B-04", "B-07", "B-09", "B-15", "B-16",
]


static func get_supported_card_ids() -> Array[String]:
	return SUPPORTED_CARD_IDS.duplicate()

# Zone 卡池
var calm_pool: Array = []
var heated_pool: Array = []
var overdrive_pool: Array = []
var graveyard: Array = []

# 当前抽到的意图卡
var current_intent: CardData = null
var _definitions_by_id: Dictionary = {}
var _configured_entries: Dictionary = {}
var _rng := RandomNumberGenerator.new()

# 反应追踪 (ADR-0008)
var reactions_triggered_this_turn: int = 0
const MAX_REACTIONS_PER_TURN: int = 2

# 全局数据访问
var battle_context: BattleContext = null
var battle_system = null  # 延迟绑定，避免循环依赖


# ============================================================
# 初始化
# ============================================================
func setup(ctx: BattleContext, deck_config: Dictionary = {}, seed_override: int = -1) -> void:
	battle_context = ctx
	generate_boss_cards()
	configure_deck(deck_config)
	if seed_override >= 0:
		_rng.seed = seed_override
	else:
		_rng.randomize()


func get_rng_seed() -> int:
	return int(_rng.seed)


func generate_boss_cards() -> void:
	calm_pool.clear()
	heated_pool.clear()
	overdrive_pool.clear()
	_definitions_by_id.clear()

	# ── Boss Starter (Calm) ──
	_add_boss_card("B-01", "B-01 熔炉点火", "boss_starter", "Calm", 0, [
		_make_enemy_od(2),
		_make_damage(2)
	], "Boss OD +2, 伤害 2")

	_add_boss_card("B-02", "B-02 熔炉共鸣", "boss_starter", "Calm", 0, [
		_make_enemy_od(3)
	], "Boss OD +3")

	# ── Boss Extender (Heated) ──
	var b03 := _add_boss_card("B-03", "B-03 过热回流", "boss_extender", "Heated", 3, [
		_make_damage(4),
		_make_od(2)
	], "伤害 4, 玩家 OD +2")
	b03.heated_damage_bonus = 1

	_add_boss_card("B-04", "B-04 烈焰风暴", "boss_extender", "Heated", 4, [
		_make_damage(5),
		_make_enemy_od(1)
	], "伤害 5, Boss OD +1")

	# ── Boss Guard (Heated / Overdrive) ──
	var b07 := _add_boss_card("B-07", "B-07 压力护壁", "boss_guard", "Heated", 2, [
		_make_enemy_od(2)
	], "Boss 护盾 +4, OD +2")
	b07.board_zone = CardData.BoardZone.FRONT_ROW
	b07.display_type = CardData.DisplayType.UNIT
	b07.unit_power = 3
	b07.unit_defense = 4
	b07.is_guard_card = true
	# B-07 already in heated_pool from _add_boss_card
	overdrive_pool.append(_clone_card_data(b07))

	# ── Boss Reaction — 简化为仅 RW-1 (Cross-zone) ──
	var b09 := _add_boss_card("B-09", "B-09 热压反制", "boss_reaction", "Calm", 1, [], "Boss 护盾 +3, 玩家 Load +1")
	b09.board_zone = CardData.BoardZone.BACK_ROW
	b09.display_type = CardData.DisplayType.TRAP
	b09.reaction_trigger = "player_3rd_card"
	# B-09 already in calm_pool from _add_boss_card
	heated_pool.append(_clone_card_data(b09))

	# ── Boss Finisher (Overdrive) ──
	_add_boss_card("B-15", "B-15 熔炉爆发", "boss_finisher", "Overdrive", 7, [
		_make_damage(8),
		_make_enemy_od(-4)
	], "伤害 8, Boss OD -4")



	# ── Phase 4C-1: Overdrive 维持卡 ──
	var b16 := _add_boss_card("B-16", "B-16 熔炉过载", "boss_finisher", "Overdrive", 6, [
		_make_damage(6),
		_make_enemy_od(1),
		_make_od(2)
	], "伤害 6, Boss OD +1, 玩家 OD +2")
	b16.heated_damage_bonus = 2

func _add_boss_card(card_id: String, card_name: String, role: String, zone: String, require_od: int, effects: Array, desc: String) -> CardData:
	var card := CardData.new()
	card.card_id = card_id
	card.card_name = card_name
	card.card_type = CardData.CardType.SPELL
	card.rarity = CardData.CardRarity.COMMON
	card.od_cost = 0  # Boss 卡不推玩家 OD
	card.require_od = require_od
	card.boss_card_role = role
	card.short_description = desc
	card.description = desc
	card.effects = effects
	add_child(card)
	# Boss pool clones intentionally share stateless effects; their common owner is the deck.
	for effect in effects:
		if effect is Node and effect.get_parent() == null:
			add_child(effect)
	_definitions_by_id[card_id] = card

	match zone:
		"Calm": calm_pool.append(card)
		"Heated": heated_pool.append(card)
		"Overdrive": overdrive_pool.append(card)
	return card
# ── CardData 手动拷贝（CardData extends Node，无 duplicate() 方法）──
func _clone_card_data(src: CardData) -> CardData:
	var dst := CardData.new()
	dst.card_id = src.card_id
	dst.card_name = src.card_name
	dst.card_type = src.card_type
	dst.rarity = src.rarity
	dst.od_cost = src.od_cost
	dst.require_od = src.require_od
	dst.boss_card_role = src.boss_card_role
	dst.reaction_trigger = src.reaction_trigger
	dst.is_guard_card = src.is_guard_card
	# Board identity is gameplay data. Cross-zone pool clones must retain it,
	# otherwise units/traps silently fall back to INSTANT and never enter play.
	dst.board_zone = src.board_zone
	dst.display_type = src.display_type
	dst.unit_power = src.unit_power
	dst.unit_defense = src.unit_defense
	dst.unit_description = src.unit_description
	dst.is_continuous = src.is_continuous
	dst.continuous_duration = src.continuous_duration
	dst.on_field_effect = src.on_field_effect
	dst.short_description = src.short_description
	dst.description = src.description
	dst.effects = src.effects  # 同效果引用（Boss 卡效果无状态，安全）
	dst.keywords = src.keywords.duplicate()
	dst.heated_damage_bonus = src.heated_damage_bonus
	dst.overdrive_damage_bonus = src.overdrive_damage_bonus
	dst.calm_damage_bonus = src.calm_damage_bonus
	dst.overdrive_self_damage = src.overdrive_self_damage
	add_child(dst)
	return dst


func configure_deck(deck_config: Dictionary) -> void:
	_configured_entries.clear()
	var pools = deck_config.get("pools", {})
	if not pools is Dictionary:
		return
	for zone_id in ["Calm", "Heated", "Overdrive"]:
		var entries = pools.get(zone_id, [])
		_configured_entries[zone_id] = entries.duplicate(true) if entries is Array else []


func get_configured_entries(zone_name: String) -> Array:
	var entries = _configured_entries.get(zone_name, [])
	return entries.duplicate(true) if entries is Array else []


static func select_weighted_card_id(entries: Array, roll: int) -> String:
	var cumulative := 0
	for entry in entries:
		if not entry is Dictionary:
			continue
		cumulative += int(entry.get("weight", 0))
		if roll <= cumulative:
			return str(entry.get("card_id", ""))
	return ""


func create_card_by_id(card_id: String) -> CardData:
	var definition: CardData = _definitions_by_id.get(card_id)
	return _clone_card_data(definition) if definition != null else null


func enable_terrain_threat_experiment() -> void:
	if _definitions_by_id.has("B-18"):
		return
	var card := _add_boss_card("B-18", "B-18 断层轰击", "boss_extender", "Experiment", 0, [], "预告降低建筑地形；留出一个完整玩家回合，Boss OD +1")
	card.od_cost = 1


func _terrain_card_eligible(card_id: String) -> bool:
	if card_id != "B-18": return true
	return _definitions_by_id.has(card_id) and battle_system != null and battle_system.get_boss_terrain_cast_status().get("ok", false)



# ============================================================
# 辅助 — 效果工厂
# ============================================================
func _make_damage(base: int):
	var e := DamageEffect.new()
	e.base_damage = base
	return e

func _make_od(amount: int):
	var e := ODEffect.new()
	e.amount = amount
	return e

func _make_enemy_od(amount: int):
	var e := EnemyODEffect.new()
	e.amount = amount
	return e


# ============================================================
# Zone 池管理
# ============================================================
func get_pool(zone_name: String) -> Array:
	match zone_name:
		"Calm": return calm_pool
		"Heated": return heated_pool
		"Overdrive": return overdrive_pool
	return []


func draw_card(zone_name: String) -> CardData:
	var configured: Array = _configured_entries.get(zone_name, [])
	if not configured.is_empty():
		configured = configured.filter(func(entry: Variant) -> bool:
			return entry is Dictionary and _terrain_card_eligible(str(entry.get("card_id", ""))))
		var total_weight := 0
		for entry in configured:
			if entry is Dictionary:
				total_weight += int(entry.get("weight", 0))
		if total_weight <= 0:
			return null
		var roll := _rng.randi_range(1, total_weight)
		var card_id := select_weighted_card_id(configured, roll)
		var configured_card := create_card_by_id(card_id)
		if configured_card == null:
			return null
		current_intent = configured_card
		_emit_intent(configured_card, zone_name)
		return configured_card

	var pool := get_pool(zone_name)
	if pool.is_empty():
		_recycle_graveyard(zone_name)
		pool = get_pool(zone_name)
	if pool.is_empty():
		return null

	var card: CardData = pool.pop_front()
	current_intent = card

	_emit_intent(card, zone_name)
	return card


func _emit_intent(card: CardData, zone_name: String) -> void:
	var danger := "LOW"
	match zone_name:
		"Heated": danger = "MID"
		"Overdrive": danger = "HIGH"

	intent_updated.emit(card, danger)


func play_intent_card() -> CardData:
	"""
	Phase 8A-Hotfix: 消费当前意图卡。
	GY 添加由 boss_play_card() 统一处理，避免重复入墓地。
	"""
	var card := current_intent
	current_intent = null
	return card


func _recycle_graveyard(zone_name: String) -> void:
	var recycled: Array = []
	var zone_tag := ""
	match zone_name:
		"Calm": zone_tag = "boss_starter"
		"Heated": zone_tag = "boss_extender"
		"Overdrive": zone_tag = "boss_finisher"

	for c in graveyard:
		# The opt-in weighted encounter owns B-18; never leak it into default pools.
		if c.card_id == "B-18": continue
		if c.boss_card_role == zone_tag or c.boss_card_role == "boss_guard" or c.boss_card_role == "boss_reaction":
			get_pool(zone_name).append(c)
			recycled.append(c)
	for c in recycled:
		graveyard.erase(c)


# ============================================================
# 反应系统 MVP — 仅 RW-1: 玩家第 3 张牌 → Boss 护盾 +3
# ============================================================
func check_player_card_reaction(cards_played: int) -> bool:
	if cards_played != 3:
		return false
	if reactions_triggered_this_turn >= MAX_REACTIONS_PER_TURN:
		return false

	# Phase 4C-2: 优先从 Boss 后场触发 Reaction（可见威胁）
	var enemy = battle_context.enemy if battle_context else null
	if enemy and not enemy.traps.is_empty():
		for card in enemy.traps.duplicate():
			if card.boss_card_role == "boss_reaction" and card.reaction_trigger == "player_3rd_card":
				_trigger_reaction_from_field(card, enemy)
				reactions_triggered_this_turn += 1
				return true

	# Fallback: 从卡池扫描（兼容 B-09 尚未抽到时也保留触发能力）
	for card in calm_pool + heated_pool + overdrive_pool:
		if card.boss_card_role == "boss_reaction" and card.reaction_trigger == "player_3rd_card":
			_trigger_reaction_rw1(card)
			reactions_triggered_this_turn += 1
			return true
	return false


func _trigger_reaction_rw1(card: CardData) -> void:
	if battle_context and battle_context.enemy:
		battle_context.enemy.add_boss_shield(3, "Boss Reaction RW-1")
		print("[BOSS REACTION] RW-1 热压反制: Boss 护盾 +3")
	# 玩家 Load +1
	if battle_context and battle_context.od_mode:
		battle_context.od_mode.load += 1
		print("[BOSS REACTION] RW-1: 玩家 Load +1 (now %d)" % battle_context.od_mode.load)
	# 发出信号供表现层使用
	boss_reaction_triggered.emit(card, 3)  # 传 CardData 供 BossReactionFX 创建卡框


## Phase 4C-2: 从 Boss 后场触发 Reaction（可见威胁 → 消费）
func _trigger_reaction_from_field(card: CardData, enemy) -> void:
	print("[BOSS TRAP TRIGGER] %s 触发 — 从 Boss 后场移除" % card.card_name)
	# 1. 应用效果（与 _trigger_reaction_rw1 一致）
	_trigger_reaction_rw1(card)
	# 2. 从后场移除
	enemy.traps.erase(card)
	# 3. Phase 4B-7: 同步进两个 GY（boss_deck.graveyard + enemy.graveyard）
	graveyard.append(card)
	enemy.graveyard.append(card)
	print("[BOSS TRAP] %s removed from back row → graveyard (boss_deck GY: %d, enemy GY: %d)" % [card.card_name, graveyard.size(), enemy.graveyard.size()])


# ============================================================
# 回合管理
# ============================================================
func reset_turn() -> void:
	reactions_triggered_this_turn = 0
	current_intent = null
	# 重置阶段追踪
	if battle_context:
		battle_context.phases_locked_this_turn = 0


func has_intent() -> bool:
	return current_intent != null
