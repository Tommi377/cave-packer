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
		text = "%s\n\n%s\n%d/%d" % [
			data.display_name,
			get_price(),
			UpgradeManager.get_upgrade_level(data.id),
			data.max_level
		]
	else: text = data.display_name

func get_price() -> String:
	var result := ""
	var costs = UpgradeManager.get_upgrade_currency_costs(data.id)
	for currency in costs.keys():
		var amount: int = costs.get(currency)
		result += ("%d %s" % [amount, currency])
		pass
	return result

func update_style() -> void:
	disabled = not UpgradeManager.can_purchase(data.id)
	visible = UpgradeManager._check_prerequisites(data)
