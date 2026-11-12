extends "res://scenes/experiments/phase102_edge_fortification_trial.gd"
const Footprints := preload("res://core/battle/building_footprint_trial.gd")
var _footprint_size: OptionButton
var _footprint_rotation: OptionButton
func _setup_game() -> void:
	super._setup_game()
	if battle.hand_structure_build_committed.is_connected(engineering._record_hand_build):battle.hand_structure_build_committed.disconnect(engineering._record_hand_build)
	engineering=Footprints.new(battle,prepared_blueprints);engineering.begin_player_turn()
	fortification=Fortification.new(battle,engineering);fortification.begin_player_turn()

func _build_engineering_controls() -> void:
	super._build_engineering_controls()
	_engineering_window.size=Vector2i(590,530)
	var body: VBoxContainer=_engineering_text.get_parent()
	var choices:=HBoxContainer.new();choices.name="FootprintSelection";body.add_child(choices);body.move_child(choices,2)
	_footprint_size=OptionButton.new();_footprint_size.name="FootprintSize";choices.add_child(_footprint_size)
	for text: String in ["冷却设施 1×1","冷却设施 1×2","冷却设施 2×2"]:_footprint_size.add_item(text)
	_footprint_rotation=OptionButton.new();_footprint_rotation.name="FootprintRotation";choices.add_child(_footprint_rotation)
	for text: String in ["朝北 0°","朝东 90°","朝南 180°","朝西 270°"]:_footprint_rotation.add_item(text)
	for picker: OptionButton in [_footprint_size,_footprint_rotation]:picker.item_selected.connect(func(_i):_apply_footprint_selection())
	var note:=Label.new();note.text="空间试验：大尺寸暂沿用原能力/费用；围护设施保持1×1。";note.add_theme_font_size_override("font_size",14);body.add_child(note);body.move_child(note,3)

func _apply_footprint_selection() -> void:
	engineering.select_footprint([Vector2i.ONE,Vector2i(1,2),Vector2i(2,2)][_footprint_size.selected],_footprint_rotation.selected)
	_refresh_engineering(false)

func _preview_engineering(rush: bool) -> void:
	super._preview_engineering(rush)
	if not _engineering_quote.get("ok",false):return
	var cells: Array=_engineering_quote.layout._structure_plan.structure.get("footprint_cells",[_engineering_quote.cell])
	var positions: PackedStringArray=[]
	for cell: Vector2i in cells:positions.append("(%d列,%d行)"%[cell.x+1,cell.y+1])
	_engineering_confirm.dialog_text+="\n占用%d格：%s\n付款后固定方向，不能通过旋转修复或挪动。"%[cells.size(),"、".join(positions)]

func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file("res://scenes/experiments/phase103_building_footprint_trial.tscn")
	if err!=OK:_gb1_restarting=false;push_error("Footprint trial restart failed: %d"%err)
