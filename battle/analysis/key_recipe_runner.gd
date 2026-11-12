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
var _recorded_transactions: Dictionary={}
func setup(owner: Node) -> void:scene_ref=weakref(owner)
func scene() -> Variant:
	var s: Variant=scene_ref.get_ref() if scene_ref!=null else null
	return s if is_instance_valid(s) and s.is_inside_tree() else null
func _gate() -> String:
	var s: Variant=scene()
	if s==null or s._gb1_restarting:return "场次已离开"
	if s.battle_ended:return "战斗已结束"
	var selection: String=s.advance165.input_hint()
	if not selection.is_empty():return selection
	if running or s.advance165.running or s.axis155.running or not s.axis155_native_ready():return "等待当前动作完成"
	if s._has_non_presentation_end_turn_busy():return "请先完成或取消当前技能、驻军或其他选取"
	if s._is_piece_selection_active() or s._is_lane_selection_active() or s._is_monster_summon_interaction_active() or s._od_release_context.get("active",false):return "请先完成或取消原选取"
	return ""
func fingerprint() -> Dictionary:
	var s: Variant=scene()
	if s==null:return {}
	var f: Dictionary=s.advance165.fingerprint()
	f.recipe=s.battle.recipe166_snapshot()
	return f
func preview(direction: String,anchor: Vector2i) -> Dictionary:
	var gate:=_gate()
	if not gate.is_empty():return {"ok":false,"reason":gate}
	return scene().battle.recipe166_preview(direction,anchor)
func prepare(direction: String,anchor: Vector2i) -> Dictionary:
	_quotes.clear()
	var q:=preview(direction,anchor)
	if not q.get("ok",false):return q
	_serial+=1
	q={"ok":true,"serial":_serial,"quote":q.duplicate(true),"signature":fingerprint(),"key_ids":q.key_ids.duplicate(),"derived_count":q.derived_count,"command_cost":q.command_cost}
	_quotes[_serial]=q.duplicate(true)
	return q
func invalidate() -> void:_quotes.clear()
func accelerate() -> void:
	if running:speed=4.0;changed.emit()
func skip() -> void:
	if running:skipped=true;changed.emit()
func execute(q: Dictionary) -> Dictionary:
	var gate:=_gate()
	if not gate.is_empty():return {"ok":false,"reason":gate}
	if not q.get("ok",false) or not _quotes.has(q.get("serial")) or _quotes[q.serial]!=q:return {"ok":false,"reason":"预览已失效、被改动或已提交"}
	if q.signature!=fingerprint():invalidate();return {"ok":false,"reason":"局面已变化，请重新预览"}
	_quotes.clear();running=true;speed=1.0;skipped=false;elapsed=0.0
	var s: Variant=scene()
	var receipt: Dictionary=s.battle.recipe166_commit(q.quote)
	if not receipt.get("ok",false):running=false;last_result=receipt;changed.emit();return receipt
	last_result=receipt.duplicate(true)
	_record_receipt(s,receipt)
	s._play_command_economy_spend(int(receipt.cost))
	if is_instance_valid(s._end_turn_control):s._end_turn_control.set_busy(true,"正在成阵，可加速或跳过")
	s._refresh_tables();s._refresh_weakpoint162a()
	s.recipe_fx166.begin(receipt)
	committed.emit(receipt.duplicate(true));changed.emit()
	# No rule mutation below this boundary. The entire effect is already paid.
	while not skipped and elapsed<2.6:
		await get_tree().process_frame
		s=scene()
		if s==null:return last_result
		elapsed+=get_process_delta_time()*speed
		s.recipe_fx166.present(elapsed)
	s=scene()
	if s!=null:s.recipe_fx166.finish();s._refresh_tables()
	running=false;last_result.presentation_skipped=skipped;last_result.presentation_speed=speed
	if s!=null:s._release_idle_end_turn_busy();s._refresh_command_economy_surfaces()
	changed.emit()
	if s!=null:s.recipe166_finished.call_deferred()
	return last_result
func _record_receipt(s: Node,receipt: Dictionary) -> void:
	var tx: String=str(receipt.transaction)
	if _recorded_transactions.has(tx):return
	_recorded_transactions[tx]=true
	var telemetry: Variant=s.get("_playtest")
	if telemetry==null:return
	for key: Dictionary in receipt.key_sources:
		var event:=key.duplicate(true);event.transaction=tx;event.source_kind="recipe166_key"
		telemetry.record_event("card_played",event)
	telemetry.record_event("recipe166_committed",receipt.duplicate(true))
	telemetry.record_event("command_result",{"side":"player","command_id":"recipe166","ok":true,"cost":int(receipt.cost),"refund":0,"transaction":tx})
func _exit_tree() -> void:
	_quotes.clear();skipped=true;running=false
