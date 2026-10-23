extends SceneTree
## Real seeded shared-hand Tinker Path transactions, with detached attack-rule oracle.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_sharpshot_scope()
	_test_clockwork_wind_up(2)
	_test_clockwork_wind_up(3)
	_test_rejections_and_retry()
	for failure in failures:
		printerr(failure)
	print("combat_tinker_path_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _starter() -> Array:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/cards/starter_deck.json"))
	return raw if raw is Array else []


func _counts(cards: Array) -> Dictionary:
	var result: Dictionary = {}
	for id in cards:
		result[id] = int(result.get(id, 0)) + 1
	return result


func _all_cards(deck: CombatDeck) -> Array:
	var cards: Array = []
	cards.append_array(deck.draw_pile)
	cards.append_array(deck.hand)
	cards.append_array(deck.discard_pile)
	return cards


func _party(position: int) -> CombatParty:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	if not (raw is Array):
		return CombatParty.new([])
	var lookup: Dictionary = {}
	for hero in raw:
		var definition: Dictionary = hero.duplicate(true)
		definition["max_hp"] = int(definition["max_hp"])
		lookup[definition["id"]] = definition
	var ids: Array[String] = ["warden", "seamstress", "tinker"]
	if position == 2:
		ids = ["warden", "tinker", "seamstress"]
	elif position == 1:
		ids = ["tinker", "warden", "seamstress"]
	var ordered: Array = []
	for id in ids:
		if not lookup.has(id):
			return CombatParty.new([])
		ordered.append(lookup[id])
	return CombatParty.new(ordered)


## Search bounded deterministic seeds until the selected authentic card occurs
## among CombatDeck's ORIGINAL five drawn cards. Never inject it into hand.
func _fixture(path_id: String, position: int) -> Dictionary:
	var base: Array = _starter()
	for seed_value in range(1, 512):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var choice := RunTinkerPathChoice.new()
		var selected: Dictionary = choice.choose(path_id, base, rng)
		if not selected.get("ok", false):
			return {}
		var ids: Array[String] = []
		ids.assign(selected["deck"])
		var deck := CombatDeck.new(ids, rng)
		var party := _party(position)
		var hand := CombatTinkerPathHand.new(choice, deck, party)
		if not hand.is_bound() or not hand.start_player_turn():
			return {}
		if deck.hand.has(str(selected["card_id"])):
			return {"choice": choice, "selection": selected, "original": base,
				"deck": deck, "party": party, "hand": hand, "rng": rng,
				"position": position, "seed": seed_value}
	return {}


func _metadata(f: Dictionary) -> Dictionary:
	var selected: Dictionary = f["selection"]
	return f["choice"].get_card_definition(str(selected["card_id"]))


func _call(f: Dictionary, commit: bool, overrides: Dictionary = {}) -> Dictionary:
	var meta: Dictionary = _metadata(f)
	var id: String = str(overrides.get("id", meta.get("id", "")))
	var owner: String = str(overrides.get("owner", meta.get("owner", "")))
	var cost: int = int(overrides.get("cost", meta.get("cost", -1)))
	var pos: int = int(overrides.get("position", f["position"]))
	var target: String = str(overrides.get("target", meta.get("target_kind", "")))
	var hand: CombatTinkerPathHand = f["hand"]
	if commit:
		return hand.commit_path_card(id, owner, cost, pos, target)
	return hand.preview_path_card(id, owner, cost, pos, target)


## Includes private Path rule state to catch hidden early credits/consumption,
## and a public future attack quote to cover the shared first-attack latch.
func _snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var rules: CombatTinkerPathRules = f["hand"].get_rules()
	var party: CombatParty = f["party"]
	var tinker: Dictionary = {}
	for hero in party.get_heroes():
		if hero.get("id") == "tinker":
			tinker = hero
	return {
		"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"deck_turn": deck.turn_active, "state_turn": deck.combat_state.player_turn_active,
		"state_energy": deck.combat_state.energy, "party": party.get_heroes(),
		"rng": f["rng"].state, "path_turn": rules._turn_active,
		"armed": rules._scope_armed, "discount_used": rules._clockwork_used,
		"pending": rules._pending_energy, "ready": rules._ready_energy,
		"attack": rules.preview("tinker_pop_shot", int(tinker.get("position", 0)),
			int(tinker.get("hp", 0)), 3)
	}


func _reject(f: Dictionary, commit: bool, overrides: Dictionary, label: String) -> void:
	var before: Dictionary = _snapshot(f)
	var result: Dictionary = _call(f, commit, overrides)
	_check(not result.get("ok", false), label + ": refuses")
	_check(_snapshot(f) == before, label + ": preserves piles, energy, party, rules, RNG")


func _verify_fixture(f: Dictionary, path_id: String) -> bool:
	_check(not f.is_empty(), path_id + ": genuine selected card found in initial draw")
	if f.is_empty():
		return false
	var deck: CombatDeck = f["deck"]
	var selected: Dictionary = f["selection"]
	var source: Array = f["original"]
	var cards: Array = _all_cards(deck)
	var expected := _counts(source)
	expected[selected["card_id"]] = 1
	_check(f["choice"].get_selection()["path_id"] == path_id and
		selected["card_id"] == ("tinker_scope" if path_id == "sharpshot" else "tinker_wind_up"),
		path_id + ": genuine selection and authored Path identity")
	_check(deck.turn_active and deck.energy == 3 and deck.hand.size() == 5 and
		cards.size() == source.size() + 1 and deck.hand.count(selected["card_id"]) == 1,
		path_id + ": real starting hand five, energy three, selected occurrence held")
	_check(_counts(cards) == expected and
		cards.count("tinker_wind_up" if path_id == "sharpshot" else "tinker_scope") == 0,
		path_id + ": original starter occurrences conserved plus only selected card")
	_check(f["party"].is_valid() and f["hand"].is_bound() and
		f["hand"].get_rules() is CombatTinkerPathRules,
		path_id + ": authentic party/deck and shared rules bound")
	return true


func _test_sharpshot_scope() -> void:
	var f: Dictionary = _fixture("sharpshot", 3)
	if not _verify_fixture(f, "sharpshot"):
		return
	var deck: CombatDeck = f["deck"]
	var rules: CombatTinkerPathRules = f["hand"].get_rules()
	var baseline: Dictionary = _snapshot(f)
	for repeat in range(3):
		var quote: Dictionary = _call(f, false)
		_check(quote.get("ok", false) and quote.get("cost") == 0 and
			quote.get("arms_scope") and quote.get("printed_cost") == 0,
			"Scope preview is a zero-cost selected-card quote")
	_check(_snapshot(f) == baseline, "repeat Scope previews preserve RNG and all state")
	_check(rules.preview("tinker_pop_shot", 3, 26, 3).get("damage_bonus") == 3,
		"uncommitted Scope leaves native Sharpshot +3 only")
	var rng_before: int = f["rng"].state
	var result: Dictionary = _call(f, true)
	_check(result.get("ok", false) and result.get("cost") == 0 and
		deck.energy == 3 and deck.hand.count("tinker_scope") == 0 and
		deck.discard_pile.count("tinker_scope") == 1 and f["rng"].state == rng_before,
		"Scope spends zero and moves exact held occurrence once without RNG")
	_check(rules == f["hand"].get_rules() and rules._scope_armed and
		_counts(_all_cards(deck)) == _counts(f["selection"]["deck"]),
		"same Path rule authority armed and whole deck conserved")
	_reject(f, true, {}, "duplicate Scope play")
	for repeat in range(3):
		_check(rules.preview("tinker_pop_shot", 3, 26, 3).get("damage_bonus") == 7,
			"Sharpshot +3 and Scope +4 stack through repeated attack previews")
	_check(rules.preview("tinker_tune_up", 3, 26, 3).get("damage_bonus") == 0 and
		rules.commit_successful("tinker_tune_up", 3, 26, 3, true).get("ok", false),
		"confirmed nonattack through same Path rules does not consume Scope")
	_check(rules.preview("tinker_pop_shot", 3, 26, 3).get("damage_bonus") == 7,
		"nonattack preserved first-attack + Scope stack")
	_check(not rules.commit_successful("tinker_pop_shot", 3, 26, 3, false).get("ok", false)
		and rules.preview("tinker_pop_shot", 3, 26, 3).get("damage_bonus") == 7,
		"rejected attack cannot consume either bonus")
	_check(deck.draw_extra(1) == 1 and
		rules.preview("tinker_pop_shot", 3, 26, 3).get("damage_bonus") == 7,
		"real extra draw does not consume Scope")
	var landed: Dictionary = rules.commit_successful("tinker_pop_shot", 3, 26, 3, true)
	_check(landed.get("damage_bonus") == 7 and landed.get("scope_bonus") == 4 and
		landed.get("sharpshot_bonus") == 3 and
		rules.preview("tinker_scrap_bomb", 3, 26, 3).get("damage_bonus") == 0,
		"confirmed first Tinker attack consumes both once in shared rule contract")
	_check(_counts(_all_cards(deck)) == _counts(f["selection"]["deck"]),
		"follow-up attack rule projection did not counterfeit hand transaction")
	var expiry: Dictionary = _fixture("sharpshot", 3)
	if not _verify_fixture(expiry, "sharpshot"):
		return
	_check(_call(expiry, true).get("ok", false), "Scope armed for expiry test")
	_check(expiry["hand"].end_player_turn() and expiry["hand"].start_player_turn(),
		"genuine next deck turn opens and Scope expires")
	_check(expiry["hand"].get_rules().preview("tinker_pop_shot", 3, 26, 3).get(
		"damage_bonus") == 3, "unspent Scope expired; fresh Sharpshot +3")
	var zero: Dictionary = _fixture("sharpshot", 3)
	if _verify_fixture(zero, "sharpshot"):
		_check(zero["deck"].try_spend_energy(3), "exhaust energy before free Scope")
		_check(_call(zero, true).get("ok", false) and zero["deck"].energy == 0,
			"Scope remains playable at zero energy")


func _test_clockwork_wind_up(position: int) -> void:
	var f: Dictionary = _fixture("clockwork", position)
	if not _verify_fixture(f, "clockwork"):
		return
	var deck: CombatDeck = f["deck"]
	var rules: CombatTinkerPathRules = f["hand"].get_rules()
	var baseline: Dictionary = _snapshot(f)
	_check(_call(f, false).get("cost") == 1 and
		_call(f, false).get("next_turn_energy") == 1 and
		_snapshot(f) == baseline, "Wind-up from %d previews cost 1 without mutation" % position)
	var rng_before: int = f["rng"].state
	var receipt: Dictionary = _call(f, true)
	_check(receipt.get("ok", false) and receipt.get("cost") == 1 and
		deck.energy == 2 and deck.hand.count("tinker_wind_up") == 0 and
		deck.discard_pile.count("tinker_wind_up") == 1 and f["rng"].state == rng_before,
		"Wind-up from %d costs exactly 1, discarded once, no RNG" % position)
	_check(rules._pending_energy == 1 and rules._ready_energy == 0 and
		not rules._clockwork_used and deck.energy == 2,
		"Wind-up grants pending credit only and doesn't consume Clockwork")
	_check(rules.preview("tinker_pop_shot", position, 26, 3).get("cost") == 1 and
		rules.preview("tinker_tune_up", 3, 26, 3).get("cost") == 0 and
		rules.preview("tinker_scrap_bomb", 3, 26, 1).get("discount") == 1,
		"printed costs 0/1 unchanged and expensive discount retained")
	_reject(f, true, {}, "Wind-up duplicate")
	var before_duplicate: Dictionary = _snapshot(f)
	_check(not f["hand"].start_player_turn() and _snapshot(f) == before_duplicate,
		"repeated turn entry cannot accelerate queued energy or redraw")
	_check(rules.take_next_turn_energy_bonus() == 0 and rules._pending_energy == 1,
		"Wind-up cannot be claimed in its own turn")
	_check(f["hand"].end_player_turn(), "end genuine deck turn for Wind-up")
	_check(not f["hand"].end_player_turn(), "duplicate end refuses")
	_check(f["hand"].start_player_turn() and deck.energy == 4 and
		deck.combat_state.energy == 4 and rules._pending_energy == 0 and
		rules._ready_energy == 0,
		"NEXT real deck turn resets 3 then credits 1 exactly once")
	_check(rules.take_next_turn_energy_bonus() == 0,
		"adapter already consumed ready credit from same rules")
	before_duplicate = _snapshot(f)
	_check(not f["hand"].start_player_turn() and _snapshot(f) == before_duplicate,
		"second claim cannot award another energy or draw")
	_check(f["hand"].end_player_turn() and f["hand"].start_player_turn() and
		deck.energy == 3, "following turn resets to 3 with no stale credit")


func _test_rejections_and_retry() -> void:
	var f: Dictionary = _fixture("clockwork", 2)
	if not _verify_fixture(f, "clockwork"):
		return
	for bad in [
		{"id": "tinker_scope"}, {"id": "tinker_pop_shot"},
		{"id": "unknown"}, {"owner": "warden"}, {"owner": ""},
		{"cost": 0}, {"cost": 2}, {"position": 3}, {"position": 1},
		{"target": "enemy_single"}, {"target": "ally_single"}
	]:
		_reject(f, false, bad, "forged preview " + str(bad))
		_reject(f, true, bad, "forged commit " + str(bad))
	_check(_call(f, true).get("ok", false),
		"after forged metadata rejections the authentic held Wind-up can succeed")
	_reject(f, true, {}, "spent occurrence cannot replay")
	var absent: Dictionary = _fixture("clockwork", 2)
	if _verify_fixture(absent, "clockwork"):
		_check(absent["deck"].discard_played("tinker_wind_up"),
			"setup: real deck discards selected card so it is no longer held")
		_reject(absent, false, {}, "absent Path card preview")
		_reject(absent, true, {}, "absent Path card commit")
	var empty_energy: Dictionary = _fixture("clockwork", 2)
	if _verify_fixture(empty_energy, "clockwork"):
		_check(empty_energy["deck"].try_spend_energy(3), "setup: real zero energy")
		_reject(empty_energy, false, {}, "insufficient energy preview")
		_reject(empty_energy, true, {}, "insufficient energy commit")
	for path_id in ["sharpshot", "clockwork"]:
		var wrong_pos: int = 2 if path_id == "sharpshot" else 1
		var moved: Dictionary = _fixture(path_id, wrong_pos)
		if _verify_fixture(moved, path_id):
			_reject(moved, false, {}, path_id + " wrong live Tinker position")
			_reject(moved, true, {}, path_id + " wrong live Tinker position")
		var downed: Dictionary = _fixture(path_id, 3)
		if _verify_fixture(downed, path_id):
			var party: CombatParty = downed["party"]
			_check(party.apply_damage(3, 26) and party.is_downed(3),
				"setup: real Tinker downed")
			_reject(downed, false, {}, path_id + " downed preview")
			_reject(downed, true, {}, path_id + " downed commit")
		var inactive: Dictionary = _fixture(path_id, 3)
		if _verify_fixture(inactive, path_id):
			_check(inactive["hand"].end_player_turn(), "setup: genuine closed turn")
			_reject(inactive, false, {}, path_id + " inactive preview")
			_reject(inactive, true, {}, path_id + " inactive commit")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var deck: Array = _starter()
	var choice := RunTinkerPathChoice.new()
	var selected: Dictionary = choice.choose("sharpshot", deck, rng)
	if selected.get("ok", false):
		var ids: Array[String] = []
		ids.assign(selected["deck"])
		ids.append("tinker_scope")
		var forged_deck := CombatDeck.new(ids, rng)
		var invalid := CombatTinkerPathHand.new(choice, forged_deck, _party(3))
		_check(not invalid.is_bound() and not invalid.start_player_turn(),
			"duplicate Path occurrence cannot bind or open a battle")
		var not_chosen := CombatTinkerPathHand.new(RunTinkerPathChoice.new(),
			forged_deck, _party(3))
		_check(not not_chosen.is_bound() and not not_chosen.start_player_turn(),
			"unselected Path cannot bind or open a battle")
