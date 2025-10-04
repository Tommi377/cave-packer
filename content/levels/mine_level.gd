extends Node2D

@onready var tilemap: TileMapLayer = $MineTilemap
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D

# Inventory UI
var inventory_ui: Control = null

func _ready() -> void:
	setup_camera()
	setup_inventory()
	
	# Connect tilemap signals
	if tilemap:
		tilemap.block_broken.connect(_on_block_broken)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()

func setup_camera() -> void:
	if player and camera:
		camera.enabled = true
		camera.zoom = Vector2(2.0, 2.0)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0

func setup_inventory() -> void:
	# Create a CanvasLayer for UI (stays fixed on screen)
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Load and instantiate inventory UI
	var inventory_scene = load("res://content/inventory/inventory_ui.tscn")
	if inventory_scene:
		inventory_ui = inventory_scene.instantiate()
		ui_layer.add_child(inventory_ui)
		
		# Position in top-right corner (screen coordinates)
		inventory_ui.position = Vector2(550, 20)
		inventory_ui.visible = true
		
		# Connect player to inventory
		if player:
			player.inventory_ui = inventory_ui
		
		print("Inventory UI setup complete")
	else:
		print("Failed to load inventory UI scene")

func toggle_inventory() -> void:
	if inventory_ui:
		inventory_ui.visible = not inventory_ui.visible

func _on_block_broken(tile_pos: Vector2i, ore_type: String) -> void:
	print("Block broken at ", tile_pos, " - Ore type: ", ore_type)
