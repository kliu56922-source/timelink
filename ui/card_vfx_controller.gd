extends Node
class_name CardVFXController
## CardVFXController — 卡牌动效统一入口
## 所有卡牌相关 tween 集中管理，保证安全 kill + freed-node 检查。

# ============================================================
# 内部状态
# ============================================================
## 循环 tween：key = node.get_instance_id()
var _loop_tweens: Dictionary = {}
## 一次性 tween 引用（用于 stop_all 批量 kill）
var _one_shot_tweens: Array[Tween] = []


# ============================================================
# 安全工具
# ============================================================

func _is_safe(node: Node) -> bool:
	return node != null and is_instance_valid(node)


## 停止所有动效（场景退出/重置时调用）
func stop_all() -> void:
	for key in _loop_tweens.keys():
		var tw: Tween = _loop_tweens[key]
		if tw and tw.is_valid():
			tw.kill()
	_loop_tweens.clear()
	for tw in _one_shot_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_one_shot_tweens.clear()


## 停止指定节点的所有动效（含 premium surface）
func stop_for(node: Node) -> void:
	if not _is_safe(node):
		return
	var base_id: int = node.get_instance_id()
	# 清理旧版 key（仅 instance_id）
	if _loop_tweens.has(base_id):
		var tw: Tween = _loop_tweens[base_id]
		if tw and tw.is_valid():
			tw.kill()
		_loop_tweens.erase(base_id)
	# Phase 12B: 清理 premium surface key（"%d_sweep", "%d_glow"）
	for suffix in ["_sweep", "_glow"]:
		var key := "%d%s" % [base_id, suffix]
		if _loop_tweens.has(key):
			var tw: Tween = _loop_tweens[key]
			if tw and tw.is_valid():
				tw.kill()
			_loop_tweens.erase(key)


# ============================================================
# 手牌待机 — 轻微上下浮动 + 呼吸
# ============================================================

func play_hand_idle(card_ui: Control, intensity: float = 1.0) -> void:
	if not _is_safe(card_ui):
		return
	stop_hand_idle(card_ui)
	var key: int = card_ui.get_instance_id()
	var tween: Tween = card_ui.create_tween()
	tween.set_loops()
	var amp: float = 3.0 * intensity
	tween.tween_property(card_ui, "position:y", card_ui.position.y - amp, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card_ui, "position:y", card_ui.position.y + amp, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop_tweens[key] = tween


func stop_hand_idle(card_ui: Control) -> void:
	stop_for(card_ui)


# ============================================================
# 场上待机 — 轻微亮度呼吸
# ============================================================

func play_field_idle(card_ui: Control, card_type: String = "") -> void:
	if not _is_safe(card_ui):
		return
	stop_field_idle(card_ui)
	var key: int = card_ui.get_instance_id()
	var tween: Tween = card_ui.create_tween()
	tween.set_loops()
	var lo := 0.92
	var hi := 1.08
	match card_type:
		"MONSTER":
			lo = 0.90; hi = 1.10
		"BUILD":
			lo = 0.90; hi = 1.10
		"COUNTER":
			lo = 0.94; hi = 1.05
		"FINISHER":
			lo = 0.85; hi = 1.15
	tween.tween_property(card_ui, "modulate:a", lo, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card_ui, "modulate:a", hi, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop_tweens[key] = tween


func stop_field_idle(card_ui: Control) -> void:
	stop_for(card_ui)
	if _is_safe(card_ui):
		card_ui.modulate.a = 1.0


# ============================================================
# 选中 / 取消选中 — 短促放大 + 边缘发光
# ============================================================

func play_card_selected(card_ui: Control) -> void:
	if not _is_safe(card_ui):
		return
	stop_for(card_ui)
	var tween: Tween = card_ui.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_ui, "scale", Vector2(1.08, 1.08), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "modulate", Color(1.2, 1.2, 0.85, 1), 0.12)
	_one_shot_tweens.append(tween)


func play_card_unselected(card_ui: Control) -> void:
	if not _is_safe(card_ui):
		return
	stop_for(card_ui)
	var tween: Tween = card_ui.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_ui, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "modulate", Color(1, 1, 1, 1), 0.15)
	_one_shot_tweens.append(tween)


# ============================================================
# 打出动画 — 从 from_pos 飞到 to_pos
# ============================================================

func play_card_play(card_ui: Control, from_pos: Vector2, to_pos: Vector2) -> void:
	if not _is_safe(card_ui):
		return
	stop_for(card_ui)
	card_ui.global_position = from_pos
	card_ui.scale = Vector2(0.6, 0.6)
	card_ui.modulate.a = 0.5
	var tween: Tween = card_ui.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_ui, "global_position", to_pos, 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "scale", Vector2(1.0, 1.0), 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "modulate:a", 1.0, 0.2)
	_one_shot_tweens.append(tween)


# ============================================================
# 攻击动画 — 前冲再返回
# ============================================================

func play_card_attack(attacker_ui: Control, target_ui: Control = null) -> void:
	if not _is_safe(attacker_ui):
		return
	stop_for(attacker_ui)
	var original_pos := attacker_ui.position
	var lunge_offset := Vector2(0, -12)
	# 如果目标存在，向目标方向冲
	if _is_safe(target_ui):
		var dir := (target_ui.global_position - attacker_ui.global_position).normalized()
		lunge_offset = dir * 20.0

	var tween: Tween = attacker_ui.create_tween()
	tween.tween_property(attacker_ui, "position", original_pos + lunge_offset, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker_ui, "position", original_pos, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_one_shot_tweens.append(tween)


# ============================================================
# 效果发动 — 按卡牌类型差异化闪光
# ============================================================

func play_card_effect(card_ui: Control, card_type: String = "", is_super: bool = false) -> void:
	if not _is_safe(card_ui):
		return
	var flash_color: Color
	var duration: float = 0.25
	if is_super:
		flash_color = Color(1.6, 0.9, 0.2, 1)    # FINISHER 金红强光
		duration = 0.4
	else:
		match card_type:
			"SPELL":  flash_color = Color(0.5, 0.6, 2.0, 1)   # 蓝光
			"BUILD":  flash_color = Color(1.4, 0.7, 0.15, 1)  # 铜金
			"COUNTER": flash_color = Color(0.3, 1.0, 0.5, 1)   # 暗绿
			_:        flash_color = Color(1.5, 1.5, 1.8, 1)    # 通用白蓝

	var tween: Tween = card_ui.create_tween()
	tween.tween_property(card_ui, "modulate", flash_color, 0.08)
	tween.tween_property(card_ui, "modulate", Color(1, 1, 1, 1), duration)
	_one_shot_tweens.append(tween)


# ============================================================
# 落位动画 — 打出后落地冲击
# ============================================================

func play_card_landing(card_ui: Control, card_type: String, is_super: bool = false) -> void:
	if not _is_safe(card_ui):
		return
	stop_for(card_ui)
	var rest_scale := Vector2.ONE
	if card_ui.has_method("get_tabletop_rest_scale"):
		rest_scale = card_ui.get_tabletop_rest_scale()

	if is_super:
		# FINISHER：放大落地 + 金红强光
		card_ui.scale = rest_scale * 0.5
		card_ui.modulate = Color(1.8, 1.4, 0.3, 1)
		var t: Tween = card_ui.create_tween()
		t.set_parallel(true)
		t.tween_property(card_ui, "scale", rest_scale * 1.08, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(card_ui, "modulate", Color(1, 1, 1, 1), 0.3)
		t.tween_property(card_ui, "scale", rest_scale, 0.15)\
			.set_delay(0.18)
		_one_shot_tweens.append(t)
		return

	match card_type:
		"MONSTER":
			# 落位缩放 pulse
			card_ui.scale = rest_scale * 0.7
			card_ui.modulate.a = 0.6
			var t: Tween = card_ui.create_tween()
			t.set_parallel(true)
			t.tween_property(card_ui, "scale", rest_scale * 1.06, 0.12)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(card_ui, "modulate:a", 1.0, 0.12)
			t.tween_property(card_ui, "scale", rest_scale, 0.15)\
				.set_delay(0.12)
			_one_shot_tweens.append(t)
		"BUILD":
			# 铜金闪光 + 轻微 scale
			card_ui.modulate = Color(1.5, 1.1, 0.4, 1)
			card_ui.scale = rest_scale * 0.8
			var t: Tween = card_ui.create_tween()
			t.set_parallel(true)
			t.tween_property(card_ui, "modulate", Color(1, 1, 1, 1), 0.25)
			t.tween_property(card_ui, "scale", rest_scale, 0.25)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_one_shot_tweens.append(t)
		"COUNTER":
			# 暗化伏线短暂闪一下
			card_ui.modulate.a = 0.4
			var t: Tween = card_ui.create_tween()
			t.tween_property(card_ui, "modulate:a", 1.0, 0.2)
			t.tween_property(card_ui, "modulate:a", 0.65, 0.3)\
				.set_delay(0.1)
			_one_shot_tweens.append(t)
		_:
			# 通用落地 pulse
			card_ui.scale = rest_scale * 0.85
			var t: Tween = card_ui.create_tween()
			t.tween_property(card_ui, "scale", rest_scale, 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_one_shot_tweens.append(t)


# ============================================================
# Premium Idle 分类 — 哪些卡需要特殊轻动
# ============================================================

## 返回卡片是否应获得 premium 手牌/场上待机动画
func _should_use_premium_idle(card: CardData) -> bool:
	if card == null:
		return false
	if card.rarity == CardData.CardRarity.RARE or card.rarity == CardData.CardRarity.SUPER:
		return true
	if card.is_building_card():
		return true
	if card.card_family == "build":
		return true
	if card.archetype_role == CardData.ArchetypeRole.FINISHER:
		return true
	return false


## 返回卡牌类型对应的 hand idle 强度
func _get_hand_idle_intensity(card: CardData) -> float:
	if card == null:
		return 0.3
	if card.rarity == CardData.CardRarity.SUPER:
		return 1.5
	if card.rarity == CardData.CardRarity.RARE:
		return 1.0
	if card.is_building_card():
		return 0.8
	return 0.5


## 返回场上待机的卡牌类型标签
func _get_field_idle_type(card: CardData) -> String:
	if card == null:
		return ""
	if card.is_front_row_card():
		return "MONSTER"
	if card.is_building_card():
		return "BUILD"
	if card.display_type == CardData.DisplayType.TRAP:
		return "COUNTER"
	if card.rarity == CardData.CardRarity.SUPER:
		return "FINISHER"
	return ""


# ============================================================
# Phase 12B: Premium Card Surface MVP
# ============================================================

## 公开判定：卡片是否应获得 premium 卡面效果
func is_premium_card(card: CardData) -> bool:
	if card == null:
		return false
	if card.rarity == CardData.CardRarity.RARE or card.rarity == CardData.CardRarity.SUPER:
		return true
	if card.is_building_card():
		return true
	if card.archetype_role == CardData.ArchetypeRole.FINISHER:
		return true
	return false


## 返回 premium 卡面的流光颜色
func _get_premium_sweep_color(card: CardData) -> Color:
	if card == null:
		return Color(0.6, 0.6, 0.85, 0.10)
	# FINISHER / SUPER → 金红 + 白光
	if card.rarity == CardData.CardRarity.SUPER or card.archetype_role == CardData.ArchetypeRole.FINISHER:
		return Color(1.0, 0.85, 0.35, 0.18)
	# BUILD → 铜金 + 蓝白
	if card.is_building_card():
		return Color(0.7, 0.6, 0.9, 0.15)
	# RARE → 白金 + 淡蓝
	if card.rarity == CardData.CardRarity.RARE:
		return Color(0.8, 0.8, 1.0, 0.14)
	# 默认 — 不应到达此路径
	return Color(0.6, 0.6, 0.75, 0.08)


## 返回 premium 卡面呼吸的 alpha 范围 [lo, hi]
func _get_premium_breath_range(card: CardData) -> Array:
	if card == null:
		return [0.04, 0.10]
	if card.rarity == CardData.CardRarity.SUPER:
		return [0.08, 0.22]
	if card.rarity == CardData.CardRarity.RARE:
		return [0.06, 0.16]
	if card.is_building_card():
		return [0.05, 0.14]
	return [0.04, 0.10]


## 启动 premium 卡面效果（卡面流光 + 边缘呼吸）
## mode: -1=auto(根据CardUI模式), 0=手牌, 1=场上, 2=详情
func play_premium_surface(card_ui: Control, card: CardData, mode: int = -1) -> void:
	if not _is_safe(card_ui):
		return
	if card == null:
		return
	if not is_premium_card(card):
		return

	# 先停止旧效果
	stop_premium_surface(card_ui)

	var art_panel: Panel = null
	if card_ui.has_method("get_art_panel"):
		art_panel = card_ui.get_art_panel()
	if art_panel == null or not _is_safe(art_panel):
		return

	var is_hand: bool = true
	var is_detail: bool = false
	if mode >= 0:
		is_hand = (mode == 0)
		is_detail = (mode == 2)
	elif card_ui.has_method("get_display_mode"):
		var dm: int = card_ui.get_display_mode()  # CardDisplayMode enum
		is_hand = (dm == 0)  # HAND
		is_detail = (dm == 3)  # DETAIL

	var sweep_color := _get_premium_sweep_color(card)
	var breath_range: Array = _get_premium_breath_range(card)
	var sweep_duration: float = 3.0 if is_detail else 2.6
	var breath_lo: float = breath_range[0]
	var breath_hi: float = breath_range[1]
	# 场上强度降低
	if not is_hand and not is_detail:
		breath_lo *= 0.5
		breath_hi *= 0.6
		sweep_color.a *= 0.6

	# ── 效果 A: 卡面流光 ──
	var sweep := ColorRect.new()
	sweep.name = "PremiumSweepLine"
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	sweep.color = sweep_color
	# 初始位置：左侧窄条
	sweep.anchor_left = 0.0
	sweep.anchor_right = 0.0
	sweep.offset_right = 6.0
	art_panel.add_child(sweep)

	var sweep_tween: Tween = card_ui.create_tween()
	sweep_tween.set_loops()
	# 从左扫到右
	var sweep_key := "%d_sweep" % card_ui.get_instance_id()
	sweep_tween.tween_property(sweep, "anchor_left", 0.0, sweep_duration * 0.15)\
		.set_trans(Tween.TRANS_LINEAR)
	sweep_tween.tween_property(sweep, "anchor_left", 1.0, sweep_duration * 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sweep_tween.tween_property(sweep, "anchor_right", 1.0, sweep_duration * 0.15)\
		.set_trans(Tween.TRANS_LINEAR)
	sweep_tween.tween_interval(sweep_duration * 0.1)
	# 重置到左侧
	sweep_tween.tween_callback(func():
		if _is_safe(sweep):
			sweep.anchor_left = 0.0
			sweep.anchor_right = 0.0
			sweep.offset_right = 6.0
	)
	_loop_tweens[sweep_key] = sweep_tween

	# ── 效果 B: 边缘微光呼吸 ──
	var glow := ColorRect.new()
	glow.name = "PremiumEdgeGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(sweep_color.r, sweep_color.g, sweep_color.b, breath_lo)
	art_panel.add_child(glow)

	var glow_key := "%d_glow" % card_ui.get_instance_id()
	var glow_tween: Tween = card_ui.create_tween()
	glow_tween.set_loops()
	var period: float = 2.0 if is_detail else 1.5
	glow_tween.tween_property(glow, "color:a", breath_hi, period * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(glow, "color:a", breath_lo, period * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop_tweens[glow_key] = glow_tween

	print("[PremiumSurface] Started for %s (hand=%s detail=%s)" % [card.card_name if "card_name" in card else "?", is_hand, is_detail])


## 停止 premium 卡面效果
func stop_premium_surface(card_ui: Control) -> void:
	if not _is_safe(card_ui):
		return

	# Kill loop tweens
	for suffix in ["_sweep", "_glow"]:
		var key := "%d%s" % [card_ui.get_instance_id(), suffix]
		if _loop_tweens.has(key):
			var tw: Tween = _loop_tweens[key]
			if tw and tw.is_valid():
				tw.kill()
			_loop_tweens.erase(key)

	# Clean up overlay nodes
	var art_panel: Panel = null
	if card_ui.has_method("get_art_panel"):
		art_panel = card_ui.get_art_panel()
	if art_panel != null and _is_safe(art_panel):
		for overlay_name in ["PremiumSweepLine", "PremiumEdgeGlow"]:
			var node := art_panel.get_node_or_null(NodePath(overlay_name))
			if node != null and is_instance_valid(node):
				node.queue_free()


# ============================================================
# Phase 12C: Card Play Cinematic — 出牌电影感
# ============================================================

## 出牌 Departure — 卡牌从手牌离开前的起手闪光
func play_card_departure(card_ui: Control, card_type: String, is_super: bool = false) -> void:
	if not _is_safe(card_ui):
		return

	stop_for(card_ui)
	var orig_scale := card_ui.scale
	var orig_mod := card_ui.modulate
	var flash_color: Color
	var departure_scale: float = 1.12

	if is_super:
		flash_color = Color(2.0, 1.5, 0.35, 1)
		departure_scale = 1.2
	else:
		match card_type:
			"MONSTER": flash_color = Color(1.4, 0.65, 0.2, 1)
			"BUILD":   flash_color = Color(1.3, 0.7, 0.25, 1)
			"COUNTER": flash_color = Color(0.3, 1.0, 0.65, 1)
			"SPELL":   flash_color = Color(0.4, 0.55, 2.0, 1)
			_:         flash_color = Color(1.3, 1.3, 1.4, 1)

	var tween: Tween = card_ui.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_ui, "scale", Vector2(departure_scale, departure_scale), 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "modulate", flash_color, 0.08)
	tween.tween_property(card_ui, "modulate", orig_mod, 0.12).set_delay(0.08)
	tween.tween_property(card_ui, "scale", orig_scale, 0.12).set_delay(0.1)
	_one_shot_tweens.append(tween)


## ActionSlot Focus — SPELL/FINISHER 进入行动槽后的聚焦脉冲
func play_action_slot_focus(card_ui: Control, card_type: String, is_super: bool = false) -> void:
	if not _is_safe(card_ui):
		return

	stop_for(card_ui)
	var focus_color: Color
	var focus_scale: float = 1.08
	var settle_time: float = 0.25

	if is_super:
		focus_color = Color(1.8, 1.3, 0.25, 1)
		focus_scale = 1.15
		settle_time = 0.35
	else:
		match card_type:
			"SPELL":   focus_color = Color(0.5, 0.65, 2.0, 1)
			"MONSTER": focus_color = Color(1.3, 0.7, 0.3, 1)
			"BUILD":   focus_color = Color(1.2, 0.65, 0.2, 1)
			"COUNTER": focus_color = Color(0.4, 1.0, 0.7, 1)
			_:         focus_color = Color(1.2, 1.2, 1.3, 1)

	var tween: Tween = card_ui.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_ui, "scale", Vector2(focus_scale, focus_scale), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "modulate", focus_color, 0.10)
	tween.tween_property(card_ui, "modulate", Color(1, 1, 1, 1), settle_time).set_delay(0.10)
	tween.tween_property(card_ui, "scale", Vector2(1.0, 1.0), settle_time).set_delay(0.12)
	_one_shot_tweens.append(tween)


## 获取卡牌类型的 voyage 颜色（供外部使用）
func _get_cinematic_color(card_type: String, is_super: bool) -> Color:
	if is_super:
		return Color(1.8, 1.4, 0.3, 1)
	match card_type:
		"MONSTER": return Color(1.3, 0.6, 0.2, 1)
		"BUILD":   return Color(1.2, 0.65, 0.2, 1)
		"COUNTER": return Color(0.3, 0.9, 0.6, 1)
		"SPELL":   return Color(0.4, 0.6, 1.9, 1)
	return Color(1.1, 1.1, 1.2, 1)


# ============================================================
# 受击 — 抖动 + 红闪
# ============================================================

func play_card_hit(card_ui: Control) -> void:
	if not _is_safe(card_ui):
		return
	stop_for(card_ui)
	var orig_pos := card_ui.position
	var orig_mod := card_ui.modulate

	var tween: Tween = card_ui.create_tween()
	tween.tween_property(card_ui, "modulate", Color(1.6, 0.3, 0.3, 1), 0.05)
	# 抖动 3 次
	for _i in range(3):
		tween.tween_property(card_ui, "position:x", orig_pos.x + 4, 0.03)
		tween.tween_property(card_ui, "position:x", orig_pos.x - 4, 0.03)
	tween.tween_property(card_ui, "position", orig_pos, 0.06)
	tween.tween_property(card_ui, "modulate", orig_mod, 0.15)
	_one_shot_tweens.append(tween)


# ============================================================
# 破坏 — 淡出缩小
# ============================================================

func play_card_destroy(card_ui: Control) -> void:
	if not _is_safe(card_ui):
		return
	stop_for(card_ui)
	var tween: Tween = card_ui.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_ui, "modulate:a", 0.0, 0.3)
	tween.tween_property(card_ui, "scale", Vector2(0.5, 0.5), 0.3)
	# 淡出后隐藏（不释放，由调用者管理生命周期）
	var t2: Tween = card_ui.create_tween()
	t2.tween_interval(0.32)
	t2.tween_callback(func():
		if _is_safe(card_ui):
			card_ui.visible = false
	)
	_one_shot_tweens.append(tween)
	_one_shot_tweens.append(t2)


# ============================================================
# 生命周期清理
# ============================================================

func _exit_tree() -> void:
	stop_all()
