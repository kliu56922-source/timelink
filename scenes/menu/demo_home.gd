extends Control
## Player-facing launch surface. Development navigation requires an explicit flag.
const Profile=preload("res://core/config/demo_playtest_profile.gd")
const TC=preload("res://core/theme/theme_colors.gd")
var actions: VBoxContainer
var summary: Label
var start_button: Button
var help_button: Button
var settings_button: Button
var quit_button: Button
var help_dialog: AcceptDialog
var settings_dialog: Window
var fullscreen_check: CheckBox
var _starting:=false
var loading_label: Label
var _scene_loader: Node
func _ready() -> void:
	if Profile.developer_enabled():
		get_tree().call_deferred("change_scene_to_file","res://scenes/menu/main_menu.tscn")
		return
	print("[DEMO_HOME] ready cards=%d player=%d boss=%d"%[Profile.DECK_COUNT,Profile.PLAYER_HP,Profile.BOSS_HP])
	var background:=ColorRect.new();background.color=TC.BG_DARK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	var center:=CenterContainer.new();center.name="Center";center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
	var body:=VBoxContainer.new();body.name="Body";body.custom_minimum_size.x=560;body.add_theme_constant_override("separation",10);center.add_child(body)
	var title:=Label.new();title.text="时 序 链";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",44);body.add_child(title)
	var subtitle:=Label.new();subtitle.text="卡牌 · 战术棋盘 · Boss 战";subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.add_theme_font_size_override("font_size",17);subtitle.add_theme_color_override("font_color",TC.TEXT_SECONDARY);body.add_child(subtitle)
	var gap:=Control.new();gap.custom_minimum_size.y=22;body.add_child(gap)
	actions=VBoxContainer.new();actions.name="Actions";actions.add_theme_constant_override("separation",10);body.add_child(actions)
	start_button=_button("StartDemo","开始试玩",26,64)
	start_button.pressed.connect(_start_demo)
	var start_hint:=Label.new();start_hint.name="StartHint";start_hint.text="一局约 10 分钟　·　固定 19 张牌　·　十回合左右";start_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;start_hint.add_theme_font_size_override("font_size",13);start_hint.add_theme_color_override("font_color",TC.TEXT_SECONDARY);actions.add_child(start_hint)
	var gap2:=Control.new();gap2.custom_minimum_size.y=10;actions.add_child(gap2)
	help_button=_button("HowToPlay","怎么玩",17,46);help_button.pressed.connect(func():help_dialog.popup_centered())
	settings_button=_button("Settings","设置",17,46);settings_button.pressed.connect(_open_settings)
	var gap3:=Control.new();gap3.custom_minimum_size.y=8;actions.add_child(gap3)
	quit_button=_button("QuitDemo","退出",14,38);quit_button.add_theme_color_override("font_color",TC.TEXT_SECONDARY);quit_button.pressed.connect(func():get_tree().quit())
	var stamp := Label.new()
	stamp.name = "BuildStamp"
	stamp.text = "v1.0 · build 2026-11-10"
	stamp.add_theme_font_size_override("font_size", 12)
	stamp.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamp.offset_left = -220
	stamp.offset_top = -34
	stamp.offset_right = -18
	stamp.offset_bottom = -12
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(stamp)
	_build_dialogs()
	loading_label=Label.new();loading_label.name="LoadingStatus";loading_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;loading_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;loading_label.custom_minimum_size.x=520;loading_label.hide();body.add_child(loading_label);body.move_child(loading_label,4)

func _button(node_name: String,caption: String,font_size: int = 18,height: int = 50) -> Button:
	var button:=Button.new();button.name=node_name;button.text=caption;button.custom_minimum_size=Vector2(0,height);button.add_theme_font_size_override("font_size",font_size);actions.add_child(button);return button
func _build_dialogs() -> void:
	help_dialog=AcceptDialog.new();help_dialog.name="PlayGuide";help_dialog.title="玩法说明";help_dialog.ok_button_text="返回";help_dialog.min_size=Vector2i(620,360);add_child(help_dialog)
	help_dialog.dialog_text="【目标】\n在自家核心被打穿之前，先打掉对面的核心。\n\n【第一回合】\n只能部署，不能移动也不能攻击。\n凑齐「燃芯使魔」和「炉基座」可一次铺开学徒；也可以用普通牌。\n准备好后点「部署完成」。\n\n【第二回合起】\n选一个能行动的单位 → 选目标 → 有多条路线时选一条 → 执行。\n休整、指令不足、位置不对、守卫挡路都会让动作做不了，按提示处理。\n\n【怎么赢】\n护臂 2 耐久、阀门 2 耐久，各破一次对本体 10 伤；\n两个都破之后核心（4 耐久）才暴露，破核心 12 伤。\n外围先打哪个由你决定，顺序会影响接下来要扛的压力。\n\n【打不动时】\n用「燃芯使魔」或「炉基座」做素材维护：修复最多 2 点，或补回一个离场学徒。\n每次 1 指令、热 +2，每回合一次，全场两次。\n\n【看不懂时】\n悬停卡牌会提示关联与缺什么条件；点「玩法与目标」看当前该做什么。\n右上角可调演出速度，只影响表现，不影响结果。"
	settings_dialog=Window.new();settings_dialog.name="DisplaySettings";settings_dialog.title="设置";settings_dialog.visible=false;settings_dialog.size=Vector2i(460,210);settings_dialog.min_size=Vector2i(460,210);add_child(settings_dialog);settings_dialog.close_requested.connect(settings_dialog.hide)
	var body:=VBoxContainer.new();body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);body.offset_left=22;body.offset_right=-22;body.offset_top=24;body.offset_bottom=-24;body.add_theme_constant_override("separation",16);settings_dialog.add_child(body)
	var label:=Label.new();label.text="显示模式（仅本次运行）";body.add_child(label)
	fullscreen_check=CheckBox.new();fullscreen_check.text="全屏显示";body.add_child(fullscreen_check)
	fullscreen_check.toggled.connect(func(enabled: bool):DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED))
	var close:=Button.new();close.text="返回";close.custom_minimum_size.y=44;body.add_child(close);close.pressed.connect(settings_dialog.hide)
func _open_settings() -> void:
	fullscreen_check.set_pressed_no_signal(DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN])
	settings_dialog.popup_centered()
func _start_demo() -> void:
	_begin_scene_start(Profile.BATTLE_PATH)
func _begin_scene_start(path: String) -> void:
	if _starting:return
	_starting=true;start_button.disabled=true;help_button.disabled=true;settings_button.disabled=true;start_button.text="正在准备战斗…"
	_scene_start_message("正在准备战斗…首次进入约 10 秒，之后会快很多")
	_scene_loader=preload("res://ui/demo_scene_loader.gd").new();_scene_loader.setup(self,path);get_tree().root.add_child(_scene_loader)
func _scene_start_message(message: String) -> void:
	loading_label.text=message;loading_label.show()
func _scene_start_failed(message: String) -> void:
	_starting=false;start_button.disabled=false;help_button.disabled=false;settings_button.disabled=false;start_button.text="开始试玩";_scene_start_message(message)
