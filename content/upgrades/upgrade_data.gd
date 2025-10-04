extends Resource
class_name UpgradeData

## Data structure for a single upgrade in the skill tree

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 100
@export var max_level: int = 1
@export var icon: Texture2D = null

## Prerequisites - other upgrade IDs that must be purchased first
@export var required_upgrades: Array[String] = []

## Grid position in skill tree UI
@export var tree_position: Vector2i = Vector2i(0, 0)

## Category for organization
@export_enum("Backpack", "Oxygen", "Pickaxe", "Movement") var category: String = "Backpack"

## Upgrade type determines what it affects
@export_enum("grid_size", "oxygen_max", "pickaxe_speed", "pickaxe_power", "move_speed", "jump_height", "special")
var upgrade_type: String = "grid_size"

## Value to add per level (or special effect identifier)
@export var value_per_level: float = 1.0

## Current level (0 = not purchased)
var current_level: int = 0

func can_purchase(currency: int, purchased_upgrades: Dictionary) -> bool:
	# Check if maxed out
	if current_level >= max_level:
		return false
	
	# Check if can afford
	if currency < cost:
		return false
	
	# Check prerequisites
	for req_id in required_upgrades:
		if not purchased_upgrades.has(req_id) or purchased_upgrades[req_id] == 0:
			return false
	
	return true

func purchase() -> bool:
	if current_level < max_level:
		current_level += 1
		return true
	return false

func is_maxed() -> bool:
	return current_level >= max_level

func get_next_level_cost() -> int:
	if is_maxed():
		return 0
	return cost * (current_level + 1) # Costs scale with level
