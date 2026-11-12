extends RefCounted
class_name UnitCombatState

var runtime_id: int = 0
var owner_side: StringName = &"player"
var current_hp: int = 1
var max_hp: int = 1
var encounter_damage_allowed: Callable
var summoned_this_turn: bool = false
var attacks_used: int = 0
var temporary_attack_bonus: int = 0
# Phase 26E: shared action economy
var actions_used: int = 0
var moves_used: int = 0
var last_action: StringName = &""

## Phase 27A: 5×5 grid cell authority
const INVALID_BOARD_CELL := Vector2i(-1, -1)
var board_cell: Vector2i = INVALID_BOARD_CELL

## Phase 27C: core breach / facing / rear defense
var facing_rank_delta: int = 0  ## -1 (toward boss) or +1 (toward player); 0 = uninitialized
var overdrive_breach_used_this_turn: bool = false

## Phase 27D: local command economy modifiers (per-unit, not shared)
var _command_cost_modifier: int = 0
var _has_free_action: bool = false
var _free_action_consumed: bool = false

func _init(
	card_runtime_id: int = 0,
	side: StringName = &"player",
	initial_max_hp: int = 1,
	was_summoned_this_turn: bool = false
) -> void:
	runtime_id = card_runtime_id
	owner_side = side
	max_hp = maxi(1, initial_max_hp)
	current_hp = max_hp
	summoned_this_turn = was_summoned_this_turn
	attacks_used = 0
	actions_used = 0
	moves_used = 0
	last_action = &""

func snapshot(max_attacks: int = 1, actions_per_turn: int = 1) -> Dictionary:
	var attack_cap := maxi(1, max_attacks)
	var action_cap := maxi(1, actions_per_turn)
	return {
		"runtime_id": runtime_id,
		"owner_side": owner_side,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"summoned_this_turn": summoned_this_turn,
		"attacks_used": attacks_used,
		"has_attacked_this_turn": attacks_used >= attack_cap,
		"temporary_attack_bonus": temporary_attack_bonus,
		"actions_used": actions_used,
		"moves_used": moves_used,
		"last_action": last_action,
		"action_available": actions_used < action_cap,
		"board_cell": board_cell,
		"lane_index": board_cell.x if board_cell != INVALID_BOARD_CELL else -1,
		"facing_rank_delta": facing_rank_delta,
		"overdrive_breach_used_this_turn": overdrive_breach_used_this_turn,
		"temp_durability_bonus": get_temporary_max_hp_bonus(),
	}

func reset_turn(max_attacks: int, actions_per_turn: int = 1) -> void:
	attacks_used = 0
	actions_used = 0
	moves_used = 0
	last_action = &""
	summoned_this_turn = false
	temporary_attack_bonus = 0
	## Phase 27C: facing persists across turns; OD breach flag resets
	overdrive_breach_used_this_turn = false
	attacks_used = clampi(attacks_used, 0, maxi(1, max_attacks))


# ═══════════════════════════════════════════
# Phase 26C: 临时攻击加成（Surge 核心指令）
# ═══════════════════════════════════════════

func get_effective_attack(base_attack: int) -> int:
	return maxi(0, base_attack + temporary_attack_bonus)


func add_temporary_attack_bonus(amount: int) -> void:
	if amount > 0:
		temporary_attack_bonus += amount


func clear_temporary_attack_bonus() -> void:
	temporary_attack_bonus = 0

func apply_damage(amount: int) -> int:
	if encounter_damage_allowed.is_valid() and not encounter_damage_allowed.call():return 0
	var normalized := maxi(0, amount)
	var before := current_hp
	current_hp = maxi(0, current_hp - normalized)
	return before - current_hp

func heal(amount: int) -> int:
	var normalized := maxi(0, amount)
	var before := current_hp
	current_hp = mini(max_hp, current_hp + normalized)
	return current_hp - before

func modify_max_hp(delta: int, add_to_current: bool = true) -> void:
	var old_max := max_hp
	max_hp = maxi(1, max_hp + delta)
	if add_to_current and max_hp > old_max:
		current_hp += max_hp - old_max
	current_hp = clampi(current_hp, 0, max_hp)

func is_dead() -> bool:
	return current_hp <= 0


# ═══════════════════════════════════════════
# Phase 27I-R1: 来源追踪临时耐久（战车连接）
# 有效值 = 所有来源中的最大值（不求和）。经既有 modify_max_hp 原语应用，
# 不修改 CardData.unit_defense，不增加全局护盾，不产生每击减伤。
# ═══════════════════════════════════════════

var _temp_max_hp_sources: Dictionary = {}   # source_key(StringName) -> amount(int)

## 写入/刷新来源贡献。同来源刷新不重复增加；有效值只增不减语义见 set 内 delta。
func set_temporary_max_hp_bonus(source_key: StringName, amount: int) -> Dictionary:
	var old_effective := get_temporary_max_hp_bonus()
	_temp_max_hp_sources[source_key] = maxi(0, amount)
	var new_effective := get_temporary_max_hp_bonus()
	var delta := new_effective - old_effective
	if delta > 0:
		modify_max_hp(delta, true)
	elif delta < 0:
		modify_max_hp(delta, false)
	return {"ok": true, "effective": new_effective, "delta": delta}

## 移除单个来源。若该来源是当前有效最大值来源，则有效 max_hp 下降并 clamp current_hp；
## 若还有其他有效来源，不降低 max_hp。清除不存在来源幂等。清除本身不造成伤害/治疗。
func clear_temporary_max_hp_bonus(source_key: StringName) -> Dictionary:
	var old_effective := get_temporary_max_hp_bonus()
	if not _temp_max_hp_sources.has(source_key):
		return {"ok": true, "effective": old_effective, "delta": 0}
	_temp_max_hp_sources.erase(source_key)
	var new_effective := get_temporary_max_hp_bonus()
	var delta := new_effective - old_effective
	if delta < 0:
		modify_max_hp(delta, false)
	return {"ok": true, "effective": new_effective, "delta": delta}

## 清空全部来源并回落 max_hp。
func clear_all_temporary_max_hp_bonuses() -> Dictionary:
	var old_effective := get_temporary_max_hp_bonus()
	_temp_max_hp_sources.clear()
	if old_effective > 0:
		modify_max_hp(-old_effective, false)
	return {"ok": true, "effective": 0, "delta": -old_effective}

## 当前有效临时耐久值（所有来源最大值）。
func get_temporary_max_hp_bonus() -> int:
	var best := 0
	for amount in _temp_max_hp_sources.values():
		best = maxi(best, int(amount))
	return best

## 返回来源键 → 贡献副本（供 BattleSystem 双向追踪 / 审计）。
func get_temporary_max_hp_sources() -> Dictionary:
	return _temp_max_hp_sources.duplicate()


# ── Phase 27A: board cell ──

func set_board_cell(cell: Vector2i) -> void:
	board_cell = cell


func clear_board_cell() -> void:
	board_cell = INVALID_BOARD_CELL
	## Phase 27C: facing cleared on death/removal
	facing_rank_delta = 0
	overdrive_breach_used_this_turn = false


## Phase 27C: facing accessors — only -1 and +1 are valid runtime values
func set_facing_rank_delta(value: int) -> void:
	if value == -1 or value == 1:
		facing_rank_delta = value


func get_facing_rank_delta() -> int:
	return facing_rank_delta


# ── Phase 27D: local command modifiers ──

func get_command_cost_modifier() -> int:
	return _command_cost_modifier


func set_command_cost_modifier(delta: int) -> void:
	_command_cost_modifier = delta


func has_free_action() -> bool:
	return _has_free_action and not _free_action_consumed


func grant_free_action() -> void:
	_has_free_action = true
	_free_action_consumed = false


func consume_free_action() -> bool:
	if _has_free_action and not _free_action_consumed:
		_free_action_consumed = true
		_has_free_action = false
		return true
	return false


func reset_command_modifiers() -> void:
	_command_cost_modifier = 0
	_has_free_action = false
	_free_action_consumed = false


# ═══════════════════════════════════════
# Phase 27E: 技能运行时状态
# ═══════════════════════════════════════

var skill_stacks: Dictionary = {}      # { StringName(skill_id): int }
var skill_flags: Dictionary = {}       # { StringName(flag): Variant }

## 获取技能层数
func get_skill_stack(skill_id: StringName) -> int:
	return int(skill_stacks.get(skill_id, 0))

## 设置技能层数（钳制到 0..max_stacks）
func set_skill_stack(skill_id: StringName, value: int, max_stacks: int) -> void:
	skill_stacks[skill_id] = clampi(value, 0, max_stacks)

## 增加技能层数
func add_skill_stack(skill_id: StringName, delta: int, max_stacks: int) -> int:
	var cur: int = get_skill_stack(skill_id)
	var nxt: int = clampi(cur + delta, 0, max_stacks)
	skill_stacks[skill_id] = nxt
	return nxt

## 消耗全部层数并返回消耗前的值
func consume_all_skill_stacks(skill_id: StringName) -> int:
	var cur: int = get_skill_stack(skill_id)
	skill_stacks[skill_id] = 0
	return cur

## 清空所有技能状态（死亡/离场时）
func clear_skill_state() -> void:
	skill_stacks.clear()
	skill_flags.clear()

## 回合临时攻击加成：回合结束时由 BattleSystem 清除
func add_turn_attack_bonus(amount: int) -> void:
	temporary_attack_bonus += amount

func get_turn_attack_bonus() -> int:
	return temporary_attack_bonus

func clear_turn_attack_bonus() -> void:
	temporary_attack_bonus = 0

## 检查是否有主动技能配置
func has_skill_config(card_id: String) -> bool:
	return _skill_snapshot != null and _skill_snapshot.has_skill(card_id)

var _skill_snapshot: RefCounted = null

func set_skill_snapshot(snap: RefCounted) -> void:
	_skill_snapshot = snap

func get_skill_snapshot() -> RefCounted:
	return _skill_snapshot
