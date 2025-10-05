extends Node
class_name OreGenerator

## Generates randomized ore shapes with connected cells

# Ore tier definitions (only valuable ores, stone drops nothing)
const ORE_TIERS = {
	"IRON_ORE": {"base_price": 15, "weight": 50, "atlas_coord": Vector2i(0, 4), "color": Color(0.7, 0.6, 0.5)},
	"COPPER_ORE": {"base_price": 25, "weight": 30, "atlas_coord": Vector2i(1, 4), "color": Color(0.8, 0.5, 0.3)},
	"GOLD_ORE": {"base_price": 50, "weight": 15, "atlas_coord": Vector2i(2, 4), "color": Color(0.9, 0.8, 0.2)},
	"DIAMONG_ORE": {"base_price": 100, "weight": 5, "atlas_coord": Vector2i(3, 4), "color": Color(0.3, 0.8, 0.9)}
}

const SIZE_WEIGHTS_0 = {
	1: 5,
	2: 4,
	3: 1
}

const SIZE_WEIGHTS = {
	0: SIZE_WEIGHTS_0
}

# Size distribution (1-8 cells, middle sizes more common)
const SIZE_WEIGHTS_TEST = {
	1: 5,
	2: 15,
	3: 25,
	4: 25,
	5: 15,
	6: 8,
	7: 5,
	8: 2
}

## Generate a random ore type based on weights
static func generate_ore_type() -> String:
	var total_weight = 0
	for tier in ORE_TIERS:
		total_weight += ORE_TIERS[tier].weight
	
	var roll = randf() * total_weight
	var current = 0.0
	
	for tier in ORE_TIERS:
		current += ORE_TIERS[tier].weight
		if roll <= current:
			return tier
	
	return "IRON_ORE" # Fallback

static func get_size_weights() -> Dictionary:
	return SIZE_WEIGHTS[UpgradeManager.get_ore_size()]

## Generate a random ore size based on weights (1-8)
static func generate_ore_size() -> int:
	var total_weight = 0
	var weights := get_size_weights()
	for size in weights:
		total_weight += weights[size]
	
	var roll = randf() * total_weight
	var current = 0.0
	
	for size in weights:
		current += weights[size]
		if roll <= current:
			return size
	
	return 3 # Fallback

## Generate a connected random shape of given size
static func generate_connected_shape(size: int) -> Array[Vector2i]:
	if size <= 0:
		return []
	
	var cells: Array[Vector2i] = []
	cells.append(Vector2i(0, 0)) # Start at origin
	
	# Keep adding adjacent cells until we reach desired size
	while cells.size() < size:
		# Pick a random existing cell
		var base_cell = cells[randi() % cells.size()]
		
		# Try to add an adjacent cell
		var directions = [
			Vector2i(1, 0), # Right
			Vector2i(-1, 0), # Left
			Vector2i(0, 1), # Down
			Vector2i(0, -1) # Up
		]
		directions.shuffle()
		
		var added = false
		for dir in directions:
			var new_cell = base_cell + dir
			if not cells.has(new_cell):
				cells.append(new_cell)
				added = true
				break
		
		# Safety: if we can't add adjacent cells, break
		if not added:
			break
	
	return cells

## Get ore tier data
static func get_ore_data(ore_type: String) -> Dictionary:
	if ORE_TIERS.has(ore_type):
		return ORE_TIERS[ore_type]
	# Fallback to iron if type not found
	return ORE_TIERS["IRON_ORE"]

## Create complete ore data package
static func generate_ore_data(ore_type: String = "") -> Dictionary:
	# Use provided ore type or generate random one
	if ore_type.is_empty():
		ore_type = generate_ore_type()
	
	var ore_size = generate_ore_size()
	var shape = generate_connected_shape(ore_size)
	var tier_data = get_ore_data(ore_type)
	
	# Normalize ore type to simple name (remove _ORE suffix)
	var simple_type = ore_type.to_lower().replace("_ore", "")
	
	return {
		"type": simple_type, # Use simple type name: "iron", "copper", etc.
		"size": ore_size,
		"base_price": tier_data.base_price, # Legacy field
		"total_value": ore_size, # New system: value = size
		"atlas_coord": tier_data.atlas_coord,
		"shape": shape,
		"color": tier_data.color
	}
