extends Node2D
class_name OreItem

## Represents a collectible ore drop with dynamic shape and value

signal picked_up(ore: OreItem)

@export var ore_type: String = "iron"
@export var ore_size: int = 3 # Number of cells (1-8)
@export var base_price: int = 10
@export var shape_cells: Array[Vector2i] = [] # Grid positions relative to origin

var total_value: int = 0
var pickup_radius: float = 32.0

@onready var sprite: ColorRect = $Sprite
@onready var area: Area2D = $Area2D
@onready var collision: CollisionShape2D = $Area2D/CollisionShape2D

func _ready():
	# Calculate total value
	total_value = base_price * ore_size
	
	# Set color based on ore type
	_set_ore_color()
	
	# Set up collision and visual size
	_setup_visuals()
	
	# Connect pickup signal
	if area:
		area.body_entered.connect(_on_body_entered)

func initialize(type: String, size: int, price: int, cells: Array[Vector2i]):
	ore_type = type
	ore_size = size
	base_price = price
	shape_cells = cells.duplicate()
	total_value = base_price * size

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

func _setup_visuals():
	# Size the sprite based on ore size (rough approximation)
	var visual_size = 8 + (ore_size * 2)
	if sprite:
		sprite.size = Vector2(visual_size, visual_size)
		sprite.position = Vector2(-visual_size * 0.5, -visual_size * 0.5)
	
	# Set up collision shape
	if collision:
		var shape = CircleShape2D.new()
		shape.radius = visual_size * 0.5
		collision.shape = shape

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
		"shape": shape_cells
	}
