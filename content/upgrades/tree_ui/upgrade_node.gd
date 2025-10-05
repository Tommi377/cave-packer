@tool
class_name UpgradeNode
extends Button

@export var data: UpgradeResource :
	set(value):
		data = value
		update_text()

func _ready() -> void:
	update_text()

func update_text() -> void:
	if not Engine.is_editor_hint():
		text = "%s\n\n$%d\n%d/%d" % [
			data.display_name,
			UpgradeManager.get_upgrade_cost(data.id),
			UpgradeManager.get_upgrade_level(data.id),
			data.max_level
		]
	else: text = data.display_name

func update_style() -> void:
	disabled = not UpgradeManager.can_purchase(data.id)
