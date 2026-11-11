extends SceneTree
## Owner combat job 9: receipt words are truthful, target-scoped and presentation only.
var failures: Array[String] = []
var checks := 0


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _words(events: Dictionary, key: String) -> PackedStringArray:
	var names := PackedStringArray()
	for event in events.get(key, []):
		names.append(str(event.get("words", "")))
	return names


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "preview starts")
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	_check(fight != null, "corridor fight mounts")
	await process_frame
	if fight == null:
		quit(1)
		return
	var hero: Dictionary = fight.battle.get_heroes()[0]
	var foe: Dictionary = fight.battle.get_foes()[0]
	var hero_id := str(hero.id)
	var foe_id := str(foe.id)
	var foe_key := "foe_%d" % int(foe.rank)
	var hero_key := "hero_%d" % int(hero.rank)
	var baseline := fight.battle.state_snapshot()
	var receipts := screen.receipts.duplicate(true)
	var rng := fight.battle.rng_state()
	var receipt := {"action": "ability", "ok": true, "actor": hero_id, "results": [{
		"target": foe_id, "target_side": "foe", "hit": true, "crit": true,
		"damage": 14, "target_hp": 7, "statuses": [
			{"status": "bleed", "duration": 2, "patch": "cotton_red_lint"},
			{"status": "stun", "resisted": true}
		], "patches": ["cotton_red_lint"]}]}
	var events := fight._float_events(receipt)
	var words := _words(events, foe_key)
	_check(words.has("CRIT! 14"), "critical result shows confirmed damage and crit")
	_check(words.has("BLEED") and words.has("RESIST"), "applied bleed and refused stun are distinct")
	_check(words.count("RED LINT") == 1, "one sewn patch firing cue, no duplicate for its status")
	_check(not events.has(hero_key), "damage and debuffs never jump onto the attacker")
	fight._show_float_receipt(receipt)
	_check(fight._float_groups.has(foe_key)
		and fight._float_groups[foe_key].get_child_count() >= 4,
		"ink words render on the struck figure")
	_check(fight._beat_input_shield.get_index() == fight.get_child_count() - 1,
		"floating words cannot intercept the held input shield")
	fight._clear_float_words()
	_check(fight._float_groups.is_empty(), "callout cleanup releases the prior beat")

	receipt.results[0].crit = false
	receipt.results[0].damage = 4
	receipt.results[0].statuses = []
	receipt.results[0].patches = []
	receipt.results[0].heap = {"rank": int(foe.rank), "hp": 2}
	words = _words(fight._float_events(receipt), foe_key)
	_check(words.has("UNSTITCHED!") and words.has("4"), "lethal blow marks kill and damage")
	receipt.results[0].erase("heap")
	receipt.results[0].hit = false
	_check(fight._float_events(receipt).is_empty(), "miss is never reported as a damaging hit")

	receipt.results = [{"target": hero_id, "target_side": "hero", "hit": true,
		"damage": 5, "target_hp": 0, "hanging": true,
		"tear": {"slot": "arms"}, "statuses": []}]
	words = _words(fight._float_events(receipt), hero_key)
	_check(words.has("HANGING") and words.has("SEAM TORN!"),
		"confirmed death-door limb loss is named without exposing a limb slot")

	receipt.results = [{"target": hero_id, "target_side": "hero", "hit": true,
		"damage": 0, "statuses": [{"status": "heal", "amount": 5},
			{"status": "guard", "duration": 2}]}]
	words = _words(fight._float_events(receipt), hero_key)
	_check(words.has("HEAL +5") and words.has("GUARD"), "friendly heals and guard float over helped unit")
	_check(fight._float_events(receipt)[hero_key].back().get("arrow", "") == "float_up",
		"guard requests the painted strengthening arrow")
	receipt.results[0].statuses = [{"status": "weak", "duration": 2}]
	_check(fight._float_events(receipt)[hero_key][0].get("arrow", "") == "float_down",
		"weakness requests the painted downward arrow without drawing geometry")

	receipt.results = [{"target": foe_id, "target_side": "foe", "hit": true,
		"damage": 3, "statuses": [{"status": "regen", "duration": 2,
			"patch": "silk_life_loop", "on": hero_id}],
		"patches": ["silk_life_loop"]}]
	events = fight._float_events(receipt)
	_check(_words(events, hero_key).has("REGEN") and _words(events, hero_key).has("LIFE LOOP"),
		"redirected helpful patch cue follows actual recipient")
	_check(not _words(events, foe_key).has("LIFE LOOP"), "patch is not falsely credited to struck foe")
	# A hero hitting a foe's Thorns/Riposte takes the counter damage itself.
	receipt.results = [{"target": foe_id, "target_side": "foe", "hit": true,
		"damage": 3, "thorns": 2, "riposte": 4, "statuses": []}]
	events = fight._float_events(receipt)
	_check(_words(events, hero_key).has("THORNS -2")
		and _words(events, hero_key).has("RIPOSTE -4"),
		"confirmed counter damage floats on the attacking doll")
	_check(not _words(events, foe_key).has("THORNS -2"),
		"counter damage cannot be misattributed to the defender")
	receipt.results[0].erase("thorns")
	receipt.results[0].erase("riposte")
	_check(not fight._float_events(receipt).has(hero_key),
		"absent counter receipts never invent a callout")
	# An authored foe Drain heals the foe after damaging a hero, not its victim.
	receipt.actor = foe_id
	receipt.results = [{"target": hero_id, "target_side": "hero", "hit": true,
		"damage": 3, "drain": 3, "statuses": []}]
	events = fight._float_events(receipt)
	_check(_words(events, foe_key).has("DRAIN +3")
		and not _words(events, hero_key).has("DRAIN +3"),
		"confirmed foe drain credits the attacker, never the damaged doll")
	receipt.results[0].erase("drain")
	_check(not fight._float_events(receipt).has(foe_key),
		"absent drain receipt never invents healing")
	_check(fight.battle.state_snapshot() == baseline and fight.battle.rng_state() == rng
		and screen.receipts == receipts, "floating callouts do not mutate rules or receipts")
	# A result can finish the fight before its delayed held-beat callouts appear.
	# Both the floating words and a late MISS must leave public Continue on top.
	fight.battle._outcome = "defeat"
	fight._beat_input_shield.show()
	fight._show_float_receipt(receipt)
	_check(fight.continue_button.get_index() == fight.get_child_count() - 1
		and not fight._beat_input_shield.visible,
		"late defeat callout preserves Continue above the hidden input shield")
	fight._clear_float_words()
	receipt.results = [{"target": foe_id, "target_side": "foe", "hit": false, "statuses": []}]
	fight._apply_target_reactions(receipt)
	_check(fight.continue_button.get_index() == fight.get_child_count() - 1
		and not fight._beat_input_shield.visible,
		"late defeat MISS preserves Continue above the reaction label")
	fight._clear_target_reactions()
	fight.battle._outcome = "ongoing"
	screen.free()
	for fail in failures:
		printerr(fail)
	print("stitched_s11_floating_outcomes_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _initialize() -> void:
	_run.call_deferred()
