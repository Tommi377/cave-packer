@tool
extends EditorScript

## Run this script in the Godot editor to create example upgrade resources
## File > Run (or press Ctrl+Shift+X)

const UPGRADES_DIR = "res://content/upgrades/resources/"

func _run():
	print("=== Creating Example Upgrade Resources ===")
	
	# Create directory if it doesn't exist
	DirAccess.make_dir_recursive_absolute(UPGRADES_DIR)
	
	# Create the upgrades collection
	var collection = UpgradesCollection.new()
	
	# Time Extension Tier 1
	var time1 = create_upgrade(
		"time_extension_1",
		"Extended Time I",
		"Increase run time by +{value} seconds",
		"run_time",
		3, 50, 1.5, 10.0,
		[], 1, Vector2(0, 0), 1
	)
	save_resource(time1, "time_extension_1.tres")
	collection.upgrades.append(time1)
	
	# Time Extension Tier 2
	var time2 = create_upgrade(
		"time_extension_2",
		"Extended Time II",
		"Further increase run time by +{value} seconds",
		"run_time",
		3, 150, 1.8, 10.0,
		["time_extension_1"], 3, Vector2(0, 1), 2
	)
	save_resource(time2, "time_extension_2.tres")
	collection.upgrades.append(time2)
	
	# Time Extension Tier 3
	var time3 = create_upgrade(
		"time_extension_3",
		"Extended Time III",
		"Maximum time extension: +{value} seconds",
		"run_time",
		3, 500, 2.0, 10.0,
		["time_extension_2"], 3, Vector2(0, 2), 3
	)
	save_resource(time3, "time_extension_3.tres")
	collection.upgrades.append(time3)
	
	# Inventory Size Tier 1
	var inv1 = create_upgrade(
		"inventory_size_1",
		"Bigger Backpack",
		"Carry +{value} more ore items",
		"grid_size",
		5, 100, 1.6, 1.0,
		[], 1, Vector2(1, 0), 1
	)
	save_resource(inv1, "inventory_size_1.tres")
	collection.upgrades.append(inv1)
	
	# Inventory Size Tier 2
	var inv2 = create_upgrade(
		"inventory_size_2",
		"Massive Storage",
		"Increase capacity by +{value} more items",
		"grid_size",
		5, 300, 2.0, 2.0,
		["inventory_size_1"], 3, Vector2(1, 1), 2
	)
	save_resource(inv2, "inventory_size_2.tres")
	collection.upgrades.append(inv2)
	
	# Pickaxe Damage
	var damage = create_upgrade(
		"pickaxe_damage_1",
		"Sharper Pickaxe",
		"Increase mining damage by +{value}",
		"pickaxe_power",
		5, 75, 1.7, 1.0,
		[], 1, Vector2(2, 0), 1
	)
	save_resource(damage, "pickaxe_damage_1.tres")
	collection.upgrades.append(damage)
	
	# Speed Boost
	var speed = create_upgrade(
		"speed_boost_1",
		"Speed Boost",
		"Increase movement speed by +{value}",
		"move_speed",
		4, 120, 1.5, 0.15,
		[], 1, Vector2(3, 0), 1
	)
	save_resource(speed, "speed_boost_1.tres")
	collection.upgrades.append(speed)
	
	# Jump Height
	var jump = create_upgrade(
		"jump_height_1",
		"Higher Jump",
		"Jump +{value} units higher",
		"jump_height",
		3, 150, 1.8, 0.2,
		[], 1, Vector2(4, 0), 1
	)
	save_resource(jump, "jump_height_1.tres")
	collection.upgrades.append(jump)
	
	# Swing Speed
	var swing = create_upgrade(
		"swing_speed_1",
		"Faster Swing",
		"Reduce swing cooldown by {value}%",
		"pickaxe_speed",
		4, 100, 1.6, 0.2,
		[], 1, Vector2(5, 0), 1
	)
	save_resource(swing, "swing_speed_1.tres")
	collection.upgrades.append(swing)
	
	# Double Jump
	var double_jump = create_upgrade(
		"double_jump",
		"Double Jump",
		"Jump again in mid-air",
		"special",
		1, 250, 1.0, 1.0,
		["jump_height_1"], 3, Vector2(5, 1), 2
	)
	save_resource(double_jump, "double_jump.tres")
	collection.upgrades.append(double_jump)
	
	# Save the collection
	var result = ResourceSaver.save(collection, UPGRADES_DIR + "example_upgrades_collection.tres")
	if result == OK:
		print("✓ Created upgrades collection with ", collection.upgrades.size(), " upgrades")
		print("✓ Saved to: ", UPGRADES_DIR + "example_upgrades_collection.tres")
		print("")
		print("NEXT STEPS:")
		print("1. Open the UpgradeManager autoload in the scene tree")
		print("2. In the Inspector, find 'Upgrades Collection' property")
		print("3. Drag the file: ", UPGRADES_DIR + "example_upgrades_collection.tres")
		print("4. Save your scene and test!")
	else:
		print("✗ Failed to save collection. Error code: ", result)

func create_upgrade(
	id: String,
	name: String,
	desc: String,
	stat: String,
	max_lvl: int,
	cost: int,
	multiplier: float,
	value: float,
	required: Array[String],
	req_level: int,
	pos: Vector2,
	tier: int
) -> UpgradeResource:
	var upgrade = UpgradeResource.new()
	upgrade.id = id
	upgrade.display_name = name
	upgrade.description = desc
	upgrade.stat_name = stat
	upgrade.max_level = max_lvl
	upgrade.base_cost = cost
	upgrade.cost_multiplier = multiplier
	upgrade.value_per_level = value
	upgrade.required_upgrades = required
	upgrade.required_level = req_level
	upgrade.tree_position = pos
	upgrade.tier = tier
	return upgrade

func save_resource(resource: Resource, filename: String):
	var path = UPGRADES_DIR + filename
	var result = ResourceSaver.save(resource, path)
	if result == OK:
		print("  ✓ Saved: ", filename)
	else:
		print("  ✗ Failed to save: ", filename)
