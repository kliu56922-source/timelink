extends Panel
class_name CardDetailPanel

const TC = preload("res://core/theme/theme_colors.gd")
const CardVisualProfileClass = preload("res://ui/card_visual_profile.gd")

## CardDetailPanel 鈥?鍗＄墝璇︽儏棰勮闈㈡澘
## 鏄剧ず CardData 鍏ㄩ儴瀛楁 + OD Zone 鍖哄潡 + Chain Route 璺嚎淇℃伅銆?

# ============================================================
# @onready 鑺傜偣
# ============================================================
@onready var name_label: Label = _safe_node("ScrollContainer/VBoxContainer/NameLabel")
@onready var type_label: Label = _safe_node("ScrollContainer/VBoxContainer/TypeLabel")
@onready var rarity_label: Label = _safe_node("ScrollContainer/VBoxContainer/RarityLabel")
@onready var role_label: Label = _safe_node("ScrollContainer/VBoxContainer/RoleLabel")
@onready var cost_label: Label = _safe_node("ScrollContainer/VBoxContainer/CostLabel")
@onready var description_label: Label = _safe_node("ScrollContainer/VBoxContainer/DescriptionLabel")
@onready var keyword_label: Label = _safe_node("ScrollContainer/VBoxContainer/KeywordLabel")
@onready var chain_info_label: Label = _safe_node("ScrollContainer/VBoxContainer/ChainInfoLabel")
@onready var flavor_text_label: Label = _safe_node("ScrollContainer/VBoxContainer/FlavorTextLabel")

# Zone 鍖哄潡
@onready var zone_box: VBoxContainer = _safe_node("ScrollContainer/VBoxContainer/ZoneBox")
@onready var calm_panel: Panel = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/CalmPanel")
@onready var calm_title: Label = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/CalmPanel/CalmVBox/CalmTitle")
@onready var calm_text: Label = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/CalmPanel/CalmVBox/CalmText")
@onready var heated_panel: Panel = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/HeatedPanel")
@onready var heated_title: Label = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/HeatedPanel/HeatedVBox/HeatedTitle")
@onready var heated_text: Label = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/HeatedPanel/HeatedVBox/HeatedText")
@onready var overdrive_panel: Panel = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/OverdrivePanel")
@onready var overdrive_title: Label = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/OverdrivePanel/OverdriveVBox/OverdriveTitle")
@onready var overdrive_text: Label = _safe_node("ScrollContainer/VBoxContainer/ZoneBox/OverdrivePanel/OverdriveVBox/OverdriveText")

# Route 鍖哄潡
@onready var route_separator: HSeparator = _safe_node("ScrollContainer/VBoxContainer/RouteHSep")
@onready var route_panel: Panel = _safe_node("ScrollContainer/VBoxContainer/RoutePanel")
@onready var route_name_label: Label = _safe_node("ScrollContainer/VBoxContainer/RoutePanel/RouteVBox/RouteNameLabel")
@onready var route_step_label: Label = _safe_node("ScrollContainer/VBoxContainer/RoutePanel/RouteVBox/RouteStepLabel")
@onready var route_next_label: Label = _safe_node("ScrollContainer/VBoxContainer/RoutePanel/RouteVBox/RouteNextLabel")
@onready var route_reward_label: Label = _safe_node("ScrollContainer/VBoxContainer/RoutePanel/RouteVBox/RouteRewardLabel")
@onready var route_recommend_label: Label = _safe_node("ScrollContainer/VBoxContainer/RoutePanel/RouteVBox/RouteRecommendLabel")

# 鍙敤鎬х姸鎬佹爣绛撅紙绋嬪簭鍖栧垱寤猴級
var _status_label: Label = null

# Zone 婵€娲绘牱寮?
var _style_calm_active: StyleBoxFlat
var _style_heated_active: StyleBoxFlat
var _style_overdrive_active: StyleBoxFlat
var _style_calm_inactive: StyleBoxFlat
var _style_heated_inactive: StyleBoxFlat
var _style_overdrive_inactive: StyleBoxFlat

# Route 棰滆壊鏍峰紡锛堣繍琛屾椂鍔ㄦ€佺敓鎴愶級
var _style_route_heat: StyleBoxFlat
var _style_route_cool: StyleBoxFlat
var _style_route_disrupt: StyleBoxFlat
var _style_route_default: StyleBoxFlat

# 澶栭儴寮曠敤
var _chain_system: ChainSequenceSystem = null

# Phase 7E-2: 璇︽儏闈㈡澘鍗″浘 鈥?TextureRect锛堝姩鎬佸垱寤?鏇存柊锛?
var _detail_art_rect: TextureRect = null
var _detail_art_sep: HSeparator = null
var _preview_hint_label: Label = null
var _pinned_detail_mode := false


# ============================================================
# 瀹夊叏鑺傜偣鑾峰彇
# ============================================================
func _safe_node(path: String) -> Node:
	return get_node_or_null(NodePath(path))


# ============================================================
# 鍒濆鍖?
# ============================================================
func _ready() -> void:
	_build_active_styles()
	_build_route_styles()
	_prepare_label_layouts()
	_ensure_preview_hint()
	if calm_panel:
		_style_calm_inactive = calm_panel.get_theme_stylebox("panel").duplicate() if calm_panel.get_theme_stylebox("panel") else _style_calm_inactive
	if heated_panel:
		_style_heated_inactive = heated_panel.get_theme_stylebox("panel").duplicate() if heated_panel.get_theme_stylebox("panel") else _style_heated_inactive
	if overdrive_panel:
		_style_overdrive_inactive = overdrive_panel.get_theme_stylebox("panel").duplicate() if overdrive_panel.get_theme_stylebox("panel") else _style_overdrive_inactive
	_apply_detail_mode()


func set_detail_mode(pinned: bool) -> void:
	_pinned_detail_mode = pinned
	_apply_detail_mode()


func is_detail_pinned_mode() -> bool:
	return _pinned_detail_mode


func _ensure_preview_hint() -> void:
	var vbox := _safe_node("ScrollContainer/VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	_preview_hint_label = vbox.get_node_or_null(NodePath("PreviewHintLabel")) as Label
	if _preview_hint_label != null:
		return
	_preview_hint_label = Label.new()
	_preview_hint_label.name = "PreviewHintLabel"
	_preview_hint_label.add_theme_font_size_override("font_size", 10)
	_preview_hint_label.add_theme_color_override("font_color", Color(0.45, 0.82, 1.0, 0.95))
	_preview_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_preview_hint_label)
	vbox.move_child(_preview_hint_label, 0)


func _apply_detail_mode() -> void:
	_ensure_preview_hint()
	if _preview_hint_label != null:
		_preview_hint_label.text = "已固定 · 右键或 Esc 关闭" if _pinned_detail_mode else "快速预览 · 右键固定详情"
		_preview_hint_label.visible = true

	# Hover previews expose only decision-critical facts. Pinned details restore
	# the complete route, zone and flavor breakdown inside the scroll view.
	for node in [rarity_label, role_label, zone_box]:
		if node != null and is_instance_valid(node):
			node.visible = _pinned_detail_mode
	if not _pinned_detail_mode:
		for optional_node in [chain_info_label, route_separator, route_panel, flavor_text_label]:
			if optional_node != null and is_instance_valid(optional_node):
				optional_node.visible = false
	var value_info := get_node_or_null(NodePath("ScrollContainer/VBoxContainer/ValueInfoBox")) as Control
	if value_info != null:
		value_info.visible = _pinned_detail_mode

	_set_descendant_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
	mouse_filter = Control.MOUSE_FILTER_PASS if _pinned_detail_mode else Control.MOUSE_FILTER_IGNORE
	var scroll := _safe_node("ScrollContainer") as ScrollContainer
	if scroll != null:
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS if _pinned_detail_mode else Control.MOUSE_FILTER_IGNORE


func _set_descendant_mouse_filter(node: Node, filter: Control.MouseFilter) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
		_set_descendant_mouse_filter(child, filter)


func _prepare_label_layouts() -> void:
	var sc := _safe_node("ScrollContainer") as ScrollContainer
	if sc and is_instance_valid(sc):
		sc.clip_contents = true
		# Phase 13A: 强制纵向滚动，禁用横向滚动，防止文本溢出
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		sc.follow_focus = false

	var labels: Array[Label] = [
		name_label, type_label, rarity_label, role_label, cost_label,
		description_label, keyword_label, chain_info_label, flavor_text_label,
		calm_text, heated_text, overdrive_text,
		route_name_label, route_step_label, route_next_label,
		route_reward_label, route_recommend_label,
	]
	for lbl in labels:
		if lbl == null or not is_instance_valid(lbl):
			continue
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.clip_text = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(0, 0)


func _build_active_styles() -> void:
	_style_calm_active = StyleBoxFlat.new()
	_style_calm_active.bg_color = Color(0.06, 0.14, 0.28, 1)
	_style_calm_active.border_width_left = 2
	_style_calm_active.border_width_right = 2
	_style_calm_active.border_width_top = 2
	_style_calm_active.border_width_bottom = 2
	_style_calm_active.border_color = Color(0.25, 0.6, 1, 1)
	_style_calm_active.set_corner_radius_all(4)

	_style_heated_active = StyleBoxFlat.new()
	_style_heated_active.bg_color = Color(0.22, 0.1, 0.03, 1)
	_style_heated_active.border_width_left = 2
	_style_heated_active.border_width_right = 2
	_style_heated_active.border_width_top = 2
	_style_heated_active.border_width_bottom = 2
	_style_heated_active.border_color = Color(1, 0.5, 0.1, 1)
	_style_heated_active.set_corner_radius_all(4)

	_style_overdrive_active = StyleBoxFlat.new()
	_style_overdrive_active.bg_color = Color(0.22, 0.04, 0.04, 1)
	_style_overdrive_active.border_width_left = 2
	_style_overdrive_active.border_width_right = 2
	_style_overdrive_active.border_width_top = 2
	_style_overdrive_active.border_width_bottom = 2
	_style_overdrive_active.border_color = Color(1, 0.12, 0.05, 1)
	_style_overdrive_active.set_corner_radius_all(4)

	_style_calm_inactive = StyleBoxFlat.new()
	_style_calm_inactive.bg_color = Color(0.05, 0.08, 0.15, 1)
	_style_calm_inactive.border_color = Color(0.15, 0.22, 0.4, 1)
	_style_calm_inactive.set_corner_radius_all(4)

	_style_heated_inactive = StyleBoxFlat.new()
	_style_heated_inactive.bg_color = Color(0.12, 0.07, 0.03, 1)
	_style_heated_inactive.border_color = Color(0.35, 0.18, 0.06, 1)
	_style_heated_inactive.set_corner_radius_all(4)

	_style_overdrive_inactive = StyleBoxFlat.new()
	_style_overdrive_inactive.bg_color = Color(0.12, 0.03, 0.03, 1)
	_style_overdrive_inactive.border_color = Color(0.35, 0.06, 0.06, 1)
	_style_overdrive_inactive.set_corner_radius_all(4)


func _build_route_styles() -> void:
	_style_route_heat = StyleBoxFlat.new()
	_style_route_heat.bg_color = Color(0.14, 0.04, 0.02, 1)
	_style_route_heat.border_width_left = 2
	_style_route_heat.border_width_right = 2
	_style_route_heat.border_width_top = 2
	_style_route_heat.border_width_bottom = 2
	_style_route_heat.border_color = Color(1, 0.4, 0.1, 1)
	_style_route_heat.set_corner_radius_all(4)

	_style_route_cool = StyleBoxFlat.new()
	_style_route_cool.bg_color = Color(0.02, 0.06, 0.14, 1)
	_style_route_cool.border_width_left = 2
	_style_route_cool.border_width_right = 2
	_style_route_cool.border_width_top = 2
	_style_route_cool.border_width_bottom = 2
	_style_route_cool.border_color = Color(0.2, 0.5, 1, 1)
	_style_route_cool.set_corner_radius_all(4)

	_style_route_disrupt = StyleBoxFlat.new()
	_style_route_disrupt.bg_color = Color(0.02, 0.12, 0.04, 1)
	_style_route_disrupt.border_width_left = 2
	_style_route_disrupt.border_width_right = 2
	_style_route_disrupt.border_width_top = 2
	_style_route_disrupt.border_width_bottom = 2
	_style_route_disrupt.border_color = Color(0.2, 0.85, 0.3, 1)
	_style_route_disrupt.set_corner_radius_all(4)

	_style_route_default = StyleBoxFlat.new()
	_style_route_default.bg_color = Color(0.04, 0.04, 0.08, 1)
	_style_route_default.border_color = Color(0.3, 0.3, 0.45, 1)
	_style_route_default.set_corner_radius_all(4)


# ============================================================
# 澶栭儴寮曠敤璁剧疆
# ============================================================

func set_chain_system(cs: ChainSequenceSystem) -> void:
	_chain_system = cs


# ============================================================
# 鍏紑 API
# ============================================================

## zone_name: "Calm" / "Heated" / "Overdrive" / ""
## status: {ok: bool, reason: String} 鈥?鍙敤鎬х姸鎬?
func _ensure_detail_family_accent() -> ColorRect:
	var existing := get_node_or_null(NodePath("DetailFamilyAccent")) as ColorRect
	if existing:
		return existing
	var accent := ColorRect.new()
	accent.name = "DetailFamilyAccent"
	accent.anchor_bottom = 1.0
	accent.offset_right = 5.0
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.z_index = 5
	add_child(accent)
	return accent


func _refresh_detail_family(card: CardData) -> void:
	var profile: Dictionary = CardVisualProfileClass.from_card(card)
	var accent_color: Color = profile["accent"]
	_ensure_detail_family_accent().color = accent_color
	if type_label:
		var identity := str(profile["family_label"])
		if str(profile["display_label"]) != "":
			identity += " · " + str(profile["display_label"])
		type_label.text = identity
		type_label.add_theme_color_override("font_color", accent_color)


func show_card(card: CardData, zone_name: String = "", status: Dictionary = {}, combat_state: Dictionary = {}) -> void:
	if card == null:
		clear()
		return

	visible = true
	_refresh_detail_family(card)

	# --- Phase 7E-2: 璇︽儏鍗″浘锛?12脳512 detail锛?---
	_update_detail_art(card)

	# --- 鍙敤鎬х姸鎬?---
	_update_status_label(status)

	# Phase 13F-2: ascension preview
	_update_ascension_preview(status)

	# --- 鍩虹淇℃伅 ---
	if name_label:
		name_label.text = card.get_display_name() if card.has_method("get_display_name") else card.card_name
		name_label.add_theme_color_override("font_color",
			Color(1, 0.8, 0.2, 1) if card.rarity == CardData.CardRarity.SUPER else Color(1, 1, 1, 1))

	if type_label:
		var type_str := card.get_family_label() if card.has_method("get_family_label") else ""
		if type_str == "":
			match card.card_type:
				CardData.CardType.SPELL: type_str = "魔法"
				CardData.CardType.UNIT:  type_str = "单位"
				CardData.CardType.TRAP:  type_str = "陷阱"
		# Phase 23B: preserve CardVisualProfile identity; only overwrite if UNKNOWN
		if type_label.text == "" or type_label.text == "UNKNOWN":
			type_label.text = "类型: " + type_str

	if rarity_label:
		var r_str := ""
		match card.rarity:
			CardData.CardRarity.COMMON: r_str = "普通"
			CardData.CardRarity.RARE:   r_str = "稀有"
			CardData.CardRarity.SUPER:  r_str = "超级"
		rarity_label.text = "稀有度: " + r_str
		rarity_label.add_theme_color_override("font_color",
			TC.ACCENT_GOLD if card.rarity == CardData.CardRarity.SUPER else TC.TEXT_SECONDARY)

	if role_label:
		var role_str := ""
		var role_color := TC.role_color(card.archetype_role)
		match card.archetype_role:
			CardData.ArchetypeRole.STARTER:   role_str = "启动"
			CardData.ArchetypeRole.EXTENDER:  role_str = "展开"
			CardData.ArchetypeRole.CONTROL:   role_str = "控制"
			CardData.ArchetypeRole.FINISHER:  role_str = "终结"
			CardData.ArchetypeRole.DEFENSE:   role_str = "防守"
		role_label.text = "定位: " + role_str
		role_label.add_theme_color_override("font_color", role_color)

	if cost_label:
		var lines: Array[String] = []
		lines.append("OD Cost: %d" % card.od_cost)
		if card.load_cost > 0:
			lines.append("Load Cost: %d" % card.load_cost)
		if card.require_od > 0:
			lines.append("Require OD: %d" % card.require_od)
		if card.require_load > 0:
			lines.append("Require Load: %d" % card.require_load)
		if card.require_hp_cost > 0:
			lines.append("HP Cost: %d" % card.require_hp_cost)
		if card.require_awaken:
			lines.append("Require: AWAKEN")
		cost_label.text = "\n".join(lines)

	if description_label:
		var text := card.get_detail_description() if card.has_method("get_detail_description") else (card.description if card.description != "" else "(no description)")
		if card.unit_power > 0 or card.unit_defense > 0:
			if not combat_state.is_empty():
				text += "\nATK: %d  HP: %d/%d" % [card.unit_power, int(combat_state.get("current_hp", 0)), int(combat_state.get("max_hp", card.unit_defense))]
			else:
				text += "\nATK: %d  Max HP: %d" % [card.unit_power, card.unit_defense]
		text = _update_piece_badge(card, text)
		description_label.text = text

	if keyword_label:
		if card.keywords.size() > 0:
			var kw_line := ""
			for kw in card.keywords:
				kw_line += "#" + kw + "  "
			keyword_label.text = kw_line
			keyword_label.visible = true
		else:
			keyword_label.text = ""
			keyword_label.visible = false

	# --- OD Zone 鍖哄潡 ---
	_populate_zone_panels(card)
	_highlight_zone(zone_name)

	# --- Chain / Combo ---
	if chain_info_label:
		var chain_lines: Array[String] = []
		if card.chain_id != "":
			chain_lines.append("Chain: %s  Step: %d" % [card.chain_id, card.chain_step])
		if card.combo_hint != "":
			chain_lines.append("Combo: " + card.combo_hint)
		chain_info_label.text = "\n".join(chain_lines)
		chain_info_label.visible = not chain_lines.is_empty()

	# --- Route 璺嚎鍖哄潡 ---
	_populate_route_panel(card)

	# --- Phase 4C-5: 璺嚎浠峰€煎瓧娈?---
	_populate_route_value_info(card)

	# --- Flavor ---
	if flavor_text_label:
		if card.flavor_text != "":
			flavor_text_label.text = "\"" + card.flavor_text + "\""
			flavor_text_label.visible = true
		else:
			flavor_text_label.text = ""
			flavor_text_label.visible = false
	_apply_detail_mode()


func set_current_zone(zone_name: String) -> void:
	_highlight_zone(zone_name)


## Phase 27I-R0: 详情面板紧凑棋子徽记（数据驱动，不计算合法性/费用）
func _update_piece_badge(card: CardData, base_text: String) -> String:
	if card == null or not card.piece_enabled:
		return base_text
	var piece_type: StringName = card.piece_type
	var badge := _piece_badge_name(piece_type)
	if badge == "":
		return base_text
	return "【%s】%s" % [badge, base_text]


func _piece_badge_name(piece_type: StringName) -> String:
	match piece_type:
		StringName("pawn"): return "兵卒"
		StringName("knight"): return "骑士"
		StringName("bishop"): return "主教"
		StringName("rook"): return "战车"
		StringName("queen"): return "皇后"
	return ""


# ============================================================
# Phase 4C-5: 璺嚎浠峰€间俊鎭?鈥?Board Zone / OD Impact / Depth Impact / Use Hint
# ============================================================

## 鍦?RoleLabel 鍚庡姩鎬佹坊鍔犺矾绾夸环鍊煎瓧娈?
func _populate_route_value_info(card: CardData) -> void:
	var vbox := _safe_node("ScrollContainer/VBoxContainer")
	if not vbox:
		return

	# 绉婚櫎鏃х殑 ValueInfo 瀹瑰櫒锛堝鏋滃瓨鍦級
	var old_box := vbox.get_node_or_null(NodePath("ValueInfoBox"))
	if old_box and is_instance_valid(old_box):
		vbox.remove_child(old_box)
		old_box.queue_free()

	var info_box := VBoxContainer.new()
	info_box.name = "ValueInfoBox"
	info_box.add_theme_constant_override("separation", 1)

	# 鈹€鈹€ Board Zone 鈹€鈹€
	var zone_str := _get_board_zone_name(card)
	if zone_str != "":
		var zone_lbl := Label.new()
		zone_lbl.text = "Zone: " + zone_str
		zone_lbl.add_theme_font_size_override("font_size", 10)
		zone_lbl.add_theme_color_override("font_color", TC.TEXT_SECONDARY)
		zone_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.add_child(zone_lbl)

	# 鈹€鈹€ OD Impact 鈹€鈹€
	var od_lines := _get_od_impact_lines(card)
	for od_line in od_lines:
		var od_lbl := Label.new()
		od_lbl.text = od_line
		od_lbl.add_theme_font_size_override("font_size", 10)
		od_lbl.add_theme_color_override("font_color", TC.ZONE_HEATED)
		od_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.add_child(od_lbl)

	# 鈹€鈹€ Depth Impact 鈹€鈹€
	var depth_line := _get_depth_impact_line(card)
	if depth_line != "":
		var d_lbl := Label.new()
		d_lbl.text = depth_line
		d_lbl.add_theme_font_size_override("font_size", 10)
		d_lbl.add_theme_color_override("font_color", TC.WARNING)
		d_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.add_child(d_lbl)

	# 鈹€鈹€ Use Hint 鈹€鈹€
	var hint := _get_use_hint(card)
	if hint != "":
		var hint_lbl := Label.new()
		hint_lbl.text = "Tip: " + hint
		hint_lbl.add_theme_font_size_override("font_size", 9)
		hint_lbl.add_theme_color_override("font_color", TC.INFO)
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.add_child(hint_lbl)

	# 鈹€鈹€ Phase 4C-5: Abyss Lock 鏈熼棿 CONTROL 鍗℃爣"Recovery option" 鈹€鈹€
	if card.archetype_role == CardData.ArchetypeRole.CONTROL:
		var rec_lbl := Label.new()
		rec_lbl.text = "Control: Recovery option"
		rec_lbl.add_theme_font_size_override("font_size", 10)
		rec_lbl.add_theme_color_override("font_color", TC.ROLE_CONTROL)
		rec_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_box.add_child(rec_lbl)

	# 鎻掑叆鍒?VBoxContainer 涓?
	vbox.add_child(info_box)
	# 鏀惧埌 FlavorText 涔嬪墠
	if flavor_text_label and is_instance_valid(flavor_text_label):
		vbox.move_child(info_box, flavor_text_label.get_index())


## 鑾峰彇鐗屾鍖哄煙涓枃鍚?
func _get_board_zone_name(card: CardData) -> String:
	var zone := card.get_board_zone()
	match zone:
		CardData.BoardZone.FRONT_ROW: return "Front Row"
		CardData.BoardZone.BACK_ROW:  return "Back Row"
		_: return "ActionSlot -> Graveyard"
	return ""


## 鑾峰彇 OD Impact 琛屽垪琛?
func _get_od_impact_lines(card: CardData) -> Array[String]:
	var lines: Array[String] = []

	# OD 澧炲姞鏁堟灉
	for effect in card.effects:
		var effect_name: String = effect.get_class() if effect else ""
		if effect_name == "ODEffect" or effect_name == "GDScriptNativeClass":
			if "amount" in effect and effect.amount > 0:
				if not effect_name.begins_with("Enemy"):
					lines.append("OD: +%d" % effect.amount)

	# Boss OD 褰卞搷锛圗nemyODEffect锛?
	if card.card_name in ["Jam Signal", "Chain Breaker"]:
		lines.append("Boss OD: -%d" % (6 if card.card_name == "Chain Breaker" else 2))

	if card.card_name == "Cooldown":
		lines.append("OD: -2 (self)")
		lines.append("Boss OD: -2 (if Heated+)")

	# OD 闇€姹?
	if card.require_od > 0:
		lines.append("Requires OD: %d" % card.require_od)

	if lines.is_empty():
		lines.append("OD: 0")

	return lines


## 鑾峰彇 Depth Impact 鎻忚堪
func _get_depth_impact_line(card: CardData) -> String:
	match card.card_name:
		"Cooldown": return "Depth: -3 (cooldown)"
		"Heat Sink": return "Depth: -1 (if D>=3). Safe at high Depth."
		_: return ""
	return ""


## 鑾峰彇浣跨敤鎻愮ず
func _get_use_hint(card: CardData) -> String:
	match card.card_name:
		"Cooldown": return "Use to recover from Abyss Lock."
		"Heat Sink": return "Use when Depth is high for bonus shield."
		"Jam Signal": return "Set early to counter Boss OD growth."
		"Chain Breaker": return "Save for route finish - gets Route Bonus."
		"Ember Familiar": return "Good starter while Calm."
		"Ignite Blade": return "Play after Ember Familiar for Heat Route."
		"Heat Channeler": return "OD fuels this monster - play with Ignite Blade."
		"Final Slash": return "Finish Heat Route for double trigger."
		"Overdrive Eruption": return "Needs Awaken + max OD - ultimate finisher."
		"Core Cathedral": return "Build early if going Overdrive Route."
		"Overclock Pulse": return "Key extender for Overdrive Route."
		"Warm-Up Rite": return "Start Heat Route with draw and OD boost."
		"Signal Tripwire": return "Set early to counter Boss OD gain."
		"Chain Conductor": return "Follow Overclock Pulse; needs OD>=4."
		"Containment Wall": return "Protects key monsters and buildings."
		_:
			match card.archetype_role:
				CardData.ArchetypeRole.STARTER: return "Start your route or build OD."
				CardData.ArchetypeRole.EXTENDER: return "Extend your route advantage."
				CardData.ArchetypeRole.CONTROL: return "Disrupt Boss or recover Depth."
				CardData.ArchetypeRole.FINISHER: return "Unleash when ready for massive damage."
	return ""


# ============================================================
# Phase 7E-2: 璇︽儏闈㈡澘鍗″浘 鈥?鍔ㄦ€佸姞杞?512脳512 detail 鍥?
# ============================================================

## 鍦?VBoxContainer 椤堕儴鍒涘缓/鏇存柊 detail 鍗″浘
func _update_detail_art(card: CardData) -> void:
	var vbox := _safe_node("ScrollContainer/VBoxContainer")
	if not vbox:
		return

	# Use the shared mode resolver rather than a second, incomplete path chain.
	var tex: Texture2D = card.get_art_texture_for_mode(3)
	var is_detail_512 := tex != null and not card.detail_path.is_empty() and tex.resource_path == card.detail_path

	# 鏃犱换浣曠湡瀹炲崱鍥?鈫?闅愯棌 art 鍖哄煙
	if tex == null:
		if _detail_art_rect and is_instance_valid(_detail_art_rect):
			_detail_art_rect.texture = null
			_detail_art_rect.visible = false
		if _detail_art_sep and is_instance_valid(_detail_art_sep):
			_detail_art_sep.visible = false
		return

	# 鍒涘缓鎴栧鐢?TextureRect
	if not _detail_art_rect or not is_instance_valid(_detail_art_rect):
		_detail_art_rect = TextureRect.new()
		_detail_art_rect.name = "DetailArtRect"
		_detail_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 鎻掑叆鍒?VBoxContainer 鏈€椤堕儴
		vbox.add_child(_detail_art_rect)
		vbox.move_child(_detail_art_rect, 0)

	# Phase 13A: 重置 anchors 防止卡图偏移到右侧
	_detail_art_rect.anchor_left = 0.0
	_detail_art_rect.anchor_right = 0.0
	_detail_art_rect.anchor_top = 0.0
	_detail_art_rect.anchor_bottom = 0.0
	_detail_art_rect.offset_left = 0
	_detail_art_rect.offset_top = 0
	_detail_art_rect.offset_right = 0
	_detail_art_rect.offset_bottom = 0
	_detail_art_rect.scale = Vector2.ONE
	_detail_art_rect.rotation = 0.0
	_detail_art_rect.position = Vector2.ZERO
	_detail_art_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Phase 13A: 使用 SHRINK_CENTER 防止卡图横向撑爆面板
	_detail_art_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_art_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_art_rect.clip_contents = true

	# Phase 13A: 卡图区域固定紧凑 banner，限制最大宽度
	var art_w: int = 196 if is_detail_512 else 156
	var art_h: int = 128 if is_detail_512 else 104
	_detail_art_rect.custom_minimum_size = Vector2(art_w, art_h)
	_detail_art_rect.size = Vector2(art_w, art_h)

	_detail_art_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_detail_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_detail_art_rect.texture = tex
	_detail_art_rect.visible = true

	# 鍒涘缓鎴栧鐢ㄥ垎闅旂嚎
	if not _detail_art_sep or not is_instance_valid(_detail_art_sep):
		_detail_art_sep = HSeparator.new()
		_detail_art_sep.name = "DetailArtSep"
		_detail_art_sep.custom_minimum_size = Vector2(0, 2)
		_detail_art_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(_detail_art_sep)
		vbox.move_child(_detail_art_sep, 1)
	_detail_art_sep.visible = true


func clear() -> void:
	visible = false
	_pinned_detail_mode = false
	_apply_detail_mode()
	if name_label:
		name_label.text = ""
	if _detail_art_rect and is_instance_valid(_detail_art_rect):
		_detail_art_rect.visible = false


func set_visible_panel(value: bool) -> void:
	visible = value


# ============================================================
# Route 璺嚎闈㈡澘
# ============================================================

func _populate_route_panel(card: CardData) -> void:
	if card.route_id == "":
		if route_panel:
			route_panel.visible = false
		if route_separator:
			route_separator.visible = false
		return

	# 鏄剧ず璺嚎闈㈡澘
	if route_separator:
		route_separator.visible = true
	if route_panel:
		route_panel.visible = true

	# 璺嚎鍚嶇О + 棰滆壊
	var route_color := _get_route_color(card.route_id)
	if route_name_label:
		route_name_label.text = _route_display_name(card.route_id)
		route_name_label.add_theme_color_override("font_color", route_color)

	# 姝ラ
	if route_step_label:
		route_step_label.text = "步骤 %d" % card.route_step

	# 涓嬩竴寮犳帹鑽?
	if route_next_label:
		if card.next_cards.size() > 0:
			route_next_label.text = "下一张: " + ", ".join(card.next_cards)
			route_next_label.visible = true
		else:
			route_next_label.text = "路线完成"
			route_next_label.visible = true

	# 瀹屾垚濂栧姳
	if route_reward_label:
		if card.combo_reward_text != "":
			route_reward_label.text = "奖励: " + card.combo_reward_text
			route_reward_label.visible = true
		else:
			route_reward_label.visible = false

	# 鎴樻枟涓殑璺嚎鎺ㄨ崘淇℃伅
	if route_recommend_label and _chain_system:
		var rec_text := ""
		var rec_color := Color(0.7, 0.7, 0.7, 1)

		if _chain_system.is_card_next_in_route(card):
			rec_text = "[Next Step] %s" % _chain_system.get_route_display_name()
			rec_color = route_color
		elif _chain_system.is_card_in_active_route(card):
			rec_text = "%s (already played this step)" % _chain_system.get_route_display_name()
		elif card.route_id != "" and _chain_system.current_route_id == "":
			rec_text = "Start: %s" % _route_display_name(card.route_id)
		elif card.route_id != "" and card.route_id != _chain_system.current_route_id:
			rec_text = "Different Route (will switch from %s)" % _chain_system.get_route_display_name()

		route_recommend_label.text = rec_text
		route_recommend_label.add_theme_color_override("font_color", rec_color)
		route_recommend_label.visible = rec_text != ""
	elif route_recommend_label:
		# DeckBuilder 妯″紡锛氭棤 chain_system锛屾樉绀鸿矾绾跨畝浠?
		route_recommend_label.text = "Route: %s" % _route_display_name(card.route_id)
		route_recommend_label.add_theme_color_override("font_color", route_color)
		route_recommend_label.visible = true

	# 璺嚎 Panel 杈规棰滆壊
	if route_panel:
		var style := _get_route_style(card.route_id)
		if style:
			route_panel.add_theme_stylebox_override("panel", style)


func _route_display_name(route_id: String) -> String:
	match route_id:
		"heat_route": return "Heat Route"
		"overdrive_route": return "Overdrive Route"
		"control_route": return "Control Route"
		# 鏃у悕绉板吋瀹?
		"cool_route": return "Overdrive Route"
		"disrupt_route": return "Control Route"
	return route_id


func _get_route_color(route_id: String) -> Color:
	match route_id:
		"heat_route": return Color(1, 0.4, 0.1, 1)
		"overdrive_route": return Color(1, 0.15, 0.05, 1)
		"control_route": return Color(0.2, 0.5, 1, 1)
		# 鏃у悕绉板吋瀹?
		"cool_route": return Color(1, 0.15, 0.05, 1)
		"disrupt_route": return Color(0.2, 0.5, 1, 1)
	return Color(0.6, 0.6, 0.6, 1)


func _get_route_style(route_id: String) -> StyleBoxFlat:
	match route_id:
		"heat_route": return _style_route_heat
		"overdrive_route": return _style_route_cool      # 鐢ㄧ孩姗欒壊
		"control_route": return _style_route_disrupt     # 鐢ㄧ豢鑹?
		# 鏃у悕绉板吋瀹?
		"cool_route": return _style_route_cool
		"disrupt_route": return _style_route_disrupt
	return _style_route_default


# ============================================================
# 鍐呴儴锛歓one 鏄剧ず
# ============================================================

func _populate_zone_panels(card: CardData) -> void:
	if not zone_box:
		return

	var has_calm := card.calm_text != "" or card.calm_damage_bonus > 0
	var has_heated := card.heated_text != "" or card.heated_damage_bonus > 0
	var has_overdrive := card.overdrive_text != "" or card.overdrive_damage_bonus > 0 or card.overdrive_self_damage > 0

	zone_box.visible = has_calm or has_heated or has_overdrive

	if calm_panel:
		calm_panel.visible = has_calm
	if calm_text:
		var txt := card.calm_text if card.calm_text != "" else ""
		if card.calm_damage_bonus > 0:
			txt += (" (+%d DMG)" % card.calm_damage_bonus)
		calm_text.text = txt if txt != "" else "(no bonus)"

	if heated_panel:
		heated_panel.visible = has_heated
	if heated_text:
		var txt := card.heated_text if card.heated_text != "" else ""
		if card.heated_damage_bonus > 0:
			txt += (" (+%d DMG)" % card.heated_damage_bonus)
		heated_text.text = txt if txt != "" else "(no bonus)"

	if overdrive_panel:
		overdrive_panel.visible = has_overdrive
	if overdrive_text:
		var txt := card.overdrive_text if card.overdrive_text != "" else ""
		if card.overdrive_damage_bonus > 0:
			txt += (" (+%d DMG)" % card.overdrive_damage_bonus)
		if card.overdrive_self_damage > 0:
			txt += (" [Self: %d]" % card.overdrive_self_damage)
		overdrive_text.text = txt if txt != "" else "(no bonus)"


func _update_status_label(status: Dictionary) -> void:
	if not status.is_empty():
		if not _status_label:
			_status_label = Label.new()
			_status_label.name = "StatusLabel"
			_status_label.add_theme_font_size_override("font_size", 13)
			_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var vbox = _safe_node("ScrollContainer/VBoxContainer")
			if vbox and name_label:
				vbox.add_child(_status_label)
				vbox.move_child(_status_label, name_label.get_index() + 1)
		if _status_label:
			var ok: bool = status.get("ok", true)
			var reason: String = status.get("reason", "")
			if ok:
				_status_label.text = "✓ 可使用"
				_status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3, 1))
			else:
				_status_label.text = "✗ %s" % reason
				_status_label.add_theme_color_override("font_color", Color(1, 0.35, 0.25, 1))
			if status.has("hand_facts"):
				var facts: Dictionary=status.hand_facts
				_status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				_status_label.text += "\n" + str(facts.get("cost","")) + " · " + str(facts.get("context",""))
				_status_label.text += "\n" + str(facts.get("detail",""))
			_status_label.visible = true
			if status.has("back_row_facts"):
				var back_row: Dictionary = status.back_row_facts
				_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_status_label.text = "◆ 后场：%s\n%s" % [str(back_row.get("state","")),str(back_row.get("detail",""))]
				_status_label.add_theme_color_override("font_color",Color("79ffe1"))

		# Phase 5E-4: 寤虹瓚鎺ュ彛鐘舵€佽拷鍔?
		_update_building_status_in_detail(status)
	elif _status_label:
		_status_label.visible = false
		# Phase 5E-4: 娓呯悊寤虹瓚鐘舵€?
		_remove_building_status_labels()


## Phase 5E-4: 鍦ㄨ鎯呴潰鏉夸腑鏄剧ず寤虹瓚鎺ュ彛鐘舵€?
func _update_building_status_in_detail(status: Dictionary) -> void:
	if not status.has("building_ok"):
		_remove_building_status_labels()
		return

	var vbox := _safe_node("ScrollContainer/VBoxContainer")
	if not vbox:
		return

	_remove_building_status_labels()

	var b_ok: bool = status.get("building_ok", false)
	var b_reason: String = status.get("building_reason", "")
	var b_cost: String = status.get("building_cost", "")
	var b_preview: String = status.get("building_preview", "")

	# 鍒涘缓寤虹瓚鎺ュ彛鐘舵€佸鍣?
	var b_box := VBoxContainer.new()
	b_box.name = "BuildingStatusBox"
	b_box.add_theme_constant_override("separation", 1)

	# 鍒嗛殧绾?
	var sep: HSeparator = HSeparator.new()
	sep.name = "BuildingSep"
	sep.custom_minimum_size = Vector2(0, 2)
	b_box.add_child(sep)

	# 鏍囬锛氬缓绛戞帴鍙?
	var title: Label = Label.new()
	title.text = "◆ 建筑接口"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.90, 0.55, 0.22, 1))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b_box.add_child(title)

	# 鐘舵€佽
	var state_label := Label.new()
	if b_ok:
		state_label.text = "  点击发动: %s -> %s" % [b_cost, b_preview]
		state_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
	else:
		state_label.text = "  ✗ %s" % b_reason
		state_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3, 1))
	state_label.add_theme_font_size_override("font_size", 10)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b_box.add_child(state_label)

	vbox.add_child(b_box)
	# 鏀惧湪 Route 淇℃伅涔嬪悗
	var found_route_panel := vbox.get_node_or_null(NodePath("RoutePanel"))
	if found_route_panel and is_instance_valid(found_route_panel):
		vbox.move_child(b_box, found_route_panel.get_index() + 1)


func _remove_building_status_labels() -> void:
	var vbox := _safe_node("ScrollContainer/VBoxContainer")
	if not vbox:
		return
	var old_box := vbox.get_node_or_null(NodePath("BuildingStatusBox"))
	if old_box and is_instance_valid(old_box):
		vbox.remove_child(old_box)
		old_box.queue_free()


func _highlight_zone(zone_name: String) -> void:
	if calm_panel and _style_calm_inactive:
		calm_panel.add_theme_stylebox_override("panel", _style_calm_inactive)
	if heated_panel and _style_heated_inactive:
		heated_panel.add_theme_stylebox_override("panel", _style_heated_inactive)
	if overdrive_panel and _style_overdrive_inactive:
		overdrive_panel.add_theme_stylebox_override("panel", _style_overdrive_inactive)

	match zone_name:
		"Calm":
			if calm_panel:
				calm_panel.add_theme_stylebox_override("panel", _style_calm_active)
		"Heated":
			if heated_panel:
				heated_panel.add_theme_stylebox_override("panel", _style_heated_active)
		"Overdrive":
			if overdrive_panel:
				overdrive_panel.add_theme_stylebox_override("panel", _style_overdrive_active)

# ============================================================
# Phase 13F-2: Ascension preview in detail panel
# ============================================================

func _update_ascension_preview(status: Dictionary) -> void:
	if not status.has("ascension_target"):
		_remove_ascension_preview()
		return

	var vbox := _safe_node("ScrollContainer/VBoxContainer")
	if not vbox:
		return

	_remove_ascension_preview()

	var target: CardData = status.get("ascension_target")
	if target == null:
		return

	var asc_ok: bool = status.get("ascension_ok", false)
	var asc_label: String = status.get("ascension_label", "")
	var asc_reason: String = status.get("ascension_reason", "")
	var asc_preview: String = status.get("ascension_preview", "")

	# Separator
	var sep: HSeparator = HSeparator.new()
	sep.name = "AscensionSep"
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# Section box
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "AscensionPreviewBox"
	box.add_theme_constant_override("separation", 1)

	var title: Label = Label.new()
	title.name = "AscensionTitle"
	title.text = "【OD升格】"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	var target_line: Label = Label.new()
	target_line.text = "可升格为: %s" % asc_preview
	target_line.add_theme_font_size_override("font_size", 10)
	target_line.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 1))
	target_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(target_line)

	if asc_ok:
		var ok_line: Label = Label.new()
		ok_line.text = "条件满足: %s" % asc_label
		ok_line.add_theme_font_size_override("font_size", 10)
		ok_line.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3, 1))
		ok_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ok_line)
	else:
		var cond_line: Label = Label.new()
		cond_line.text = "条件: %s" % asc_reason
		cond_line.add_theme_font_size_override("font_size", 10)
		cond_line.add_theme_color_override("font_color", Color(1, 0.5, 0.3, 1))
		cond_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cond_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cond_line)

	vbox.add_child(box)
	# Place before flavor text
	if flavor_text_label and is_instance_valid(flavor_text_label):
		vbox.move_child(box, flavor_text_label.get_index())


func _remove_ascension_preview() -> void:
	var vbox := _safe_node("ScrollContainer/VBoxContainer")
	if not vbox:
		return
	for node_name in ["AscensionPreviewBox", "AscensionSep"]:
		var node := vbox.get_node_or_null(NodePath(node_name))
		if node and is_instance_valid(node):
			node.queue_free()
