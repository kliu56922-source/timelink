extends "res://core/buff/buff.gd"

func _init() -> void:
	duration = 2

func on_card_played(context: BattleContext, card: CardData) -> void:
	print("[BUFF] DoubleTrigger: re-executing effects")
	for effect in card.effects:
		effect.execute(context)
