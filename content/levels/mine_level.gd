extends Node2D

@onready var tilemap: TileMapLayer = $MineTilemap
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var inventory_ui: InventoryUI = %InventoryUI
@onready var deadline_bar: ProgressBar = %DeadlineBar
@onready var deadline_label: Label = %DeadlineLabel
@onready var earnings_label: Label = %EarningsLabel
@onready var end_day_button: Button = %EndDayButton

@onready var deposit_box_area: Area2D = $DepositBox/Area2D
@onready var press_e_label: Label = $DepositBox/Label/PressELabel
@onready var profit_label: Label = $DepositBox/Label/ProfitLabel

var player_near_deposit: bool = false

func _ready() -> void:
	setup_camera()
	
	# Connect player to inventory
	if player and inventory_ui:
		player.inventory_ui = inventory_ui
		inventory_ui.set_player(player)
		inventory_ui.inventory_mode_changed.connect(_on_inventory_mode_changed)
	
	# Connect tilemap signals
	if tilemap:
		tilemap.block_broken.connect(_on_block_broken)
	
	# Connect deposit box
	if deposit_box_area:
		deposit_box_area.body_entered.connect(_on_deposit_area_entered)
		deposit_box_area.body_exited.connect(_on_deposit_area_exited)
	
	if end_day_button:
		end_day_button.pressed.connect(GameManager.end_run)
	
	# Connect to GameManager updates
	if GameManager:
		GameManager.deadline_changed.connect(_on_deadline_changed)
		GameManager.currency_deposited.connect(_on_currency_deposited)
		GameManager.run_started.connect(_on_run_started)
		GameManager.run_ended.connect(_on_run_ended)
		_update_deadline_display(GameManager.current_time, GameManager.max_time)
		_update_earnings_display()
	
	# Start the run
	if GameManager and not GameManager.run_active:
		GameManager.start_run()

func _input(event: InputEvent) -> void:
	# Inventory UI now handles toggle internally
	if event.is_action_pressed("interact"):
		if player_near_deposit:
			_deposit_inventory()
	if Input.is_key_label_pressed(KEY_O):
		GameManager.end_run()

func setup_camera() -> void:
	if player and camera:
		camera.enabled = true
		camera.zoom = Vector2(3.0, 3.0)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0

func toggle_inventory() -> void:
	# Deprecated - inventory UI handles this now
	pass

func _on_inventory_mode_changed(is_active: bool) -> void:
	# Update player's inventory mode state
	if player:
		player.inventory_mode_active = is_active
	
	# Pause/resume timer during inventory mode
	if GameManager:
		if is_active:
			GameManager.pause_timer()
		else:
			GameManager.resume_timer()

func _on_block_broken(tile_pos: Vector2i, ore_type: String) -> void:
	print("Block broken at ", tile_pos, " - Ore type: ", ore_type)

func _on_deposit_area_entered(body: Node2D):
	if body is Player:
		player_near_deposit = true
		press_e_label.visible = true
		print("Press E to deposit inventory")

func _on_deposit_area_exited(body: Node2D):
	if body is Player:
		player_near_deposit = false
		press_e_label.visible = false

func _deposit_inventory():
	if not inventory_ui:
		return
	
	# Get all ore items from inventory and group by type
	var ore_counts: Dictionary = {}
	var grid = inventory_ui.inventory_grid.get_grid_state()
	var counted_items = {}
	
	# Count ores by type
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var ore_data = grid[y][x]
			if ore_data != null:
				# Use grid_position as unique identifier
				var item_id = str(ore_data.get("grid_position", Vector2i(x, y)))
				if not counted_items.has(item_id):
					counted_items[item_id] = true
					var ore_type = ore_data.get("type", "iron")
					var ore_size = ore_data.get("size", 1)
					ore_counts[ore_type] = ore_counts.get(ore_type, 0) + ore_size
	
	if ore_counts.is_empty():
		print("No ores to deposit")
		return
	
	# Display what was deposited
	var deposit_text = ""
	for ore_type in ore_counts:
		deposit_text += "+%d %s\n" % [ore_counts[ore_type], ore_type.capitalize()]
	
	profit_label.text = deposit_text.strip_edges()
	profit_label.visible = true
	var timer := get_tree().create_timer(2)
	timer.timeout.connect(func(): profit_label.visible = false)
	
	# Deposit to GameManager
	if GameManager:
		for ore_type in ore_counts:
			GameManager.deposit_ores(ore_type, ore_counts[ore_type])
	
	# Clear inventory after successful deposit
	inventory_ui.inventory_grid.clear_all()
	print("Deposited inventory: ", ore_counts)

func _toggle_upgrade_ui():
	# No longer needed - removed upgrade UI from mine level
	pass

func _on_deadline_changed(current: float, max_value: float):
	_update_deadline_display(current, max_value)

func _on_money_deposited(_amount: int):
	_update_earnings_display()

func _on_currency_deposited(_ore_type: String, _amount: int):
	_update_earnings_display()

func _on_run_started():
	_update_deadline_display(GameManager.current_time, GameManager.max_time)
	_update_earnings_display()

func _on_run_ended():
	print("Run completed!")
	# Return to surface automatically
	get_tree().change_scene_to_file("res://content/surface/surface_base.tscn")

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
			earnings_label.text = "Iron: %d\nCopper: %d\nGold: %d\nDiamond: %d" % [
				GameManager.get_currency("iron"),
				GameManager.get_currency("copper"),
				GameManager.get_currency("gold"),
				GameManager.get_currency("diamond")
			]

func _on_purchase_requested(_upgrade_id: String):
	# No longer needed - upgrade UI is on surface
	pass
