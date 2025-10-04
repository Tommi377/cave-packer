extends Control
class_name InventoryUI

## Visual representation of the inventory grid
## Handles user interaction for placing/removing items

const InventoryGridScript = preload("res://content/inventory/inventory_grid.gd")

signal item_pickup_requested(grid_pos: Vector2i)
signal close_requested()

@export var cell_size: int = 32
@export var cell_padding: int = 2
@export var show_grid_lines: bool = true

@onready var grid_container: Control = $GridContainer
@onready var preview_container: Control = $PreviewContainer
@onready var info_label: Label = $InfoPanel/InfoLabel

var inventory_grid: Node
var held_item: Dictionary = {}
var held_rotation: int = 0
var preview_position: Vector2i = Vector2i(-1, -1)
var preview_valid: bool = false

func _ready() -> void:
	# Initialize inventory grid
	inventory_grid = InventoryGridScript.new()
	add_child(inventory_grid)
	
	inventory_grid.item_placed.connect(_on_item_placed)
	inventory_grid.item_removed.connect(_on_item_removed)
	inventory_grid.grid_full.connect(_on_grid_full)
	
	_update_ui()

func _input(event: InputEvent) -> void:
	if not visible or held_item.is_empty():
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
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		if preview_valid and preview_position != Vector2i(-1, -1):
			_place_held_item()
			accept_event()
	
	# Cancel/drop item
	elif event.is_action_pressed("ui_cancel"):
		_drop_held_item()
		accept_event()

func _gui_input(event: InputEvent) -> void:
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
				_drop_held_item()

func _draw() -> void:
	if inventory_grid == null:
		return
	
	var grid_width = inventory_grid.grid_width
	var grid_height = inventory_grid.grid_height
	
	# Draw grid background
	var grid_rect = Rect2(Vector2.ZERO, Vector2(
		grid_width * cell_size + (grid_width - 1) * cell_padding,
		grid_height * cell_size + (grid_height - 1) * cell_padding
	))
	draw_rect(grid_rect, Color(0.1, 0.1, 0.1, 0.8))
	
	# Draw grid cells
	var grid_state = inventory_grid.get_grid_state()
	for y in range(grid_height):
		for x in range(grid_width):
			var cell_pos = Vector2(
				x * (cell_size + cell_padding),
				y * (cell_size + cell_padding)
			)
			var cell_rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
			
			# Draw cell background
			var cell_color = Color(0.2, 0.2, 0.2, 1.0)
			if grid_state[y][x] != null:
				# Color based on ore type
				var ore_data = grid_state[y][x]
				cell_color = ore_data.get("color", Color.GRAY)
			
			draw_rect(cell_rect, cell_color)
			
			# Draw grid lines
			if show_grid_lines:
				draw_rect(cell_rect, Color(0.4, 0.4, 0.4), false, 1.0)
	
	# Draw preview
	if not held_item.is_empty() and preview_position != Vector2i(-1, -1):
		var shape = inventory_grid._rotate_shape(
			held_item.get("shape", [Vector2i(0, 0)]),
			held_rotation
		)
		
		var preview_color = held_item.get("color", Color.GRAY)
		if preview_valid:
			preview_color.a = 0.6
		else:
			preview_color = Color(1.0, 0.2, 0.2, 0.6) # Red tint for invalid
		
		for offset in shape:
			var cell_pos_grid = preview_position + offset
			var cell_pos = Vector2(
				cell_pos_grid.x * (cell_size + cell_padding),
				cell_pos_grid.y * (cell_size + cell_padding)
			)
			var cell_rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
			draw_rect(cell_rect, preview_color)
			draw_rect(cell_rect, Color.WHITE, false, 2.0)

## Update the entire UI
func _update_ui() -> void:
	queue_redraw()
	_update_info_label()

## Try to pick up an item from a grid cell
func pick_up_item(ore_data: Dictionary) -> void:
	if not held_item.is_empty():
		# Already holding something, can't pick up
		return
	
	held_item = ore_data
	held_rotation = 0
	_update_ui()

## Update preview based on mouse position
func _update_mouse_preview(mouse_pos: Vector2) -> void:
	if held_item.is_empty():
		preview_position = Vector2i(-1, -1)
		queue_redraw()
		return
	
	# Convert mouse position to grid coordinates
	var grid_x = int(mouse_pos.x / (cell_size + cell_padding))
	var grid_y = int(mouse_pos.y / (cell_size + cell_padding))
	
	preview_position = Vector2i(grid_x, grid_y)
	_update_preview()

## Update preview validity
func _update_preview() -> void:
	if held_item.is_empty() or preview_position == Vector2i(-1, -1):
		preview_valid = false
		queue_redraw()
		return
	
	var shape = inventory_grid._rotate_shape(
		held_item.get("shape", [Vector2i(0, 0)]),
		held_rotation
	)
	
	preview_valid = inventory_grid.can_place_at(shape, preview_position)
	queue_redraw()

## Place the currently held item
func _place_held_item() -> void:
	if held_item.is_empty():
		return
	
	if inventory_grid.place_item(held_item, preview_position, held_rotation):
		held_item = {}
		held_rotation = 0
		preview_position = Vector2i(-1, -1)
		_update_ui()

## Drop/discard the held item
func _drop_held_item() -> void:
	# TODO: Actually drop the item back into the world
	print("Dropped item: ", held_item.get("type", "unknown"))
	held_item = {}
	held_rotation = 0
	preview_position = Vector2i(-1, -1)
	_update_ui()

## Try to pick up item at mouse position
func _try_pickup_at_mouse(mouse_pos: Vector2) -> void:
	var grid_x = int(mouse_pos.x / (cell_size + cell_padding))
	var grid_y = int(mouse_pos.y / (cell_size + cell_padding))
	var grid_pos = Vector2i(grid_x, grid_y)
	
	var ore_data = inventory_grid.remove_item_at(grid_pos)
	if not ore_data.is_empty():
		held_item = ore_data
		held_rotation = ore_data.get("rotation", 0)
		_update_ui()
		item_pickup_requested.emit(grid_pos)

## Update info label
func _update_info_label() -> void:
	if info_label == null:
		return
	
	var total_value = inventory_grid.get_total_value()
	var occupied = inventory_grid.get_occupied_count()
	var total = inventory_grid.grid_width * inventory_grid.grid_height
	
	info_label.text = "Value: $%d | Space: %d/%d" % [total_value, occupied, total]
	
	if not held_item.is_empty():
		var item_name = held_item.get("type", "unknown")
		var item_value = held_item.get("value", 0)
		info_label.text += "\nHolding: %s ($%d) | Q/R to rotate" % [item_name, item_value]

## Callbacks
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

func get_total_value() -> int:
	return inventory_grid.get_total_value()

func clear_inventory() -> void:
	inventory_grid.clear_all()
	held_item = {}
	held_rotation = 0
	_update_ui()
