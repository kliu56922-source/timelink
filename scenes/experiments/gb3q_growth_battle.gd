extends "res://scenes/experiments/gb3p_run_battle.gd"
const GrowthCfg=preload("res://core/run/run_growth_config.gd")
var growth_label: Label
var _opening_module_applied:=false
const Emergency=preload("res://core/run/boss_emergency.gd")
var emergency=Emergency.new()
var _pending_emergency_skills:=0
func configure_run(contract: Dictionary) -> Dictionary:
 if is_inside_tree():return {"ok":false,"reason_code":&"already_in_tree"}
 var errors: Array[String]=GrowthCfg.validate_contract(contract,BossLibrary.get_supported_card_ids())
 if not errors.is_empty():return {"ok":false,"reason_code":&"invalid_growth_contract","errors":errors}
 var normalized: Dictionary=contract.duplicate(true)
 normalized.deck_ids=RunConfig.STARTER.duplicate();normalized.deck_order=RunConfig.STARTER.duplicate()
 var result: Dictionary=super.configure_run(normalized)
 if result.ok:_run_contract=contract.duplicate(true)
 return result
func _gb1_prepare_startup() -> void:
 super._gb1_prepare_startup()
 if not _gb1_startup_ok:return
 for id in _run_contract.upgrades:
  var card: CardData=_gb1_cards_by_id[id]
  card.unit_power+=int(_run_contract.upgrades[id])
  card.display_name=card.get_display_name()+"〔改造〕"
 if "armor" in _run_contract.modules:_gb1_cards_by_id.S01.unit_defense+=2
 var apprentice: CardData=_gb1_cards_by_id.S01
 apprentice.description=apprentice.description.replace("普通棋子1/2：","普通棋子：")
 apprentice.description+="\n本次远征基础：%d攻 / %d血"%[apprentice.unit_power,apprentice.unit_defense]
func _get_card_status(card: CardData) -> Dictionary:
 var status: Dictionary=super._get_card_status(card)
 # This adapter owns growth instances; keep legacy trial summaries unchanged.
 if card!=null and status.get("hand_facts") is Dictionary:
  if card.card_id=="S01":
   status.hand_facts.summary="登场：%d攻 / %d血\n有建筑时找蒸汽中转"%[card.unit_power,card.unit_defense]
  elif card.card_id=="P02" and _run_contract.get("upgrades",{}).has("P02"):
   status.hand_facts.summary="登场：找炉心建筑\n%d攻 / %d血 · 已改造"%[card.unit_power,card.unit_defense]
 return status
func _setup_game() -> void:
 super._setup_game()
 if "warm" in _run_contract.modules:context.od_mode.add_heat(2,&"run_module_warm")
 emergency.setup(_run_contract.token,context.are_boss_phase_locks_enabled())
func _refresh_tables() -> void:
 # Original startup draws six once. Extend that draw before rebuilding its hand UI.
 if not _opening_module_applied and context!=null and context.player!=null and context.player.hand.size()==6:
  _opening_module_applied=true
  if "draw" in _run_contract.get("modules",[]):context.player.draw(1)
 super._refresh_tables()
func _ready() -> void:
 await super._ready()
 if not _gb1_startup_ok:return
 growth_label=Label.new();growth_label.name="RunGrowthSummary";growth_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;growth_label.custom_minimum_size.x=220
 var modules: Array[String]=[]
 var names={"warm":"预热飞轮","armor":"学徒护套","draw":"补给匣"}
 for id in _run_contract.modules:modules.append(names[id])
 growth_label.text="本次构筑：%d张 · 改造%d张
模组：%s"%[_run_contract.deck_ids.size(),_run_contract.upgrades.size(),"、".join(modules) if not modules.is_empty() else "无"]
 growth_label.add_theme_font_size_override("font_size",12)
 var body=get_node("GB1HelpLayer/GB1HelpPanel/Body")
 body.add_child(growth_label)

func poll_emergency() -> Dictionary:
 if context==null or battle==null or run_startup_pending:
  var waiting: Dictionary=emergency.snapshot();waiting.safe=false;return waiting
 var alive: bool=not battle_ended and not _run_completed and context.player.hp>0 and context.enemy.hp>0
 var safe: bool=alive and _emergency_is_safe()
 emergency.observe(int(context.enemy.combat_phase),safe,alive)
 var result: Dictionary=emergency.snapshot();result.safe=safe;return result
func _emergency_is_safe() -> bool:
 var safe: bool=bool(battle.get_command_economy_snapshot("player").get("turn_open",false)) and not _has_non_presentation_end_turn_busy() and not _is_monster_summon_interaction_active() and not battle._siege_command_in_progress and _pending_emergency_skills==0
 if _battle_presentation_director!=null and (_battle_presentation_director.is_busy() or int(_battle_presentation_director.get_cleanup_snapshot().queue_count)>0):safe=false
 if battle.reaction_trial!=null and (battle.reaction_trial.waiting or not battle.reaction_trial.event.is_empty()):safe=false
 return safe
func _emergency_facts() -> Dictionary:
 return {"hp":context.player.hp,"depth":context.depth_pressure,"shield":context.player.shield}
func preview_emergency(token: Variant,id: Variant) -> Dictionary:
 if not _emergency_can_commit():return {"ok":false}
 return emergency.preview(token,id,_emergency_facts())
func _emergency_can_commit() -> bool:
 return context!=null and not battle_ended and not _run_completed and context.player.hp>0 and context.enemy.hp>0 and emergency.snapshot().state=="open" and _emergency_is_safe()
func commit_emergency(token: Variant,id: Variant) -> Dictionary:
 if not _emergency_can_commit():return {"ok":false}
 var result: Dictionary=emergency.take(token,id,_emergency_facts())
 if not result.ok:return result
 context.player.hp=int(result.hp_after)
 context.player.shield=int(result.shield_after)
 if id=="vent":context.modify_depth(int(result.depth_after)-context.depth_pressure,"Boss阶段应急")
 _refresh_tables();_update_avatar_huds();_refresh_command_economy_hud()
 return result
func _input(event: InputEvent) -> void:
 if run_input_enabled:
  var q: Dictionary=poll_emergency()
  var player_pending: bool=q.state=="pending" and bool(battle.get_command_economy_snapshot("player").get("turn_open",false)) and (battle.reaction_trial==null or (not battle.reaction_trial.waiting and battle.reaction_trial.event.is_empty()))
  if q.state=="open" or player_pending:get_viewport().set_input_as_handled();return
 super._input(event)
func _on_end_turn() -> void:
 if poll_emergency().state in ["pending","open"]:return
 super._on_end_turn()
func prepare_run_release() -> void:
 emergency.close();super.prepare_run_release()

func _execute_skill_command(card: CardData,skill_id: StringName,target) -> bool:
 # Parent schedules a deferred coroutine after its synchronous damage/payment.
 _pending_emergency_skills+=1
 var accepted: bool=super._execute_skill_command(card,skill_id,target)
 if not accepted:_pending_emergency_skills=maxi(0,_pending_emergency_skills-1)
 return accepted
func _present_committed_skill(facts: Dictionary) -> void:
 if not _run_completed and not battle_ended:await super._present_committed_skill(facts)
 _pending_emergency_skills=maxi(0,_pending_emergency_skills-1)
