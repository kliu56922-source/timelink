extends "res://battle/analysis/key_recipe_runner.gd"
func execute(q: Dictionary) -> Dictionary:
	var refusal:=_gate()
	if not refusal.is_empty():return {"ok":false,"reason":refusal}
	if not q.get("ok",false) or not _quotes.has(q.get("serial")) or _quotes[q.serial]!=q:return {"ok":false,"reason":"预览已失效、被改动或已提交"}
	if q.signature!=fingerprint():invalidate();return {"ok":false,"reason":"局面已变化，请重新预览"}
	_quotes.clear();running=true;speed=1.0;skipped=false;elapsed=0.0
	var owner: Variant=scene();var ids: Array=q.quote.key_uids.duplicate();var starts: Dictionary={}
	for uid: int in ids:
		for card: CardData in owner.context.player.hand:
			if card.get_instance_id()!=uid:continue
			var face: CardUI=owner._live_hand_ui(card)
			if is_instance_valid(face):starts[uid]=face.get_global_rect().get_center()
	owner.recipe_fx166.arm167c(ids,starts)
	var receipt: Dictionary=owner.battle.recipe166_commit(q.quote)
	if not receipt.get("ok",false):owner.recipe_fx166.finish();running=false;last_result=receipt;changed.emit();return receipt
	last_result=receipt.duplicate(true);_record_receipt(owner,receipt)
	owner._play_command_economy_spend(int(receipt.cost))
	if is_instance_valid(owner._end_turn_control):owner._end_turn_control.set_busy(true,"整套已结算，正在逐张显示；可加速/跳过")
	owner.recipe_fx166.begin(receipt);owner._refresh_tables();owner._refresh_weakpoint162a();owner.recipe_fx166.mask167c.enforce()
	if not owner.recipe_fx166.prepared167c:skipped=true;last_result.presentation_issue="展示数据不完整，显示真实结果"
	committed.emit(receipt.duplicate(true));changed.emit()
	while not skipped and elapsed<float(owner.recipe_fx166.duration167c):
		await get_tree().process_frame
		owner=scene()
		if owner==null:return last_result
		elapsed+=get_process_delta_time()*speed;owner.recipe_fx166.present(elapsed)
	owner=scene()
	if owner!=null:
		last_result.presentation_viewed=owner.recipe_fx166.viewed167c.duplicate(true);owner.recipe_fx166.finish();owner._refresh_tables()
	running=false;last_result.presentation_skipped=skipped;last_result.presentation_speed=speed
	if owner!=null:owner._release_idle_end_turn_busy();owner._refresh_command_economy_surfaces()
	changed.emit()
	if owner!=null:owner.recipe166_finished.call_deferred()
	return last_result
