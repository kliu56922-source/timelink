extends RefCounted
class_name BoardPieceRegistry

var _model_paths: Dictionary = {}
var _disabled_ids: Dictionary = {}
var _piece_scales: Dictionary = {}
var _piece_y_offsets: Dictionary = {}
var _placeholder_body_sizes: Dictionary = {}
var _placeholder_core_sizes: Dictionary = {}


func load_from_config(config_path: String) -> void:
	if not FileAccess.file_exists(config_path):
		push_warning("[BoardPieceRegistry] Config not found: %s" % config_path)
		return

	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("[BoardPieceRegistry] Cannot open config: %s" % config_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[BoardPieceRegistry] Invalid JSON config: %s" % config_path)
		return

	var models = parsed.get("models", [])
	if typeof(models) != TYPE_ARRAY:
		push_warning("[BoardPieceRegistry] Config has no models array: %s" % config_path)
		return

	for item in models:
		if typeof(item) == TYPE_DICTIONARY:
			_load_model_entry(item)


func register_piece(card_id: String, scene_path: String) -> void:
	var key := card_id.strip_edges()
	if key == "" or scene_path.strip_edges() == "":
		return
	_model_paths[key] = scene_path
	_disabled_ids.erase(key)


func unregister_piece(card_id: String) -> void:
	var key := card_id.strip_edges()
	_model_paths.erase(key)
	_disabled_ids[key] = true


func get_piece_scene_path(card: CardData) -> String:
	if card == null:
		return ""
	for key in _get_card_lookup_keys(card):
		if _disabled_ids.has(key):
			return ""
		if _model_paths.has(key):
			return str(_model_paths[key])
	return ""


func has_piece_scene(card: CardData) -> bool:
	var path := get_piece_scene_path(card)
	return path != "" and ResourceLoader.exists(path)


func get_piece_scale(card: CardData, _owner_side: String = "player", row_kind: String = "front") -> Vector3:
	var override = _get_card_override(_piece_scales, card)
	if override is Vector3:
		return override

	var family := _family(card)
	if row_kind == "back":
		return Vector3(0.76, 0.76, 0.76)
	if family == "monster":
		return Vector3(1.0, 1.0, 1.0)
	if family == "building":
		return Vector3(0.92, 0.92, 0.92)
	if family == "counter":
		return Vector3(0.82, 0.82, 0.82)
	return Vector3(0.9, 0.9, 0.9)


func get_placeholder_body_size(card: CardData, row_kind: String = "front") -> Vector3:
	var override = _get_card_override(_placeholder_body_sizes, card)
	if override is Vector3:
		return override

	var family := _family(card)
	if row_kind == "back":
		return Vector3(0.72, 0.14, 0.42)
	if family == "monster":
		return Vector3(0.62, 0.34, 0.48)
	if family == "building":
		return Vector3(0.78, 0.30, 0.54)
	if family == "counter":
		return Vector3(0.70, 0.12, 0.44)
	return Vector3(0.74, 0.16, 0.44)


func get_placeholder_core_size(card: CardData, row_kind: String = "front") -> Vector3:
	var override = _get_card_override(_placeholder_core_sizes, card)
	if override is Vector3:
		return override

	if row_kind == "back":
		return Vector3(0.50, 0.032, 0.06)
	var family := _family(card)
	if family == "monster":
		return Vector3(0.44, 0.045, 0.10)
	if family == "building":
		return Vector3(0.56, 0.05, 0.10)
	return Vector3(0.48, 0.04, 0.08)


func get_piece_y_offset(card: CardData, row_kind: String = "front") -> float:
	var override = _get_card_override(_piece_y_offsets, card)
	if typeof(override) == TYPE_FLOAT or typeof(override) == TYPE_INT:
		return float(override)

	if row_kind == "back":
		return 0.10
	var family := _family(card)
	if family == "monster":
		return 0.20
	if family == "building":
		return 0.18
	return 0.12


func get_piece_color(card: CardData, owner_side: String = "player") -> Color:
	if owner_side == "boss":
		return Color(0.55, 0.16, 0.08, 0.95)
	var family := _family(card)
	if family == "monster":
		return Color(0.78, 0.38, 0.13, 0.95)
	if family == "building":
		return Color(0.70, 0.50, 0.22, 0.95)
	if family == "counter":
		return Color(0.08, 0.62, 0.40, 0.92)
	return Color(0.14, 0.38, 0.78, 0.92)


func get_piece_trim_color(card: CardData, owner_side: String = "player") -> Color:
	if owner_side == "boss":
		return Color(1.0, 0.34, 0.1, 1)
	var family := _family(card)
	if family == "monster":
		return Color(1.0, 0.62, 0.2, 1)
	if family == "building":
		return Color(1.0, 0.78, 0.28, 1)
	if family == "counter":
		return Color(0.18, 1.0, 0.62, 1)
	return Color(0.25, 0.85, 1.0, 1)


func _load_model_entry(entry: Dictionary) -> void:
	var key := str(entry.get("card_id", entry.get("id", ""))).strip_edges()
	if key == "":
		return

	var enabled := bool(entry.get("enabled", true))
	var scene_path := str(entry.get("scene_path", "")).strip_edges()
	if enabled and scene_path != "":
		_model_paths[key] = scene_path
		_disabled_ids.erase(key)
	else:
		_model_paths.erase(key)
		_disabled_ids[key] = true

	if entry.has("scale"):
		_piece_scales[key] = _vector3_from_array(entry.get("scale"), Vector3.ONE)
	if entry.has("y_offset"):
		_piece_y_offsets[key] = float(entry.get("y_offset", 0.0))
	if entry.has("placeholder_body"):
		_placeholder_body_sizes[key] = _vector3_from_array(entry.get("placeholder_body"), Vector3.ZERO)
	if entry.has("placeholder_core"):
		_placeholder_core_sizes[key] = _vector3_from_array(entry.get("placeholder_core"), Vector3.ZERO)


func _vector3_from_array(value, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY or value.size() < 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _get_card_override(source: Dictionary, card: CardData):
	if card == null:
		return null
	for key in _get_card_lookup_keys(card):
		if source.has(key):
			return source[key]
	return null


func _get_card_lookup_keys(card: CardData) -> Array[String]:
	var keys: Array[String] = []
	if card == null:
		return keys
	for raw_key in [card.card_id, card.card_name, card.display_name, card.english_name]:
		var key := str(raw_key).strip_edges()
		if key != "" and not keys.has(key):
			keys.append(key)
	return keys


func _family(card: CardData) -> String:
	if card == null:
		return ""
	var family := str(card.card_family).to_lower()
	if family == "build":
		return "building"
	return family
