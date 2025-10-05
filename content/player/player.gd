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
@export var jump_velocity: float = -270.0
@export var jump_cut_multiplier: float = 0.5 # How much to reduce velocity when releasing jump early
@export var coyote_time: float = 0.1 # Time after leaving ground where jump is still allowed
@export var jump_buffer_time: float = 0.1 # Time before landing where jump input is remembered
@export var max_air_jumps: int = 0 # Number of additional jumps allowed in air (0 = no double jump, 1 = double jump, 2 = triple jump, etc.)

@export_group("Gravity")
@export var gravity: float = 980.0
@export var max_fall_speed: float = 500.0
@export var fast_fall_multiplier: float = 1.3 # Faster fall when holding down

@export_group("Pickaxe")
@export var pickaxe_range: float = 16.0
@export var pickaxe_cooldown: float = 1.0
@export var pickaxe_damage: int = 1 # Damage dealt per pickaxe swing

# State tracking
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var pickaxe_timer: float = 0.0
var is_attacking: bool = false
var facing_right: bool = true
var air_jumps_used: int = 0 # Track how many air jumps have been used

# Node references
@onready var visual: CanvasGroup = %Visual
@onready var pickaxe_container: Node2D = $Visual/PickaxeContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var walk_animation: AnimationPlayer = $WalkAnimation

# Possibly useless?
@onready var pickaxe_hitbox: Area2D = $PickaxeHitbox if has_node("PickaxeHitbox") else null

# Inventory reference (set by level controller)
var inventory_ui: InventoryUI = null
var inventory_mode_active: bool = false

func _ready() -> void:
	# Ensure the player uses the floor detection properly
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(46) # Spelunky-like slope handling
	
	# Apply upgrades
	apply_upgrades()

func apply_upgrades() -> void:
	# Check if UpgradeManager exists and apply upgrades
	if not UpgradeManager:
		return
	
	# Set max air jumps based on double_jump upgrade level
	# Level 0 = 0 air jumps (no double jump)
	# Level 1 = 1 air jump (double jump)
	# Level 2 = 2 air jumps (triple jump), etc.
	max_air_jumps = UpgradeManager.get_upgrade_level("double_jump")
	
	# Apply movement speed multiplier
	var speed_multiplier = UpgradeManager.get_move_speed_multiplier()
	move_speed *= speed_multiplier
	
	# Apply jump height multiplier
	var jump_multiplier = UpgradeManager.get_jump_height_multiplier()
	jump_velocity *= jump_multiplier

func _physics_process(delta: float) -> void:
	update_timers(delta)

	# Don't process movement if inventory is active
	if inventory_mode_active:
		velocity = Vector2.ZERO
		return

	var input_direction := get_input_direction()
	
	apply_gravity(delta, input_direction)
	handle_jump()
	handle_horizontal_movement(delta, input_direction)
	handle_pickaxe()
	update_sprite_direction(input_direction)
	
	move_and_slide()
	
	if is_on_floor():
		coyote_timer = coyote_time
		air_jumps_used = 0 # Reset air jumps when landing
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
	
	# Perform regular jump if conditions are met (on ground or coyote time)
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		# Play jump sound/animation here
	# Perform air jump if available (double jump, triple jump, etc.)
	elif Input.is_action_just_pressed("jump") and air_jumps_used < max_air_jumps and not is_on_floor():
		velocity.y = jump_velocity
		air_jumps_used += 1
		# Play air jump sound/animation here
		print("Air jump %d/%d" % [air_jumps_used, max_air_jumps])
	
	# Jump cut: reduce upward velocity if player releases jump early
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func handle_horizontal_movement(delta: float, input_direction: float) -> void:
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	var current_friction := friction if is_on_floor() else air_friction
	
	if velocity.x != 0:
		walk_animation.play("move")
	elif walk_animation.is_playing():
		walk_animation.play("RESET")
	
	if input_direction != 0:
		# Accelerate in the input direction
		velocity.x = move_toward(velocity.x, input_direction * move_speed, current_acceleration * delta)
	else:
		# Apply friction when no input
		velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)

func handle_pickaxe() -> void:
	if Input.is_action_pressed("move_up"):
		pickaxe_container.position = Vector2(-8, 0)
		pickaxe_container.rotation = deg_to_rad(-60)
		
	elif Input.is_action_pressed("move_down"):
		# Mining downward
		pickaxe_container.position = Vector2(0, -2) # One tile down
		pickaxe_container.rotation = deg_to_rad(90)
	else:
		pickaxe_container.position = Vector2(0, 0)
		pickaxe_container.rotation = deg_to_rad(0)
	
	if (
		(Input.is_action_pressed("pickup") or Input.is_action_pressed("attack")) and
		pickaxe_timer <= 0
	):
		swing_pickaxe()

func swing_pickaxe() -> void:
	is_attacking = true
	pickaxe_timer = pickaxe_cooldown
	
	# Play attack animation with adjusted speed to match cooldown
	if animation_player and animation_player.has_animation("pickaxe_swing"):
		# Play the animation with custom speed (doesn't affect other animations)
		animation_player.play("pickaxe_swing", -1, 1.0 / pickaxe_cooldown * 0.2 + 0.1)
		# The third parameter is speed_scale for this specific play() call
		# Formula: (1.0 / pickaxe_cooldown) * animation_default_length
		# This makes a 0.2s animation match any cooldown duration
	
	# Check for destructible blocks in range
	detect_and_break_blocks()
	
	# Reset attack state after animation completes
	await get_tree().create_timer(pickaxe_cooldown).timeout
	is_attacking = false

func detect_and_break_blocks() -> void:
	# Determine mining direction based on input
	var mine_direction := Vector2.ZERO
	
	# Check for directional input
	if Input.is_action_pressed("move_up"):
		# Mining upward
		mine_direction = Vector2(0, -16) # One tile up (16 pixels)
	elif Input.is_action_pressed("move_down"):
		# Mining downward
		mine_direction = Vector2(0, 16) # One tile down
	else:
		# Mining forward (left or right based on facing direction)
		mine_direction = Vector2(16 if facing_right else -16, 0)
	
	var check_position := global_position + mine_direction
	
	# Find the tilemap in the scene
	var tilemap = get_tree().get_first_node_in_group("tilemap")
	if tilemap and tilemap.has_method("damage_tile_at_position"):
		var hit_tile = tilemap.damage_tile_at_position(check_position, pickaxe_damage)
		if hit_tile:
			print("Hit tile at: ", check_position, " (direction: ", mine_direction, ") for ", pickaxe_damage, " damage")
		else:
			print("No tile to hit at: ", check_position)
	else:
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

## Called by OreItem when player touches it
func collect_ore(_ore: Node2D) -> void:
	# Ores are no longer automatically collected
	# They must be picked up through the inventory UI
	pass
