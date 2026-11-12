extends Node
class_name Enemy

const TC = preload("res://core/theme/theme_colors.gd")
const MAX_OD := 10
## Optional encounter policy. No effect on ordinary Boss encounters.
var encounter_damage_allowed: Callable
var opening_intent_provider: Callable

# ============================================================
# Boss 属性 — 熔炉守卫
# ============================================================
var hp: int = 85
var max_hp: int = 85
var deck: Array = []
var hand: Array = []
var field: Array = []
var traps: Array = []
var graveyard: Array = []

# ============================================================
# OD 系统
# ============================================================
var od: int = 0
var max_od: int = MAX_OD

# Zone 阈值
const ZONE_CALM_MAX := 3
const ZONE_HEATED_MAX := 7

# 追踪上一次 Zone
var _previous_zone: String = "Calm"
var _turn_count: int = 0

# 领域被动
var forge_domain_active: bool = false
var forge_armor_bonus: int = 0  # 前2回合额外护甲（与Domain叠加）

# Boss 意图文本（供 UI 读取）
var intent_text: String = ""
var intent_color: Color = Color.WHITE
var intent_danger: String = ""  # LOW / MID / HIGH / OVERDRIVE

# 陷阱临时伤害修正（本回合有效，act() 后清零）
var trap_damage_mult: float = 1.0

# Boss 护盾 — ADR-0006: 专用字段，不经过 ShieldEffect
# 扣减顺序: shield → armor → HP
var boss_shield: int = 0

# 统计（供结算面板）
var overdrive_entry_count: int = 0  # 进入Overdrive次数
var was_interrupted: bool = false    # 本次从Overdrive被Trap/Control降低

# 显示名
var player_name: String = "熔炉守卫"

# ============================================================
# 信号
# ============================================================
signal zone_changed(old_zone: String, new_zone: String)
signal intent_revealed(card: CardData)
## Phase 24A: Emitted after any HP/shield/OD/zone change. Carries immutable snapshot.
signal combat_state_changed(snapshot: Dictionary)
## Phase 24A: Emitted after intent fields are fully assigned.
signal intent_state_changed(snapshot: Dictionary)

## Phase 24A: Boss phase counter (1→2→3).
var combat_phase: int = 1


# ============================================================
# OD 系统
# ============================================================
func modify_od(amount: int) -> void:
	var old_od := od
	var old_zone := get_od_zone_name()
	od = clampi(od + amount, 0, max_od)
	var new_zone := get_od_zone_name()
	print("[BOSS OD] %d %+d → %d  [%s]" % [old_od, amount, od, new_zone])
	if old_zone != new_zone:
		_previous_zone = old_zone
		zone_changed.emit(old_zone, new_zone)
		_on_zone_changed(old_zone, new_zone)
	notify_combat_state_changed()


func reset_od() -> void:
	od = 0
	forge_domain_active = false
	print("[BOSS OD] Reset to 0 — Forge Domain cleared")
	notify_combat_state_changed()


func get_od_zone_name() -> String:
	if od <= ZONE_CALM_MAX:
		return "Calm"
	elif od <= ZONE_HEATED_MAX:
		return "Heated"
	return "Overdrive"


func get_od_zone_color() -> Color:
	match get_od_zone_name():
		"Calm": return TC.ZONE_CALM
		"Heated": return TC.ZONE_HEATED
		"Overdrive": return TC.ZONE_OVERDRIVE
	return TC.TEXT_DIM


func is_overdrive() -> bool:
	return od >= 8


# ============================================================
# Phase 24A: 状态权威 API
# ============================================================
func get_boss_status_snapshot() -> Dictionary:
	return {
		"name": player_name,
		"hp": hp,
		"max_hp": max_hp,
		"shield": boss_shield,
		"od": od,
		"max_od": max_od,
		"zone": get_od_zone_name(),
		"phase": "PHASE %d" % combat_phase,
		"intent_text": intent_text,
		"intent_danger": intent_danger,
	}


func notify_combat_state_changed() -> void:
	combat_state_changed.emit(get_boss_status_snapshot())


func notify_intent_changed() -> void:
	intent_state_changed.emit(get_boss_status_snapshot())


func set_hp_authoritative(value: int, source: String = "") -> void:
	if value<hp and encounter_damage_allowed.is_valid() and not encounter_damage_allowed.call():return
	hp = value
	print("[BOSS STATE] hp=%d source=%s" % [hp, source])
	notify_combat_state_changed()


func change_hp_direct(delta: int, source: String = "") -> void:
	if delta<0 and encounter_damage_allowed.is_valid() and not encounter_damage_allowed.call():return
	hp += delta
	print("[BOSS STATE] hp_delta=%+d hp=%d source=%s" % [delta, hp, source])
	notify_combat_state_changed()


func add_boss_shield(amount: int, source: String = "") -> void:
	boss_shield = maxi(0, boss_shield + amount)
	print("[BOSS STATE] shield_delta=%+d shield=%d source=%s" % [amount, boss_shield, source])
	notify_combat_state_changed()


func apply_phase_lock_state(hp_value: int, shield_gain: int, new_phase: int, source: String) -> void:
	hp = hp_value
	boss_shield = maxi(0, boss_shield + shield_gain)
	combat_phase = maxi(combat_phase, new_phase)
	print("[BOSS STATE] phase=%d hp=%d shield_delta=%+d source=%s" % [combat_phase, hp, shield_gain, source])
	notify_combat_state_changed()


# ============================================================
# Zone 切换回调 — 处理所有 6 种转换
# ============================================================
func _on_zone_changed(old_zone: String, new_zone: String) -> void:
	print("[BOSS ZONE] %s → %s" % [old_zone, new_zone])

	# 离开 Heated → 关闭熔炉领域
	if old_zone == "Heated" and forge_domain_active:
		_deactivate_forge_domain()

	# 从Overdrive降级 = 被玩家打断
	if old_zone == "Overdrive" and new_zone != "Overdrive":
		was_interrupted = true

	# 进入新区
	match new_zone:
		"Heated":
			_activate_forge_domain()
		"Overdrive":
			overdrive_entry_count += 1
			_activate_overdrive_mode()


# ============================================================
# 领域被动：升温区激活熔炉领域（减伤 1）
# ============================================================
func _activate_forge_domain() -> void:
	forge_domain_active = true
	print("[BOSS DOMAIN] Forge Domain ACTIVATED — all damage reduced by 1")


func _deactivate_forge_domain() -> void:
	forge_domain_active = false
	print("[BOSS DOMAIN] Forge Domain DEACTIVATED — damage reduction removed")


# ============================================================
# 超驱模式
# ============================================================
func _activate_overdrive_mode() -> void:
	print("[BOSS OVERDRIVE] Entering meltdown mode! All systems critical.")


# ============================================================
# 战斗
# ============================================================
## Pure calculation shared by GB3I preview and actual damage. -1 uses live shield.
func preview_damage(dmg: int, bypass_shield: bool = false, shield_override: int = -1) -> Dictionary:
	var shield_before := boss_shield if shield_override < 0 else shield_override
	var damage := maxi(0, dmg)
	var absorbed := mini(damage, shield_before) if not bypass_shield else 0
	damage -= absorbed
	var armor := (forge_armor_bonus if _turn_count <= 2 else 0) + (1 if forge_domain_active else 0)
	var before_armor := damage
	if armor > 0 and damage > 0: damage = maxi(1, damage - armor)
	return {"hp_after": hp - damage, "hp_loss": damage, "shield_after": shield_before - absorbed, "absorbed": absorbed, "armor_prevented": before_armor - damage}

func take_damage(dmg: int, bypass_shield: bool = false) -> void:
	if encounter_damage_allowed.is_valid() and not encounter_damage_allowed.call():return
	var result := preview_damage(dmg, bypass_shield)
	boss_shield = result.shield_after
	hp = result.hp_after
	print("[HIT] %s takes %d damage → HP: %d/%d" % [player_name, result.hp_loss, hp, max_hp])
	notify_combat_state_changed()


func is_dead() -> bool:
	return hp <= 0


func draw(amount: int) -> void:
	for _i in range(amount):
		if deck.is_empty():
			if graveyard.is_empty():
				break
			deck = graveyard.duplicate()
			graveyard.clear()
		if not deck.is_empty():
			var card = deck.pop_front()
			hand.append(card)


# ============================================================
# AI：回合行动 — Boss Card Deck v2.0 MVP
# ============================================================
var boss_deck: BossCardDeck = null  # 由 BattleScene 注入

## 揭示意图：OD增长 + 抽意图卡 + 设置 intent_text/danger/color
## Phase 4C-4: 揭示意图 — OD增长 + 抽意图卡 + Zone行为倾向
func reveal_intent() -> void:
	_turn_count += 1

	# 1. 每回合自然增长 OD +2
	modify_od(2)

	var zone := get_od_zone_name()
	print("")
	print("== BOSS TURN %d ==" % _turn_count)
	print("Boss HP:%d/%d OD:%d Zone:%s Shield:%d Field:%d Trap:%d" % [hp, max_hp, od, zone, boss_shield, field.size(), traps.size()])

	# 2. 牌驱动：从 Zone 池抽牌
	if opening_intent_provider.is_valid() and boss_deck!=null:
		var opening: CardData=opening_intent_provider.call()
		if opening!=null:
			boss_deck.current_intent=opening
			intent_text=opening.get_display_name()+"："+opening.short_description
			intent_danger="LOW";intent_color=TC.ZONE_CALM
			notify_intent_changed();boss_deck.intent_updated.emit(opening,"LOW");intent_revealed.emit(opening)
			return
	if boss_deck and boss_deck.has_method("draw_card"):
		var card: CardData = boss_deck.draw_card(zone)
		if card:
			# Phase 4C-4: 意图文本含 Zone 行为倾向
			var behavior_text := _get_zone_behavior_text(zone)
			intent_text = "[%s] %s" % [behavior_text, card.card_name]
			match zone:
				"Calm": intent_danger = "LOW"; intent_color = TC.ZONE_CALM
				"Heated": intent_danger = "MID"; intent_color = TC.ZONE_HEATED
				"Overdrive": intent_danger = "HIGH"; intent_color = TC.ZONE_OVERDRIVE
			# Phase 24A-R: notify_intent_changed 必须在 intent_revealed.emit 之前
			notify_intent_changed()
			intent_revealed.emit(card)
			return

	# Zone pool empty or no boss_deck -> fallback intent
	_set_fallback_intent(zone)


## Phase 4C-4: 返回当前 Zone 对应的行为倾向短文本（2-3字）
func _get_zone_behavior_text(zone: String) -> String:
	match zone:
		"Calm":     return "部署"
		"Heated":   return "设伏"
		"Overdrive": return "爆发"
	return ""


## Set fallback intent for old AI
func _set_fallback_intent(zone: String) -> void:
	match zone:
		"Calm":
			intent_text = "[部署] Forge Strike 2"
			intent_danger = "LOW"
			intent_color = TC.ZONE_CALM
		"Heated":
			intent_text = "[设伏] Heated Slam 4"
			intent_danger = "MID"
			intent_color = TC.ZONE_HEATED
		"Overdrive":
			intent_text = "[爆发] Meltdown Burst %d !!" % _meltdown_burst_dmg()
			intent_danger = "OVERDRIVE"
			intent_color = TC.ZONE_OVERDRIVE
	notify_intent_changed()


## Execute the currently drawn intent card (call after reveal_intent + animation)
func execute_intent(target: Player) -> void:
	var zone := get_od_zone_name()
	var cancelled_b18: CardData = null
	if boss_deck and boss_deck.has_intent():
		var card = boss_deck.current_intent
		var terrain_status: Dictionary = {}
		var b18_blocked := false
		if card != null and card.card_id == "B-18" and boss_deck.battle_system != null \
				and boss_deck.battle_system.has_method("get_boss_terrain_card_status"):
			terrain_status = boss_deck.battle_system.get_boss_terrain_card_status(card)
			b18_blocked = not terrain_status.get("ok", false)
		if b18_blocked:
			# GB-2A: 抽中 B-18 后、施放前失去资格 → 取消本次施放。
			# 不再转换成隐藏的直接攻击：不走 boss_play_card，因此不支付 OD+1、
			# 不执行任何牌效果、不进玩家或 Boss 墓地；也不重抽、不补偿、不改地形。
			# 已登记的其他 pending 与后续战术 AI 均不受影响。
			cancelled_b18 = card
			intent_text = "断层轰击取消：当前无合法目标"
			print("[B18_CANCELLED] reason=%s" % str(terrain_status.get("reason_code", &"terrain_threat_invalid")))
			notify_intent_changed()
		elif boss_deck.battle_system and boss_deck.battle_system.has_method("boss_play_card"):
			boss_deck.battle_system.boss_play_card(card)
		boss_deck.play_intent_card()
	else:
		_fallback_act(target, zone)

	# Low HP override
	if is_low_hp() and intent_danger != "HIGH":
		intent_danger = "HIGH"

	# Reset per-turn state
	trap_damage_mult = 1.0
	was_interrupted = false

	# GB-2A: 消费之后再释放本次未施放的独立克隆；不在本次调用仍引用该卡时提前 free。
	if cancelled_b18 != null:
		_release_unplayed_b18(cancelled_b18)


## GB-2A: 释放本次被取消、且没有任何权威持有的 B-18 克隆。
## 已经入场 / 进墓地 / 属于卡池模板或卡组墓地时不释放，只报告异常身份原因。
func _release_unplayed_b18(card: CardData) -> void:
	var owner_reason := _unplayed_b18_owner_reason(card)
	if not owner_reason.is_empty():
		print("[B18_CANCELLED_OWNERSHIP] reason=%s — card not released" % owner_reason)
		return
	card.queue_free()


func _unplayed_b18_owner_reason(card: CardData) -> String:
	if card == null:
		return "null_card"
	if not is_instance_valid(card):
		return "freed_instance"
	if field.has(card):
		return "boss_field"
	if traps.has(card):
		return "boss_back_row"
	if graveyard.has(card):
		return "boss_graveyard"
	if boss_deck == null:
		return ""
	if boss_deck.current_intent == card:
		return "still_current_intent"
	if boss_deck.graveyard.has(card):
		return "deck_graveyard"
	for zone_name in ["Calm", "Heated", "Overdrive"]:
		if boss_deck.get_pool(zone_name).has(card):
			return "deck_pool_template"
	return ""


## Backward-compatible wrapper: reveal + execute together
func act(target: Player) -> void:
	reveal_intent()
	execute_intent(target)


func _fallback_act(target: Player, zone: String) -> void:
	match zone:
		"Calm":
			intent_text = "熔炉打击 %d" % 3
			intent_danger = "LOW"
			intent_color = TC.ZONE_CALM
			_forge_strike(target, 3, "Forge Strike")
		"Heated":
			intent_text = "蓄热重击 %d" % 4
			intent_danger = "MID"
			intent_color = TC.ZONE_HEATED
			_forge_strike(target, 4, "Heated Slam")
			modify_od(1)
		"Overdrive":
			var burst := _meltdown_burst_dmg()
			intent_text = "熔毁爆发 %d !!" % burst
			intent_danger = "OVERDRIVE"
			intent_color = TC.ZONE_OVERDRIVE
			_meltdown_burst(target)
			modify_od(-5)


# ============================================================
# 攻击技
# ============================================================
func _forge_strike(target: Player, dmg: int, label: String) -> void:
	var actual: int = maxi(1, int(ceil(dmg * trap_damage_mult)))
	if trap_damage_mult < 1.0:
		print("[BOSS TRAP] Damage reduced x%.0f%%: %d → %d" % [(1.0 - trap_damage_mult) * 100, dmg, actual])
	target.take_damage(actual)
	print("[BOSS] %s: %d damage to player" % [label, actual])


func _meltdown_burst_dmg() -> int:
	var burst_dmg: int = 6
	if forge_domain_active:
		burst_dmg += 1
	return burst_dmg


func _meltdown_burst(target: Player) -> void:
	var burst_dmg := _meltdown_burst_dmg()
	target.take_damage(burst_dmg)
	print("[BOSS SKILL] Meltdown Burst: %d damage to player!" % burst_dmg)


func _armor_description() -> String:
	var parts: Array[String] = []
	if _turn_count <= 2:
		parts.append("炉甲+" + str(forge_armor_bonus))
	if forge_domain_active:
		parts.append("领域+1")
	if parts.is_empty():
		return "无"
	return ", ".join(parts)


## Boss 是否濒死（HP < 30%）
func is_low_hp() -> bool:
	return hp < max_hp * 0.3
