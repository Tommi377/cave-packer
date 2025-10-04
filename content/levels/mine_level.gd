extends Node2D

@onready var tilemap: TileMapLayer = $MineTilemap
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D

func _ready() -> void:
	setup_camera()
	
	# Connect tilemap signals
	if tilemap:
		tilemap.block_broken.connect(_on_block_broken)

func setup_camera() -> void:
	if player and camera:
		camera.enabled = true
		camera.zoom = Vector2(2.0, 2.0)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0

func _on_block_broken(tile_pos: Vector2i, ore_type: String) -> void:
	print("Block broken at ", tile_pos, " - Ore type: ", ore_type)
