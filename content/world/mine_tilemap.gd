extends TileMapLayer
class_name MineTilemap

@onready var ore_tilemap: TileMapLayer = $OreTilemap
@onready var fog_tilemap: TileMapLayer = $FogTilemap

## Tile types (atlas coordinates)
const ORE_ATLAS = {
	"IRON_ORE": Vector2i(0, 4),
	"COPPER_ORE": Vector2i(1, 4),
	"GOLD_ORE": Vector2i(2, 4),
	"DIAMOND_ORE": Vector2i(3, 4),
}

## Depth zones (measured in tiles from surface)
const SURFACE_DEPTH = 0
const MID_DEPTH = 20
const DEEP_DEPTH = 40

## Ore spawn chances by depth
const ORE_SPAWN_CHANCE = {
	"surface": {"STONE": 0.95, "IRON_ORE": 0.04, "COPPER_ORE": 0.01},
	"mid": {"STONE": 0.90, "IRON_ORE": 0.04, "COPPER_ORE": 0.04, "GOLD_ORE": 0.02},
	"deep": {"STONE": 0.78, "IRON_ORE": 0.05, "COPPER_ORE": 0.10, "GOLD_ORE": 0.05, "DIAMOND_ORE": 0.02}
}

## Ore drop scene
const ORE_ITEM_SCENE = preload("res://content/world/ore_item.tscn")

## Block HP tracking - only stores HP for blocks that have been damaged
## Undamaged blocks are assumed to have full HP based on their y-depth
var block_hp: Dictionary = {} # { Vector2i: int }

signal block_broken(tile_pos: Vector2i, ore_type: String)

func _ready() -> void:
	add_to_group("tilemap")
	
	# Generate initial mine if empty
	if get_used_cells().is_empty():
		generate_mine()

## Generate the mine shaft
func generate_mine(width: int = 40, depth: int = 60) -> void:
	# Clear existing tiles
	clear()
	
	# Generate from top (y=0) to bottom
	for y in range(depth):
		for x in range(width):
			var tile_pos = Vector2i(x, y)
			set_cells_terrain_connect([tile_pos], 0, 0, false)
			
			var ore_type := _get_tile_for_depth(y)
			if ore_type != "STONE":
				ore_tilemap.set_cell(tile_pos, 0, ORE_ATLAS[ore_type])
				pass
			if y > 0:
				fog_tilemap.set_cell(tile_pos, 0, Vector2i(0, 5))
	
	#set_cells_terrain_connect(get_used_cells(), 0, 0)
	
	print("Mine generated: ", width, "x", depth, " tiles")

## Get appropriate tile type based on depth
func _get_tile_for_depth(depth_y: int) -> String:
	if depth_y == 0:
		return "STONE"
	
	var zone = _get_depth_zone(depth_y)
	var chances = ORE_SPAWN_CHANCE[zone]
	
	# Random weighted selection
	var roll = randf()
	var cumulative = 0.0
	
	for ore_type in chances:
		cumulative += chances[ore_type]
		if roll <= cumulative:
			return ore_type
	
	return "STONE" # Fallback

## Determine depth zone
func _get_depth_zone(depth_y: int) -> String:
	if depth_y < MID_DEPTH:
		return "surface"
	elif depth_y < DEEP_DEPTH:
		return "mid"
	else:
		return "deep"

## Damage a tile at world position (for pickaxe attacks)
func damage_tile_at_position(world_pos: Vector2, damage: int = 1) -> bool:
	var tile_pos = local_to_map(to_local(world_pos))
	return damage_tile(tile_pos, damage)

## Damage a tile at tile coordinates
func damage_tile(tile_pos: Vector2i, damage: int = 1) -> bool:
	var tile_data = get_cell_tile_data(tile_pos)
	if tile_data == null:
		return false # No tile here
	
	# Calculate max HP based on depth
	var max_hp = tile_pos.y if tile_pos.y > 0 else 1
	
	# Get current HP (lazy initialization - if not damaged yet, assume full HP)
	var current_hp = block_hp.get(tile_pos, max_hp)
	
	# Apply damage
	current_hp -= damage
	
	print("Block at ", tile_pos, " took ", damage, " damage. HP: ", current_hp, "/", max_hp)
	
	# If HP reaches 0 or below, break the tile
	if current_hp <= 0:
		# Clean up HP tracking before breaking
		block_hp.erase(tile_pos)
		return break_tile(tile_pos)
	
	# Store the damaged HP (only now does it enter the dictionary)
	block_hp[tile_pos] = current_hp
	
	return true # Tile was damaged but not broken

## Break a tile at world position
func break_tile_at_position(world_pos: Vector2) -> bool:
	var tile_pos = local_to_map(to_local(world_pos))
	return break_tile(tile_pos)

## Break a tile at tile coordinates
func break_tile(tile_pos: Vector2i) -> bool:
	var tile_data = get_cell_tile_data(tile_pos)
	if tile_data == null:
		return false # No tile here
	
	print(JSON.from_native(tile_data))
	
	# Check if tile is bedrock (unbreakable)
	var atlas_coords = ore_tilemap.get_cell_atlas_coords(tile_pos)
	
	# Determine ore type from atlas coords
	var ore_type = _atlas_to_ore_type(atlas_coords)
	
	# Remove the tile from the HP tracking
	block_hp.erase(tile_pos)
	
	set_cells_terrain_connect([tile_pos], 0, -1, false)
	ore_tilemap.erase_cell(tile_pos)
	
	# Only spawn ore drops for actual ore blocks (not stone)
	if ore_type != "STONE":
		spawn_ore_drop(map_to_local(tile_pos), ore_type)
	
	# Remove fog of war
	_unfog_area(tile_pos)
	
	# Emit signal
	block_broken.emit(tile_pos, ore_type)
	
	return true

## Spawn an ore drop entity with random size and shape
func spawn_ore_drop(world_pos: Vector2, ore_type: String) -> void:
	if not ORE_ITEM_SCENE:
		print("ORE_ITEM_SCENE not loaded!")
		return
	
	# Generate ore data with the specific ore type from the broken block
	var ore_data = OreGenerator.generate_ore_data(ore_type)
	
	# Create ore instance
	var ore: OreItem = ORE_ITEM_SCENE.instantiate()
	get_parent().add_child(ore)
	ore.global_position = world_pos
	
	# Initialize with generated data
	ore.initialize(
		ore_data.type,
		ore_data.size,
		ore_data.base_price,
		ore_data.shape,
		ore_data.atlas_coord,
		ore_data.color
	)
	
	print("Spawned ", ore_data.type, " ore (size: ", ore_data.size, ", value: $", ore_data.total_value, ")")


## Check if a tile exists at position
func has_tile_at(world_pos: Vector2) -> bool:
	var tile_pos = local_to_map(to_local(world_pos))
	return get_cell_source_id(tile_pos) != -1

## Get current depth based on player position
func get_depth_at_position(world_pos: Vector2) -> int:
	var tile_pos = local_to_map(to_local(world_pos))
	return max(0, tile_pos.y) # Surface is y=0

## Get tiles in a radius around a position
func get_tiles_in_radius(world_pos: Vector2, radius: float) -> Array[Vector2i]:
	var center_tile = local_to_map(to_local(world_pos))
	var tiles: Array[Vector2i] = []
	var radius_tiles = int(ceil(radius / tile_set.tile_size.x))
	
	for y in range(center_tile.y - radius_tiles, center_tile.y + radius_tiles + 1):
		for x in range(center_tile.x - radius_tiles, center_tile.x + radius_tiles + 1):
			var tile_pos = Vector2i(x, y)
			if get_cell_source_id(tile_pos) != -1:
				var tile_world_pos = map_to_local(tile_pos)
				if world_pos.distance_to(tile_world_pos) <= radius:
					tiles.append(tile_pos)
	
	return tiles

func _unfog_area(tile_pos: Vector2i) -> void:
	var surrounding := get_surrounding_cells(tile_pos)
	surrounding.append_array([
		tile_pos + Vector2i(1, 1),
		tile_pos + Vector2i(-1, -1),
		tile_pos + Vector2i(-1, 1),
		tile_pos + Vector2i(1, -1),
	])
	for tile in surrounding:
		fog_tilemap.erase_cell(tile)

func _atlas_to_ore_type(atlas_coords: Vector2i) -> String:
	var type = ORE_ATLAS.find_key(atlas_coords);
	if not type:
		return "STONE"
	return type
