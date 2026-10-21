extends SceneTree

const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const BOMB := "tinker_scrap_bomb"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_pairs()
	_test_all_authored_pairs()
	_test_rejections()
	_test_passives_and_statuses()
	_test_draw_rollback_and_replay()
	_test_spare_spool()
	_test_spool_rejections()
	for failure in failures:
		printerr(failure)
	print("combat_stitched_cards_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _definitions(path: String) -> Array:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(not records.is_empty(), "authored fixture exists: " + path)
	for record in records:
		if record.has("max_hp"):
			_check(record.max_hp == floor(record.max_hp), "integral authored HP")
			record.max_hp = int(record.max_hp)
	return records


func _fixture(first: String, second: String, seed_value: int = 83) -> Dictionary:
	var rest := RunRestStitchCards.new([first, second], {}, 3)
	_check(rest.is_valid(), "valid Rest inputs")
	var chosen := rest.choose_stitch(0, 1, rest.get_snapshot())
	_check(chosen.ok and rest.preview_play(chosen.stitched_id,
		CombatParty.new(_definitions("res://data/heroes/starter_party.json")).get_heroes()).ok, "authentic playable Rest composite")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new([chosen.stitched_id], rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.hand == [chosen.stitched_id], "held composite, active three energy")
	var party := CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
	var enemies := CombatEnemies.new(_definitions("res://data/enemies/starter_enemies.json"))
	_check(party.is_valid() and enemies.is_valid(), "real rosters valid")
	var attacks := CombatAttackCards.new()
	return {"rest": rest, "id": chosen.stitched_id, "deck": deck, "party": party,
		"enemies": enemies, "attacks": attacks, "service": CombatStitchedCards.new(attacks)}


func _play(c: Dictionary, a: int, b: int) -> Dictionary:
	return c.service.play_stitched(c.deck, c.party, c.enemies, c.rest, c.id, a, b)


func _snapshot(c: Dictionary) -> Array:
	return [c.deck.draw_pile.duplicate(), c.deck.hand.duplicate(), c.deck.discard_pile.duplicate(),
		c.deck.energy, c.deck.turn_active, c.deck._rng.state, c.party.get_heroes(),
		c.enemies.get_enemies(), c.attacks._tinker._consumed,
		{} if c.attacks._patches == null else c.attacks._patches.latch_snapshot(), c.rest.get_snapshot()]


func _reject(c: Dictionary, a: int, b: int, label: String) -> void:
	var before := _snapshot(c)
	_check(_play(c, a, b) == {"ok": false, "halves": []}, label + " rejects without outcomes")
	_check(_snapshot(c) == before, label + " preserves complete state and latches/RNG")


func _expected_hit(position: int, damage: int, block: int = 0, statuses: Dictionary = {}) -> Dictionary:
	return {"position": position, "damage": damage, "block_absorbed": block,
		"hp_loss": damage - block, "statuses": statuses}


func _test_pairs() -> void:
	for reverse in [false, true]:
		var c := _fixture(POP if reverse else PRICK, PRICK if reverse else POP)
		var before := _snapshot(c)
		var expected := before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[7][0].hp -= 3
		expected[7][0]["statuses"] = {"bleed": 3}
		expected[7][1].hp -= 8
		expected[8] = true
		var result := _play(c, 2 if reverse else 1, 1 if reverse else 2)
		var hits := [{"ok": true, "hits": [_expected_hit(1, 3, 0, {"bleed": 3})]},
			{"ok": true, "hits": [_expected_hit(2, 8)]}]
		if reverse:
			hits.reverse()
		_check(result == {"ok": true, "halves": hits}, "independent exact ordered attack outcomes")
		_check(_snapshot(c) == expected, "exact complete attack transition")
		c.deck.hand.append(POP)
		var next: Dictionary = c.attacks.play_attack(c.deck, c.party, c.enemies, POP, 1)
		_check(next == {"ok": true, "hits": [_expected_hit(1, 5)]}, "shared Tinker latch consumed once")
		c.attacks.start_player_turn()
		_check(c.attacks._tinker.bonus_for_attack(POP) == 3, "turn reset restores Tinker")

		c = _fixture(BOMB if reverse else PRICK, PRICK if reverse else BOMB)
		var area := _play(c, 0 if reverse else 1, 1 if reverse else 0)
		_check(area.ok and c.deck.energy == 0 and c.deck.discard_pile == [c.id], "area composite charges capped three once")
		var area_hits := [{"ok": true, "hits": [_expected_hit(1, 3, 0, {"bleed": 3})]},
			{"ok": true, "hits": [_expected_hit(1, 7), _expected_hit(2, 7)]}]
		if reverse:
			area_hits.reverse()
		_check(area.halves == area_hits, "exact ordered area outcomes")
		_check(c.enemies.get_enemy(1).hp == 2 and c.enemies.get_enemy(2).hp == 5
			and c.enemies.get_enemy(1).statuses == {"bleed": 3}, "Prick/area both orders exact HP and Bleed")

		c = _fixture(POP if reverse else "warden_strike_plus", "warden_strike_plus" if reverse else POP)
		_check(_play(c, 2 if reverse else 1, 1 if reverse else 2).ok, "upgraded half both orders")
		_check(c.enemies.get_enemy(1).hp == 5 and c.enemies.get_enemy(2).hp == 4, "Strike+ retains seven, Pop eight")

		c = _fixture("seamstress_mend" if reverse else "warden_brace", "warden_brace" if reverse else "seamstress_mend")
		_check(c.party.apply_damage(3, 8), "real heal precondition")
		var expected_support := _snapshot(c)
		expected_support[1] = []
		expected_support[2] = [c.id]
		expected_support[3] = 1
		expected_support[6][0].block = 7
		expected_support[6][2].hp += 5
		_check(_play(c, 3 if reverse else 0, 0 if reverse else 3).ok, "Brace/Mend both orders")
		_check(_snapshot(c) == expected_support, "exact complete self and ally transition")


func _test_all_authored_pairs() -> void:
	var catalog := StarterCards.new()
	for a in catalog.get_all_card_ids():
		for b in catalog.get_all_card_ids():
			var first := catalog.get_definition(a)
			var second := catalog.get_definition(b)
			if first.owner == second.owner:
				continue
			var c := _fixture(a, b)
			var ta := 1 if first.target_kind in ["enemy_single", "ally_single"] else 0
			var tb := 2 if second.target_kind == "enemy_single" and second.to_positions.has(2) else 1
			if second.target_kind not in ["enemy_single", "ally_single"]:
				tb = 0
			_check(_play(c, ta, tb).ok, "every canonical cross-owner pair: " + a + "/" + b)
			_check(c.deck.energy == 3 - mini(3, maxi(first.cost, second.cost) + 1)
				and c.deck.discard_pile == [c.id] and c.deck.hand.is_empty(), "one composite charge/discard: " + a + "/" + b)


func _test_rejections() -> void:
	var c := _fixture(PRICK, POP)
	_reject(c, 0, 2, "missing first target")
	_reject(c, 1, 0, "missing second target after staged damage")
	_reject(c, 1, 3, "unoccupied second target")
	_reject(c, -1, 2, "negative first target")
	c.deck.try_spend_energy(2)
	_reject(c, 1, 2, "insufficient energy")
	c = _fixture(PRICK, POP)
	c.deck.end_turn()
	_reject(c, 1, 2, "inactive turn")
	c = _fixture(PRICK, POP)
	c.deck.discard_played(c.id)
	_reject(c, 1, 2, "unheld ID")
	c = _fixture(PRICK, POP)
	c.id = "stitched_000002"
	c.deck.hand.assign([c.id])
	_reject(c, 1, 2, "unowned ID even held")
	c = _fixture(PRICK, POP)
	var forged: Dictionary = c.rest.get_snapshot()
	forged.descriptors[c.id].second_half.effects.damage = 999
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors, 0, 2)
	_check(not c.rest.is_valid(), "forged descriptor validation precondition")
	_reject(c, 1, 2, "forged run descriptor")
	for owner in [2, 3]:
		c = _fixture(PRICK, POP)
		_check(c.party.apply_damage(owner, c.party.get_hero(owner).hp), "downed owner precondition")
		_reject(c, 1, 2, "downed owner " + str(owner))
	c = _fixture("warden_strike", POP)
	var heroes: Array = c.party.get_heroes()
	c.party = CombatParty.new([heroes[2], heroes[1], heroes[0]])
	_reject(c, 1, 2, "misplaced first owner")
	c = _fixture(PRICK, BOMB)
	var defs: Array = c.party.get_heroes()
	c.party = CombatParty.new([defs[0], defs[2], defs[1]])
	_reject(c, 1, 0, "misplaced second owner")
	c = _fixture(POP, "warden_strike")
	_reject(c, 1, 3, "authored second to-position")
	c = _fixture("warden_strike", POP)
	_reject(c, 3, 1, "authored first to-position")
	c = _fixture(PRICK, POP)
	c.enemies.apply_damage(2, 12)
	_reject(c, 1, 2, "slain second target")
	c = _fixture(PRICK, POP)
	c.enemies.apply_damage(1, 9)
	_reject(c, 1, 1, "second target killed by first half")
	_check(_play(c, 1, 2).ok and c.enemies.get_enemy(1).hp == 0
		and not c.enemies.is_victorious() and c.enemies.get_enemy(2).position == 2, "retry retains passives and slain original slots")
	c = _fixture(PRICK, BOMB)
	_reject(c, 1, 1, "area forbids nonzero target")
	c = _fixture("warden_brace", "seamstress_mend")
	_reject(c, 1, 2, "self forbids target")
	_reject(c, 0, 0, "ally needs target")
	c.party.apply_damage(3, 26)
	_reject(c, 0, 3, "ally cannot revive")
	c = _fixture("seamstress_stitch_up", "tinker_tune_up")
	_reject(c, 1, 1, "draw forbids nonzero target")
	c.party.gain_block(1, CombatParty.MAX_INT)
	_reject(c, 1, 0, "Block overflow")
	c = _fixture(PRICK, "warden_shield_bash")
	c.enemies._enemies[1]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	# Shield Bash must target slot one: overflow there after Prick stages real damage.
	c.enemies._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	_reject(c, 2, 1, "second status overflow rolls back first damage and Bleed")
	c = _fixture(PRICK, POP)
	var before := _snapshot(c)
	_check(not c.service.play_stitched(null, c.party, c.enemies, c.rest, c.id, 1, 2).ok
		and _snapshot(c) == before, "null deck preserves surviving real models")
	_check(not c.service.play_stitched(c.deck, null, c.enemies, c.rest, c.id, 1, 2).ok
		and _snapshot(c) == before, "null party preserves surviving real models")
	_check(not c.service.play_stitched(c.deck, c.party, null, c.rest, c.id, 1, 2).ok
		and _snapshot(c) == before, "null enemies preserve surviving real models")
	_check(not c.service.play_stitched(c.deck, c.party, c.enemies, null, c.id, 1, 2).ok
		and _snapshot(c) == before, "null run owner preserves surviving real models")
	c.enemies = CombatEnemies.new([_definitions("res://data/enemies/starter_enemies.json")[0]])
	c.enemies.apply_damage(1, 9)
	_reject(c, 1, 1, "first kills final enemy but entire pair rejects")
	c = _fixture(PRICK, "warden_brace")
	c.enemies = CombatEnemies.new([_definitions("res://data/enemies/starter_enemies.json")[0]])
	c.enemies.apply_damage(1, 9)
	_check(_play(c, 1, 0).ok and c.enemies.is_victorious() and c.enemies.get_enemy(1).position == 1
		and c.party.get_hero(1).block == 7, "lethal first half can finish legal support and preserve final slot")


func _test_passives_and_statuses() -> void:
	var c := _fixture(PRICK, POP)
	var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(), ["button_eye", "pincushion_arm"],
		[{"id": "button_eye", "slot": "HEAD"}, {"id": "pincushion_arm", "slot": "ARM"}], 10)
	_check(wardrobe.sew("button_eye", "seamstress", "HEAD", "stitched-test-eye", wardrobe.get_snapshot()).ok
		and wardrobe.sew("pincushion_arm", "tinker", "ARM", "stitched-test-arm", wardrobe.get_snapshot()).ok, "real wearer patches sewn")
	_check(c.attacks.bind_patch_wardrobe(wardrobe, RunTornMending.new(c.party.get_heroes())), "real patch binding")
	var ledger := wardrobe.get_snapshot()
	_reject(c, 1, 0, "staged patch/passive rollback")
	c.party._heroes[2]["statuses"] = {"weak": 1}
	c.enemies.gain_block(2, 2)
	var result := _play(c, 1, 2)
	_check(result == {"ok": true, "halves": [
		{"ok": true, "hits": [_expected_hit(1, 3, 0, {"bleed": 3, "exposed": 1})]},
		{"ok": true, "hits": [_expected_hit(2, 6, 2)]}]}, "wearer bonus then Weak floor, Block and authored on-hit")
	_check(c.attacks._patches.latch_snapshot().seamstress and wardrobe.get_snapshot() == ledger, "published patch latch, unchanged run ledger")
	c.deck.hand.append(PRICK)
	var next: Dictionary = c.attacks.play_attack(c.deck, c.party, c.enemies, PRICK, 1)
	_check(next == {"ok": true, "hits": [_expected_hit(1, 4, 0, {"bleed": 3})]}
		and c.enemies.get_enemy(1).statuses == {"bleed": 6, "exposed": 1}, "Exposed affects subsequent hit, no second Button Eye, Bleed persists")
	# The second half reads the first half's newly authoritative Exposed counter.
	c = _fixture(PRICK, POP)
	_check(c.attacks.bind_patch_wardrobe(wardrobe, RunTornMending.new(c.party.get_heroes())), "fresh combat patch latches")
	result = _play(c, 1, 1)
	_check(result == {"ok": true, "halves": [
		{"ok": true, "hits": [_expected_hit(1, 3, 0, {"bleed": 3, "exposed": 1})]},
		{"ok": true, "hits": [{"position": 1, "damage": 13, "block_absorbed": 0, "hp_loss": 9, "statuses": {}}]}]},
		"second half observes first Exposed and only its own ARM: floor((5+3+1)*1.5)")


func _draw_sequence(seed_value: int) -> Array:
	var c := _fixture("tinker_tune_up", "seamstress_stitch_up", seed_value)
	c.deck.discard_pile.assign(["warden_strike", "warden_brace", PRICK])
	c.party.gain_block(1, CombatParty.MAX_INT)
	_reject(c, 0, 1, "draw refill precedes failing second half")
	c.party.start_player_turn()
	var before := _snapshot(c)
	var oracle := RandomNumberGenerator.new()
	oracle.state = before[5]
	var pile: Array[String] = c.deck.discard_pile.duplicate()
	for i in range(pile.size() - 1, 0, -1):
		var other := oracle.randi_range(0, i)
		var saved := pile[i]
		pile[i] = pile[other]
		pile[other] = saved
	var drawn: String = pile.pop_back()
	var expected := before.duplicate(true)
	expected[0] = pile
	expected[1] = [drawn]
	expected[2] = [c.id]
	expected[3] = 1
	expected[5] = oracle.state
	expected[6][0].block = 5
	_check(_play(c, 0, 1).ok, "Tune/Stitch commits after retry")
	_check(_snapshot(c) == expected, "exact seeded refill, no half/composite self-redraw, one discard")
	return [before, _snapshot(c)]


func _test_draw_rollback_and_replay() -> void:
	for seed_value in [0, 83, 9741]:
		_check(_draw_sequence(seed_value) == _draw_sequence(seed_value), "same-seed failure/success replay")
	var c := _fixture("seamstress_stitch_up", "tinker_tune_up")
	c.deck.draw_pile.assign(["warden_brace"])
	_check(_play(c, 3, 0).ok and c.party.get_hero(3).block == 5
		and c.deck.hand == ["warden_brace"] and c.deck.discard_pile == [c.id], "Stitch/Tune reverse order draws from existing pile")


func _bind_spool(c: Dictionary, mode: String = "sewn") -> void:
	var slots: Array = JSON.parse_string(FileAccess.get_file_as_string(CombatShopPatchRules.SLOTS_CATALOG))
	c.wardrobe = RunPatchWardrobe.new(c.party.get_heroes(), [] if mode == "absent" else ["spare_spool"], slots, 5)
	c.torn = RunTornMending.new(c.party.get_heroes())
	_check(c.wardrobe.is_valid() and c.torn.is_valid(), "real valid stitched wardrobe/torn authorities")
	if mode not in ["absent", "unsewn"]:
		_check(c.wardrobe.sew("spare_spool", "tinker" if mode == "wrong" else "seamstress", "ARM", "sew", c.wardrobe.get_snapshot()).ok, "stitched fixture actually sews Spool")
	if mode == "moved":
		_check(c.wardrobe.start_rest("rest", c.wardrobe.get_snapshot()).ok, "real Rest opens")
		_check(c.wardrobe.re_sew("spare_spool", "seamstress", "tinker", "rest", "move", c.wardrobe.get_snapshot()).ok, "stitched Spool moves to other owner")
		_check(c.wardrobe.end_rest("rest", c.wardrobe.get_snapshot()).ok, "real Rest closes")
	if mode == "torn":
		var start: Array = c.torn.read_state().heroes
		var finish := start.duplicate(true)
		finish[1].hp = 0
		_check(c.torn.observe_battle_end("tear", start, finish).ok, "actual stitched Mend owner tear")
		var state: Dictionary = c.wardrobe.get_snapshot()
		_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes, state.owned, state.scraps, state.gold, state.cards, state), "stitched wardrobe refreshes torn owner")
		c.party._heroes.assign(c.torn.read_state().heroes)
	if mode != "unbound":
		_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn), "stitched explicit Spool binding")


func _spool_sequence(seed_value: int, reverse: bool) -> Array:
	var c := _fixture(POP if reverse else "seamstress_mend", "seamstress_mend" if reverse else POP, seed_value)
	_bind_spool(c)
	_check(c.party.apply_damage(1, 12) and c.party.get_hero(1).hp == 28, "real stitched wound")
	var ledger := [c.wardrobe.get_snapshot(), c.torn.read_state()]
	var before := _snapshot(c)
	_reject(c, 2 if reverse else 1, 0, "later half fails after patched heal or Tinker attack")
	var expected := before.duplicate(true)
	expected[1] = []
	expected[2] = [c.id]
	expected[3] = 1
	expected[6][0].hp = 35
	expected[7][1].hp = 4
	expected[8] = true
	_check(_play(c, 2 if reverse else 1, 1 if reverse else 2).ok, "bound Mend composite commits either order")
	_check(_snapshot(c) == expected, "seven real healing, eight Pop damage, exact one charge/discard/latch and no RNG draw")
	_check(ledger == [c.wardrobe.get_snapshot(), c.torn.read_state()], "composite leaves authoritative ledgers pristine")
	return [before, _snapshot(c), ledger]


func _test_spare_spool() -> void:
	for seed_value in [0, 83, 9741]:
		for reverse in [false, true]:
			_check(_spool_sequence(seed_value, reverse) == _spool_sequence(seed_value, reverse), "bound composite exact seeded replay in each order")
	for reverse in [false, true]:
		for mode in ["absent", "unsewn", "wrong", "moved", "unbound", "sewn"]:
			var c := _fixture("warden_brace" if reverse else "seamstress_mend", "seamstress_mend" if reverse else "warden_brace")
			_bind_spool(c, mode)
			_check(c.party.apply_damage(3, 12), "wounded stitched ally")
			var before := _snapshot(c)
			var expected := before.duplicate(true)
			expected[1] = []
			expected[2] = [c.id]
			expected[3] = 1
			expected[6][0].block = 7
			expected[6][2].hp += 7 if mode == "sewn" else 5
			_check(_play(c, 0 if reverse else 3, 3 if reverse else 0).ok, mode + " Mend/Brace commits both orders")
			_check(_snapshot(c) == expected, mode + " exact five/seven HP, piles/energy and no phantom bonus")
		var capped := _fixture("warden_brace" if reverse else "seamstress_mend", "seamstress_mend" if reverse else "warden_brace")
		_bind_spool(capped)
		_check(capped.party.apply_damage(3, 2), "stitched cap precondition")
		_check(_play(capped, 0 if reverse else 3, 3 if reverse else 0).ok and capped.party.get_hero(3).hp == 26, "patched composite clamps at real maximum")
	var torn := _fixture("seamstress_mend", POP)
	_bind_spool(torn, "torn")
	_check(torn.party.is_downed(2) and torn.torn.read_state().tear_counts.seamstress == 1, "stitched owner truly torn")
	_reject(torn, 1, 2, "torn wearer cannot grant healing or play composite")


func _test_spool_rejections() -> void:
	for mode in ["null", "invalid", "stale_wardrobe", "stale_torn", "drift"]:
		var c := _fixture("seamstress_mend", POP)
		_bind_spool(c)
		_check(c.party.apply_damage(1, 12), "rejection fixture wound")
		var w: Dictionary = c.wardrobe.get_snapshot()
		var t: Dictionary = c.torn.read_state()
		match mode:
			"null":
				_check(not c.service.bind_patch_wardrobe(null, c.torn), "stitched null binding rejects")
			"invalid":
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, RunTornMending.new()), "stitched invalid authority rejects")
			"stale_wardrobe":
				w.scraps += 1
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, c.torn, w, t), "stitched stale wardrobe snapshot rejects")
			"stale_torn":
				t.heroes[0].hp -= 1
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, c.torn, w, t), "stitched stale torn snapshot rejects")
			"drift":
				_check(c.wardrobe.start_rest("later", w).ok, "stitched bound ledger actually advances")
		var ledgers := [c.wardrobe.get_snapshot(), c.torn.read_state()]
		_reject(c, 1, 2, mode + " stitched binding fails closed")
		_check(ledgers == [c.wardrobe.get_snapshot(), c.torn.read_state()], "rejected composite preserves ledgers")
	var c := _fixture("seamstress_mend", POP)
	_bind_spool(c)
	var forged: Dictionary = c.rest.get_snapshot()
	forged.descriptors[c.id].first_half.effects.heal = 7
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors, 0, 2)
	_check(not c.rest.is_valid(), "preinflated Mend descriptor truly invalid")
	_reject(c, 1, 2, "forged stitched heal cannot earn another bonus")
	# Draw first really refills/shuffles before the invalid Mend selection.
	c = _fixture("tinker_tune_up", "seamstress_mend")
	_bind_spool(c)
	c.deck.discard_pile.assign(["warden_strike", "warden_brace", PRICK])
	_check(c.party.apply_damage(1, 12), "draw/heal rollback wound")
	_reject(c, 0, 0, "bound draw RNG and piles roll back on missing second heal target")
	_check(_play(c, 0, 1).ok and c.party.get_hero(1).hp == 35 and c.deck.energy == 1
		and c.deck.discard_pile == [c.id] and c.deck.hand.size() == 1, "draw/heal retry commits once with seven HP")
