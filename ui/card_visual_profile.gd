class_name CardVisualProfile
extends RefCounted

const MONSTER_COLOR := Color("e06b32")
const BUILDING_COLOR := Color("c5a35a")
const COUNTER_COLOR := Color("39c89e")
const SPELL_COLOR := Color("488fe5")
const FALLBACK_COLOR := Color("8c96a8")


static func from_card(card: CardData) -> Dictionary:
	if card == null:
		return {
			"family_key": "unknown",
			"family_label": "UNKNOWN",
			"accent": FALLBACK_COLOR,
			"display_label": "",
			"is_finisher": false,
		}

	var family_key := str(card.card_family).to_lower()
	var family_label := "UNKNOWN"
	var accent := FALLBACK_COLOR
	match family_key:
		"monster":
			family_label = "MONSTER"
			accent = MONSTER_COLOR
		"building":
			family_label = "BUILD"
			accent = BUILDING_COLOR
		"counter":
			family_label = "COUNTER"
			accent = COUNTER_COLOR
		"spell":
			family_label = "SPELL"
			accent = SPELL_COLOR
		_:
			family_key = "unknown"

	return {
		"family_key": family_key,
		"family_label": family_label,
		"accent": accent,
		"display_label": _display_type_label(card),
		"is_finisher": card.archetype_role == CardData.ArchetypeRole.FINISHER,
	}


static func _display_type_label(card: CardData) -> String:
	var display_type: int = card.get_display_type() if card.has_method("get_display_type") else card.display_type
	match display_type:
		CardData.DisplayType.UNIT:
			return "UNIT"
		CardData.DisplayType.SUSTAIN:
			return "SUSTAIN"
		CardData.DisplayType.TRAP:
			return "TRAP"
		_:
			return ""
