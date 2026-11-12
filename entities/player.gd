extends Node
class_name Player

const MAX_OD := 10
const MAX_HAND_SIZE := 10  # Phase 8A-Hotfix: 手牌上限

var hp: int = 35
var od: int = 0
var od_phase: int = 0
var is_awakened: bool = false
var temp_damage_bonus: int = 0
var shield: int = 0

var field: Array = []
var graveyard: Array = []
var deck: Array = []
var hand: Array = []
var discard: Array = []
var buffs: Array = []
var traps: Array = []

signal od_phase_changed(new_phase: int)
signal awakening_triggered()
## Observation of the completed native damage transaction; no rule changes.
signal damage_committed(receipt: Dictionary)

# Phase 8A-Hotfix: 手牌上限辅助
func can_add_to_hand() -> bool:
	return hand.size() < MAX_HAND_SIZE

func get_hand_limit() -> int:
	return MAX_HAND_SIZE

# Phase 5B-2: 伤害减免钩子（BattleSystem 设置，P16 封压壁等建筑用）
var damage_prevention_callback: Callable
## Optional encounter phase guard; ordinary encounters keep it unbound.
var encounter_damage_allowed: Callable


# Phase 25B-R1: OD 变更回调 — 由 BattleScene 绑定到 context.change_od
var od_change_request_callback: Callable

func modify_od(amount: int) -> void:
	if od_change_request_callback.is_valid():
		od_change_request_callback.call(amount)
		return
	# Fallback: 独立 Player（无战斗上下文）仍使用旧逻辑
	var old_od = od
	od = clampi(od + amount, 0, MAX_OD)
	update_od_phase()
	print("[OD:fallback] %d -> %d (Phase %d)" % [old_od, od, od_phase])


func take_damage(dmg: int) -> void:
	if encounter_damage_allowed.is_valid() and not encounter_damage_allowed.call():return
	var receipt_hp_before: int = hp
	var receipt_shield_before: int = shield
	# Phase 5B-2: 伤害减免钩子
	var effective_dmg := dmg
	var prevented_info := {}
	if damage_prevention_callback.is_valid():
		var result: Variant = damage_prevention_callback.call(dmg)
		if result is Dictionary:
			effective_dmg = result.get("damage", dmg)
			prevented_info = result
		else:
			effective_dmg = int(result) if typeof(result) == TYPE_INT else dmg
	var remaining := effective_dmg
	if shield > 0:
		var absorbed := mini(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		print("[SHIELD] Absorbed %d damage (shield left: %d)" % [absorbed, shield])
	if remaining > 0:
		hp -= remaining
	if prevented_info.is_empty():
		print("[HIT] Player takes %d damage (shield absorbed %d) -> HP: %d, Shield: %d" % [dmg, dmg - remaining, hp, shield])
	else:
		var prevented: int = prevented_info.get("prevented", 0)
		var card_name: String = prevented_info.get("card", "?")
		print("[HIT] Player takes %d damage (prevented %d by %s, shield absorbed %d) -> HP: %d, Shield: %d" % [effective_dmg, prevented, card_name, dmg - remaining, hp, shield])

	damage_committed.emit({"requested": dmg, "effective": effective_dmg, "hp_before": receipt_hp_before, "hp_after": hp, "shield_before": receipt_shield_before, "shield_after": shield})

func is_dead() -> bool:
	return hp <= 0


# Phase 24B: Install callback from BattleSystem.init(); draw delegates to authority
var draw_request_callback: Callable

func draw(amount: int, source: String = "Player.draw") -> Dictionary:
	if amount <= 0:
		return {"requested": amount, "drawn": [], "burned": [], "heat_cycles": 0, "recycled_count": 0, "depth_added": 0, "fatigue_damage": 0, "fatigue_triggers": 0, "source": source}
	if draw_request_callback.is_valid():
		var resolved: Variant = draw_request_callback.call(amount, source)
		if resolved is Dictionary:
			return resolved
	# Compatibility: old void draw() callers — route via hand-add directly (no heat cycle)
	for _i in range(amount):
		if deck.is_empty():
			if discard.is_empty():
				break
			deck = discard.duplicate()
			discard.clear()
		if deck.is_empty():
			break
		var card = deck.pop_front()
		if hand.size() >= MAX_HAND_SIZE:
			graveyard.append(card)
			continue
		hand.append(card)
	return {"requested": amount, "drawn": [], "burned": [], "heat_cycles": 0, "recycled_count": 0, "depth_added": 0, "fatigue_damage": 0, "fatigue_triggers": 0, "source": source, "error": "draw_authority_missing"}


## Phase 25B-R1: od_phase 由 ODMode._sync_to_player() 从快照 Zone 直接写入。
## 保留 update_od_phase() 仅作为 fallback（独立 Player 或未绑定 callback 时使用）。
func update_od_phase() -> void:
	# 如果 callback 已绑定，od_phase 由 ODMode._sync_to_player() 权威写入，不应在此覆盖
	if od_change_request_callback.is_valid():
		return
	# Fallback: 使用旧硬编码阈值
	var old_phase = od_phase
	if od >= MAX_OD:
		od_phase = 3
	elif od >= 7:
		od_phase = 2
	elif od >= 4:
		od_phase = 1
	else:
		od_phase = 0
	if od_phase != old_phase:
		od_phase_changed.emit(od_phase)
	if od >= MAX_OD and not is_awakened:
		awakening_triggered.emit()
