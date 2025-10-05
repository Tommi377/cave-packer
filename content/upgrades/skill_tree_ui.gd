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

const CELL_SIZE = 100
const NODE_SIZE = 80

var upgrade_buttons = {}
var selected_upgrade_id: String = ""
var last_can_purchase: bool = false # Track state changes

func _ready():
	initialize()

func initialize():
	tree_ui.initialize()
	tree_ui.upgrade_pressed.connect(_on_purchase_button_pressed)
	tree_ui.upgrade_hovered.connect(_on_upgrade_button_hovered)

func can_purchase(upgrade_id: String) -> bool:
	if not UpgradeManager:
		return false
	
	return UpgradeManager.can_purchase(upgrade_id)

func refresh_tree():
	tree_ui.refresh_tree()
		
	## Update info panel if something is selected
	if selected_upgrade_id != "":
		_show_upgrade_info(selected_upgrade_id)
		
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
	
	upgrade_desc_label.text = desc
	
	# Multi-currency cost display
	var costs = upgrade.get_currency_costs(current_level)
	if current_level >= upgrade.max_level:
		upgrade_cost_label.text = "MAXED OUT"
	elif not costs.is_empty():
		var cost_text = "Cost: "
		var cost_parts = []
		for ore_type in costs:
			var ore_name = ore_type.capitalize()
			cost_parts.append("%d %s" % [costs[ore_type], ore_name])
		upgrade_cost_label.text = cost_text + ", ".join(cost_parts)
	else:
		upgrade_cost_label.text = "Free"
	
	upgrade_level_label.text = "Level: %d/%d" % [current_level, upgrade.max_level]
	
func _on_purchase_button_pressed(id: String):
	print("Upgrade %s pressed!" % [id])
	purchase_requested.emit(id)
	refresh_tree()
