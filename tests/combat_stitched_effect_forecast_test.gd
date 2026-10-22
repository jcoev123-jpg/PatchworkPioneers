extends SceneTree
## The forecast is compared with two independent real CombatStitchedCards plays.
## All fixtures are Rest-crafted from shipped cards and shipped starter rosters.

const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const BOMB := "tinker_scrap_bomb"
const BRACE := "warden_brace"
const MEND := "seamstress_mend"
const TUNE := "tinker_tune_up"

var checks := 0
var failures: Array[String] = []
var forecast := CombatStitchedEffectForecast.new()


func _initialize() -> void:
	_test_separate_targets()
	_test_late_failure_and_retry()
	_test_patches_and_both_orders()
	_test_support_and_area()
	_test_draw_and_seeded_replay()
	_test_rejections()
	_test_real_torn_and_mend()
	for failure in failures:
		printerr(failure)
	print("combat_stitched_effect_forecast_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(yes: bool, message: String) -> void:
	checks += 1
	if not yes:
		failures.append(message)


func _authored(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Array and not parsed.is_empty(), "real authored resource " + path)
	if not parsed is Array:
		return []
	for entry in parsed:
		_check(entry is Dictionary and entry.get("max_hp") is float
			and entry["max_hp"] == floor(entry["max_hp"]), "integral starter HP")
		entry["max_hp"] = int(entry["max_hp"])
	return parsed


func _fixture(first: String, second: String, seed_value: int = 9527) -> Dictionary:
	var catalogue := StarterCards.new()
	var a := catalogue.get_definition(first)
	var b := catalogue.get_definition(second)
	_check(not a.is_empty() and not b.is_empty() and a.owner != b.owner,
		"two genuine cross-owner half definitions")
	var starter_cards: Array[String] = [first, second, "warden_strike"]
	var rest := RunRestStitchCards.new(starter_cards, {}, 3)
	_check(rest.is_valid(), "valid Rest seed ledger")
	var choice := rest.choose_stitch(0, 1, rest.get_snapshot())
	_check(choice.get("ok", false) and rest.is_consumed()
		and choice.descriptor.half_ids == [first, second]
		and choice.descriptor.cost == mini(3, maxi(a.cost, b.cost) + 1)
		and choice.remaining_scraps == 0,
		"real three-scrap Rest creates ordered unupgradable composite")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new([choice.stitched_id], rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand == [choice.stitched_id], "held composite in seeded active turn")
	var party := CombatParty.new(_authored("res://data/heroes/starter_party.json"))
	var enemies := CombatEnemies.new(_authored("res://data/enemies/starter_enemies.json"))
	_check(party.is_valid() and enemies.is_valid()
		and party.get_hero(1).id == "warden" and party.get_hero(1).max_hp == 40
		and party.get_hero(2).id == "seamstress" and party.get_hero(2).max_hp == 30
		and party.get_hero(3).id == "tinker" and party.get_hero(3).max_hp == 26
		and enemies.get_enemy(1).id == "ragling" and enemies.get_enemy(1).hp == 12
		and enemies.get_enemy(2).id == "ragling_guard" and enemies.get_enemy(2).hp == 12,
		"actual three starter heroes and two 12-HP enemy slots")
	var attacks := CombatAttackCards.new()
	return {"rest": rest, "id": choice.stitched_id, "deck": deck,
		"party": party, "enemies": enemies, "attacks": attacks,
		"service": CombatStitchedCards.new(attacks),
		"wardrobe": null, "torn": null}


func _state(c: Dictionary) -> Dictionary:
	var a: CombatAttackCards = c.attacks
	return {
		"draw_pile": c.deck.draw_pile.duplicate(),
		"hand": c.deck.hand.duplicate(),
		"discard_pile": c.deck.discard_pile.duplicate(),
		"energy": c.deck.energy,
		"turn_active": c.deck.turn_active,
		"rng_seed": c.deck._rng.seed,
		"rng_state": c.deck._rng.state,
		"heroes": c.party.get_heroes(),
		"enemies": c.enemies.get_enemies(),
		"tinker_consumed": a._tinker._consumed,
		"patch_latches": {} if a._patches == null else a._patches.latch_snapshot(),
	}


func _whole(c: Dictionary) -> Dictionary:
	var a: CombatAttackCards = c.attacks
	return {
		"combat": _state(c),
		"rest": c.rest.get_snapshot(),
		"rest_consumed": c.rest.is_consumed(),
		"wardrobe": {} if c.wardrobe == null else c.wardrobe.get_snapshot(),
		"torn": {} if c.torn == null else c.torn.read_state(),
		"patch_active": {} if a._patches == null else a._patches.active_snapshot(),
		"support_wardrobe_snapshot": c.service._support._wardrobe_snapshot.duplicate(true),
		"support_torn_snapshot": c.service._support._torn_snapshot.duplicate(true),
	}


func _peek(c: Dictionary, first_target: Variant, second_target: Variant,
		expected: Variant = null) -> Dictionary:
	var receipt: Variant = c.rest.get_snapshot() if expected == null else expected
	return forecast.get_forecast(c.rest, receipt, c.deck, c.party, c.enemies,
		c.id, first_target, second_target, c.service)


func _real(c: Dictionary, a: int, b: int) -> Dictionary:
	return c.service.play_stitched(c.deck, c.party, c.enemies, c.rest, c.id, a, b)


func _compare(c: Dictionary, a: int, b: int, label: String) -> Dictionary:
	var before := _whole(c)
	var first := _peek(c, a, b)
	var second := _peek(c, a, b)
	_check(first.playable and first.halves.size() == 2
		and first.projected.size() > 0, label + ": full two-half forecast")
	_check(first == second, label + ": repeated unchanged forecast is deterministic")
	_check(_whole(c) == before, label + ": no original model, Rest, RNG, wardrobe or latch changed")
	if not first.playable:
		return first
	var real := _real(c, a, b)
	_check(real.ok and real.halves == first.halves, label + ": exact committed ordered half events")
	_check(_state(c) == first.projected, label + ": exact post-commit combat and RNG state")
	_check(c.rest.get_snapshot() == before.rest and
		(c.wardrobe == null or c.wardrobe.get_snapshot() == before.wardrobe),
		label + ": real play does not spend run scraps or wardrobe")
	# Returned nested dictionaries are truly independent, not shallow aliases.
	var clean := first.duplicate(true)
	first.halves[0]["ok"] = false
	first.projected.heroes[0]["hp"] = -99
	first.projected.enemies[0]["hp"] = -99
	_check(_peek_after_play_does_not_change_prior(second, clean),
		label + ": returned deep copies cannot alter older outcomes or real state")
	return clean


func _peek_after_play_does_not_change_prior(second: Dictionary, clean: Dictionary) -> bool:
	return second == clean and second.halves[0].ok and second.projected.heroes[0].hp >= 0


func _reject(c: Dictionary, a: Variant, b: Variant, label: String,
		expected: Variant = null) -> void:
	var before := _whole(c)
	var result := _peek(c, a, b, expected)
	_check(result == {"playable": false, "stitched_id": "", "cost": 0,
		"halves": [], "projected": {}}, label + ": atomic empty rejection")
	_check(_peek(c, a, b, expected) == result and _whole(c) == before,
		label + ": stable refusal, no input state or RNG/latch/ledger changes")


func _test_separate_targets() -> void:
	for seed_value in [7, 9527]:
		var c := _fixture(PRICK, POP, seed_value)
		var outcome := _compare(c, 1, 2, "Prick first / Pop second seed " + str(seed_value))
		_check(outcome.cost == 2 and outcome.projected.energy == 1
			and outcome.projected.discard_pile == [c.id]
			and outcome.projected.hand.is_empty(), "two cost-one halves charged once")
		_check(outcome.halves == [
			{"ok": true, "hits": [{"position": 1, "damage": 3,
				"block_absorbed": 0, "hp_loss": 3, "statuses": {"bleed": 3}}]},
			{"ok": true, "hits": [{"position": 2, "damage": 8,
				"block_absorbed": 0, "hp_loss": 8, "statuses": {}}]}],
			"Prick 3/Bleed 3 and first Pop 8 exact events")
		_check(outcome.projected.enemies[0].hp == 9
			and outcome.projected.enemies[1].hp == 4
			and outcome.projected.tinker_consumed, "enemy slots and Tinker latch")
		var backwards := _fixture(POP, PRICK, seed_value)
		var reverse := _compare(backwards, 2, 1, "Pop then Prick seed " + str(seed_value))
		_check(reverse.halves[0].hits[0].damage == 8
			and reverse.halves[1].hits[0].statuses == {"bleed": 3},
			"authored order preserved both ways")


func _test_late_failure_and_retry() -> void:
	var c := _fixture(PRICK, POP)
	_check(c.enemies.apply_damage(1, 9) and c.enemies.get_enemy(1).hp == 3
		and c.enemies.get_enemy(2).hp == 12, "real first target in lethal range")
	var offered := CombatStitchedTargetPreview.new().get_preview(c.rest,
		c.rest.get_snapshot(), c.deck, c.party, c.enemies, c.id)
	_check(offered.playable and offered.second_half.target_positions.has(1),
		"late-slain target originally selectable")
	_reject(c, 1, 1, "late second-half target dies from first Prick")
	var good := _compare(c, 1, 2, "legal retry after late failure")
	_check(good.playable and good.projected.enemies[0].hp == 0
		and good.projected.enemies[1].hp == 4, "legal retry commits one composite")
	c = _fixture(PRICK, POP)
	c.enemies.apply_damage(1, 12)
	_reject(c, 1, 2, "already slain first target")
	c = _fixture(PRICK, POP)
	c.enemies.apply_damage(2, 12)
	_reject(c, 1, 2, "already slain second target")


func _patches(c: Dictionary) -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(records is Array, "authored M04 patch catalog")
	var definitions: Array = []
	for entry in records:
		if entry.get("id") in ["button_eye", "pincushion_arm"]:
			definitions.append({"id": entry.id, "slot": entry.slot})
	_check(definitions.size() == 2, "both authored attack patches present")
	var torn := RunTornMending.new(c.party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(),
		["button_eye", "pincushion_arm"], definitions, 4)
	_check(wardrobe.is_valid() and torn.is_valid(), "genuine wardrobe and tear services")
	_check(wardrobe.sew("button_eye", "seamstress", "HEAD", "forecast-eye",
		wardrobe.get_snapshot()).ok, "sew real Button Eye to Seamstress")
	_check(wardrobe.sew("pincushion_arm", "tinker", "ARM", "forecast-arm",
		wardrobe.get_snapshot()).ok, "sew real Pincushion Arm to Tinker")
	_check(c.attacks.bind_patch_wardrobe(wardrobe, torn)
		and c.service.bind_patch_wardrobe(wardrobe, torn),
		"existing attack and support transactions bind genuine patch ledgers")
	c.wardrobe = wardrobe
	c.torn = torn


func _test_patches_and_both_orders() -> void:
	for seed_value in [9, 9527]:
		for reversed in [false, true]:
			var c := _fixture(POP if reversed else PRICK,
				PRICK if reversed else POP, seed_value)
			_patches(c)
			var before := _whole(c)
			var result := _compare(c, 1, 1,
				"actual wearer Exposed and ARM, reversed=" + str(reversed))
			_check(result.playable and before.patch_active.seamstress == ["button_eye"]
				and before.patch_active.tinker == ["pincushion_arm"],
				"real patch snapshot has correct distinct wearers")
			if reversed:
				_check(result.halves[0].hits[0].damage == 9
					and result.halves[1].hits[0].damage == 3
					and result.projected.enemies[0].statuses ==
						{"bleed": 3, "exposed": 1},
					"first Pop gets 5+3+1, later Prick grants Exposed")
			else:
				_check(result.halves[0].hits[0].statuses ==
						{"bleed": 3, "exposed": 1}
					and result.halves[1].hits[0].damage == 13
					and result.halves[1].hits[0].hp_loss == 9,
					"Exposed from Prick amplifies second Pop to floor(13.5)=13")
			_check(result.projected.patch_latches.seamstress
				and result.projected.tinker_consumed,
				"forecast projects consumed first-combat/turn latches")
	# An already-used Tinker latch must be forecast as already used.
	var spent := _fixture(PRICK, POP)
	_patches(spent)
	spent.attacks._tinker._consumed = true
	spent.attacks._patches._consumed.seamstress = true
	var saved := _whole(spent)
	var depleted := _compare(spent, 1, 2, "inherited prior Tinker/HEAD latch")
	_check(depleted.halves[0].hits[0].statuses == {"bleed": 3}
		and depleted.halves[1].hits[0].damage == 6
		and saved.combat.tinker_consumed, "no imaginary first attack reactivation")


func _test_support_and_area() -> void:
	for reverse in [false, true]:
		var c := _fixture(MEND if reverse else BRACE, BRACE if reverse else MEND)
		_check(c.party.apply_damage(3, 3) and c.party.get_hero(3).hp == 23,
			"capped Mend recipient starts down 3 HP")
		var result := _compare(c, 3 if reverse else 0,
			0 if reverse else 3, "Brace/Mend ordered support")
		_check(result.projected.heroes[0].block == 7
			and result.projected.heroes[2].hp == 26
			and result.projected.energy == 1,
			"+7 self Block, healing capped at max HP, one charge")
	var c := _fixture(PRICK, BOMB)
	var result := _compare(c, 1, 0, "Prick then target-free Scrap Bomb")
	_check(result.cost == 3 and result.projected.energy == 0
		and result.projected.enemies[0].hp == 2
		and result.projected.enemies[1].hp == 5
		and result.halves[1].hits.size() == 2
		and result.halves[1].hits[0].damage == 7
		and result.halves[1].hits[1].damage == 7,
		"7-damage Tinker bomb on every living eligible slot")
	c = _fixture(PRICK, BOMB)
	_check(c.enemies.apply_damage(1, 9), "first hit kills the first Bomb slot")
	var survivors := _compare(c, 1, 0, "Bomb skips newly slain target")
	_check(survivors.halves[1].hits.size() == 1
		and survivors.halves[1].hits[0].position == 2,
		"authoritative area resolver excludes first-half kill")
	c = _fixture(BOMB, PRICK)
	var backward := _compare(c, 0, 2, "Bomb then Prick reverse order")
	_check(backward.halves[0].hits.size() == 2
		and backward.halves[1].hits[0].position == 2,
		"reverse order uses target-free half first")


func _test_draw_and_seeded_replay() -> void:
	for seed_value in [0, 101, 9527]:
		var copies: Array = []
		for duplicate in range(2):
			var c := _fixture(TUNE, "seamstress_stitch_up", seed_value)
			c.deck.draw_pile.clear()
			c.deck.discard_pile.assign(["warden_strike", PRICK, BRACE])
			var before := _whole(c)
			var outcome := _compare(c, 0, 1, "seeded reshuffle " + str(seed_value))
			_check(outcome.playable and outcome.projected.hand.size() == 1
				and outcome.projected.discard_pile == [c.id]
				and outcome.projected.rng_state != before.combat.rng_state
				and outcome.projected.heroes[0].block == 5
				and outcome.projected.energy == 1,
				"Tune Up draws one after seeded Fisher-Yates reshuffle")
			copies.append(outcome)
		_check(copies[0] == copies[1], "independent real/rest RNG matches for seed " + str(seed_value))
	var no_refill := _fixture(TUNE, BRACE)
	no_refill.deck.draw_pile.assign([POP])
	var direct := _compare(no_refill, 0, 0, "Tune Up direct draw")
	_check(direct.projected.hand == [POP] and direct.projected.discard_pile == [no_refill.id],
		"no redraw of self/composite, original pile consumed")


func _test_rejections() -> void:
	var c := _fixture(PRICK, POP)
	_reject(c, 0, 2, "missing first target")
	_reject(c, 1, 0, "missing late target after first hit")
	_reject(c, 1, 3, "unoccupied second slot")
	_reject(c, 4, 2, "out-of-range first target")
	_reject(c, "1", 2, "wrong target Variant type")
	var stale: Dictionary = c.rest.get_snapshot()
	stale.remaining_scraps += 1
	_reject(c, 1, 2, "stale Rest optimistic receipt", stale)
	_check(_compare(c, 1, 2, "legal real play after every rejected target").playable,
		"rejections never prevent legitimate committed card")
	c = _fixture(PRICK, POP)
	c.deck.try_spend_energy(2)
	_reject(c, 1, 2, "insufficient energy")
	c = _fixture(PRICK, POP)
	c.deck.end_turn()
	_reject(c, 1, 2, "inactive turn")
	c = _fixture(PRICK, POP)
	c.deck.discard_played(c.id)
	_reject(c, 1, 2, "unheld composite")
	c = _fixture(PRICK, POP)
	var forged: Dictionary = c.rest.get_snapshot()
	forged.descriptors[c.id].second_half.effects.damage = 999
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors, 0, 2)
	_check(not c.rest.is_valid(), "forged Rest descriptor genuinely invalid")
	_reject(c, 1, 2, "forged Rest descriptor")
	for owner in [2, 3]:
		c = _fixture(PRICK, POP)
		_check(c.party.apply_damage(owner, c.party.get_hero(owner).hp)
			and c.party.is_downed(owner), "real downed original owner")
		_reject(c, 1, 2, "downed/torn owner " + str(owner))
	c = _fixture(PRICK, BOMB)
	var slots: Array = c.party.get_heroes()
	c.party = CombatParty.new([slots[0], slots[2], slots[1]])
	_check(c.party.get_hero(2).id == "tinker", "wrong original Tinker from slot")
	_reject(c, 1, 0, "wrong from-position for second half")
	c = _fixture("warden_strike", POP)
	slots = c.party.get_heroes()
	c.party = CombatParty.new([slots[2], slots[1], slots[0]])
	_reject(c, 1, 2, "wrong from-position for first half")
	c = _fixture(PRICK, "warden_shield_bash")
	_reject(c, 2, 2, "forbidden authored Warden second target")
	c = _fixture(PRICK, POP)
	c.enemies._enemies[0]["statuses"] = {"bleed": CombatEnemies.MAX_INT}
	_reject(c, 1, 2, "early overflow rejects before any forecast outcome")
	c = _fixture(PRICK, "warden_shield_bash")
	c.enemies._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	_reject(c, 2, 1, "late status overflow rolls back first-half damage")
	c = _fixture(PRICK, POP)
	var before := _whole(c)
	_check(not forecast.get_forecast(null, c.rest.get_snapshot(), c.deck,
		c.party, c.enemies, c.id, 1, 2).playable
		and not forecast.get_forecast(c.rest, c.rest.get_snapshot(), null,
			c.party, c.enemies, c.id, 1, 2).playable
		and _whole(c) == before, "null run ledger/deck fail safely")


func _test_real_torn_and_mend() -> void:
	var c := _fixture(PRICK, POP)
	_patches(c)
	var start: Array = c.torn.read_state().heroes
	var end := start.duplicate(true)
	end[1]["hp"] = 0
	_check(c.torn.observe_battle_end("real-tear", start, end).ok,
		"real battle tear downs the sewn Button Eye owner")
	var worn: Dictionary = c.wardrobe.get_snapshot()
	_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes,
		worn.owned, worn.scraps, worn.gold, worn.cards, worn),
		"refresh real patch context from torn roster")
	c.party._heroes.assign(c.torn.read_state().heroes)
	_check(c.wardrobe.project_active(c.torn.read_state()).active.seamstress.is_empty()
		and c.wardrobe.get_snapshot().worn.seamstress.HEAD == "button_eye",
		"torn wearer retains sewing but cannot use the patch")
	_check(c.attacks.bind_patch_wardrobe(c.wardrobe, c.torn)
		and c.service.bind_patch_wardrobe(c.wardrobe, c.torn),
		"torn attack and support projections bind")
	_reject(c, 1, 2, "genuine torn/downed owner may not play the composite")
	var run_state: Dictionary = c.torn.read_state()
	var mended: Dictionary = c.torn.choose_mend("real-mend", "fresh-mend-receipt",
		"seamstress", 2, 2, run_state.heroes, true)
	_check(mended.ok and mended.heroes[1].hp > 0
		and mended.heroes[1].max_hp == 27,
		"real two-scrap torn mending restores living Seamstress")
	worn = c.wardrobe.get_snapshot()
	_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes,
		worn.owned, worn.scraps, worn.gold, worn.cards, worn),
		"refresh restored wearer from real mend")
	c.party._heroes.assign(c.torn.read_state().heroes)
	_check(c.attacks.bind_patch_wardrobe(c.wardrobe, c.torn)
		and c.service.bind_patch_wardrobe(c.wardrobe, c.torn),
		"fresh battle rebinds restored wearer")
	var healed := _compare(c, 1, 2, "real sewn owner mended then played")
	_check(healed.playable and healed.halves[0].hits[0].statuses ==
		{"bleed": 3, "exposed": 1}
		and healed.halves[1].hits[0].damage == 9,
		"restored Button Eye and ARM powers return on their genuine owners")
