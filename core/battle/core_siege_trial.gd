extends RefCounted
## GB3I only: one opening per column, created by an actual P04 intercept.
var _battle_ref: WeakRef
var columns: Dictionary = {}

func _init(battle: Node) -> void:
	_battle_ref = weakref(battle)

func suppress_column(column: int) -> void:
	if column >= 0 and column < 5: columns[column] = true

func end_turn(side: StringName) -> void:
	if side == &"player": columns.clear()

func can_bypass(attacker: CardData, damage: int, shield: int) -> bool:
	var bt = _battle_ref.get_ref()
	return is_instance_valid(attacker) and attacker in bt.context.player.field and damage > 0 and shield > 0 and columns.has(bt.get_unit_cell(attacker).x)

## Only called after the normal core attack validator, after ordinary breach.
func consume_for_hit(attacker: CardData, damage: int) -> bool:
	var bt = _battle_ref.get_ref()
	if not can_bypass(attacker, damage, bt.context.enemy.boss_shield): return false
	columns.erase(bt.get_unit_cell(attacker).x)
	return true

func preview_core(attacker: CardData) -> Dictionary:
	var bt = _battle_ref.get_ref()
	var status: Dictionary = bt.get_unit_command_status(attacker, "attack_core")
	if not status.get("ok", false):
		var rejected := status.duplicate(true)
		var core: Dictionary = bt.can_monster_attack_boss(attacker)
		if not core.get("ok", false): rejected["reason"] = core.get("reason", "尚未满足攻城条件")
		return rejected
	if attacker not in bt.context.player.field: return {"ok": false, "reason": "此预览用于己方攻城"}
	var enemy: Enemy = bt.context.enemy
	var damage: int = bt.get_effective_unit_attack(attacker) + bt.get_normal_attack_bonus(attacker)
	var breach: int = mini(enemy.boss_shield, bt.frontline_trial.breach_amount(attacker)) if bt.frontline_trial != null else 0
	var bypass := can_bypass(attacker, damage, enemy.boss_shield - breach)
	var result := enemy.preview_damage(damage, bypass, enemy.boss_shield - breach)
	var hp_damage_before_phase: int = result.hp_loss
	result.merge({"ok": true, "cost": status.get("cost", 0), "damage": damage, "breach": breach, "suppressed": bypass, "hp_before": enemy.hp, "shield_before": enemy.boss_shield, "phase_lock": 0, "od_before": enemy.od, "od_after": enemy.od})
	# Mirrors check_hp_phase_lock, including its one-lock-per-turn rule.
	var overflow := 0
	if bt.context.are_boss_phase_locks_enabled():
		if bt.context.phases_locked_this_turn >= 1:
			overflow = damage
		else:
			for phase in [3, 2]:
				var triggered: bool = bt.context.boss_phase2_triggered if phase == 3 else bt.context.boss_phase1_triggered
				var lock: Dictionary = bt.context.get_boss_phase_lock(phase)
				var threshold: int = lock.get("hp_threshold", 25 if phase == 3 else 51)
				if triggered or result.hp_after > threshold: continue
				result.hp_after = threshold
				result.shield_after += int(lock.get("shield_gain", 6 if phase == 3 else 4))
				result.phase_lock = phase
				overflow = maxi(0, damage - (enemy.hp - threshold))
				if phase == 3: result.od_after = maxi(8, result.od_after)
				break
		if overflow > 0:
			var gain := clampi(ceili(float(overflow) / bt.context.OVERFLOW_OD_DIVISOR), bt.context.OVERFLOW_OD_MIN, bt.context.OVERFLOW_OD_MAX)
			result.od_after = clampi(result.od_after + gain, 0, enemy.max_od)
	result.hp_loss = enemy.hp - int(result.hp_after)
	result["phase_prevented"] = maxi(0, hp_damage_before_phase - int(result.hp_loss))
	return result

func preview_unit(attacker: CardData, target: CardData) -> Dictionary:
	var bt = _battle_ref.get_ref()
	var status: Dictionary = bt.get_unit_command_status(attacker, "attack", target)
	if not status.get("ok", false): return status.duplicate(true)
	if status.has("siege_plan"): return {"ok": false, "reason": "建筑掩护：点击目标查看攻城确认"}
	if attacker not in bt.context.player.field or bt.monster_combat_rules.resolution_mode != "simultaneous_hp":
		return {"ok": false, "reason": "请查看该攻击的专用确认"}
	var outgoing: int = bt.get_effective_unit_attack(attacker) + bt.get_normal_attack_bonus(attacker)
	var incoming: int = target.unit_power
	# The authoritative gateway only applies P05 to player-owned units.
	outgoing = maxi(0, outgoing)
	incoming = maxi(0, incoming - bt._apply_p05_mitigation(attacker, incoming, false))
	if bt.frontline_trial != null: incoming = maxi(0, incoming - bt.frontline_trial.escort_amount(attacker))
	return {"ok": true, "cost": status.get("cost", 0), "target_hp_before": bt._state_for_card(target).current_hp, "target_hp_after": maxi(0, bt._state_for_card(target).current_hp - outgoing), "actor_hp_before": bt._state_for_card(attacker).current_hp, "actor_hp_after": maxi(0, bt._state_for_card(attacker).current_hp - incoming)}
