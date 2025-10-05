class_name TreeUI
extends Control

signal upgrade_pressed(id: String)

var upgrade_buttons: Dictionary[String, UpgradeNode] = {}

const CELL_SIZE = 100
const OFFSET = 100

func initialize():
	for upgrade: UpgradeNode in get_children():
		upgrade.update_style()
		upgrade.update_text()
		upgrade_buttons[upgrade.data.id] = upgrade
		upgrade.pressed.connect(
			func(): upgrade_pressed.emit(upgrade.data.id)
		)

	refresh_tree()

func refresh_tree():
	# Update all button styles

	queue_redraw()
	
func _draw():
	# Draw connection lines between prerequisites
	print(upgrade_buttons)
	for upgrade_node: UpgradeNode in upgrade_buttons.values():
		var to_offset := upgrade_node.size / 2
		var to_pos := Vector2(upgrade_node.global_position + to_offset)
		var upgrade := UpgradeManager.get_upgrade(upgrade_node.data.id)
		
		for req_id in upgrade.required_upgrades:
			var from_offset := upgrade_buttons[req_id].size / 2
			var from_pos := Vector2(upgrade_buttons[req_id].global_position + from_offset)
			
			# Color based on prerequisite status
			var req_level = UpgradeManager.get_upgrade_level(req_id)
			var line_color = Color.GREEN if req_level >= upgrade.required_level else Color.DARK_GRAY
			draw_line(from_pos, to_pos, line_color, 2.0)
