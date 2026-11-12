extends RefCounted
class_name Buff

var duration: int = -1

func on_card_played(_context: BattleContext, _card: CardData) -> void:
	pass

func on_turn_end(_context: BattleContext) -> void:
	if duration > 0:
		duration -= 1
		if duration == 0:
			_context.player.buffs.erase(self)
			print("[BUFF] %s expired" % get_class())
