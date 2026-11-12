class_name PipelineContext
extends RefCounted

var card_data: CardData
var player: Player
var enemy: Enemy
var battle_context: BattleContext

var od_cost: int = 0
var repeat_count: int = 1
var is_cancelled: bool = false
var effect_contexts: Array[EffectContext] = []
var metadata: Dictionary = {}
