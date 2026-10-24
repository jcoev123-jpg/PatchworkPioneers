extends SceneTree
## Scene-free three-hero Path composition and fail-closed regression.

const PATHS := {
	"warden": ["bulwark", "vanguard"],
	"seamstress": ["bloodline", "unpicker"],
	"tinker": ["sharpshot", "clockwork"],
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/cards/starter_deck.json"))
	_check(raw is Array and raw.size() == 12, "authored twelve-card base exists")
	if not raw is Array or raw.size() != 12:
		_finish()
		return
	var base: Array = raw
	_check(base == StarterCards.new().get_starting_deck(),
		"authored base exactly matches the starter catalog order")
	_test_combinations(base)
	_test_rejections(base)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("run_hero_path_loadout_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _counts(ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for id in ids:
		result[id] = int(result.get(id, 0)) + 1
	return result


func _selection(w: Variant, s: Variant, t: Variant) -> Dictionary:
	return {"warden": w, "seamstress": s, "tinker": t}


func _test_combinations(base: Array) -> void:
	var seen := 0
	for w in PATHS["warden"]:
		for s in PATHS["seamstress"]:
			for t in PATHS["tinker"]:
				seen += 1
				var label: String = w + "/" + s + "/" + t
				var selection := _selection(w, s, t)
				var selection_before := selection.duplicate(true)
				var rng := RandomNumberGenerator.new()
				rng.seed = 238600 + seen
				var state_before := rng.state
				var composer := RunHeroPathLoadout.new()
				_check(not composer.is_claimed() and composer.get_receipt().is_empty(),
					label + " starts unclaimed")
				var result: Dictionary = composer.choose(selection, rng)
				_check(result.get("ok", false) and composer.is_claimed(),
					label + " succeeds exactly once")
				_check(rng.state == state_before and selection == selection_before,
					label + " leaves caller RNG and selection unchanged")
				if not result.get("ok", false):
					continue
				var paths: Dictionary = result.get("paths", {})
				var deck: Variant = result.get("deck")
				_check(paths.size() == 3 and paths.has("warden") and
					paths.has("seamstress") and paths.has("tinker"),
					label + " has only three active hero records")
				_check(deck is Array[String] and deck.size() == 15,
					label + " supplies typed fifteen-card deck")
				if not deck is Array[String] or deck.size() != 15 or paths.size() != 3:
					continue
				var w_choice := RunWardenPathChoice.new().choose(w)
				var s_choice := RunSeamstressPathChoice.new().choose(s)
				var t_source := RunTinkerPathChoice.new()
				var t_choice := t_source.choose(t, base)
				var t_offer := t_source.get_definition(t)
				_check(w_choice.get("ok", false) and s_choice.get("ok", false) and
					t_choice.get("ok", false) and not t_offer.is_empty(),
					label + " independent chooser preconditions")
				if not w_choice.get("ok", false) or not s_choice.get("ok", false) or \
						not t_choice.get("ok", false) or t_offer.is_empty():
					continue
				var chosen_cards: Array = [
					w_choice["card"]["id"], s_choice["card"]["id"], t_choice["card_id"]]
				var expected: Array = base.duplicate()
				expected.append_array(chosen_cards)
				_check(deck == expected, label + " preserves all base occurrences and append order")
				_check(_counts(deck) == _counts(expected) and
					not deck.has("warden_lance_pin" if w == "bulwark" else "warden_bulwark_brace") and
					not deck.has("seamstress_fray" if s == "bloodline" else "seamstress_leech_stitch") and
					not deck.has("tinker_wind_up" if t == "sharpshot" else "tinker_scope"),
					label + " has only selected Path cards")
				_check(paths["warden"] == {
					"path_id": w, "display_name": w_choice["display_name"],
					"passive": w_choice["passive"], "card": w_choice["card"]},
					label + " Warden replacement record equals authored chooser")
				_check(paths["seamstress"] == {
					"path_id": s, "display_name": s_choice["display_name"],
					"passive": s_choice["passive"], "card": s_choice["card"]},
					label + " Seamstress replacement record equals authored chooser")
				_check(paths["tinker"] == {
					"path_id": t, "display_name": t_offer["display_name"],
					"passive_id": t_choice["passive_id"],
					"passive": t_offer["passive"], "card": t_offer["card"]},
					label + " Tinker replacement record equals authored chooser")
				_check(paths["tinker"]["card"]["starting_copies"] == 0,
					label + " chosen Tinker card comes from Path, not base catalog")
				var shuffle_rng := RandomNumberGenerator.new()
				shuffle_rng.seed = 238900 + seen
				var combat := CombatDeck.new(deck, shuffle_rng)
				_check(_counts(combat.draw_pile) == _counts(expected) and
					combat.draw_pile.size() == 15,
					label + " CombatDeck accepts typed IDs without changing multiset")
				var stored: Dictionary = composer.get_receipt()
				_check(stored == result, label + " detached receipt initially matches")
				paths["warden"]["passive"]["forged"] = true
				paths["seamstress"]["card"]["effects"]["forged"] = 99
				paths["tinker"]["card"]["from_positions"].clear()
				deck.append("forged_card")
				_check(composer.get_receipt() == stored,
					label + " mutating returned deck and nested records cannot reach claim")
				stored["paths"]["tinker"]["passive"]["forged"] = true
				_check(not composer.get_receipt()["paths"]["tinker"]["passive"].has("forged"),
					label + " getter also returns a detached deep copy")
				var replay := composer.choose(selection, rng)
				_check(replay.get("ok") == false and composer.get_receipt()["deck"] == expected
					and rng.state == state_before, label + " replay fails without RNG or claim change")
	_check(seen == 8, "all eight legal Path combinations exercised")


func _test_rejections(base: Array) -> void:
	var invalid: Array = [
		null, [], "bulwark", {},
		{"warden": "bulwark", "seamstress": "bloodline"},
		{"warden": "bulwark", "seamstress": "bloodline",
			"tinker": "sharpshot", "extra": "x"},
		_selection("unknown", "bloodline", "sharpshot"),
		_selection("bulwark", "unknown", "sharpshot"),
		_selection("bulwark", "bloodline", "unknown"),
		_selection("bulwark", "bloodline", 1),
		_selection("bulwark", null, "sharpshot"),
		_selection(["bulwark", "vanguard"], "bloodline", "sharpshot"),
		{1: "bulwark", "seamstress": "bloodline", "tinker": "sharpshot"},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 238999
	var state_before := rng.state
	var composer := RunHeroPathLoadout.new()
	for index in invalid.size():
		var candidate: Variant = invalid[index]
		var before: Variant = candidate.duplicate(true) if candidate is Dictionary or \
			candidate is Array else candidate
		var rejected: Dictionary = composer.choose(candidate, rng)
		_check(rejected.get("ok") == false and not composer.is_claimed() and
			composer.get_receipt().is_empty(), "invalid input %d fails without partial claim" % index)
		_check(candidate == before and rng.state == state_before and
			JSON.parse_string(FileAccess.get_file_as_string(
				"res://data/cards/starter_deck.json")) == base,
			"invalid input %d leaves caller, RNG and starter unchanged" % index)
	var valid := _selection("bulwark", "bloodline", "sharpshot")
	_check(composer.choose(valid, rng).get("ok", false) and composer.is_claimed(),
		"valid selection succeeds after every rejection")
	_check(rng.state == state_before, "valid composition still consumes no caller RNG")
