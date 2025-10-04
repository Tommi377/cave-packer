extends Node2D

## Surface base scene controller

@onready var upgrade_ui: SkillTreeUI = $UILayer/SkillTreeUI
@onready var currency_label: Label = $UILayer/CurrencyLabel
@onready var start_run_button: Button = $UILayer/StartRunButton

func _ready():
	start_run_button.pressed.connect(_on_start_run_pressed)
	
	upgrade_ui.purchase_requested.connect(_on_purchase_requested)
	_update_currency_display()
	
	# Listen for day ended to refresh UI
	if GameManager:
		GameManager.day_ended.connect(_on_day_ended)
	
	# Give some starting currency for testing (first time only)
	if GameManager and GameManager.current_day_earnings == 0:
		GameManager.current_day_earnings = 500
		
func _on_start_run_pressed():
	if GameManager:
		GameManager.start_day()
	else:
		push_error("GameManager not found!")
		
func _on_purchase_requested(upgrade_id: String):
	if UpgradeManager:
		if UpgradeManager.purchase_upgrade(upgrade_id):
			print("Purchased upgrade: ", upgrade_id)
			upgrade_ui.refresh_tree()
			_update_currency_display()
		else:
			print("Cannot purchase upgrade: ", upgrade_id)
			
func _update_currency_display():
	if GameManager:
		currency_label.text = "Credits: %d" % GameManager.current_day_earnings

func _on_day_ended(goal_reached: bool):
	# Refresh currency display after day
	_update_currency_display()
	upgrade_ui.refresh_tree()
	
	if goal_reached:
		print("Day successful! Goal reached.")
	else:
		print("Day failed! Goal not reached.")
