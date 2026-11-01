class_name CombatUnravel
extends RefCounted
## Roster-bound Unravel gauge service. Pure rules, no scene dependencies, no RNG.
## Gauges are per original position (1-based, never compacted). Thresholds: normal=8, elite=12, boss=16.
## On reaching threshold: mark unravelled, queue exactly one action skip, clamp gauge to threshold.
## Consuming the skip resets gauge to 0, clears unravelled, raises threshold by 4.
## No cross-fight leakage; snapshots are deep copies. Bleed ticks add exactly 1 Unravel per tick.

const MAX_ENEMIES := 3
const THRESHOLD_NORMAL := 8
const THRESHOLD_ELITE := 12
const THRESHOLD_BOSS := 16
const THRESHOLD_INCREMENT := 4
const VALID_TIERS := ["normal", "elite", "boss"]

var _bound_enemies: CombatEnemies = null
var _gauges: Dictionary = {}  # position -> {gauge: int, threshold: int, unravelled: bool, skip_pending: bool}
var _tiers_by_position: Dictionary = {}  # position -> "normal"|"elite"|"boss"


func bind_roster(enemies: CombatEnemies, tiers_by_position: Dictionary) -> bool:
	## Atomically bind to a CombatEnemies roster with explicit tier per original position.
	## tiers_by_position uses integer keys 1,2,3 with values "normal", "elite", or "boss".
	## Rejects incomplete, unknown, or invalid tiers. Returns false without partial state.
	if enemies == null or not enemies.is_valid():
		return false
	if not tiers_by_position is Dictionary:
		return false
	var expected_positions: Array[int] = []
	for i in range(enemies.get_enemies().size()):
		expected_positions.append(i + 1)
	if tiers_by_position.size() != expected_positions.size():
		return false
	var new_gauges: Dictionary = {}
	var new_tiers: Dictionary = {}
	for position in expected_positions:
		if not tiers_by_position.has(position):
			return false
		var tier = tiers_by_position[position]
		if not tier is String or tier not in VALID_TIERS:
			return false
		var threshold: int
		match tier:
			"normal": threshold = THRESHOLD_NORMAL
			"elite": threshold = THRESHOLD_ELITE
			"boss": threshold = THRESHOLD_BOSS
		new_gauges[position] = {
			"gauge": 0,
			"threshold": threshold,
			"unravelled": false,
			"skip_pending": false
		}
		new_tiers[position] = tier
	_bound_enemies = enemies
	_gauges = new_gauges
	_tiers_by_position = new_tiers
	return true


## Extend this fight's original gauges for the one authenticated spawned normal
## child. Preserve every earlier gauge, pending skip and threshold in place.
func admit_broodling(enemies: CombatEnemies) -> bool:
	if enemies == null or enemies != _bound_enemies or not enemies.is_valid():
		return false
	var position := enemies.get_enemies().size()
	if position < 2 or position > enemies.get_capacity() or _gauges.size() != position - 1:
		return false
	var child := enemies.get_enemy(position)
	if child.get("id") != CombatEnemies.BROODLING_ID or child.get("max_hp") != 8 \
			or child.get("position") != position or child.get("hp", 0) <= 0:
		return false
	var parent_latched := false
	for index in range(1, position):
		if enemies.get_enemy(index).get("id") in [CombatEnemies.MOTH_ID, CombatEnemies.MOTH_QUEEN_ID] \
				and enemies.get_enemy(index).get(CombatEnemies.BROODLING_LATCH) == true:
			parent_latched = true
	if not parent_latched:
		return false
	_gauges[position] = {"gauge": 0, "threshold": THRESHOLD_NORMAL,
		"unravelled": false, "skip_pending": false}
	_tiers_by_position[position] = "normal"
	return true


func get_snapshot(position: int) -> Dictionary:
	## Return a deep copy of the gauge state for the given position.
	## Returns empty dictionary if unbound or invalid position.
	if _bound_enemies == null:
		return {}
	if not _gauges.has(position):
		return {}
	return _gauges[position].duplicate(true)


func apply_unravel(enemies: CombatEnemies, position: int, amount: int) -> bool:
	## Add Unravel amount to the gauge. Returns false if unbound, wrong roster, slain/missing slot, or invalid amount.
	## On reaching threshold: clamp gauge to threshold, mark unravelled, queue exactly one skip.
	## Repeated charges at/above threshold do not stack additional skips.
	if not _validate_roster_and_position(enemies, position):
		return false
	if not amount is int or amount < 0:
		return false
	var gauge_data: Dictionary = _gauges[position]
	if gauge_data["unravelled"] and gauge_data["skip_pending"]:
		return true
	var new_gauge: int = gauge_data["gauge"] + amount
	if new_gauge >= gauge_data["threshold"]:
		new_gauge = gauge_data["threshold"]
		gauge_data["unravelled"] = true
		gauge_data["skip_pending"] = true
	gauge_data["gauge"] = new_gauge
	return true


func record_bleed_tick(enemies: CombatEnemies, position: int) -> bool:
	## Record that a Bleed tick occurred on the enemy at position.
	## Adds exactly 1 Unravel regardless of Bleed HP damage or Block.
	## Returns false if unbound, wrong roster, slain/missing slot.
	if not _validate_roster_and_position(enemies, position):
		return false
	return apply_unravel(enemies, position, 1)


func consume_action_skip(enemies: CombatEnemies, position: int) -> bool:
	## Consume the pending action skip for the enemy at position.
	## Returns true if a skip was pending and consumed (resets gauge to 0, raises threshold by 4, clears unravelled/skip_pending).
	## Returns false if no skip pending, unbound, wrong roster, or invalid position.
	if not _validate_roster_and_position(enemies, position):
		return false
	var gauge_data: Dictionary = _gauges[position]
	if not gauge_data["skip_pending"]:
		return false
	gauge_data["gauge"] = 0
	gauge_data["threshold"] += THRESHOLD_INCREMENT
	gauge_data["unravelled"] = false
	gauge_data["skip_pending"] = false
	return true


## The Termite split replaces one living source with two fresh actors. Their
## gauges start clean: an old charge, threshold break or pending skip never
## transfers. Every unrelated gauge stays byte-for-byte in place.
func can_admit_split(enemies: CombatEnemies, source: Variant,
		proposed: Variant = null) -> bool:
	return not _split_proposal(enemies, source, proposed).is_empty()


func admit_split(enemies: CombatEnemies, source: Variant) -> bool:
	var proposal := _split_proposal(enemies, source, null)
	if proposal.is_empty():
		return false
	_gauges = proposal["gauges"]
	_tiers_by_position = proposal["tiers"]
	return true


func _split_proposal(enemies: CombatEnemies, source: Variant,
		proposed: Variant = null) -> Dictionary:
	if _bound_enemies == null or enemies != _bound_enemies or not enemies.is_valid():
		return {}
	var roster: Array = []
	if proposed == null:
		roster = enemies.get_enemies()
	elif proposed is Array:
		roster = proposed
	else:
		return {}
	var old_size := _gauges.size()
	if old_size < 1 or old_size >= enemies.get_capacity() or roster.size() != old_size + 1:
		return {}
	if not source is int or source < 1 or source > old_size:
		return {}
	if _tiers_by_position.size() != old_size:
		return {}
	var left: Dictionary = roster[source - 1]
	var right: Dictionary = roster[old_size]
	if not _valid_split_half(left, source, CombatEnemies.HALF_LEFT_ID) \
			or not _valid_split_half(right, old_size + 1, CombatEnemies.HALF_RIGHT_ID):
		return {}
	for index in range(old_size):
		if not _valid_gauge(_gauges.get(index + 1)):
			return {}
	var tier = _tiers_by_position.get(source)
	if not tier is String or tier not in VALID_TIERS:
		return {}
	var threshold := _threshold_for(tier)
	var gauges := _gauges.duplicate(true)
	gauges[source] = {"gauge": 0, "threshold": threshold,
		"unravelled": false, "skip_pending": false}
	gauges[old_size + 1] = {"gauge": 0, "threshold": threshold,
		"unravelled": false, "skip_pending": false}
	var tiers := _tiers_by_position.duplicate(true)
	tiers[old_size + 1] = tier
	return {"gauges": gauges, "tiers": tiers}


static func _valid_split_half(record: Dictionary, position: int, id: String) -> bool:
	if record.get("id") != id or record.get("position") != position:
		return false
	var maximum = record.get("max_hp")
	if not maximum is int or maximum <= 0 or record.get("hp") != maximum \
			or record.get("block") != 0:
		return false
	if record.has("enemy_position") and record["enemy_position"] != position:
		return false
	if record.has("statuses") or record.has(CombatEnemies.SPLIT_FIELD) \
			or record.has("revive_once") or record.has("revived") \
			or record.has("chew_block_on_attack"):
		return false
	var spec = record.get("intent")
	if not spec is Dictionary or spec.get("target") != "front":
		return false
	var actions = spec.get("actions")
	if not actions is Array or actions.size() != 1:
		return false
	var action = actions[0]
	return action is Dictionary and action.get("type") == "attack" \
		and action.get("amount") is int and action["amount"] >= 1 \
		and action.get("weight") == 1 and action.size() == 3


static func _valid_gauge(gauge: Variant) -> bool:
	if not gauge is Dictionary or gauge.size() != 4:
		return false
	var amount = gauge.get("gauge")
	var threshold = gauge.get("threshold")
	var pending = gauge.get("skip_pending")
	var unravelled = gauge.get("unravelled")
	if not amount is int or not threshold is int or not pending is bool \
			or not unravelled is bool:
		return false
	return threshold > 0 and amount >= 0 and amount <= threshold \
		and pending == unravelled and (amount == threshold) == pending


static func _threshold_for(tier: String) -> int:
	match tier:
		"elite":
			return THRESHOLD_ELITE
		"boss":
			return THRESHOLD_BOSS
	return THRESHOLD_NORMAL


func _validate_roster_and_position(enemies: CombatEnemies, position: int) -> bool:
	if enemies != _bound_enemies or _bound_enemies == null:
		return false
	if not _bound_enemies.is_valid():
		return false
	if not _gauges.has(position):
		return false
	if _bound_enemies.is_slain(position):
		return false
	return true