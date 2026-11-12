class_name EffectContext
extends RefCounted

# ADR-0007: 目标方向枚举
enum TargetType {
	TARGET_ENEMY = 0,   # 目标为敌方（玩家卡默认）
	TARGET_PLAYER = 1,  # 目标为玩家（Boss 卡默认）
}

var player: Player
var enemy: Enemy
var battle_context: BattleContext
var source_card: CardData
var field_system: FieldSystem
## Phase 24B: Authoritative draw resolver (set by BattleSystem)
var battle_system: BattleSystem
## Phase 27K-R1-A: source-only metadata. Defaults preserve independent legacy
## EffectContext construction and never alter effect values.
var heat_transaction_id: StringName = &""
var effect_index: int = -1
var effect_repeat_index: int = 0
var heat_source_descriptor: Dictionary = {}

var target_type: int = TargetType.TARGET_ENEMY  # ADR-0007: 默认目标=敌方（向后兼容）

var base_value: int = 0
var final_value: int = 0
var is_cancelled: bool = false
var tags: Array[String] = []

## Only the current validated P18 cast; never retained by BattleSystem.
var siege_cast_plan: Dictionary = {}

## Only the current validated P22 cast; no retained target or state authority.
var structure_repair_plan: Dictionary = {}

## Only the current validated P23 cast.
var terrain_raise_plan: Dictionary = {}
