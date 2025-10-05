extends Node

## Manages all upgrade purchases and stat bonuses using resource-based upgrades

signal upgrade_purchased(upgrade_id: String, new_level: int)
signal purchase_state_changed()

## Load the upgrades collection resource
@export var upgrades_collection: UpgradesCollection = preload("uid://duc1rbggwiy3u")

## Track purchased upgrade levels
var upgrade_levels: Dictionary = {}

## Cached stat values for performance
var cached_stats: Dictionary = {}
var stats_dirty: bool = true

func _ready():
	if not upgrades_collection:
		push_error("UpgradeManager: No upgrades_collection assigned!")
		return
	
	# Initialize all upgrades to level 0
	for upgrade in upgrades_collection.upgrades:
		upgrade_levels[upgrade.id] = 0
	
	print("UpgradeManager initialized with ", upgrades_collection.upgrades.size(), " upgrades")

## Purchase an upgrade
func purchase_upgrade(upgrade_id: String) -> bool:
	var upgrade = upgrades_collection.get_upgrade(upgrade_id)
	if not upgrade:
		push_warning("Upgrade not found: ", upgrade_id)
		return false
	
	var current_level = get_upgrade_level(upgrade_id)
	
	# Check if at max level
	if current_level >= upgrade.max_level:
		print("Already at max level for: ", upgrade_id)
		return false
	
	# Check cost (multi-currency)
	var costs = upgrade.get_currency_costs(current_level)
	if not GameManager.has_currencies(costs):
		print("Not enough currency. Need: ", costs)
		print("Have: Iron=", GameManager.get_currency("iron"),
			" Copper=", GameManager.get_currency("copper"),
			" Gold=", GameManager.get_currency("gold"),
			" Diamond=", GameManager.get_currency("diamond"))
		return false
	
	# Check prerequisites
	if not _check_prerequisites(upgrade):
		print("Prerequisites not met for: ", upgrade_id)
		return false
	
	# Purchase (spend currencies)
	if not GameManager.spend_currencies(costs):
		return false
		
	upgrade_levels[upgrade_id] = current_level + 1
	stats_dirty = true
	
	print("Purchased upgrade: ", upgrade.display_name, " Level ", upgrade_levels[upgrade_id])
	
	upgrade_purchased.emit(upgrade_id, upgrade_levels[upgrade_id])
	purchase_state_changed.emit()
	
	return true

## Check if prerequisites are met
func _check_prerequisites(upgrade: UpgradeResource) -> bool:
	for required in upgrade.required_upgrades:
		var req_level = get_upgrade_level(required.id)
		if req_level == 0:
			print("Missing prerequisite: ", required.id, " (need level ", upgrade.required_level, ", have ", req_level, ")")
			return false
	return true

## Get current level of an upgrade
func get_upgrade_level(upgrade_id: String) -> int:
	return upgrade_levels.get(upgrade_id, 0)

## Check if upgrade can be purchased
func can_purchase(upgrade_id: String) -> bool:
	var upgrade = upgrades_collection.get_upgrade(upgrade_id)
	if not upgrade:
		return false
	
	var current_level = get_upgrade_level(upgrade_id)
	
	# Check max level
	if current_level >= upgrade.max_level:
		return false
	
	# Check cost (multi-currency)
	var costs = upgrade.get_currency_costs(current_level)
	if not GameManager.has_currencies(costs):
		return false
	
	# Check prerequisites
	if not _check_prerequisites(upgrade):
		return false
	
	return true

## Get total stat value from all upgrades
func get_stat_value(stat_name: String) -> float:
	if stats_dirty:
		_recalculate_stats()
	
	return cached_stats.get(stat_name, 0.0)

## Recalculate all stat bonuses
func _recalculate_stats():
	cached_stats.clear()
	
	if not upgrades_collection:
		return
	
	for upgrade in upgrades_collection.upgrades:
		if upgrade.stat_name == "":
			continue
		
		var level = get_upgrade_level(upgrade.id)
		if level <= 0:
			continue
		
		var value = upgrade.get_value(level)
		
		if upgrade.upgrade_type == UpgradeResource.UpgradeType.MULTIPLIER:
			# Multipliers stack multiplicatively
			var current = cached_stats.get(upgrade.stat_name, 1.0)
			cached_stats[upgrade.stat_name] = current * (1.0 + value / 100.0)
		else:
			# Stat boosts stack additively
			var current = cached_stats.get(upgrade.stat_name, 0.0)
			cached_stats[upgrade.stat_name] = current + value
	
	stats_dirty = false

## Get all upgrades
func get_all_upgrades() -> Array[UpgradeResource]:
	if upgrades_collection:
		return upgrades_collection.upgrades
	return []

## Get upgrade resource by ID
func get_upgrade(upgrade_id: String) -> UpgradeResource:
	if upgrades_collection:
		return upgrades_collection.get_upgrade(upgrade_id)
	return null

## Get multi-currency costs for next level
func get_upgrade_currency_costs(upgrade_id: String) -> Dictionary:
	var upgrade = get_upgrade(upgrade_id)
	if not upgrade:
		return {}
	return upgrade.get_currency_costs(get_upgrade_level(upgrade_id))

## Backward compatibility functions
func get_backpack_size() -> int:
	return 2 + int(get_stat_value("grid_size"))
	
func get_ore_size() -> int:
	return int(get_stat_value("ore_size"))

func get_run_time() -> float:
	return 30.0 + get_stat_value("run_time")

func get_pickaxe_speed_multiplier() -> float:
	return 1.0 - get_stat_value("pickaxe_speed")

func get_pickaxe_damage() -> float:
	return 1.0 + get_stat_value("pickaxe_power")

func get_move_speed_multiplier() -> float:
	return 1.0 + get_stat_value("move_speed")

func get_jump_height_multiplier() -> float:
	return 2.0 + get_stat_value("jump_height") / 2

## Save/Load system
func get_save_data() -> Dictionary:
	return {
		"upgrade_levels": upgrade_levels.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	var saved_levels = data.get("upgrade_levels", {})
	
	for upgrade_id in saved_levels:
		if upgrade_levels.has(upgrade_id):
			upgrade_levels[upgrade_id] = saved_levels[upgrade_id]
	
	stats_dirty = true
	_recalculate_stats()
	purchase_state_changed.emit()
