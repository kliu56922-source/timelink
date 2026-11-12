extends Node
class_name ComboSystem

var combo_count := 0
var combo_timer := 0.0
const COMBO_TIMEOUT := 2.5

func _process(delta: float) -> void:
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			_reset()

func on_card_played() -> void:
	combo_count += 1
	combo_timer = COMBO_TIMEOUT

func _reset() -> void:
	if combo_count > 0:
		print("Combo End: %d" % combo_count)
	combo_count = 0
	combo_timer = 0.0

func get_speed_multiplier() -> float:
	return 1.0 + combo_count * 0.15

func get_od_multiplier() -> float:
	return mini(1.0 + combo_count * 0.2, 2.0)  # ADR-0003: 全局硬上限 combo_mult ≤ 2.0

func get_shake_strength() -> float:
	return 5.0 + combo_count * 2.0

func get_od_bonus() -> int:
	return floori(combo_count / 5.0)

func get_repeat_bonus() -> int:
	return floori(combo_count / 3.0)

func get_draw_bonus() -> int:
	return floori(combo_count / 4.0)

func get_card_od_cost(card):
	# TODO: 实现 OD 成本计算逻辑
	# 目前返回基于连击数的基础值
	return max(1, combo_count)
func reset():
	combo_count = 0