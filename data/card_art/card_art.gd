extends Sprite2D

var card_data: CardData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(data: CardData):
	card_data = data
	_apply_frame()

func _apply_frame():
	if not card_data:
		return
		
	match card_data.frame_style:
		"attack":
			modulate = Color(1,0.5,0.5)
		"defense":
			modulate = Color(0.5,0.5,1)