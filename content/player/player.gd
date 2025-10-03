extends CharacterBody2D
class_name Player

# Movement parameters - Spelunky-inspired values
@export_group("Movement")
@export var move_speed: float = 180.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0
@export var air_acceleration: float = 800.0
@export var air_friction: float = 400.0

@export_group("Jump")
@export var jump_velocity: float = -380.0
@export var jump_cut_multiplier: float = 0.5 # How much to reduce velocity when releasing jump early
@export var coyote_time: float = 0.1 # Time after leaving ground where jump is still allowed
@export var jump_buffer_time: float = 0.1 # Time before landing where jump input is remembered

@export_group("Gravity")
@export var gravity: float = 980.0
@export var max_fall_speed: float = 500.0
@export var fast_fall_multiplier: float = 1.3 # Faster fall when holding down

@export_group("Pickaxe")
@export var pickaxe_range: float = 32.0
@export var pickaxe_cooldown: float = 0.3

# State tracking
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var pickaxe_timer: float = 0.0
var is_attacking: bool = false
var facing_right: bool = true

# Node references
@onready var visual: CanvasGroup = %Visual
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var pickaxe_hitbox: Area2D = $PickaxeHitbox if has_node("PickaxeHitbox") else null

func _ready() -> void:
	# Ensure the player uses the floor detection properly
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(46) # Spelunky-like slope handling

func _physics_process(delta: float) -> void:
	update_timers(delta)

	var input_direction := get_input_direction()
	
	apply_gravity(delta, input_direction)
	handle_jump()
	handle_horizontal_movement(delta, input_direction)
	handle_pickaxe()
	update_sprite_direction(input_direction)
	
	move_and_slide()
	
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

func get_input_direction() -> float:
	var direction := 0.0
	if Input.is_action_pressed("move_right"):
		direction += 1.0
	if Input.is_action_pressed("move_left"):
		direction -= 1.0
	return direction

func apply_gravity(delta: float, _input_direction: float) -> void:
	if not is_on_floor():
		var gravity_multiplier := 1.0
		
		# Fast fall when holding down
		if Input.is_action_pressed("move_down") and velocity.y > 0:
			gravity_multiplier = fast_fall_multiplier
		
		velocity.y += gravity * gravity_multiplier * delta
		velocity.y = min(velocity.y, max_fall_speed)

func handle_jump() -> void:
	# Jump buffer: remember jump input for a short time
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	# Perform jump if conditions are met
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		# Play jump sound/animation here
	
	# Jump cut: reduce upward velocity if player releases jump early
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func handle_horizontal_movement(delta: float, input_direction: float) -> void:
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	var current_friction := friction if is_on_floor() else air_friction
	
	if input_direction != 0:
		# Accelerate in the input direction
		velocity.x = move_toward(velocity.x, input_direction * move_speed, current_acceleration * delta)
	else:
		# Apply friction when no input
		velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)

func handle_pickaxe() -> void:
	if Input.is_action_just_pressed("attack") and pickaxe_timer <= 0:
		swing_pickaxe()

func swing_pickaxe() -> void:
	is_attacking = true
	pickaxe_timer = pickaxe_cooldown
	
	# Play attack animation
	if animation_player and animation_player.has_animation("pickaxe_swing"):
		animation_player.play("pickaxe_swing")
	
	# Check for destructible blocks in range
	detect_and_break_blocks()
	
	# Reset attack state after a short delay
	await get_tree().create_timer(0.2).timeout
	is_attacking = false

func detect_and_break_blocks() -> void:
	# Calculate the position to check for blocks based on facing direction
	var check_offset := Vector2(pickaxe_range if facing_right else -pickaxe_range, 0)
	var check_position := global_position + check_offset
	
	# Here you would implement tilemap detection and destruction
	# This will be connected to your tilemap system
	# Example: get_tilemap().break_tile_at_position(check_position)
	
	print("Swing pickaxe at position: ", check_position)

func update_sprite_direction(input_direction: float) -> void:
	if input_direction > 0:
		facing_right = true
		if visual:
			visual.scale.x = 1.0 # Face right (normal)
		if pickaxe_hitbox:
			pickaxe_hitbox.position.x = abs(pickaxe_hitbox.position.x) # Positive x (right side)
	elif input_direction < 0:
		facing_right = false
		if visual:
			visual.scale.x = -1.0 # Face left (flipped)
		if pickaxe_hitbox:
			pickaxe_hitbox.position.x = - abs(pickaxe_hitbox.position.x) # Negative x (left side)

func update_timers(delta: float) -> void:
	if coyote_timer > 0:
		coyote_timer -= delta
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if pickaxe_timer > 0:
		pickaxe_timer -= delta

# Public methods for external systems

func take_damage(_amount: int) -> void:
	# Implement damage system
	pass

func collect_ore(_ore_data: Dictionary) -> void:
	# Implement ore collection
	pass
