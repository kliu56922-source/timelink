extends "res://ui/card_detail_panel.gd"
## Installed before the native panel's ready callback. Every native reader keeps
## the same panel/API; its actual shown identity is independent of hand caches.
signal reading_requested168a1(card: CardData)
var _reading_ref168a1: WeakRef
func reading_card168a1() -> CardData:
 return _reading_ref168a1.get_ref() if _reading_ref168a1!=null else null
func show_card(card: CardData,zone_name: String="",status: Dictionary={},combat_state: Dictionary={}) -> void:
 _reading_ref168a1=weakref(card) if is_instance_valid(card) else null
 reading_requested168a1.emit(card)
 super.show_card(card,zone_name,status,combat_state)
func clear() -> void:
 _reading_ref168a1=null;reading_requested168a1.emit(null)
 super.clear()
