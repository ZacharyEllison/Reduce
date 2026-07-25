extends Node2D

@export_subgroup("Properties")
@export var width: int = 8
@export var height: int = 8
@export var offset: int = 68

@export_subgroup("Scenes")
@export var tile_scene: PackedScene 
@export var sparkles_scene: PackedScene

@export_subgroup("Tiles")
@export var textures: Array[Texture2D] 

@export_subgroup("Cursors")
@export var open_hand_cursor: Texture2D
@export var closed_hand_cursor: Texture2D

@export var directions: Dictionary[String,Vector2i] = {
	'up': Vector2i(0,-1),
	'down': Vector2i(0,1),
	'left': Vector2i(-1,0),
	'right': Vector2i(1,0)
}

@onready var container = $Board


# State
var grid = []
var first_touch = Vector2i(-1, -1)
var is_swapping = false
var combo_count: int = 0

# Functions

func _ready():
	set_cursor(open_hand_cursor)
	randomize()
	setup_grid_array() 
	process_board_state()
	center_grid_on_screen() 
	get_viewport().size_changed.connect(center_grid_on_screen)

# Centers the board on-screen, the above conection ensures the board is centered after resizing the window
func center_grid_on_screen():	
	container.position = get_viewport_rect().size / 2.0 - Vector2(width - 1, height - 1) * offset / 2.0
	%BoardRect.position -= Vector2(offset/2,offset/2)
	%BoardRect.size = Vector2(width, height) * offset
	print(Vector2(width, height) * offset)

# Initialize grid
func setup_grid_array():
	grid = []
	for x in width:
		grid.append([])
		grid[x].resize(height)
		grid[x].fill(null)
		
	# Spawn initial pieces
	#for x in width:
		#for y in height:
			#spawn_at(x,y)
	spawn_at(width-1,height-2)
	spawn_at(width-1,height-1)

# Spawn a new tile at a certain grid position
func spawn_at(x: int, y: int, val: int=2048):
	var created_piece = tile_scene.instantiate() 
	var random_index = randi_range(0, textures.size() - 1)
	
	container.add_child(created_piece) 
	
	created_piece.set_tile_type(val, textures[0]) 
	created_piece.tile_pressed.connect(_on_tile_pressed) 
	created_piece.grid_position = Vector2i(x, y) 
	created_piece.position = grid_to_pixel(x, y) 
	
	grid[x][y] = created_piece

# Interaction
func _on_tile_pressed(grid_position: Vector2i):
	if not is_swapping:
		first_touch = grid_position
		set_cursor(closed_hand_cursor)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if first_touch != Vector2i(-1, -1):
				var local_mouse_pos = container.get_local_mouse_position()
				var direction = calculate_swipe(local_mouse_pos)
				move_all_tiles(direction)
	elif event is InputEventKey and event.is_pressed():
		Audio.play("res://sounds/tile-swap.ogg", false, randf_range(0.8, 1.2), 0.3)
		if event.keycode == KEY_UP:
			move_all_tiles(directions['up'])
		if event.keycode == KEY_DOWN:
			move_all_tiles(directions['down'])
		if event.keycode == KEY_LEFT:
			move_all_tiles(directions['left'])
		if event.keycode == KEY_RIGHT:
			move_all_tiles(directions['right'])

func calculate_swipe(final_pos: Vector2):
	var direction: Vector2i
	var difference = final_pos - grid_to_pixel(first_touch.x, first_touch.y)
	
	if difference.length() > 32:
		var other_touch = first_touch
		if abs(difference.x) > abs(difference.y): # Horizontal dragging
			if difference.x > 0: # right
				direction = Vector2i(1,0)
			else: # left
				direction = Vector2i(-1,0)
		else: # Vertical dragging
			if difference.y > 0: # down 
				direction = Vector2i(0,1)
			else: # up
				direction = Vector2i(0,-1)
		return direction
	else:
		return Vector2i(0,0)
		
	set_cursor(open_hand_cursor)
	first_touch = Vector2i(-1, -1)

func move_tile( start_position: Vector2i, end_position:Vector2i):
	var tile = grid[start_position.x][start_position.y]
	if tile && tile.type:
		tile.move_to(grid_to_pixel(end_position.x,end_position.y))
	return

# Game loop
func move_all_tiles( direction: Vector2i):
	if direction == Vector2i(0,0):
		return
	Audio.play("res://sounds/tile-swap.ogg", false, randf_range(0.8, 1.2), 0.3)
	print('move called: ', directions.find_key(direction))
	var tiles = find_tiles()
	for tile in tiles:
		var end_movement_position: Vector2i
		print('tile position: ', tile.grid_position)
		var compare_position: Vector2i = tile.grid_position + direction
		while is_within_grid(compare_position):
			print(tile.grid_position, '-->', compare_position )
			var compare_tile = get_tile(compare_position)
			if compare_tile: # end of line
				if compare_tile.type == tile.type:
					process_tile_merge(compare_tile, tile)
				# Fall through to movement
				end_movement_position = compare_position - direction
				move_tile(tile.grid_position, end_movement_position)
			compare_position += direction
		end_movement_position = compare_position - direction
		print(tile.grid_position, ' ', end_movement_position, )
		move_tile(tile.grid_position, end_movement_position)
			

func process_tile_merge(target, source):
	# sparkle
	var effect = sparkles_scene.instantiate()
	effect.position = target.position
	container.add_child(effect)
	# reduce target type
	if target.type > 1:
		target.set_tile_type(target.type / 2, textures[0])
	# clear source tile
	grid[source.grid_position.x][source.grid_position.y] = null
	# animate
	var source_tween = source.create_tween().set_parallel(true)
	source_tween.tween_property(source, "scale", Vector2.ZERO, 0.2)
	source_tween.finished.connect(source.queue_free)
	#var target_tween = target.create_tween().set_parallel(false)
	#target_tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	#target_tween.tween_property(target, "scale", Vector2(1.1, 1.1), 0.02)
	#target_tween.chain().tween_property(target, "scale", Vector2(1.0, 1.0), 0.02)


func get_tile(pos:Vector2i) -> Variant:
	var tile = grid[pos.x][pos.y]
	if tile && tile.type:
		return tile
	else:
		return null

func handle_swap_logic(pos_a: Vector2i, pos_b: Vector2i):
	#is_swapping = true
	#swap_pieces(pos_a, pos_b)
	#await get_tree().create_timer(0.3).timeout
	if find_tiles().size() > 0:
		process_board_state()
	else:
		swap_pieces(pos_a, pos_b)
		Audio.play("res://sounds/tile-swap.ogg", false, 2, 0.3)
		await get_tree().create_timer(0.3).timeout
		is_swapping = false

func swap_pieces(a: Vector2i, b: Vector2i):
	var piece_a = grid[a.x][a.y]
	var piece_b = grid[b.x][b.y]
	
	if piece_a and piece_b:
		grid[a.x][a.y] = piece_b
		grid[b.x][b.y] = piece_a
		
		piece_a.grid_position = b
		piece_b.grid_position = a
		
		piece_a.move_to(grid_to_pixel(b.x, b.y), false)
		piece_b.move_to(grid_to_pixel(a.x, a.y), false)

func find_tiles() -> Array:
	var tile_dict = {}
	for y in range(height):
		for x in range(width):
			var p1 = grid[x][y]
			if p1 and p1.type:
				tile_dict[p1] = true
	return tile_dict.keys()

func process_board_state():
	#combo_count = 0 
	var matches = find_tiles()
	print(matches[0].position)
	
	#while matches.size() > 0:
		##combo_count += 1
		#Audio.play("res://sounds/tile-match.ogg", true, 1.0 + (combo_count * 0.1))
		#
		#for piece in matches:
			#var effect = sparkles_scene.instantiate()
			#effect.position = piece.position
			#container.add_child(effect)
			#
			#grid[piece.grid_position.x][piece.grid_position.y] = null
			#var tween = piece.create_tween()
			#tween.tween_property(piece, "scale", Vector2.ZERO, 0.2)
			#tween.finished.connect(piece.queue_free)
		
		#await get_tree().create_timer(0.3).timeout/
		#await collapse_columns()
		#await refill_board()
		
		#matches = find_tiles()
	
	is_swapping = false

func collapse_columns():
	for x in width:
		for y in range(height - 1, -1, -1):
			if grid[x][y] == null:
				for k in range(y - 1, -1, -1):
					if grid[x][k] != null:
						grid[x][y] = grid[x][k]
						grid[x][k] = null
						grid[x][y].grid_position = Vector2i(x, y)
						grid[x][y].move_to(grid_to_pixel(x, y))
						break
	await get_tree().create_timer(0.3).timeout

func refill_board():
	for x in width:
		for y in height:
			if grid[x][y] == null:
				spawn_at(x, y)
				grid[x][y].position.y -= offset * 2 
				grid[x][y].move_to(grid_to_pixel(x, y))
	await get_tree().create_timer(0.3).timeout

# Utilities for coordinates
func grid_to_pixel(column: int, row: int) -> Vector2:
	return Vector2(offset * column, offset * row)

func is_within_grid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func set_cursor(cursor_texture: Texture2D):
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
