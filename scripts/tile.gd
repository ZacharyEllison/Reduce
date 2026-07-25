extends Area2D

# The tile's color based on its value.
@export var colors : Dictionary = {
	1 : Color.ROYAL_BLUE,
	2 : Color.CYAN,
	4 : Color.AQUAMARINE,
	8 : Color.SEA_GREEN,
	16 : Color.YELLOW_GREEN,
	32 : Color.GOLD,
	64 : Color.ORANGE,
	128 : Color.MAROON,
	256 : Color.FIREBRICK,
	512 : Color.WEB_MAROON,
	1024 : Color.MEDIUM_VIOLET_RED,
	2048 : Color.DEEP_PINK
}

signal tile_pressed(pos)

var type:int
var grid_position:Vector2i

@onready var label : Label = %Label

#func _ready() -> void:
	#label.text = str(colors.keys()[2])
# Highlight tile when hovering mouse
func _on_mouse_entered():
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property($Sprite2D, "modulate", Color(1.2, 1.2, 1.2), 0.50) # Brighten

# Return to default state when mouse exits
func _on_mouse_exited():
	reset_tween()

# Set piece text when initializing
func set_tile_type(id: int, texture: Texture2D):
	type = id
	$Sprite2D.texture = texture
	#$Sprite2D.color = colors[id]
	label.text = str(id)

# Letting the main code know when a tile has been pressed
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tile_pressed.emit(grid_position)
			var tween = create_tween().set_parallel(true)
			tween.tween_property($Sprite2D, "scale", Vector2(0.8, 0.8), 0.05)
			tween.tween_property($Sprite2D, "modulate", Color(0.8, 0.8, 0.8), 0.1)
		else:
			reset_tween()

# Animations when tile is moving
func move_to(target_position: Vector2, play_sound: bool = true):
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", target_position, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	$Sprite2D.scale = Vector2(1.2, 0.8)
	tween.tween_property($Sprite2D, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if play_sound:
		tween.finished.connect(_on_move_finished)

# Audio that plays after the tile lands on the board
func _on_move_finished():
	Audio.play("res://sounds/tile-land.ogg", false, 1.2 - (grid_position.y * 0.05), 0.2)

func reset_tween():
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1), 0.1)
