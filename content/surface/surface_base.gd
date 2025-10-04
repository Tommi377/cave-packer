extends Node2D

## Surface base scene controller

@onready var upgrade_ui: SkillTreeUI = $UILayer/SkillTreeUI
@onready var currency_label: Label = $UILayer/CurrencyLabel
@onready var start_run_button: Button = $UILayer/StartRunButton

func _ready():
	start_run_button.pressed.connect(_on_start_run_pressed)
	
	upgrade_ui.purchase_requested.connect(_on_purchase_requested)
	_update_currency_display()
	
	# Listen for run ended to refresh UI
	if GameManager:
		GameManager.run_ended.connect(_on_run_ended)
	
	# Give some starting currency for testing (first time only)
	if UpgradeManager and UpgradeManager.currency == 0:
		UpgradeManager.currency = 100
		
func _on_start_run_pressed():
	if GameManager:
		GameManager.start_run()
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
	if UpgradeManager:
		currency_label.text = "Credits: %d" % UpgradeManager.currency

func _on_run_ended(success: bool):
	# Refresh currency display after run
	_update_currency_display()
	upgrade_ui.refresh_tree()
	
	if success:
		print("Run successful! Inventory sold.")
	else:
		print("Run failed! Inventory lost.")
