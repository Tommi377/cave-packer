extends Node

## GameManager - Handles incremental game loop with short runs and upgrades

signal run_started()
signal run_ended()
signal deadline_changed(current: float, max_value: float)
signal money_deposited(amount: int)

## Run state
var run_active: bool = false
var current_time: float = 30.0 # Base 30 seconds per run
var max_time: float = 30.0
var time_running: bool = false

## Money tracking
var total_money: int = 0 # Total money the player has (persistent wallet)

## Scene references
const MINE_SCENE = "res://content/levels/mine_level.tscn"

func _ready():
	time_running = false
	# Give starting money for first-time players
	if total_money == 0:
		total_money = 100
		print("GameManager: Set starting money to 100")

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
		max_time += UpgradeManager.get_stat_value("run_time")
	
	current_time = max_time
	run_active = true
	time_running = true
	
	print("Run started! Time limit: ", max_time, " seconds")
	print("Current money: ", total_money)
	run_started.emit()

## End the current run (called when timer runs out)
func end_run():
	if not run_active:
		return
	
	run_active = false
	time_running = false
	
	print("Run ended. Total money: ", total_money)
	run_ended.emit()

func _deplete_time(delta: float):
	current_time -= delta
	deadline_changed.emit(current_time, max_time)
	
	if current_time <= 0.0:
		current_time = 0.0
		# Time's up - force end run
		end_run()

## Called when player deposits ores at deposit box
func deposit_ores(value: int):
	total_money += value
	money_deposited.emit(value)
	
	print("Deposited ", value, " credits. Total money: ", total_money)

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
