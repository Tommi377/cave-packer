extends RigidBody2D
class_name OreItem

## Represents a collectible ore drop with dynamic shape and value

signal picked_up(ore: OreItem)

@export var ore_type: String = "IRON_ORE"
@export var ore_size: int = 3 # Number of cells (1-8)
@export var base_price: int = 10 # Legacy - no longer used for currency
@export var shape_cells: Array[Vector2i] = [] # Grid positions relative to origin
@export var ore_color: Color = Color.WHITE # Color for visual display

var total_value: int = 0 # Legacy - equals ore_size now
var pickup_radius: float = 32.0
var atlas_coord: Vector2i = Vector2i(0, 4) # Default atlas coordinate

@onready var sprite: ColorRect = $Sprite
@onready var area: Area2D = $Area2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready():
	# In new system, total_value = ore_size (amount of that ore type)
	total_value = ore_size
	
	# Set color based on ore type
	_set_ore_color()
	
	# Configure physics
	gravity_scale = 1.0
	linear_damp = 2.0 # Add some air resistance
	angular_damp = 3.0 # Slow down rotation
	
	# Add to ore_items group for inventory detection
	add_to_group("ore_items")
	
	# Connect pickup signal
	if area:
		area.body_entered.connect(_on_body_entered)

func initialize(type: String, size: int, price: int, cells: Array[Vector2i], atlas_coord_param: Vector2i, color: Color = Color.WHITE):
	ore_type = type
	ore_size = size
	base_price = price # Legacy
	shape_cells = cells.duplicate()
	ore_color = color
	atlas_coord = atlas_coord_param
	total_value = size # New system: value = size
	
	# Set atlas texture region if sprite exists
	if sprite_2d and sprite_2d.texture:
		if sprite_2d.texture is AtlasTexture:
			sprite_2d.texture.region = Rect2(Vector2(atlas_coord) * Vector2(16, 16), Vector2(16, 16))
	
	_set_ore_color()
	
	# Add a small upward and random horizontal impulse when spawned
	var impulse_x = randf_range(-50, 50)
	var impulse_y = randf_range(-150, -100)
	apply_impulse(Vector2(impulse_x, impulse_y))
	
	# Add some random rotation
	angular_velocity = randf_range(-3, 3)

func _set_ore_color():
	if not sprite:
		return
	
	match ore_type:
		"stone":
			sprite.color = Color(0.5, 0.5, 0.5) # Gray
		"iron":
			sprite.color = Color(0.7, 0.6, 0.5) # Brown-gray
		"copper":
			sprite.color = Color(0.8, 0.5, 0.3) # Orange-brown
		"gold":
			sprite.color = Color(0.9, 0.8, 0.2) # Gold
		"diamond":
			sprite.color = Color(0.3, 0.8, 0.9) # Cyan
		_:
			sprite.color = Color.WHITE

func _on_body_entered(body: Node2D):
	if body.has_method("collect_ore"):
		body.collect_ore(self)
		picked_up.emit(self)

func get_inventory_data() -> Dictionary:
	return {
		"type": ore_type,
		"size": ore_size,
		"base_price": base_price,
		"total_value": total_value,
		"shape": shape_cells,
		"color": ore_color,
		"atlas_coord": atlas_coord
	}
