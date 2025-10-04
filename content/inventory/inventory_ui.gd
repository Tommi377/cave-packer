extends Control
class_name InventoryUI

## Two-zone inventory system: Player Inventory + Drop Zone List
## Player must enter inventory mode to interact with items

signal inventory_mode_changed(is_active: bool)

@export var cell_size: int = 32
@export var cell_padding: int = 2
@export var show_grid_lines: bool = true
@export var pickup_radius: float = 80.0
@export var drop_item_height: int = 36

@onready var inventory_grid: InventoryGrid = $InventoryGrid
@onready var info_label: Label = $InfoPanel/InfoLabel

var held_item: Dictionary = {}
var held_from_drop_zone: bool = false # Track if item came from drop zone
var held_rotation: int = 0
var preview_position: Vector2i = Vector2i(-1, -1)
var preview_valid: bool = false

var inventory_mode_active: bool = false
var player_reference: Node2D = null

# Drop zone as a simple scrollable list
var drop_zone_items: Array[Dictionary] = []
var drop_zone_scroll_offset: float = 0.0
var drop_zone_hovered_index: int = -1

# UI Layout - Fullscreen with drop zone on left, inventory on right
var screen_size: Vector2
var drop_zone_offset: Vector2
var drop_zone_width: float = 400
var drop_zone_height: float
var player_zone_offset: Vector2
var background_color: Color = Color(0, 0, 0, 0.7) # Semi-transparent dark background

func _ready() -> void:
	if inventory_grid:
		inventory_grid.item_placed.connect(_on_item_placed)
		inventory_grid.item_removed.connect(_on_item_removed)
		inventory_grid.grid_full.connect(_on_grid_full)
	
	# Calculate layout when ready
	_calculate_layout()
	
	visible = false
	inventory_mode_active = false
	_update_ui()

func _calculate_layout() -> void:
	# Get viewport size for fullscreen layout
	screen_size = get_viewport_rect().size
	
	# Drop zone on left side
	var margin = 40.0
	drop_zone_offset = Vector2(margin, margin + 40)
	drop_zone_height = screen_size.y - (margin * 2) - 80
	
	# Player inventory on right side
	var grid_width = inventory_grid.grid_width if inventory_grid else 5
	var grid_height = inventory_grid.grid_height if inventory_grid else 5
	var grid_pixel_width = grid_width * cell_size + (grid_width - 1) * cell_padding
	var grid_pixel_height = grid_height * cell_size + (grid_height - 1) * cell_padding
	
	# Center the inventory grid on the right side
	var right_side_x = screen_size.x * 0.5 + margin
	var available_right_width = screen_size.x - right_side_x - margin
	player_zone_offset = Vector2(
		right_side_x + (available_right_width - grid_pixel_width) * 0.5,
		(screen_size.y - grid_pixel_height) * 0.5
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory_mode()
		accept_event()
		return
	
	if not inventory_mode_active:
		return
	
	if held_item.is_empty():
		return
	
	# Rotate held item
	if event.is_action_pressed("rotate_left"):
		held_rotation = (held_rotation - 1) % 4
		_update_preview()
		accept_event()
	elif event.is_action_pressed("rotate_right"):
		held_rotation = (held_rotation + 1) % 4
		_update_preview()
		accept_event()
	
	# Place item
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		if preview_valid and preview_position != Vector2i(-1, -1):
			_place_held_item()
			accept_event()
	
	# Cancel
	elif event.is_action_pressed("ui_cancel"):
		_return_held_item()
		accept_event()

func toggle_inventory_mode() -> void:
	inventory_mode_active = not inventory_mode_active
	visible = inventory_mode_active
	
	if inventory_mode_active:
		_calculate_layout() # Recalculate layout when opening
		_refresh_drop_zone()
	else:
		held_item = {}
		held_rotation = 0
		preview_position = Vector2i(-1, -1)
		held_from_drop_zone = false
	
	inventory_mode_changed.emit(inventory_mode_active)
	_update_ui()

func _refresh_drop_zone() -> void:
	drop_zone_items.clear()
	drop_zone_scroll_offset = 0.0
	
	if not player_reference:
		return
	
	var nearby_ores = _get_nearby_ores()
	
	for ore in nearby_ores:
		if ore.has_method("get_inventory_data"):
			var ore_data = ore.get_inventory_data()
			ore_data["world_node"] = ore
			drop_zone_items.append(ore_data)
	
	queue_redraw()

func _get_nearby_ores() -> Array[Node2D]:
	var result: Array[Node2D] = []
	
	if not player_reference:
		return result
	
	var all_ores = get_tree().get_nodes_in_group("ore_items")
	
	for ore in all_ores:
		if ore is Node2D:
			var distance = player_reference.global_position.distance_to(ore.global_position)
			if distance <= pickup_radius:
				result.append(ore)
	
	return result

func _gui_input(event: InputEvent) -> void:
	if not inventory_mode_active:
		return
	
	if event is InputEventMouseMotion:
		_update_mouse_preview(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not held_item.is_empty() and preview_valid:
				_place_held_item()
			else:
				_try_pickup_at_mouse(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not held_item.is_empty():
				_return_held_item()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			drop_zone_scroll_offset = max(0, drop_zone_scroll_offset - 20)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var max_scroll = max(0, drop_zone_items.size() * drop_item_height - drop_zone_height)
			drop_zone_scroll_offset = min(max_scroll, drop_zone_scroll_offset + 20)
			queue_redraw()

func _draw() -> void:
	if inventory_grid == null:
		return
	
	# Draw fullscreen semi-transparent background
	draw_rect(Rect2(Vector2.ZERO, screen_size), background_color)
	
	# Draw drop zone list (left side)
	_draw_drop_zone()
	
	# Draw player inventory grid (right side)
	_draw_player_inventory()
	
	# Draw preview if holding item and hovering over player inventory
	if not held_item.is_empty() and preview_position != Vector2i(-1, -1):
		_draw_preview()
	
	# Draw held item at cursor (outside grid for better UX)
	if not held_item.is_empty():
		_draw_held_item_at_cursor()

func _draw_player_inventory() -> void:
	var grid_width = inventory_grid.grid_width
	var grid_height = inventory_grid.grid_height
	
	# Title with larger font
	var title = "PLAYER INVENTORY"
	draw_string(ThemeDB.fallback_font, player_zone_offset + Vector2(0, -25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	
	# Background with border
	var grid_rect = Rect2(player_zone_offset, Vector2(
		grid_width * cell_size + (grid_width - 1) * cell_padding,
		grid_height * cell_size + (grid_height - 1) * cell_padding
	))
	draw_rect(grid_rect, Color(0.15, 0.15, 0.2, 0.95))
	draw_rect(grid_rect, Color(0.5, 0.5, 0.6, 1.0), false, 2.0)
	
	# Grid cells
	var grid_state = inventory_grid.get_grid_state()
	for y in range(grid_height):
		for x in range(grid_width):
			var cell_pos = player_zone_offset + Vector2(
				x * (cell_size + cell_padding),
				y * (cell_size + cell_padding)
			)
			var cell_rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
			
			var cell_color = Color(0.2, 0.2, 0.2, 1.0)
			if grid_state[y][x] != null:
				var ore_data = grid_state[y][x]
				cell_color = ore_data.get("color", Color.GRAY)
			
			draw_rect(cell_rect, cell_color)
			
			if show_grid_lines:
				draw_rect(cell_rect, Color(0.4, 0.4, 0.4), false, 1.0)

func _draw_drop_zone() -> void:
	# Title with larger font
	var title = "DROP ZONE - NEARBY ORES (%d)" % drop_zone_items.size()
	draw_string(ThemeDB.fallback_font, drop_zone_offset + Vector2(0, -25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	
	# Background with border
	var drop_rect = Rect2(drop_zone_offset, Vector2(drop_zone_width, drop_zone_height))
	draw_rect(drop_rect, Color(0.15, 0.15, 0.2, 0.95))
	draw_rect(drop_rect, Color(0.5, 0.5, 0.6, 1.0), false, 2.0)
	
	# Clip items to drop zone
	var item_y = 0.0 - drop_zone_scroll_offset
	
	for i in range(drop_zone_items.size()):
		if item_y + drop_item_height < 0:
			item_y += drop_item_height
			continue
		if item_y > drop_zone_height:
			break
		
		var ore_data = drop_zone_items[i]
		var item_pos = drop_zone_offset + Vector2(5, item_y + 5)
		var item_rect = Rect2(item_pos, Vector2(drop_zone_width - 10, drop_item_height - 5))
		
		# Check if this item is being held
		var is_held = false
		if not held_item.is_empty() and held_from_drop_zone:
			if held_item.get("world_node") == ore_data.get("world_node"):
				is_held = true
		
		if not is_held:
			# Background color
			var bg_color = Color(0.2, 0.2, 0.2, 1.0) if i != drop_zone_hovered_index else Color(0.3, 0.3, 0.3, 1.0)
			draw_rect(item_rect, bg_color)
			
			# Ore color indicator
			var color_rect = Rect2(item_pos, Vector2(drop_item_height - 10, drop_item_height - 10))
			var ore_color = ore_data.get("color", Color.GRAY)
			draw_rect(color_rect, ore_color)
			draw_rect(color_rect, Color.WHITE, false, 1.0)
			
			# Text info
			var text_pos = item_pos + Vector2(drop_item_height, 0)
			var ore_type = ore_data.get("type", "unknown").capitalize()
			var ore_size = ore_data.get("size", 1)
			var ore_value = ore_data.get("total_value", 0)
			var text = "%s (Size: %d) - $%d" % [ore_type, ore_size, ore_value]
			draw_string(ThemeDB.fallback_font, text_pos + Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		
		item_y += drop_item_height

func _draw_preview() -> void:
	var shape = inventory_grid._rotate_shape(
		held_item.get("shape", [Vector2i(0, 0)]),
		held_rotation
	)
	
	var preview_color = held_item.get("color", Color.GRAY)
	if preview_valid:
		preview_color.a = 0.6
	else:
		preview_color = Color(1.0, 0.2, 0.2, 0.6)
	
	for shape_offset in shape:
		var cell_pos_grid = preview_position + shape_offset
		var cell_pos = player_zone_offset + Vector2(
			cell_pos_grid.x * (cell_size + cell_padding),
			cell_pos_grid.y * (cell_size + cell_padding)
		)
		var cell_rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
		draw_rect(cell_rect, preview_color)
		draw_rect(cell_rect, Color.WHITE, false, 2.0)

func _draw_held_item_at_cursor() -> void:
	var mouse_pos = get_local_mouse_position()
	
	var shape = inventory_grid._rotate_shape(
		held_item.get("shape", [Vector2i(0, 0)]),
		held_rotation
	)
	
	var ore_color = held_item.get("color", Color.GRAY)
	ore_color.a = 0.8
	
	# Draw centered on cursor
	for shape_offset in shape:
		var cell_pos = mouse_pos + Vector2(
			shape_offset.x * (cell_size + cell_padding),
			shape_offset.y * (cell_size + cell_padding)
		)
		var cell_rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
		draw_rect(cell_rect, ore_color)
		draw_rect(cell_rect, Color.WHITE, false, 2.0)
	
	# Draw info text below the item
	var ore_type = held_item.get("type", "unknown").capitalize()
	var ore_value = held_item.get("total_value", 0)
	var info_text = "%s - $%d" % [ore_type, ore_value]
	var text_pos = mouse_pos + Vector2(0, (shape.size() * cell_size) + 10)
	draw_string(ThemeDB.fallback_font, text_pos, info_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _update_ui() -> void:
	_update_info_label()
	queue_redraw()

func _update_mouse_preview(mouse_pos: Vector2) -> void:
	# Check if mouse is over player inventory
	var grid_width = inventory_grid.grid_width
	var grid_height = inventory_grid.grid_height
	var player_rect = Rect2(player_zone_offset, Vector2(
		grid_width * cell_size + (grid_width - 1) * cell_padding,
		grid_height * cell_size + (grid_height - 1) * cell_padding
	))
	
	# Check if mouse is over drop zone
	var drop_rect = Rect2(drop_zone_offset, Vector2(drop_zone_width, drop_zone_height))
	
	if player_rect.has_point(mouse_pos):
		# Update grid preview
		var local_pos = mouse_pos - player_zone_offset
		var grid_x = int(local_pos.x / (cell_size + cell_padding))
		var grid_y = int(local_pos.y / (cell_size + cell_padding))
		preview_position = Vector2i(grid_x, grid_y)
		
		if not held_item.is_empty():
			var shape = inventory_grid._rotate_shape(
				held_item.get("shape", [Vector2i(0, 0)]),
				held_rotation
			)
			preview_valid = inventory_grid.can_place_at(shape, preview_position)
		else:
			preview_valid = false
	elif drop_rect.has_point(mouse_pos):
		# Update drop zone hover
		var local_y = mouse_pos.y - drop_zone_offset.y + drop_zone_scroll_offset
		drop_zone_hovered_index = int(local_y / drop_item_height)
		if drop_zone_hovered_index < 0 or drop_zone_hovered_index >= drop_zone_items.size():
			drop_zone_hovered_index = -1
		preview_position = Vector2i(-1, -1)
		preview_valid = false
	else:
		preview_position = Vector2i(-1, -1)
		preview_valid = false
		drop_zone_hovered_index = -1
	
	queue_redraw()

func _update_preview() -> void:
	if preview_position != Vector2i(-1, -1):
		var shape = inventory_grid._rotate_shape(
			held_item.get("shape", [Vector2i(0, 0)]),
			held_rotation
		)
		preview_valid = inventory_grid.can_place_at(shape, preview_position)
		queue_redraw()

func _place_held_item() -> void:
	if held_item.is_empty():
		return
	
	# Can only place in player inventory grid
	if preview_position == Vector2i(-1, -1):
		return
	
	if inventory_grid.place_item(held_item, preview_position, held_rotation):
		# Remove ore from world if it was from drop zone
		if held_from_drop_zone:
			# Remove from drop zone items first to prevent duplication
			for i in range(drop_zone_items.size() - 1, -1, -1):
				if drop_zone_items[i].get("world_node") == held_item.get("world_node"):
					drop_zone_items.remove_at(i)
					break
			_remove_ore_from_world(held_item)
		
		held_item = {}
		held_rotation = 0
		preview_position = Vector2i(-1, -1)
		held_from_drop_zone = false
		
		_update_ui()

func _return_held_item() -> void:
	if held_item.is_empty():
		return
	
	if held_from_drop_zone:
		# Just clear, ore stays in world
		held_item = {}
		held_from_drop_zone = false
	else:
		# Try to return to inventory
		if inventory_grid.try_add_ore(held_item):
			held_item = {}
			held_rotation = 0
		else:
			print("Cannot return item - no space")
	
	preview_position = Vector2i(-1, -1)
	_update_ui()

func _try_pickup_at_mouse(mouse_pos: Vector2) -> void:
	# Check player inventory
	var grid_width = inventory_grid.grid_width
	var grid_height = inventory_grid.grid_height
	var player_rect = Rect2(player_zone_offset, Vector2(
		grid_width * cell_size + (grid_width - 1) * cell_padding,
		grid_height * cell_size + (grid_height - 1) * cell_padding
	))
	
	# Check drop zone
	var drop_rect = Rect2(drop_zone_offset, Vector2(drop_zone_width, drop_zone_height))
	
	if player_rect.has_point(mouse_pos):
		# Pick from inventory
		var local_pos = mouse_pos - player_zone_offset
		var grid_x = int(local_pos.x / (cell_size + cell_padding))
		var grid_y = int(local_pos.y / (cell_size + cell_padding))
		var grid_pos = Vector2i(grid_x, grid_y)
		
		var ore_data = inventory_grid.remove_item_at(grid_pos)
		if not ore_data.is_empty():
			held_item = ore_data
			held_from_drop_zone = false
			held_rotation = ore_data.get("rotation", 0)
			_update_ui()
	
	elif drop_rect.has_point(mouse_pos):
		# Clicking in drop zone area
		if not held_item.is_empty() and not held_from_drop_zone:
			# Drop from inventory to world
			_spawn_ore_in_world(held_item)
			held_item = {}
			held_rotation = 0
			preview_position = Vector2i(-1, -1)
			held_from_drop_zone = false
			_update_ui()
		elif drop_zone_hovered_index >= 0 and drop_zone_hovered_index < drop_zone_items.size():
			# Pick from drop zone
			held_item = drop_zone_items[drop_zone_hovered_index]
			held_from_drop_zone = true
			held_rotation = 0
			_update_ui()

func _remove_ore_from_world(ore_data: Dictionary) -> void:
	if ore_data.has("world_node"):
		var ore_node = ore_data["world_node"]
		if is_instance_valid(ore_node):
			ore_node.queue_free()

func _spawn_ore_in_world(ore_data: Dictionary) -> void:
	# Load the ore item scene
	var ore_scene = preload("res://content/world/ore_item.tscn")
	var ore_instance = ore_scene.instantiate()
	
	# Position near the player
	if player_reference:
		var spawn_offset = Vector2(randf_range(-30, 30), randf_range(-30, -10))
		ore_instance.global_position = player_reference.global_position + spawn_offset
	
	# Initialize the ore with its data
	ore_instance.initialize(
		ore_data.get("type", "iron"),
		ore_data.get("size", 1),
		ore_data.get("price", 10),
		ore_data.get("shape", [Vector2i(0, 0)]),
		ore_data.get("color", Color.GRAY)
	)
	
	# Add to the scene
	get_tree().root.add_child(ore_instance)
	
	# Refresh drop zone to show newly spawned ore
	await get_tree().process_frame
	_refresh_drop_zone()


func _update_info_label() -> void:
	if info_label == null:
		return
	
	var total_value = inventory_grid.get_total_value()
	var occupied = inventory_grid.get_occupied_count()
	var total = inventory_grid.grid_width * inventory_grid.grid_height
	
	var base_text = "Press Tab to toggle inventory | Value: $%d | Space: %d/%d | Nearby Ores: %d" % [total_value, occupied, total, drop_zone_items.size()]
	
	if not held_item.is_empty():
		var item_name = held_item.get("type", "unknown").capitalize()
		var item_value = held_item.get("total_value", 0)
		info_label.text = "Holding: %s ($%d) | Q/E to rotate | %s" % [item_name, item_value, base_text]
	else:
		info_label.text = base_text

func _on_item_placed(_ore_data: Dictionary) -> void:
	_update_ui()

func _on_item_removed(_ore_data: Dictionary) -> void:
	_update_ui()

func _on_grid_full() -> void:
	print("Inventory full!")

## Public API
func can_accept_item(ore_data: Dictionary) -> bool:
	var shape = ore_data.get("shape", [Vector2i(0, 0)])
	return inventory_grid.has_space_for(shape)

func try_add_ore(_ore_data: Dictionary) -> bool:
	return false # Deprecated

func get_total_value() -> int:
	return inventory_grid.get_total_value()

func clear_inventory() -> void:
	inventory_grid.clear_all()
	held_item = {}
	held_rotation = 0
	_update_ui()

func clear_all() -> void:
	clear_inventory()

func set_player(player: Node2D) -> void:
	player_reference = player
