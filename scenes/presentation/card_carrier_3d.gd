extends Node3D
class_name CardCarrier3D

## Phase 22E-1: Card Carrier with stable configuration API
## Instanced per token. _ready() assembles GLBs, then external code calls configure_card().

const GLB_BASE   := "res://assets/models/card_carrier/runtime/card_carrier_base.glb"
const GLB_FRAME  := "res://assets/models/card_carrier/runtime/card_carrier_frame.glb"
const GLB_GLOW   := "res://assets/models/card_carrier/runtime/card_carrier_glow.glb"
const GLB_SOCKET := "res://assets/models/card_carrier/runtime/card_carrier_socket.glb"

const GAP := 0.003
const CARD_ART_MODE_FIELD := 1  # PLAYER_FIELD
const CARD_ART_MODE_DETAIL := 3  # DETAIL
const FIELD_PORTRAIT_TARGET_WIDTH := 1.20
const FIELD_PORTRAIT_CENTER_Y := 0.68

var _assembled := false
var _errors := 0
var _art_mat: StandardMaterial3D = null  # Per-instance material (never shared)
var _glow_mat: StandardMaterial3D = null  # Phase 27I-R0-R4: per-instance glow material (cached, never shared)
var _pending_card: CardData = null
var _pending_owner_side := "player"
var _pending_zone := "front"

# Phase 23B-R2: Building replacement target highlight
const REPLACEMENT_TARGET_COLOR := Color(1.0, 0.62, 0.12, 1.0)
var _replacement_target_highlighted := false
var _warned_no_art := false  # Phase 26B-T3: prevent spam


func _ready() -> void:
	_art_mat = StandardMaterial3D.new()
	_art_mat.albedo_color = Color(0.4, 0.4, 0.42, 1)
	_art_mat.roughness = 0.85
	_art_mat.metallic = 0.05
	_art_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # prevent light pollution on art

	_apply_art_material_to_plane()

	_load(GLB_BASE, "BaseRoot")
	_load(GLB_FRAME, "FrameRoot")
	_load(GLB_GLOW, "GlowRoot", true)
	_load(GLB_SOCKET, "SocketVisualRoot")

	await get_tree().process_frame
	_stack_components()
	_assembled = true
	_apply_pending_configuration()


func _apply_art_material_to_plane() -> void:
	var art := get_node_or_null("ArtPlane") as MeshInstance3D
	if art and _art_mat:
		for i in art.get_surface_override_material_count():
			art.set_surface_override_material(i, _art_mat)
		art.material_override = _art_mat


## Phase 27I-R0-R4: 析构前清除本载体的材质引用，避免 headless dummy renderer 在
## 场景释放时读到已失效的 material RID（`material is null` 告警）。只影响 teardown，
## 不改变战斗中的材质/美术表现。
func _exit_tree() -> void:
	_clear_material_references(self)


func _clear_material_references(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = null
		for i in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, null)
	for c in node.get_children():
		_clear_material_references(c)


# ── Public API ──

func configure_card(card: CardData, owner_side: String, zone: String) -> void:
	_pending_card = card
	_pending_owner_side = owner_side
	_pending_zone = zone
	if _assembled:
		_apply_pending_configuration()


func _apply_pending_configuration() -> void:
	if not _pending_card:
		return
	_ensure_field_portrait()
	_apply_art(_pending_card)
	_refresh_field_portrait()
	# Phase 24A-R4-R: unified refresh respects priority
	_refresh_highlight()


func set_art_texture(tex: Texture2D) -> void:
	if not _art_mat:
		_art_mat = StandardMaterial3D.new()
	_art_mat.albedo_texture = tex
	_apply_art_material_to_plane()
	var portrait := _ensure_field_portrait()
	portrait.texture = tex
	_fit_field_portrait(portrait)
	_refresh_field_portrait()


func set_glow_color(color: Color) -> void:
	var gr := get_node_or_null("GlowRoot") as Node3D
	if not gr:
		return
	# Phase 27I-R0-R4: 缓存单份 glow 材质并复用，避免每次调用创建新材质后立即弃用，
	# 导致 mesh 的 material_override/surface-override RID 指向已被释放的材质，
	# 在场景析构时触发 `material is null` 渲染告警。
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.emission_enabled = true
		_glow_mat.emission_energy_multiplier = 2.0
		_glow_mat.roughness = 0.3
		_glow_mat.metallic = 0.15
	_glow_mat.albedo_color = color
	_glow_mat.emission = color
	for c in gr.get_children():
		_override_recursive(c, _glow_mat)


func set_socket_visible(v: bool) -> void:
	var sv := get_node_or_null("SocketVisualRoot")
	if sv:
		sv.visible = v


func is_assembled() -> bool:
	return _assembled


func get_model_mount() -> Marker3D:
	return get_node_or_null("ModelMount") as Marker3D


## Phase 23C0-R: Compute combined AABB in CardCarrier root local space.
## Transforms each child mesh's AABB by the child's Transform relative to root.
func get_combined_aabb() -> AABB:
	# Collect all mesh AABBs transformed to root space, merge at the end
	var boxes: Array[AABB] = []
	_collect_mesh_boxes(self, self, boxes)
	if boxes.is_empty():
		# Fallback only when NO meshes found after full traversal
		return AABB(Vector3(-0.5, -0.08, -0.66), Vector3(1.0, 0.16, 1.32))
	var merged := boxes[0]
	for i in range(1, boxes.size()):
		merged = merged.merge(boxes[i])
	return merged


## Phase 23C0-R: Recursively collect mesh AABBs transformed to root space into an Array.
func _collect_mesh_boxes(root: Node3D, current: Node, out_boxes: Array[AABB]) -> void:
	for child in current.get_children():
		if not is_instance_valid(child):
			continue
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var local_aabb := mi.get_aabb()
			if local_aabb.size.length_squared() < 0.0001:
				continue
			# Transform mesh AABB to CardCarrier root local space
			# Phase 23C0-R2: Use global_transform so AABB is invariant under carrier world placement
			var to_root: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
			var corners := _aabb_corners(local_aabb)
			var transformed := AABB(corners[0], Vector3.ZERO)
			transformed.position = to_root * corners[0]
			for j in range(1, corners.size()):
				transformed = transformed.expand(to_root * corners[j])
			out_boxes.append(transformed)
		if child is Node3D:
			_collect_mesh_boxes(root, child, out_boxes)


func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var pos := aabb.position
	var end := aabb.end
	return [
		pos,
		Vector3(end.x, pos.y, pos.z),
		Vector3(pos.x, end.y, pos.z),
		Vector3(pos.x, pos.y, end.z),
		Vector3(end.x, end.y, pos.z),
		Vector3(end.x, pos.y, end.z),
		Vector3(pos.x, end.y, end.z),
		end,
	]


## Phase 23C0-R: Compute the token root world Y so that the carrier bottom
## sits at surface_y + target_gap in world space.
##
## Correct contract:
##   effective_scale_y = abs(token.global_basis.get_scale().y)
##   world_bottom = token_world_y + local_bottom_y × effective_scale_y
##   target: world_bottom = surface_y + target_gap
##   => token_world_y = surface_y + target_gap - local_bottom_y × effective_scale_y
##
## Returns Dictionary with diagnostic values.
func compute_contact_y(surface_y: float, target_gap: float, effective_scale_y: float = 1.0) -> Dictionary:
	if abs(effective_scale_y) < 0.0001:
		effective_scale_y = 1.0
	var aabb := get_combined_aabb()
	var local_bottom_y: float
	if aabb.size.y > 0.0001:
		local_bottom_y = aabb.position.y  # signed, typically negative
	else:
		local_bottom_y = -0.08  # fallback for un-assembled carrier

	var local_bottom_scaled: float = local_bottom_y * effective_scale_y
	var token_world_y: float = surface_y + target_gap - local_bottom_scaled
	var computed_world_bottom: float = token_world_y + local_bottom_scaled
	var actual_gap: float = computed_world_bottom - surface_y

	# Called during routine refresh; diagnostics remain available in the result.
	return {
		"carrier_y": token_world_y,
		"local_bottom_y": local_bottom_y,
		"effective_scale_y": effective_scale_y,
		"computed_world_bottom": computed_world_bottom,
		"surface_y": surface_y,
		"actual_gap": actual_gap,
		"ok": true,
	}


func toggle_socket_visual() -> void:
	var sv := get_node_or_null("SocketVisualRoot")
	if sv:
		sv.visible = not sv.visible


# ── Phase 23B-R2: Replacement target highlight ──

func set_replacement_target_highlight(active: bool) -> void:
	if _replacement_target_highlighted == active:
		return
	_replacement_target_highlighted = active
	_refresh_highlight()

func is_replacement_target_highlighted() -> bool:
	return _replacement_target_highlighted


# ── Phase 24A-R4-R: Unified highlight with priority: command > replacement > card-family default ──
const COMMAND_TARGET_COLOR := Color(1.0, 0.68, 0.12, 1.0)
# Phase 26E: movement source highlight
const MOVEMENT_SOURCE_COLOR := Color(0.3, 0.85, 0.85, 1.0)
var _movement_source_highlighted := false

var _command_target_highlighted := false


func set_command_target_highlight(active: bool) -> void:
	if _command_target_highlighted == active:
		return
	_command_target_highlighted = active
	_refresh_highlight()


func is_command_target_highlighted() -> bool:
	return _command_target_highlighted


# Phase 26C: Core Command target highlight (highest priority, cyan)
const CORE_COMMAND_TARGET_COLOR := Color(0.35, 0.90, 1.0, 1.0)
var _core_command_target_highlighted := false


func set_core_command_target_highlight(active: bool) -> void:
	if _core_command_target_highlighted == active:
		return
	_core_command_target_highlighted = active
	_refresh_highlight()


func is_core_command_target_highlighted() -> bool:
	return _core_command_target_highlighted


func set_movement_source_highlight(active: bool) -> void:
	if _movement_source_highlighted == active:
		return
	_movement_source_highlighted = active
	_refresh_highlight()

func is_movement_source_highlighted() -> bool:
	return _movement_source_highlighted

## Priority: core-command (cyan) > monster-command (orange) > movement source (teal) > replacement (gold) > card-family default
func _refresh_highlight() -> void:
	if _core_command_target_highlighted:
		set_glow_color(CORE_COMMAND_TARGET_COLOR)
		set_socket_visible(true)
	elif _command_target_highlighted:
		set_glow_color(COMMAND_TARGET_COLOR)
		set_socket_visible(true)
	elif _movement_source_highlighted:
		set_glow_color(MOVEMENT_SOURCE_COLOR)
		set_socket_visible(true)
	elif _replacement_target_highlighted:
		set_glow_color(REPLACEMENT_TARGET_COLOR)
		set_socket_visible(true)
	elif _pending_card:
		_apply_glow(_pending_card, _pending_owner_side)
		set_socket_visible(false)
	else:
		set_glow_color(Color(0.14, 0.38, 0.78, 1))
		set_socket_visible(false)


# ── Internal: Art ──

func _ensure_field_portrait() -> Sprite3D:
	var portrait := get_node_or_null("FieldPortrait") as Sprite3D
	if portrait != null:
		return portrait
	portrait = Sprite3D.new()
	portrait.name = "FieldPortrait"
	portrait.position = Vector3(0.0, FIELD_PORTRAIT_CENTER_Y, 0.0)
	portrait.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	portrait.shaded = false
	portrait.double_sided = true
	portrait.visible = false
	add_child(portrait)
	return portrait


func _fit_field_portrait(portrait: Sprite3D) -> void:
	if portrait == null or portrait.texture == null:
		return
	var texture_width := maxi(1, portrait.texture.get_width())
	portrait.pixel_size = FIELD_PORTRAIT_TARGET_WIDTH / float(texture_width)


func _refresh_field_portrait() -> void:
	var portrait := get_node_or_null("FieldPortrait") as Sprite3D
	if portrait == null:
		return
	var is_front_unit := false
	if _pending_card != null and _pending_zone == "front":
		is_front_unit = _pending_card.is_front_row_card()
	portrait.visible = is_front_unit and portrait.texture != null

func _apply_art(card: CardData) -> void:
	## Current card owns its picture. Missing content returns to the existing placeholder.
	if not card:
		return
	var tex: Texture2D = null
	if card.has_method("get_art_texture_for_mode"):
		tex = card.get_art_texture_for_mode(CARD_ART_MODE_FIELD) as Texture2D
	if not tex and card.has_method("get_art_texture"):
		tex = card.get_art_texture() as Texture2D
	if tex:
		set_art_texture(tex)
		_warned_no_art = false
	else:
		# Truly no texture ever loaded: minimal gray (only first frame before any art)
		_art_mat.albedo_texture = null
		_art_mat.albedo_color = Color(0.25, 0.25, 0.28, 1)
		var portrait := get_node_or_null("FieldPortrait") as Sprite3D
		if portrait != null:
			portrait.texture = null
			portrait.visible = false
		if not _warned_no_art:
			print_rich("[color=yellow][PRESENTATION WARN][/color] CardCarrier: no art for %s, showing placeholder" % (card.card_name if "card_name" in card else "?"))
			_warned_no_art = true
	_apply_art_material_to_plane()


# ── Internal: Glow ──

func _apply_glow(card: CardData, owner_side: String) -> void:
	if not card:
		return
	var family := card.card_family.to_lower() if "card_family" in card else ""
	var color: Color
	match family:
		"monster":   color = Color(0.90, 0.40, 0.12, 1)  # orange-copper
		"build":     color = Color(0.80, 0.55, 0.15, 1)  # brass-gold
		"counter":   color = Color(0.10, 0.70, 0.45, 1)  # cyan-green
		"spell":     color = Color(0.25, 0.55, 0.85, 1)  # blue-white
		"finisher":  color = Color(0.95, 0.25, 0.10, 1)  # gold-red
		"arsenal":   color = Color(0.95, 0.30, 0.08, 1)  # gold-red
		_:           color = Color(0.14, 0.38, 0.78, 1)  # default blue

	# Boss tint: add cinnabar red bias
	if owner_side == "boss":
		color = color.lerp(Color(0.85, 0.18, 0.05, 1), 0.35)

	set_glow_color(color)


# ── Internal: GLB loading ──

func _load(path: String, parent_name: String, emissive := false) -> Node3D:
	var parent := get_node_or_null(parent_name)
	if not parent:
		printerr("[Carrier] Missing: " + parent_name); _errors += 1; return null
	if not FileAccess.file_exists(path):
		printerr("[Carrier] Missing file: " + path); _errors += 1; return null

	var inst: Node3D = null
	if ResourceLoader.exists(path, "PackedScene"):
		var scn := load(path) as PackedScene
		if scn: inst = scn.instantiate() as Node3D
	if not inst:
		var gltf := GLTFDocument.new(); var st := GLTFState.new()
		if gltf.append_from_file(path, st) == OK:
			inst = gltf.generate_scene(st) as Node3D
	if not inst:
		printerr("[Carrier] Load failed: " + path); _errors += 1; return null

	inst.name = parent_name + "Model"
	parent.add_child(inst)
	if emissive:
		_glow_default(inst)
	return inst


func _glow_default(node: Node) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0.85, 0.95, 1)
	m.emission_enabled = true; m.emission = Color(0, 0.7, 0.85, 1)
	m.emission_energy_multiplier = 2.5; m.roughness = 0.3; m.metallic = 0.15
	_override_recursive(node, m)


func _override_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = mat
		for i in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_override_recursive(c, mat)


func _stack_components() -> void:
	var ba := _get_mesh_aabb(get_node("BaseRoot"))
	var fa := _get_mesh_aabb(get_node("FrameRoot"))
	if ba.size.y < 0.0001 or fa.size.y < 0.0001:
		return
	var base_top := ba.end.y
	var fr := get_node("FrameRoot") as Node3D
	if fr:
		fr.position.y = base_top + GAP
	var art := get_node_or_null("ArtPlane") as MeshInstance3D
	if art:
		art.position.y = base_top + GAP + 0.001
	var gr := get_node("GlowRoot") as Node3D
	if gr:
		gr.position.y = base_top + GAP + 0.001
	var sr := get_node("SocketVisualRoot") as Node3D
	if sr:
		sr.position.y = base_top + GAP
	var mm := get_node_or_null("ModelMount") as Marker3D
	if mm:
		mm.position.y = base_top + GAP + 0.015


func _get_mesh_aabb(node: Node) -> AABB:
	var aabb := AABB(); var first := true
	for c in node.get_children():
		if c is MeshInstance3D:
			var ma := (c as MeshInstance3D).get_aabb()
			aabb = ma if first else aabb.merge(ma); first = false
		if c is Node3D:
			var ca := _get_mesh_aabb(c)
			if ca.size.length_squared() > 0.0001:
				aabb = ca if first else aabb.merge(ca); first = false
	return aabb


# ── Phase 25E: Combat Stats Badge ──

var _pending_combat_stats: Dictionary = {}

func _ensure_combat_stats_badge() -> Label3D:
	var label := get_node_or_null("CombatStatsBadge") as Label3D
	if label != null:
		return label
	label = Label3D.new()
	label.name = "CombatStatsBadge"
	label.font_size = 16
	label.pixel_size = 0.0018
	label.outline_size = 2
	label.modulate = Color(1.0, 0.92, 0.72, 1.0)
	label.outline_modulate = Color(0.03, 0.04, 0.08, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 0.28, 0.02)
	label.visible = false
	add_child(label)
	return label

func set_combat_stats(atk: int, current_hp: int, max_hp: int) -> void:
	_pending_combat_stats = {"atk": maxi(0, atk), "current_hp": maxi(0, current_hp), "max_hp": maxi(1, max_hp)}
	var label := _ensure_combat_stats_badge()
	label.text = "攻%d · 血%d/%d" % [_pending_combat_stats.atk, _pending_combat_stats.current_hp, _pending_combat_stats.max_hp]
	label.visible = true

func clear_combat_stats() -> void:
	_pending_combat_stats.clear()
	var label := get_node_or_null("CombatStatsBadge") as Label3D
	if label != null:
		label.text = ""
		label.visible = false
