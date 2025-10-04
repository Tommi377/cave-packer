extends Node2D

@onready var tilemap: TileMapLayer = $MineTilemap
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var inventory_ui: Control = $UILayer/InventoryUI
@onready var deadline_bar: ProgressBar = $UILayer/DeadlineBar
@onready var deadline_label: Label = $UILayer/DeadlineLabel
@onready var earnings_label: Label = $UILayer/EarningsLabel
@onready var goal_label: Label = $UILayer/GoalLabel
@onready var deposit_box_area: Area2D = $DepositBox/Area2D
@onready var computer_area: Area2D = $SurfaceComputer/Area2D
@onready var upgrade_ui: Control = $UILayer/UpgradeUI

var player_near_deposit: bool = false
var player_near_computer: bool = false

func _ready() -> void:
	setup_camera()
	
	# Connect player to inventory
	if player and inventory_ui:
		player.inventory_ui = inventory_ui
	
	# Connect tilemap signals
	if tilemap:
		tilemap.block_broken.connect(_on_block_broken)
	
	# Connect deposit box
	if deposit_box_area:
		deposit_box_area.body_entered.connect(_on_deposit_area_entered)
		deposit_box_area.body_exited.connect(_on_deposit_area_exited)
	
	# Connect computer
	if computer_area:
		computer_area.body_entered.connect(_on_computer_area_entered)
		computer_area.body_exited.connect(_on_computer_area_exited)
	
	# Connect to GameManager updates
	if GameManager:
		GameManager.deadline_changed.connect(_on_deadline_changed)
		GameManager.money_deposited.connect(_on_money_deposited)
		GameManager.day_started.connect(_on_day_started)
		GameManager.day_ended.connect(_on_day_ended)
		_update_deadline_display(GameManager.current_time, GameManager.max_time)
		_update_earnings_display()
	
	# Hide upgrade UI initially
	if upgrade_ui:
		upgrade_ui.visible = false
	
	# Start the day
	if GameManager and not GameManager.current_day_active:
		GameManager.start_day()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
	
	if event.is_action_pressed("interact"):
		if player_near_deposit:
			_deposit_inventory()
		elif player_near_computer:
			_toggle_upgrade_ui()

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

func _on_deposit_area_entered(body: Node2D):
	if body is Player:
		player_near_deposit = true
		print("Press E to deposit inventory")

func _on_deposit_area_exited(body: Node2D):
	if body is Player:
		player_near_deposit = false

func _on_computer_area_entered(body: Node2D):
	if body is Player:
		player_near_computer = true
		print("Press E to access upgrades")

func _on_computer_area_exited(body: Node2D):
	if body is Player:
		player_near_computer = false
		if upgrade_ui:
			upgrade_ui.visible = false

func _deposit_inventory():
	if not inventory_ui:
		return
	
	# Calculate total value from inventory
	var inventory_value = inventory_ui.get_total_value()
	
	if inventory_value == 0:
		print("No ores to deposit")
		return
	
	# Deposit to GameManager
	if GameManager:
		GameManager.deposit_ores(inventory_value)
	
	# Clear inventory after successful deposit
	inventory_ui.clear_all()
	print("Deposited inventory worth ", inventory_value, " credits")

func _toggle_upgrade_ui():
	if upgrade_ui:
		upgrade_ui.visible = not upgrade_ui.visible

func _on_deadline_changed(current: float, max_value: float):
	_update_deadline_display(current, max_value)

func _on_money_deposited(_amount: int):
	_update_earnings_display()

func _on_day_started():
	_update_deadline_display(GameManager.current_time, GameManager.max_time)
	_update_earnings_display()

func _on_day_ended(goal_met: bool):
	if goal_met:
		print("Day completed successfully!")
	else:
		print("Day failed - goal not reached")
	# Could show end-of-day screen here

func _update_deadline_display(current: float, max_value: float):
	if deadline_bar:
		deadline_bar.max_value = max_value
		deadline_bar.value = current
		
		# Color based on time left
		var percentage = (current / max_value) * 100.0
		if percentage > 50:
			deadline_bar.modulate = Color.GREEN
		elif percentage > 25:
			deadline_bar.modulate = Color.YELLOW
		else:
			deadline_bar.modulate = Color.RED
	
	if deadline_label:
		var total_seconds = int(current)
		var minutes = floori(total_seconds / 60.0)
		var seconds = total_seconds % 60
		deadline_label.text = "Time: %d:%02d" % [minutes, seconds]

func _update_earnings_display():
	if GameManager:
		if earnings_label:
			earnings_label.text = "Earnings: $%d" % GameManager.current_day_earnings
		if goal_label:
			goal_label.text = "Goal: $%d" % GameManager.money_goal
