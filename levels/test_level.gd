extends Node2D

@onready var player: Player = $Player
@onready var startPos := player.global_position

func _ready() -> void:
	# Set up the test level
	setup_camera()

func _input(_event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_R):
		player.global_position = startPos

func setup_camera() -> void:
	if player:
		var camera = Camera2D.new()
		camera.enabled = true
		camera.zoom = Vector2(2.5, 2.5)  # Zoom in for better view
		player.add_child(camera)
