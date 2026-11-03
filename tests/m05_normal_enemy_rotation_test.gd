extends SceneTree
## The four M05 normals travel through production catalogs, typed Fight selection,
## seeded weighted phases and a real mounted routed battle.

const POOLS := "res://data/encounters/m03_typed_battle_pools.json"
const CATALOGS := RunAuthoredBattleEntry.CATALOG_PATHS
const NEW := {
	"felt_bulwark": {"name": "Felt Bulwark", "max_hp": 18, "target": "front",
		"actions": [{"type": "attack", "amount": 5, "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
			{"type": "block", "amount": 3, "weight": 3},
			{"type": "buff", "amount": 2, "weight": 1}]},
	"moth_scribe": {"name": "Moth Scribe", "max_hp": 14, "target": "exposed",
		"chew_block_on_attack": true,
		"actions": [{"type": "attack", "amount": 5, "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "weak", "weight": 2},
			{"type": "block", "amount": 2, "weight": 1}]},
	"pin_skitter": {"name": "Pin Skitter", "max_hp": 13, "target": "random", "thorns": 2,
		"actions": [{"type": "attack", "amount": 5, "weight": 4},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1},
			{"type": "block", "amount": 1, "weight": 1}]},
	"thread_biter": {"name": "Thread Biter", "max_hp": 15, "target": "lowest_living_hp",
		"drain": true,
		"actions": [{"type": "attack", "amount": 5, "weight": 2},
			{"type": "attack", "amount": 6, "weight": 1, "move": "attack2"},
			{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
			{"type": "block", "amount": 2, "weight": 1}]},
}
const OLD := {
	"ragling": ["Ragling", 12, "front", [{"type": "attack", "amount": 5, "weight": 3}]],
	"ragling_guard": ["Guard Ragling", 12, "front",
		[{"type": "block", "amount": 5, "weight": 3},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
			{"type": "attack", "amount": 6, "weight": 1},
			{"type": "attack", "amount": 7, "weight": 1, "move": "attack2"}]],
	"fray_scavenger": ["Fray Scavenger", 14, "lowest_living_hp",
		[{"type": "attack", "amount": 5, "weight": 3},
			{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
			{"type": "block", "amount": 2, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
			{"type": "steal_gold", "amount": 2, "weight": 1}]],
	"button_guard": ["Button Guard", 16, "front",
		[{"type": "attack", "amount": 5, "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
			{"type": "block", "amount": 2, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]],
	"spool_stalker": ["Spool Stalker", 14, "exposed",
		[{"type": "attack", "amount": 5, "weight": 3}, {"type": "block", "amount": 2, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 2},
			{"type": "buff", "amount": 2, "weight": 1}]],
	"seam_ripper": ["Seam Ripper", 18, "lowest_living_hp",
		[{"type": "attack", "amount": 5, "weight": 3}, {"type": "block", "amount": 2, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
			{"type": "buff", "amount": 2, "weight": 1}]],
}
const PAIRS := {
	"felt_moth_pressure": {"schedule": "res://data/encounters/bobbin_skirmish.json",
		"enemy_ids": ["felt_bulwark", "moth_scribe"]},
	"pin_thread_crossfire": {"schedule": "res://data/encounters/buttonhole_holdout.json",
		"enemy_ids": ["pin_skitter", "thread_biter"]},
}
const PRIOR := {
	"Fight": {
		"buttonfront_pinfall": ["button_guard", "fray_scavenger"],
		"starter_attacks": ["ragling", "ragling_guard"],
		"bobbin_skirmish": ["fray_scavenger", "spool_stalker"],
		"buttonhole_holdout": ["button_guard", "seam_ripper"],
		"guard_counterattack": ["ragling_guard", "button_guard"],
		"double_hem_siege": ["fray_scavenger", "seam_ripper"],
		"triple_spool_pinch": ["fray_scavenger", "button_guard", "spool_stalker"],
		"seamshift_tripwire": ["seam_ripper", "spool_stalker", "fray_scavenger"],
		"front_hem_pivot": ["button_guard", "fray_scavenger"],
		"rear_spool_reversal": ["spool_stalker", "seam_ripper"],
		"rearline_needlemark": ["fray_scavenger", "seam_ripper"],
		"middlemark_clamp": ["spool_stalker", "seam_ripper"],
		"backhem_pinwheel": ["fray_scavenger", "button_guard", "spool_stalker"],
		"hemdrag_relay": ["seam_ripper", "button_guard"],
		"spoolbridge_staggered_exposure": ["spool_stalker", "seam_ripper"],
		"hemhook_exposed_swap": ["spool_stalker", "seam_ripper", "fray_scavenger"],
	},
	"Elite": {"thimble_crossfire": ["button_guard", "seam_ripper"],
		"needle_marshal_elite": ["needle_marshal", "ragling_guard"],
		"spool_hexer_elite": ["spool_hexer", "spool_stalker"]},
	"Boss": {"patchwork_behemoth": ["patchwork_behemoth"]},
}

var failures: Array[String] = []
var checks := 0
var catalog := {}
var pools := {}

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)

func _rng(value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = value
	return result

func _normalized(value: Variant) -> Variant:
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_normalized(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _normalized(value[key])
		return result
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return value

func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30},
		{"id": "tinker", "name": "Tinker", "max_hp": 26},
	])
	_check(party.is_valid() and CombatEnemyIntents.living_positions(party) == [1, 2, 3],
		"genuine three-hero combat authority starts living")
	return party

func _catalog_and_bindings() -> void:
	for path in CATALOGS:
		var raw := FileAccess.get_file_as_string(path)
		var parsed := RunTypedBattleRoster._parse_catalog_text(raw)
		_check(not raw.is_empty() and not parsed.is_empty(), "genuine catalog parses " + path)
		for record in parsed:
			_check(not catalog.has(record.id), "unique enemy ID across all catalogs " + record.id)
			catalog[record.id] = _normalized(record)
	for id in NEW:
		var expected: Dictionary = NEW[id]
		_check(catalog.has(id), "M05 ID present " + id)
		if not catalog.has(id):
			continue
		var record: Dictionary = catalog[id]
		var expected_record := {"id": id, "name": expected.name, "max_hp": expected.max_hp,
			"art_path": "res://assets/paper/enemies/" + id + ".png",
			"intent": {"target": expected.target, "actions": expected.actions}}
		# Authored keyword metadata lives beside the intent and only the records
		# that genuinely carry it may add it to the exact record oracle.
		if expected.has("drain"):
			expected_record["drain"] = expected.drain
		if expected.has("thorns"):
			expected_record["thorns"] = expected.thorns
		if expected.has("chew_block_on_attack"):
			expected_record["chew_block_on_attack"] = expected.chew_block_on_attack
		_check(record == expected_record,
			"exact new identity, HP, art, policy and ordered weighted actions " + id)
		for raw in expected.actions:
			_check(CombatEnemyIntents.positive_weight(raw.weight) > 0
				and not CombatEnemyIntents.weighted_action(raw).is_empty(),
				"new weighted action is executable " + id + " " + str(raw))
	var scribe_record: Dictionary = catalog.get("moth_scribe", {})
	var bulwark_record: Dictionary = catalog.get("felt_bulwark", {})
	_check(not scribe_record.is_empty() and scribe_record.get("chew_block_on_attack") is bool
		and scribe_record.get("chew_block_on_attack") == true
		and not bulwark_record.is_empty()
		and not bulwark_record.has("chew_block_on_attack"),
		"AC1: only the Moth Scribe in the real felt_moth_pressure pair chews Block")
	_check(scribe_record.get("intent", {}).get("actions") == [
			{"type": "attack", "amount": 5, "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "weak", "weight": 2},
			{"type": "block", "amount": 2, "weight": 1}],
		"AC1: the Scribe has exact attack/attack2/attack3/Weak/Block weighted 1/1/1/2/1 actions")
	for id in OLD:
		_check(catalog.has(id), "original normal still present " + id)
		if not catalog.has(id):
			continue
		var old: Array = OLD[id]
		_check(catalog[id] == {"id": id, "name": old[0], "max_hp": old[1],
			"art_path": "res://assets/paper/enemies/" + id + ".png",
			"intent": {"target": old[2], "actions": old[3]}},
			"original normal retains exact full definition " + id)
	pools = JSON.parse_string(FileAccess.get_file_as_string(POOLS))
	_check(pools is Dictionary and pools.get("Fight") is Dictionary
		and pools.get("Elite") is Dictionary and pools.get("Boss") is Dictionary,
		"production typed Fight/Elite/Boss pools parse")
	if not pools is Dictionary or not pools.get("Fight") is Dictionary:
		return
	for id in PAIRS:
		_check(pools["Fight"].get(id) == PAIRS[id], "new named Fight alias exact " + id)
		var definitions := RunFightEncounterSelection._parse_schedule_text(
			FileAccess.get_file_as_string(PAIRS[id].schedule))
		_check(definitions.size() == 2 and definitions[0].enemy_position == 1
			and definitions[1].enemy_position == 2,
			"reused original schedule contains two ordered sources " + id)
	for kind in PRIOR:
		for id in PRIOR[kind]:
			_check(pools[kind].get(id) == {"schedule": "res://data/encounters/" + id + ".json",
				"enemy_ids": PRIOR[kind][id]},
				"unmodified prior typed binding " + kind + "/" + id)

func _choose_fight(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight" and map.choose_node(id):
			return id
	return ""

func _assemble(id: String, run_seed: int) -> Dictionary:
	var rng := _rng(run_seed)
	var map := RunMap.new()
	_check(map.generate(rng), "seeded real twelve-floor map created " + id)
	var node := _choose_fight(map)
	_check(not node.is_empty() and map.get_node(node).get("type") == "Fight"
		and map.get_route() == [node], "actual legal current Fight chosen " + id)
	if node.is_empty():
		return {}
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, {"Fight": {id: PAIRS[id].schedule}})
	_check(choice.get("success") and choice.get("node_type") == "Fight"
		and choice.get("encounter_id") == id, "real typed selector reaches alias " + id)
	if not choice.get("success", false):
		return {}
	var before := [map.get_floors(), map.get_route(), map.get_legal_choices(),
		rng.state, selector._selected.duplicate(true)]
	var roster := RunTypedBattleRoster.new().assemble(choice, {id: PAIRS[id].enemy_ids}, CATALOGS)
	_check(roster.get("ok") and roster.get("node_type") == "Fight",
		"real typed assembler resolves alias catalogs " + id)
	_check(before == [map.get_floors(), map.get_route(), map.get_legal_choices(),
		rng.state, selector._selected.duplicate(true)],
		"assembly neither spends RNG nor mutates route/selection cache " + id)
	if not roster.get("ok", false):
		return {}
	var expected: Array = PAIRS[id].enemy_ids
	var snapshots: Array = roster.enemies.get_enemies()
	_check(snapshots.size() == 2 and CombatEnemyIntents.new(roster.definitions).is_valid(),
		"two living source slots and valid schedule " + id)
	for index in range(2):
		var actor: Dictionary = roster.enemies.get_enemy(index + 1)
		var authored: Dictionary = NEW[expected[index]]
		_check(actor.get("id") == expected[index] and actor.get("name") == authored.name
			and actor.get("position") == index + 1 and actor.get("hp") == authored.max_hp
			and actor.get("max_hp") == authored.max_hp and actor.get("block") == 0,
			"source identity, HP and slot " + id + "/" + str(index + 1))
	_check(roster.definitions == RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(PAIRS[id].schedule)),
		"exact pre-existing schedule carried intact " + id)
	var live := RunAuthoredBattleEntry.new()._entry_from_data(map, _rng(981), 
		RunFightEncounterSelection.new(), {"Fight": {id: PAIRS[id]}})
	_check(live.get("success") and live.get("encounter_id") == id
		and live.get("enemies") is CombatEnemies and live.get("intents") is CombatEnemyIntents,
		"live production entry accepts canonical schedule alias " + id)
	return {"choice": choice, "roster": roster, "rng_state": rng.state,
		"floors": map.get_floors(), "route": map.get_route()}

func _weighted(id: String, assembled: Dictionary) -> void:
	if assembled.is_empty():
		return
	var present := {}
	for seed_value in range(1, 161):
		var first: Array = []
		var states: Array = []
		var phase_states: Array = []
		for replay in range(2):
			var party := _party()
			_check(party.apply_damage(3, 21), "Tinker wounded for policy differentiation")
			party._heroes[1]["statuses"] = {"exposed": 2}
			var enemies := CombatEnemies.new(assembled.roster.enemies.get_enemies())
			var rng := _rng(seed_value)
			var scheduler := CombatEnemyIntents.new(assembled.roster.definitions)
			_check(enemies.is_valid() and scheduler.bind_battle(enemies, party, rng),
				"actual authored roster binds weighted intents " + id)
			if not scheduler.is_bound():
				return
			var announced := scheduler.get_intents()
			var committed := rng.state
			_check(announced.size() == 2 and announced == scheduler.get_intents(),
				"cached prediction unchanged on UI-style refresh " + id)
			_check(rng.state == committed, "forecast reads spend zero RNG " + id)
			# Independent RNG oracle: one weighted roll per source, plus only
			# random-policy targeting when that source needs a hero.
			var oracle := _rng(seed_value)
			for index in range(2):
				var spec: Dictionary = NEW[PAIRS[id].enemy_ids[index]]
				var total := 0
				for raw in spec.actions:
					total += raw.weight
				var roll := oracle.randi_range(1, total)
				var picked: Dictionary = {}
				for raw in spec.actions:
					roll -= raw.weight
					if roll <= 0:
						picked = raw
						break
				var action: Dictionary = announced[index]
				var body: Dictionary = picked.duplicate(true)
				body.erase("weight")
				for key in body:
					if key == "direction" and body.type == "shove":
						_check(action.get(key) in [-1, 1],
							"authored shove is bounded to a legal direction " + id)
					else:
						_check(action.get(key) == body[key],
							"weighted announced action matches seeded authored roll " + id)
				_check(action.get("enemy_position") == index + 1,
					"announced source stays in original slot " + id)
				if action.type in ["attack", "debuff", "shove"]:
					var target := CombatEnemyIntents.priority_target(party, spec.target)
					if spec.target == "random":
						target = [1, 2, 3][oracle.randi_range(0, 2)]
					_check(action.get("target_position") == target,
						"announced live target matches policy and run RNG " + id)
				else:
					_check(not action.has("target_position"),
						"Block/buff never invent a hero target " + id)
				present[PAIRS[id].enemy_ids[index] + "/" + action.get("move", action.type)] = true
			_check(rng.state == oracle.state,
				"only expected weighted and random-target RNG draws consumed " + id)
			first.append(announced)
			states.append(rng.state)
			var phase := CombatEnemyPhase.new().execute_phase(party, enemies, announced, null, true)
			_check(phase.get("ok") and phase.get("events", []).size() == 2,
				"actual enemy phase executes announced alternatives " + id)
			_check(scheduler.get_intents() == announced and rng.state == committed,
				"execution does not reroll the cached predictions " + id)
			phase_states.append([phase.get("events"), party.get_heroes(), enemies.get_enemies()])
		_check(first[0] == first[1] and states[0] == states[1]
			and phase_states[0] == phase_states[1],
			"two same-seed announcements and committed phases replay identically " + id)
	for actor_id in PAIRS[id].enemy_ids:
		for raw in NEW[actor_id].actions:
			_check(present.has(actor_id + "/" + raw.get("move", raw.type)),
				"actual seeded phase covered authored alternative " + actor_id + "/" + raw.get("move", raw.type))
	# Preannounced targets downed after admission fall back at execution time
	# without a second roll, for both deterministic and random policies.
	for source in range(2):
		var found := false
		for seed_value in range(1, 90):
			var party := _party()
			var enemies := CombatEnemies.new(assembled.roster.enemies.get_enemies())
			var rng := _rng(seed_value)
			var scheduler := CombatEnemyIntents.new(assembled.roster.definitions)
			if not scheduler.bind_battle(enemies, party, rng):
				continue
			var announced := scheduler.get_intents()
			var action: Dictionary = announced[source]
			if not action.has("target_position"):
				continue
			var target: int = action.target_position
			var old_hp: int = party.get_hero(target).hp
			if not party.apply_damage(target, old_hp) or not party.is_downed(target):
				continue
			var before_rng := rng.state
			var expected_target := CombatEnemyIntents.priority_target(party,
				NEW[PAIRS[id].enemy_ids[source]].target)
			var resolved := CombatEnemyIntents.resolve_announced_action(party, action, enemies)
			_check(resolved.get("target_position") == expected_target
				and not party.is_downed(expected_target),
				"downed announced target finds legal deterministic fallback " + id)
			var phase := CombatEnemyPhase.new().execute_phase(party, enemies, [action], null, true)
			_check(phase.get("ok") and phase.get("events", []).size() == 1
				and phase.events[0].get("target_position") == expected_target,
				"executor uses live legal fallback of announced action " + id)
			_check(rng.state == before_rng and scheduler.get_intents() == announced,
				"downed fallback spends no RNG or reroll " + id)
			found = true
			break
		_check(found, "found genuine target-bearing action for downed fallback " + id)

## The genuine assembled record for one authored ID, so focused beats reuse the
## real roster's identity, HP, art and authored alternatives.
func _pair_record(assembled: Dictionary, id: String) -> Dictionary:
	if assembled.is_empty():
		return {}
	for record in assembled.roster.enemies.get_enemies():
		if record is Dictionary and record.get("id") == id:
			return record.duplicate(true)
	return {}

## The authored alternative of one kind/amount from the genuine pair record.
func _pair_action(assembled: Dictionary, id: String, kind: String,
		amount: int) -> Dictionary:
	for raw in _pair_record(assembled, id).get("intent", {}).get("actions", []):
		if raw is Dictionary and raw.get("type") == kind \
				and int(raw.get("amount", -1)) == amount:
			return raw.duplicate(true)
	return {}

func _slot_for(enemies: CombatEnemies, id: String) -> int:
	for index in range(enemies.get_enemies().size()):
		if enemies.get_enemy(index + 1).get("id") == id:
			return index + 1
	return 0

func _announced_for(intents: Array, source: int) -> Dictionary:
	for action in intents:
		if action is Dictionary and action.get("enemy_position") == source:
			return action.duplicate(true)
	return {}

## Bind the genuine assembled pair with one source narrowed to a single authored
## alternative (weight 1): one authored weighted choice, never a guessed seed.
## The other source keeps its real alternatives, so the run RNG keeps its real
## cadence (exactly its one weighted roll, no extra target draw).
func _forced_pair(assembled: Dictionary, party: CombatParty, source_id: String,
		action: Dictionary, override: Dictionary = {}) -> Dictionary:
	if assembled.is_empty() or not party.is_valid() or action.is_empty():
		return {}
	var normalized := CombatEnemyIntents.weighted_action(action)
	var body: Dictionary = normalized.get("action", {}).duplicate(true)
	_check(not body.is_empty(), "focused beat is a valid authored action: " + str(action))
	if body.is_empty():
		return {}
	body["weight"] = 1
	var records: Array = []
	var narrowed := false
	for record in assembled.roster.enemies.get_enemies():
		var copy: Dictionary = record.duplicate(true)
		if copy.get("id") == source_id:
			if not override.is_empty():
				copy = override.duplicate(true)
			copy["intent"] = {"target": copy.get("intent", {}).get("target"),
				"actions": [body]}
			narrowed = true
		records.append(copy)
	_check(narrowed, "the genuine pair contains the focused source " + source_id)
	if not narrowed:
		return {}
	var enemies := CombatEnemies.new(records)
	var rng := _rng(18141)
	var scheduler := CombatEnemyIntents.new(assembled.roster.definitions)
	var bound := enemies.is_valid() and scheduler.bind_battle(enemies, party, rng)
	_check(bound, "the genuine pair binds the focused beat " + source_id)
	if not bound:
		return {}
	return {"enemies": enemies, "party": party, "rng": rng,
		"intents": scheduler.get_intents(), "scheduler": scheduler}

## AC1/AC2/AC3: the real assembled felt_moth_pressure pair, the Scribe alive and
## a living Exposed hero holding six Block. Its authentic five-point bite clears
## that Block before the shared Exposed-adjusted damage lands; the Weak 1 and
## Block 2 alternatives, an unflagged source and a slain Scribe stay inert.
func _scribe_chew(assembled: Dictionary) -> void:
	if assembled.is_empty():
		return
	var scribe := _pair_record(assembled, "moth_scribe")
	var bulwark := _pair_record(assembled, "felt_bulwark")
	_check(not scribe.is_empty() and not bulwark.is_empty(),
		"AC1 precondition: the real felt_moth_pressure pair assembles")
	if scribe.is_empty() or bulwark.is_empty():
		return
	_check(scribe.get("chew_block_on_attack") is bool
		and scribe.get("chew_block_on_attack") == true
		and not bulwark.has("chew_block_on_attack"),
		"AC1: only the real Moth Scribe in the pair carries the genuine chew trait")
	_check(int(scribe.get("max_hp", 0)) == 14
		and String(scribe.get("art_path", "")) == "res://assets/paper/enemies/moth_scribe.png"
		and scribe.get("intent", {}).get("target") == "exposed",
		"AC1: the assembled Scribe keeps its 14 HP, art path and exposed policy")
	var bite := _pair_action(assembled, "moth_scribe", "attack", 5)
	var weaken := _pair_action(assembled, "moth_scribe", "debuff", 1)
	var brace := _pair_action(assembled, "moth_scribe", "block", 2)
	_check(_normalized(bite) == _normalized(NEW["moth_scribe"].actions[0])
		and _normalized(weaken) == _normalized(NEW["moth_scribe"].actions[3])
		and _normalized(brace) == _normalized(NEW["moth_scribe"].actions[4]),
		"AC1: the assembled 5/Weak-1/Block-2 alternatives have exact weights 1/2/1")

	# AC2: the exposed policy selects the living Exposed hero, and the real
	# production phase eats all six of its Block before the bite resolves.
	var party := _party()
	party._heroes[1]["statuses"] = {"exposed": 1}
	_check(party.gain_block(2, 6) and party.get_hero(2).get("block") == 6,
		"AC2 precondition: the Exposed Seamstress really holds six Block")
	_check(CombatStatuses.new().adjusted_attack_damage(5, {}, {"exposed": 1}) == 7,
		"AC2 precondition: the shared Exposed rule turns the authentic five into seven")
	var live := _forced_pair(assembled, party, "moth_scribe", bite)
	if live.is_empty():
		return
	var slot := _slot_for(live.enemies, "moth_scribe")
	_check(slot == 2, "AC2: the Scribe keeps its genuine assembled slot")
	var announced := _announced_for(live.intents, slot)
	_check(announced.get("type") == "attack" and int(announced.get("amount", -1)) == 5
		and announced.get("target_position") == 2,
		"AC2: the exposed policy announces the five-point bite on the Exposed hero")
	var oracle := _rng(18141)
	var bulwark_total := 0
	for raw in NEW["felt_bulwark"].actions:
		bulwark_total += int(raw.weight)
	oracle.randi_range(1, bulwark_total)
	_check(live.rng.state == oracle.state,
		"AC3: binding draws only the Bulwark's one real weighted roll")
	var committed: int = live.rng.state
	var receipt := CombatEnemyPhase.new().execute_phase(party, live.enemies,
		[announced], null, true)
	_check(receipt == {"ok": true, "events": [{"type": "attack",
			"enemy_position": slot, "target_position": 2, "applied": true}]},
		"AC2: the production enemy phase publishes one applied Scribe bite")
	_check(party.get_hero(2).get("block") == 0 and party.get_hero(2).get("hp") == 23,
		"AC2: six Block are eaten first, then the Exposed-adjusted seven reaches HP")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 0
		and party.get_hero(3).get("hp") == 26,
		"AC2: the Scribe's bite touches no other hero")
	_check(live.rng.state == committed and live.scheduler.get_intents() == live.intents,
		"AC3: executing the bite spends no extra run RNG and keeps its announcement")

	# AC2: with no Exposed hero the established fallback keeps the front target,
	# so six Block are eaten and exactly the authentic five reaches HP.
	var fallback_party := _party()
	_check(fallback_party.gain_block(1, 6),
		"AC2 precondition: the front Warden really holds six Block")
	var fallback := _forced_pair(assembled, fallback_party, "moth_scribe", bite)
	if not fallback.is_empty():
		var fallback_slot := _slot_for(fallback.enemies, "moth_scribe")
		var fallback_action := _announced_for(fallback.intents, fallback_slot)
		_check(fallback_action.get("target_position") == 1,
			"AC2: without an Exposed hero the policy falls back to the front slot")
		_check(CombatEnemyPhase.new().execute_phase(fallback_party, fallback.enemies,
			[fallback_action], null, true).get("ok") == true
			and fallback_party.get_hero(1).get("block") == 0
			and fallback_party.get_hero(1).get("hp") == 35,
			"AC2: six Block are eaten first, then exactly the authentic five reaches HP")

	# AC3: the authored Weak 1 never chews the hero's Block or HP.
	var weak_party := _party()
	weak_party._heroes[1]["statuses"] = {"exposed": 1}
	_check(weak_party.gain_block(2, 6),
		"AC3 precondition: six Block before the authentic Weak 1")
	var weak_case := _forced_pair(assembled, weak_party, "moth_scribe", weaken)
	if not weak_case.is_empty():
		var weak_slot := _slot_for(weak_case.enemies, "moth_scribe")
		var weak_receipt := CombatEnemyPhase.new().execute_phase(weak_party,
			weak_case.enemies, [_announced_for(weak_case.intents, weak_slot)], null, true)
		_check(weak_receipt.get("ok") == true
			and weak_receipt.get("events", []).size() == 1
			and weak_receipt["events"][0].get("type") == "debuff"
			and weak_receipt["events"][0].get("target_position") == 2,
			"AC3: the authentic Weak 1 stays a debuff on the Exposed hero")
		_check(weak_party.get_hero(2).get("block") == 6
			and weak_party.get_hero(2).get("hp") == 30
			and weak_party.get_hero(2).get("statuses", {}).get("weak", 0) == 1,
			"AC3: Weak 1 adds its status without chewing Block or HP")

	# AC3: the authored Block 2 never chews; it only grants the Scribe Block.
	var brace_party := _party()
	brace_party._heroes[1]["statuses"] = {"exposed": 1}
	_check(brace_party.gain_block(2, 6),
		"AC3 precondition: six Block before the authentic Block 2")
	var brace_case := _forced_pair(assembled, brace_party, "moth_scribe", brace)
	if not brace_case.is_empty():
		var brace_slot := _slot_for(brace_case.enemies, "moth_scribe")
		var brace_receipt := CombatEnemyPhase.new().execute_phase(brace_party,
			brace_case.enemies, [_announced_for(brace_case.intents, brace_slot)], null, true)
		_check(brace_receipt.get("ok") == true
			and brace_receipt.get("events", []).size() == 1
			and brace_receipt["events"][0].get("type") == "block",
			"AC3: the authentic Block 2 stays a self-Block")
		_check(brace_party.get_hero(2).get("block") == 6
			and brace_party.get_hero(2).get("hp") == 30
			and brace_case.enemies.get_enemy(brace_slot).get("block") == 2,
			"AC3: Block 2 grants the Scribe Block without touching the hero")

	# AC2: the unflagged Felt Bulwark's existing five is absorbed normally.
	var guard_party := _party()
	_check(guard_party.gain_block(1, 6),
		"AC2 precondition: six Block before the Bulwark's ordinary five")
	var bulwark_bite := _pair_action(assembled, "felt_bulwark", "attack", 5)
	_check(not bulwark_bite.is_empty(),
		"AC2 precondition: the real Bulwark authors its five-point attack")
	var guard_case := _forced_pair(assembled, guard_party, "felt_bulwark", bulwark_bite)
	if not guard_case.is_empty():
		var guard_slot := _slot_for(guard_case.enemies, "felt_bulwark")
		var guard_action := _announced_for(guard_case.intents, guard_slot)
		_check(guard_action.get("target_position") == 1,
			"AC2: the unflagged Bulwark announces its ordinary front five")
		_check(CombatEnemyPhase.new().execute_phase(guard_party, guard_case.enemies,
			[guard_action], null, true).get("ok") == true
			and guard_party.get_hero(1).get("hp") == 40
			and guard_party.get_hero(1).get("block") == 1,
			"AC2: an unflagged five is absorbed by six Block, leaving one and full HP")

	# AC3: a copied Scribe without the flag keeps ordinary Block mitigation.
	for mode in ["absent", "false"]:
		var unflagged: Dictionary = scribe.duplicate(true)
		if mode == "absent":
			unflagged.erase("chew_block_on_attack")
		else:
			unflagged["chew_block_on_attack"] = false
		var disabled_party := _party()
		_check(disabled_party.gain_block(1, 6),
			"AC3 precondition: six Block for the unflagged Scribe: " + mode)
		var disabled_case := _forced_pair(assembled, disabled_party, "moth_scribe",
			bite, unflagged)
		if disabled_case.is_empty():
			continue
		var disabled_slot := _slot_for(disabled_case.enemies, "moth_scribe")
		_check(CombatEnemyPhase.new().execute_phase(disabled_party,
			disabled_case.enemies,
			[_announced_for(disabled_case.intents, disabled_slot)], null, true).get("ok") == true
			and disabled_party.get_hero(1).get("block") == 1
			and disabled_party.get_hero(1).get("hp") == 40,
			"AC3: an unflagged Scribe five is absorbed by Block: " + mode)

	# AC3: a slain Scribe's announced bite chews nothing and deals nothing.
	var dead_party := _party()
	dead_party._heroes[1]["statuses"] = {"exposed": 1}
	_check(dead_party.gain_block(2, 6),
		"AC3 precondition: six Block before the slain Scribe's bite")
	var dead_case := _forced_pair(assembled, dead_party, "moth_scribe", bite)
	if not dead_case.is_empty():
		var dead_slot := _slot_for(dead_case.enemies, "moth_scribe")
		var dead_action := _announced_for(dead_case.intents, dead_slot)
		_check(dead_case.enemies.apply_damage(dead_slot, 99999)
			and dead_case.enemies.is_slain(dead_slot),
			"AC3 precondition: the Scribe is genuinely slain before its beat")
		_check(CombatEnemyPhase.new().execute_phase(dead_party, dead_case.enemies,
			[dead_action], null, true) == {"ok": true, "events": [{"type": "attack",
				"enemy_position": dead_slot, "target_position": 2, "applied": false}]},
			"AC3: a slain Scribe's announced bite resolves as one inert beat")
		_check(dead_party.get_hero(2).get("block") == 6
			and dead_party.get_hero(2).get("hp") == 30,
			"AC3: a slain Scribe eats no Block and deals no HP")

	# AC3: identical fixed seed replays the announcement, phase receipt and RNG.
	var replay_party := _party()
	replay_party._heroes[1]["statuses"] = {"exposed": 1}
	_check(replay_party.gain_block(2, 6), "AC3 replay precondition: six Block")
	var replay := _forced_pair(assembled, replay_party, "moth_scribe", bite)
	if not replay.is_empty():
		_check(replay.intents == live.intents and replay.rng.state == committed,
			"AC3: the same seed announces the identical Scribe bite on the same RNG state")
		var replay_slot := _slot_for(replay.enemies, "moth_scribe")
		var replay_receipt := CombatEnemyPhase.new().execute_phase(replay_party,
			replay.enemies, [_announced_for(replay.intents, replay_slot)], null, true)
		_check(replay_receipt == receipt
			and replay_party.get_heroes() == party.get_heroes()
			and replay.enemies.get_enemies() == live.enemies.get_enemies()
			and replay.rng.state == committed,
			"AC3: replaying the seed publishes the same bite and end state")

func _click(button: Control) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(),
		"physical mouse target visible")
	if not is_instance_valid(button) or not button.is_visible_in_tree():
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _mounted(wanted: String = "") -> void:
	# Find a real run seed that picks an M05 candidate from the entire pool,
	# without forcing a test-only entry in the app.
	var fixture := {}
	var ids: Array = pools["Fight"].keys()
	ids.sort()
	for seed_value in range(1, 700):
		var rng := _rng(seed_value)
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var node := _choose_fight(map)
		if node.is_empty():
			continue
		var selected_id: String = ids[rng.randi_range(0, ids.size() - 1)]
		if PAIRS.has(selected_id):
			var group: Array = preload("res://tests/floor_band_oracle.gd").group(
				map.get_current_floor(), PAIRS[selected_id].enemy_ids.size(), rng)
			if not group.any(func(actor_id): return NEW.has(actor_id)):
				continue
			if not wanted.is_empty() and not group.has(wanted):
				continue
			fixture = {"seed": seed_value, "node": node, "encounter": selected_id,
				"group": group, "rng_state": rng.state}
			break
	_check(not fixture.is_empty(), "genuine seeded full Fight rotation reaches new alternative")
	if fixture.is_empty():
		return
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real 1280x720 app scene loads")
	if scene == null:
		return
	root.size = Vector2i(1280, 720)
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.run_seed = fixture.seed
	await _click(app.route_button)
	_check(app.run_map != null and app.run_map.get_route().is_empty(),
		"physical title route opens genuine uncommitted map")
	if app.run_map == null:
		app.free()
		return
	var button: Button
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.node:
			button = candidate
	_check(button != null and app.run_map.get_legal_choices().has(fixture.node),
		"new-pair Fight is reachable by mounted route button")
	if button == null:
		app.free()
		return
	await _click(button)
	for frame in range(3):
		await process_frame
	_check(app.encounter_id == fixture.encounter and app.deck != null
		and app.enemy_intents != null and app.enemy_intents.is_bound()
		and app.enemies != null and app.battle_view != null,
		"actual routed entry mounts selected new pair with weighted intents")
	if app.enemies == null or app.deck == null:
		app.free()
		return
	var presenter = app.get_node("LiveEnemyRoster")
	var expected: Array = fixture.group
	var records: Dictionary = preload("res://tests/floor_band_oracle.gd").records()
	_check(preload("res://tests/floor_band_oracle.gd").legal_group(
		expected, app.run_map.get_current_floor()) and app.encounter_id == fixture.encounter,
		"physical route matches independent shrinking-band roster and run RNG")
	_check(presenter.enemies == app.enemies and presenter._labels.size() == expected.size()
		and presenter._puppets.size() >= CombatParty.PARTY_SIZE + expected.size(),
		"mounted battle owns both real selected enemy puppets")
	var m05_count := 0
	for index in range(expected.size()):
		var actor: Dictionary = app.enemies.get_enemy(index + 1)
		var puppet = presenter._puppets[index + CombatParty.PARTY_SIZE]
		_check(actor.id == expected[index] and puppet.actor_id == expected[index]
			and actor.position == index + 1 and actor.max_hp == int(records[expected[index]].max_hp)
			and actor.hp == actor.max_hp and actor.block == 0
			and puppet.is_visible_in_tree() and puppet.size.x > 0
			and presenter._labels[index].text == records[expected[index]].name,
			"band-selected actor renders its exact catalog ID, HP and name " + expected[index])
		if NEW.has(expected[index]):
			m05_count += 1
			# The mounted actor's own exact ID chooses its imported Art v3 pose pair.
			var id: String = String(actor.id)
			var idle_path := "res://assets/paper/enemies/" + id + ".png"
			var attack_path := "res://assets/paper/enemies/" + id + "_attack.png"
			var art: Dictionary = presenter.art_for(id)
			var idle: Texture2D = art.get("idle") as Texture2D
			var attack: Texture2D = art.get("attack") as Texture2D
			_check(idle is Texture2D and idle.resource_path == idle_path
				and puppet.current_texture() == idle
				and attack is Texture2D and attack != idle
				and attack.resource_path == attack_path and puppet.attack_texture == attack
				and puppet.fallback_kind == id
				and not puppet.fallback_silhouettes().is_empty(),
				"genuine M05 actor shows its imported idle and own attack pose " + id)
			# The identity-specific sewn fallback still exists when the image is
			# unavailable: force empty art on the same mounted puppet, then restore it.
			puppet.bind_actor(id, {})
			_check(puppet.current_texture() == null and puppet.attack_texture == null
				and puppet.fallback_kind == id
				and not puppet.fallback_silhouettes().is_empty(),
				"the same mounted M05 actor falls back to its own sewn silhouette " + id)
			puppet.bind_actor(id, presenter.art_for(id))
	_check(m05_count > 0, "seeded live band group actually contains an M05 normal")
	_check(app.deck.hand.size() == 5 and app.end_turn_button.is_visible_in_tree(),
		"real five-card hand and End Turn reachable at 1280x720")
	# A genuine mounted card remains playable before enemy End Turn.
	var played := false
	for i in range(app.deck.hand.size()):
		var card_id: String = app.deck.hand[i]
		if card_id not in ["warden_strike", "seamstress_prick", "tinker_pop_shot"]:
			continue
		var before := [app.deck.hand.size(), app.deck.energy, app.enemies.get_enemies()]
		await _click(app.hand_view.get_child(i))
		await _click(presenter._labels[0])
		played = app.deck.hand.size() < before[0] and app.deck.energy < before[1]
		if played:
			break
	_check(played, "physical card selection and enemy targeting commits a starter attack")
	var prior_turn: int = app.enemy_intents._turn_index
	var prior_hand: Array = app.deck.hand.duplicate()
	await _click(app.end_turn_button)
	_check(app.enemy_intents._turn_index == prior_turn + 1
		and app.deck.hand.size() == 5 and app.deck.hand != prior_hand,
		"mounted End Turn resolves weighted enemy phase and draws next hand")
	if not wanted.is_empty():
		await _mounted_named_moves(app, presenter, wanted)
	app.free()

## Keep the real route, run RNG, deck, scheduler and mounted presenter. Only
## isolate the admitted source and replenish heroes to witness its next moves.
func _mounted_named_moves(app, presenter, wanted: String) -> void:
	var source := _slot_for(app.enemies, wanted)
	_check(source > 0 and app.enemies.get_enemies().size() <= 3,
		"named mounted precondition: real admitted source in a two/three-enemy Fight")
	if source == 0:
		return
	for actor in app.enemies.get_enemies():
		if actor.position != source:
			_check(app.enemies.apply_damage(actor.position, 99999), "isolate admitted named source")
	var seen := {}
	var names: Array = ["Roll Charge", "Felt Slam"] if wanted == "felt_bulwark" else ["Quill Stab", "Ink Flick"]
	for turn in range(40):
		for hero in app.party._heroes:
			hero.hp = hero.max_hp
			hero.block = 0
			hero.statuses = {}
		app.party._heroes[1].statuses = {"exposed": 2}
		var action := _announced_for(app.enemy_intents.get_intents(), source)
		var move: String = action.get("move", "")
		if move in ["attack2", "attack3"]:
			var index := 0 if move == "attack2" else 1
			var target: int = action.target_position
			_check(target == (1 if wanted == "felt_bulwark" else 2)
				and action.amount == (6 if index == 0 else 7), "mounted named source, amount and policy")
			_check(app.party.gain_block(target, 3), "mounted named recipient has real Block")
			app._refresh_enemy_roster()
			var before: Array = [app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state]
			var pose := LiveMovePoseCatalog.new().lookup_enemy(wanted, action,
				"res://assets/paper/enemies/" + wanted + "_attack.png")
			_check(presenter._badges[source - 1].tooltip_text.contains(names[index])
				and pose.get("name") == names[index] and pose.get("pose") == move,
				"genuine mounted tooltip and pose receipt: " + names[index])
			_check(before == [app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state],
				"mounted named presentation leaves actors and run RNG unchanged")
			if not seen.has(move):
				var cache: Array = app.enemy_intents._cache.duplicate(true)
				var authored: Dictionary = app.enemies._enemies[source - 1].intent.duplicate(true)
				for refusal in ["amount", "move", "stale"]:
					if refusal == "amount":
						app.enemy_intents._cache[source - 1].amount += 1
					elif refusal == "move":
						app.enemy_intents._cache[source - 1].move = "attack4"
					else:
						for raw in app.enemies._enemies[source - 1].intent.actions:
							if raw.get("move") == move:
								raw.amount += 1
					var protected := _named_flow_state(app)
					_check(not app.round_flow.end_turn() and _named_flow_state(app) == protected,
						"real flow refuses named " + refusal + " without party/enemy/deck/wallet/RNG mutation")
					app.enemy_intents._cache.assign(cache.duplicate(true))
					app.enemies._enemies[source - 1].intent = authored.duplicate(true)
			var hp: int = app.party.get_hero(target).hp
			var damage: int = int(action.amount) if wanted == "felt_bulwark" else (9 if index == 0 else 10)
			await _click(app.end_turn_button)
			_check(app.party.get_hero(target).hp == hp - damage + (3 if wanted == "felt_bulwark" else 0)
				and app.party.get_hero(target).block == 0,
				"physical End Turn resolves named damage once with mitigation/chew: " + names[index])
			seen[move] = true
		else:
			await _click(app.end_turn_button)
		if seen.size() == 2:
			break
	_check(seen.has("attack2") and seen.has("attack3"), "both genuine mounted named moves reached: " + wanted)

func _named_flow_state(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state,
		app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.exhausted.duplicate(), app.deck.energy, app.deck.turn_active,
		app.round_flow.get_gold(), app.session_gold, app.enemy_intents.get_intents(), app.enemy_intents._turn_index]

func _run() -> void:
	_catalog_and_bindings()
	if pools is Dictionary and pools.get("Fight") is Dictionary:
		for id in PAIRS:
			var first := _assemble(id, 18141)
			var again := _assemble(id, 18141)
			_check(not first.is_empty() and not again.is_empty(),
				"independent actual selections both succeed " + id)
			if not first.is_empty() and not again.is_empty():
				_check(first.choice == again.choice and first.rng_state == again.rng_state
					and first.floors == again.floors and first.route == again.route
					and first.roster.enemies.get_enemies() == again.roster.enemies.get_enemies(),
					"seeded new Fight route, actor roster and RNG replay " + id)
				_weighted(id, first)
				if id == "felt_moth_pressure":
					_scribe_chew(first)
		await _mounted()
		await _mounted("felt_bulwark")
		await _mounted("moth_scribe")
	if failures.is_empty():
		print("m05_normal_enemy_rotation_test: PASS (", checks, " checks)")
	else:
		for reason in failures:
			printerr(reason)
		printerr("m05_normal_enemy_rotation_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
