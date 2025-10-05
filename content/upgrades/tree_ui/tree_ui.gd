class_name TreeUI
extends Control

signal upgrade_pressed(id: String)
signal upgrade_hovered(id: String)

var upgrade_buttons: Dictionary[String, UpgradeNode] = {}

const CELL_SIZE = 100
const OFFSET = 100

func initialize():
	for upgrade: UpgradeNode in get_children():
		upgrade_buttons[upgrade.data.id] = upgrade
		upgrade.pressed.connect(
			func(): 
				upgrade_pressed.emit(upgrade.data.id)
		)
		upgrade.mouse_entered.connect(
			func(): 
				upgrade_hovered.emit(upgrade.data.id)
		)

	refresh_tree()

func refresh_tree():
	for upgrade: UpgradeNode in get_children():
		upgrade.update_style()
		upgrade.update_text()

	queue_redraw()
	
func _draw():
	# Draw connection lines between prerequisites
	for upgrade_node: UpgradeNode in upgrade_buttons.values():
		var upgrade := UpgradeManager.get_upgrade(upgrade_node.data.id)
		
		var to_offset := upgrade_node.size / 2
		var to_pos := Vector2(upgrade_node.global_position + to_offset)
		
		var can_render := true
		for req in upgrade.required_upgrades:
			if UpgradeManager.get_upgrade_level(req.id) == 0:
				can_render = false
				break
		if can_render:
			for req in upgrade.required_upgrades:
				var from_offset := upgrade_buttons[req.id].size / 2
				var from_pos := Vector2(upgrade_buttons[req.id].global_position + from_offset)
				
				# Color based on prerequisite status
				var line_color = Color.DARK_GRAY
				draw_line(from_pos, to_pos, line_color, 2.0)
