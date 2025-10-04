extends Node2D

@onready var tilemap: TileMapLayer = $MineTilemap
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var inventory_ui: Control = $UILayer/InventoryUI

func _ready() -> void:
	setup_camera()
	
	# Connect player to inventory
	if player and inventory_ui:
		player.inventory_ui = inventory_ui
	
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

func toggle_inventory() -> void:
	if inventory_ui:
		inventory_ui.visible = not inventory_ui.visible

func _on_block_broken(tile_pos: Vector2i, ore_type: String) -> void:
	print("Block broken at ", tile_pos, " - Ore type: ", ore_type)
