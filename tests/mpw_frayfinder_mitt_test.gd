extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_catalog()
	_thresholds()
	_commit_and_turns()
	_negative_attempts()
	_torn_and_mended()
	_stitched_halves()
	_mixed_stitched_halves()
	for failure in failures:
		printerr(failure)
	print("mpw_frayfinder_mitt_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _party_defs() -> Array:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	_check(typeof(source) == TYPE_ARRAY and source.size() == 3, "authored hero roster")
	for actor in source:
		actor.max_hp = int(actor.max_hp)
	return source


func _deck_ids() -> Array[String]:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/cards/starter_deck.json"))
	var ids: Array[String] = []
	ids.assign(source)
	_check(ids.size() == 12 and ids.has("warden_strike")
		and ids.has("tinker_pop_shot"), "genuine 12-card shared starter deck")
	return ids


func _catalog() -> void:
	var m05: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_attack_patches.json"))
	var m04: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(typeof(m05) == TYPE_ARRAY and typeof(m04) == TYPE_ARRAY, "two readable catalogs")
	if typeof(m05) != TYPE_ARRAY or typeof(m04) != TYPE_ARRAY:
		return
	var found := []
	for record in m05:
		if record.get("id") == "frayfinder_mitt":
			found.append(record)
	_check(found.size() == 1, "unique Frayfinder ID independent of catalog size")
	if found.size() == 1:
		var p: Dictionary = found[0]
		_check(p.slot == "ARM" and p.effect == "first_single_target_half_unravel_attack_bonus"
			and p.amount == 2 and p.minimum_unravel_numerator == 1
			and p.minimum_unravel_denominator == 2 and p.once_per_player_turn == true
			and p.hit_number == 1 and p.target_kind == "enemy_single",
			"exact M05 ARM numeric first-hit half-threshold contract")
	var ids := {}
	for record in m04:
		ids[record.id] = record
	_check(ids.has("button_eye") and ids.has("pincushion_arm"),
		"existing M04 ids retained without total/order assumption")
	if ids.has("button_eye") and ids.has("pincushion_arm"):
		_check(ids.button_eye.slot == "HEAD" and ids.button_eye.amount == 1
			and ids.button_eye.effect == "first_attack_exposed"
			and ids.pincushion_arm.slot == "ARM" and ids.pincushion_arm.amount == 1
			and ids.pincushion_arm.effect == "card_attack_bonus",
			"original M04 rules unchanged")


func _fight(wearer: String = "warden", seed_value: int = 919,
		with_patch: bool = true, torn: RunTornMending = null) -> Dictionary:
	var defs := _party_defs()
	var party := CombatParty.new(defs)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(_deck_ids(), rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.hand.size() == 5,
		"seeded real turn opens with 3 energy and exactly 5 draws")
	# Extra real draws make specific attack IDs available without injecting a
	# card into the hand or inventing an alternate deck authority.
	_check(deck.draw_extra(7) == 7, "remaining seven drawn via CombatDeck")
	var enemies := CombatEnemies.new([
		{"id": "ragling", "max_hp": 60},
		{"id": "elite_guard", "max_hp": 60},
		{"id": "boss_behemoth", "max_hp": 60}
	])
	var gauge := CombatUnravel.new()
	_check(party.is_valid() and enemies.is_valid()
		and gauge.bind_roster(enemies, {1: "normal", 2: "elite", 3: "boss"}),
		"genuine living party and bound normal elite boss roster")
	if torn == null:
		torn = RunTornMending.new(CombatParty.new(defs).get_heroes())
	var m04: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	var m05: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_attack_patches.json"))
	var patch_defs := []
	for authored in m04 + m05:
		patch_defs.append({"id": authored.id, "slot": authored.slot})
	var wardrobe := RunPatchWardrobe.new(CombatParty.new(defs).get_heroes(),
		["frayfinder_mitt", "pincushion_arm", "button_eye"], patch_defs, 0, 5,
		["warden_strike"], seed_value)
	_check(wardrobe.is_valid() and torn.is_valid(), "actual owned patch and run torn ledger")
	if with_patch:
		var sewing := wardrobe.sew("frayfinder_mitt", wearer, "ARM",
			"sew_mitt", wardrobe.get_snapshot())
		_check(sewing.ok and sewing.receipt.slot == "ARM"
			and wardrobe.get_snapshot().worn[wearer].ARM == "frayfinder_mitt",
			"genuine sewn ARM transaction with canonical receipt")
	var rule := CombatFrayfinderMitt.new()
	_check(rule.bind_battle(deck, party, enemies, gauge, wardrobe, torn)
		and rule.begin_player_turn(), "valid service bound to same authorities and active turn")
	return {"deck": deck, "party": party, "enemies": enemies, "gauge": gauge,
		"wardrobe": wardrobe, "torn": torn, "rule": rule, "rng": rng}


func _state(f: Dictionary) -> Array:
	var deck: CombatDeck = f.deck
	return [f.party.get_heroes(), f.enemies.get_enemies(), deck.draw_pile.duplicate(),
		deck.hand.duplicate(), deck.discard_pile.duplicate(), deck.energy,
		deck.turn_active, f.rng.seed, f.rng.state, f.wardrobe.get_snapshot(),
		f.torn.read_state(), f.gauge.get_snapshot(1), f.gauge.get_snapshot(2),
		f.gauge.get_snapshot(3), f.rule.latch_snapshot()]


func _unchanged(f: Dictionary, label: String, action: Callable) -> void:
	var before := _state(f)
	action.call()
	_check(_state(f) == before, label + " leaves party/enemies/piles/energy/run/gauges/RNG/latches identical")


func _thresholds() -> void:
	for tier_case in [[1, 4, 8], [2, 6, 12], [3, 8, 16]]:
		for just_below in [true, false]:
			var f := _fight("seamstress" if tier_case[0] == 3 else "warden")
			var slot: int = tier_case[0]
			var amount: int = tier_case[1] - (1 if just_below else 0)
			_check(f.gauge.get_snapshot(slot).threshold == tier_case[2]
				and f.gauge.apply_unravel(f.enemies, slot, amount), "real tier and charge")
			var before := _state(f)
			var quoted: Dictionary = f.rule.quote_starter_hit(
				"seamstress_prick" if slot == 3 else "warden_strike", slot)
			_check(quoted.get("bonus") == (0 if just_below else 2)
				and f.gauge.get_snapshot(slot).gauge == amount,
				"threshold boundary position %d gauge %d/%d" % [slot, amount, tier_case[2]])
			_check(before == _state(f), "threshold quote is completely read-only")
	var raised := _fight()
	_check(raised.gauge.apply_unravel(raised.enemies, 1, 8)
		and raised.gauge.consume_action_skip(raised.enemies, 1)
		and raised.gauge.get_snapshot(1).threshold == 12,
		"normal Unravel skip resets to real raised threshold 12")
	_check(raised.gauge.apply_unravel(raised.enemies, 1, 5)
		and raised.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
		"raised 5/12 does not earn bonus")
	_check(raised.gauge.apply_unravel(raised.enemies, 1, 1)
		and raised.rule.quote_starter_hit("warden_strike", 1).bonus == 2,
		"raised 6/12 does earn +2")


func _commit_and_turns() -> void:
	var f := _fight()
	_check(f.gauge.apply_unravel(f.enemies, 1, 4), "pre-hit half gauge")
	var before := _state(f)
	var first: Dictionary = f.rule.quote_starter_hit("warden_strike", 1)
	var repeat: Dictionary = f.rule.quote_starter_hit("warden_strike", 1)
	_check(first.bonus == 2 and repeat == first, "repeat preview quotes same +2 without spending")
	_check(not f.rule.consume_confirmed_hit(first, {"ok": true, "hits": []})
		and _state(f) == before, "preview-only counterfeit receipt cannot consume")
	var result: Dictionary = CombatAttackCards.new().play_attack(
		f.deck, f.party, f.enemies, "warden_strike", 1)
	_check(result.ok and result.hits.size() == 1 and result.hits[0].hp_loss > 0,
		"real confirmed starter attack changes HP and discards exactly once")
	_check(f.rule.consume_confirmed_hit(first, result)
		and f.rule.latch_snapshot().get("warden") == true,
		"only valid confirmed receipt consumes wearer latch")
	_check(not f.rule.consume_confirmed_hit(first, result), "receipt replay refused")
	_check(f.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
		"same owner later attack never gets bonus")
	_check(not f.rule.begin_player_turn(), "hover/preview cannot reset active turn")
	_check(f.deck.end_turn() and f.rule.end_player_turn(), "real turn closes before latch reset")
	_check(f.deck.start_turn() and f.deck.energy == 3 and f.rule.begin_player_turn()
		and f.rule.latch_snapshot().is_empty(), "new real 3-energy turn resets latch")
	_check(f.deck.draw_extra(7) >= 0 and f.rule.quote_starter_hit(
		"warden_strike", 1).bonus == 2, "new turn requalifies under retained half gauge")


func _negative_attempts() -> void:
	var f := _fight()
	_check(f.gauge.apply_unravel(f.enemies, 1, 4), "negative fixture half gauge")
	_unchanged(f, "area or target-free", func():
		_check(f.rule.quote_starter_hit("tinker_scrap_bomb", 1).bonus == 0,
			"area card never qualifies even with one selected target"))
	_unchanged(f, "later multi-hit", func():
		_check(f.rule.quote_starter_hit("warden_strike", 1, 2).bonus == 0,
			"second hit cannot multiply +2"))
	_unchanged(f, "other two owners", func():
		_check(f.rule.quote_starter_hit("seamstress_prick", 1).bonus == 0
			and f.rule.quote_starter_hit("tinker_pop_shot", 1).bonus == 0,
			"unpatched Seamstress and Tinker cannot borrow Warden ARM"))
	_unchanged(f, "no target", func():
		_check(f.rule.quote_starter_hit("warden_strike", 9).bonus == 0,
			"invalid target refuses"))
	_unchanged(f, "unheld or unknown card", func():
		_check(f.rule.quote_starter_hit("not_a_card", 1).bonus == 0,
			"nonexistent card rejected"))
	var q: Dictionary = f.rule.quote_starter_hit("warden_strike", 1)
	_check(not f.rule.consume_confirmed_hit(q, {"ok": false, "hits": []}),
		"refused hit does not consume")
	var foreign := CombatEnemies.new([{"id": "other", "max_hp": 10}])
	f.gauge._bound_enemies = foreign
	_unchanged(f, "wrong roster", func():
		_check(f.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
			"wrong roster fails closed"))
	f.gauge._bound_enemies = f.enemies
	_check(f.rule.quote_starter_hit("warden_strike", 1).bonus == 2,
		"restored correct roster remains usable")
	_check(f.party.apply_damage(1, 40) and f.party.is_downed(1),
		"party owner currently downed despite run carryover living")
	_unchanged(f, "downed CombatParty", func():
		_check(f.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
			"currently downed owner cannot gain bonus"))
	var low := _fight()
	_check(low.deck.try_spend_energy(3) and low.deck.energy == 0,
		"real deck depleted by genuine spend API")
	_unchanged(low, "insufficient energy", func():
		_check(low.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
			"uncommitted unaffordable hit never quotes"))
	var slain := _fight()
	_check(slain.gauge.apply_unravel(slain.enemies, 1, 4)
		and slain.enemies.apply_damage(1, 60), "actual slain target")
	_unchanged(slain, "slain target", func():
		_check(slain.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
			"slain enemy never qualifies"))
	var none := _fight("warden", 923, false)
	_check(none.gauge.apply_unravel(none.enemies, 1, 4)
		and none.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
		"owned but unsewn Frayfinder is not active")
	_check(none.wardrobe.sew("pincushion_arm", "warden", "ARM",
		"pin", none.wardrobe.get_snapshot()).ok,
		"genuine alternative ARM is sewn")
	_check(none.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
		"alternative ARM cannot grant Frayfinder")


func _torn_and_mended() -> void:
	var initial := CombatParty.new(_party_defs()).get_heroes()
	var torn := RunTornMending.new(initial)
	var ending: Array = initial.duplicate(true)
	ending[0].hp = 0
	_check(torn.observe_battle_end("fight_tear", initial, ending).ok
		and torn.read_state().tear_counts.warden == 1
		and torn.read_state().heroes[0].hp == 0, "real run tear recorded")
	var masked := _fight("warden", 127, true, torn)
	_check(masked.gauge.apply_unravel(masked.enemies, 1, 4)
		and masked.rule.quote_starter_hit("warden_strike", 1).bonus == 0,
		"currently TORN run wearer is inactive, although combat HP is positive")
	var mend := torn.choose_mend("map_mend", "receipt_mend", "warden", 1,
		2, torn.read_state().heroes, true)
	_check(mend.ok and torn.read_state().tear_counts.warden == 1
		and torn.read_state().heroes[0].hp > 0, "real paid mend reactivates prior tear")
	var restored := _fight("warden", 128, true, torn)
	_check(restored.gauge.apply_unravel(restored.enemies, 1, 4)
		and restored.rule.quote_starter_hit("warden_strike", 1).bonus == 2,
		"past tear count does not suppress living mended wearer")


func _stitched_halves() -> void:
	for first_owner in ["warden", "tinker"]:
		var ids := ["warden_strike", "tinker_pop_shot"]
		var rest := RunRestStitchCards.new(ids, {}, 3)
		_check(rest.is_valid(), "real Rest stitch authority initialized")
		var stitched := rest.choose_stitch(1, 0, rest.get_snapshot())
		_check(stitched.ok and stitched.descriptor.owners == ["tinker", "warden"],
			"authentic composite preserves first Tinker then Warden owner order")
		var rng := RandomNumberGenerator.new()
		rng.seed = 107
		var deck := CombatDeck.new([stitched.stitched_id], rng)
		var party := CombatParty.new(_party_defs())
		var enemies := CombatEnemies.new([
			{"id": "normal_a", "max_hp": 60},
			{"id": "normal_b", "max_hp": 60}])
		var gauge := CombatUnravel.new()
		_check(gauge.bind_roster(enemies, {1: "normal", 2: "normal"})
			and deck.start_turn() and deck.hand.has(stitched.stitched_id),
			"real held two-owner stitched attack and bound combat roster")
		var torn := RunTornMending.new(CombatParty.new(_party_defs()).get_heroes())
		var wd := RunPatchWardrobe.new(CombatParty.new(_party_defs()).get_heroes(),
			["frayfinder_mitt"], [{"id": "frayfinder_mitt", "slot": "ARM"}], 0)
		_check(wd.sew("frayfinder_mitt", first_owner, "ARM", "stitch_sew",
			wd.get_snapshot()).ok, "only intended stitched owner wears ARM")
		var rule := CombatFrayfinderMitt.new()
		_check(rule.bind_battle(deck, party, enemies, gauge, wd, torn)
			and rule.begin_player_turn(), "stitched battle service bound")
		_check(gauge.apply_unravel(enemies, 1, 4)
			and gauge.apply_unravel(enemies, 2, 4), "both real pre-hit gauges half")
		var first: Dictionary = rule.quote_stitched_half(rest, stitched.stitched_id, 0, 1)
		var second: Dictionary = rule.quote_stitched_half(rest, stitched.stitched_id, 1, 2)
		_check(first.get("owner") == "tinker" and second.get("owner") == "warden"
			and first.bonus == (2 if first_owner == "tinker" else 0)
			and second.bonus == (2 if first_owner == "warden" else 0),
			"ordered halves consult own ARM without borrowing or doubling")
		var pre := [party.get_heroes(), enemies.get_enemies(), deck.energy,
			deck.hand.duplicate(), deck.discard_pile.duplicate(), rng.state]
		var played := CombatStitchedCards.new().play_stitched(deck, party, enemies,
			rest, stitched.stitched_id, 1, 2)
		_check(played.ok and played.halves.size() == 2
			and played.halves[0].hits[0].position == 1
			and played.halves[1].hits[0].position == 2,
			"actual committed stitched play resolves first then second")
		_check(not rule.consume_confirmed_hit(second, played, rest),
			"out-of-order second half cannot confirm before first")
		_check(rule.consume_confirmed_hit(first, played, rest)
			and rule.consume_confirmed_hit(second, played, rest),
			"each original half confirmed in owner order")
		_check(not rule.consume_confirmed_hit(first, played, rest)
			and rule.latch_snapshot().size() == 1
			and rule.latch_snapshot().get(first_owner) == true,
			"stitched receipt replay denied and only true wearer latched")
		_check(party.get_heroes() == pre[0] and rng.state == pre[5]
			and deck.energy == pre[2] - stitched.descriptor.cost
			and deck.hand.is_empty() and deck.discard_pile == [stitched.stitched_id],
			"service itself has no energy/pile/RNG/party effects; resolver owns commit")

func _mixed_stitched_halves() -> void:
	for pair in [
		["warden_strike", "seamstress_mend", "ally_heal"],
		["warden_strike", "seamstress_stitch_up", "ally_block"],
		["tinker_tune_up", "warden_strike", "draw"]
	]:
		var label: String = str(pair[0]) + "/" + str(pair[1])
		var attack_index := 0 if pair[0] == "warden_strike" else 1
		var support_index := 1 - attack_index
		var rest := RunRestStitchCards.new([pair[0], pair[1], "warden_strike"], {}, 3)
		_check(rest.is_valid(), label + ": authentic Rest authority")
		var stitched := rest.choose_stitch(0, 1, rest.get_snapshot())
		_check(stitched.ok and stitched.descriptor.owners.size() == 2
			and stitched.descriptor.owners[0] != stitched.descriptor.owners[1],
			label + ": real distinct-owner ordered descriptor")
		var id: String = stitched.stitched_id
		var rng := RandomNumberGenerator.new()
		rng.seed = 4901
		var deck := CombatDeck.new([id, "warden_strike"], rng)
		_check(deck.start_turn() and deck.energy == 3 and deck.hand.has(id)
			and deck.hand.has("warden_strike"), label + ": real active hand and follow-up card")
		deck.discard_pile.assign(["seamstress_prick", "warden_brace"])
		var party := CombatParty.new(_party_defs())
		_check(party.apply_damage(3, 9), label + ": wounded ally")
		var enemies := CombatEnemies.new([{"id": "ragling", "max_hp": 80}])
		var gauge := CombatUnravel.new()
		_check(gauge.bind_roster(enemies, {1: "normal"})
			and gauge.apply_unravel(enemies, 1, 4), label + ": real 4/8 Unravel gauge")
		var torn := RunTornMending.new(CombatParty.new(_party_defs()).get_heroes())
		var wardrobe := RunPatchWardrobe.new(CombatParty.new(_party_defs()).get_heroes(),
			["frayfinder_mitt"], [{"id": "frayfinder_mitt", "slot": "ARM"}], 0)
		_check(wardrobe.sew("frayfinder_mitt", "warden", "ARM", "mixed_sew",
			wardrobe.get_snapshot()).ok, label + ": real sewn Warden ARM")
		var rule := CombatFrayfinderMitt.new()
		_check(rule.bind_battle(deck, party, enemies, gauge, wardrobe, torn)
			and rule.begin_player_turn(), label + ": bound live model instances")
		var support: Dictionary = rest.preview_play(id, party.get_heroes()).halves[support_index]
		_check(support.target_kind not in ["enemy_single", "enemy_all"],
			label + ": genuine support half")
		var quote := rule.quote_stitched_half(rest, id, attack_index, 1)
		_check(quote.get("bonus") == 2 and quote.get("owner") == "warden"
			and quote.has("seal"), label + ": actual attack quoted +2")
		_check(not rule.quote_stitched_half(rest, id, support_index, 3).has("seal"),
			label + ": support cannot invent attack quote")
		var prior := party.get_hero(3)
		var rng_before := rng.state
		var hand_before := deck.hand.size()
		var first_target := 1 if attack_index == 0 else 0
		var second_target := 3 if attack_index == 0 else 1
		var played := CombatStitchedCards.new().play_stitched(deck, party, enemies,
			rest, id, first_target, second_target)
		_check(played.ok and played.halves.size() == 2
			and played.halves[attack_index].hits.size() == 1
			and played.halves[attack_index].hits[0].position == 1,
			label + ": true successful mixed stitched commit")
		_check(played.halves[support_index].get("effect") == pair[2]
			and not played.halves[support_index].has("hits"),
			label + ": successful support reports an effect, not attack hits")
		match pair[2]:
			"ally_heal":
				_check(party.get_hero(3).hp == prior.hp + 5, label + ": real healing")
			"ally_block":
				_check(party.get_hero(3).block == prior.block + 5, label + ": real Block")
			"draw":
				_check(deck.hand.size() == hand_before and rng.state != rng_before,
					label + ": genuine draw and seeded shuffle advance RNG")
		var tampered := played.duplicate(true)
		tampered.halves[support_index].amount += 1
		var unchanged := [party.get_heroes(), enemies.get_enemies(), deck.hand.duplicate(),
			deck.draw_pile.duplicate(), deck.discard_pile.duplicate(), deck.energy,
			rng.state, rule.latch_snapshot()]
		_check(not rule.consume_confirmed_hit(quote, tampered, rest)
			and unchanged == [party.get_heroes(), enemies.get_enemies(), deck.hand,
			deck.draw_pile, deck.discard_pile, deck.energy, rng.state, rule.latch_snapshot()],
			label + ": counterfeit support receipt preserves all authorities")
		_check(rule.consume_confirmed_hit(quote, played, rest)
			and rule.latch_snapshot() == {"warden": true}
			and rule._stitched_sequence.get(id) == 2,
			label + ": authentic support advances sequence and attack spends once")
		_check(not rule.consume_confirmed_hit(quote, played, rest),
			label + ": replay denied")
		_check(rule.quote_starter_hit("warden_strike", 1).get("bonus") == 0,
			label + ": already-spent wearer cannot claim follow-up +2")
		var next := CombatAttackCards.new().play_attack(deck, party, enemies,
			"warden_strike", 1)
		_check(next.ok and next.hits.size() == 1 and rule.latch_snapshot() == {"warden": true},
			label + ": same-owner follow-up really commits without resetting latch")
