extends "res://core/battle/card_execution_battle_167c.gd"
## Private quiet encounter policy. Player queries/commands remain inherited.
var _wait168a: CardData
signal player_card_committed168a(card: CardData, receipt: Dictionary)
func play_card(card: CardData,requested_lane: int=-1,requested_cell: Vector2i=INVALID_GRID_CELL,cast_options: Dictionary={}) -> Dictionary:
 var receipt: Dictionary=super.play_card(card,requested_lane,requested_cell,cast_options)
 # Native structure creation during a root is material placement, not an
 # additional single-card activation or separately paid effect.
 if receipt.get("ok",false) and not _recipe166_committing and receipt.get("source_kind",&"")!=&"recipe166_material":player_card_committed168a.emit(card,receipt.duplicate(true))
 return receipt
func init(ctx: BattleContext) -> void:
 super.init(ctx)
 ctx.enemy.opening_intent_provider=training_intent168a
func training_intent168a() -> CardData:
 if not is_instance_valid(_wait168a):
  _wait168a=CardData.new();add_child(_wait168a)
  _wait168a.card_id="TRAIN168_WAIT";_wait168a.card_name="Training Wait";_wait168a.display_name="木桩待机"
  _wait168a.short_description="仅推进正常回合；不攻击、不设伏、不增加护盾。"
  _wait168a.board_zone=CardData.BoardZone.INSTANT
 return _wait168a
func boss_play_card(card: CardData) -> void:
 if card!=_wait168a:return
 if preparation_active166b():opening166b.commit_boss_preparation()
 context.boss_action_event.emit("training_wait","木桩待机","训练条件：无主动攻击；玩家费用与回合规则保留")
func get_boss_tactical_action_candidates() -> Array[Dictionary]:return []
func execute_boss_tactical_candidate(_candidate: Dictionary) -> Dictionary:return {"ok":false,"reason_code":&"training_quiet"}
func _on_boss_siege_tactical_start() -> Dictionary:return {"ok":false,"reason_code":&"training_quiet"}
func resolve_boss_siege_intent() -> Dictionary:return {"ok":false,"reason_code":&"training_quiet"}
func _on_boss_terrain_tactical_start() -> Dictionary:return {"ok":false,"reason_code":&"training_quiet"}
