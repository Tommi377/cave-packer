extends Control
class_name SkillTreeUI

## Visual skill tree interface

signal upgrade_selected(upgrade_id: String)
signal purchase_requested(upgrade_id: String)

@onready var tree_ui: TreeUI = $TreeUI
@onready var tree_container: Control = $TreeContainer
@onready var info_panel: PanelContainer = $InfoPanel
@onready var upgrade_name_label: Label = $InfoPanel/MarginContainer/VBox/UpgradeName
@onready var upgrade_desc_label: Label = $InfoPanel/MarginContainer/VBox/Description
@onready var upgrade_cost_label: Label = $InfoPanel/MarginContainer/VBox/Cost
@onready var upgrade_level_label: Label = $InfoPanel/MarginContainer/VBox/Level
@onready var purchase_button: Button = $InfoPanel/MarginContainer/VBox/PurchaseButton

const CELL_SIZE = 100
const NODE_SIZE = 80

var upgrade_buttons = {}
var selected_upgrade_id: String = ""
var last_can_purchase: bool = false # Track state changes

func _ready():
	initialize()

# Update purchase button state every frame when info panel is visible
func _process(_delta):
	pass
	#if info_panel.visible and selected_upgrade_id != "":
		#var can_buy = can_purchase(selected_upgrade_id)
		#purchase_button.disabled = not can_buy
		#
		## Debug info only when state changes
		#if can_buy != last_can_purchase:
			#last_can_purchase = can_buy
			#if GameManager:
				#var cost = UpgradeManager.get_upgrade_cost(selected_upgrade_id)
				#print("Purchase state changed - Money: ", GameManager.total_money, " Cost: ", cost, " Can buy: ", can_buy)
	
func initialize():
	tree_ui.initialize()
	tree_ui.upgrade_pressed.connect(_on_purchase_button_pressed)

func can_purchase(upgrade_id: String) -> bool:
	if not UpgradeManager:
		return false
	
	return UpgradeManager.can_purchase(upgrade_id)

func refresh_tree():
	tree_ui.refresh_tree()
		
	## Update info panel if something is selected
	#if selected_upgrade_id != "":
		#_show_upgrade_info(selected_upgrade_id)
		
	queue_redraw()

func _on_upgrade_button_pressed(upgrade_id: String):
	selected_upgrade_id = upgrade_id
	_show_upgrade_info(upgrade_id)
	upgrade_selected.emit(upgrade_id)

func _on_upgrade_button_hovered(upgrade_id: String):
	# Show info on hover
	selected_upgrade_id = upgrade_id
	_show_upgrade_info(upgrade_id)
	
func _show_upgrade_info(upgrade_id: String):
	var upgrade = UpgradeManager.get_upgrade(upgrade_id)
	if not upgrade:
		return
	
	var current_level = UpgradeManager.get_upgrade_level(upgrade_id)
	
	info_panel.visible = true
	upgrade_name_label.text = upgrade.display_name
	
	# Use the upgrade resource's description formatting
	var desc = upgrade.get_description_with_values(current_level)
	
	# Add prerequisite info if locked
	if upgrade.required_upgrades.size() > 0:
		var all_reqs_met = true
		var req_text = "\n\nRequires:"
		for req_id in upgrade.required_upgrades:
			var req = UpgradeManager.get_upgrade(req_id)
			if not req:
				continue
			
			var req_level = UpgradeManager.get_upgrade_level(req_id)
			if req_level < upgrade.required_level:
				req_text += "\n  ✗ " + req.display_name + " (Level " + str(upgrade.required_level) + ")"
				all_reqs_met = false
			else:
				req_text += "\n  ✓ " + req.display_name
		
		if not all_reqs_met:
			desc += req_text
	
	upgrade_desc_label.text = desc
	
	var cost = upgrade.get_cost(current_level)
	if current_level >= upgrade.max_level:
		upgrade_cost_label.text = "MAXED OUT"
		purchase_button.text = "Maxed"
	elif cost > 0:
		if GameManager:
			upgrade_cost_label.text = "Cost: %d (You have: %d)" % [cost, GameManager.total_money]
		else:
			upgrade_cost_label.text = "Cost: %d" % cost
		purchase_button.text = "Purchase"
	
	upgrade_level_label.text = "Level: %d/%d" % [current_level, upgrade.max_level]
	
	purchase_button.disabled = not can_purchase(upgrade_id)
	
func _on_purchase_button_pressed(id: String):
	print("Upgrade %s pressed!" % [id])
	purchase_requested.emit(id)
