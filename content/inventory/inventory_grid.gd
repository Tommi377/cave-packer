extends Node
class_name InventoryGrid

## Grid-based inventory system for tetromino-shaped ore pieces
## Tracks which cells are occupied and manages placement logic

signal item_placed(ore_data: Dictionary)
signal item_removed(ore_data: Dictionary)
signal grid_full()

@export var grid_width: int = 5
@export var grid_height: int = 5

# Grid state: 2D array where each cell is either null or contains ore_data
var grid: Array[Array] = []

# Currently held item waiting to be placed
var held_item: Dictionary = {}
var held_item_rotation: int = 0 # 0, 1, 2, 3 for 0°, 90°, 180°, 270°

func _ready() -> void:
	_initialize_grid()

## Initialize empty grid
func _initialize_grid() -> void:
	grid.clear()
	for y in range(grid_height):
		var row: Array = []
		row.resize(grid_width)
		row.fill(null)
		grid.append(row)

## Check if a tetromino shape can be placed at position
func can_place_at(shape: Array[Vector2i], grid_pos: Vector2i) -> bool:
	for offset in shape:
		var cell_pos = grid_pos + offset
		
		# Check bounds
		if cell_pos.x < 0 or cell_pos.x >= grid_width:
			return false
		if cell_pos.y < 0 or cell_pos.y >= grid_height:
			return false
		
		# Check if cell is occupied
		if grid[cell_pos.y][cell_pos.x] != null:
			return false
	
	return true

## Place an ore item at the specified position
func place_item(ore_data: Dictionary, grid_pos: Vector2i, rotation: int = 0) -> bool:
	var rotated_shape = _rotate_shape(ore_data.get("shape", [Vector2i(0, 0)]), rotation)
	
	if not can_place_at(rotated_shape, grid_pos):
		return false
	
	# Create a copy of ore_data with rotated shape
	var placed_data = ore_data.duplicate()
	placed_data["shape"] = rotated_shape
	placed_data["grid_position"] = grid_pos
	placed_data["rotation"] = rotation
	
	# Mark cells as occupied
	for offset in rotated_shape:
		var cell_pos = grid_pos + offset
		grid[cell_pos.y][cell_pos.x] = placed_data
	
	item_placed.emit(placed_data)
	return true

## Remove item at grid position
func remove_item_at(grid_pos: Vector2i) -> Dictionary:
	if grid_pos.x < 0 or grid_pos.x >= grid_width:
		return {}
	if grid_pos.y < 0 or grid_pos.y >= grid_height:
		return {}
	
	var ore_data = grid[grid_pos.y][grid_pos.x]
	if ore_data == null:
		return {}
	
	# Clear all cells occupied by this item
	var shape = ore_data.get("shape", [Vector2i(0, 0)])
	var base_pos = ore_data.get("grid_position", grid_pos)
	
	for offset in shape:
		var cell_pos = base_pos + offset
		if cell_pos.x >= 0 and cell_pos.x < grid_width and cell_pos.y >= 0 and cell_pos.y < grid_height:
			grid[cell_pos.y][cell_pos.x] = null
	
	item_removed.emit(ore_data)
	return ore_data

## Rotate a tetromino shape by 90° increments
func _rotate_shape(shape: Array[Vector2i], rotation: int) -> Array[Vector2i]:
	var rotated: Array[Vector2i] = []
	var rot = rotation % 4
	
	for point in shape:
		var new_point = point
		
		# Apply rotation
		for i in range(rot):
			# 90° clockwise rotation: (x, y) -> (y, -x)
			new_point = Vector2i(new_point.y, -new_point.x)
		
		rotated.append(new_point)
	
	# Normalize to top-left origin
	return _normalize_shape(rotated)

## Normalize shape so minimum x and y are 0
func _normalize_shape(shape: Array[Vector2i]) -> Array[Vector2i]:
	if shape.is_empty():
		return shape
	
	var min_x = shape[0].x
	var min_y = shape[0].y
	
	for point in shape:
		min_x = mini(min_x, point.x)
		min_y = mini(min_y, point.y)
	
	var normalized: Array[Vector2i] = []
	for point in shape:
		normalized.append(Vector2i(point.x - min_x, point.y - min_y))
	
	return normalized

## Get total number of occupied cells
func get_occupied_count() -> int:
	var count = 0
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x] != null:
				count += 1
	return count

## Check if grid has space for a shape
func has_space_for(shape: Array[Vector2i]) -> bool:
	# Try placing at every position
	for y in range(grid_height):
		for x in range(grid_width):
			if can_place_at(shape, Vector2i(x, y)):
				return true
	return false

## Calculate total value of inventory
func get_total_value() -> int:
	var total = 0
	var counted_items = {}
	
	for y in range(grid_height):
		for x in range(grid_width):
			var ore_data = grid[y][x]
			if ore_data != null:
				# Use grid_position as unique identifier to avoid counting same item multiple times
				var item_id = str(ore_data.get("grid_position", Vector2i(x, y)))
				if not counted_items.has(item_id):
					counted_items[item_id] = true
					total += ore_data.get("total_value", 0) # Use total_value from ore
	
	return total

## Try to automatically add an ore to inventory (finds first available spot)
func try_add_ore(ore_data: Dictionary) -> bool:
	# Try all rotations and positions
	for rotation in range(4):
		for y in range(grid_height):
			for x in range(grid_width):
				if place_item(ore_data, Vector2i(x, y), rotation):
					return true
	
	# No space found
	grid_full.emit()
	return false

## Clear entire inventory
func clear_all() -> void:
	_initialize_grid()

## Get grid state for UI display
func get_grid_state() -> Array[Array]:
	return grid

## Resize the grid (for upgrades)
func resize_grid(new_width: int, new_height: int) -> void:
	# This is a simple implementation - items outside new bounds will be lost
	# For production, you'd want to handle this more gracefully
	var old_grid = grid.duplicate(true)
	grid_width = new_width
	grid_height = new_height
	_initialize_grid()
	
	# Try to restore items that fit
	for y in range(mini(old_grid.size(), new_height)):
		for x in range(mini(old_grid[y].size(), new_width)):
			if old_grid[y][x] != null:
				grid[y][x] = old_grid[y][x]
