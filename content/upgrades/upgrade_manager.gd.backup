extends Node
# class_name UpgradeManager

## Manages all upgrades, progression, and skill tree state

signal upgrade_purchased(upgrade_id: String, new_level: int)
signal stats_changed()

## All available upgrades (upgrade_id -> UpgradeData)
var upgrades: Dictionary = {}

## Current upgrade levels (upgrade_id -> level)
var upgrade_levels: Dictionary = {}

func _ready() -> void:
	_initialize_upgrades()

## Initialize all available upgrades
func _initialize_upgrades() -> void:
	# Backpack upgrades (each level adds +1 to grid size)
	_add_upgrade("backpack_1", "Bigger Backpack", "Expand inventory to 6×6", 50,
		"Backpack", "grid_size", 1.0, Vector2i(0, 0), [], 1, 50)
	_add_upgrade("backpack_2", "Large Backpack", "Expand inventory to 7×7", 100,
		"Backpack", "grid_size", 1.0, Vector2i(0, 1), ["backpack_1"], 1, 100)
	_add_upgrade("backpack_3", "Huge Backpack", "Expand inventory up to 10×10", 200,
		"Backpack", "grid_size", 1.0, Vector2i(0, 2), ["backpack_2"], 3, 150)
	
	# Run time upgrades (each level adds +10s to run duration)
	_add_upgrade("run_time_1", "Extra Time I", "Increase run time by 10s", 50,
		"Time", "run_time", 10.0, Vector2i(1, 0), [], 1, 50)
	_add_upgrade("run_time_2", "Extra Time II", "Increase run time by 20s", 100,
		"Time", "run_time", 10.0, Vector2i(1, 1), ["run_time_1"], 1, 100)
	_add_upgrade("run_time_3", "Extra Time III", "Increase run time by 30s", 200,
		"Time", "run_time", 10.0, Vector2i(1, 2), ["run_time_2"], 3, 150)
	
	# Pickaxe upgrades
	_add_upgrade("pickaxe_speed_1", "Fast Swing", "Mine faster", 60,
		"Pickaxe", "pickaxe_speed", 0.2, Vector2i(2, 0), [], 3, 60)
	_add_upgrade("pickaxe_speed_2", "Rapid Swing", "Mine even faster", 120,
		"Pickaxe", "pickaxe_speed", 0.2, Vector2i(2, 1), ["pickaxe_speed_1"], 3, 80)
	_add_upgrade("pickaxe_power_1", "Power Strike", "Break multiple blocks", 200,
		"Pickaxe", "pickaxe_power", 1.0, Vector2i(3, 1), ["pickaxe_speed_1"], 2, 200)
	
	# Movement upgrades
	_add_upgrade("move_speed_1", "Sprint Boots", "Move faster", 80,
		"Movement", "move_speed", 0.15, Vector2i(4, 0), [], 3, 80)
	_add_upgrade("jump_height_1", "Jump Boost", "Jump higher", 100,
		"Movement", "jump_height", 0.2, Vector2i(4, 1), [], 3, 100)
	_add_upgrade("double_jump", "Double Jump", "Jump again in mid-air", 250,
		"Movement", "special", 1.0, Vector2i(5, 1), ["jump_height_1"], 1, 250)

func _add_upgrade(id: String, upgrade_name: String, desc: String, base_cost: int,
	category: String, type: String, value: float, pos: Vector2i, reqs: Array,
	max_lvl: int, cost_step: int) -> void:
	# Create upgrade as dictionary (simpler than Resource for now)
	var upgrade = {
		"id": id,
		"display_name": upgrade_name,
		"description": desc,
		"base_cost": base_cost,
		"cost_step": cost_step, # How much the cost increases per level
		"category": category,
		"upgrade_type": type,
		"value_per_level": value,
		"tree_position": pos,
		"required_upgrades": reqs.duplicate(),
		"current_level": 0,
		"max_level": max_lvl
	}
	
	upgrades[id] = upgrade
	upgrade_levels[id] = 0

## Attempt to purchase an upgrade
func purchase_upgrade(upgrade_id: String) -> bool:
	print("=== Attempting to purchase: ", upgrade_id, " ===")
	
	if not upgrades.has(upgrade_id):
		print("ERROR: Upgrade not found: ", upgrade_id)
		return false
	
	if not GameManager:
		push_error("GameManager not found!")
		return false
	
	var upgrade = upgrades[upgrade_id]
	print("Upgrade info: Level ", upgrade.current_level, "/", upgrade.max_level)
	
	# Check if maxed out
	if upgrade.current_level >= upgrade.max_level:
		print("ERROR: Already maxed out")
		return false
	
	# Calculate cost based on level (base_cost + (current_level * cost_step))
	var upgrade_cost = upgrade.base_cost + (upgrade.current_level * upgrade.cost_step)
	print("Cost: ", upgrade_cost, " | Available money: ", GameManager.total_money)
	
	# Check if can afford
	if GameManager.total_money < upgrade_cost:
		print("ERROR: Not enough money")
		return false
	
	# Check prerequisites
	for req_id in upgrade.required_upgrades:
		if not upgrade_levels.has(req_id) or upgrade_levels[req_id] == 0:
			print("ERROR: Missing prerequisite: ", req_id)
			return false
	
	print("All checks passed - purchasing!")
	
	# Purchase
	GameManager.total_money -= upgrade_cost
	upgrade.current_level += 1
	upgrade_levels[upgrade_id] = upgrade.current_level
	
	upgrade_purchased.emit(upgrade_id, upgrade.current_level)
	stats_changed.emit()
	
	print("SUCCESS: Purchased upgrade: ", upgrade_id, " Level: ", upgrade.current_level, " Cost: ", upgrade_cost)
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

## Get the cost of the next level for an upgrade
func get_upgrade_cost(upgrade_id: String) -> int:
	if not upgrades.has(upgrade_id):
		return 0
	
	var upgrade = upgrades[upgrade_id]
	if upgrade.current_level >= upgrade.max_level:
		return 0
	
	# Calculate cost: base_cost + (current_level * cost_step)
	return upgrade.base_cost + (upgrade.current_level * upgrade.cost_step)

## Get current backpack size
func get_backpack_size() -> int:
	return 5 + int(get_stat_value("grid_size"))

## Get current run time capacity
func get_run_time() -> float:
	return 30.0 + get_stat_value("run_time") # Base 30 seconds

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
		"upgrade_levels": upgrade_levels.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	var saved_levels = data.get("upgrade_levels", {})
	
	for upgrade_id in saved_levels:
		if upgrades.has(upgrade_id):
			var level = saved_levels[upgrade_id]
			upgrades[upgrade_id].current_level = level
			upgrade_levels[upgrade_id] = level
	
	stats_changed.emit()
