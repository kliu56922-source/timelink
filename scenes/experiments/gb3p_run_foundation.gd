extends Control
## Owns one data session and one disposable battle. No persistent save changes.
const RunConfig = preload("res://core/run/run_foundation_config.gd")
const Session = preload("res://core/run/run_session.gd")
const BossLibrary = preload("res://core/deck/boss_card_library.gd")
const GameCfg = preload("res://core/config/game_config.gd")
const BATTLE_ENTRY := "res://scenes/experiments/gb3p_run_battle.tscn"
var session: RefCounted=Session.new()
var active_battle: Control
var generation := 0
var page := "prepare"
var seed_edit: LineEdit
var body_label: Label
var title_label: Label
var start_button: Button
var continue_button: Button
var reload_button: Button
var same_button: Button
var new_button: Button
var back_button: Button
var panel_root: Control
var _config: Dictionary={}
var _config_errors: Array[String]=[]
var _transitioning := false
var _pending_navigation := ""
var _load_error := ""
var _focused_page := ""
var _starts: Array[Dictionary]=[]
func _ready() -> void:
 _read_config();_build_page();_refresh_page()
func _new_run_session() -> RefCounted:
 return Session.new()
func _read_config() -> void:
 var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/experiments/roguelike_run_foundation.json"))
 _config_errors=RunConfig.validate(raw,RunConfig.STARTER,BossLibrary.get_supported_card_ids())
 if _config_errors.is_empty():_config=RunConfig.resolve(raw,GameCfg.get_encounter("forge_guard_demo"))
func _parse_seed() -> Dictionary:
 var value: String=seed_edit.text
 if value.is_empty() or not value.is_valid_int():return {"ok":false}
 for code in value.to_utf8_buffer():
  if code<48 or code>57:return {"ok":false}
 if value.length()>10 or value.to_int()>2147483646:return {"ok":false}
 return {"ok":true,"seed":value.to_int()}
func start_run(seed_value: Variant) -> Dictionary:
 if _transitioning or page!="prepare":return {"ok":false,"reason_code":&"busy"}
 if not _config_errors.is_empty():return {"ok":false,"reason_code":&"invalid_config"}
 var next=_new_run_session()
 var configured: Dictionary=next.configure(_config)
 if not configured.ok:return configured
 var begun: Dictionary=next.begin(seed_value,generation+1)
 if not begun.ok:return begun
 generation+=1;session=next;_starts.clear();seed_edit.text=str(seed_value);_load_error=""
 _transitioning=true;page="loading";_refresh_page();call_deferred("_load_battle")
 return {"ok":true}
func get_run_snapshot() -> Dictionary:
 return session.snapshot()
func get_start_facts() -> Array[Dictionary]:
 return _starts.duplicate(true)
func continue_run() -> Dictionary:
 if _transitioning:return {"ok":false,"reason_code":&"busy"}
 var result: Dictionary=session.advance_encounter()
 if not result.ok:return result
 _transitioning=true;page="loading";_load_error="";_refresh_page();call_deferred("_load_battle")
 return result
func reload_encounter() -> void:
 if _transitioning or session.snapshot().state!="ready":return
 _transitioning=true;page="loading";_load_error="";_refresh_page();call_deferred("_load_battle")
func _release_battle() -> void:
 if not is_instance_valid(active_battle):active_battle=null;return
 var old=active_battle
 old.set_run_input(false)
 # Parent startup contains awaits. Let it finish before releasing its owner.
 if old.run_startup_pending:await old.run_startup_finished
 old.prepare_run_release()
 # Frame waits resume while their owner is valid; battle_ended blocks commits.
 await get_tree().process_frame
 active_battle=null
 old.queue_free()
 await old.tree_exited
 await get_tree().process_frame
func _get_run_battle_scene() -> PackedScene:
 return load(BATTLE_ENTRY) as PackedScene
func _load_battle() -> void:
 await _release_battle()
 if not _pending_navigation.is_empty():_transitioning=false;_complete_navigation();return
 var prepared: Dictionary=session.prepare_encounter()
 if not prepared.ok:_loading_failed("会话拒绝加载："+str(prepared.reason_code));return
 var packed=_get_run_battle_scene()
 if packed==null:session.cancel_loading(prepared.token);_loading_failed("战斗入口无法加载");return
 var child=packed.instantiate()
 var checked: Dictionary=child.configure_run(prepared.contract)
 if not checked.ok:
  child.free();session.cancel_loading(prepared.token);_loading_failed("合同预检失败："+str(checked.get("errors",[])));return
 child.run_host=weakref(self)
 child.encounter_started.connect(_on_encounter_started)
 child.encounter_completed.connect(_on_encounter_completed)
 child.startup_failed.connect(_on_startup_failed)
 active_battle=child
 $BattleHost.add_child(child)
func _on_encounter_started(token: String, fact: Dictionary) -> void:
 var accepted: Dictionary=session.mark_started(token)
 if not accepted.ok:return
 _starts.append(fact.duplicate(true));_transitioning=false;page="fighting"
 if not _pending_navigation.is_empty():_complete_navigation();return
 active_battle.set_run_input(true);_refresh_page()
func _on_startup_failed(token: String, reason: String) -> void:
 if not session.cancel_loading(token).ok:return
 _loading_failed(reason)
func _loading_failed(reason: String) -> void:
 _load_error=reason;_transitioning=false;page="load_failed";_refresh_page()
 if not _pending_navigation.is_empty():_complete_navigation()
func _on_encounter_completed(token: String, result: Dictionary) -> void:
 # Return from all damage/scene handlers before changing visible result pages.
 call_deferred("_accept_result",token,result.duplicate(true))
func _accept_result(token: String, result: Dictionary) -> void:
 var accepted: Dictionary=session.finish_encounter(token,bool(result.get("victory",false)),int(result.get("raw_hp",0)),int(result.get("turns",0)))
 if not accepted.ok:return
 if is_instance_valid(active_battle):
  active_battle.set_run_input(false)
  var old_panel=active_battle.get_node_or_null("BattleResultLayer")
  if old_panel!=null:old_panel.queue_free()
 page=session.snapshot().state;_refresh_page()
func retry_run(same_seed: bool) -> void:
 _pending_navigation="retry_same" if same_seed else "retry_new"
 if _transitioning:return
 _complete_navigation()
func return_to_menu() -> void:
 _pending_navigation="menu"
 if _transitioning:return
 _complete_navigation()
func _complete_navigation() -> void:
 if _transitioning:return
 _transitioning=true
 var destination := _pending_navigation;_pending_navigation=""
 var old_seed: int=session.snapshot().run_seed
 session.abandon();page="loading";_refresh_page()
 await _release_battle()
 session=_new_run_session();_starts.clear();_load_error=""
 _transitioning=false
 if destination=="menu":
  get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn");return
 page="prepare"
 if destination=="retry_same":seed_edit.text=str(old_seed)
 else:
  var rng:=RandomNumberGenerator.new();rng.randomize()
  var new_seed:=rng.randi_range(0,2147483646)
  if new_seed==old_seed:new_seed=(new_seed+1)%2147483647
  seed_edit.text=str(new_seed)
 _refresh_page()
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel") and page!="fighting" and not _transitioning:
  if page=="prepare":return_to_menu()
  else:retry_run(true)
  get_viewport().set_input_as_handled()
func _make_button(box: VBoxContainer, name_value: String, text_value: String, action: Callable) -> Button:
 var button:=Button.new();button.name=name_value;button.text=text_value;button.custom_minimum_size.y=42
 button.pressed.connect(action);box.add_child(button);return button
func _build_page() -> void:
 var layer:=CanvasLayer.new();layer.name="RunPageLayer";layer.layer=2000;add_child(layer)
 panel_root=ColorRect.new();panel_root.name="RunPage";panel_root.color=Color(0.055,0.065,0.08);panel_root.mouse_filter=Control.MOUSE_FILTER_STOP
 panel_root.focus_mode=Control.FOCUS_ALL
 layer.add_child(panel_root);panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
 panel_root.add_child(margin)
 var center:=CenterContainer.new();margin.add_child(center)
 var box:=VBoxContainer.new();box.name="Actions";box.custom_minimum_size.x=580;box.add_theme_constant_override("separation",10);center.add_child(box)
 title_label=Label.new();title_label.add_theme_font_size_override("font_size",28);box.add_child(title_label)
 body_label=Label.new();body_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(body_label)
 seed_edit=LineEdit.new();seed_edit.name="Seed";seed_edit.text="20261008";seed_edit.placeholder_text="数字种子 0–2147483646";box.add_child(seed_edit)
 seed_edit.text_changed.connect(func(_text):_refresh_page())
 seed_edit.text_submitted.connect(func(_text):_start_from_ui())
 start_button=_make_button(box,"Start","开始远征",_start_from_ui)
 continue_button=_make_button(box,"Continue","领取补给并继续",func():continue_run())
 reload_button=_make_button(box,"Reload","重新加载本场",reload_encounter)
 same_button=_make_button(box,"RetrySame","同种子重试（从第一场开始）",func():retry_run(true))
 new_button=_make_button(box,"RetryNew","新远征",func():retry_run(false))
 back_button=_make_button(box,"Return","放弃并返回主菜单",return_to_menu)
func _start_from_ui() -> void:
 var parsed:=_parse_seed()
 if parsed.ok:start_run(parsed.seed)
func _refresh_page() -> void:
 if panel_root==null:return
 panel_root.visible=page!="fighting"
 var snap: Dictionary=session.snapshot()
 start_button.visible=page=="prepare"
 continue_button.visible=page=="between"
 reload_button.visible=page=="load_failed"
 same_button.visible=page in ["won","lost"]
 new_button.visible=page in ["won","lost"]
 back_button.visible=page in ["prepare","load_failed","between","won","lost"]
 seed_edit.visible=page=="prepare"
 if page=="prepare":
  title_label.text="短远征 · 连战试制"
  body_label.text="工程混轴 · 19张卡牌\n核心生命35 · 前六张固定，后续牌序随种子变化\n边境守卫 → 炉区巡卫 → 熔炉守卫\n每场重建棋盘；生命继承，前两场各补给6。\n选择卡牌可查看关联；教学试玩仍在原入口。"
  if not _config_errors.is_empty():body_label.text+="\n配置错误："+"；".join(_config_errors)
  start_button.visible=true;start_button.disabled=not _parse_seed().ok or not _config_errors.is_empty();back_button.visible=true
 elif page=="loading":
  title_label.text="正在准备战斗";body_label.text="释放上一场，核对本场牌组与遭遇……"
 elif page=="load_failed":
  title_label.text="本场加载失败";body_label.text=_load_error+"\n生命与已领取补给保持，不会重复恢复。";reload_button.visible=true;back_button.visible=true
 elif page=="between":
  var last: Dictionary=snap.results[-1]
  title_label.text="第%d场完成 · %s"%[snap.encounter_index+1,last.display_name]
  var healed: int=snap.core_hp+mini(6,maxi(0,35-snap.core_hp))
  body_label.text="本场%d回合 · 当前核心生命%d\n继续时补给：%d → %d\n下一场：%s"%[last.turns,snap.core_hp,snap.core_hp,healed,_config.encounters[snap.encounter_index+1].display_name]
  continue_button.visible=true;back_button.visible=true
 elif page in ["won","lost"]:
  title_label.text="远征成功" if page=="won" else "远征结束 · 核心失守"
  var turns:=0;var lines: Array[String]=[]
  for row in snap.results:
   turns+=row.turns;lines.append("%s：%d回合 · 核心%d → %d · %s"%[row.display_name,row.turns,row.initial_hp,maxi(0,row.raw_hp),"胜利" if row.victory else "失利"])
  body_label.text="核心生命%d · 合计%d回合\n%s\n种子%d"%[snap.core_hp,turns,"\n".join(lines),snap.run_seed]
  same_button.visible=true;new_button.visible=true;back_button.visible=true

 # Only a page transition transfers keyboard ownership. Text edits keep focus.
 if page!=_focused_page:
  _focused_page=page
  var focus_target: Control=panel_root
  match page:
   "prepare":focus_target=seed_edit
   "between":focus_target=continue_button
   "load_failed":focus_target=reload_button
   "won","lost":focus_target=same_button
  if page=="fighting":
   var owner=get_viewport().gui_get_focus_owner()
   if owner!=null and (owner==panel_root or panel_root.is_ancestor_of(owner)):owner.release_focus()
  else:focus_target.grab_focus()
