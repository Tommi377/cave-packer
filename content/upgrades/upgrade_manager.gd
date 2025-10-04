extends Node
# class_name UpgradeManager

## Manages all upgrades, progression, and skill tree state

signal upgrade_purchased(upgrade_id: String, new_level: int)
signal stats_changed()

## Currency
var currency: int = 0

## All available upgrades (upgrade_id -> UpgradeData)
var upgrades: Dictionary = {}

## Current upgrade levels (upgrade_id -> level)
var upgrade_levels: Dictionary = {}

func _ready() -> void:
	_initialize_upgrades()

## Initialize all available upgrades
func _initialize_upgrades() -> void:
	# Backpack upgrades
	_add_upgrade("backpack_1", "Bigger Backpack", "Expand inventory to 6×6", 50, 
		"Backpack", "grid_size", 1.0, Vector2i(0, 0), [])
	_add_upgrade("backpack_2", "Large Backpack", "Expand inventory to 7×7", 100, 
		"Backpack", "grid_size", 1.0, Vector2i(0, 1), ["backpack_1"])
	_add_upgrade("backpack_3", "Huge Backpack", "Expand inventory to 8×8", 200, 
		"Backpack", "grid_size", 1.0, Vector2i(0, 2), ["backpack_2"])
	
	# Oxygen upgrades
	_add_upgrade("oxygen_1", "O2 Tank I", "Increase oxygen capacity by 30s", 75, 
		"Oxygen", "oxygen_max", 30.0, Vector2i(1, 0), [])
	_add_upgrade("oxygen_2", "O2 Tank II", "Increase oxygen capacity by 60s", 150, 
		"Oxygen", "oxygen_max", 60.0, Vector2i(1, 1), ["oxygen_1"])
	_add_upgrade("oxygen_3", "O2 Tank III", "Increase oxygen capacity by 90s", 300, 
		"Oxygen", "oxygen_max", 90.0, Vector2i(1, 2), ["oxygen_2"])
	
	# Pickaxe upgrades
	_add_upgrade("pickaxe_speed_1", "Fast Swing", "Mine 20% faster", 60, 
		"Pickaxe", "pickaxe_speed", 0.2, Vector2i(2, 0), [])
	_add_upgrade("pickaxe_speed_2", "Rapid Swing", "Mine 40% faster", 120, 
		"Pickaxe", "pickaxe_speed", 0.2, Vector2i(2, 1), ["pickaxe_speed_1"])
	_add_upgrade("pickaxe_power_1", "Power Strike", "Break multiple blocks", 200, 
		"Pickaxe", "pickaxe_power", 1.0, Vector2i(3, 1), ["pickaxe_speed_1"])
	
	# Movement upgrades
	_add_upgrade("move_speed_1", "Sprint Boots", "Move 15% faster", 80, 
		"Movement", "move_speed", 0.15, Vector2i(4, 0), [])
	_add_upgrade("jump_height_1", "Jump Boost", "Jump 20% higher", 100, 
		"Movement", "jump_height", 0.2, Vector2i(4, 1), [])
	_add_upgrade("double_jump", "Double Jump", "Jump again in mid-air", 250, 
		"Movement", "special", 1.0, Vector2i(5, 1), ["jump_height_1"])

func _add_upgrade(id: String, upgrade_name: String, desc: String, cost: int,
	category: String, type: String, value: float, pos: Vector2i, reqs: Array) -> void:
	# Create upgrade as dictionary (simpler than Resource for now)
	var upgrade = {
		"id": id,
		"display_name": upgrade_name,
		"description": desc,
		"cost": cost,
		"category": category,
		"upgrade_type": type,
		"value_per_level": value,
		"tree_position": pos,
		"required_upgrades": reqs.duplicate(),
		"current_level": 0,
		"max_level": 1
	}
	
	upgrades[id] = upgrade
	upgrade_levels[id] = 0

## Attempt to purchase an upgrade
func purchase_upgrade(upgrade_id: String) -> bool:
	if not upgrades.has(upgrade_id):
		print("Upgrade not found: ", upgrade_id)
		return false
	
	var upgrade = upgrades[upgrade_id]
	
	# Check if maxed out
	if upgrade.current_level >= upgrade.max_level:
		return false
	
	# Calculate cost (scales with level)
	var upgrade_cost = upgrade.cost * (upgrade.current_level + 1)
	
	# Check if can afford
	if currency < upgrade_cost:
		return false
	
	# Check prerequisites
	for req_id in upgrade.required_upgrades:
		if not upgrade_levels.has(req_id) or upgrade_levels[req_id] == 0:
			return false
	
	# Purchase
	currency -= upgrade_cost
	upgrade.current_level += 1
	upgrade_levels[upgrade_id] = upgrade.current_level
	
	upgrade_purchased.emit(upgrade_id, upgrade.current_level)
	stats_changed.emit()
	
	print("Purchased upgrade: ", upgrade_id, " Level: ", upgrade.current_level, " Cost: ", upgrade_cost)
	return true

## Get all upgrades in a category
func get_upgrades_by_category(category: String) -> Array:
	var result: Array = []
	for upgrade_id in upgrades:
		var upgrade = upgrades[upgrade_id]
		if upgrade.category == category:
			result.append(upgrade)
	return result

## Get total stat value from upgrades
func get_stat_value(upgrade_type: String) -> float:
	var total: float = 0.0
	for upgrade_id in upgrades:
		var upgrade = upgrades[upgrade_id]
		if upgrade.upgrade_type == upgrade_type and upgrade.current_level > 0:
			total += upgrade.value_per_level * upgrade.current_level
	return total

## Check if player has a specific upgrade
func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_levels.get(upgrade_id, 0) > 0

## Get upgrade level
func get_upgrade_level(upgrade_id: String) -> int:
	return upgrade_levels.get(upgrade_id, 0)

## Add currency (from selling ores)
func add_currency(amount: int) -> void:
	currency += amount
	print("Currency added: ", amount, " | Total: ", currency)

## Sell all ores from inventory
func sell_inventory(inventory_value: int) -> void:
	add_currency(inventory_value)

## Get current backpack size
func get_backpack_size() -> int:
	return 5 + int(get_stat_value("grid_size"))

## Get current oxygen capacity
func get_oxygen_capacity() -> float:
	return 120.0 + get_stat_value("oxygen_max")  # Base 120 seconds

## Get pickaxe speed multiplier
func get_pickaxe_speed_multiplier() -> float:
	return 1.0 + get_stat_value("pickaxe_speed")

## Get movement speed multiplier
func get_move_speed_multiplier() -> float:
	return 1.0 + get_stat_value("move_speed")

## Get jump height multiplier
func get_jump_height_multiplier() -> float:
	return 1.0 + get_stat_value("jump_height")

## Save/Load system
func get_save_data() -> Dictionary:
	return {
		"currency": currency,
		"upgrade_levels": upgrade_levels.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	currency = data.get("currency", 0)
	var saved_levels = data.get("upgrade_levels", {})
	
	for upgrade_id in saved_levels:
		if upgrades.has(upgrade_id):
			var level = saved_levels[upgrade_id]
			upgrades[upgrade_id].current_level = level
			upgrade_levels[upgrade_id] = level
	
	stats_changed.emit()
