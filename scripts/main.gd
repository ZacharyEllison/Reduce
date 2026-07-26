extends Node2D

@export_subgroup("Properties")
@export var width: int = 4
@export var height: int = 4
@export var offset: int = 68
@export var default_spawn_value: int = 2048

@export_subgroup("Scenes")
@export var tile_scene: PackedScene 
@export var sparkles_scene: PackedScene

@export_subgroup("Tiles")
@export var textures: Array[Texture2D] 

@export_subgroup("Cursors")
@export var open_hand_cursor: Texture2D
@export var closed_hand_cursor: Texture2D

const DIRECTIONS = {
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0)
}

@onready var container: Node2D = $Board

# Game Over Canvas Layer & Centered UI
var game_over_layer: CanvasLayer
var game_over_panel: PanelContainer
var score_label: Label
var game_over_title: Label
var retry_button: Button

# Board State
var grid: Array = []
var first_touch: Vector2i = Vector2i(-1, -1)
var is_moving: bool = false
var is_game_over: bool = false


func _ready() -> void:
	set_cursor(open_hand_cursor)
	randomize()
	setup_grid_array()
	setup_game_over_ui()
	center_grid_on_screen()
	get_viewport().size_changed.connect(center_grid_on_screen)
	
	# Spawn initial tiles
	spawn_random_tile()
	spawn_random_tile()


func setup_grid_array() -> void:
	grid = []
	for x in width:
		var col = []
		col.resize(height)
		col.fill(null)
		grid.append(col)


# Centers the board container and locks the Game Over panel directly to its size/position
func center_grid_on_screen() -> void:
	var board_size = Vector2(width, height) * offset
	var board_pos = get_viewport_rect().size / 2.0 - Vector2(width - 1, height - 1) * offset / 2.0
	
	container.position = board_pos
	
	if has_node("%BoardRect"):
		%BoardRect.position = -Vector2(offset / 2.0, offset / 2.0)
		%BoardRect.size = board_size

	# Align Game Over Card to match the exact size and position of the board
	if game_over_panel:
		var top_left = board_pos - Vector2(offset / 2.0, offset / 2.0)
		game_over_panel.position = top_left
		game_over_panel.custom_minimum_size = board_size
		game_over_panel.size = board_size


# --- Centered Game Over UI Setup ---

func setup_game_over_ui() -> void:
	game_over_layer = CanvasLayer.new()
	add_child(game_over_layer)

	# Main Card Panel directly overlaying board
	game_over_panel = PanelContainer.new()
	game_over_panel.modulate = Color(1, 1, 1, 0)
	game_over_panel.hide()
	game_over_layer.add_child(game_over_panel)

	# Style panel dark semi-transparent card background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.85)
	style_box.set_corner_radius_all(12)
	game_over_panel.add_theme_stylebox_override("panel", style_box)

	# Centered vertical layout container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	game_over_panel.add_child(vbox)

	# Game Over Title
	game_over_title = Label.new()
	game_over_title.text = "GAME OVER"
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title.add_theme_font_size_override("font_size", 32)
	game_over_title.modulate = Color.DEEP_PINK
	vbox.add_child(game_over_title)

	# Final Score Display
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(score_label)

	# Retry Button
	retry_button = Button.new()
	retry_button.text = "Try Again"
	retry_button.custom_minimum_size = Vector2(120, 36)
	retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_button.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry_button)


# --- Spawning ---

func spawn_at(x: int, y: int, val: int = default_spawn_value) -> void:
	if not is_within_grid(Vector2i(x, y)) or grid[x][y] != null:
		return

	var created_piece = tile_scene.instantiate()
	container.add_child(created_piece)

	var tex = textures[0] if textures.size() > 0 else null
	if created_piece.has_method("set_tile_type"):
		created_piece.set_tile_type(val, tex)
	elif "type" in created_piece:
		created_piece.type = val

	if created_piece.has_signal("tile_pressed"):
		created_piece.tile_pressed.connect(_on_tile_pressed)

	created_piece.grid_position = Vector2i(x, y)
	created_piece.position = grid_to_pixel(x, y)
	grid[x][y] = created_piece


func spawn_random_tile() -> void:
	var empty_cells = []
	for x in width:
		for y in height:
			if grid[x][y] == null:
				empty_cells.append(Vector2i(x, y))

	if empty_cells.is_empty():
		return

	var pos = empty_cells.pick_random()
	var spawn_val = 2048 if randf() < 0.9 else 1024
	spawn_at(pos.x, pos.y, spawn_val)


# --- Input Handling ---

func _on_tile_pressed(grid_pos: Vector2i) -> void:
	if not is_moving and not is_game_over:
		first_touch = grid_pos
		set_cursor(closed_hand_cursor)


func _input(event: InputEvent) -> void:
	if is_moving or is_game_over:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if first_touch != Vector2i(-1, -1):
				var local_mouse_pos = container.get_local_mouse_position()
				var direction = calculate_swipe(local_mouse_pos)
				if direction != Vector2i.ZERO:
					move_all_tiles(direction)
				set_cursor(open_hand_cursor)
				first_touch = Vector2i(-1, -1)

	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var direction = Vector2i.ZERO
		match event.keycode:
			KEY_UP: direction = DIRECTIONS["up"]
			KEY_DOWN: direction = DIRECTIONS["down"]
			KEY_LEFT: direction = DIRECTIONS["left"]
			KEY_RIGHT: direction = DIRECTIONS["right"]

		if direction != Vector2i.ZERO:
			move_all_tiles(direction)


func calculate_swipe(final_pos: Vector2) -> Vector2i:
	var start_pixel = grid_to_pixel(first_touch.x, first_touch.y)
	var difference = final_pos - start_pixel

	if difference.length() > 32:
		if abs(difference.x) > abs(difference.y):
			return Vector2i(1, 0) if difference.x > 0 else Vector2i(-1, 0)
		else:
			return Vector2i(0, 1) if difference.y > 0 else Vector2i(0, -1)
			
	return Vector2i.ZERO


# --- Core Game Loop ---

func move_all_tiles(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return

	is_moving = true
	var board_changed = false
	var merged_tiles = []

	var x_range = range(width)
	var y_range = range(height)

	if direction.x > 0: x_range = range(width - 1, -1, -1)
	if direction.y > 0: y_range = range(height - 1, -1, -1)

	for x in x_range:
		for y in y_range:
			var tile = grid[x][y]
			if tile == null:
				continue

			var current = Vector2i(x, y)
			var next = current + direction

			while is_within_grid(next) and grid[next.x][next.y] == null:
				current = next
				next += direction

			if is_within_grid(next):
				var target_tile = grid[next.x][next.y]
				if target_tile != null and target_tile.type == tile.type and not target_tile in merged_tiles:
					grid[x][y] = null
					var new_value = max(1, target_tile.type / 2)

					if tile.has_method("move_to"):
						tile.move_to(grid_to_pixel(next.x, next.y))
					else:
						tile.position = grid_to_pixel(next.x, next.y)

					process_tile_merge(target_tile, tile, new_value)
					merged_tiles.append(target_tile)
					board_changed = true
					continue

			if current != Vector2i(x, y):
				grid[x][y] = null
				grid[current.x][current.y] = tile
				tile.grid_position = current
				
				if tile.has_method("move_to"):
					tile.move_to(grid_to_pixel(current.x, current.y))
				else:
					tile.position = grid_to_pixel(current.x, current.y)
					
				board_changed = true

	if board_changed:
		if Audio.has_method("play"):
			Audio.play("res://sounds/tile-swap.ogg", false, randf_range(0.8, 1.2), 0.3)
		await get_tree().create_timer(0.15).timeout
		
		spawn_random_tile()
		
		if check_game_over():
			trigger_game_over()

	is_moving = false


func process_tile_merge(target: Node2D, source: Node2D, new_value: int) -> void:
	if sparkles_scene:
		var effect = sparkles_scene.instantiate()
		effect.position = grid_to_pixel(target.grid_position.x, target.grid_position.y)
		container.add_child(effect)

	var tex = textures[0] if textures.size() > 0 else null
	if target.has_method("set_tile_type"):
		target.set_tile_type(new_value, tex)
	elif "type" in target:
		target.type = new_value

	var tween = source.create_tween()
	tween.tween_property(source, "scale", Vector2.ZERO, 0.15)
	tween.finished.connect(source.queue_free)


# --- Game Over, Scoring & Reset ---

func check_game_over() -> bool:
	for x in width:
		for y in height:
			if grid[x][y] == null:
				return false

	for x in width:
		for y in height:
			var current_tile = grid[x][y]
			if current_tile == null:
				continue
			
			var check_directions = [Vector2i(1, 0), Vector2i(0, 1)]
			for dir in check_directions:
				var neighbor_pos = Vector2i(x, y) + dir
				if is_within_grid(neighbor_pos):
					var neighbor_tile = grid[neighbor_pos.x][neighbor_pos.y]
					if neighbor_tile != null and neighbor_tile.type == current_tile.type:
						return false

	return true


func calculate_total_score() -> int:
	var total_score: int = 0
	for x in width:
		for y in height:
			var tile = grid[x][y]
			if tile != null:
				total_score += tile.type
	return total_score


func trigger_game_over() -> void:
	is_game_over = true
	var final_score = calculate_total_score()
	score_label.text = "Score: " + str(final_score)

	set_cursor(open_hand_cursor)
	game_over_panel.show()

	# Pivot UI card scaling from center
	game_over_panel.pivot_offset = game_over_panel.size / 2.0
	game_over_panel.scale = Vector2(0.8, 0.8)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(game_over_panel, "modulate", Color.WHITE, 0.3)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(game_over_panel, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


func _on_retry_pressed() -> void:
	# Fade out Game Over UI
	var tween = create_tween()
	tween.tween_property(game_over_panel, "modulate", Color(1, 1, 1, 0), 0.2)
	await tween.finished
	game_over_panel.hide()

	# Clear active tiles
	for child in container.get_children():
		if child != get_node_or_null("%BoardRect"):
			child.queue_free()

	setup_grid_array()
	is_game_over = false

	# Respawn initial board
	spawn_random_tile()
	spawn_random_tile()


# --- Helpers ---

func is_within_grid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func grid_to_pixel(col: int, row: int) -> Vector2:
	return Vector2(col * offset, row * offset)


func set_cursor(cursor_texture: Texture2D) -> void:
	if cursor_texture:
		Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
