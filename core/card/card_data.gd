extends Node
class_name CardData

enum CardType {
	SPELL,
	UNIT,
	TRAP
}

enum CardRarity {
	COMMON,
	RARE,
	SUPER
}

enum ArchetypeRole {
	STARTER,
	EXTENDER,
	CONTROL,
	FINISHER,
	DEFENSE
}

# =========================
# 牌桌归属 — Phase 2A
# =========================
enum BoardZone {
	FRONT_ROW,   # 前场 — 打出后留在前场槽位
	BACK_ROW,    # 后场 — 打出后留在后场槽位（盖伏或正面持续）
	INSTANT,     # 瞬发 — 结算后直接进墓地
}

enum DisplayType {
	UNIT,     # 单位展示（前场，显示 ATK/DEF）
	TRAP,     # 陷阱盖伏（后场，显示卡背/灰色遮罩）
	SUSTAIN,  # 持续效果展示（后场正面，显示持续回合）
	NONE,     # 无展示（瞬发卡，结算即消失）
}

# =========================
# 基础信息
# =========================
var card_name: String = ""
var card_id: String = ""
var display_name: String = ""
var english_name: String = ""
var legacy_names: Array[String] = []
var art: Texture2D
var art_path: String = ""
var thumb_path: String = ""   # Phase 7E-1: 160x128 手牌/场上/Feed
var detail_path: String = ""  # Phase 7E-1: 512x512 详情面板
var art_focus: String = "center"
var frame_style: String = "default"
var card_family: String = "" # "monster" / "spell" / "counter" / "building"

# =========================
# Phase 27I-R0: 固定棋子身份（不可变数据字段）
# 只保存身份与配置引用，不保存战斗期可变层数/消耗/锚点。
# =========================
var piece_type: StringName = &""
var piece_enabled: bool = false
var piece_effect_profile_id: StringName = &""
var piece_payload_id: StringName = &""

# 类型与稀有度
var card_type: int = CardType.SPELL
var rarity: int = CardRarity.COMMON
var archetype_role: int = ArchetypeRole.STARTER

# 描述文本
var description: String = ""
var short_description: String = ""  # 8-16字短效果（战斗手牌显示用）
var calm_text: String = ""
var heated_text: String = ""
var overdrive_text: String = ""
var activation_condition_text: String = ""
var od_interface_text: String = ""
var building_charge_text: String = ""
var building_resonance_text: String = ""
var risk_text: String = ""

# =========================
# 费用系统
# =========================
var od_cost: int = 0
var load_cost: int = 1

# SUPER 卡条件
var require_od: int = 0
var require_load: int = 0
var require_hp_cost: int = 0
var require_awaken: bool = false

# =========================
# OD Zone 效果配置文件
# =========================
var calm_damage_bonus: int = 0
var heated_damage_bonus: int = 0
var overdrive_damage_bonus: int = 0
var overdrive_self_damage: int = 0

# =========================
# 单位属性
# =========================
var unit_power: int = 0
var unit_defense: int = 0
var unit_description: String = ""

# =========================
# 关键词系统
# =========================
var keywords: Array[String] = []

# =========================
# 效果
# =========================
var effects: Array = []


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	# Mutable Node effects belong to this card; externally parented nodes keep their owner.
	for effect in effects:
		if is_instance_valid(effect) and effect is Node and effect.get_parent() == null:
			effect.free()
	# Keep shared array contents intact; this card's reference is released on destruction.


# =========================
# 陷阱
# =========================
var trap_triggered: bool = false

# =========================
# 抉择卡接口
# =========================
var is_choice_card: bool = false
var choice_a_name: String = ""
var choice_b_name: String = ""
var choice_a_effect_type: String = ""
var choice_b_effect_type: String = ""

# =========================
# Combo / 连锁信息
# =========================
var chain_id: String = ""
var chain_step: int = 0
var combo_hint: String = ""

# =========================
# Route / 路线系统
# =========================
var route_id: String = ""
var route_step: int = 0
var next_cards: Array[String] = []
var combo_reward_text: String = ""

# =========================
# 美术 / UI 信息
# =========================
var art_id: String = ""
var color_theme: String = ""
var flavor_text: String = ""

# =========================
# Boss 专属字段 — ADR-0005
# 玩家卡使用默认值，行为不变
# =========================
var boss_card_role: String = ""        # "boss_starter" / "boss_extender" / "boss_guard" / "boss_reaction" / "boss_finisher"; 空=玩家卡
var reaction_trigger: String = ""      # "player_3rd_card" / "player_enters_overdrive" / "boss_enters_overdrive"; 空=非Reaction卡
var is_guard_card: bool = false        # Boss Guard 卡标记

# =========================
# 牌桌归属字段 — Phase 2A
# =========================
var board_zone: int = BoardZone.INSTANT
var display_type: int = DisplayType.NONE
var is_continuous: bool = false
var continuous_duration: int = 0
var on_field_effect: String = ""

# =========================
# Phase 5D-2: 小轴元数据字段（构筑身份，不影响战斗）
# =========================
var series_id: String = "generic"                # 所属小轴: core_cathedral / abyss_containment / steam_monster / generic
var secondary_series_ids: Array[String] = []     # 跨轴身份
var search_tags: Array[String] = []              # 可检索标签
var related_cards: Array[String] = []             # UI 关联推荐卡名
var building_tier: int = -1                      # 建筑层级: -1=非建筑, 0=T0支援, 1=T1引擎, 2=T2奇观
var building_unique: bool = false                # 同名建筑唯一
var entry_condition_type: String = ""            # 发动条件类型: od_at_least / series_played / active_monsters
var entry_condition_value: int = 0               # 发动条件数值
var entry_condition_text_cn: String = ""         # 发动条件中文描述

# =========================
# Phase 7A-5: OD 五层引擎字段
var engine_gain: int = -999           # -999 = fallback to od_cost
var layer_1_2_text: String = ""       # L1-L2 分层说明文本
var layer_3_4_text: String = ""       # L3-L4 分层说明文本
var layer_5_text: String = ""         # L5 分层说明文本

# =========================
# Phase 13C: OD Arsenal / 额外卡组字段
# =========================
var is_arsenal_card: bool = false                 # 是否为 Arsenal 卡
var arsenal_tier: String = ""                     # "mid" / "final"
var unlock_layer: int = 0                         # 需要达到的 OD 引擎层级 (3 或 5)
var usage_stage: String = ""                      # "mid" / "final"
var arsenal_usage_limit: int = 1                  # 每局最多使用次数（默认1）
var enters_graveyard: bool = true                 # 使用后是否进入墓地
var requires_mid_arsenal_used: bool = false       # 是否需要先使用过中级 Arsenal 才能用这张卡

# =========================
# Phase 13F-1: OD Ascension / 过载升格字段
# =========================
var is_ascension_form: bool = false               # 是否为升格形态（怪兽类 Arsenal）
var ascends_from_ids: Array[String] = []           # 可由哪些基础卡升格而来
var ascension_layer: int = 0                       # 升格需要的 OD 层级
var ascension_cost_type: String = ""               # "single_replace" / "fusion" / "depth_guard"
var ascension_material_count: int = 1              # 升格需要的素材怪兽数量
var ascension_replaces_source: bool = true         # 升格是否替换原怪兽槽位
var ascension_text_cn: String = ""                 # 升格中文说明
var ascension_depth_min: int = 0                   # 升格所需最低 Depth
var ascension_material_series_id: String = ""      # 合体素材系列要求

# Phase 6A: 检索 (Tutor) 字段
# =========================
var tutor_enabled: bool = false                  # 是否有检索效果
var tutor_timing: String = ""                    # 触发时机: "on_play" / "on_building_activate"
var tutor_series_id: String = ""                 # 限定系列
var tutor_card_type: String = ""                 # 限定卡牌类型: MONSTER/SPELL/COUNTER/BUILD
var tutor_tag: String = ""                       # 限定标签
var tutor_count: int = 1                         # 检索数量（当前最多1）
var tutor_text_cn: String = ""                   # 详情面板说明文本


func get_load_cost() -> int:
	return load_cost


func get_display_name() -> String:
	if display_name != "":
		return display_name
	return card_name


func get_internal_name() -> String:
	return card_name


func matches_name(value: String) -> bool:
	if value == card_name or value == display_name or value == english_name or value == card_id:
		return true
	return value in legacy_names


func get_family_tag() -> String:
	match card_family:
		"monster":
			return "MONSTER"
		"spell":
			return "SPELL"
		"counter":
			return "COUNTER"
		"building":
			return "BUILD"
		_:
			match card_type:
				CardType.UNIT:
					return "MONSTER"
				CardType.TRAP:
					return "COUNTER"
				_:
					return "SPELL"


func get_family_label() -> String:
	match card_family:
		"monster":
			return "怪兽"
		"spell":
			return "魔法"
		"counter":
			return "反制"
		"building":
			return "建筑"
		_:
			match card_type:
				CardType.UNIT:
					return "怪兽"
				CardType.TRAP:
					return "反制"
				_:
					return "魔法"


func is_building_card() -> bool:
	# Explicit gameplay family wins over the persistent-card presentation style.
	# Older cards without a family retain the sustain fallback.
	return card_family == "building" if not card_family.is_empty() else display_type == DisplayType.SUSTAIN


func get_art_texture() -> Texture2D:
	if art != null:
		return art
	if art_path != "" and ResourceLoader.exists(art_path):
		var loaded := load(art_path)
		if loaded is Texture2D:
			return loaded
	return null


## Phase 7E-1: 按显示模式返回对应尺寸卡图
## mode: 0=HAND, 1=PLAYER_FIELD, 2=BOSS_FIELD, 3=DETAIL, 4=FEED
## DETAIL→detail_path(512), 其他→thumb_path(160)
func get_art_texture_for_mode(mode: int) -> Texture2D:
	# DETAIL 模式使用 512x512 detail 图
	if mode == 3:  # CardDisplayMode.DETAIL
		if detail_path != "" and ResourceLoader.exists(detail_path):
			var loaded := load(detail_path)
			if loaded is Texture2D:
				return loaded
	# HAND / FIELD / FEED 使用 160x128 thumb
	if thumb_path != "" and ResourceLoader.exists(thumb_path):
		var loaded := load(thumb_path)
		if loaded is Texture2D:
			return loaded
	# Fallback to legacy art_path
	if art_path != "" and ResourceLoader.exists(art_path):
		var loaded := load(art_path)
		if loaded is Texture2D:
			return loaded
	# Explicit mode/legacy paths retain priority; a direct resource is the final fallback.
	return art


func get_detail_description() -> String:
	var lines: Array[String] = []
	if description != "":
		lines.append(description)
	elif short_description != "":
		lines.append(short_description)

	# Phase 13C: Arsenal 卡标识行
	if is_arsenal_card:
		var arsenal_label := "OD Arsenal"
		if arsenal_tier == "mid":
			arsenal_label += " / 解锁层级 L%d / 阶段 中级构装" % unlock_layer
		elif arsenal_tier == "final":
			arsenal_label += " / 解锁层级 L%d / 阶段 终场构装" % unlock_layer
		if not enters_graveyard:
			arsenal_label += " / 不进入墓地"
		lines.append(arsenal_label)

	# Phase 13F-1: 升格形态信息行
	if is_ascension_form and ascension_text_cn != "":
		lines.append("升格形态: " + ascension_text_cn)

	if activation_condition_text != "":
		lines.append("发动条件: " + activation_condition_text)
	if od_interface_text != "":
		lines.append("OD接口: " + od_interface_text)
	if building_charge_text != "":
		lines.append("建筑充能: " + building_charge_text)
	if building_resonance_text != "":
		lines.append("建筑共鸣: " + building_resonance_text)
	if tutor_text_cn != "":
		lines.append("检索: " + tutor_text_cn)
	if risk_text != "":
		lines.append("风险: " + risk_text)

	return "\n".join(lines)


# =========================
# 牌桌归属 Helper — Phase 2A
# =========================

## 返回卡牌的牌桌目标区域。
## 优先使用显式设置的 board_zone / display_type；
## 若均为默认值，则根据 card_type 推算默认映射。
func get_board_zone() -> int:
	if board_zone != BoardZone.INSTANT:
		return board_zone
	if display_type != DisplayType.NONE:
		return board_zone
	return _default_board_zone()


func _default_board_zone() -> int:
	match card_type:
		CardType.UNIT:
			return BoardZone.FRONT_ROW
		CardType.TRAP:
			return BoardZone.BACK_ROW
		_:
			# SPELL 如果是持续卡，默认进后场
			if is_continuous:
				return BoardZone.BACK_ROW
			return BoardZone.INSTANT


## 卡牌打出后是否停留在场上（前场或后场）
func should_stay_on_board() -> bool:
	return get_board_zone() != BoardZone.INSTANT


## 是否是前场卡（UNIT 默认；可被显式字段覆盖）
func is_front_row_card() -> bool:
	return get_board_zone() == BoardZone.FRONT_ROW


## 是否是后场卡（TRAP 默认；持续 SPELL 也可设为后场）
func is_back_row_card() -> bool:
	return get_board_zone() == BoardZone.BACK_ROW


## 是否是瞬发卡（SPELL/SUPER/FINISHER 默认，结算后进墓地）
func is_instant_card() -> bool:
	return get_board_zone() == BoardZone.INSTANT


## 返回卡牌在槽位中的展示类型。
## 优先显式值，否则由 card_type 推算。
func get_display_type() -> int:
	if display_type != DisplayType.NONE:
		return display_type
	return _default_display_type()


func _default_display_type() -> int:
	match card_type:
		CardType.UNIT:
			return DisplayType.UNIT
		CardType.TRAP:
			return DisplayType.TRAP
		_:
			return DisplayType.NONE


# ============================================================
# Phase 27C-R1-R2: 运行时卡牌实体克隆工厂
# ============================================================
# 规则：
#   - card_id 表示卡牌定义，可以相同。
#   - 每一张放入牌组的卡必须是独立的 CardData Node。
#   - get_instance_id() 是运行时实体身份，牌组内必须唯一。
#   - Array/Dictionary 等可变字段独立复制。
#   - Texture2D 等不可变资源允许共享。
#   - Effect 若为可变 Node，必须独立实例化。
#   - 运行时字段（trap_triggered 等）必须初始化为默认状态。
# ============================================================
static func clone_card_entity(src: CardData) -> CardData:
	if src == null:
		return null
	var dst := CardData.new()

	# ── 基础信息 ──
	dst.card_name = src.card_name
	dst.card_id = src.card_id
	dst.display_name = src.display_name
	dst.english_name = src.english_name
	dst.legacy_names.assign(src.legacy_names)
	# Texture2D 是不可变资源，允许共享
	dst.art = src.art
	dst.art_path = src.art_path
	dst.thumb_path = src.thumb_path
	dst.detail_path = src.detail_path
	dst.art_focus = src.art_focus
	dst.frame_style = src.frame_style
	dst.card_family = src.card_family

	# ── Phase 27I-R0: 固定棋子身份 ──
	dst.piece_type = src.piece_type
	dst.piece_enabled = src.piece_enabled
	dst.piece_effect_profile_id = src.piece_effect_profile_id
	dst.piece_payload_id = src.piece_payload_id

	# ── 类型与稀有度 ──
	dst.card_type = src.card_type
	dst.rarity = src.rarity
	dst.archetype_role = src.archetype_role

	# ── 描述文本 ──
	dst.description = src.description
	dst.short_description = src.short_description
	dst.calm_text = src.calm_text
	dst.heated_text = src.heated_text
	dst.overdrive_text = src.overdrive_text
	dst.activation_condition_text = src.activation_condition_text
	dst.od_interface_text = src.od_interface_text
	dst.building_charge_text = src.building_charge_text
	dst.building_resonance_text = src.building_resonance_text
	dst.risk_text = src.risk_text

	# ── 费用系统 ──
	dst.od_cost = src.od_cost
	dst.load_cost = src.load_cost
	dst.require_od = src.require_od
	dst.require_load = src.require_load
	dst.require_hp_cost = src.require_hp_cost
	dst.require_awaken = src.require_awaken

	# ── OD Zone 效果 ──
	dst.calm_damage_bonus = src.calm_damage_bonus
	dst.heated_damage_bonus = src.heated_damage_bonus
	dst.overdrive_damage_bonus = src.overdrive_damage_bonus
	dst.overdrive_self_damage = src.overdrive_self_damage

	# ── 单位属性 ──
	dst.unit_power = src.unit_power
	dst.unit_defense = src.unit_defense
	dst.unit_description = src.unit_description

	# ── 关键词 — Array[String] 独立复制 ──
	dst.keywords.assign(src.keywords)

	# ── 效果 — Node 类型必须独立实例化；简单 RefCounted 可共享 ──
	dst.effects = _clone_effects(src.effects)

	# ── 陷阱（运行时字段，必须初始化为默认）──
	dst.trap_triggered = false

	# ── 抉择卡 ──
	dst.is_choice_card = src.is_choice_card
	dst.choice_a_name = src.choice_a_name
	dst.choice_b_name = src.choice_b_name
	dst.choice_a_effect_type = src.choice_a_effect_type
	dst.choice_b_effect_type = src.choice_b_effect_type

	# ── Combo / 连锁 ──
	dst.chain_id = src.chain_id
	dst.chain_step = src.chain_step
	dst.combo_hint = src.combo_hint

	# ── Route / 路线 ──
	dst.route_id = src.route_id
	dst.route_step = src.route_step
	dst.next_cards.assign(src.next_cards)
	dst.combo_reward_text = src.combo_reward_text

	# ── 美术 / UI ──
	dst.art_id = src.art_id
	dst.color_theme = src.color_theme
	dst.flavor_text = src.flavor_text

	# ── Boss 专属 ──
	dst.boss_card_role = src.boss_card_role
	dst.reaction_trigger = src.reaction_trigger
	dst.is_guard_card = src.is_guard_card

	# ── 牌桌归属 ──
	dst.board_zone = src.board_zone
	dst.display_type = src.display_type
	dst.is_continuous = src.is_continuous
	dst.continuous_duration = src.continuous_duration
	dst.on_field_effect = src.on_field_effect

	# ── 小轴元数据 ──
	dst.series_id = src.series_id
	dst.secondary_series_ids.assign(src.secondary_series_ids)
	dst.search_tags.assign(src.search_tags)
	dst.related_cards.assign(src.related_cards)
	dst.building_tier = src.building_tier
	dst.building_unique = src.building_unique
	dst.entry_condition_type = src.entry_condition_type
	dst.entry_condition_value = src.entry_condition_value
	dst.entry_condition_text_cn = src.entry_condition_text_cn

	# ── OD 五层引擎 ──
	dst.engine_gain = src.engine_gain
	dst.layer_1_2_text = src.layer_1_2_text
	dst.layer_3_4_text = src.layer_3_4_text
	dst.layer_5_text = src.layer_5_text

	# ── OD Arsenal ──
	dst.is_arsenal_card = src.is_arsenal_card
	dst.arsenal_tier = src.arsenal_tier
	dst.unlock_layer = src.unlock_layer
	dst.usage_stage = src.usage_stage
	dst.arsenal_usage_limit = src.arsenal_usage_limit
	dst.enters_graveyard = src.enters_graveyard
	dst.requires_mid_arsenal_used = src.requires_mid_arsenal_used

	# ── OD Ascension ──
	dst.is_ascension_form = src.is_ascension_form
	dst.ascends_from_ids.assign(src.ascends_from_ids)
	dst.ascension_layer = src.ascension_layer
	dst.ascension_cost_type = src.ascension_cost_type
	dst.ascension_material_count = src.ascension_material_count
	dst.ascension_replaces_source = src.ascension_replaces_source
	dst.ascension_text_cn = src.ascension_text_cn
	dst.ascension_depth_min = src.ascension_depth_min
	dst.ascension_material_series_id = src.ascension_material_series_id

	# ── 检索 ──
	dst.tutor_enabled = src.tutor_enabled
	dst.tutor_timing = src.tutor_timing
	dst.tutor_series_id = src.tutor_series_id
	dst.tutor_card_type = src.tutor_card_type
	dst.tutor_tag = src.tutor_tag
	dst.tutor_count = src.tutor_count
	dst.tutor_text_cn = src.tutor_text_cn

	# ── Phase 27C 字段已在上方覆盖（board_zone, display_type, card_family, is_guard_card）──

	print("[CARD_CLONE] Cloned '%s' — src_id=%d → dst_id=%d" % [src.card_name, src.get_instance_id(), dst.get_instance_id()])
	return dst


## 复制 effects 数组：Effect 是 Node，必须独立实例化
static func _clone_effects(src_effects: Array) -> Array:
	var result: Array = []
	for raw in src_effects:
		if raw == null:
			continue
		# Effect 是 Node 子类，必须独立实例
		if raw is Node:
			var cloned = _clone_effect_node(raw)
			if cloned != null:
				result.append(cloned)
		else:
			# RefCounted/Resource — 无状态可共享
			result.append(raw)
	return result


## Node.duplicate() 不保留非导出的脚本参数；显式复制效果配置。
static func _clone_effect_node(src: Node):
	if src.has_method("duplicate"):
		var cloned = src.duplicate()
		for property in src.get_property_list():
			if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			if int(property.usage) & PROPERTY_USAGE_READ_ONLY:
				continue
			var value = src.get(property.name)
			if value is Array or value is Dictionary:
				value = value.duplicate(true)
			cloned.set(property.name, value)
		return cloned
	return null
