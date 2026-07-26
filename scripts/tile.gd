extends Area2D

# The tile's color based on its value.
# Inverted palette: As tiles merge and decrease in value (2048 -> 1),
# the colors go UP in brightness and intensity.
@export var colors : Dictionary = {
	2048 : Color.ROYAL_BLUE,        # Starting tile (Level 0)
	1024 : Color.CYAN,              # 1st Merge
	512  : Color.AQUAMARINE,        # 2nd Merge
	256  : Color.SEA_GREEN,         # 3rd Merge
	128  : Color.YELLOW_GREEN,      # 4th Merge
	64   : Color.GOLD,              # 5th Merge
	32   : Color.ORANGE,            # 6th Merge
	16   : Color.FIREBRICK,         # 7th Merge
	8    : Color.MEDIUM_VIOLET_RED, # 8th Merge
	4    : Color.DEEP_PINK,         # 9th Merge
	2    : Color.CORAL,             # 10th Merge
	1    : Color.WHITE              # Final / Highest Merge Tier
}
signal tile_pressed(pos)

var type: int
var grid_position: Vector2i

@onready var label : Label = %Label
@onready var sprite : Sprite2D = $Sprite2D


# Highlight tile when hovering mouse
func _on_mouse_entered():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 1.2), 0.1) # Brighten


# Return to default state when mouse exits
func _on_mouse_exited():
	reset_tween()


# Set piece text and color when initializing or updating value
func set_tile_type(id: int, texture: Texture2D, animate_color: bool = true):
	type = id
	if texture:
		sprite.texture = texture
	label.text = str(id)

	# Fetch the color from the dictionary, defaulting to WHITE if not found
	var target_color: Color = colors.get(id, Color.WHITE)

	if animate_color:
		# Smoothly tween the sprite's base color tint (self_modulate)
		var color_tween = create_tween()
		color_tween.tween_property(sprite, "self_modulate", target_color, 0.2)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)
	else:
		sprite.self_modulate = target_color


# Letting the main code know when a tile has been pressed
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tile_pressed.emit(grid_position)
			var tween = create_tween().set_parallel(true)
			tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.05)
			tween.tween_property(sprite, "modulate", Color(0.8, 0.8, 0.8), 0.1)
		else:
			reset_tween()


# Animations when tile is moving
func move_to(target_position: Vector2, play_sound: bool = true):
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", target_position, 0.3)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	sprite.scale = Vector2(1.2, 0.8)
	tween.tween_property(sprite, "scale", Vector2(1, 1), 0.3)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)
		
	if play_sound:
		tween.finished.connect(_on_move_finished)


# Audio that plays after the tile lands on the board
func _on_move_finished():
	if Audio.has_method("play"):
		Audio.play("res://sounds/tile-land.ogg", false, 1.2 - (grid_position.y * 0.05), 0.2)


func reset_tween():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
