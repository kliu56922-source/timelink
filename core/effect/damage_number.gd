extends Label

var velocity := Vector2.ZERO
var gravity := 800
var lifetime := 0.8

func _ready():
	scale = Vector2(1.5, 1.5)
	modulate = Color(1, 0.4, 0.4)

func setup(value: int, is_crit: bool = false):
	text = str(value)

	if is_crit:
		scale = Vector2(2.2, 2.2)
		modulate = Color(1, 0.8, 0.2)

	velocity = Vector2(randf_range(-80, 80), -250)

func _process(delta):
	velocity.y += gravity * delta
	position += velocity * delta

	lifetime -= delta
	modulate.a = lifetime

	if lifetime <= 0:
		queue_free()