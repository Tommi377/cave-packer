extends Control
class_name SkillTreeUI

## Visual skill tree interface

signal upgrade_selected(upgrade_id: String)
signal purchase_requested(upgrade_id: String)

@onready var tree_container: Control = $TreeContainer
@onready var info_panel: PanelContainer = $InfoPanel
@onready var upgrade_name_label: Label = $InfoPanel/VBox/UpgradeName
@onready var upgrade_desc_label: Label = $InfoPanel/VBox/Description
@onready var upgrade_cost_label: Label = $InfoPanel/VBox/Cost
@onready var upgrade_level_label: Label = $InfoPanel/VBox/Level
@onready var purchase_button: Button = $InfoPanel/VBox/PurchaseButton

const CELL_SIZE = 100
const NODE_SIZE = 80

var upgrade_buttons = {}
var selected_upgrade_id: String = ""

func _ready():
	purchase_button.pressed.connect(_on_purchase_button_pressed)
	info_panel.visible = false
	initialize()
	
func initialize():
	if UpgradeManager:
		_build_tree()
	else:
		push_error("UpgradeManager not found!")
	
func _build_tree():
	# Clear existing buttons
	for child in tree_container.get_children():
		child.queue_free()
	upgrade_buttons.clear()
	
	# Create button for each upgrade
	for upgrade_id in UpgradeManager.upgrades.keys():
		var upgrade = UpgradeManager.upgrades[upgrade_id]
		var button = _create_upgrade_button(upgrade)
		tree_container.add_child(button)
		upgrade_buttons[upgrade_id] = button
		
	# Draw connections
	queue_redraw()
	
func _create_upgrade_button(upgrade: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.text = upgrade.display_name
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Position based on tree_position
	var pos = upgrade.tree_position as Vector2i
	button.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
	
	button.pressed.connect(_on_upgrade_button_pressed.bind(upgrade.id))
	
	_update_button_style(button, upgrade)
	
	return button
	
func _update_button_style(button: Button, upgrade: Dictionary):
	# Color based on state
	if upgrade.current_level >= upgrade.max_level:
		button.modulate = Color(0.2, 0.8, 0.2) # Green - purchased
		button.disabled = true
	elif can_purchase(upgrade.id):
		button.modulate = Color(1.0, 1.0, 0.3) # Yellow - available
		button.disabled = false
	else:
		button.modulate = Color(0.5, 0.5, 0.5) # Gray - locked
		button.disabled = true
		
func can_purchase(upgrade_id: String) -> bool:
	var upgrade = UpgradeManager.upgrades[upgrade_id]
	
	# Check if maxed
	if upgrade.current_level >= upgrade.max_level:
		return false
		
	# Check prerequisites
	for req_id in upgrade.required_upgrades:
		var req = UpgradeManager.upgrades[req_id]
		if req.current_level < 1:
			return false
			
	# Check currency
	var cost = upgrade.cost * (upgrade.current_level + 1)
	if UpgradeManager.currency < cost:
		return false
		
	return true
	
func refresh_tree():
	# Update all button styles
	for upgrade_id in upgrade_buttons.keys():
		var button = upgrade_buttons[upgrade_id]
		var upgrade = UpgradeManager.upgrades[upgrade_id]
		_update_button_style(button, upgrade)
		
	# Update info panel if something is selected
	if selected_upgrade_id != "":
		_show_upgrade_info(selected_upgrade_id)
		
	queue_redraw()
	
func _draw():
	# Draw connection lines between prerequisites
	for upgrade_id in UpgradeManager.upgrades.keys():
		var upgrade = UpgradeManager.upgrades[upgrade_id]
		var to_pos = Vector2(upgrade.tree_position) * CELL_SIZE + Vector2(NODE_SIZE * 0.5, NODE_SIZE * 0.5)
		
		for req_id in upgrade.required_upgrades:
			var req = UpgradeManager.upgrades[req_id]
			var from_pos = Vector2(req.tree_position) * CELL_SIZE + Vector2(NODE_SIZE * 0.5, NODE_SIZE * 0.5)
			
			# Color based on prerequisite status
			var line_color = Color.GREEN if req.current_level >= 1 else Color.DARK_GRAY
			draw_line(from_pos + tree_container.position, to_pos + tree_container.position, line_color, 2.0)
			
func _on_upgrade_button_pressed(upgrade_id: String):
	selected_upgrade_id = upgrade_id
	_show_upgrade_info(upgrade_id)
	upgrade_selected.emit(upgrade_id)
	
func _show_upgrade_info(upgrade_id: String):
	var upgrade = UpgradeManager.upgrades[upgrade_id]
	
	info_panel.visible = true
	upgrade_name_label.text = upgrade.display_name
	upgrade_desc_label.text = upgrade.description
	
	var cost = upgrade.cost * (upgrade.current_level + 1)
	upgrade_cost_label.text = "Cost: %d" % cost
	
	upgrade_level_label.text = "Level: %d/%d" % [upgrade.current_level, upgrade.max_level]
	
	purchase_button.disabled = not can_purchase(upgrade_id)
	
func _on_purchase_button_pressed():
	if selected_upgrade_id != "":
		purchase_requested.emit(selected_upgrade_id)
