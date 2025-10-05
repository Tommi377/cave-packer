extends Node

## GameManager - Handles incremental game loop with short runs and upgrades

signal run_started()
signal run_ended()
signal deadline_changed(current: float, max_value: float)
signal currency_deposited(ore_type: String, amount: int)

## Run state
var current_day: int = 0
var run_active: bool = false
var current_time: float = 30.0 # Base 30 seconds per run
var max_time: float = 30.0
var time_running: bool = false

## Currency tracking (multi-currency system)
var currencies: Dictionary = {
	"iron": 0,
	"copper": 0,
	"gold": 0,
	"diamond": 0
}

## Scene references
const MINE_SCENE = "res://content/levels/mine_level.tscn"

func _ready():
	time_running = false
	# Give starting currency for first-time players
	if currencies["iron"] == 0:
		currencies["iron"] = 50000
		currencies["copper"] = 20000
		currencies["gold"] = 10000
		currencies["diamond"] = 50000
		print("GameManager: Set starting currencies")

func _process(delta: float):
	if time_running and run_active:
		_deplete_time(delta)

## Start a new run in the mine
func start_run():
	if run_active:
		push_warning("Run already active!")
		return
	
	# Get max time from upgrades
	max_time = 30.0 # Base 30 seconds
	if UpgradeManager:
		max_time = UpgradeManager.get_run_time()
	
	current_time = max_time
	run_active = true
	time_running = true
	current_day += 1
	
	print("Run started! Time limit: ", max_time, " seconds")
	print("Current currencies: Iron=", currencies["iron"], " Copper=", currencies["copper"],
		" Gold=", currencies["gold"], " Diamond=", currencies["diamond"])
	run_started.emit()

## End the current run (called when timer runs out)
func end_run():
	if not run_active:
		return
	
	run_active = false
	time_running = false
	
	print("Run ended. Currencies: Iron=", currencies["iron"], " Copper=", currencies["copper"],
		" Gold=", currencies["gold"], " Diamond=", currencies["diamond"])
	run_ended.emit()

func _deplete_time(delta: float):
	current_time -= delta
	deadline_changed.emit(current_time, max_time)
	
	if current_time <= 0.0:
		current_time = 0.0
		# Time's up - force end run
		end_run()

## Called when player deposits ores at deposit box
func deposit_ores(ore_type: String, amount: int):
	var ore_key = ore_type.to_lower().replace("_ore", "")
	
	if currencies.has(ore_key):
		currencies[ore_key] += amount
		currency_deposited.emit(ore_key, amount)
		print("Deposited ", amount, " ", ore_key, ". Total: ", currencies[ore_key])
	else:
		push_warning("Unknown ore type: ", ore_type)

## Pause the timer (e.g., during inventory mode)
func pause_timer():
	time_running = false

## Resume the timer
func resume_timer():
	if run_active:
		time_running = true

## Get current time percentage
func get_time_percentage() -> float:
	if max_time <= 0:
		return 0.0
	return (current_time / max_time) * 100.0

## Check if player has enough of a specific currency
func has_currency(ore_type: String, amount: int) -> bool:
	var ore_key = ore_type.to_lower()
	return currencies.get(ore_key, 0) >= amount

## Check if player has enough of all currencies in a cost dictionary
func has_currencies(costs: Dictionary) -> bool:
	for ore_type in costs:
		if not has_currency(ore_type, costs[ore_type]):
			return false
	return true

## Spend currency (returns false if not enough)
func spend_currency(ore_type: String, amount: int) -> bool:
	var ore_key = ore_type.to_lower()
	if not has_currency(ore_key, amount):
		return false
	currencies[ore_key] -= amount
	return true

## Spend multiple currencies (returns false if not enough of any)
func spend_currencies(costs: Dictionary) -> bool:
	# First check if we have enough
	if not has_currencies(costs):
		return false
	# Then spend
	for ore_type in costs:
		var ore_key = ore_type.to_lower()
		currencies[ore_key] -= costs[ore_type]
	return true

## Get currency amount
func get_currency(ore_type: String) -> int:
	var ore_key = ore_type.to_lower()
	return currencies.get(ore_key, 0)
