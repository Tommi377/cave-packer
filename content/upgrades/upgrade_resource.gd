extends Resource
class_name UpgradeResource

## Base upgrade resource that can be created and modified in the editor

enum UpgradeType {
	STAT_BOOST, # Adds to a stat value
	UNLOCK, # Unlocks a feature/ability
	MULTIPLIER # Multiplies a value
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var upgrade_type: UpgradeType = UpgradeType.STAT_BOOST

## What stat does this upgrade affect? (e.g., "run_time", "inventory_size", "pickaxe_damage")
@export var stat_name: String = ""

## Upgrade progression
@export var max_level: int = 3

## Multi-currency costs (new system)
## Dictionary of ore_type: amount, e.g., {"iron": 10, "copper": 5}
@export var currency_costs: Dictionary = {}
@export var cost_scaling: Dictionary = {} # Per-ore-type multipliers, e.g., {"iron": 1.5, "copper": 2.0}

## Stat modification
@export var value_per_level: float = 10.0
@export var is_percentage: bool = false

## Prerequisites
@export var required_upgrades: Array[String] = []
@export var required_level: int = 1

## Visual/UI
@export var tree_position: Vector2 = Vector2.ZERO
@export var tier: int = 1

func get_currency_costs(current_level: int) -> Dictionary:
	# New multi-currency cost function
	if current_level >= max_level:
		return {}
	
	var costs = {}
	for ore_type in currency_costs:
		var base = currency_costs[ore_type]
		var multiplier = cost_scaling.get(ore_type, 1.0)
		costs[ore_type] = int(base * pow(multiplier, current_level))
	
	return costs

func get_value(level: int) -> float:
	return value_per_level * level

func get_description_with_values(current_level: int) -> String:
	var next_level = current_level + 1
	if next_level > max_level:
		return description + '\n'
	
	var current_value = get_value(current_level)
	var next_value = get_value(next_level)
	var bonus = next_value - current_value
	
	var bonus_text = str(bonus)
	if is_percentage:
		bonus_text += "%"
	
	return description.replace("{value}", bonus_text) + '\n'
