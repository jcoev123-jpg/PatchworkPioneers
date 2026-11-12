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
	# The rules expose mutable unit dictionaries; an observer must freeze both
	# their HP and nested status maps before the real battle changes them.
	var original_foe: Dictionary = fight.battle._units[foe_id].duplicate(true)
	fight.battle._units[foe_id]["statuses"]["bleed"] = 2
	var captured_before := screen._capture_turn_units()
	fight.battle._units[foe_id]["hp"] = int(original_foe["hp"]) - 2
	fight.battle._units[foe_id]["statuses"]["bleed"] = 1
	var captured_after := screen._capture_turn_units()
	_check(int(captured_before[foe_id]["hp"]) == int(original_foe["hp"])
		and int(captured_before[foe_id]["statuses"].get("bleed", 0)) == 2
		and int(captured_after[foe_id]["statuses"].get("bleed", 0)) == 1,
		"real-battle observer snapshots hold original HP and nested statuses")
	var mounted_cues := StitchedBattleScreen.turn_change_cues(captured_before, captured_after,
		{"actor": "another_unit", "results": []})
	_check(mounted_cues.size() == 1 and str(mounted_cues[0].get("target", "")) == foe_id
		and str(mounted_cues[0].get("status", "")) == "bleed"
		and int(mounted_cues[0].get("amount", 0)) == 2,
		"real-battle mutable units produce a confirmed tick instead of vanishing")
	fight.battle._units[foe_id] = original_foe
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
	# A foe killed by its own clock loses every status immediately, rather than
	# showing a normal countdown. Verify the lethal clock, not merely dead=true.
	var fatal_before := {foe_id: {"side": "foe", "hp": 2, "max_hp": 20,
		"dead": false, "statuses": {"bleed": 2, "rot": 2}}}
	var fatal_after := {foe_id: {"side": "foe", "hp": 0, "max_hp": 20,
		"dead": true, "statuses": {}}}
	var fatal_receipt := {"action": "pass", "ok": true, "actor": hero_id, "results": []}
	var fatal_cues := StitchedBattleScreen.turn_change_cues(fatal_before, fatal_after, fatal_receipt)
	_check(fatal_cues.size() == 2 and str(fatal_cues[0].get("status", "")) == "bleed"
		and int(fatal_cues[0].get("amount", 0)) == 2 and bool(fatal_cues[1].get("killed", false)),
		"fatal Bleed reports exact damage and foe death, without a phantom Rot tick")
	fatal_receipt["turn_cues"] = fatal_cues
	var fatal_words := _words(fight._float_events(fatal_receipt), foe_key)
	_check(fatal_words.has("BLEED -2") and fatal_words.has("UNSTITCHED!")
		and not fatal_words.has("ROT -2"), "a fatal Bleed tick floats the kill on the foe")
	fatal_before[foe_id]["hp"] = 3
	fatal_cues = StitchedBattleScreen.turn_change_cues(fatal_before, fatal_after, fatal_receipt)
	_check(fatal_cues.size() == 3 and int(fatal_cues[1].get("amount", 0)) == 1
		and str(fatal_cues[1].get("status", "")) == "rot"
		and bool(fatal_cues[2].get("killed", false)),
		"Rot kills after nonfatal Bleed with its actual remaining-HP damage")
	fatal_before[foe_id] = {"side": "foe", "hp": 1, "max_hp": 20,
		"dead": false, "statuses": {"regen": 1, "bleed": 3}}
	fatal_cues = StitchedBattleScreen.turn_change_cues(fatal_before, fatal_after, fatal_receipt)
	_check(fatal_cues.size() == 3 and str(fatal_cues[0].get("status", "")) == "regen"
		and int(fatal_cues[0].get("amount", 0)) == 2
		and int(fatal_cues[1].get("amount", 0)) == 3
		and bool(fatal_cues[2].get("killed", false)),
		"final foe kill accounts for regeneration before Bleed")
	fatal_before[foe_id]["hp"] = 6
	_check(StitchedBattleScreen.turn_change_cues(fatal_before, fatal_after, fatal_receipt).is_empty(),
		"dead flag without lethal clocks cannot invent a foe kill")
	fatal_before[foe_id]["hp"] = 1
	fatal_receipt["actor"] = foe_id
	_check(StitchedBattleScreen.turn_change_cues(fatal_before, fatal_after, fatal_receipt).is_empty(),
		"an actor death with unrelated actions cannot be assigned to its clocks")
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
	# When a hit leaves a foe at 1 HP and that foe is next to tick, a
	# confirmed Bleed death must not lose its damage or UNSTITCHED word.
	var clock_kill_before := {foe_id: {"side": "foe", "hp": 5, "max_hp": 20,
		"dead": false, "statuses": {"bleed": 2, "rot": 2}}}
	var clock_kill_after := {foe_id: {"side": "foe", "hp": 0, "max_hp": 20,
		"dead": true, "statuses": {}}}
	var clock_kill_receipt := {"action": "ability", "ok": true, "actor": hero_id,
		"results": [{"target": foe_id, "target_side": "foe", "hit": true,
			"damage": 4, "target_hp": 1, "statuses": []}]}
	var clock_kill_cues := StitchedBattleScreen.turn_change_cues(
		clock_kill_before, clock_kill_after, clock_kill_receipt)
	_check(clock_kill_cues.size() == 2
		and str(clock_kill_cues[0].get("status", "")) == "bleed"
		and int(clock_kill_cues[0].get("amount", -1)) == 1
		and bool(clock_kill_cues[1].get("killed", false)),
		"a post-hit HP anchor proves a fatal overlapping Bleed tick, not phantom Rot")
	clock_kill_receipt["turn_cues"] = clock_kill_cues
	var clock_kill_words := _words(fight._float_events(clock_kill_receipt), foe_key)
	_check(clock_kill_words.has("4") and clock_kill_words.has("BLEED -1")
		and clock_kill_words.count("UNSTITCHED!") == 1,
		"real hit, fatal Bleed tick and kill remain distinct floated outcomes")
	clock_kill_receipt.erase("turn_cues")
	clock_kill_receipt.results[0].erase("target_hp")
	_check(StitchedBattleScreen.turn_change_cues(
		clock_kill_before, clock_kill_after, clock_kill_receipt).is_empty(),
		"missing post-hit HP cannot claim a fatal overlapping clock")
	clock_kill_receipt.results[0]["target_hp"] = 0
	_check(StitchedBattleScreen.turn_change_cues(
		clock_kill_before, clock_kill_after, clock_kill_receipt).is_empty(),
		"a kill from the hit itself cannot claim extra fatal clock damage")
	clock_kill_receipt.results[0]["target_hp"] = 1
	clock_kill_receipt.results[0]["statuses"] = [{"status": "bleed", "duration": 2}]
	_check(StitchedBattleScreen.turn_change_cues(
		clock_kill_before, clock_kill_after, clock_kill_receipt).is_empty(),
		"a status rewritten by the hit cannot be used to invent its fatal tick")
	clock_kill_receipt.results[0]["statuses"] = [{"status": "bleed", "resisted": true}]
	clock_kill_cues = StitchedBattleScreen.turn_change_cues(
		clock_kill_before, clock_kill_after, clock_kill_receipt)
	_check(clock_kill_cues.size() == 2 and int(clock_kill_cues[0].get("amount", 0)) == 1
		and bool(clock_kill_cues[1].get("killed", false)),
		"a resisted Bleed application leaves the earlier Bleed clock free to finish the foe")
	clock_kill_receipt.results[0]["statuses"] = [{"status": "bleed", "refused": true}]
	_check(StitchedBattleScreen.turn_change_cues(
		clock_kill_before, clock_kill_after, clock_kill_receipt).size() == 2,
		"a refused status also cannot erase a settled existing Bleed tick")
	clock_kill_receipt.results[0]["statuses"] = []
	clock_kill_receipt.results.append({"target": foe_id, "target_hp": 1})
	_check(StitchedBattleScreen.turn_change_cues(
		clock_kill_before, clock_kill_after, clock_kill_receipt).is_empty(),
		"multiple results against one foe leave fatal clock attribution ambiguous")
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
	# A status duration can decrease alongside an unrelated state change.
	# Without matching settled HP, no bleeding or regeneration may be announced.
	var unexplained_before := {"seat": {"hp": 12, "max_hp": 20,
		"statuses": {"bleed": 2}}}
	var unexplained_after := {"seat": {"hp": 12, "max_hp": 20,
		"statuses": {"bleed": 1}}}
	_check(StitchedBattleScreen.turn_change_cues(unexplained_before, unexplained_after,
		{"actor": "other", "results": []}).is_empty(),
		"duration drop without matching damage never reports a phantom bleed tick")
	unexplained_before["seat"] = {"hp": 12, "max_hp": 20, "statuses": {"regen": 1}}
	unexplained_after["seat"] = {"hp": 13, "max_hp": 20, "statuses": {}}
	_check(StitchedBattleScreen.turn_change_cues(unexplained_before, unexplained_after,
		{"actor": "other", "results": []}).is_empty(),
		"regen with an unexplained one-HP settlement never reports +2 or expiry")
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
	fight._show_move_name("Pot Helm Command")
	fight._place_overlays()
	var words_rect := Rect2(fight._float_groups[foe_key].position, fight._float_groups[foe_key].size)
	var title_rect := Rect2(fight.move_banner.position, fight.move_banner.size)
	_check(words_rect.position.y >= title_rect.end.y + 4.0
		and words_rect.end.y < fight.BAR_TOP - 90.0,
		"four stacked status words clear the held move title and bottom bar")
	fight._show_move_name("")
	_check(fight._beat_input_shield.get_index() == fight.get_child_count() - 1,
		"floating words cannot intercept the held input shield")
	fight._clear_float_words()
	_check(fight._float_groups.is_empty(), "callout cleanup releases the prior beat")
	fight._show_float_receipt(receipt)
	fight._cancel_beats()
	_check(fight._float_groups.is_empty(),
		"interrupting a held beat clears its words before a reduced-motion action")

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
	# A fourth foe's arrival is an actual rules receipt, not a guessed
	# announcement based on an empty rank suddenly becoming occupied.
	var new_foe := StitchedEnemyCatalog.foe_for(StitchedEnemyCatalog.load_catalog(), "ragling")
	var arrived := fight.battle.summon_foe(new_foe)
	fight.refresh()
	_check(bool(arrived.get("ok", false)) and str(arrived.get("action", "")) == "summon"
		and str(arrived.get("target", "")) == "ragling" and int(arrived.get("rank", 0)) == 4
		and _words(fight._float_events(arrived), "foe_4").has("SUMMONED!"),
		"a real fourth-foe summon receipt floats on the newly occupied seat")
	_check(fight.battle.rng_state() == rng and not bool(fight.battle.summon_foe(new_foe).get("ok", true)),
		"summoning uses no RNG and refuses an already occupied fourth seat")
	var invalid_arrival: Dictionary = arrived.duplicate(true)
	invalid_arrival["rank"] = 3
	_check(fight._float_events(invalid_arrival).is_empty(),
		"an arrival receipt for a different seat cannot float on its occupant")
	invalid_arrival["rank"] = 4
	invalid_arrival["ok"] = false
	_check(fight._float_events(invalid_arrival).is_empty(),
		"a refused arrival never announces itself")
	fight._start_beats([arrived])
	await physics_frame
	await physics_frame
	_check(fight._beats != null and fight._beats.is_running()
		and fight._float_groups.has("foe_4"),
		"summon arrival holds a visible floated word over the fourth seat")
	fight._cancel_beats()
	fight.battle._units.erase("ragling")
	var split_arrival := fight.battle.summon_foe(new_foe, "split")
	fight.refresh()
	_check(bool(split_arrival.get("ok", false))
		and _words(fight._float_events(split_arrival), "foe_4").has("SPLIT!"),
		"a rules-confirmed split arrival uses its own fourth-seat cue")
	fight.battle._units.erase("ragling")
	fight.refresh()
	_check(fight.battle.state_snapshot() == baseline and fight.battle.rng_state() == rng,
		"arrival callout checks leave the original preview battle untouched")
	# A dynamically admitted boss inherits the same no-retreat rule as one
	# authored at battle setup, even before it acts in the next round.
	var normal_config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	var normal_built := StitchedRules.create(normal_config)
	_check(bool(normal_built.get("ok", false)), "ordinary setup for a summoned boss succeeds")
	if bool(normal_built.get("ok", false)):
		var boss_battle: StitchedRules = normal_built.battle
		var boss_entry := StitchedEnemyCatalog.foe_for(StitchedEnemyCatalog.load_catalog(), "patchwork_behemoth")
		var boss_arrival := boss_battle.summon_foe(boss_entry)
		_check(bool(boss_arrival.get("ok", false)) and boss_battle.is_boss_encounter(),
			"summoning a valid boss marks the encounter as a boss fight")
		for attempt in range(20):
			if boss_battle.current_side() == "hero":
				break
			if not bool(boss_battle.pass_turn().get("ok", false)):
				break
		var before_boss_retreat := boss_battle.state_snapshot()
		var boss_retreat := boss_battle.retreat()
		_check(boss_battle.current_side() == "hero" and not bool(boss_retreat.get("ok", false))
			and str(boss_retreat.get("error", "")).contains("boss")
			and boss_battle.state_snapshot() == before_boss_retreat,
			"a summoned boss refuses retreat without changing state or RNG")
	# Accessibility: reduced motion must not erase confirmed pass ticks or the
	# final kill. Words fade in place while the stage only pulses its lighting.
	screen.reduced_motion = true
	fight._seen_receipts = screen.receipts.size()
	screen.receipts.append(passed)
	fight._play_new_receipts()
	_check(fight._float_groups.has(foe_key) and fight._beats == null
		and fight.stage._spot_tween != null,
		"reduced-motion status-only pass shows a float and light, with no attack beat")
	screen.receipts.pop_back()
	fight._seen_receipts = screen.receipts.size()
	var reduced_miss := {"action": "ability", "ok": true, "actor": hero_id, "results": [
		{"target": foe_id, "target_side": "foe", "hit": false, "statuses": []}]}
	screen.receipts.append(reduced_miss)
	fight._play_new_receipts()
	var miss_shown := false
	if fight._float_groups.has(foe_key):
		for child in fight._float_groups[foe_key].get_children():
			if child is Label and child.text == "MISS":
				miss_shown = true
	_check(miss_shown and fight._beats == null,
		"reduced-motion miss shows a truthful MISS word without a held attack")
	screen.receipts.pop_back()
	fight._seen_receipts = screen.receipts.size()
	fight.battle._outcome = "victory"
	var reduced_finish := {"action": "ability", "ok": true, "actor": hero_id, "results": [
		{"target": foe_id, "target_side": "foe", "hit": true,
		"damage": 5, "target_hp": 0, "heap": {"rank": int(foe.rank)}, "statuses": []}]}
	screen.receipts.append(reduced_finish)
	fight._play_new_receipts()
	_check(_words(fight._float_events(reduced_finish), foe_key).has("UNSTITCHED!")
		and fight._float_groups.has(foe_key) and not fight._beat_input_shield.visible
		and fight.continue_button.get_index() == fight.get_child_count() - 1,
		"reduced-motion final kill floats above the foe without covering Continue")
	screen.receipts.pop_back()
	fight._seen_receipts = screen.receipts.size()
	fight._clear_float_words()
	fight.stage.end_spotlight(0.0)
	screen.reduced_motion = false
	fight.battle._outcome = "ongoing"
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
