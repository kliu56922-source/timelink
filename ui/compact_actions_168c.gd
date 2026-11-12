extends Node
## No gameplay automation: explicit ordinary attack or explicit material+repair.
var owner_ref: WeakRef
var box: VBoxContainer
var attack_buttons: Dictionary={}
var repair_buttons: Dictionary={}
var dialog: ConfirmationDialog
var attack_quote: Dictionary={}
var _issued_quote168c: Dictionary={}
var owned_running:=false
var owned_result:=false
var last_result: Dictionary={}
var _rows: Array=[]
var _actor_uid:=0
var _elapsed:=0.2
var _progress_origin168c:=Vector2.ZERO
func s() -> Variant:
 var owner: Variant=owner_ref.get_ref() if owner_ref!=null else null
 return owner if is_instance_valid(owner) and owner.is_inside_tree() else null
func setup(owner: Node) -> void:
 owner_ref=weakref(owner);name="CompactActions168C";process_priority=300
 var choices: VBoxContainer=owner.advance_panel165.content_scroll.get_child(0)
 box=VBoxContainer.new();box.name="CompactChoices168C";choices.add_child(box);choices.move_child(box,1)
 _progress_origin168c=owner.axis155_panel.progress.position
 owner.axis155.changed.connect(func():
  if owner.axis155.running and not owned_running:owned_result=false;owner.axis155_panel.progress.position=_progress_origin168c)
 dialog=ConfirmationDialog.new();dialog.name="CompactAttackConfirm168C";dialog.title="普通攻击 · 确认后结算";dialog.size=Vector2i(600,330);dialog.exclusive=true;owner.add_child(dialog);dialog.hide()
 dialog.get_ok_button().text="确认普通攻击";dialog.get_cancel_button().text="取消 · 不付款"
 dialog.confirmed.connect(func():await execute_attack168c());dialog.canceled.connect(cancel_attack168c)
 owner.axis155.step_finished.connect(func(_i,r):
  if owned_running:owner.axis155_panel.progress_text.text="本次普通攻击已结算 · 实付%d指令\n热量%+d · Depth %d→%d\n不会自动接移动或要害攻击。"%[r.command_spent,r.heat_delta,r.depth_before,r.depth_after])
func _process(delta: float) -> void:
 var owner: Variant=s()
 if owner==null:return
 if owner.advance_panel165.panel.visible and owner.advance_panel165.config.visible and owner.advance_panel165.actor_uid!=_actor_uid:refresh168c()
 _elapsed+=delta
 if _elapsed>=0.2:_elapsed=0;refresh168c()
 if owned_result and not owner.axis155.running and (owner.advance_panel165.panel.visible or owner.support_panel166c.panel.visible or owner.targets167b.drawer.visible):owner.axis155_panel.progress.hide();owner.axis155_panel.progress.position=_progress_origin168c;owned_result=false
func actor168c(uid: int) -> CardData:return s().axis155.resolve(uid,"field") if s()!=null else null
func attack_status168c(uid: int,target_uid: int) -> Dictionary:
 var owner: Variant=s();var actor: CardData=actor168c(uid)
 var target: CardData=owner.axis155.resolve(target_uid,"enemy") if owner!=null else null
 if actor==null or target==null:return {"ok":false,"reason":"原单位或敌棋已离场"}
 var q: Dictionary=owner.battle.get_unit_command_status(actor,"attack",target)
 if not q.get("ok",false):return {"ok":false,"reason":str(q.get("reason_text",q.get("reason","当前不能直接攻击；可手动调整或换单位")))}
 if not q.get("siege_plan",{}).is_empty():return {"ok":false,"reason":"受围护目标请用原手动攻城确认"}
 if actor.piece_enabled and actor.card_family=="monster":
  var piece: Dictionary=owner.battle.get_card_piece_status(actor,&"attack",null,target,{"enhanced_requested":false,"payment_mode":&"none"})
  if not piece.get("ok",false) or int(piece.get("total_command_cost",-1))!=int(q.cost):return {"ok":false,"reason":"棋型普通攻击前提不满足；请用原手动入口"}
 return {"ok":true,"cost":int(q.cost)}
func refresh168c() -> void:
 var owner: Variant=s()
 if owner==null:return
 var ui: Variant=owner.advance_panel165
 box.visible=ui.panel.visible and ui.config.visible and ui.part_id.is_empty() and not owner.battle.preparation_active166b() and not owner.battle_ended and not owned_running
 if not box.visible:return
 var actor: CardData=actor168c(ui.actor_uid)
 if actor==null:box.hide();return
 var rows: Array=[]
 for enemy: CardData in owner.context.enemy.field:
  var status: Dictionary=attack_status168c(actor.get_instance_id(),enemy.get_instance_id())
  rows.append({"kind":"attack","uid":enemy.get_instance_id(),"label":"普通攻击："+enemy.get_display_name()+" · "+("%d指令"%status.cost if status.ok else "查看限制"),"ready":status.ok,"tip":"单次普通攻击，不移动/强化，不自动改目标；仍有原生还击。" if status.ok else status.reason})
 var st: Variant=owner.battle._state_for_card(actor)
 if st!=null and st.current_hp>0 and st.current_hp<st.max_hp:
  for card: CardData in owner.context.player.hand:
   if card.card_id not in ["P02","P05"]:continue
   var q: Dictionary=owner.battle.support166_preview("repair",card.get_instance_id(),owner.battle.get_unit_cell(actor))
   rows.append({"kind":"repair","uid":card.get_instance_id(),"label":"用"+card.get_display_name()+"修复＋%d血"%mini(2,st.max_hp-st.current_hp),"ready":q.get("ok",false),"tip":"明确消耗该手牌，预览费用后仍需确认；不刷新行动。" if q.get("ok",false) else str(q.get("reason","当前不可修复"))})
 if _actor_uid==ui.actor_uid and rows==_rows:return
 _actor_uid=ui.actor_uid;_rows=rows.duplicate(true);attack_buttons.clear();repair_buttons.clear()
 for c: Node in box.get_children():box.remove_child(c);c.queue_free()
 if rows.is_empty():return
 owner.advance_panel165.label(box,"快捷处理 · 选择后预览")
 for row: Dictionary in rows:
  var callback: Callable=request_ui_attack168c.bind(_actor_uid,row.uid) if row.kind=="attack" else request_ui_repair168c.bind(_actor_uid,row.uid)
  var b: Button=owner.advance_panel165.button(box,row.label,callback);b.disabled=not row.ready;b.tooltip_text=row.tip
  if row.kind=="attack":attack_buttons[row.uid]=b
  else:repair_buttons[row.uid]=b
# A queued old button is never authorization for a different visible selection.
func ui_actor_matches168c(uid: int) -> bool:
 var owner: Variant=s()
 if owner==null:return false
 var ui: Variant=owner.advance_panel165
 return ui.panel.visible and ui.config.visible and ui.part_id.is_empty() and ui.actor_uid==uid
func request_ui_attack168c(actor_uid: int,target_uid: int) -> Dictionary:
 if not ui_actor_matches168c(actor_uid):refresh168c();return {"ok":false,"reason":"单位选择已变化，请点当前单位的快捷动作"}
 return request_attack168c(actor_uid,target_uid)
func request_ui_repair168c(actor_uid: int,source_uid: int) -> void:
 if not ui_actor_matches168c(actor_uid):refresh168c();return
 request_repair168c(actor_uid,source_uid)
# Explicit callers below already choose a UID; visible UI always uses guarded entrypoints.
func request_repair168c(actor_uid: int,source_uid: int) -> void:
 var owner: Variant=s();var actor: CardData=actor168c(actor_uid)
 if owner==null or actor==null or not owner.support166c._gate().is_empty():return
 if owner.battle.support166_source(source_uid)==null:return
 var q: Dictionary=owner.battle.support166_preview("repair",source_uid,owner.battle.get_unit_cell(actor))
 if not q.get("ok",false):return
 owner.targets167b.dismiss();owner.support_panel166c.open_target167d(actor);owner.support_panel166c.choose_source(source_uid)
func request_attack168c(actor_uid: int,target_uid: int) -> Dictionary:
 var owner: Variant=s()
 if owner==null or dialog.visible or owned_running:return {"ok":false,"reason":"先完成或取消当前预览"}
 var gate: String=owner.recipe166._gate()
 if not gate.is_empty():return {"ok":false,"reason":gate}
 var status: Dictionary=attack_status168c(actor_uid,target_uid)
 if not status.ok:return status
 var actor: CardData=actor168c(actor_uid);var target: CardData=owner.axis155.resolve(target_uid,"enemy")
 var q: Dictionary=owner.axis155._quote("单次普通攻击",[{"kind":"attack","uid":actor_uid,"zone":"field","target_uid":target_uid,"cell":owner.battle.get_unit_cell(target),"compact168c":true}])
 if not q.get("ok",false):return q
 attack_quote=q.duplicate(true);_issued_quote168c=q.duplicate(true)
 dialog.dialog_text="单位：%s · 血量%d\n敌棋：%s · 血量%d · 攻击%d\n单次普通攻击：%d指令，Depth %d→%d\n保留原交战还击/减伤与棋型被动。\n不自动移动、出牌、强化或接要害；强化/攻城仍用手动入口。\n取消不付款；场面变化须重新预览。"%[actor.get_display_name(),owner.battle.get_unit_current_hp(actor),target.get_display_name(),owner.battle.get_unit_current_hp(target),target.unit_power,q.max_command,owner.context.depth_pressure,q.max_depth]
 dialog.popup_centered(Vector2i(600,330));return q
func _retire_attack168c() -> void:
 var owner: Variant=s()
 if owner!=null and not _issued_quote168c.is_empty() and owner.axis155._quotes.get(_issued_quote168c.id,{})==_issued_quote168c:owner.axis155._quotes.erase(_issued_quote168c.id)
 _issued_quote168c={}
func cancel_attack168c() -> void:
 if is_instance_valid(dialog):dialog.hide()
 _retire_attack168c();attack_quote={}
func execute_attack168c() -> Dictionary:
 var owner: Variant=s()
 if owner==null or owned_running or attack_quote.is_empty():return {"ok":false,"reason":"没有待确认攻击"}
 var q: Dictionary=attack_quote.duplicate(true);attack_quote={};dialog.hide();owned_running=true;owned_result=false
 owner.targets167b.dismiss();owner.advance_panel165.dismiss()
 owner.axis155_panel.progress.position=Vector2(16,maxf(235,owner.recipe_panel166.entry.position.y+owner.recipe_panel166.entry.size.y+8))
 owner.axis155_panel.progress_text.text="单次普通攻击正在结算；保留原生还击。\n完成后交回控制，不自动接其他动作。"
 var result: Dictionary=await owner.axis155.execute(q)
 owner=s()
 if owner==null:return result
 _retire_attack168c()
 owned_running=false;owned_result=true;last_result=result.duplicate(true)
 var paid:=0
 for receipt: Dictionary in result.get("receipts",[]):paid+=int(receipt.command_spent)
 owner.axis155_panel.progress_text.text=("普通攻击完成" if result.get("ok",false) else "普通攻击未继续："+str(result.get("reason","未提交")))+"\n本次实付%d指令。已结算动作不退款；没有自动接续。\n可直接点下一单位/部位，或收起记录。"%paid
 owner.axis155_panel.progress.show();return result
