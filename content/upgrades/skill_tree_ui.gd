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
var last_can_purchase: bool = false # Track state changes

func _ready():
	purchase_button.pressed.connect(_on_purchase_button_pressed)
	info_panel.visible = false
	initialize()

# Update purchase button state every frame when info panel is visible
func _process(_delta):
	if info_panel.visible and selected_upgrade_id != "":
		var can_buy = can_purchase(selected_upgrade_id)
		purchase_button.disabled = not can_buy
		
		# Debug info only when state changes
		if can_buy != last_can_purchase:
			last_can_purchase = can_buy
			if GameManager:
				var cost = UpgradeManager.get_upgrade_cost(selected_upgrade_id)
				print("Purchase state changed - Money: ", GameManager.current_day_earnings, " Cost: ", cost, " Can buy: ", can_buy)
	
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
	
	# Connect both click and hover events
	button.pressed.connect(_on_upgrade_button_pressed.bind(upgrade.id))
	button.mouse_entered.connect(_on_upgrade_button_hovered.bind(upgrade.id))
	
	_update_button_style(button, upgrade)
	
	return button
	
func _update_button_style(button: Button, upgrade: Dictionary):
	# Color based on state - but don't disable locked ones so they can be clicked
	if upgrade.current_level >= upgrade.max_level:
		button.modulate = Color(0.2, 0.8, 0.2) # Green - purchased
	elif can_purchase(upgrade.id):
		button.modulate = Color(1.0, 1.0, 0.3) # Yellow - available
	else:
		button.modulate = Color(0.5, 0.5, 0.5) # Gray - locked
	
	# Never disable buttons so they can always be clicked/hovered to show info
	button.disabled = false
		
func can_purchase(upgrade_id: String) -> bool:
	if not GameManager:
		print("can_purchase: GameManager not found!")
		return false
	
	if not UpgradeManager:
		print("can_purchase: UpgradeManager not found!")
		return false
		
	var upgrade = UpgradeManager.upgrades[upgrade_id]
	
	# Check if maxed
	if upgrade.current_level >= upgrade.max_level:
		print("can_purchase: Upgrade maxed out")
		return false
		
	# Check prerequisites
	for req_id in upgrade.required_upgrades:
		var req = UpgradeManager.upgrades[req_id]
		if req.current_level < 1:
			print("can_purchase: Missing prerequisite: ", req_id)
			return false
			
	# Check currency using the cost function
	var cost = UpgradeManager.get_upgrade_cost(upgrade_id)
	if GameManager.current_day_earnings < cost:
		print("can_purchase: Not enough money. Have: ", GameManager.current_day_earnings, " Need: ", cost)
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

func _on_upgrade_button_hovered(upgrade_id: String):
	# Show info on hover
	selected_upgrade_id = upgrade_id
	_show_upgrade_info(upgrade_id)
	
func _show_upgrade_info(upgrade_id: String):
	var upgrade = UpgradeManager.upgrades[upgrade_id]
	
	info_panel.visible = true
	upgrade_name_label.text = upgrade.display_name
	
	# Build description with status info
	var desc = upgrade.description
	
	# Add prerequisite info if locked
	if upgrade.required_upgrades.size() > 0:
		var all_reqs_met = true
		var req_text = "\n\nRequires:"
		for req_id in upgrade.required_upgrades:
			var req = UpgradeManager.upgrades[req_id]
			if req.current_level < 1:
				req_text += "\n  ✗ " + req.display_name
				all_reqs_met = false
			else:
				req_text += "\n  ✓ " + req.display_name
		
		if not all_reqs_met:
			desc += req_text
	
	upgrade_desc_label.text = desc
	
	var cost = UpgradeManager.get_upgrade_cost(upgrade_id)
	if upgrade.current_level >= upgrade.max_level:
		upgrade_cost_label.text = "MAXED OUT"
		purchase_button.text = "Maxed"
	elif cost > 0:
		if GameManager:
			upgrade_cost_label.text = "Cost: %d (You have: %d)" % [cost, GameManager.current_day_earnings]
		else:
			upgrade_cost_label.text = "Cost: %d" % cost
		purchase_button.text = "Purchase"
	
	upgrade_level_label.text = "Level: %d/%d" % [upgrade.current_level, upgrade.max_level]
	
	purchase_button.disabled = not can_purchase(upgrade_id)
	
func _on_purchase_button_pressed():
	if selected_upgrade_id != "":
		purchase_requested.emit(selected_upgrade_id)
