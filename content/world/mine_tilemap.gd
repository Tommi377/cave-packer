extends TileMapLayer
class_name MineTilemap

## Tile types (atlas coordinates)
enum TileType {
	AIR = -1,
	DIRT = 0,
	STONE = 1,
	IRON_ORE = 2,
	GOLD_ORE = 3,
	CRYSTAL_ORE = 4
}

## Depth zones (measured in tiles from surface)
const SURFACE_DEPTH = 0
const MID_DEPTH = 20
const DEEP_DEPTH = 40

## Ore spawn chances by depth
const ORE_SPAWN_CHANCE = {
	"surface": {"stone": 0.95, "iron": 0.05},
	"mid": {"stone": 0.70, "iron": 0.25, "gold": 0.05},
	"deep": {"stone": 0.50, "iron": 0.20, "gold": 0.15, "crystal": 0.15}
}

## Ore drop scene paths (lazy loaded)
const ORE_SCENE_PATHS = {
	"stone": "res://content/world/ores/ore_stone.tscn",
	"iron": "res://content/world/ores/ore_iron.tscn",
	"gold": "res://content/world/ores/ore_gold.tscn",
	"crystal": "res://content/world/ores/ore_crystal.tscn",
}

var ore_scenes = {}

signal block_broken(tile_pos: Vector2i, ore_type: String)
signal depth_changed(depth: int)

func _ready() -> void:
	add_to_group("tilemap")
	
	# Setup TileSet if not configured
	if tile_set == null or tile_set.get_physics_layers_count() == 0:
		_setup_tileset()
	
	# Load ore scenes if they exist
	for ore_type in ORE_SCENE_PATHS:
		var path = ORE_SCENE_PATHS[ore_type]
		if ResourceLoader.exists(path):
			ore_scenes[ore_type] = load(path)
	
	# Generate initial mine if empty
	if get_used_cells().is_empty():
		generate_mine()

## Setup a basic TileSet programmatically
func _setup_tileset() -> void:
	# Create TileSet if needed
	if tile_set == null:
		tile_set = TileSet.new()
	
	# Setup physics layer
	if tile_set.get_physics_layers_count() == 0:
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, 1) # Layer 1 for world
	
	# Create atlas source if needed
	var atlas_source_id = 0
	var atlas: TileSetAtlasSource
	
	if tile_set.has_source(atlas_source_id):
		atlas = tile_set.get_source(atlas_source_id)
	else:
		atlas = TileSetAtlasSource.new()
		
		# Create a texture atlas with colored tiles (5 tiles x 1 row = 80x16 pixels)
		var image = Image.create(80, 16, false, Image.FORMAT_RGBA8)
		
		# Fill with tile colors
		var colors = [
			Color(0.4, 0.3, 0.2),      # 0: Dirt (brown)
			Color(0.5, 0.5, 0.5),      # 1: Stone (gray)
			Color(0.8, 0.5, 0.3),      # 2: Iron ore (orange)
			Color(0.8, 0.7, 0.2),      # 3: Gold ore (golden)
			Color(0.3, 0.7, 0.9)       # 4: Crystal ore (cyan)
		]
		
		for i in range(5):
			image.fill_rect(Rect2i(i * 16, 0, 16, 16), colors[i])
		
		var texture = ImageTexture.create_from_image(image)
		atlas.texture = texture
		atlas.texture_region_size = Vector2i(16, 16)
		
		tile_set.add_source(atlas, atlas_source_id)
	
	# Define tiles with collision
	var tile_coords = [
		Vector2i(0, 0), # Dirt
		Vector2i(1, 0), # Stone
		Vector2i(2, 0), # Iron ore
		Vector2i(3, 0), # Gold ore
		Vector2i(4, 0)  # Crystal ore
	]
	
	for coords in tile_coords:
		if not atlas.has_tile(coords):
			atlas.create_tile(coords)
			
			# Add collision shape (full 16x16 square)
			var tile_data = atlas.get_tile_data(coords, 0)
			if tile_data:
				tile_data.set_collision_polygons_count(0, 1)
				var collision_polygon = PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8),
					Vector2(8, 8), Vector2(-8, 8)
				])
				tile_data.set_collision_polygon_points(0, 0, collision_polygon)

## Generate the mine shaft
func generate_mine(width: int = 40, depth: int = 60) -> void:
	# Clear existing tiles
	clear()
	
	# Generate from top (y=0) to bottom
	for y in range(depth):
		for x in range(width):
			var tile_type = _get_tile_for_depth(y)
			var atlas_coords = _tile_type_to_atlas(tile_type)
			set_cell(Vector2i(x, y), 0, atlas_coords)
	
	# Create surface platform (y = -1)
	for x in range(width):
		set_cell(Vector2i(x, -1), 0, Vector2i(1, 0)) # Stone platform
	
	print("Mine generated: ", width, "x", depth, " tiles")

## Get appropriate tile type based on depth
func _get_tile_for_depth(depth_y: int) -> String:
	var zone = _get_depth_zone(depth_y)
	var chances = ORE_SPAWN_CHANCE[zone]
	
	# Random weighted selection
	var roll = randf()
	var cumulative = 0.0
	
	for ore_type in chances:
		cumulative += chances[ore_type]
		if roll <= cumulative:
			return ore_type
	
	return "stone" # Fallback

## Determine depth zone
func _get_depth_zone(depth_y: int) -> String:
	if depth_y < MID_DEPTH:
		return "surface"
	elif depth_y < DEEP_DEPTH:
		return "mid"
	else:
		return "deep"

## Convert ore type string to atlas coordinates
func _tile_type_to_atlas(ore_type: String) -> Vector2i:
	match ore_type:
		"stone":
			return Vector2i(1, 0)
		"iron":
			return Vector2i(2, 0)
		"gold":
			return Vector2i(3, 0)
		"crystal":
			return Vector2i(4, 0)
		_:
			return Vector2i(0, 0) # Dirt fallback

## Break a tile at world position
func break_tile_at_position(world_pos: Vector2) -> bool:
	var tile_pos = local_to_map(to_local(world_pos))
	return break_tile(tile_pos)

## Break a tile at tile coordinates
func break_tile(tile_pos: Vector2i) -> bool:
	var tile_data = get_cell_tile_data(tile_pos)
	if tile_data == null:
		return false # No tile here
	
	# Determine ore type from atlas coords
	var atlas_coords = get_cell_atlas_coords(tile_pos)
	var ore_type = _atlas_to_ore_type(atlas_coords)
	
	# Erase the tile
	erase_cell(tile_pos)
	
	# Spawn ore drop
	spawn_ore_drop(map_to_local(tile_pos), ore_type)
	
	# Emit signal
	block_broken.emit(tile_pos, ore_type)
	
	return true

## Convert atlas coords to ore type
func _atlas_to_ore_type(atlas_coords: Vector2i) -> String:
	match atlas_coords:
		Vector2i(0, 0):
			return "stone"
		Vector2i(1, 0):
			return "stone"
		Vector2i(2, 0):
			return "iron"
		Vector2i(3, 0):
			return "gold"
		Vector2i(4, 0):
			return "crystal"
		_:
			return "stone"

## Spawn an ore drop entity
func spawn_ore_drop(world_pos: Vector2, ore_type: String) -> void:
	# Check if we have the ore scene
	if not ore_scenes.has(ore_type) or ore_scenes[ore_type] == null:
		print("No ore scene for type: ", ore_type)
		return
	
	var ore = ore_scenes[ore_type].instantiate()
	get_parent().add_child(ore)
	ore.global_position = world_pos
	
	# Add some random velocity for juice
	if ore.has_method("apply_drop_impulse"):
		var impulse = Vector2(randf_range(-50, 50), randf_range(-100, -50))
		ore.apply_drop_impulse(impulse)

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
