extends Node
signal changed
signal committed(receipt: Dictionary)
var scene_ref: WeakRef
var running:=false
var speed:=1.0
var skipped:=false
var elapsed:=0.0
var last_result: Dictionary={}
var _serial:=0
var _quotes: Dictionary={}
func setup(owner: Node) -> void:scene_ref=weakref(owner)
func scene() -> Variant:
	var s: Variant=scene_ref.get_ref() if scene_ref!=null else null
	return s if is_instance_valid(s) and s.is_inside_tree() else null
func _gate() -> String:
	var s: Variant=scene()
	if s==null or s._gb1_restarting:return "场次已离开"
	if s.battle_ended:return "战斗已结束"
	if s._exit_modal_active:return "请先关闭返回确认弹窗，再进行维护"
	var selection: String=s.advance165.input_hint()
	if not selection.is_empty():return selection
	if running or s.recipe166.running or s.advance165.running or s.axis155.running or not s.axis155_native_ready():return "等待当前动作完成"
	if s._has_non_presentation_end_turn_busy():return "请先完成或取消当前技能、驻军或其他选取"
	if s._is_piece_selection_active() or s._is_lane_selection_active() or s._is_monster_summon_interaction_active() or s._od_release_context.get("active",false):return "请先完成或取消原选取"
	return ""
func invalidate() -> void:_quotes.clear()
func accelerate() -> void:
	if running:speed=4.0;changed.emit()
func skip() -> void:
	if running:skipped=true;changed.emit()
func fingerprint() -> Dictionary:
	var s: Variant=scene()
	if s==null:return {}
	var f: Dictionary=s.advance165.fingerprint();f.maintenance=s.battle.support166_signature();return f
func preview(mode: String,source_uid: int,target: Vector2i) -> Dictionary:
	var gate:=_gate()
	if not gate.is_empty():return {"ok":false,"reason":gate}
	return scene().battle.support166_preview(mode,source_uid,target)
func prepare(mode: String,source_uid: int,target: Vector2i) -> Dictionary:
	_quotes.clear();var q:=preview(mode,source_uid,target)
	if not q.get("ok",false):return q
	_serial+=1
	var approved: Dictionary={"ok":true,"serial":_serial,"quote":q.duplicate(true),"signature":fingerprint()}
	_quotes[_serial]=approved.duplicate(true);return approved
func execute(approved: Dictionary) -> Dictionary:
	var gate:=_gate()
	if not gate.is_empty():return {"ok":false,"reason":gate}
	if not approved.get("ok",false) or not _quotes.has(approved.get("serial")) or _quotes[approved.serial]!=approved:return {"ok":false,"reason":"预览已失效、被改动或已提交"}
	if approved.signature!=fingerprint():invalidate();return {"ok":false,"reason":"局面已变化，请重新预览"}
	_quotes.clear();running=true;speed=1.0;skipped=false;elapsed=0.0
	var s: Variant=scene();var receipt: Dictionary=s.battle.support166_commit(approved.quote)
	if not receipt.get("ok",false):running=false;last_result=receipt;changed.emit();return receipt
	last_result=receipt.duplicate(true)
	if s._playtest!=null:
		s._playtest.record_event("maintenance166c_committed",receipt.duplicate(true))
		s._playtest.record_event("card_played",{"card_id":receipt.source_id,"source_kind":"maintenance166c_material","transaction":receipt.transaction})
		s._playtest.record_event("command_result",{"side":"player","command_id":"maintenance166c","ok":true,"cost":1,"refund":0,"transaction":receipt.transaction})
	s._play_command_economy_spend(1);s._end_turn_control.set_busy(true,"维护已结算，可加速或跳过")
	s._refresh_tables();s._refresh_weakpoint162a();s.support_fx166c.begin(receipt)
	committed.emit(receipt.duplicate(true));changed.emit()
	while not skipped and elapsed<1.4:
		await get_tree().process_frame
		s=scene()
		if s==null:return last_result
		elapsed+=get_process_delta_time()*speed;s.support_fx166c.present(elapsed)
	s=scene()
	if s!=null:s.support_fx166c.finish();s._refresh_tables()
	running=false;last_result.presentation_skipped=skipped;last_result.presentation_speed=speed
	if s!=null:s._release_idle_end_turn_busy();s._refresh_command_economy_surfaces()
	changed.emit()
	if s!=null:s.support166c_finished.call_deferred()
	return last_result
func _exit_tree() -> void:
	_quotes.clear();skipped=true;running=false
