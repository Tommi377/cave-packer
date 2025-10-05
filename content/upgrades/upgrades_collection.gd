extends Resource
class_name UpgradesCollection

## Collection of all upgrade resources in the game

@export var upgrades: Array[UpgradeResource] = []

func get_upgrade(id: String) -> UpgradeResource:
	for upgrade in upgrades:
		if upgrade.id == id:
			return upgrade
	return null

func get_upgrades_by_tier(tier: int) -> Array[UpgradeResource]:
	var result: Array[UpgradeResource] = []
	for upgrade in upgrades:
		if upgrade.tier == tier:
			result.append(upgrade)
	return result

func get_all_stat_names() -> Array[String]:
	var stats: Array[String] = []
	for upgrade in upgrades:
		if upgrade.stat_name != "" and not stats.has(upgrade.stat_name):
			stats.append(upgrade.stat_name)
	return stats

func get_max_tier() -> int:
	var max_tier = 1
	for upgrade in upgrades:
		if upgrade.tier > max_tier:
			max_tier = upgrade.tier
	return max_tier
