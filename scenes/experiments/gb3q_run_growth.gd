extends "res://scenes/experiments/gb3p_run_foundation.gd"
const GrowthSession=preload("res://core/run/run_meta_session.gd")
const ProgressStore=preload("res://core/run/run_progress_store.gd")
const GrowthConfig=preload("res://core/run/run_growth_config.gd")
var progress_path:="user://roguelike_progress.json"
var progress_store=ProgressStore.new()
var _progress: Dictionary={"schema":1,"unlocks":[],"checkpoint":null}
var _progress_error:=""
var _progress_message:=""
var _progress_message_key:=""
var _progress_recovered:=false
var _profile:="base"
var profile_picker: OptionButton
var resume_button: Button
var save_button: Button
var record_button: Button
var choice_box: VBoxContainer
var choice_buttons: Array[Button]=[]
var confirm_button: Button
var skip_button: Button
var _selection := ""
var _selection_token := ""
var _growth_focus := ""
var _emergency_process_mode: int=Node.PROCESS_MODE_INHERIT
var _emergency_input_before:=false
func _ready() -> void:
 session=_new_run_session();super._ready()
 progress_store.path=progress_path;_reload_progress();_refresh_page()
func _new_run_session() -> RefCounted:
 var value=GrowthSession.new();value.set_profile(_profile);return value
func _read_config() -> void:
 super._read_config()
 var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/experiments/roguelike_run_growth.json"))
 _config_errors.append_array(GrowthConfig.validate(raw))
 if _config_errors.is_empty():_config.growth=raw.duplicate(true)
func _get_run_battle_scene() -> PackedScene:return load("res://scenes/experiments/gb3q_growth_battle.tscn") as PackedScene
func _build_page() -> void:
 super._build_page()
 var box: VBoxContainer=start_button.get_parent()
 choice_box=VBoxContainer.new();choice_box.name="GrowthChoices";choice_box.add_theme_constant_override("separation",8);box.add_child(choice_box);box.move_child(choice_box,seed_edit.get_index())
 for i in range(3):
  var button:=_make_button(choice_box,"Choice"+str(i),"",_inspect_slot.bind(i));choice_buttons.append(button)
 confirm_button=_make_button(choice_box,"ConfirmGrowth","请先选择",confirm_choice)
 skip_button=_make_button(choice_box,"SkipGrowth","跳过",func():inspect_choice("skip"))
func _inspect_slot(index: int) -> void:
 if page=="emergency":
  var offers: Array=active_battle.emergency.snapshot().offers
  if index>=0 and index<offers.size():inspect_choice(str(offers[index].id))
  return
 var offers: Array=session.snapshot().growth.offers
 if index>=0 and index<offers.size():inspect_choice(str(offers[index].id))
func inspect_choice(id: String) -> void:
 if _transitioning:return
 if page=="emergency":
  var token: String=active_battle.emergency.snapshot().token
  if active_battle.preview_emergency(token,id).get("ok",false):_selection=id;_selection_token=token;_refresh_page()
  return
 var snapshot: Dictionary=session.snapshot()
 var result: Dictionary=session.preview_choice(snapshot.growth.token,id)
 if not result.ok:return
 _selection=id;_selection_token=snapshot.growth.token;_refresh_page()
func confirm_choice() -> void:
 if _transitioning or _selection.is_empty():return
 if page=="emergency":
  var result: Dictionary=active_battle.commit_emergency(_selection_token,_selection)
  if result.ok:
   _selection="";_selection_token="";page="fighting"
   active_battle.process_mode=_emergency_process_mode;active_battle.set_run_input(_emergency_input_before);_refresh_page()
  return
 var result: Dictionary=session.commit_choice(_selection_token,_selection)
 if not result.ok:return
 _selection="";_selection_token="";_refresh_page()
func _refresh_page() -> void:
 _refresh_growth_page();_refresh_meta_page()
func _refresh_growth_page() -> void:
 super._refresh_page()
 if choice_box==null:return
 if page=="emergency":_refresh_emergency_page();return
 _clear_emergency_focus()
 var snap: Dictionary=session.snapshot()
 var growth: Dictionary=snap.growth
 var choosing: bool=page=="between" and growth.stage in ["card","camp","module"]
 choice_box.visible=choosing
 if page=="prepare":
  title_label.text="成长远征 · 构筑试制"
  body_label.text="工程混轴19张 · 两场遭遇 → 完整Boss
胜利后：选牌或跳过 → 营地取舍 → 模组 → 继续。
查看不会领取，选择后再确认；继续时仍补给最多6。
初始起手六张保护；新增卡可能稀释后续抽牌。
本次构筑失败/重试清空；战后手动保存可续玩。
保存覆盖一个旧节点，关闭前未保存的进度会丢失。"
  if not _config_errors.is_empty():body_label.text+="
配置错误："+"；".join(_config_errors)
 if not choosing:
  # Growth stages share base page=between; hand keyboard ownership back once.
  if page=="between" and growth.stage=="done" and not _growth_focus.is_empty():continue_button.grab_focus()
  _selection="";_selection_token="";_growth_focus=""
  if page in ["between","won","lost"]:body_label.text+="
本次构筑：%d张 · 改造%d张 · 模组%d枚"%[growth.deck_ids.size(),growth.upgrades.size(),growth.modules.size()]
  return
 continue_button.visible=false;back_button.visible=true
 if _selection_token!=growth.token:_selection="";_selection_token=""
 var titles={"card":"战后选牌 · 选一张或跳过","camp":"营地 · 恢复与改造二选一","module":"模组 · 本远征跨场生效"}
 title_label.text=titles[growth.stage]
 body_label.text="核心%d/35 · 牌组%d张 · 改造%d张 · 模组%d枚
"%[snap.core_hp,growth.deck_ids.size(),growth.upgrades.size(),growth.modules.size()]
 if _selection.is_empty():body_label.text+="点选查看说明，确认后才领取；也可跳过。"
 else:
  var preview: Dictionary=session.preview_choice(_selection_token,_selection)
  if preview.ok:
   body_label.text+=preview.name+"："+preview.description
   if growth.stage=="card" and _selection!="skip":body_label.text+="
与持有%s关联；牌组%d → %d，前六起手不变。"%[preview.related_name,preview.deck_before,preview.deck_after]
   if growth.stage=="camp":body_label.text+="
生命%d → %d；继续时另有最多6补给。"%[preview.hp_before,preview.hp_after]
 for i in range(choice_buttons.size()):
  var button: Button=choice_buttons[i];button.visible=i<growth.offers.size()
  if button.visible:button.text=("已选：" if _selection==growth.offers[i].id else "查看：")+str(growth.offers[i].name)+(str(" · "+growth.offers[i].role) if growth.stage=="card" else "")
 confirm_button.disabled=_selection.is_empty();confirm_button.text="确认跳过" if _selection=="skip" else ("确认领取" if not _selection.is_empty() else "请先选择")
 skip_button.text="离开营地" if growth.stage=="camp" else "跳过本项"
 if _growth_focus!=growth.token:
  _growth_focus=growth.token
  if not growth.offers.is_empty():choice_buttons[0].grab_focus()
  else:skip_button.grab_focus()
 if growth.stage=="module" and growth.modules.size()>=2:body_label.text+="\n模组已达上限2；本项请选择跳过，已有模组保持。"

func _process(_delta: float) -> void:_poll_emergency()
func _poll_emergency() -> void:
 if page!="fighting" or _transitioning or not is_instance_valid(active_battle):return
 var status: Dictionary=active_battle.poll_emergency()
 if status.state!="open" or not status.get("safe",false):return
 _emergency_process_mode=active_battle.process_mode;_emergency_input_before=active_battle.run_input_enabled
 active_battle.set_run_input(false);active_battle.process_mode=Node.PROCESS_MODE_DISABLED
 _selection="";_selection_token="";page="emergency";_refresh_page();choice_buttons[0].grab_focus()
func cancel_emergency_preview() -> void:
 if page!="emergency":return
 _selection="";_selection_token="";_refresh_page();choice_buttons[0].grab_focus()
func _unhandled_key_input(event: InputEvent) -> void:
 if page=="emergency" and event.is_action_pressed("ui_cancel"):
  cancel_emergency_preview();get_viewport().set_input_as_handled();return
 super._unhandled_key_input(event)
func _refresh_emergency_page() -> void:
 choice_box.visible=true;back_button.visible=true
 title_label.text="Boss阶段应急 · 本战仅一次"
 body_label.text="当前行动与换阶段已结算；选择后确认，或明确跳过。\n保留当前棋盘、指令与Boss阶段；Esc只取消预览。"
 var status: Dictionary=active_battle.emergency.snapshot()
 for i in range(choice_buttons.size()):
  choice_buttons[i].visible=i<status.offers.size()
  if choice_buttons[i].visible:choice_buttons[i].text=("已选：" if _selection==status.offers[i].id else "查看：")+status.offers[i].name
 confirm_button.disabled=_selection.is_empty();confirm_button.text="确认跳过" if _selection=="skip" else ("确认应急" if not _selection.is_empty() else "请先选择")
 skip_button.text="跳过本战应急"
 if not _selection.is_empty():
  var p: Dictionary=active_battle.preview_emergency(_selection_token,_selection)
  if p.get("ok",false):body_label.text+="\n%s：%s\n核心%d → %d · Depth %d → %d · 护盾%d → %d"%[p.name,p.description,p.hp_before,p.hp_after,p.depth_before,p.depth_after,p.shield_before,p.shield_after]
 var controls: Array[Control]=[]
 for button in choice_buttons:
  if button.visible:controls.append(button)
 if not confirm_button.disabled:controls.append(confirm_button)
 controls.append(skip_button);controls.append(back_button)
 for i in range(controls.size()):
  controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()]);controls[i].focus_previous=controls[i].get_path_to(controls[(i-1+controls.size())%controls.size()])

func _clear_emergency_focus() -> void:
 for button in choice_buttons:button.focus_next=NodePath("");button.focus_previous=NodePath("")
 for button in [confirm_button,skip_button,back_button]:button.focus_next=NodePath("");button.focus_previous=NodePath("")
 var controls: Array[Control]=[]
 if page=="prepare":controls=[seed_edit,start_button,back_button]
 elif page in ["won","lost"]:controls=[same_button,new_button,back_button]
 for i in range(controls.size()):
  controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()]);controls[i].focus_previous=controls[i].get_path_to(controls[(i-1+controls.size())%controls.size()])

# Explicit persistence owns no battle transactions and performs no automatic writes.
func _reload_progress() -> void:
 var result: Dictionary=progress_store.read(_config)
 _progress_error="" if result.ok else str(result.reason_code)
 if result.ok:_progress=result.data;_progress_recovered=result.get("recovered",false)
func select_profile(id: String) -> Dictionary:
 if _transitioning or page!="prepare" or id not in GrowthSession.PROFILES or (id!="base" and id not in _progress.unlocks):return {"ok":false,"reason_code":&"locked_or_busy"}
 _profile=id;_progress_message="";_refresh_page();return {"ok":true}
func start_run(seed_value: Variant) -> Dictionary:
 if _profile!="base" and _profile not in _progress.unlocks:return {"ok":false,"reason_code":&"locked_profile"}
 _progress_message="";return super.start_run(seed_value)
func save_node() -> Dictionary:
 if _transitioning or page!="between":return {"ok":false,"reason_code":&"unsafe_node"}
 var result: Dictionary=progress_store.record(_config,session,true)
 _progress_message="本节点已保存；解锁已记录，可返回后从准备页续玩。" if result.ok else "保存失败，旧文件保留："+str(result.reason_code)
 _progress_message_key=_node_key(session.export_checkpoint().checkpoint) if result.ok else ""
 _reload_progress();_refresh_page();return result
func record_terminal() -> Dictionary:
 if _transitioning or page not in ["won","lost"]:return {"ok":false,"reason_code":&"not_terminal"}
 _progress_message_key=""
 var result: Dictionary=progress_store.record(_config,session,false)
 _progress_message="结算与解锁已记录；旧续玩节点已清除。" if result.ok else "记录失败，旧文件保留："+str(result.reason_code)
 _reload_progress();_refresh_page();return result
func resume_saved() -> Dictionary:
 if _transitioning or page!="prepare":return {"ok":false,"reason_code":&"busy"}
 _reload_progress()
 if not _progress_error.is_empty() or _progress.checkpoint==null:return {"ok":false,"reason_code":&"no_valid_checkpoint"}
 var node: Dictionary=_progress.checkpoint
 var next_generation: int=maxi(generation,int(node.generation))+1
 var result: Dictionary=GrowthSession.restore_checkpoint(_config,node,next_generation)
 if not result.ok:return result
 session=result.session;_progress_message_key=_node_key(session.export_checkpoint().checkpoint);generation=next_generation;_profile=node.profile;seed_edit.text=str(node.seed);_starts.clear();_load_error="";_selection="";_selection_token="";_progress_message="已恢复保存节点；已领取成长与补给不会重复。";page="between";_refresh_page();return {"ok":true}
func _build_progress_controls() -> void:
 var box: VBoxContainer=start_button.get_parent()
 profile_picker=OptionButton.new();profile_picker.name="StartingProfile";profile_picker.custom_minimum_size.y=42;box.add_child(profile_picker);box.move_child(profile_picker,seed_edit.get_index())
 for label in ["基础开局 · 35生命 / 无预装模组","护套开局 · 30生命 / 学徒耐久+2","预热开局 · 30生命 / 每场初始热量2"]:profile_picker.add_item(label)
 profile_picker.item_selected.connect(func(index):select_profile(GrowthSession.PROFILES[index]))
 resume_button=_make_button(box,"ResumeSaved","继续已保存远征",resume_saved);box.move_child(resume_button,start_button.get_index()+1)
 save_button=_make_button(box,"SaveNode","保存本节点与解锁（覆盖旧节点）",save_node);box.move_child(save_button,back_button.get_index())
 record_button=_make_button(box,"RecordTerminal","记录结算与解锁（清除续玩节点）",record_terminal);box.move_child(record_button,back_button.get_index())
func _node_key(node: Dictionary) -> String:
 var data: Dictionary=node.duplicate(true);data.erase("generation");return JSON.stringify(data,"",true).sha256_text()
func _refresh_meta_page() -> void:
 if choice_box==null:return
 if profile_picker==null:_build_progress_controls()
 var current_node: Dictionary=session.export_checkpoint()
 if not _progress_message_key.is_empty() and (not current_node.ok or _node_key(current_node.checkpoint)!=_progress_message_key):_progress_message="";_progress_message_key=""
 profile_picker.visible=page=="prepare";resume_button.visible=page=="prepare"
 save_button.visible=page=="between" and session.snapshot().growth.stage in ["card","done"]
 record_button.visible=page in ["won","lost"]
 resume_button.disabled=_progress.checkpoint==null or not _progress_error.is_empty()
 save_button.disabled=not _progress_error.is_empty();record_button.disabled=save_button.disabled
 for i in range(3):
  var id: String=GrowthSession.PROFILES[i];profile_picker.set_item_disabled(i,id!="base" and id not in _progress.unlocks)
 profile_picker.select(GrowthSession.PROFILES.find(_profile))
 if page=="prepare":
  body_label.text+="\n护套：记录首战胜利解锁；预热：记录精英胜利解锁。\n预装模组占两枚总上限；基础开局始终可选。"
  if _progress.checkpoint!=null:body_label.text+="\n已存第%d战后%s；开始新局不会自动覆盖。"%[_progress.checkpoint.results.size(),"选牌前" if _progress.checkpoint.stage=="card" else "成长完成"]
 if page!="fighting" and page!="emergency":
  if _progress_recovered:body_label.text+="\n主存档缺失，已校验恢复副本；可以续玩或重新保存。"
  if save_button.visible and current_node.ok and (_progress.checkpoint==null or _node_key(current_node.checkpoint)!=_node_key(_progress.checkpoint)):body_label.text+="\n当前节点尚未保存；点击保存才记录这一进度。"
  if not _progress_error.is_empty():body_label.text+="\n成长存档不可用，原文件保留，可玩基础新局："+_progress_error
  if not _progress_message.is_empty():body_label.text+="\n"+_progress_message
 var controls: Array[Control]=[]
 if page=="prepare":controls=[seed_edit,profile_picker,start_button]
 elif page=="between":
  if choice_box.visible:
   for button in choice_buttons:
    if button.visible:controls.append(button)
   if not confirm_button.disabled:controls.append(confirm_button)
   controls.append(skip_button)
  else:controls.append(continue_button)
 elif page in ["won","lost"]:controls=[same_button,new_button]
 elif page=="load_failed":controls=[reload_button]
 else:return
 if resume_button.visible and not resume_button.disabled:controls.insert(2,resume_button)
 if save_button.visible and not save_button.disabled:controls.append(save_button)
 if record_button.visible and not record_button.disabled:controls.insert(1,record_button)
 controls.append(back_button)
 for i in range(controls.size()):
  controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()]);controls[i].focus_previous=controls[i].get_path_to(controls[(i-1+controls.size())%controls.size()])
