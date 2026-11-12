extends "res://scenes/playtest/phase166c_maintenance.gd"
var ready166d:=false
var transition166d:=false
var body_busy166d:=false
var flow166d: Node
var _nav166d:=""
func _ready() -> void:
	await super._ready()
	flow166d=preload("res://ui/encounter_flow_readout.gd").new();add_child(flow166d);flow166d.setup(self)
	var guide: Variant=get_node("IntegratedPlaytestTools").guide_window
	guide.dialog_text+="\n166D：顶部第N回合按实际己方回合计数，含部署；上次Boss动作不是下次预告。成阵后可点击炉基座单独支付资源强化主力，也可保留资源；不自动代用。三要害全破后点单位→攻击Boss本体收尾，仍需合法攻核位置/无守卫与足够指令。结束回合结算期间重复请求不生效。"
	ready166d=true
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("166C ","166D ")
func _on_end_turn() -> void:
	if transition166d or body_busy166d or _exit_modal_active or _gb1_restarting or battle_ended:return
	if battle==null or not battle.get_command_economy_snapshot("player").get("turn_open",false):return
	transition166d=true
	await super._on_end_turn()
	transition166d=false
	if not _nav166d.is_empty():var nav:=_nav166d;_nav166d="";axis155_navigate.call_deferred(nav)
func axis155_native_ready() -> bool:
	if transition166d or body_busy166d:return false
	return super.axis155_native_ready()
func integrated_navigation_ready() -> bool:
	if transition166d or body_busy166d:return false
	return super.integrated_navigation_ready()
func finish_body166d(uid: int) -> Dictionary:
	if _exit_modal_active or not axis155_native_ready() or body_busy166d:return {"ok":false,"reason":"等待当前操作完成"}
	var selection_gate: String=recipe166._gate()
	if not selection_gate.is_empty():return {"ok":false,"reason":selection_gate}
	for part: Dictionary in battle.get_weakpoint_snapshots():
		if not part.broken:return {"ok":false,"reason":"本入口在三要害全破后启用；原手动攻本体仍保留"}
	var actor: CardData=advance165.resolve(uid)
	var q: Dictionary=battle.get_unit_command_status(actor,"attack_core") if actor!=null else {"ok":false}
	if not q.get("ok",false):return {"ok":false,"reason":"请检查攻核位置、朝向、守卫、休整与指令"}
	body_busy166d=true
	var before: int=battle.get_command_economy_snapshot("player").current_points
	# Retain original piece/native target authority, cleanup and presentation.
	_on_monster_command("attack",actor);_on_boss_area_attack_clicked("enemy")
	for i in range(900):
		await get_tree().process_frame
		if battle_ended or (not _has_non_presentation_end_turn_busy() and not _presentation_end_turn_blocked and (_battle_presentation_director==null or not _battle_presentation_director.is_busy())):break
	var paid: int=before-int(battle.get_command_economy_snapshot("player").current_points)
	body_busy166d=false
	if paid>0:advance_panel165.dismiss()
	if not _nav166d.is_empty():var nav:=_nav166d;_nav166d="";axis155_navigate.call_deferred(nav)
	return {"ok":paid>0,"cost":paid,"quoted_cost":int(q.cost),"native_lifecycle":true}
func axis155_navigate(nav: String) -> void:
	if not ready166d:return
	if body_busy166d:_nav166d=nav;return
	if transition166d:_nav166d=nav;return
	if support166c.running:_support_nav166c=nav;support166c.skip();return
	if recipe166.running:_recipe_nav166=nav;recipe166.skip();return
	if advance165.running:_advance_nav165=nav;advance165.stop("导航");return
	if axis155.running:_axis155_navigation=nav;axis155.stop("导航");return
	if nav not in ["restart","home"] or _gb1_restarting or not axis155_native_ready():return
	support_panel166c.dismiss();recipe_panel166.dismiss();advance_panel165.dismiss();advance165.stop("navigation");axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var destination: String="res://scenes/playtest/phase166d_integrated.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
	var error:=get_tree().change_scene_to_file(destination)
	if error!=OK:_gb1_restarting=false;push_error("166D navigation failed")
