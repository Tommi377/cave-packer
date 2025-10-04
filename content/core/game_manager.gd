extends Node

## GameManager - Handles day-based game loop with deadline timer and money goals

signal day_started()
signal day_ended(goal_reached: bool)
signal deadline_changed(current: float, max_value: float)
signal money_deposited(amount: int)
signal goal_reached()

## Day state
var current_day_active: bool = false
var current_time: float = 300.0 # 5 minutes per day
var max_time: float = 300.0
var time_running: bool = false

## Money tracking
var current_day_earnings: int = 0 # Total money the player has (persistent wallet)
var money_goal: int = 500 # Goal for the current day

## Scene references
const MINE_SCENE = "res://content/levels/mine_level.tscn"

func _ready():
	time_running = false

func _process(delta: float):
	if time_running and current_day_active:
		_deplete_time(delta)

## Start a new day in the mine
func start_day():
	if current_day_active:
		push_warning("Day already active!")
		return
	
	# Get max time from upgrades if needed
	max_time = 300.0 # Base 5 minutes
	current_time = max_time
	current_day_active = true
	time_running = true
	# DON'T reset current_day_earnings - it's the player's persistent wallet!
	
	print("Day started! Time limit: ", max_time, " seconds")
	print("Current money: ", current_day_earnings)
	day_started.emit()

## End the current day (called when timer runs out)
func end_day():
	if not current_day_active:
		return
	
	current_day_active = false
	time_running = false
	
	var goal_met = current_day_earnings >= money_goal
	
	print("Day ended. Total money: ", current_day_earnings, " / Goal: ", money_goal)
	
	if goal_met:
		print("Goal reached! You can continue.")
	else:
		print("Goal not reached. Day failed.")
	
	day_ended.emit(goal_met)

func _deplete_time(delta: float):
	current_time -= delta
	deadline_changed.emit(current_time, max_time)
	
	if current_time <= 0.0:
		current_time = 0.0
		# Time's up - force end day
		end_day()

## Called when player deposits ores at deposit box
func deposit_ores(value: int):
	current_day_earnings += value
	money_deposited.emit(value)
	
	print("Deposited ", value, " credits. Total earnings: ", current_day_earnings, " / ", money_goal)
	
	if current_day_earnings >= money_goal:
		goal_reached.emit()

## Get current time percentage
func get_time_percentage() -> float:
	if max_time <= 0:
		return 0.0
	return (current_time / max_time) * 100.0

## Get progress toward goal
func get_goal_percentage() -> float:
	if money_goal <= 0:
		return 100.0
	return (float(current_day_earnings) / float(money_goal)) * 100.0
