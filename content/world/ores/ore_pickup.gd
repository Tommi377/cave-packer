extends RigidBody2D
class_name OrePickup

## Ore properties
@export var ore_type: String = "stone"
@export var ore_value: int = 1
@export var tetromino_shape: Array[Vector2i] = [Vector2i(0, 0)] # Single block by default

## Visual
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var pickup_area: Area2D = $PickupArea

## Pickup settings
var can_be_picked_up: bool = false
var pickup_timer: float = 0.0
const PICKUP_DELAY = 0.3 # Delay before can be picked up

signal ore_collected(ore_data: Dictionary)

func _ready() -> void:
	# Set up physics
	gravity_scale = 1.0
	max_contacts_reported = 3
	contact_monitor = true
	
	# Connect pickup area
	if pickup_area:
		pickup_area.body_entered.connect(_on_pickup_area_entered)
	
	# Start pickup delay
	pickup_timer = PICKUP_DELAY

func _process(delta: float) -> void:
	# Update pickup timer
	if pickup_timer > 0:
		pickup_timer -= delta
		if pickup_timer <= 0:
			can_be_picked_up = true

func _on_pickup_area_entered(body: Node2D) -> void:
	if not can_be_picked_up:
		return
	
	if body is Player:
		collect(body)

func collect(player: Player) -> void:
	# Create ore data package
	var ore_data = {
		"type": ore_type,
		"value": ore_value,
		"shape": tetromino_shape,
		"color": sprite.modulate if sprite else Color.WHITE
	}
	
	# Notify player
	player.collect_ore(ore_data)
	
	# Emit signal
	ore_collected.emit(ore_data)
	
	# Remove from scene
	queue_free()

func apply_drop_impulse(impulse: Vector2) -> void:
	linear_velocity = impulse

func set_ore_color(color: Color) -> void:
	if sprite:
		sprite.modulate = color
