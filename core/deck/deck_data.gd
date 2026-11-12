extends Resource
class_name DeckData

@export var deck_name: String = "My Deck"
@export var cards: Array = []

const MAX_CARDS = 21

func add_card(card: CardData) -> bool:
	if cards.size() >= MAX_CARDS:
		return false
	cards.append(card)
	return true

func remove_card(card: CardData) -> void:
	cards.erase(card)
