extends RefCounted
## Independent, executable oracle for the original M01 starter fight: the real
## authored party, enemy roster, deck and weighted intent scheduler on a separate
## seeded generator. Mounted tests compare the app against these rules instead of
## one hard-coded passive enemy action, so an authored intent change cannot make
## a legacy expectation look like live behavior.

const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/starter_enemies.json"
const DECK_PATH := "res://data/cards/starter_deck.json"
const SCHEDULE_PATH := "res://data/encounters/starter_attacks.json"
const OPENING_BLOCK := 6


## Rebuild the run's opening exactly: deck shuffle, authored weighted bind, then
## cleared Block, one-shot Warden Block and the first dealt hand.
static func build(seed_value: int) -> Dictionary:
	var failure := {"ok": false}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var party_records := _records(PARTY_PATH)
	var enemy_records := _records(ENEMIES_PATH)
	var deck_ids: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var definitions := RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(SCHEDULE_PATH))
	if party_records.is_empty() or enemy_records.is_empty() \
			or not deck_ids is Array or definitions.is_empty():
		return failure
	var cards: Array[String] = []
	cards.assign(deck_ids)
	var deck := CombatDeck.new(cards, rng)
	var party := CombatParty.new(party_records)
	var enemies := CombatEnemies.new(enemy_records)
	var intents := CombatEnemyIntents.new(definitions)
	if not party.is_valid() or not enemies.is_valid() or not intents.is_valid() \
			or not intents.bind_battle(enemies, party, rng):
		return failure
	if not deck.start_turn() or not party.start_player_turn() \
			or not party.gain_block(1, OPENING_BLOCK):
		return failure
	return {"ok": true, "rng": rng, "deck": deck, "party": party,
		"enemies": enemies, "intents": intents}


## One authoritative End Turn on the oracle: hero owner tick, close the hand,
## execute the cached phase, enemy owner tick, then advance announcements and
## open the next hand exactly like CombatRoundFlow.
static func end_turn(context: Dictionary) -> bool:
	if not context.get("ok", false):
		return false
	var party: CombatParty = context["party"]
	var enemies: CombatEnemies = context["enemies"]
	var deck: CombatDeck = context["deck"]
	var intents: CombatEnemyIntents = context["intents"]
	var batch := CombatStatusTurnBatch.new()
	var hero_tick := batch.tick_side("heroes", party.get_heroes())
	var enemy_preflight := batch.tick_side("enemies", enemies.get_enemies())
	if not hero_tick["ok"] or not enemy_preflight["ok"]:
		return false
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = party._heroes[index]
		var next: Dictionary = hero_tick["actors"][index]
		hero["hp"] = next["hp"]
		hero["block"] = next["block"]
		if hero.has("statuses") or not next["statuses"].is_empty():
			hero["statuses"] = next["statuses"]
	deck.end_turn()
	var phase := CombatEnemyPhase.new().execute_phase(party, enemies,
		intents.get_intents(), null, intents.is_bound())
	if not phase["ok"]:
		return false
	var enemy_tick := batch.tick_side("enemies", enemies.get_enemies())
	if not enemy_tick["ok"]:
		return false
	for index in range(enemies._enemies.size()):
		var enemy: Dictionary = enemies._enemies[index]
		var next: Dictionary = enemy_tick["actors"][index]
		enemy["hp"] = next["hp"]
		enemy["block"] = next["block"]
		if enemy.has("statuses") or not next["statuses"].is_empty():
			enemy["statuses"] = next["statuses"]
	if party.is_defeated() or enemies.is_victorious():
		return true
	intents.advance_turn()
	party.start_player_turn()
	deck.start_turn()
	return true


## The mounted hidden intent label for one cached announcement batch.
static func intent_text(announcements: Array, hero_names: Array) -> String:
	var clauses := PackedStringArray()
	for action in announcements:
		var clause := intent_clause(action, hero_names)
		if not clause.is_empty():
			clauses.append(clause)
	return "Intent: " + ("none" if clauses.is_empty() else "; ".join(clauses))


## One source's clause in the committed live intent label.
static func intent_clause(action: Dictionary, hero_names: Array) -> String:
	if not action is Dictionary:
		return ""
	var source := int(action.get("enemy_position", 0))
	var amount := int(action.get("amount", 0))
	var target := int(action.get("target_position", 0))
	match String(action.get("type", "")):
		"attack":
			var hero_name := ""
			if target >= 1 and target <= hero_names.size():
				hero_name = String(hero_names[target - 1])
			return "Enemy %d -> Hero %d (%s): %d damage" % [source, target, hero_name, amount]
		"block":
			return "Enemy %d: %d Block" % [source, amount]
		"buff":
			return "Enemy %d: Buff +%d Block" % [source, amount]
		"debuff":
			return "Enemy %d -> Hero %d: %s %d" % [source, target,
				String(action.get("status", "")).capitalize(), amount]
		"shove":
			return "Enemy %d: Shove Hero %d %s" % [source, target,
				"back" if int(action.get("direction", 0)) == 1 else "front"]
	return ""


## The authored Guard Ragling's own alternatives: Block 5, a right shield rush
## or a real six-point hit. Never a fixed passive Block.
static func is_authored_guard_action(action: Dictionary) -> bool:
	if not action is Dictionary:
		return false
	var target = action.get("target_position")
	match String(action.get("type", "")):
		"block":
			return int(action.get("amount", 0)) == 5 and not action.has("target_position")
		"shove":
			return int(action.get("amount", -1)) == 0 \
				and int(action.get("direction", 0)) == 1 and target in [1, 2, 3]
		"attack":
			return int(action.get("amount", 0)) == 6 and target in [1, 2, 3]
	return false


## The Guard's action in one cached batch, or {} when the batch has none.
static func guard_action(announcements: Array, position: int = 2) -> Dictionary:
	for action in announcements:
		if action is Dictionary and action.get("enemy_position") == position:
			return action.duplicate(true)
	return {}


static func _records(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array:
		return []
	var records: Array = []
	for record in parsed:
		if not record is Dictionary:
			return []
		var copy: Dictionary = record.duplicate(true)
		if copy.get("max_hp") is float:
			copy["max_hp"] = int(copy["max_hp"])
		records.append(copy)
	return records
