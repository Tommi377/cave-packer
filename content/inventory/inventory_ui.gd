extends Control
class_name InventoryUI

## Two-zone inventory system: Player Inventory + Drop Zone List
## Player must enter inventory mode to interact with items

signal inventory_mode_changed(is_active: bool)

@export var cell_size: int = 32
@export var cell_padding: int = 2
@export var pickup_radius: float = 80.0

# Scene nodes
@onready var inventory_grid: InventoryGrid = $InventoryGrid
@onready var info_label: Label = $InfoPanel/InfoLabel
@onready var drop_zone_list: VBoxContainer = $MainContainer/LeftPanel/DropZonePanel/DropZoneScroll/DropZoneList
@onready var drop_zone_title: Label = $MainContainer/LeftPanel/DropZoneTitle
@onready var inventory_container: Control = $MainContainer/RightPanel/InventoryPanel/InventoryContainer
@onready var held_item_preview: Control = $HeldItemPreview

var held_item: Dictionary = {}
var held_from_drop_zone: bool = false
var held_rotation: int = 0
var preview_position: Vector2i = Vector2i(-1, -1)
var preview_valid: bool = false
var held_item_grab_offset: Vector2i = Vector2i.ZERO # Track where on the item the user grabbed it

var inventory_mode_active: bool = false
var player_reference: Node2D = null

# Drop zone data
var drop_zone_items: Array[Dictionary] = []
var drop_zone_item_nodes: Array[Control] = []

# Inventory grid rendering
var grid_cells: Array[ColorRect] = []

func _ready() -> void:
	if inventory_grid:
		inventory_grid.item_placed.connect(_on_item_placed)
		inventory_grid.item_removed.connect(_on_item_removed)
		inventory_grid.grid_full.connect(_on_grid_full)
	
	_setup_inventory_grid_ui()
	_setup_held_item_preview()
	
	# Connect inventory container's gui_input signal
	inventory_container.gui_input.connect(_on_inventory_container_gui_input)
	
	visible = false
	inventory_mode_active = false
	_update_ui()

func _setup_inventory_grid_ui() -> void:
	# Create visual grid cells
	var grid_width = inventory_grid.grid_width
	var grid_height = inventory_grid.grid_height
	
	# Set container size
	inventory_container.custom_minimum_size = Vector2(
		grid_width * cell_size + (grid_width - 1) * cell_padding,
		grid_height * cell_size + (grid_height - 1) * cell_padding
	)
	
	# Create grid cells as ColorRects
	for y in range(grid_height):
		for x in range(grid_width):
			var cell = ColorRect.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.position = Vector2(
				x * (cell_size + cell_padding),
				y * (cell_size + cell_padding)
			)
			cell.color = Color(0.2, 0.2, 0.2, 1.0)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE # Allow clicks to pass through
			inventory_container.add_child(cell)
			grid_cells.append(cell)

func _setup_held_item_preview() -> void:
	held_item_preview.draw.connect(_draw_held_item)

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
		_refresh_drop_zone()
	else:
		held_item = {}
		held_rotation = 0
		preview_position = Vector2i(-1, -1)
		held_from_drop_zone = false
		held_item_grab_offset = Vector2i.ZERO
		held_item_preview.queue_redraw() # Clear preview when closing
	
	inventory_mode_changed.emit(inventory_mode_active)
	_update_ui()

func _refresh_drop_zone() -> void:
	drop_zone_items.clear()
	
	# Clear existing UI
	for node in drop_zone_item_nodes:
		node.queue_free()
	drop_zone_item_nodes.clear()
	
	if not player_reference:
		return
	
	var nearby_ores = _get_nearby_ores()
	
	for ore in nearby_ores:
		if ore.has_method("get_inventory_data"):
			var ore_data = ore.get_inventory_data()
			ore_data["world_node"] = ore
			drop_zone_items.append(ore_data)
			_create_drop_zone_item_ui(ore_data)
	
	drop_zone_title.text = "DROP ZONE - NEARBY ORES (%d)" % drop_zone_items.size()

func _create_drop_zone_item_ui(ore_data: Dictionary) -> void:
	var item_button = Button.new()
	item_button.custom_minimum_size = Vector2(0, 44)
	item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let button handle clicks
	item_button.add_child(hbox)
	
	# Color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(32, 32)
	color_rect.color = ore_data.get("color", Color.GRAY)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(color_rect)
	
	# Info label
	var label = Label.new()
	var ore_type = ore_data.get("type", "unknown").capitalize()
	var ore_size = ore_data.get("size", 1)
	var ore_value = ore_data.get("total_value", 0)
	label.text = "%s (Size: %d) - $%d" % [ore_type, ore_size, ore_value]
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)
	
	# Connect click event to the whole button
	item_button.pressed.connect(_on_drop_zone_item_clicked.bind(ore_data))
	
	drop_zone_list.add_child(item_button)
	drop_zone_item_nodes.append(item_button)

func _on_drop_zone_item_clicked(ore_data: Dictionary) -> void:
	if held_item.is_empty():
		held_item = ore_data
		held_from_drop_zone = true
		held_rotation = 0
		held_item_grab_offset = Vector2i.ZERO # No offset for drop zone items
		# Hide the item from the list visually
		for i in range(drop_zone_items.size()):
			if drop_zone_items[i].get("world_node") == ore_data.get("world_node"):
				if i < drop_zone_item_nodes.size():
					drop_zone_item_nodes[i].visible = false
				break
		_update_ui()

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

func _process(_delta: float) -> void:
	if not inventory_mode_active:
		return
	
	if not held_item.is_empty():
		held_item_preview.queue_redraw()
	
	_update_mouse_preview()

func _update_mouse_preview() -> void:
	if held_item.is_empty():
		preview_position = Vector2i(-1, -1)
		_update_inventory_grid_display()
		return
	
	var mouse_pos = inventory_container.get_local_mouse_position()
	
	# Check if mouse is over inventory grid
	var grid_rect = Rect2(Vector2.ZERO, inventory_container.size)
	
	if grid_rect.has_point(mouse_pos):
		var grid_x = int(mouse_pos.x / (cell_size + cell_padding))
		var grid_y = int(mouse_pos.y / (cell_size + cell_padding))
		
		# Apply grab offset to preview position so the item places where expected
		preview_position = Vector2i(grid_x, grid_y) - held_item_grab_offset
		
		var shape = inventory_grid._rotate_shape(
			held_item.get("shape", [Vector2i(0, 0)]),
			held_rotation
		)
		preview_valid = inventory_grid.can_place_at(shape, preview_position)
	else:
		preview_position = Vector2i(-1, -1)
		preview_valid = false
	
	_update_inventory_grid_display()

func _update_preview() -> void:
	if preview_position != Vector2i(-1, -1):
		var shape = inventory_grid._rotate_shape(
			held_item.get("shape", [Vector2i(0, 0)]),
			held_rotation
		)
		preview_valid = inventory_grid.can_place_at(shape, preview_position)
		_update_inventory_grid_display()

func _update_inventory_grid_display() -> void:
	var grid_width = inventory_grid.grid_width
	var grid_height = inventory_grid.grid_height
	var grid_state = inventory_grid.get_grid_state()
	
	# Update all cells
	var cell_idx = 0
	for y in range(grid_height):
		for x in range(grid_width):
			var cell = grid_cells[cell_idx]
			var cell_color = Color(0.2, 0.2, 0.2, 1.0)
			
			# Show ore color if occupied
			if grid_state[y][x] != null:
				var ore_data = grid_state[y][x]
				cell_color = ore_data.get("color", Color.GRAY)
			
			# Show preview
			if preview_position != Vector2i(-1, -1):
				var shape = inventory_grid._rotate_shape(
					held_item.get("shape", [Vector2i(0, 0)]),
					held_rotation
				)
				for shape_offset in shape:
					var preview_cell = preview_position + shape_offset
					if preview_cell == Vector2i(x, y):
						if preview_valid:
							cell_color = held_item.get("color", Color.GRAY)
							cell_color.a = 0.6
						else:
							cell_color = Color(1.0, 0.2, 0.2, 0.6)
			
			cell.color = cell_color
			cell_idx += 1

func _draw_held_item() -> void:
	if held_item.is_empty():
		return
	
	var mouse_pos = held_item_preview.get_local_mouse_position()
	
	var shape = inventory_grid._rotate_shape(
		held_item.get("shape", [Vector2i(0, 0)]),
		held_rotation
	)
	
	var ore_color = held_item.get("color", Color.GRAY)
	ore_color.a = 0.8
	
	# Apply grab offset so the item is centered on the cell that was clicked
	var offset_pixels = Vector2(
		- held_item_grab_offset.x * (cell_size + cell_padding),
		- held_item_grab_offset.y * (cell_size + cell_padding)
	)
	
	# Draw centered on cursor with offset
	for shape_offset in shape:
		var cell_pos = mouse_pos + offset_pixels + Vector2(
			shape_offset.x * (cell_size + cell_padding),
			shape_offset.y * (cell_size + cell_padding)
		)
		var cell_rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
		held_item_preview.draw_rect(cell_rect, ore_color)
		held_item_preview.draw_rect(cell_rect, Color.WHITE, false, 2.0)
	
	# Draw info text below the item
	var ore_type = held_item.get("type", "unknown").capitalize()
	var ore_value = held_item.get("total_value", 0)
	var info_text = "%s - $%d" % [ore_type, ore_value]
	var text_pos = mouse_pos + Vector2(0, (shape.size() * cell_size) + 10)
	held_item_preview.draw_string(ThemeDB.fallback_font, text_pos, info_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func _place_held_item() -> void:
	if held_item.is_empty():
		return
	
	if preview_position == Vector2i(-1, -1):
		return
	
	if inventory_grid.place_item(held_item, preview_position, held_rotation):
		if held_from_drop_zone:
			_remove_ore_from_world(held_item)
		
		held_item = {}
		held_rotation = 0
		preview_position = Vector2i(-1, -1)
		held_from_drop_zone = false
		held_item_grab_offset = Vector2i.ZERO
		
		# Clear the held item preview
		held_item_preview.queue_redraw()
		
		_update_ui()

func _return_held_item() -> void:
	if held_item.is_empty():
		return
	
	if held_from_drop_zone:
		# Show the item again in the drop zone
		for i in range(drop_zone_items.size()):
			if drop_zone_items[i].get("world_node") == held_item.get("world_node"):
				if i < drop_zone_item_nodes.size():
					drop_zone_item_nodes[i].visible = true
				break
		held_item = {}
		held_from_drop_zone = false
	else:
		if inventory_grid.try_add_ore(held_item):
			held_item = {}
			held_rotation = 0
		else:
			print("Cannot return item - no space")
	
	preview_position = Vector2i(-1, -1)
	held_item_grab_offset = Vector2i.ZERO
	
	# Clear the held item preview
	held_item_preview.queue_redraw()
	
	_update_ui()

func _on_inventory_container_gui_input(event: InputEvent) -> void:
	if not inventory_mode_active:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# If holding an item, try to place it first
			if not held_item.is_empty():
				if preview_valid and preview_position != Vector2i(-1, -1):
					_place_held_item()
					return
			
			# Otherwise, try to pick up an item
			# event.position is already local to inventory_container
			var local_pos = event.position
			var grid_x = int(local_pos.x / (cell_size + cell_padding))
			var grid_y = int(local_pos.y / (cell_size + cell_padding))
			var grid_pos = Vector2i(grid_x, grid_y)
			
			var ore_data = inventory_grid.remove_item_at(grid_pos)
			if not ore_data.is_empty():
				held_item = ore_data
				held_from_drop_zone = false
				held_rotation = 0 # Reset rotation when picking up
				
				# Calculate grab offset - which cell of the ore was clicked
				var ore_origin = ore_data.get("grid_position", Vector2i(0, 0))
				held_item_grab_offset = grid_pos - ore_origin
				
				_update_ui()

func _remove_ore_from_world(ore_data: Dictionary) -> void:
	if ore_data.has("world_node"):
		var ore_node = ore_data["world_node"]
		if is_instance_valid(ore_node):
			ore_node.queue_free()
	
	# Refresh drop zone to remove from list
	await get_tree().process_frame
	_refresh_drop_zone()

func _spawn_ore_in_world(ore_data: Dictionary) -> void:
	var ore_scene = preload("res://content/world/ore_item.tscn")
	var ore_instance = ore_scene.instantiate()
	
	if player_reference:
		var spawn_offset = Vector2(randf_range(-30, 30), randf_range(-30, -10))
		ore_instance.global_position = player_reference.global_position + spawn_offset
	
	ore_instance.initialize(
		ore_data.get("type", "IRON_ORE"),
		ore_data.get("size", 1),
		ore_data.get("price", 10),
		ore_data.get("shape", [Vector2i(0, 0)]),
		ore_data.get("color", Color.GRAY)
	)
	
	get_tree().root.add_child(ore_instance)
	
	await get_tree().process_frame
	_refresh_drop_zone()

func _update_ui() -> void:
	_update_info_label()
	_update_inventory_grid_display()
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

func set_player(player: Node2D) -> void:
	player_reference = player

func _on_item_placed(_ore_data: Dictionary) -> void:
	_update_ui()

func _on_item_removed(_ore_data: Dictionary) -> void:
	_update_ui()

func _on_grid_full() -> void:
	print("Inventory is full!")
