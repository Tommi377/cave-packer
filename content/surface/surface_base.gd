extends Node2D

## Surface base scene controller

@onready var computer_area: Area2D = $ComputerTerminal/Area2D
@onready var upgrade_ui: SkillTreeUI = $UILayer/SkillTreeUI
@onready var currency_label: Label = $UILayer/CurrencyLabel
@onready var sell_button: Button = $UILayer/SellButton

var player: CharacterBody2D

func _ready():
	computer_area.body_entered.connect(_on_computer_area_entered)
	computer_area.body_exited.connect(_on_computer_area_exited)
	sell_button.pressed.connect(_on_sell_button_pressed)
	
	upgrade_ui.visible = true # Show by default on surface
	upgrade_ui.purchase_requested.connect(_on_purchase_requested)
	_update_currency_display()
	
	# Give some starting currency for testing
	if UpgradeManager:
		UpgradeManager.currency = 500
	
func _on_computer_area_entered(body: Node2D):
	if body.name == "Player":
		player = body
		# Show prompt to interact
		print("Press E to access computer")
		
func _on_computer_area_exited(body: Node2D):
	if body == player:
		player = null
		upgrade_ui.visible = false
		
func _process(_delta):
	if player and Input.is_action_just_pressed("interact"):
		_toggle_upgrade_ui()
		
func _toggle_upgrade_ui():
	upgrade_ui.visible = not upgrade_ui.visible
	if upgrade_ui.visible:
		upgrade_ui.refresh_tree()
		_update_currency_display()
		
func _on_purchase_requested(upgrade_id: String):
	if UpgradeManager:
		if UpgradeManager.purchase_upgrade(upgrade_id):
			print("Purchased upgrade: ", upgrade_id)
			upgrade_ui.refresh_tree()
			_update_currency_display()
		else:
			print("Cannot purchase upgrade: ", upgrade_id)
			
func _update_currency_display():
	if UpgradeManager:
		currency_label.text = "Credits: %d" % UpgradeManager.currency
		
func _on_sell_button_pressed():
	if not player:
		return
		
	# Access player's inventory
	var inventory = player.get("inventory_ui")
	if inventory:
		# Calculate total value from inventory
		# This would need inventory integration
		print("Selling inventory for credits")
