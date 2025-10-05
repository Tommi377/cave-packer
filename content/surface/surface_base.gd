extends Node2D

## Surface base scene controller - incremental game loop

@onready var upgrade_ui: SkillTreeUI = $UILayer/SkillTreeUI
@onready var currency_label: Label = $UILayer/CurrencyLabel
@onready var start_run_button: Button = $UILayer/StartRunButton

func _ready():
	start_run_button.pressed.connect(_on_start_run_pressed)
	
	upgrade_ui.purchase_requested.connect(_on_purchase_requested)
	
	# Listen for run ended to refresh UI and show skill tree
	if GameManager:
		GameManager.run_ended.connect(_on_run_ended)
	
	# Update currency display
	_update_currency_display()
	
	# Show skill tree immediately - we only arrive here after a run ends
	if upgrade_ui:
		upgrade_ui.visible = true
		# Defer refresh to ensure all systems are ready
		call_deferred("_refresh_skill_tree")
		
func _on_start_run_pressed():
	if GameManager:
		# Change to mine scene - GameManager will start the run there
		get_tree().change_scene_to_file("res://content/levels/mine_level.tscn")
		upgrade_ui.visible = false
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
		currency_label.text = "Iron: %d\nCopper: %d\nGold: %d\nDiamond: %d" % [
			GameManager.get_currency("iron"),
			GameManager.get_currency("copper"),
			GameManager.get_currency("gold"),
			GameManager.get_currency("diamond")
		]

func _on_run_ended():
	# Refresh currency display and skill tree after run
	_update_currency_display()
	if upgrade_ui:
		upgrade_ui.refresh_tree()
		upgrade_ui.visible = true

func _refresh_skill_tree():
	# Deferred function to refresh skill tree after ready
	if upgrade_ui:
		upgrade_ui.refresh_tree()
