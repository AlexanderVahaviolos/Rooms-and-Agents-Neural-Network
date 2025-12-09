class_name Score
extends RefCounted

var agent: CharacterBody2D
var memory: MemoryInput
var score: float

# --- SCORING CONSTANTS ---
const MOVE_REWARD_FACTOR: float = 0.02     # per pixel moved
const VEL_ALIGN_REWARD: float = 0.05       # reward when velocity aligns with facing
const VEL_MISALIGN_PENALTY: float = 0.01

const IDLE_SPEED_THRESHOLD: float = 1.0
const IDLE_PENALTY_PER_SEC: float = 0.05

# Exit shaping
const EXIT_APPROACH_REWARD_PER_PIXEL: float = 1.5   # reward per pixel closer to exit
const EXIT_RETREAT_PENALTY_PER_PIXEL: float = 0.5   # penalty per pixel farther

const EXIT_ALIGN_DOT_THRESHOLD: float = 0.7
const EXIT_ALIGN_REWARD: float = 0.2
const EXIT_MISALIGN_PENALTY: float = 0.05

const EXIT_COMPLETION_BONUS: float = 125.0  # big reward when actually reaching the exit

# --- STAGNATION CHECKING ---
var last_significant_score: float = 0.0

# --- CIRCLE CHECKING ---
var total_path_length: float = 0.0
const MIN_PATH_LENGTH: float = 100.0 # ignoring very short early runs
const EFFICIENCY_THRESHOLD: float = 0.15 # <15% effective progress
const CIRCLE_TIME_LIMIT: float = 5.0

# --- SPINNING CHECKING ---
var prev_spin_angle: float = 0.0
var total_spin_angle: float = 0.0
const SPIN_THRESHOLD: float = TAU*2
const SPIN_TIME_LIMIT: float = 5.0
const SMALL_ANGLE: float = deg_to_rad(3)

# --- TIMERS ---
var stagnation_timer: float = 0.0
var circle_timer: float = 0.0
var spin_timer: float = 0.0
var stuck_timer: float = 0.0
var idle_timer: float = 0.0

func _init(ag_ref: CharacterBody2D) -> void:
	self.agent = ag_ref
	self.memory = ag_ref.memory
	self.score = ag_ref.score

func reset() -> void:
	score = 0.0
	# --- STAGNATION CHECKING ---
	last_significant_score = 0.0

	# --- SPINNING CHECKING ---
	prev_spin_angle = 0.0
	total_spin_angle = 0.0

	# --- CIRCLE CHECKING ---
	total_path_length = 0.0

	# --- TIMER RESETS ---
	stagnation_timer = 0.0
	circle_timer = 0.0
	spin_timer = 0.0
	stuck_timer = 0.0
	idle_timer = 0.0

func update_score(delta: float) -> void:
	var dist_moved = agent.global_position.distance_to(agent.prev_position)
	var net_displacement = agent.global_position.distance_to(agent.start_position)
	var vel_aligned = 0.0
	if agent.velocity.length() > 0.001:
		vel_aligned = agent.velocity.normalized().dot(agent.direction)

	# -------------------------
	# 1. Movement / Alignment
	# -------------------------
	if dist_moved > 0.0:
		score += dist_moved * MOVE_REWARD_FACTOR
	if vel_aligned > 0.7:
		score += VEL_ALIGN_REWARD
	else:
		score -= VEL_MISALIGN_PENALTY
	
	# Penalty for being Idle / very slow
	if agent.velocity.length() < IDLE_SPEED_THRESHOLD:
		score -= delta * IDLE_PENALTY_PER_SEC
	
	# -------------------------
	# 2. Exit shaping
	# -------------------------
	if !memory.exit_dict.is_empty():
		# Check if they are in line with the exit direction
		for key in memory.exit_dict.keys():
			var mem_entry = memory.memory_dict.get(key, null)
			if mem_entry == null:
				continue
			
			var curr_dist: float = mem_entry["distance"]
			var prev_dist: float = agent.prev_exit_distances.get(key, curr_dist)
			var dir_to_exit: Vector2 = mem_entry["direction"].normalized()
			
			# Direction reward: Agent moving roughly toward the exit
			var vel_norm = agent.velocity
			if vel_norm.length_squared() > 0.01:
				vel_norm = vel_norm.normalized()
				var exit_aligned: float = vel_norm.dot(dir_to_exit)
				if exit_aligned > EXIT_ALIGN_DOT_THRESHOLD:
					score += EXIT_ALIGN_REWARD
				else:
					score -= EXIT_MISALIGN_PENALTY
				
			# Distance change reward
			var delta_d: float = prev_dist - curr_dist
			if delta_d > 0.0:
				score += delta_d * EXIT_APPROACH_REWARD_PER_PIXEL
			elif delta_d < 0.0:
				score += delta_d * EXIT_RETREAT_PENALTY_PER_PIXEL
			
			agent.prev_exit_distances[key] = memory.memory_dict[key]["distance"]
			
	# -------------------------
	# 3. Kill checks 
	# -------------------------	
	
	# OVERALL JUST BAD CHECK
	if score < -40:
		agent.death_flag = true
		agent.death_reason = SimulationManager.DeathTypes.BAD_SCORE
		return 
	
	# SPIN CHECK
	var current_spin_angle = agent.direction.angle()
	var delta_rotation_rad = current_spin_angle - prev_spin_angle
	
	if delta_rotation_rad > PI:
		delta_rotation_rad -= TAU
	elif delta_rotation_rad < -PI:
		delta_rotation_rad += TAU
	
	prev_spin_angle = current_spin_angle
		
	if abs(delta_rotation_rad) > SMALL_ANGLE:
		spin_timer += delta
		total_spin_angle += abs(delta_rotation_rad)
	else:	
		total_spin_angle = 0.0
		spin_timer = 0.0
		
	if spin_timer >= SPIN_TIME_LIMIT and total_spin_angle >= SPIN_THRESHOLD: # 2 full cycles
		score -= 20
		agent.death_flag = true
		agent.death_reason = SimulationManager.DeathTypes.SPINNING
		return 
	
	# CIRCLE CHECK
	total_path_length += dist_moved
	var efficiency = (net_displacement / max(total_path_length, 0.001))
	
	if total_path_length > MIN_PATH_LENGTH and efficiency < EFFICIENCY_THRESHOLD:
		circle_timer += delta
	else:
		circle_timer = 0.0
	
	if circle_timer > CIRCLE_TIME_LIMIT:
		score -= 15.0
		agent.death_flag = true
		agent.death_reason = SimulationManager.DeathTypes.CIRCLING
		return 
		
	# TOUCHED THE WALL TOO MANY TIMES CHECK
	if agent.wall_touch_counter > 4:
		# score is already deducted every wall touch
		agent.death_flag = true
		agent.death_reason = SimulationManager.DeathTypes.WALL_TOUCH
		return 
	
	# PROGRESS CHECK
	var progress = score - last_significant_score

	if progress > 0.02:
		stagnation_timer = 0.0
		last_significant_score = score
	else:
		stagnation_timer += delta

	if stagnation_timer > 10.0: # 10 seconds of no real score gain
		score -= 20.0
		agent.death_flag = true
		agent.death_reason = SimulationManager.DeathTypes.STAGNATION
		return 
	
	# STUCK ON WALL CHECK
	if agent.is_on_wall() and dist_moved < 1.0:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	
	if stuck_timer > 2.0:
		score -= 40.0
		agent.death_flag = true
		agent.death_reason = SimulationManager.DeathTypes.WALL_STUCK
		return 
	
	# NO MOVEMENT CHECK
	if dist_moved < 1.0 and agent.velocity.length() < 2.0: # and if no arrow trap in range
		idle_timer += delta
		if idle_timer > 5.0:
			score -= 20.0
			agent.death_flag = true
			agent.death_reason = SimulationManager.DeathTypes.NO_MOVEMENT
			return 
	else:
		idle_timer = 0.0
	
	# Update previous for next update
	agent.prev_position = agent.global_position
	agent.prev_velocity = agent.velocity
	
	agent.score = score
	return 
