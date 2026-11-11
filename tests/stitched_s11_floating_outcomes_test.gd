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
	var prior_units := {"victim": {"id": "victim", "hp": 12, "max_hp": 20,
		"statuses": {"bleed": 2, "rot": 1, "weak": 1}},
		"ally": {"id": "ally", "hp": 8, "max_hp": 20, "statuses": {"regen": 1}}}
	var settled_units := {"victim": {"id": "victim", "hp": 8, "max_hp": 20,
		"statuses": {"bleed": 1}},
		"ally": {"id": "ally", "hp": 10, "max_hp": 20, "statuses": {}}}
	var tick_cues := StitchedBattleScreen.turn_change_cues(prior_units, settled_units,
		{"actor": "someone_else", "results": []})
	var saw_bleed := false
	var saw_regen := false
	for cue in tick_cues:
		if str(cue.get("status", "")) == "bleed" and int(cue.get("amount", 0)) == 2:
			saw_bleed = true
		if str(cue.get("status", "")) == "regen" and int(cue.get("amount", 0)) == 2 \
				and bool(cue.get("expired", false)):
			saw_regen = true
	_check(tick_cues.size() == 4 and saw_bleed,
		"unaffected units expose exact bleed, rot, regen ticks and status expiry")
	_check(saw_regen, "regen heal and expiration use the settled clock")
	_check(StitchedBattleScreen.turn_change_cues(prior_units, settled_units,
		{"actor": "someone_else", "results": [{"target": "victim"}]}).size() == 1,
		"do not misattribute attack damage or applied statuses to turn-start ticks")
	# A next-to-act foe can be struck and tick Bleed in the same settlement.
	# The result's target_hp (after the hit, before clocks) proves which
	# portion is a hit and which is the settled start-of-turn tick.
	var overlap_before := {foe_id: {"hp": 12, "max_hp": 20,
		"statuses": {"bleed": 2, "weak": 1}}}
	var overlap_after := {foe_id: {"hp": 6, "max_hp": 20,
		"statuses": {"bleed": 1}}}
	var overlap_receipt := {"action": "ability", "ok": true, "actor": hero_id,
		"results": [{"target": foe_id, "target_side": "foe", "hit": true,
			"damage": 4, "target_hp": 8, "statuses": []}]}
	var overlap_cues := StitchedBattleScreen.turn_change_cues(
		overlap_before, overlap_after, overlap_receipt)
	_check(overlap_cues.size() == 2 and int(overlap_cues[0].get("amount", 0)) == 2
		and str(overlap_cues[0].get("status", "")) == "bleed",
		"overlapping strike and bleed separate from post-hit HP without double counting")
	overlap_receipt["turn_cues"] = overlap_cues
	_check(_words(fight._float_events(overlap_receipt), foe_key).has("BLEED -2")
		and _words(fight._float_events(overlap_receipt), foe_key).has("WEAK ENDED"),
		"strike and tick words stack over their actual target")
	overlap_receipt.erase("turn_cues")
	overlap_receipt.results[0].target_hp = 7
	_check(StitchedBattleScreen.turn_change_cues(
		overlap_before, overlap_after, overlap_receipt).is_empty(),
		"an inconsistent post-hit HP cannot invent a clock tick")
	overlap_receipt.results[0].target_hp = 8
	overlap_receipt.results[0].statuses = [{"status": "bleed", "duration": 2}]
	_check(StitchedBattleScreen.turn_change_cues(
		overlap_before, overlap_after, overlap_receipt).is_empty(),
		"an ability reapplying a status cannot be mistaken for its expiration")
	overlap_receipt.results[0].statuses = []
	overlap_receipt.results.append({"target": foe_id, "target_hp": 8})
	_check(StitchedBattleScreen.turn_change_cues(
		overlap_before, overlap_after, overlap_receipt).is_empty(),
		"two results on the same foe cannot claim one intermediate HP")
	overlap_receipt.results.pop_back()
	overlap_before[foe_id] = {"hp": 12, "max_hp": 20,
		"statuses": {"regen": 1, "rot": 1}}
	overlap_after[foe_id] = {"hp": 7, "max_hp": 20, "statuses": {}}
	overlap_cues = StitchedBattleScreen.turn_change_cues(
		overlap_before, overlap_after, overlap_receipt)
	_check(overlap_cues.size() == 2 and int(overlap_cues[0].get("amount", 0)) == 1
		and int(overlap_cues[1].get("amount", 0)) == 2,
		"overlapping regen and rot use rule order after the blow")
	# A single turn can regenerate before bleeding, or bleed before rotting.
	# The numbers must reflect the intervening HP, not separate old-HP caps.
	var combo_before := {"seat": {"hp": 1, "max_hp": 12,
		"statuses": {"regen": 1, "bleed": 2}}}
	var combo_after := {"seat": {"hp": 1, "max_hp": 12,
		"statuses": {"bleed": 1}}}
	var combo := StitchedBattleScreen.turn_change_cues(combo_before, combo_after,
		{"actor": "other", "results": []})
	var numbers := {}
	for cue in combo:
		numbers[str(cue.get("status", ""))] = int(cue.get("amount", -1))
	_check(combo.size() == 2 and int(numbers.get("regen", -1)) == 2
		and int(numbers.get("bleed", -1)) == 2,
		"regen first restores two, letting subsequent bleed deal its full two")
	combo_before["seat"] = {"hp": 3, "max_hp": 12,
		"statuses": {"bleed": 2, "rot": 1}}
	combo_after["seat"] = {"hp": 0, "max_hp": 12,
		"statuses": {"bleed": 1}}
	combo = StitchedBattleScreen.turn_change_cues(combo_before, combo_after,
		{"actor": "other", "results": []})
	numbers.clear()
	for cue in combo:
		numbers[str(cue.get("status", ""))] = int(cue.get("amount", -1))
	_check(combo.size() == 2 and int(numbers.get("bleed", -1)) == 2
		and int(numbers.get("rot", -1)) == 1,
		"bleed first leaves one HP for rot, so no phantom extra rot damage")
	receipt["turn_cues"] = [{"target": foe_id, "status": "bleed", "amount": 2, "expired": false},
		{"target": hero_id, "status": "regen", "amount": 2, "expired": true}]
	_check(_words(fight._float_events(receipt), foe_key).has("BLEED -2")
		and _words(fight._float_events(receipt), hero_key).has("REGEN +2")
		and _words(fight._float_events(receipt), hero_key).has("REGEN ENDED"),
		"turn-start ticks and expiration float over the units whose clocks actually changed")
	# A pass can advance a bleed/rot/regen clock without an attack receipt.
	# It needs its own held word beat, never a fabricated strike.
	var passed := {"action": "pass", "ok": true, "actor": hero_id, "turn_cues": [
		{"target": foe_id, "status": "rot", "amount": 2, "expired": true}]}
	words = _words(fight._float_events(passed), foe_key)
	_check(words.has("ROT -2") and words.has("ROT ENDED"),
		"pass-only settled clock has visible tick and expiry, with no invented attack")
	_check(fight._float_events({"action": "pass", "ok": true}).is_empty(),
		"pass without a settled status has no phantom outcome")
	fight._start_beats([passed])
	await physics_frame
	await physics_frame
	_check(fight._beats != null and fight._beats.is_running()
		and fight._float_groups.has(foe_key),
		"status-only pass animates its observed cues in a held beat")
	_check(fight.stage._spot_tween != null and fight.stage._spot_tween.is_running(),
		"tick-only spotlight starts with correctly typed Godot seat arrays")
	fight._cancel_beats()
	receipt.erase("turn_cues")
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
	receipt.results[0].lost = true
	words = _words(fight._float_events(receipt), hero_key)
	_check(words.has("LOST!") and not words.has("UNSTITCHED!") and not words.has("HANGING"),
		"terminal doll loss has its own callout, never the foe kill or hanging word")

	receipt.actor = hero_id
	receipt.results = [{"target": hero_id, "target_side": "hero", "hit": true,
		"damage": 0, "attacker_tear": {"ok": true, "slot": "legs"}, "statuses": []}]
	words = _words(fight._float_events(receipt), hero_key)
	_check(words.has("SEAM TORN!"), "a confirmed counter-tear on the attacker is called out")
	receipt.results[0].attacker_lost = true
	words = _words(fight._float_events(receipt), hero_key)
	_check(words.has("LOST!") and words.has("SEAM TORN!"),
		"counter damage that loses the attacking doll announces both the tear and final loss")
	receipt.results[0].erase("attacker_lost")
	receipt.results[0].attacker_heap = {"rank": int(foe.rank), "hp": 3}
	receipt.actor = foe_id
	words = _words(fight._float_events(receipt), foe_key)
	_check(words.has("UNSTITCHED!"), "counter-killed foe is called out on the attacker")
	receipt.actor = hero_id

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
	# Announce only rules-confirmed forced movement and a successful cut; a
	# failed/blocked effect cannot become a phantom floating outcome.
	receipt.results = [{"target": foe_id, "target_side": "foe", "hit": true,
		"damage": 0, "statuses": [], "shift": {"ok": true, "from": 1, "to": 2}}]
	_check(_words(fight._float_events(receipt), foe_key).has("PUSHED BACK"),
		"a confirmed rank increase announces the pushed foe")
	receipt.results[0].shift = {"ok": true, "from": 2, "to": 1}
	_check(_words(fight._float_events(receipt), foe_key).has("PULLED FORWARD"),
		"a confirmed rank decrease announces the pulled foe")
	receipt.results[0].shift = {"ok": false, "reason": "blocked"}
	_check(not fight._float_events(receipt).has(foe_key),
		"a blocked displacement cannot float a movement cue")
	receipt.results = [{"target": hero_id, "target_side": "hero", "hit": true,
		"damage": 0, "statuses": [], "snip": {"ok": true, "hero": hero_id, "after_rank": 1}}]
	_check(_words(fight._float_events(receipt), hero_key).has("THREAD CUT!"),
		"a confirmed severed thread floats over the affected doll")
	receipt.results[0].snip = {"ok": false, "error": "already cut"}
	_check(not fight._float_events(receipt).has(hero_key),
		"a refused thread cut cannot invent a callout")

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
	# The actual lost state used to hide the doll during the held blow, dropping LOST!
	# despite a synthetic "lost" receipt appearing correct against a living doll.
	var saved_hero: Dictionary = fight.battle.get_unit(hero_id).duplicate(true)
	var lost_receipt := {"ok": true, "action": "ability", "actor": foe_id, "results": [
		{"target": hero_id, "target_side": "hero", "hit": true,
		"damage": 6, "target_hp": 0, "lost": true, "statuses": []}]}
	screen.receipts.append(lost_receipt)
	fight.battle._units[hero_id]["lost"] = true
	fight.battle._units[hero_id]["hp"] = 0
	fight.refresh()
	_check(fight._live_receipt_key(hero_id) == hero_key
		and fight.stage.figure_nodes[hero_key].visible and fight.plates[hero_key].visible
		and fight.plates[hero_key].get_node("HealthText").text.begins_with("0/"),
		"truly LOST doll holds its own picture and zero-HP plate for the pending blow")
	_check(_words(fight._float_events(lost_receipt), hero_key).has("LOST!"),
		"terminal loss is called out on the actually LOST doll, not only a living fixture")
	var fatal_tick := {"action": "pass", "ok": true, "actor": foe_id, "turn_cues": [
		{"target": hero_id, "lost": true}]}
	_check(_words(fight._float_events(fatal_tick), hero_key).has("LOST!"),
		"a death-door bleed tick can announce terminal loss over the held doll")
	screen.receipts.pop_back()
	fight.battle._units[hero_id] = saved_hero
	fight.refresh()
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
