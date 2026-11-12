extends "res://scenes/experiments/phase100_engineering_book_trial.gd"
const Construction := preload("res://core/battle/construction_site_trial.gd")
@export var prepared_blueprints: Array[String]=["P13","P16"]
var _site_labels: Dictionary={}

func _setup_game() -> void:
	super._setup_game()
	engineering=Construction.new(battle,prepared_blueprints)
	engineering.begin_player_turn()

func _refresh_engineering(refresh_hand: bool=true) -> void:
	super._refresh_engineering(refresh_hand)
	if not is_instance_valid(_engineering_text) or engineering==null:return
	var state: Dictionary=engineering.snapshot()
	var quote: Dictionary=engineering.inspect(_selected_engineering_cell(),false,_engineering_edge())
	var name_text: String={"P13":"冷却设施","P16":"围护设施"}.get(state.plan,"空闲，等待计划或整备手牌")
	_engineering_text.text="工程位：%s\n施工预算%d/4 · 累计完工%d处\n稳筑2指令：生成可受击工地，下个己方回合尝试完工。\n急筑另耗2热：立即完工，不送充能/连锁。\n完工保留核心损伤与破口；被毁须重新付费。\n当前位置：%s"%[name_text,state.admissions,state.completed,"可施工" if quote.ok else _engineering_reason(str(quote.reason_code))]
	for site: Dictionary in state.sites:
		var core: Dictionary=site.structure
		if site.admitted and not core.is_empty():_engineering_text.text+="\n施工中：第%d列第%d行 · 核心%d/%d"%[site.cell.x+1,site.cell.y+1,core.integrity_current,core.integrity_max]
		elif not site.admitted:_engineering_text.text+="\n已付费待入场：第%d列第%d行"%[site.cell.x+1,site.cell.y+1]
	var cancelled: Array=state.cancelled
	if not cancelled.is_empty():_engineering_text.text+="\n已毁/已替换工地%d处，不会自动重建。"%cancelled.size()
	_sync_site_labels()

func _preview_engineering(rush: bool) -> void:
	super._preview_engineering(rush)
	var timing:="急筑直接尝试完工，额外热量不转换为长期充能。" if rush else "稳筑立即产生可受击工地，下个己方回合尝试完工。"
	_engineering_confirm.dialog_text=_engineering_confirm.dialog_text.replace("预订位置之后若受阻，将保留已付费计划等待重试。",timing+"\n损伤、破口不会被完工清除；被毁需重新付费。")

func _sync_site_labels() -> void:
	if engineering==null or not is_instance_valid(_tactical_structure_presenter):return
	var live: Dictionary={}
	for site: Dictionary in engineering.snapshot().sites:
		if not site.admitted or site.structure.is_empty():continue
		var id: StringName=site.structure.structure_id
		var committed_root: Node3D=_tactical_structure_presenter.get_node_or_null("StructureCommittedRoot")
		if committed_root==null:continue
		var wrapper: Node3D=_tactical_structure_presenter._find_committed_view(committed_root,id)
		if not is_instance_valid(wrapper):continue
		live[id]=true
		var label: Label3D=_site_labels.get(id)
		if not is_instance_valid(label):
			label=Label3D.new();label.name="ConstructionStatus101";label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			label.position=Vector3(0,0.9,0);label.pixel_size=0.004;label.font_size=44;label.no_depth_test=true;label.modulate=Color(1.0,0.75,0.25)
			wrapper.add_child(label);_site_labels[id]=label
		label.text="施工中\n耐久%d/%d"%[site.structure.integrity_current,site.structure.integrity_max]
	for id: Variant in _site_labels.keys():
		if not live.has(id):
			var label: Label3D=_site_labels[id]
			if is_instance_valid(label):label.queue_free()
			_site_labels.erase(id)

func site_label_count() -> int:
	return _site_labels.size()

func _process(delta: float) -> void:
	super._process(delta)
	if _engineering_frame%15==0:_sync_site_labels()

func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file("res://scenes/experiments/phase101_construction_site_trial.tscn")
	if err!=OK:_gb1_restarting=false;push_error("Construction trial restart failed: %d"%err)
