extends SceneTree
## Authored-catalog proof for the two harder v3 look-driven normals. This batch is
## data/service-layer content only: the catalog is real, but nothing here claims
## the pair is selectable from the live run map yet.

const PATH := "res://data/enemies/v3_tough_normals.json"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const ELITES_PATH := "res://data/enemies/m04_elites.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_records()
	_test_weighted_alternatives()
	_test_seeded_announcements_and_priority_target()
	_test_forced_shove_and_block()
	_test_forced_statuses_and_attacks()
	_test_fail_closed()
	if failures.is_empty():
		print("v3_tough_normals_catalog_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("v3_tough_normals_catalog_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _norm(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _norm(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_norm(item))
		return result
	if value is float and is_finite(value) and floorf(value) == value \
			and absf(value) <= 9007199254740991.0:
		return int(value)
	return value


## The two records exactly as the brief authors them.
func _expected() -> Dictionary:
	return {
		"spindle_ram": {"id": "spindle_ram", "name": "Spindle Ram", "max_hp": 30,
			"art_path": "res://assets/paper/enemies/spindle_ram.png",
			"intent": {"target": "front", "actions": [
				{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
				{"type": "block", "amount": 7, "weight": 2},
				{"type": "attack", "amount": 8, "weight": 3}]}},
		"razor_ribbon_wraith": {"id": "razor_ribbon_wraith", "name": "Razor Ribbon Wraith",
			"max_hp": 27, "revive_once": true, "art_path": "res://assets/paper/enemies/razor_ribbon_wraith.png",
			"intent": {"target": "lowest_living_hp", "actions": [
				{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
				{"type": "debuff", "status": "exposed", "amount": 1, "weight": 1},
				{"type": "attack", "amount": 9, "weight": 3}]}}
	}


func _load() -> Array:
	return RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(PATH))


func _find(records: Array, id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and record.get("id") == id:
			return record.duplicate(true)
	return {}


func _without_weight(raw: Dictionary) -> Dictionary:
	var body := {}
	for key in raw:
		if key != "weight":
			body[key] = raw[key]
	return body


func _contains_weighted(actions: Array, body: Dictionary, weight: int) -> bool:
	for raw in actions:
		if not raw is Dictionary or int(raw.get("weight", 0)) != weight:
			continue
		if _norm(_without_weight(raw)) == _norm(body):
			return true
	return false


## The genuine authored alternative of one kind/amount (and status, when given).
func _authored(record: Dictionary, kind: String, amount: int, status: String = "") -> Dictionary:
	var spec: Variant = record.get("intent")
	if not spec is Dictionary:
		return {}
	var actions: Variant = spec.get("actions")
	if not actions is Array:
		return {}
	for raw in actions:
		if not raw is Dictionary or raw.get("type") != kind \
				or int(raw.get("amount", -1)) != amount:
			continue
		if status.is_empty() or raw.get("status") == status:
			return raw.duplicate(true)
	return {}


## The authentic record bound to exactly one of its own alternatives, so an
## executed beat never depends on a lucky weighted roll.
func _single_alternative(source: Dictionary, raw: Dictionary) -> Dictionary:
	var normalized := CombatEnemyIntents.weighted_action(raw)
	_check(not normalized.is_empty(), "forced alternative is a valid authored action: " + str(raw))
	if normalized.is_empty() or source.is_empty():
		return {}
	var record: Dictionary = source.duplicate(true)
	var action: Dictionary = normalized["action"].duplicate(true)
	action["weight"] = 1
	record["intent"] = {"target": source.get("intent", {}).get("target"), "actions": [action]}
	return record


func _enemy(position: int, pattern: Array) -> Dictionary:
	return {"enemy_position": position, "pattern": pattern}


func _party() -> CombatParty:
	return CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])


## Bind genuine records to a real scheduler and the run's single seeded generator.
func _bind_records(records: Array, party: CombatParty, seed_value: int) -> Dictionary:
	var enemies := CombatEnemies.new(records.duplicate(true))
	var definitions: Array = []
	for index in range(records.size()):
		definitions.append(_enemy(index + 1, [{"type": "block", "amount": 1}]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scheduler := CombatEnemyIntents.new(definitions)
	var bound := enemies.is_valid() and scheduler.bind_battle(enemies, party, rng)
	_check(bound, "the authentic roster binds weighted intentions")
	if not bound:
		return {}
	return {"ok": true, "enemies": enemies, "scheduler": scheduler,
		"intents": scheduler.get_intents(), "rng": rng}


## Hero state that a swap must not disturb, keyed by identity rather than slot.
func _signature(party: CombatParty) -> Dictionary:
	var result := {}
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		var hero := party.get_hero(position)
		result[String(hero.get("id", ""))] = {"hp": hero.get("hp"), "block": hero.get("block"),
			"statuses": hero.get("statuses", {})}
	return result


func _positions(party: CombatParty) -> Array:
	var ids: Array = []
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		ids.append(party.get_hero(position).get("id"))
	return ids


func _announcements_for(bound: Dictionary, source: int) -> Array:
	var intents: Array = []
	for intent in bound.get("intents", []):
		if intent.get("enemy_position") == source:
			intents.append(intent)
	return intents


## True when the announcement body is one of the record's authored alternatives.
func _is_authored_alternative(record: Dictionary, announced: Dictionary) -> bool:
	var spec: Variant = record.get("intent")
	if not spec is Dictionary:
		return false
	var body: Dictionary = {}
	for key in announced:
		if key in ["enemy_position", "target_position"]:
			continue
		body[key] = announced[key]
	var actions: Variant = spec.get("actions")
	if not actions is Array:
		return false
	for raw in actions:
		if raw is Dictionary and _norm(_without_weight(raw)) == _norm(body):
			return true
	return false


func _test_catalog_records() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	_check(not text.is_empty(), "v3_tough_normals.json is readable")
	var parsed := RunTypedBattleRoster._parse_catalog_text(text)
	_check(parsed.size() == 2, "the strict catalog parser accepts exactly the two new records")
	if parsed.size() != 2:
		return
	var expected := _expected()
	var ids: Array[String] = []
	for record in parsed:
		ids.append(String(record.get("id", "")))
	for id in expected:
		var occurrences := 0
		for present in ids:
			if present == String(id):
				occurrences += 1
		_check(occurrences == 1, "exactly one record for " + String(id))
		var record := _find(parsed, String(id))
		_check(not record.is_empty(), "record present: " + String(id))
		if record.is_empty():
			continue
		_check(_norm(record) == _norm(expected[id]),
			"record has its exact authored fields: " + String(id))
		_check(record.get("name") == expected[id]["name"], "name is authored: " + String(id))
		_check(record.get("max_hp") is int and record.get("max_hp") == expected[id]["max_hp"],
			"max_hp is a genuine int: " + String(id))
		_check(record.get("art_path") == expected[id]["art_path"],
			"art_path is authored: " + String(id))
		var spec: Variant = record.get("intent")
		_check(spec is Dictionary and spec.get("target") == expected[id]["intent"]["target"],
			"target policy is authored: " + String(id))
	for present in ids:
		_check(expected.has(present), "no unexpected record in the new catalog: " + present)
	_check(_find(parsed, "spindle_ram").get("art_path")
		!= _find(parsed, "razor_ribbon_wraith").get("art_path"),
		"the two enemies carry distinct art paths")
	# Building genuine actors must not touch the authored source in any way.
	var roster: Array = []
	for id in expected:
		roster.append(_find(parsed, String(id)))
	var enemies := CombatEnemies.new(roster)
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"a valid two-enemy CombatEnemies is built from both records")
	var ram: Dictionary = enemies.get_enemy(1)
	_check(ram.get("id") == "spindle_ram" and ram.get("max_hp") == 30 and ram.get("hp") == 30
		and ram.get("block") == 0 and ram.get("position") == 1,
		"the front slot actor is the Ram at its authored 30 HP and zero Block")
	var wraith: Dictionary = enemies.get_enemy(2)
	_check(wraith.get("id") == "razor_ribbon_wraith" and wraith.get("max_hp") == 27
		and wraith.get("hp") == 27 and wraith.get("block") == 0 and wraith.get("position") == 2,
		"slot 2 actor is the Wraith at its authored 27 HP and zero Block")
	_check(FileAccess.get_file_as_string(PATH) == text,
		"constructing the roster leaves the source JSON byte-identical")
	var reread := _load()
	_check(_norm(reread) == _norm(parsed),
		"re-reading the catalog returns the same authored records")
	for record in reread:
		_check(not record.has("hp") and not record.has("block") and not record.has("position"),
			"the parsed source never gains mutable battle state: " + String(record.get("id", "")))
	# The accepted shared catalogs are untouched by this batch: this file is new
	# and separate, so only their stable authored identity is re-checked here.
	var run_parsed := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(RUN_ENEMIES_PATH))
	_check(not run_parsed.is_empty(), "the existing run enemy catalog still parses")
	var scavenger := _find(run_parsed, "fray_scavenger")
	_check(scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14,
		"the earlier run catalog entry fray_scavenger is unchanged")
	var elite_parsed := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(ELITES_PATH))
	_check(not elite_parsed.is_empty(), "the existing elite catalog still parses")
	var marshal := _find(elite_parsed, "needle_marshal")
	_check(marshal.get("name") == "Needle Marshal" and marshal.get("max_hp") == 28,
		"the accepted elite entry needle_marshal is unchanged")


func _test_weighted_alternatives() -> void:
	var parsed := _load()
	var expected := _expected()
	for id in expected:
		var record := _find(parsed, String(id))
		_check(not record.is_empty(), "weighted source present: " + String(id))
		if record.is_empty():
			continue
		var spec: Variant = record.get("intent")
		var slot := CombatEnemyIntents._weighted_slot(1, spec)
		_check(not slot.is_empty(), "authored intent validates as a weighted slot: " + String(id))
		if slot.is_empty():
			continue
		_check(slot.get("target") == expected[id]["intent"]["target"],
			"weighted slot keeps the authored target policy: " + String(id))
		var actual: Array = []
		for entry in slot.get("actions", []):
			actual.append(_norm(entry))
			_check(int(entry.get("weight", 0)) > 0,
				"every alternative has a positive weight: " + String(id))
		var wanted: Array = []
		for raw in expected[id]["intent"]["actions"]:
			wanted.append(_norm({"weight": raw["weight"], "action": _without_weight(raw)}))
		_check(actual == wanted,
			"the weighted slot holds exactly the authored alternatives: " + String(id))
		for raw in record["intent"]["actions"]:
			var direct := CombatEnemyIntents.weighted_action(raw)
			_check(not direct.is_empty(),
				"weighted_action accepts the authored alternative: %s %s" % [String(id), str(raw)])
			if direct.is_empty():
				continue
			_check(int(direct.get("weight", 0)) == int(raw.get("weight", -1)),
				"weighted_action keeps the authored weight: " + String(id))
			_check(_norm(direct.get("action", {})) == _norm(_without_weight(raw)),
				"weighted_action keeps the exact action body: " + String(id))
	# The exact look-driven signatures of this batch, named one by one.
	var ram_actions: Array = _find(parsed, "spindle_ram").get("intent", {}).get("actions", [])
	_check(_contains_weighted(ram_actions, {"type": "shove", "amount": 0, "direction": 1}, 2),
		"Spindle Ram announces its +1 shove with weight 2")
	_check(_contains_weighted(ram_actions, {"type": "block", "amount": 7}, 2),
		"Spindle Ram pads 7 Block with weight 2")
	_check(_contains_weighted(ram_actions, {"type": "attack", "amount": 8}, 3),
		"Spindle Ram rams for 8 with weight 3")
	var wraith_actions: Array = _find(parsed, "razor_ribbon_wraith").get("intent", {}).get("actions", [])
	_check(_contains_weighted(wraith_actions, {"type": "debuff", "status": "bleed", "amount": 2}, 2),
		"Razor Ribbon Wraith rips Bleed 2 with weight 2")
	_check(_contains_weighted(wraith_actions, {"type": "debuff", "status": "exposed", "amount": 1}, 1),
		"Razor Ribbon Wraith opens Exposed 1 with weight 1")
	_check(_contains_weighted(wraith_actions, {"type": "attack", "amount": 9}, 3),
		"Razor Ribbon Wraith slashes for 9 with weight 3")
	_check(_find(parsed, "razor_ribbon_wraith").get("intent", {}).get("target")
		== "lowest_living_hp", "Razor Ribbon Wraith hunts the lowest-living hero")
	_check(_find(parsed, "spindle_ram").get("intent", {}).get("target") == "front",
		"Spindle Ram always charges the front hero")


func _test_seeded_announcements_and_priority_target() -> void:
	var source_text := FileAccess.get_file_as_string(PATH)
	var parsed := _load()
	var snapshot: Variant = _norm(parsed)
	var ram := _find(parsed, "spindle_ram")
	var wraith := _find(parsed, "razor_ribbon_wraith")
	_check(not ram.is_empty() and not wraith.is_empty(),
		"precondition: both authentic records load for the seeded fight")
	if ram.is_empty() or wraith.is_empty():
		return
	var party := _party()
	_check(party.is_valid() and party.get_heroes().size() == CombatParty.PARTY_SIZE,
		"precondition: a genuine three-hero CombatParty")
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		_check(party.get_hero(position).get("hp", 0) > 0,
			"precondition: hero slot %d is living" % position)
	var first := _bind_records([ram, wraith], party, 1792)
	var second := _bind_records([ram, wraith], _party(), 1792)
	_check(not first.is_empty() and not second.is_empty(),
		"the authentic pair binds on identical seeds")
	if first.is_empty() or second.is_empty():
		return
	_check(first.intents.size() == 2, "the pair announces once per enemy slot")
	_check(first.intents == second.intents, "same-seed announcements replay identically")
	_check(first.rng.state == second.rng.state,
		"same-seed bindings leave matching run RNG state")
	var state_before: int = first.rng.state
	_check(first.scheduler.get_intents() == first.intents and first.rng.state == state_before,
		"reading bound announcements neither changes them nor consumes RNG")
	_check(first.scheduler.advance_turn() and second.scheduler.advance_turn(),
		"both seeded fights advance a turn")
	_check(first.scheduler.get_intents() == second.scheduler.get_intents(),
		"successive announcements replay identically on equal seeds")
	_check(first.rng.state == second.rng.state,
		"advancing keeps matching run RNG state")
	for index in range(first.intents.size()):
		var announced: Dictionary = first.intents[index]
		var source: Dictionary = [ram, wraith][index]
		var enemy_id := String(source.get("id", ""))
		_check(announced.get("enemy_position") == index + 1,
			"announcement keeps its original source slot: " + enemy_id)
		_check(_is_authored_alternative(source, announced),
			"announcement is one of the authored alternatives: " + enemy_id)
		if announced.get("type") in ["attack", "debuff", "shove"]:
			var policy := String(source.get("intent", {}).get("target", ""))
			_check(announced.get("target_position")
				== CombatEnemyIntents.priority_target(party, policy),
				"announcement applies the authored target policy: " + enemy_id)
	var advance: Array = first.scheduler.get_intents()
	for index in range(advance.size()):
		var advanced_source: Dictionary = [ram, wraith][index]
		_check(_is_authored_alternative(advanced_source, advance[index]),
			"the advanced announcement is still authored: "
				+ String(advanced_source.get("id", "")))
	_check(_norm(_load()) == snapshot,
		"binding, reading and advancing never mutate the source records")
	_check(FileAccess.get_file_as_string(PATH) == source_text,
		"the whole fight leaves the catalog source JSON byte-identical")

	# Priority target: a damaged Tinker becomes the unique lowest living hero.
	var weakened := _party()
	_check(weakened.apply_damage(3, 10), "precondition: the back hero really loses HP")
	_check(weakened.get_hero(3).get("hp") == 16 and weakened.get_hero(1).get("hp") == 40
		and weakened.get_hero(2).get("hp") == 30,
		"precondition: the Tinker is the unique lowest-living hero")
	_check(CombatEnemyIntents.priority_target(weakened, "lowest_living_hp") == 3,
		"the authored policy selects the damaged living Tinker")
	_check(weakened.get_hero(3).get("position") == 3,
		"precondition: the damaged Tinker really stands in living slot 3")
	var bleed_record := _single_alternative(wraith, _authored(wraith, "debuff", 2, "bleed"))
	_check(not bleed_record.is_empty(), "the authentic Wraith Bleed 2 alternative is present")
	var bound := _bind_records([bleed_record], weakened, 1792)
	_check(not bound.is_empty(), "the forced Wraith debuff fight binds")
	if bound.is_empty():
		return
	var announced: Dictionary = bound.intents[0]
	_check(announced.get("type") == "debuff" and announced.get("status") == "bleed"
		and int(announced.get("amount", -1)) == 2,
		"the Wraith announces its authored Bleed 2")
	_check(announced.get("target_position") == 3,
		"the Wraith announces against the lowest-living living slot")


func _test_forced_shove_and_block() -> void:
	var parsed := _load()
	var ram := _find(parsed, "spindle_ram")
	var wraith := _find(parsed, "razor_ribbon_wraith")
	_check(not ram.is_empty() and not wraith.is_empty(),
		"precondition: both authentic records load for the phase checks")
	if ram.is_empty() or wraith.is_empty():
		return
	# Spindle Ram: the crossed spindle horns ram the front hero into the next spot.
	var shove_party := _party()
	_check(shove_party.get_hero(1).get("id") == "warden"
		and shove_party.get_hero(2).get("id") == "seamstress"
		and shove_party.get_hero(3).get("id") == "tinker",
		"precondition: slots hold Warden, Seamstress then Tinker")
	var shove_before := _signature(shove_party)
	var shove_record := _single_alternative(ram, _authored(ram, "shove", 0))
	var shove := _bind_records([shove_record], shove_party, 331)
	_check(not shove.is_empty(), "the forced Ram shove fight binds")
	if not shove.is_empty():
		var announced: Dictionary = shove.intents[0]
		_check(announced.get("type") == "shove" and announced.get("target_position") == 1
			and announced.get("direction") == 1,
			"the Ram announces a legal +1 shove from the front hero")
		_check(CombatEnemyIntents.shove_is_legal(shove_party, 1, 1),
			"precondition: the announced +1 shove is legal")
		var receipt := CombatEnemyPhase.new().execute_phase(shove_party, shove.enemies,
			shove.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced Ram shove resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "shove" and event.get("applied") == true
				and event.get("target_position") == 1 and event.get("direction") == 1,
				"the phase reports the applied +1 shove")
		_check(shove_party.get_hero(1).get("id") == "seamstress"
			and shove_party.get_hero(1).get("position") == 1,
			"the Ram rams the Seamstress into slot 1")
		_check(shove_party.get_hero(2).get("id") == "warden"
			and shove_party.get_hero(2).get("position") == 2,
			"the Warden is pushed back into slot 2")
		_check(shove_party.get_hero(3).get("id") == "tinker"
			and shove_party.get_hero(3).get("position") == 3,
			"the untouched back slot keeps its hero and position")
		_check(_signature(shove_party) == shove_before,
			"the swap changes only the two hero positions, never HP, Block or status")
	# Spindle Ram: the padded wool body gains 7 Block on its own sheet only.
	var block_party := _party()
	var block_before := _signature(block_party)
	var block_record := _single_alternative(ram, _authored(ram, "block", 7))
	var blocked := _bind_records([block_record, wraith], block_party, 331)
	_check(not blocked.is_empty(), "the forced Ram Block fight binds beside the authentic Wraith")
	if not blocked.is_empty():
		var ram_intents := _announcements_for(blocked, 1)
		_check(ram_intents.size() == 1 and ram_intents[0].get("type") == "block"
			and int(ram_intents[0].get("amount", -1)) == 7,
			"the Ram announces its authored 7 Block")
		var receipt := CombatEnemyPhase.new().execute_phase(block_party, blocked.enemies,
			ram_intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced Ram Block resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "block" and event.get("applied") == true
				and event.get("enemy_position") == 1,
				"the phase reports the applied self Block")
		_check(blocked.enemies.get_enemy(1).get("block") == 7,
			"the Ram really holds its 7 Block")
		_check(blocked.enemies.get_enemy(1).get("hp") == 30,
			"the Ram keeps its authored 30 HP")
		_check(blocked.enemies.get_enemy(2).get("block") == 0
			and blocked.enemies.get_enemy(2).get("hp") == 27,
			"the allied Wraith gains no Block and loses no HP")
		_check(_signature(block_party) == block_before,
			"a self Block never changes any hero")
	# A shove whose announced neighbour fell before the beat stays inert.
	var inert_party := _party()
	var inert := _bind_records([_single_alternative(ram, _authored(ram, "shove", 0))],
		inert_party, 332)
	_check(not inert.is_empty(), "the dead-neighbour shove control binds against a full party")
	if not inert.is_empty():
		_check(inert.intents[0].get("target_position") == 1
			and inert.intents[0].get("direction") == 1,
			"the control announces the legal +1 shove before the neighbour falls")
		_check(inert_party.apply_damage(2, 30) and inert_party.is_downed(2),
			"precondition: the middle hero really falls before the enemy beat")
		var inert_before := _signature(inert_party)
		var inert_positions := _positions(inert_party)
		var receipt := CombatEnemyPhase.new().execute_phase(inert_party, inert.enemies,
			inert.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"a shove into a downed neighbour stays a reported beat")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "shove" and event.get("applied") == false,
				"the dead-neighbour shove does not apply")
		_check(_signature(inert_party) == inert_before,
			"the inert shove leaks no HP, Block or status")
		_check(_positions(inert_party) == inert_positions,
			"the inert shove moves nobody")
		_check(inert.enemies.get_enemy(1).get("block") == 0
			and inert.enemies.get_enemy(1).get("hp") == 30,
			"the inert shove leaves the Ram untouched")


func _test_forced_statuses_and_attacks() -> void:
	var parsed := _load()
	var ram := _find(parsed, "spindle_ram")
	var wraith := _find(parsed, "razor_ribbon_wraith")
	_check(not ram.is_empty() and not wraith.is_empty(),
		"precondition: both authentic records load for the resolved beats")
	if ram.is_empty() or wraith.is_empty():
		return
	# Razor Ribbon Wraith: the sharp hem rips Bleed into the announced hero only.
	var bleed_party := _party()
	_check(bleed_party.apply_damage(3, 10), "precondition: the Tinker really takes damage")
	_check(bleed_party.get_hero(3).get("hp") == 16,
		"precondition: the Tinker is the lowest living hero")
	var bleed_record := _single_alternative(wraith, _authored(wraith, "debuff", 2, "bleed"))
	var bleed := _bind_records([bleed_record], bleed_party, 551)
	_check(not bleed.is_empty(), "the forced Wraith Bleed fight binds")
	if not bleed.is_empty():
		var announced: Dictionary = bleed.intents[0]
		_check(announced.get("type") == "debuff" and announced.get("status") == "bleed"
			and announced.get("target_position") == 3,
			"the Wraith announces Bleed 2 on the damaged living hero")
		var receipt := CombatEnemyPhase.new().execute_phase(bleed_party, bleed.enemies,
			bleed.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced Wraith Bleed resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "debuff" and event.get("applied") == true
				and event.get("status") == "bleed" and event.get("target_position") == 3,
				"the phase reports the applied Bleed mark")
		_check(bleed_party.get_hero(3).get("statuses", {}).get("bleed", 0) == 2,
			"the Wraith's Bleed 2 lands on the announced hero")
		for position in [1, 2]:
			_check(bleed_party.get_hero(position).get("statuses", {}).get("bleed", 0) == 0,
				"unaffected hero %d gains no Bleed" % position)
		_check(bleed_party.get_hero(1).get("hp") == 40 and bleed_party.get_hero(2).get("hp") == 30
			and bleed_party.get_hero(3).get("hp") == 16,
			"the Bleed 2 mark costs no hero HP this beat")
		_check(bleed_party.get_hero(1).get("block") == 0
			and bleed_party.get_hero(2).get("block") == 0
			and bleed_party.get_hero(3).get("block") == 0,
			"the Bleed 2 mark changes no hero Block")
	# Razor Ribbon Wraith: the exposed seams are one Exposed counter on the same hero.
	var exposed_party := _party()
	_check(exposed_party.apply_damage(3, 10), "precondition: the Tinker really takes damage")
	var exposed_record := _single_alternative(wraith, _authored(wraith, "debuff", 1, "exposed"))
	var exposed := _bind_records([exposed_record], exposed_party, 552)
	_check(not exposed.is_empty(), "the forced Wraith Exposed fight binds")
	if not exposed.is_empty():
		_check(exposed.intents[0].get("status") == "exposed"
			and int(exposed.intents[0].get("amount", -1)) == 1
			and exposed.intents[0].get("target_position") == 3,
			"the Wraith announces Exposed 1 on the damaged living hero")
		var receipt := CombatEnemyPhase.new().execute_phase(exposed_party, exposed.enemies,
			exposed.intents, null, true)
		_check(receipt.get("ok") == true, "the announced Wraith Exposed resolves")
		_check(exposed_party.get_hero(3).get("statuses", {}).get("exposed", 0) == 1,
			"the Wraith's Exposed 1 lands on the announced hero")
		for position in [1, 2]:
			_check(exposed_party.get_hero(position).get("statuses", {}).get("exposed", 0) == 0,
				"unaffected hero %d gains no Exposed" % position)
		_check(exposed_party.get_hero(3).get("hp") == 16,
			"the Exposed mark costs the target no HP")
	# Spindle Ram: its 8-point charge is absorbed by Block before HP.
	var ram_attack_party := _party()
	_check(ram_attack_party.gain_block(1, 5),
		"precondition: the front hero really holds five Block")
	var ram_attack := _bind_records([_single_alternative(ram, _authored(ram, "attack", 8))],
		ram_attack_party, 553)
	_check(not ram_attack.is_empty(), "the forced Ram attack fight binds")
	if not ram_attack.is_empty():
		_check(ram_attack.intents[0].get("type") == "attack"
			and int(ram_attack.intents[0].get("amount", -1)) == 8
			and ram_attack.intents[0].get("target_position") == 1,
			"the Ram announces its authored 8 damage on the front hero")
		var receipt := CombatEnemyPhase.new().execute_phase(ram_attack_party, ram_attack.enemies,
			ram_attack.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced 8-damage charge resolves through a real CombatEnemyPhase")
		if receipt.get("ok", false) and receipt.get("events", []).size() == 1:
			var event: Dictionary = receipt["events"][0]
			_check(event.get("type") == "attack" and event.get("applied") == true
				and event.get("target_position") == 1,
				"the phase reports the applied front charge")
		_check(ram_attack_party.get_hero(1).get("block") == 0,
			"the front hero spends all five Block on the charge")
		_check(ram_attack_party.get_hero(1).get("hp") == 37,
			"only the unabsorbed three damage reaches the front hero")
		_check(ram_attack_party.get_hero(2).get("hp") == 30
			and ram_attack_party.get_hero(3).get("hp") == 26,
			"the Ram charge touches no other hero")
	# Razor Ribbon Wraith: its 9-point slash also passes through hero Block first.
	var wraith_attack_party := _party()
	_check(wraith_attack_party.apply_damage(3, 10),
		"precondition: the back hero really loses HP")
	_check(wraith_attack_party.gain_block(3, 4),
		"precondition: the lowest living hero really holds four Block")
	var wraith_attack := _bind_records(
		[_single_alternative(wraith, _authored(wraith, "attack", 9))], wraith_attack_party, 554)
	_check(not wraith_attack.is_empty(), "the forced Wraith attack fight binds")
	if not wraith_attack.is_empty():
		_check(wraith_attack.intents[0].get("type") == "attack"
			and int(wraith_attack.intents[0].get("amount", -1)) == 9
			and wraith_attack.intents[0].get("target_position") == 3,
			"the Wraith announces its authored 9 damage on the lowest living hero")
		var receipt := CombatEnemyPhase.new().execute_phase(wraith_attack_party,
			wraith_attack.enemies, wraith_attack.intents, null, true)
		_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1,
			"the announced 9-damage slash resolves through a real CombatEnemyPhase")
		_check(wraith_attack_party.get_hero(3).get("block") == 0,
			"the back hero spends all four Block on the slash")
		_check(wraith_attack_party.get_hero(3).get("hp") == 11,
			"only the unabsorbed five damage reaches the back hero")
		_check(wraith_attack_party.get_hero(1).get("hp") == 40
			and wraith_attack_party.get_hero(2).get("hp") == 30,
			"the Wraith slash touches no other hero")


func _test_fail_closed() -> void:
	var parsed := _load()
	var ram := _find(parsed, "spindle_ram")
	_check(not ram.is_empty(), "precondition: the authentic Ram record loads for the controls")
	if ram.is_empty():
		return
	var attack_raw := _authored(ram, "attack", 8)
	var block_raw := _authored(ram, "block", 7)
	_check(not attack_raw.is_empty() and not block_raw.is_empty(),
		"precondition: the authentic attack and Block alternatives exist")
	var block_action: Dictionary = CombatEnemyIntents.weighted_action(block_raw).get("action", {})
	_check(not block_action.is_empty(), "precondition: the Block alternative normalizes")

	# One genuine announcement succeeds first, so the duplicate below is not vacuous.
	var solo_party := _party()
	var solo := _bind_records([_single_alternative(ram, attack_raw)], solo_party, 611)
	_check(not solo.is_empty() and solo.intents.size() == 1,
		"the single-source bind succeeds before the duplicate-source control")
	if solo.is_empty() or solo.intents.size() != 1 or block_action.is_empty():
		return
	var applied := CombatEnemyPhase.new().execute_phase(solo_party, solo.enemies,
		solo.intents, null, true)
	_check(applied.get("ok") == true and applied.get("events", []).size() == 1,
		"one valid announcement really resolves before the duplicate control")
	var duplicate_intents: Array = [solo.intents[0].duplicate(true)]
	var second_source: Dictionary = block_action.duplicate(true)
	second_source["enemy_position"] = 1
	duplicate_intents.append(second_source)
	var enemy_before: Array = solo.enemies.get_enemies()
	var hero_before := _signature(solo_party)
	var rejected := CombatEnemyPhase.new().execute_phase(solo_party, solo.enemies,
		duplicate_intents, null, true)
	_check(rejected.get("ok") == false and rejected.get("events", []).is_empty(),
		"two announcements from one enemy source fail closed")
	_check(solo.enemies.get_enemies() == enemy_before,
		"the duplicate-source failure publishes no enemy mutation")
	_check(_signature(solo_party) == hero_before,
		"the duplicate-source failure publishes no hero mutation")

	# An unauthored extra key on an otherwise valid action fails closed too.
	var bad_party := _party()
	var bad := _bind_records([_single_alternative(ram, attack_raw)], bad_party, 612)
	_check(not bad.is_empty(), "the invalid-action control binds")
	if not bad.is_empty():
		var bad_intent: Dictionary = bad.intents[0].duplicate(true)
		bad_intent["weight"] = 3
		var bad_enemies_before: Array = bad.enemies.get_enemies()
		var bad_heroes_before := _signature(bad_party)
		var bad_receipt := CombatEnemyPhase.new().execute_phase(bad_party, bad.enemies,
			[bad_intent], null, true)
		_check(bad_receipt.get("ok") == false and bad_receipt.get("events", []).is_empty(),
			"an action carrying an unauthored key fails closed")
		_check(bad.enemies.get_enemies() == bad_enemies_before,
			"the invalid action publishes no enemy mutation")
		_check(_signature(bad_party) == bad_heroes_before,
			"the invalid action publishes no hero mutation")
		# A source outside this one-enemy roster also fails closed and publishes nothing.
		var stray: Dictionary = bad.intents[0].duplicate(true)
		stray["enemy_position"] = 2
		var stray_receipt := CombatEnemyPhase.new().execute_phase(bad_party, bad.enemies,
			[stray], null, true)
		_check(stray_receipt.get("ok") == false and stray_receipt.get("events", []).is_empty(),
			"an announcement from a source outside the roster fails closed")
		_check(bad.enemies.get_enemies() == bad_enemies_before
			and _signature(bad_party) == bad_heroes_before,
			"the out-of-roster source publishes no mutation")
