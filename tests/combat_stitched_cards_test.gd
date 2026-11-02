extends SceneTree

const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const BOMB := "tinker_scrap_bomb"
const SUPPORT_HALF := "warden_brace"
const SIGHT_GLASS_IDS: Array[String] = ["tinker_sight_glass", "tinker_sight_glass_plus"]
const ENERGY_IDS := ["tinker_overclock", "tinker_overclock_plus",
	"seamstress_tailors_trance", "seamstress_tailors_trance_plus"]
const SPARE_PARTS_IDS := ["tinker_spare_parts", "tinker_spare_parts_plus"]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_four_foe_plain_halves()
	_test_knit_halves()
	_test_plain_pool_halves()
	_test_plain_pool_failures()
	_test_warden_block_halves()
	_test_warden_block_failures()
	_test_pairs()
	_test_all_authored_pairs()
	_test_rejections()
	_test_ricochet_halves()
	_test_passives_and_statuses()
	_test_draw_rollback_and_replay()
	_test_spare_spool()
	_test_pool_healing_halves()
	_test_pool_heal_failures()
	_test_four_foe_halves()
	_test_pool_energy_halves()
	_test_pool_energy_failures()
	_test_pool_energy_replay()
	_test_spare_parts_halves()
	_test_spare_parts_failures()
	_test_spare_parts_replay()
	_test_sight_glass_halves()
	_test_sight_glass_failures()
	_test_sight_glass_replay()
	_test_spool_rejections()
	_test_hemguard_cuff()
	_test_cuff_rejections()
	_test_borrowed_button_halves()
	_test_borrowed_button_rejections_and_latch()
	_test_borrowed_button_party_and_torn()
	_test_tinker_pool_attack_halves()
	_test_tinker_pool_attack_latches()
	_test_tinker_pool_attack_failures()
	_test_scatter_area_halves()
	_test_scatter_area_refusals()
	for failure in failures:
		printerr(failure)
	print("combat_stitched_cards_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_knit_halves() -> void:
	var ids := ["yarn_ranger_hood_knit", "yarn_ranger_hood_knit_plus",
		"yarn_ranger_knit_shield", "yarn_ranger_knit_shield_plus"]
	var blocks := [4, 6, 6, 8]
	for i in range(ids.size()):
		for reverse in [false, true]:
			for supply in ["draw", "reshuffle", "empty"]:
				var replay: Array = []
				for attempt in range(2):
					var c := _fixture("warden_brace" if reverse else ids[i], ids[i] if reverse else "warden_brace", 351, true)
					_check(c.party.get_hero(3).id == "yarn_ranger", "knit owner genuinely present")
					if supply == "draw":
						c.deck.draw_pile.assign([PRICK, POP])
					elif supply == "reshuffle":
						c.deck.discard_pile.assign([PRICK, POP, BOMB])
					var before := _snapshot(c)
					var oracle := _oracle_draw(c.deck.draw_pile, c.deck.discard_pile, 1, c.deck._rng.state)
					var result := _play(c, 0 if reverse else 2, 2 if reverse else 0)
					var knit := {"ok": true, "effect": "block_and_draw", "amount": blocks[i], "draw": 1, "drawn": oracle.drawn.size()}
					var brace := {"ok": true, "effect": "self_block", "amount": 7}
					_check(result == {"ok": true, "halves": [brace, knit] if reverse else [knit, brace]}, "all knit printings retain both effects in order")
					var expected := before.duplicate(true)
					expected[0] = oracle.draw
					expected[1] = oracle.drawn
					expected[2] = oracle.discard + [c.id]
					expected[3] = 1
					expected[5] = oracle.rng
					expected[6][0].block = 7
					expected[6][1].block = blocks[i]
					_check(_snapshot(c) == expected, "exact Block, shared draw, single payment/discard, RNG and unchanged enemies/ledger")
					_check(not c.deck.hand.has(c.id) and c.deck.discard_pile.count(c.id) == 1, "held composite never draws itself")
					replay.append([result, _snapshot(c)])
				_check(replay[0] == replay[1], "knit seeded replay including reshuffle")
		for mode in ["target", "offboard", "negative", "downed_target", "downed_owner", "missing_owner", "energy", "corrupt", "owner", "foreign", "impossible", "stale", "overflow", "late"]:
			var c := _fixture(ids[i], "warden_strike", 352, true)
			c.deck.discard_pile.assign([PRICK, POP, BOMB])
			match mode:
				"downed_target": _check(c.party.apply_damage(2, 999), "downed knit target")
				"downed_owner": _check(c.party.apply_damage(3, 999), "downed knit owner")
				"missing_owner": c.party = CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
				"energy": _check(c.deck.try_spend_energy(2), "unaffordable knit composite")
				"corrupt": c.rest._descriptors[c.id].first_half.effects.draw = 2
				"owner": c.rest._descriptors[c.id].first_half.owner = "seamstress"
				"foreign": c.rest._descriptors[c.id].first_half.id = "yarn_ranger_foreign_knit"
				"impossible": c.rest._descriptors[c.id].first_half.from_positions = [4]
				"stale": c.rest._deck.clear()
				"overflow": _check(c.party.gain_block(2, CombatParty.MAX_INT), "knit overflow precondition")
			var target: int = {"target": 0, "offboard": 4, "negative": -1}.get(mode, 2)
			_reject(c, target, 3 if mode == "late" else 1, "knit full rollback " + mode)
		# Every living seat, including self, is a real recipient.
		for seat in [1, 2, 3]:
			var c := _fixture(ids[i], "warden_strike", 353, true)
			_check(_play(c, seat, 1).ok and c.party.get_hero(seat).block == blocks[i], "knit targets any living ally including self")


func _test_plain_pool_halves() -> void:
	for buckle in ["warden_brass_buckle", "warden_brass_buckle_plus"]:
		for whip in ["seamstress_thread_whip", "seamstress_thread_whip_plus"]:
			for reverse in [false, true]:
				var c := _rest_fixture(whip if reverse else buckle, buckle if reverse else whip, 327)
				# Keep original slot two after slot one dies; no roster compaction.
				_check(c.enemies.apply_damage(1, 99) and c.enemies.gain_block(2, 30), "plain pair has slain front and Blocked second slot")
				var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(), ["button_eye", "pincushion_arm"],
					[{"id": "button_eye", "slot": "HEAD"}, {"id": "pincushion_arm", "slot": "ARM"}], 10)
				_check(wardrobe.sew("button_eye", "warden", "HEAD", "plain-eye", wardrobe.get_snapshot()).ok
					and wardrobe.sew("pincushion_arm", "warden", "ARM", "plain-arm", wardrobe.get_snapshot()).ok, "real Warden patch receipts")
				var torn := RunTornMending.new(c.party.get_heroes())
				_check(c.attacks.bind_patch_wardrobe(wardrobe, torn), "plain staged patch authority bound")
				c.party._heroes[0]["statuses"] = {"weak": 1}
				_check(c.party.get_hero(1).statuses == {"weak": 1}, "plain Warden genuinely Weak")
				var before := _snapshot(c)
				# Independent ordinary plays against the same pre-state, in authored order.
				var oracle_party := CombatParty.new(c.party.get_heroes())
				oracle_party._heroes = c.party.get_heroes()
				var oracle_enemies := CombatEnemies.new(c.enemies.get_enemies())
				oracle_enemies._enemies = c.enemies.get_enemies()
				var ordinary := CombatPoolPlainStrikes.new()
				_check(ordinary.bind_patch_wardrobe(wardrobe, torn), "ordinary oracle authentic patch binding")
				var halves: Array = []
				for id in ([whip, buckle] if reverse else [buckle, whip]):
					var rng := RandomNumberGenerator.new()
					rng.seed = 327
					var deck := CombatDeck.new([id], rng)
					_check(deck.start_turn() and deck.hand == [id], "ordinary oracle really holds half")
					var hit := ordinary.play_card(deck, oracle_party, oracle_enemies, id, 2)
					_check(hit.ok, "ordinary oracle hit succeeds")
					halves.append(hit)
				var result := _play(c, 2, 2)
				_check(result == {"ok": true, "halves": halves}, "all base/+ pair orders equal ordinary rules including second-half Exposed")
				_check(c.party.get_heroes() == oracle_party.get_heroes() and c.enemies.get_enemies() == oracle_enemies.get_enemies(), "exact printed damage, wearer bonuses, Block and statuses")
				_check(c.party.get_hero(1).block == (6 if buckle.ends_with("_plus") else 4), "Brass Buckle retains printed Block")
				_check(c.deck.energy == 1 and c.deck.hand.is_empty() and c.deck.discard_pile == [c.id]
					and c.deck._rng.state == before[5] and not c.attacks._tinker._consumed
					and c.attacks._patches.latch_snapshot() == ordinary.get_patches().latch_snapshot(), "one capped charge/discard, unchanged RNG, exact shared latches")
				_reject(c, 2, 2, "played plain composite cannot replay")
	# Block bonuses are owner-only and additive across ARM and HEAD.
	for wearer in ["warden", "seamstress", "tinker"]:
		var c := _rest_fixture("warden_brass_buckle_plus", "seamstress_thread_whip_plus", 328)
		var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(), ["hemguard_cuff", "reinforced_browband"],
			[{"id": "hemguard_cuff", "slot": "ARM"}, {"id": "reinforced_browband", "slot": "HEAD"}], 10)
		_check(wardrobe.sew("hemguard_cuff", wearer, "ARM", "plain-cuff", wardrobe.get_snapshot()).ok
			and wardrobe.sew("reinforced_browband", wearer, "HEAD", "plain-brow", wardrobe.get_snapshot()).ok, "real dual Block patch receipts")
		var torn := RunTornMending.new(c.party.get_heroes())
		var heads := CombatM05HeadPatchRules.new()
		_check(c.attacks.bind_patch_wardrobe(wardrobe, torn) and heads.bind_wardrobe(wardrobe, torn)
			and c.attacks.bind_head_patch_rules(heads), "dual Block authority")
		_check(_play(c, 1, 2).ok and c.party.get_hero(1).block == (10 if wearer == "warden" else 6), "only Buckle owner's ARM/HEAD increase Block")


func _test_four_foe_plain_halves() -> void:
	for buckle in ["warden_brass_buckle", "warden_brass_buckle_plus"]:
		for whip in ["seamstress_thread_whip", "seamstress_thread_whip_plus"]:
			for reverse in [false, true]:
				var replays: Array = []
				for attempt in range(2):
					var first: String = whip if reverse else buckle
					var second: String = buckle if reverse else whip
					var c := _rest_fixture(first, second, 43602)
					c.enemies = _four_foes()
					c.wardrobe = RunPatchWardrobe.new(c.party.get_heroes(), ["button_eye"], RunAuthoredPatchDefinitions.load_definitions(), 5)
					c.torn = RunTornMending.new(c.party.get_heroes())
					_check(c.wardrobe.sew("button_eye", "warden", "HEAD", "four-eye", c.wardrobe.get_snapshot()).ok
						and c.attacks.bind_patch_wardrobe(c.wardrobe, c.torn), "genuine stitched first-hit patch authority")
					var preview: Dictionary = c.rest.preview_play(c.id, c.party.get_heroes())
					_check(preview.ok and preview.halves[0].id == first and preview.halves[1].id == second
						and preview.halves[0].owner != preview.halves[1].owner and c.deck.hand == [c.id],
						"canonical different-owner Rest halves held in authored order")
					_check(c.enemies.gain_block(2, 30), "real shared target can survive both staged hits")
					c.enemies._enemies[3].statuses = {"bleed": 2, "weak": 1}
					var before := _snapshot(c)
					# Both legal halves succeed in isolation from this prestate. A
					# subsequent invalid target therefore exercises actual rollback.
					var stage := CombatPoolPlainStrikes.stage_for_stitch(c.attacks.stage_transaction())
					var detached_party := CombatParty.new(c.party.get_heroes())
					var detached_foes := _four_foes()
					_check(stage.resolve_staged_half(detached_party, detached_foes, preview.halves[0], 2).ok,
						"first half really succeeds before later-half failure")
					_reject(c, 2, 4, "late unprinted fourth target rolls back hit, Block, patch and latch")
					_reject(c, 4, 2, "first unprinted fourth target")
					var expected := before.duplicate(true)
					expected[1] = []
					expected[2] = [c.id]
					expected[3] = 1
					var buckle_damage: int = 7 if buckle.ends_with("_plus") else 5
					var whip_damage: int = 8 if whip.ends_with("_plus") else 6
					# Warden's Button Eye lands AFTER its hit; a later Whip
					# sees Exposed, whereas an earlier Whip does printed damage.
					if not reverse:
						whip_damage = whip_damage * 3 / 2
					var gain: int = 6 if buckle.ends_with("_plus") else 4
					expected[6][0].block = gain
					expected[7][1].block -= buckle_damage + whip_damage
					expected[7][1].statuses = {"exposed": 1}
					expected[9]["warden"] = true
					var buckle_receipt := {"ok": true, "hits": [_expected_hit(2, buckle_damage, buckle_damage, {"exposed": 1})], "block_deltas": {1: gain}}
					var whip_receipt := {"ok": true, "hits": [_expected_hit(2, whip_damage, whip_damage)], "block_deltas": {}}
					var receipt := _play(c, 2, 2)
					_check(receipt == {"ok": true, "halves": [whip_receipt, buckle_receipt] if reverse else [buckle_receipt, whip_receipt]},
						"both ordered receipts include exact damage, Block and patch status")
					_check(_snapshot(c) == expected and c.enemies.get_enemy(4) == before[7][3],
						"one atomic charge/discard; exact complete state, fourth foe, ledgers, latches and RNG")
					replays.append([receipt, _snapshot(c)])
				_check(replays[0] == replays[1], "four-foe plain composite deterministic replay")
	for id in CombatPoolPlainStrikes.SUPPORTED_IDS:
		var other := "seamstress_thread_whip" if id.begins_with("warden") else "warden_brass_buckle"
		for reverse in [false, true]:
			for mode in ["energy", "dead", "downed", "owner", "from", "to", "capacity", "status", "roster", "forged", "stale", "lethal"]:
				if mode == "from" and not id.begins_with("warden"):
					continue
				if mode == "to" and not id.begins_with("seamstress"):
					continue
				var c := _rest_fixture(other if reverse else id, id if reverse else other, 43603)
				c.enemies = _four_foes()
				var a := 1
				var b := 2
				var owner := 1 if id.begins_with("warden") else 2
				match mode:
					"energy": _check(c.deck.try_spend_energy(2), "composite really underfunded")
					"dead": _check(c.enemies.apply_damage(2 if reverse else 1, 999), "selected foe really slain")
					"downed": _check(c.party.apply_damage(owner, 999), "plain owner really downed")
					"owner": c.party._heroes[owner - 1].id = "absent_owner"
					"from":
						var heroes: Array = c.party.get_heroes()
						c.party = CombatParty.new([heroes[2], heroes[1], heroes[0]])
					"to":
						if reverse: b = 3
						else: a = 3
					"capacity": c.enemies = _unopted_four_foes()
					"status": c.enemies._enemies[3].statuses = {"weak": -1}
					"roster": c.enemies._enemies[3].position = 3
					"forged": c.rest._descriptors[c.id].second_half.effects.damage = 999
					"stale": c.rest._deck.clear()
					"lethal":
						_check(c.enemies.apply_damage(1, 11), "one HP shared target before first hit")
						b = 1
				_reject(c, a, b, "four-foe plain composite refusal " + mode + id)


func _test_plain_pool_failures() -> void:
	for first in CombatPoolPlainStrikes.SUPPORTED_IDS:
		var second := "seamstress_thread_whip_plus" if first.begins_with("warden") else "warden_brass_buckle_plus"
		for mode in ["late_target", "energy", "downed", "position", "forged", "stale", "lethal"]:
			var c := _rest_fixture(first, second, 329)
			var owner := 1 if second.begins_with("warden") else 2
			match mode:
				"energy":
					_check(c.deck.try_spend_energy(2), "plain insufficient energy setup")
				"downed":
					_check(c.party.apply_damage(owner, 99), "plain second owner downed")
				"position":
					var heroes: Array = c.party.get_heroes()
					c.party = CombatParty.new([heroes[2], heroes[1], heroes[0]])
				"forged":
					c.rest._descriptors[c.id].second_half.effects.damage = 999
				"stale":
					c.rest._deck.clear()
				"lethal":
					_check(c.enemies.apply_damage(1, 11), "first half will slay shared target")
			_reject(c, 1, 0 if mode == "late_target" else 1, "plain pair rollback " + mode + first)
	# A failed later half rolls back a staged hit, Block, Exposed and Button Eye latch.
	var c := _rest_fixture("warden_brass_buckle_plus", "seamstress_thread_whip", 330)
	var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(), ["button_eye"], [{"id": "button_eye", "slot": "HEAD"}], 10)
	_check(wardrobe.sew("button_eye", "warden", "HEAD", "plain-rollback", wardrobe.get_snapshot()).ok, "rollback real eye")
	_check(c.attacks.bind_patch_wardrobe(wardrobe, RunTornMending.new(c.party.get_heroes())), "rollback eye bound")
	_reject(c, 1, 0, "plain late failure preserves full authoritative state and eye latch")
	_check(not c.attacks._patches.latch_snapshot().get("warden", false) and _play(c, 1, 2).ok
		and c.attacks._patches.latch_snapshot().get("warden", false), "legal retry consumes rolled-back eye once")
	var runs: Array = []
	for attempt in range(2):
		c = _rest_fixture("warden_brass_buckle", "seamstress_thread_whip_plus", 331)
		runs.append([_play(c, 1, 2), _snapshot(c)])
	_check(runs[0][0].ok and runs[0] == runs[1], "plain pair same-seed replay exact")


func _test_warden_block_halves() -> void:
	for required in ["warden_hold_the_line", "warden_hold_the_line_plus", "warden_bastion_quilt", "warden_bastion_quilt_plus"]:
		_check(CombatStitchedTargetPreview.WARDEN_BLOCK_IDS.has(required), "required canonical Warden admission " + required)
	for id in CombatStitchedTargetPreview.WARDEN_BLOCK_IDS:
		for reverse in [false, true]:
			for position in [1, 2, 3]:
				var c := _rest_fixture(POP if reverse else id, id if reverse else POP, 262)
				for step in range(position - 1):
					var moved := CombatPositionSwaps.preview_adjacent_swap(c.party, step + 1, 1)
					_check(moved.ok, "move living Warden to current slot")
					c.party._heroes.assign(moved.heroes)
				if position == 3 and id.begins_with("warden_hold"):
					_reject(c, 1 if reverse else 0, 0 if reverse else 1, "Hold illegal back slot")
					continue
				var before := _snapshot(c)
				var result := _play(c, 1 if reverse else 0, 0 if reverse else 1)
				_check(result.ok and result.halves.size() == 2, "both-order canonical Warden half commits")
				var plus: bool = id.ends_with("_plus")
				for hero in c.party.get_heroes():
					var expected: int = (13 if plus else 10) if id.begins_with("warden_bastion") else ((7 if plus else 5) if hero.id == "warden" else (3 if plus else 2))
					_check(hero.block == expected, "complete independent authored Block at current slot")
				_check(c.deck.energy == (0 if id.begins_with("warden_bastion") else 1)
					and c.deck.discard_pile == [c.id] and c.deck.hand.is_empty()
					and c.deck._rng.state == before[5], "single capped charge/discard without RNG draws")
				_reject(c, 0, 0, "discarded composite cannot replay")
		for downed in [false, true]:
			var c := _fixture(id, POP)
			_bind_cuff(c)
			if downed:
				_check(c.party.apply_damage(2, 999) and c.party.is_downed(2), "non-owner is downed")
			var result := _play(c, 0, 1)
			_check(result.ok, "patched Warden half commits with living owners")
			var expected: int = (13 if id.ends_with("_plus") else 10) if id.begins_with("warden_bastion") else (9 if id.ends_with("_plus") else 7)
			_check(c.party.get_hero(1).block == expected, "Cuff adds two only to printed self Block")
			_check(c.party.get_hero(2).block == (0 if downed else ((13 if id.ends_with("_plus") else 10) if id.begins_with("warden_bastion") else (3 if id.ends_with("_plus") else 2))), "living other ally gets authored amount; downed skipped")
		var torn_case := _fixture(id, POP)
		_bind_cuff(torn_case, "torn_divergent")
		_check(not torn_case.party.is_downed(2) and torn_case.torn.read_state().heroes[1].hp == 0, "fresh battle ally lives but run ledger is Torn")
		_check(_play(torn_case, 0, 1).ok and torn_case.party.get_hero(2).block == 0, "Torn other ally skipped")


func _test_warden_block_failures() -> void:
	for id in CombatStitchedTargetPreview.WARDEN_BLOCK_IDS:
		var c := _fixture(id, POP)
		_reject(c, 1, 1, "automatic Warden target must be zero")
		_check(c.party.apply_damage(1, 999) and c.party.is_downed(1), "Warden owner genuinely downed")
		_reject(c, 0, 1, "downed owner")
		c = _fixture(id, POP)
		_check(c.party.gain_block(2, CombatParty.MAX_INT), "other ally at Block capacity")
		_reject(c, 0, 1, "other recipient overflow rolls back all")
		c = _fixture(POP, id)
		_check(c.party.gain_block(2, CombatParty.MAX_INT), "later Block half overflow precondition")
		_reject(c, 1, 0, "earlier Tinker damage and latch rolled back on late Block failure")
		c = _fixture("tinker_tune_up", id)
		c.deck.discard_pile.assign(["warden_strike", PRICK, POP])
		_check(c.deck.draw_pile.is_empty() and c.deck.discard_pile.size() == 3,
			"earlier draw must reshuffle genuine discarded supply with seeded RNG")
		_check(c.party.gain_block(2, CombatParty.MAX_INT), "Block overflow follows earlier seeded draw")
		_reject(c, 0, 0, "later Warden failure rolls back seeded shuffle and every pile")
		c = _fixture(id, PRICK)
		_reject(c, 0, 99, "later attack target failure rolls back Block")
		c = _fixture(id, POP)
		_bind_cuff(c)
		_check(c.wardrobe.start_rest("stale", c.wardrobe.get_snapshot()).ok, "genuine authority change after bind")
		_reject(c, 0, 1, "stale bound wardrobe")
		c = _fixture(id, POP)
		_bind_cuff(c, "torn")
		c.party = CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
		_check(not c.party.is_downed(1) and c.torn.read_state().heroes[0].hp == 0, "living battle Warden is still run-Torn")
		_reject(c, 0, 1, "run-Torn owner cannot resolve staged Warden half")
		c = _fixture(id, POP)
		_bind_cuff(c)
		_check(not c.service.bind_patch_wardrobe(c.wardrobe, c.torn, {"forged": true}), "forged optimistic binding receipt rejected")
		_reject(c, 0, 1, "failed binding never falls back to unpatched play")
		for field in ["effects", "owner", "from_positions", "cost"]:
			c = _fixture(id, POP)
			var half: Dictionary = c.rest._descriptors[c.id].first_half
			match field:
				"effects": half.effects["block"] = 999
				"owner": half.owner = "seamstress"
				"from_positions": half.from_positions = [1]
				"cost": c.rest._descriptors[c.id].cost = 0
			_reject(c, 0, 1, "forged full Rest descriptor " + field)
		var first := _fixture(id, POP, 262)
		var second := _fixture(id, POP, 262)
		_reject(first, 0, 99, "deterministic failed attempt")
		_check(_play(first, 0, 1) == _play(second, 0, 1)
			and _snapshot(first) == _snapshot(second), "failed attempt then retry equals clean seeded play")


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


func _fixture(first: String, second: String, seed_value: int = 83,
		with_ranger: bool = false) -> Dictionary:
	var definitions := _definitions("res://data/heroes/starter_party.json")
	if with_ranger:
		for hero in _definitions("res://data/heroes/v3_party_roster.json"):
			if hero.id == "yarn_ranger":
				definitions[2] = hero
	var rest := RunRestStitchCards.new([first, second], {}, 3)
	_check(rest.is_valid(), "valid Rest inputs")
	var chosen := rest.choose_stitch(0, 1, rest.get_snapshot())
	_check(chosen.ok and rest.preview_play(chosen.stitched_id,
		CombatParty.new(definitions).get_heroes()).ok, "authentic playable Rest composite")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new([chosen.stitched_id], rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.hand == [chosen.stitched_id], "held composite, active three energy")
	var party := CombatParty.new(definitions)
	var enemies := CombatEnemies.new(_definitions("res://data/enemies/starter_enemies.json"))
	_check(party.is_valid() and enemies.is_valid(), "real rosters valid")
	var attacks := CombatAttackCards.new()
	return {"rest": rest, "id": chosen.stitched_id, "deck": deck, "party": party,
		"enemies": enemies, "attacks": attacks, "service": CombatStitchedCards.new(attacks)}


func _play(c: Dictionary, a: int, b: int) -> Dictionary:
	return c.service.play_stitched(c.deck, c.party, c.enemies, c.rest, c.id, a, b)


## Uses the Rest ledger's own deck as the battle deck, so the held composite is
## literally the run ledger's stitched card rather than a hand-written stand-in.
func _rest_fixture(first: String, second: String, seed_value: int) -> Dictionary:
	var c := _fixture(first, second, seed_value)
	var ledger: Dictionary = c.rest.get_snapshot()
	var cards: Array[String] = []
	cards.assign(ledger["deck"])
	_check(cards == [c.id], "Rest ledger deck holds exactly the composite")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	c.deck = CombatDeck.new(cards, rng)
	_check(c.deck.start_turn() and c.deck.energy == 3 and c.deck.hand == [c.id],
		"Rest-to-combat deck holds the composite with three energy")
	return c


## The four explicitly admitted authored foe records, by ID, from both shipped
## catalogs: two starter enemies and the two shipped tough normals.
func _four_foes() -> CombatEnemies:
	var catalog := _definitions("res://data/enemies/starter_enemies.json")
	catalog.append_array(_definitions("res://data/enemies/v3_tough_normals.json"))
	var selected: Array = []
	for required in ["ragling", "ragling_guard", "spindle_ram", "razor_ribbon_wraith"]:
		var matches: Array = catalog.filter(func(entry): return entry is Dictionary and entry.get("id") == required)
		_check(matches.size() == 1, "authored four-foe source present exactly once: " + required)
		if matches.size() == 1:
			selected.append(matches[0])
	var enemies := CombatEnemies.new(selected, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.is_valid() and enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
		and enemies.get_enemies().size() == 4
		and enemies.get_enemies().map(func(foe): return foe.get("position")) == [1, 2, 3, 4],
		"explicit opt-in roster really holds four authored occupied slots")
	return enemies


## The same four authored records forced into the DEFAULT three-slot capacity:
## exactly the unopted battle the staged transaction must refuse.
func _unopted_four_foes() -> CombatEnemies:
	var catalog := _definitions("res://data/enemies/starter_enemies.json")
	catalog.append_array(_definitions("res://data/enemies/v3_tough_normals.json"))
	var records: Array = []
	for required in ["ragling", "ragling_guard", "spindle_ram", "razor_ribbon_wraith"]:
		var matches: Array = catalog.filter(func(entry): return entry is Dictionary and entry.get("id") == required)
		if matches.size() == 1:
			records.append(matches[0])
	var enemies := CombatEnemies.new(records.slice(0, 3))
	_check(enemies.is_valid() and enemies.get_capacity() == CombatEnemies.MAX_ENEMIES,
		"default three-capacity roster is valid before a fourth record appears")
	var roster: Array[Dictionary] = []
	for index in range(records.size()):
		var foe: Dictionary = records[index].duplicate(true)
		foe["position"] = index + 1
		foe["hp"] = foe["max_hp"]
		foe["block"] = 0
		roster.append(foe)
	enemies._enemies = roster
	return enemies


func _position_of(party: CombatParty, hero_id: String) -> int:
	for hero in party.get_heroes():
		if hero["id"] == hero_id:
			return int(hero["position"])
	return 0


## Independent Fisher-Yates/refill oracle mirroring CombatDeck._draw exactly.
func _oracle_draw(draw_pile: Array, discard_pile: Array, count: int,
		rng_state: int) -> Dictionary:
	var oracle := RandomNumberGenerator.new()
	oracle.state = rng_state
	var pile: Array = draw_pile.duplicate()
	var discard: Array = discard_pile.duplicate()
	var drawn: Array = []
	while drawn.size() < count:
		if pile.is_empty():
			if discard.is_empty():
				break
			pile = discard.duplicate()
			discard.clear()
			for index in range(pile.size() - 1, 0, -1):
				var other := oracle.randi_range(0, index)
				var card = pile[index]
				pile[index] = pile[other]
				pile[other] = card
		drawn.append(pile.pop_back())
	return {"draw": pile, "discard": discard, "drawn": drawn, "rng": oracle.state}


func _snapshot(c: Dictionary) -> Array:
	return [c.deck.draw_pile.duplicate(), c.deck.hand.duplicate(), c.deck.discard_pile.duplicate(),
		c.deck.energy, c.deck.turn_active, c.deck._rng.state, c.party.get_heroes(),
		c.enemies.get_enemies(), c.attacks._tinker._consumed,
		{} if c.attacks._patches == null else c.attacks._patches.latch_snapshot(), c.rest.get_snapshot(),
		c.deck._rng.seed, c.rest.is_consumed(),
		{} if c.get("wardrobe") == null else c.wardrobe.get_snapshot(),
		{} if c.get("torn") == null else c.torn.read_state(),
		{} if c.service._support._patches == null else c.service._support._patches.active_snapshot(),
		c.service._support._wardrobe_snapshot.duplicate(true),
		c.service._support._torn_snapshot.duplicate(true),
		{} if c.get("button_heals") == null else c.button_heals._borrowed_button.read_state(),
		-1 if c.get("button_heals") == null else c.button_heals._heal_receipt_number]


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
	var skip := ["warden_shield_bash_plus", "seamstress_prick_plus", "tinker_pop_shot_plus", "tinker_scrap_bomb_plus"]
	for a in catalog.get_all_card_ids():
		for b in catalog.get_all_card_ids():
			if a in skip or b in skip:
				continue
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


## Authenticated random-target halves use ordinary sequential hits but commit
## neither RNG nor attack/patch latches until both halves succeed.
func _test_ricochet_halves() -> void:
	for card_id in CombatTinkerPoolAttacks.STITCHED_RANDOM_IDS:
		var authored: Dictionary = TinkerPoolCards.new().get_definition(card_id)
		var damage := 6 if card_id.ends_with("_plus") else 4
		_check(authored == RunRestStitchCards.resolve_card_definition(card_id)
			and authored.get("owner") == "tinker"
			and authored.get("target_kind") == "enemy_random"
			and authored.get("effects") == {"damage": damage, "hit_count": 3,
				"random_target_each_hit": true, "rng_source": "run",
				"living_targets_only": true},
			card_id + ": full authored base/+ random-target printing")
		for reverse in [false, true]:
			var first: String = SUPPORT_HALF if reverse else card_id
			var second: String = card_id if reverse else SUPPORT_HALF
			var replays: Array = []
			for attempt in range(2):
				var c := _rest_fixture(first, second, 3782)
				_bind_cuff(c)
				c.deck.draw_pile.assign([PRICK, BOMB])
				c.deck.discard_pile.assign(["warden_strike"])
				var desc: Dictionary = c.rest.get_snapshot().descriptors[c.id]
				_check(c.rest.is_valid() and desc.half_ids == [first, second]
					and desc.cost == 2 and c.deck.hand == [c.id] and c.deck.energy == 3
					and _position_of(c.party, "tinker") == 3
					and c.enemies.get_enemies().size() >= 2
					and (desc.second_half if reverse else desc.first_half) == authored,
					card_id + ": real Rest, multiple foes and held capped-cost card")
				c.party._heroes[2]["statuses"] = {"weak": 1}
				_check(c.enemies.gain_block(1, 2)
					and c.enemies.apply_statuses({2: {"exposed": 1}}),
					"Ricochet oracle has real Block, Weak and Exposed")
				var oracle := _scatter_ordinary_oracle(c, card_id)
				_check(oracle.result.get("ok", false) and oracle.result.hits.size() == 3
					and oracle.rng != c.deck._rng.state,
					"independent ordinary Ricochet consumes seeded RNG for three hits")
				var before := _snapshot(c)
				var receipt := _play(c, 0, 0)
				var random_index: int = 1 if reverse else 0
				var brace := {"ok": true, "effect": "self_block", "amount": 7}
				_check(receipt.get("ok", false) and receipt.halves.size() == 2
					and receipt.halves[random_index] == oracle.result
					and receipt.halves[1 - random_index] == brace,
					card_id + ": both ordered halves equal exact ordinary hit receipts")
				_check(c.enemies.get_enemies() == oracle.enemies
					and c.party.get_hero(1).block == before[6][0].block + 9
					and c.deck.energy == before[3] - 2
					and c.deck.draw_pile == before[0] and c.deck.hand.is_empty()
					and c.deck.discard_pile == before[2] + [c.id]
					and c.deck._rng.state == oracle.rng
					and c.attacks._tinker._consumed
					and c.rest.get_snapshot() == before[10],
					card_id + ": HP, Block, statuses, RNG, ledger, latch, single payment")
				replays.append([receipt, _snapshot(c)])
			_check(replays[0] == replays[1],
					card_id + ": same-seed both-order replay")
		# One remaining 1-HP enemy dies on hit one; no phantom retarget.
		var dying := _rest_fixture(card_id, SUPPORT_HALF, 3785)
		_check(dying.enemies.apply_damage(2, 999) and dying.enemies.get_enemy(1).hp > 0,
			"one living eligible enemy before lethal random retarget")
		dying.enemies._enemies[0]["hp"] = 1
		var death_oracle := _scatter_ordinary_oracle(dying, card_id)
		var death := _play(dying, 0, 0)
		_check(death_oracle.result.get("ok", false) and death_oracle.result.hits.size() == 1
			and death.get("ok", false) and death.halves[0] == death_oracle.result
			and dying.enemies.is_victorious() and dying.deck._rng.state == death_oracle.rng,
			"lethal Ricochet stops at final death, preserves slot and consumed RNG")
		var failing := _rest_fixture(card_id, SUPPORT_HALF, 3786)
		_reject(failing, 0, 1, "late Brace rejects after staged three-hit Ricochet")
		_reject(failing, 1, 0, "random half refuses manual enemy target")
		_reject(failing, -1, 0, "random half refuses negative target")
		var reversed := _rest_fixture(SUPPORT_HALF, card_id, 3786)
		_reject(reversed, 0, 2, "reverse random half refuses manual target")
		var broke := _rest_fixture(card_id, SUPPORT_HALF, 3786)
		_check(broke.deck.try_spend_energy(2) and broke.deck.energy == 1,
			"one energy cannot pay the authentic two-cost pair")
		_reject(broke, 0, 0, "unaffordable Ricochet rejects atomically")
		broke = _rest_fixture(card_id, SUPPORT_HALF, 3786)
		_check(broke.party.apply_damage(3, 999) and broke.party.is_downed(3),
			"Tinker owner actually downed")
		_reject(broke, 0, 0, "downed Tinker cannot fire")
		broke = _rest_fixture(card_id, SUPPORT_HALF, 3786)
		_check(broke.enemies.apply_damage(1, 999)
			and broke.enemies.apply_damage(2, 999), "all enemies actually dead")
		_reject(broke, 0, 0, "no living eligible targets rejects")
		broke = _rest_fixture(card_id, SUPPORT_HALF, 3786)
		broke.rest._descriptors[broke.id].first_half.effects.damage = 999
		_reject(broke, 0, 0, "forged authored damage rejects")
		broke = _rest_fixture(card_id, SUPPORT_HALF, 3786)
		_bind_cuff(broke)
		broke.service._support._wardrobe_snapshot["scraps"] = -1
		_reject(broke, 0, 0, "stale patch binding rejects")


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


func _darning_cuff_sequence(seed_value: int, reverse: bool, upgraded: bool = false) -> Array:
	var darning_id: String = "seamstress_darning_plus" if upgraded else "seamstress_darning"
	var first: String = POP if reverse else darning_id
	var second: String = darning_id if reverse else POP
	var c := _fixture(first, second, seed_value)
	_bind_cuff(c, "sewn_seamstress")
	_check(c.party.apply_damage(1, 15), "real living wound for Darning replay")
	var ledger: Array = [c.wardrobe.get_snapshot(), c.torn.read_state()]
	var before: Array = _snapshot(c)
	_reject(c, 0 if reverse else 1, 1 if reverse else 0, "invalid target rejects composite before commit")
	var expected: Array = before.duplicate(true)
	expected[1] = []
	expected[2] = [c.id]
	expected[3] = 1
	var heal: int = 6 if upgraded else 4
	var block: int = 6 if upgraded else 5
	expected[6][0].hp += heal
	expected[6][0].block = block
	expected[7][1].hp -= 8
	expected[8] = true
	var play_res := _play(c, 2 if reverse else 1, 1 if reverse else 2)
	_check(play_res.ok, "bound Cuff Darning composite commits either order")
	_check(_snapshot(c) == expected, "exact Darning heal and Cuff Block in replay")
	_check(ledger == [c.wardrobe.get_snapshot(), c.torn.read_state()], "composite leaves ledgers pristine")
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

func _test_pool_healing_halves() -> void:
	var pool := SeamstressPoolCards.new()
	for id in CombatStitchedTargetPreview.POOL_HEAL_IDS:
		var authored: Dictionary = pool.get_definition(id)
		_check(not authored.is_empty() and authored == RunRestStitchCards.resolve_card_definition(id),
			id + ": authentic pool base/+ definition")
		var field: bool = id in CombatSeamstressPoolHeals.FIELD_MEND_IDS
		var counterpart := POP if field else "warden_brace"
		for reverse in [false, true]:
			for mode in ["unbound", "absent", "unsewn", "wrong", "sewn"]:
				var first: String = counterpart if reverse else id
				var second: String = id if reverse else counterpart
				var c := _fixture(first, second, 12030)
				_bind_spool(c, mode)
				_check(c.party.apply_damage(1, 12) and c.party.apply_damage(2, 11)
					and c.party.apply_damage(3, 10), id + ": three real living wounds")
				var before := _snapshot(c)
				var expected := before.duplicate(true)
				expected[1] = []
				expected[2] = [c.id]
				expected[3] = 0 if field else 1
				var heal: int = authored.effects.heal + (2 if mode == "sewn" else 0)
				var block: int = authored.effects.get("block", 0)
				var affected: Array[int] = []
				affected.assign([1, 2, 3] if field else [1])
				for pos in affected:
					expected[6][pos - 1].hp += heal
				if field:
					expected[7][1].hp -= 8
					expected[8] = true
				else:
					expected[6][0].block = 7 + block
				var result := _play(c, (2 if field else 0) if reverse else (0 if field else 1),
					(0 if field else 1) if reverse else (2 if field else 0))
				var label: String = str(id) + " / " + counterpart + " order " + str(reverse) + " Spool " + mode
				_check(result.ok and result.halves.size() == 2, label + ": two effects committed")
				if not result.ok:
					continue
				var heal_half: Dictionary = result.halves[1 if reverse else 0]
				_check(heal_half == {"ok": true, "effect": "party_heal" if field else "ally_heal",
					"amount": heal, "block": block, "affected_positions": affected},
					label + ": exact heal, additive Block and recipient outcomes")
				if field:
					_check(result.halves[0 if reverse else 1] ==
						{"ok": true, "hits": [_expected_hit(2, 8)]},
						label + ": Tinker counterpart attack resolved with first-attack passive")
				else:
					_check(result.halves[0 if reverse else 1] ==
						{"ok": true, "effect": "self_block", "amount": 7},
						label + ": Warden Brace adds independently to Darning Block")
				_check(_snapshot(c) == expected,
					label + ": exact HP/Block, enemy, deck, cost, seeded RNG and patch ledgers")
	# Authenticated Rest stitch descriptors for Darning and Darning+ with Hemguard Cuff
	for d_id: String in CombatSeamstressPoolHeals.DARNING_IDS:
		var upgraded_d: bool = d_id.ends_with("_plus")
		var exp_heal: int = 6 if upgraded_d else 4
		var exp_block: int = 6 if upgraded_d else 5
		for reverse: bool in [false, true]:
			var first_card: String = POP if reverse else d_id
			var second_card: String = d_id if reverse else POP
			var rc := _rest_fixture(first_card, second_card, 7721)
			_bind_cuff(rc, "sewn_seamstress")
			_check(rc.party.apply_damage(1, 12), d_id + ": real wound before Rest composite")
			var before_snap := _snapshot(rc)
			var exp_snap := before_snap.duplicate(true)
			exp_snap[1] = []
			exp_snap[2] = [rc.id]
			exp_snap[3] = 1
			exp_snap[6][0].hp += exp_heal
			exp_snap[6][0].block = exp_block
			exp_snap[7][1].hp -= 8
			exp_snap[8] = true
			var rres := _play(rc, 2 if reverse else 1, 1 if reverse else 2)
			var rlabel: String = str(d_id) + " / POP Rest descriptor order " + str(reverse) + " with Cuff"
			_check(rres.ok and rres.halves.size() == 2, rlabel + ": commits both halves")
			if rres.ok:
				var d_half: Dictionary = rres.halves[1 if reverse else 0]
				_check(d_half == {"ok": true, "effect": "ally_heal",
					"amount": exp_heal, "block": exp_block, "affected_positions": [1]},
					rlabel + ": returned half block agrees with actual Block")
				_check(rc.party.get_hero(1).block == exp_block,
					rlabel + ": party hero block agrees with returned half block")
				_check(_snapshot(rc) == exp_snap,
					rlabel + ": exact party, deck, energy, RNG and ledgers preserved")

	# Full-HP healing remains legal and cannot overflow a hero's maximum.
	for id in CombatStitchedTargetPreview.POOL_HEAL_IDS:
		var field: bool = id in CombatSeamstressPoolHeals.FIELD_MEND_IDS
		var c := _fixture(id, "warden_brace")
		_check(_play(c, 0 if field else 1, 0).ok, id + ": heal at maximum HP legal")
		_check(c.party.get_hero(1).hp == 40 and c.party.get_hero(2).hp == 30
			and c.party.get_hero(3).hp == 26,
			id + ": full-health recipients capped to three authored maxima")
	var surviving := _fixture("seamstress_field_mend_plus", "warden_brace")
	_check(surviving.party.apply_damage(1, 9)
		and surviving.party.apply_damage(2, 8)
		and surviving.party.apply_damage(3, 26)
		and surviving.party.is_downed(3), "Field Mend party includes genuine downed Tinker")
	var survivor_before := _snapshot(surviving)
	var all := _play(surviving, 0, 0)
	_check(all.ok and all.halves[0].affected_positions == [1, 2]
		and surviving.party.get_hero(1).hp == 37
		and surviving.party.get_hero(2).hp == 28 and surviving.party.get_hero(3).hp == 0,
		"Field Mend+ heals only two living heroes, cannot revive torn Tinker")
	_check(surviving.deck._rng.state == survivor_before[5]
		and surviving.deck.energy == 0 and surviving.deck.discard_pile == [surviving.id],
		"Field Mend+ and Brace commit single three-energy discard, no RNG")


func _test_pool_heal_failures() -> void:
	var c := _fixture("seamstress_field_mend", POP)
	_bind_spool(c)
	_reject(c, 1, 2, "party_all has no manually selected ally or enemy")
	c.deck.try_spend_energy(1)
	_reject(c, 0, 2, "Field Mend stitched cost three must remain affordable")
	c = _fixture("seamstress_field_mend_plus", "warden_brace")
	_bind_spool(c)
	c.deck.discard_played(c.id)
	_reject(c, 0, 0, "missing authentic held Field Mend composite")
	c = _fixture("seamstress_thimble_tea", "warden_brace")
	_bind_spool(c)
	var swapped: Array[Dictionary] = c.party.get_heroes()
	c.party = CombatParty.new([swapped[1], swapped[0], swapped[2]])
	_reject(c, 1, 0, "Tea owner at illegal front FROM")
	c = _fixture("seamstress_thimble_tea_plus", "warden_brace")
	_bind_spool(c)
	_check(c.party.apply_damage(3, 26) and c.party.is_downed(3),
		"chosen ally is truly downed")
	_reject(c, 3, 0, "Tea cannot revive downed chosen ally")
	c = _fixture("seamstress_darning_plus", "warden_brace")
	_bind_spool(c)
	_check(c.party.gain_block(2, CombatParty.MAX_INT), "genuine Darning Block overflow precondition")
	_reject(c, 2, 0, "first Darning overflow rejects before healing or counterpart")
	c = _fixture("seamstress_darning", "warden_brace")
	_bind_spool(c)
	_check(c.party.apply_damage(2, 8) and c.party.gain_block(1, CombatParty.MAX_INT),
		"wounded Seamstress, Warden at full Block before second half")
	_reject(c, 2, 0, "second Brace overflow rolls back first Darning heal plus Block")
	c = _fixture("tinker_tune_up", "seamstress_darning_plus")
	_bind_spool(c)
	c.deck.discard_pile.assign(["warden_strike", POP, "warden_brace"])
	_check(c.party.apply_damage(1, 11)
		and c.party.gain_block(1, CombatParty.MAX_INT),
		"real RNG reshuffle and Darning overflow setup")
	_reject(c, 0, 1, "draw/shuffle first then Darning Block overflow: complete rollback")
	c = _fixture("seamstress_darning", "warden_brace")
	_bind_spool(c, "torn")
	_check(c.party.is_downed(2) and c.wardrobe.project_active(c.torn.read_state()).active.seamstress.is_empty(),
		"authentic sewn Spare Spool wearer torn and patch inactive")
	_reject(c, 1, 0, "torn Seamstress cannot use stitched pool card")
	# Darning Block headroom preflight with Hemguard Cuff:
	# 3 printed Block would fit in 4 headroom, but 5 (3+2) overflows.
	c = _fixture("seamstress_darning", "warden_brace")
	_bind_cuff(c, "sewn_seamstress")
	_check(c.party.gain_block(1, CombatParty.MAX_INT - 4), "genuine Darning headroom precondition (4 left)")
	_reject(c, 1, 0, "Darning with Cuff bonus (+2) overflows 4 headroom, rejects before healing")
	for mode in ["null", "stale_wardrobe", "stale_torn", "drift"]:
		c = _fixture("seamstress_field_mend", "warden_brace")
		_bind_spool(c)
		var w: Dictionary = c.wardrobe.get_snapshot()
		var t: Dictionary = c.torn.read_state()
		match mode:
			"null":
				_check(not c.service.bind_patch_wardrobe(null, c.torn),
					"invalid pool patch binding rejected")
			"stale_wardrobe":
				w.scraps += 1
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, c.torn, w, t),
					"stale pool wardrobe receipt rejected")
			"stale_torn":
				t.heroes[0].hp -= 1
				_check(not c.service.bind_patch_wardrobe(c.wardrobe, c.torn, w, t),
					"stale pool torn receipt rejected")
			"drift":
				_check(c.wardrobe.start_rest("future-rest", w).ok,
					"genuine bound wardrobe ledger drift")
		_reject(c, 0, 0, mode + ": stitched pool binding fails closed")


## AC1/AC3: an authentic paid Rest composite stays playable on an explicitly
## opted-in four-foe roster: one capped payment, one discard, every slot retained,
## and every illegal, forged, stale or failed-half play still atomic.
func _test_four_foe_halves() -> void:
	for reverse in [false, true]:
		var replays: Array = []
		for attempt in range(2):
			var c := _rest_fixture(POP if reverse else PRICK, PRICK if reverse else POP, 42401)
			c.enemies = _four_foes()
			var pop_target := 1 if reverse else 2
			var prick_target := 2 if reverse else 1
			var before := _snapshot(c)
			var expected := before.duplicate(true)
			expected[1] = []
			expected[2] = [c.id]
			expected[3] = 1
			expected[7][pop_target - 1]["hp"] -= 8
			expected[7][prick_target - 1]["hp"] -= 3
			expected[7][prick_target - 1]["statuses"] = {"bleed": 3}
			expected[8] = true
			var label := "four-foe Prick/Pop " + ("Pop first" if reverse else "Prick first")
			var receipt := _play(c, pop_target if reverse else prick_target,
				prick_target if reverse else pop_target)
			_check(receipt.ok and receipt.halves.size() == 2, label + ": both authored halves commit")
			var foes: Array = c.enemies.get_enemies()
			_check(foes.size() == 4
				and foes.map(func(foe): return foe.get("position")) == [1, 2, 3, 4]
				and foes[2]["hp"] == before[7][2]["hp"]
				and foes[3]["hp"] == before[7][3]["hp"],
				label + ": all four enemy slots retained, the two untargeted slots untouched")
			_check(c.deck.energy == 1 and c.deck.discard_pile == [c.id]
				and c.deck.hand.is_empty() and c.deck._rng.state == before[5],
				label + ": one capped charge, exactly one discard and no RNG movement")
			_check(_snapshot(c) == expected,
				label + ": exact HP, statuses, deck, energy, latches and untouched run ledger")
			replays.append([receipt, _snapshot(c)])
		_check(replays.size() == 2 and replays[0] == replays[1],
			"independent same-seed four-foe replay is exact")

	# A starter area half sweeps every living slot in the shared attack resolver,
	# so a living fourth foe it may not target refuses the whole composite with
	# no spend, publish or latch change; once that foe is slain it plays normally.
	var area := _rest_fixture(PRICK, BOMB, 42406)
	area.enemies = _four_foes()
	var area_initial := _snapshot(area)
	_reject(area, 1, 0, "starter area half cannot sweep an unauthored living fourth foe")
	_check(_snapshot(area) == area_initial and area.enemies.get_enemies().size() == 4,
		"refused area play left all four enemy slots and every authority intact")
	_check(area.enemies.apply_damage(4, 999) and area.enemies.apply_damage(4, 999)
		and area.enemies.is_slain(4),
		"fourth foe genuinely slain (its one authored revival spent)")
	var area_playable := _snapshot(area)
	_check(_play(area, 1, 0).ok, "area half plays once only its authored slots stay alive")
	var played_foes: Array = area.enemies.get_enemies()
	_check(played_foes.size() == 4 and area.enemies.is_slain(4)
		and played_foes[3]["position"] == 4
		and played_foes[0]["hp"] < area_playable[7][0]["hp"]
		and played_foes[1]["hp"] < area_playable[7][1]["hp"]
		and played_foes[2]["hp"] < area_playable[7][2]["hp"],
		"authored area recipients stay in their printed slots and never compact")

	# An already slain middle slot stays in place with the fourth foe behind it.
	var slain := _rest_fixture(PRICK, POP, 42404)
	slain.enemies = _four_foes()
	_check(slain.enemies.apply_damage(3, slain.enemies.get_enemy(3).hp)
		and slain.enemies.is_slain(3), "authored third foe genuinely slain before the play")
	var slain_before := _snapshot(slain)
	_check(_play(slain, 1, 2).ok, "composite plays around the slain third slot")
	_check(slain.enemies.get_enemies().size() == 4 and slain.enemies.is_slain(3)
		and slain.enemies.get_enemy(4).get("position") == 4
		and slain.enemies.get_enemy(4).get("hp") == slain_before[7][3]["hp"],
		"slain slot is never compacted and the fourth foe is retained")

	# Illegal targets, forged and stale receipts, and a failed second half.
	var c := _rest_fixture(PRICK, POP, 42402)
	c.enemies = _four_foes()
	_reject(c, 4, 0, "authored first half never reaches the fourth slot")
	_reject(c, 0, 4, "authored second half never reaches the fourth slot")
	_reject(c, 1, 0, "missing second target against four foes")
	_reject(c, 0, 0, "missing first target against four foes")
	_reject(c, 4, 4, "both authored halves refuse the fourth occupied slot")
	_reject(c, 1, 4, "late failure after a staged first half fully rolls back")
	var forged: Dictionary = c.rest.get_snapshot()
	forged.descriptors[c.id].first_half.effects.damage = 999
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors,
		forged.remaining_scraps, forged.next_stitch_id)
	_check(not c.rest.is_valid(), "forged four-foe descriptor really invalidates the ledger")
	_reject(c, 1, 2, "forged four-foe Rest receipt")
	c = _rest_fixture(PRICK, POP, 42403)
	c.enemies = _four_foes()
	c.rest._deck.clear()
	_check(not c.rest.get_snapshot()["deck"].has(c.id)
		and not c.rest.preview_play(c.id, c.party.get_heroes()).get("ok", false),
		"stale four-foe ledger really no longer authorises the composite")
	_reject(c, 1, 2, "stale four-foe Rest ledger")

	# An unopted four-record roster at the default capacity fails closed.
	c = _rest_fixture(PRICK, POP, 42405)
	c.enemies = _unopted_four_foes()
	_check(not c.enemies.is_valid() and c.enemies.get_enemies().size() == 4,
		"unopted fixture really holds four records at the default three capacity")
	_reject(c, 1, 2, "unopted four-slot roster")
	_check(c.enemies.get_enemies().size() == 4,
		"unopted refusal never compacts or drops the fourth record")

	# The unchanged default roster still pays and discards exactly once.
	var small := _rest_fixture(PRICK, POP, 42407)
	_check(small.enemies.get_capacity() == CombatEnemies.MAX_ENEMIES
		and small.enemies.is_valid(), "default two/three-slot roster is genuinely unopted")
	_check(_play(small, 1, 2).ok and small.deck.energy == 1
		and small.deck.discard_pile == [small.id],
		"existing default roster play is unchanged")


## Every base/+ Overclock and Tailor's Trance half must keep its printed
## +1 energy and 3 Block-first self-damage or 2/3 seeded draws when sewn against
## an authored different-owner support half, in either printed order.
func _test_pool_energy_halves() -> void:
	for id in ENERGY_IDS:
		var overclock: bool = id in CombatPoolEnergyCards.OVERCLOCK_IDS
		var authored: Dictionary = {}
		if overclock:
			authored = TinkerPoolCards.new().get_definition(id)
		else:
			authored = SeamstressPoolCards.new().get_definition(id)
		_check(not authored.is_empty()
			and authored == RunRestStitchCards.resolve_card_definition(id),
			id + ": authentic authored cross-owner pool energy half")
		var printed_draw: int = 3 if id.ends_with("_plus") else 2
		for reverse in [false, true]:
			var first: String = SUPPORT_HALF if reverse else id
			var second: String = id if reverse else SUPPORT_HALF
			var c := _rest_fixture(first, second, 4177)
			var tpos := _position_of(c.party, "tinker")
			var wpos := _position_of(c.party, "warden")
			_check(tpos == 3 and wpos == 1, id + ": authored party positions")
			c.deck.discard_pile.assign([POP, PRICK, "warden_strike"])
			if overclock:
				_check(c.party.gain_block(tpos, 2), id + ": real Tinker Block before Overclock")
			var before := _snapshot(c)
			var cost: int = int(c.rest.get_snapshot()["descriptors"][c.id]["cost"])
			_check(cost == 2, id + ": one capped two-cost composite")
			var expected := before.duplicate(true)
			var oracle := _oracle_draw(before[0], before[2],
				0 if overclock else printed_draw, before[5])
			var expected_hand: Array = before[1].duplicate()
			expected_hand.erase(c.id)
			expected_hand.append_array(oracle["drawn"])
			expected[0] = oracle["draw"]
			expected[1] = expected_hand
			expected[2] = oracle["discard"].duplicate()
			expected[2].append(c.id)
			expected[3] = before[3] - cost + 1
			expected[5] = oracle["rng"]
			expected[6][wpos - 1]["block"] += 7
			if overclock:
				expected[6][tpos - 1]["hp"] -= 1
				expected[6][tpos - 1]["block"] = 0
			var label: String = id + (" after Brace" if reverse else " before Brace")
			var result := _play(c, 0, 0)
			_check(result.ok and result.halves.size() == 2, label + ": both halves commit")
			if not result.ok:
				continue
			var expected_energy_half: Dictionary
			if overclock:
				expected_energy_half = {"ok": true, "effect": "gain_energy",
					"amount": 1, "self_hp_loss": 3}
			else:
				expected_energy_half = {"ok": true, "effect": "gain_energy",
					"amount": 1, "draw": printed_draw}
			_check(result.halves[1 if reverse else 0] == expected_energy_half,
				label + ": exact printed energy, self-damage or draw outcome")
			_check(result.halves[0 if reverse else 1] ==
				{"ok": true, "effect": "self_block", "amount": 7},
				label + ": authored Brace half still resolves")
			_check(_snapshot(c) == expected,
				label + ": exact HP/Block, energy, draws, piles, seeded RNG and latches")
			_check(c.deck.energy == 2 and c.deck.discard_pile.count(c.id) == 1
				and not c.deck.hand.has(c.id),
				label + ": one capped charge and one composite discard")

	# The two energy halves sewn together still apply each printed effect once.
	for reverse in [false, true]:
		var first: String = "seamstress_tailors_trance" if reverse else "tinker_overclock"
		var second: String = "tinker_overclock" if reverse else "seamstress_tailors_trance"
		var c := _rest_fixture(first, second, 5419)
		c.deck.discard_pile.assign([POP, PRICK, "warden_strike"])
		var tpos := _position_of(c.party, "tinker")
		_check(c.party.gain_block(tpos, 2), "paired energy half real Block precondition")
		var before := _snapshot(c)
		var cost: int = int(c.rest.get_snapshot()["descriptors"][c.id]["cost"])
		_check(cost == 2, "paired energy halves cost two")
		var expected := before.duplicate(true)
		var oracle := _oracle_draw(before[0], before[2], 2, before[5])
		var expected_hand: Array = before[1].duplicate()
		expected_hand.erase(c.id)
		expected_hand.append_array(oracle["drawn"])
		expected[0] = oracle["draw"]
		expected[1] = expected_hand
		expected[2] = oracle["discard"].duplicate()
		expected[2].append(c.id)
		expected[3] = before[3] - cost + 2
		expected[5] = oracle["rng"]
		expected[6][tpos - 1]["hp"] -= 1
		expected[6][tpos - 1]["block"] = 0
		var label := "paired " + ("Trance/Overclock" if reverse else "Overclock/Trance")
		var result := _play(c, 0, 0)
		_check(result.ok and result.halves.size() == 2, label + ": both energy halves commit")
		if not result.ok:
			continue
		var overclock_half := {"ok": true, "effect": "gain_energy", "amount": 1,
			"self_hp_loss": 3}
		var trance_half := {"ok": true, "effect": "gain_energy", "amount": 1, "draw": 2}
		var expected_halves: Array = []
		if reverse:
			expected_halves = [trance_half, overclock_half]
		else:
			expected_halves = [overclock_half, trance_half]
		_check(result.halves == expected_halves, label + ": each printed effect once in order")
		_check(_snapshot(c) == expected,
			label + ": exact HP, Block, energy, draws, piles, RNG and latches")


## Invalid target, wrong/downed owner, insufficient initial energy and a failing
## later half (including Block overflow after staged energy/draw/self-damage)
## must leave every authority and the RNG exactly unchanged.
func _test_pool_energy_failures() -> void:
	var c := _fixture("tinker_overclock", SUPPORT_HALF)
	_reject(c, 1, 0, "Overclock half has no selectable target")
	_reject(c, 0, 1, "Brace after staged Overclock must reject a nonzero target")
	c = _fixture("seamstress_tailors_trance", SUPPORT_HALF)
	c.deck.discard_pile.assign([POP, PRICK, "warden_strike"])
	_reject(c, 0, 1, "Brace after staged Trance draw must reject a nonzero target")
	c = _fixture(SUPPORT_HALF, "seamstress_tailors_trance")
	c.deck.discard_pile.assign([POP, PRICK, "warden_strike"])
	_reject(c, 1, 0, "Trance after staged Brace must reject a nonzero target")

	c = _fixture("seamstress_tailors_trance", SUPPORT_HALF)
	c.deck.discard_pile.assign([POP, PRICK, "warden_strike"])
	_check(c.party.gain_block(1, CombatParty.MAX_INT), "real Warden Block saturation")
	_reject(c, 0, 0, "Brace overflow rolls back staged Trance draw, energy and RNG")
	c = _fixture("tinker_overclock", SUPPORT_HALF)
	_check(c.party.gain_block(1, CombatParty.MAX_INT),
		"real Warden Block saturation before Overclock")
	_reject(c, 0, 0, "Brace overflow rolls back staged Overclock self-damage and energy")

	c = _fixture("tinker_overclock", SUPPORT_HALF)
	_check(c.deck.try_spend_energy(2) and c.deck.energy == 1,
		"two energy already paid before the composite")
	_reject(c, 0, 0, "two-cost pool energy composite needs two initial energy")
	c = _fixture("tinker_overclock", "warden_shield_bash")
	_check(c.deck.try_spend_energy(1) and c.deck.energy == 2,
		"one energy already paid before the cost-three composite")
	_reject(c, 0, 1, "cost-three pool energy composite needs three initial energy")

	c = _fixture("seamstress_tailors_trance", SUPPORT_HALF)
	var heroes: Array = c.party.get_heroes()
	c.party = CombatParty.new([heroes[1], heroes[0], heroes[2]])
	_reject(c, 0, 0, "Trance owner at an illegal front FROM")
	c = _fixture("tinker_overclock", SUPPORT_HALF)
	_check(c.party.apply_damage(3, 26) and c.party.is_downed(3), "real downed Tinker")
	_reject(c, 0, 0, "downed Overclock owner")
	c = _fixture("seamstress_tailors_trance", SUPPORT_HALF)
	_check(c.party.apply_damage(2, 30) and c.party.is_downed(2), "real downed Seamstress")
	_reject(c, 0, 0, "downed Trance owner")


func _pool_energy_sequence(id: String, reverse: bool, seed_value: int) -> Array:
	var c := _rest_fixture(SUPPORT_HALF if reverse else id,
		id if reverse else SUPPORT_HALF, seed_value)
	c.deck.discard_pile.assign([POP, PRICK, "warden_strike"])
	if id in CombatPoolEnergyCards.OVERCLOCK_IDS:
		_check(c.party.gain_block(_position_of(c.party, "tinker"), 2),
			id + ": replay Block precondition")
	var before := _snapshot(c)
	var result := _play(c, 0, 0)
	_check(result.ok, id + " order " + str(reverse) + ": replay composite commits")
	return [before, result, _snapshot(c)]


func _test_pool_energy_replay() -> void:
	for seed_value in [0, 83, 9741]:
		for id in ENERGY_IDS:
			for reverse in [false, true]:
				_check(_pool_energy_sequence(id, reverse, seed_value)
					== _pool_energy_sequence(id, reverse, seed_value),
					id + " order " + str(reverse) + ": same-seed Rest-to-combat replay")


## Both printed Spare Parts effects in one atomic half: the authored Block goes
## to the living Tinker in her CURRENT slot and exactly one card is drawn with
## the single seeded RNG. Base/+ are genuinely Rest-created, in either order.
func _test_spare_parts_halves() -> void:
	for card_id in SPARE_PARTS_IDS:
		var printed_block: int = 4 if card_id.ends_with("_plus") else 3
		var authored: Dictionary = TinkerPoolCards.new().get_definition(card_id)
		_check(not authored.is_empty()
			and authored == RunRestStitchCards.resolve_card_definition(card_id),
			card_id + ": authentic authored Spare Parts half")
		_check(authored.get("effects") == {"block": printed_block, "draw": 1},
			card_id + ": printed Block and one draw")
		for reverse in [false, true]:
			var c := _rest_fixture(card_id if not reverse else "warden_shield_bash",
				"warden_shield_bash" if not reverse else card_id, 8301)
			c.deck.draw_pile.assign(["warden_brace"])
			var tpos := _position_of(c.party, "tinker")
			_check(tpos == 3 and _position_of(c.party, "warden") == 1,
				card_id + ": authored party positions")
			var cost: int = int(c.rest.get_snapshot()["descriptors"][c.id]["cost"])
			_check(cost == 3 and c.deck.energy == 3 and c.deck.hand == [c.id],
				card_id + ": capped cost three, held composite and three energy")
			var before := _snapshot(c)
			var oracle := _oracle_draw(before[0], before[2], 1, before[5])
			_check(oracle["drawn"] == ["warden_brace"],
				card_id + ": known draw-pile card is the drawn one")
			var expected := before.duplicate(true)
			expected[0] = oracle["draw"]
			expected[1] = oracle["drawn"]
			expected[2] = oracle["discard"].duplicate()
			expected[2].append(c.id)
			expected[3] = 0
			expected[5] = oracle["rng"]
			expected[6][tpos - 1]["block"] = printed_block
			expected[7][0].hp -= 8
			expected[7][0]["statuses"] = {"weak": 1}
			var label: String = card_id + (" second" if reverse else " first")
			var result := _play(c, 1 if reverse else 0, 0 if reverse else 1)
			_check(result.ok and result.halves.size() == 2, label + ": both halves commit")
			if not result.ok:
				continue
			var spare_half := {"ok": true, "effect": "block_and_draw",
				"amount": printed_block, "draw": 1, "drawn": 1}
			var bash_half := {"ok": true, "hits": [_expected_hit(1, 8, 0, {"weak": 1})]}
			_check(result.halves == ([bash_half, spare_half] if reverse
				else [spare_half, bash_half]),
				label + ": exact ordered Block, draw and Shield Bash outcomes")
			_check(c.party.get_hero(tpos).block == printed_block
				and c.deck.hand == ["warden_brace"],
				label + ": exact Tinker Block and one-card hand delta")
			_check(c.deck.energy == 0 and c.deck.discard_pile == [c.id],
				label + ": one capped charge and exactly one discard")
			_check(_snapshot(c) == expected,
				label + ": exact party, piles, enemy, latches and single seeded RNG")

		# An empty draw pile reshuffles the real discard pile with the same
		# injected generator, then only the composite itself is discarded.
		for reverse in [false, true]:
			var refill := _rest_fixture(card_id if not reverse else "warden_brace",
				"warden_brace" if not reverse else card_id, 9741)
			refill.deck.discard_pile.assign(["warden_strike", PRICK, "tinker_tune_up"])
			var rtpos := _position_of(refill.party, "tinker")
			var rcost: int = int(refill.rest.get_snapshot()["descriptors"][refill.id]["cost"])
			_check(rcost == 2, card_id + ": Brace composite costs two")
			var before_refill := _snapshot(refill)
			var oracle_refill := _oracle_draw(before_refill[0], before_refill[2], 1,
				before_refill[5])
			_check(oracle_refill["drawn"].size() == 1 and oracle_refill["rng"] != before_refill[5],
				card_id + ": seeded refill really shuffled one real card")
			var expected_refill := before_refill.duplicate(true)
			expected_refill[0] = oracle_refill["draw"]
			expected_refill[1] = oracle_refill["drawn"]
			expected_refill[2] = oracle_refill["discard"].duplicate()
			expected_refill[2].append(refill.id)
			expected_refill[3] = 1
			expected_refill[5] = oracle_refill["rng"]
			expected_refill[6][rtpos - 1]["block"] = printed_block
			expected_refill[6][0]["block"] = 7
			var rlabel: String = card_id + (" after Brace" if reverse else " before Brace")
			var refill_result := _play(refill, 0, 0)
			_check(refill_result.ok and refill_result.halves.size() == 2,
				rlabel + ": commits from an exhausted draw pile")
			_check(refill.party.get_hero(rtpos).block == printed_block
				and refill.party.get_hero(1).block == 7
				and refill.deck.hand == oracle_refill["drawn"]
				and refill.deck.discard_pile == [refill.id] and refill.deck.energy == 1,
				rlabel + ": exact refilled hand, both Blocks, one charge and one discard")
			_check(_snapshot(refill) == expected_refill,
				rlabel + ": exact seeded refill state and hand delta")

		# Tinker's CURRENT slot receives the Block, not a fixed roster seat.
		var shifted := _rest_fixture(card_id, "warden_brace", 8304)
		var heroes: Array = shifted.party.get_heroes()
		shifted.party = CombatParty.new([heroes[0], heroes[2], heroes[1]])
		_check(_position_of(shifted.party, "tinker") == 2,
			card_id + ": Tinker genuinely moved to the middle slot")
		shifted.deck.draw_pile.assign(["warden_strike"])
		var before_shift := _snapshot(shifted)
		var oracle_shift := _oracle_draw(before_shift[0], before_shift[2], 1, before_shift[5])
		var expected_shift := before_shift.duplicate(true)
		expected_shift[0] = oracle_shift["draw"]
		expected_shift[1] = oracle_shift["drawn"]
		expected_shift[2] = oracle_shift["discard"].duplicate()
		expected_shift[2].append(shifted.id)
		expected_shift[3] = 1
		expected_shift[5] = oracle_shift["rng"]
		expected_shift[6][1]["block"] = printed_block
		expected_shift[6][0]["block"] = 7
		var shift_result := _play(shifted, 0, 0)
		_check(shift_result.ok and shifted.party.get_hero(2).block == printed_block
			and shifted.party.get_hero(3).block == 0,
			card_id + ": Block lands on Tinker's current middle slot only")
		_check(_snapshot(shifted) == expected_shift,
			card_id + ": exact middle-slot Block, drawn card and single discard")

		# Only Tinker's OWN sewn ARM Block patch augments her own half.
		for reverse in [false, true]:
			var patched := _rest_fixture(card_id if not reverse else "warden_brace",
				"warden_brace" if not reverse else card_id, 8303)
			_bind_cuff(patched, "wrong")  # genuine hemguard_cuff sewn on Tinker
			patched.deck.draw_pile.assign(["warden_strike"])
			var ptpos := _position_of(patched.party, "tinker")
			var before_patch := _snapshot(patched)
			var oracle_patch := _oracle_draw(before_patch[0], before_patch[2], 1,
				before_patch[5])
			var expected_patch := before_patch.duplicate(true)
			expected_patch[0] = oracle_patch["draw"]
			expected_patch[1] = oracle_patch["drawn"]
			expected_patch[2] = oracle_patch["discard"].duplicate()
			expected_patch[2].append(patched.id)
			expected_patch[3] = 1
			expected_patch[6][ptpos - 1]["block"] = printed_block + 2
			expected_patch[6][0]["block"] = 7
			var plabel: String = card_id + (" patched after Brace" if reverse
				else " patched before Brace")
			var patch_result := _play(patched, 0, 0)
			_check(patch_result.ok and patched.party.get_hero(ptpos).block == printed_block + 2
				and patched.party.get_hero(1).block == 7,
				plabel + ": Tinker's own Cuff adds +2 to her half only")
			_check(_snapshot(patched) == expected_patch,
				plabel + ": exact patch-augmented Block, drawn card and unchanged RNG")


## No rejection may publish Block, a draw, a discard, energy or RNG movement.
func _test_spare_parts_failures() -> void:
	var spare := SPARE_PARTS_IDS[0]
	var c := _fixture(spare, "warden_brace")
	_reject(c, 1, 0, "Spare Parts self half refuses a selected target")
	_reject(c, 0, 1, "Brace after staged Spare Parts refuses a selected target")
	c = _fixture(PRICK, spare)
	_reject(c, 1, 2, "Spare Parts second half refuses a selected target")

	# A failed later attack half rolls back the staged Block AND a real seeded
	# refill draw; the retry then commits both printed effects exactly once.
	c = _rest_fixture(spare, PRICK, 6101)
	c.deck.discard_pile.assign(["warden_strike", "seamstress_mend", "tinker_tune_up"])
	var tpos := _position_of(c.party, "tinker")
	var cost: int = int(c.rest.get_snapshot()["descriptors"][c.id]["cost"])
	_check(cost == 2 and c.deck.energy == 3, "Spare Parts/Prick composite costs two")
	var before := _snapshot(c)
	_reject(c, 0, 0, "missing second Prick target rolls back staged Block and seeded refill")
	var oracle := _oracle_draw(before[0], before[2], 1, before[5])
	var expected := before.duplicate(true)
	expected[0] = oracle["draw"]
	expected[1] = oracle["drawn"]
	expected[2] = oracle["discard"].duplicate()
	expected[2].append(c.id)
	expected[3] = 1
	expected[5] = oracle["rng"]
	expected[6][tpos - 1]["block"] = 3
	expected[7][1].hp -= 3
	expected[7][1]["statuses"] = {"bleed": 3}
	var retry := _play(c, 0, 2)
	_check(retry.ok and retry.halves == [
		{"ok": true, "effect": "block_and_draw", "amount": 3, "draw": 1, "drawn": 1},
		{"ok": true, "hits": [_expected_hit(2, 3, 0, {"bleed": 3})]}],
		"retry commits both printed Spare Parts effects and Prick once")
	_check(_snapshot(c) == expected,
		"retry exact seeded refill, Block, damage, one charge and one discard")

	# A failing SECOND Spare Parts half rolls back the first Brace Block.
	c = _fixture("warden_brace", spare)
	c.party.gain_block(_position_of(c.party, "tinker"), CombatParty.MAX_INT)
	_check(c.party.get_hero(_position_of(c.party, "tinker")).block == CombatParty.MAX_INT,
		"genuine Tinker Block saturation behind Brace")
	_reject(c, 0, 0, "second Spare Parts Block overflow rolls back first Brace")

	c = _fixture(spare, "warden_shield_bash")
	_check(c.deck.try_spend_energy(1) and c.deck.energy == 2,
		"one energy already paid before the cost-three composite")
	_reject(c, 0, 1, "cost-three Spare Parts composite needs three initial energy")

	c = _fixture(spare, "warden_brace")
	tpos = _position_of(c.party, "tinker")
	_check(c.party.apply_damage(tpos, c.party.get_hero(tpos).hp) and c.party.is_downed(tpos),
		"real downed Tinker")
	_reject(c, 0, 0, "downed Spare Parts owner")

	c = _fixture(spare, "warden_brace")
	var heroes: Array = c.party.get_heroes()
	c.party = CombatParty.new([heroes[2], heroes[1], heroes[0]])
	_check(_position_of(c.party, "tinker") == 1,
		"Tinker genuinely moved to an illegal front FROM slot")
	_reject(c, 0, 0, "Spare Parts owner at an illegal front FROM")

	c = _fixture(spare, "warden_brace")
	var forged: Dictionary = c.rest.get_snapshot()
	forged.descriptors[c.id].first_half.effects.block = 99
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors, 0, 2)
	_check(not c.rest.is_valid(), "preinflated Spare Parts descriptor is truly invalid")
	_reject(c, 0, 0, "forged Spare Parts descriptor cannot grant 99 Block")

	# Even an in-memory half record that disagrees with the real catalog (the
	# exact shape the old generic fallback trusted) must fail closed.
	c = _fixture(spare, "warden_brace")
	_check(c.rest._descriptors[c.id]["first_half"]["effects"]["block"] == 3,
		"live Rest descriptor really carries printed Block three")
	c.rest._descriptors[c.id]["first_half"]["effects"]["block"] = 99
	_reject(c, 0, 0, "inflated live Spare Parts half cannot publish forged Block")

	c = _fixture(spare, "warden_brace")
	c.party.gain_block(_position_of(c.party, "tinker"), CombatParty.MAX_INT)
	_check(c.party.get_hero(_position_of(c.party, "tinker")).block == CombatParty.MAX_INT,
		"genuine Tinker Block saturation")
	_reject(c, 0, 0, "Spare Parts Block overflow rejects before any draw")

	# The battle party can live while the run ledger marks Tinker torn.
	c = _rest_fixture(spare, "warden_brace", 6103)
	var slots: Array = JSON.parse_string(FileAccess.get_file_as_string(
		CombatShopPatchRules.SLOTS_CATALOG))
	c.wardrobe = RunPatchWardrobe.new(c.party.get_heroes(), [], slots, 5)
	c.torn = RunTornMending.new(c.party.get_heroes())
	var start: Array = c.torn.read_state().heroes
	var finish: Array = start.duplicate(true)
	finish[_position_of(c.party, "tinker") - 1].hp = 0
	_check(c.torn.observe_battle_end("spare_parts_tear", start, finish).ok,
		"run ledger records a genuine Tinker tear")
	var state: Dictionary = c.wardrobe.get_snapshot()
	_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes, state.owned,
		state.scraps, state.gold, state.cards, state),
		"wardrobe refreshes the torn run heroes")
	_check(c.party.get_hero(3).hp > 0 and c.torn.read_state().heroes[2].hp == 0,
		"battle Tinker still lives while the run ledger marks her torn")
	_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn),
		"composite authenticated against the torn run ledger")
	_reject(c, 0, 0, "run-torn Tinker cannot earn stitched Spare Parts")


func _spare_parts_sequence(card_id: String, reverse: bool, seed_value: int) -> Array:
	var c := _rest_fixture(card_id if not reverse else "warden_shield_bash",
		"warden_shield_bash" if not reverse else card_id, seed_value)
	c.deck.draw_pile.assign(["warden_brace"])
	var before := _snapshot(c)
	var result := _play(c, 1 if reverse else 0, 0 if reverse else 1)
	return [before, result, _snapshot(c)]


func _test_spare_parts_replay() -> void:
	for seed_value in [0, 83, 9741]:
		for card_id in SPARE_PARTS_IDS:
			for reverse in [false, true]:
				_check(_spare_parts_sequence(card_id, reverse, seed_value)
					== _spare_parts_sequence(card_id, reverse, seed_value),
					card_id + " order " + str(reverse) + ": same-seed Spare Parts replay")


## Independent effect oracle: the ORDINARY Sight Glass resolver on a fresh
## shared deck holding one loose copy over the same piles and RNG state.
func _sight_ordinary(card_id: String, before: Array, target: int,
		wardrobe: RunPatchWardrobe = null, torn: RunTornMending = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var deck := CombatDeck.new([card_id], rng)
	_check(deck.start_turn() and deck.hand == [card_id], "ordinary oracle holds one loose Sight Glass")
	deck.draw_pile.assign(before[0])
	deck.discard_pile.assign(before[2])
	rng.state = before[5]
	var enemies := CombatEnemies.new(_definitions("res://data/enemies/starter_enemies.json"))
	var party := CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
	var gadgets := CombatTinkerPoolGadgets.new()
	if wardrobe != null:
		_check(gadgets.bind_patch_wardrobe(wardrobe, torn), "ordinary oracle shares the real patch authorities")
	var result := gadgets.resolve_sight_glass(deck, party, enemies, card_id, target)
	return {"result": result, "deck": deck, "enemies": enemies}


func _bind_visor(c: Dictionary, wearer: String) -> void:
	c.wardrobe = RunPatchWardrobe.new(c.party.get_heroes(), ["button_glass_visor"],
		[{"id": "button_glass_visor", "slot": "HEAD"}], 10)
	c.torn = RunTornMending.new(c.party.get_heroes())
	_check(c.wardrobe.is_valid() and c.torn.is_valid(), "genuine Visor run authorities")
	_check(c.wardrobe.sew("button_glass_visor", wearer, "HEAD", "sight-visor-" + wearer,
		c.wardrobe.get_snapshot()).ok, "Button Glass Visor genuinely sewn on " + wearer)
	_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn),
		"stitched resolver binds the current Visor wardrobe/torn ledgers")


func _sight_result(target: int, exposed: int = 2, drawn: int = 1) -> Dictionary:
	return {"ok": true, "effect": "exposed_and_draw", "exposed_applied": exposed,
		"draw": 1, "drawn": drawn, "target": target}


func _test_sight_glass_halves() -> void:
	var brace := {"ok": true, "effect": "self_block", "amount": 7}
	for card_id in SIGHT_GLASS_IDS:
		var authored: Dictionary = TinkerPoolCards.new().get_definition(card_id)
		_check(not authored.is_empty()
			and authored == RunRestStitchCards.resolve_card_definition(card_id),
			card_id + ": authentic authored Sight Glass half")
		_check(authored.get("effects") == {"exposed": 2, "draw": 1} and authored.get("cost") == 1
			and authored.get("target_kind") == "enemy_single" and authored.get("from_positions") == [2, 3],
			card_id + ": printed Exposed 2 and one draw on one enemy from the back")
		for target in [1, 2]:
			for reverse in [false, true]:
				var label: String = "%s %s Brace on foe %d" % [card_id, "after" if reverse else "before", target]
				var c := _rest_fixture(SUPPORT_HALF if reverse else card_id,
					card_id if reverse else SUPPORT_HALF, 8401 + target)
				c.deck.draw_pile.assign([PRICK, "warden_strike"])
				c.deck.discard_pile.assign([BOMB])
				var cost: int = int(c.rest.get_snapshot()["descriptors"][c.id]["cost"])
				_check(cost == 2 and c.deck.energy == 3 and c.deck.hand == [c.id],
					label + ": held composite at its shared cost two")
				var before := _snapshot(c)
				var oracle := _oracle_draw(before[0], before[2], 1, before[5])
				_check(oracle["drawn"] == ["warden_strike"], label + ": top draw-pile card is the drawn one")
				var ordinary := _sight_ordinary(card_id, before, target)
				_check(ordinary.result.get("ok", false) and ordinary.result.get("exposed_applied") == 2,
					label + ": ordinary oracle applies printed Exposed 2")
				var expected := before.duplicate(true)
				expected[0] = oracle["draw"]
				expected[1] = oracle["drawn"]
				expected[2] = oracle["discard"].duplicate()
				expected[2].append(c.id)
				expected[3] = 3 - cost
				expected[5] = oracle["rng"]
				expected[6][0]["block"] = 7
				expected[7] = ordinary.enemies.get_enemies()
				var result := _play(c, 0 if reverse else target, target if reverse else 0)
				var sight := _sight_result(target)
				_check(result == {"ok": true, "halves": [brace, sight] if reverse else [sight, brace]},
					label + ": exact ordered Exposed/draw and Brace outcomes")
				_check(c.enemies.get_enemy(target).get("statuses", {}).get("exposed", 0) == 2
					and c.enemies.get_enemy(3 - target).get("statuses", {}).get("exposed", 0) == 0,
					label + ": Exposed lands on the chosen foe only")
				_check(c.deck.hand == ordinary.deck.hand and c.deck.draw_pile == ordinary.deck.draw_pile
					and c.deck._rng.state == ordinary.deck._rng.state,
					label + ": shared-hand draw equals the ordinary Sight Glass draw")
				_check(c.deck.energy == 3 - cost and c.deck.discard_pile.count(c.id) == 1
					and not c.deck.hand.has(c.id), label + ": one composite charge and one discard")
				for pile in [c.deck.draw_pile, c.deck.hand, c.deck.discard_pile]:
					_check(not pile.has(card_id) and not pile.has(SUPPORT_HALF),
						label + ": no loose half leaks into a pile")
				_check(_snapshot(c) == expected,
					label + ": exact piles, energy, party, enemies, latches and seeded RNG")
				_check(not c.attacks._tinker._consumed and c.attacks._tinker.bonus_for_attack(POP) == 3,
					label + ": nonattack leaves Tinker's first-attack +3 unspent")

		# Authored half order: Exposed before Shield Bash is read by that hit,
		# Exposed after it is not. Both sides come from independent oracles.
		for reverse in [false, true]:
			var label: String = card_id + (" after Shield Bash" if reverse else " before Shield Bash")
			var c := _rest_fixture("warden_shield_bash" if reverse else card_id,
				card_id if reverse else "warden_shield_bash", 8411)
			c.deck.draw_pile.assign(["warden_brace"])
			var enemies := CombatEnemies.new(_definitions("res://data/enemies/starter_enemies.json"))
			var party := CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
			if not reverse:
				_check(enemies.apply_statuses({1: {"exposed": 2}}), label + ": oracle Exposed first")
			var bash: Dictionary = CombatAttackCards.new().resolve_staged_half(party, enemies,
				"warden_shield_bash", 1, 0)
			if reverse:
				_check(enemies.apply_statuses({1: {"exposed": 2}}), label + ": oracle Exposed after the hit")
			var result := _play(c, 1, 1)
			_check(bash.get("ok", false) and result == {"ok": true,
				"halves": [bash, _sight_result(1)] if reverse else [_sight_result(1), bash]},
				label + ": exact authored-order Exposed and Shield Bash outcomes")
			_check(c.enemies.get_enemies() == enemies.get_enemies(), label + ": exact enemy HP and statuses")
			_check(c.deck.hand == ["warden_brace"] and c.deck.energy == 0 and c.deck.discard_pile == [c.id],
				label + ": one capped charge, one draw and one discard")

		# HEAD Button Glass Visor adds +1 Exposed for its Tinker wearer only.
		for wearer in ["tinker", "seamstress", "warden"]:
			var label: String = card_id + " with Visor on " + wearer
			var c := _rest_fixture(card_id, SUPPORT_HALF, 8421)
			_bind_visor(c, wearer)
			c.deck.draw_pile.assign(["warden_strike"])
			var before := _snapshot(c)
			var bonus: int = 1 if wearer == "tinker" else 0
			var ordinary := _sight_ordinary(card_id, before, 2, c.wardrobe, c.torn)
			_check(ordinary.result.get("exposed_applied", -1) == 2 + bonus,
				label + ": ordinary oracle prices the wearer-only Visor")
			var ledger: Dictionary = c.wardrobe.get_snapshot()
			var result := _play(c, 2, 0)
			_check(result == {"ok": true, "halves": [_sight_result(2, 2 + bonus), brace]},
				label + ": stitched half applies exactly Exposed " + str(2 + bonus))
			_check(c.enemies.get_enemies() == ordinary.enemies.get_enemies()
				and c.deck.hand == ordinary.deck.hand and c.wardrobe.get_snapshot() == ledger,
				label + ": exact enemy, hand and untouched run ledger")

		# An empty draw pile reshuffles the real discard with the seeded deck RNG.
		var refill := _rest_fixture(card_id, SUPPORT_HALF, 9743)
		refill.deck.discard_pile.assign(["warden_strike", PRICK, "tinker_tune_up"])
		var before_refill := _snapshot(refill)
		var oracle_refill := _oracle_draw(before_refill[0], before_refill[2], 1, before_refill[5])
		_check(oracle_refill["drawn"].size() == 1 and oracle_refill["rng"] != before_refill[5],
			card_id + ": seeded refill really shuffles one real card")
		var ordinary_refill := _sight_ordinary(card_id, before_refill, 1)
		var expected_refill := before_refill.duplicate(true)
		expected_refill[0] = oracle_refill["draw"]
		expected_refill[1] = oracle_refill["drawn"]
		expected_refill[2] = oracle_refill["discard"].duplicate()
		expected_refill[2].append(refill.id)
		expected_refill[3] = 1
		expected_refill[5] = oracle_refill["rng"]
		expected_refill[6][0]["block"] = 7
		expected_refill[7] = ordinary_refill.enemies.get_enemies()
		_check(_play(refill, 1, 0) == {"ok": true, "halves": [_sight_result(1), brace]},
			card_id + ": commits from an exhausted draw pile")
		_check(_snapshot(refill) == expected_refill and refill.deck.hand == ordinary_refill.deck.hand
			and refill.deck._rng.state == ordinary_refill.deck._rng.state,
			card_id + ": exact seeded refill equals both draw oracles")

		# No supply at all legally draws nothing; the held composite is never redrawn.
		var dry := _rest_fixture(card_id, SUPPORT_HALF, 9744)
		_check(dry.deck.draw_pile.is_empty() and dry.deck.discard_pile.is_empty(),
			card_id + ": genuinely exhausted supply")
		var dry_rng: int = dry.deck._rng.state
		_check(_play(dry, 1, 0) == {"ok": true, "halves": [_sight_result(1, 2, 0), brace]}
			and dry.deck.hand.is_empty() and dry.deck.discard_pile == [dry.id]
			and dry.deck._rng.state == dry_rng,
			card_id + ": empty supply draws zero and discards only the composite")


## No rejection may publish Exposed, a draw, a discard, energy or RNG movement.
func _test_sight_glass_failures() -> void:
	for card_id in SIGHT_GLASS_IDS:
		var c := _fixture(card_id, SUPPORT_HALF)
		for target in [0, 3, 4, 99, -1]:
			_reject(c, target, 0, card_id + ": Sight Glass target " + str(target))
		_reject(c, 1, 1, card_id + ": Brace refuses a selected target")
		c = _fixture(SUPPORT_HALF, card_id)
		_reject(c, 0, 0, card_id + ": second Sight Glass without a target rolls back Brace")
		_reject(c, 0, 3, card_id + ": second Sight Glass on an empty slot rolls back Brace")
		c = _fixture(card_id, SUPPORT_HALF)
		_check(c.enemies.apply_damage(2, c.enemies.get_enemy(2).hp) and c.enemies.is_slain(2),
			card_id + ": real slain second foe")
		_reject(c, 2, 0, card_id + ": dead Sight Glass target")
		c = _fixture(SUPPORT_HALF, card_id)
		_check(c.enemies.apply_damage(1, c.enemies.get_enemy(1).hp) and c.enemies.is_slain(1),
			card_id + ": real slain first foe")
		_reject(c, 0, 1, card_id + ": dead second-half target rolls back Brace")
		c = _fixture(card_id, SUPPORT_HALF)
		_check(c.enemies.apply_statuses({1: {"exposed": CombatEnemies.MAX_INT - 1}}),
			card_id + ": genuine near-saturated Exposed")
		_reject(c, 1, 0, card_id + ": Exposed overflow rejects before any draw")

	var sight: String = SIGHT_GLASS_IDS[0]
	# A failing later Prick rolls back the staged Exposed AND a seeded refill;
	# the legal retry then commits both printed effects exactly once.
	var c := _rest_fixture(sight, PRICK, 6111)
	c.deck.discard_pile.assign(["warden_strike", "seamstress_mend", "tinker_tune_up"])
	var cost: int = int(c.rest.get_snapshot()["descriptors"][c.id]["cost"])
	_check(cost == 2 and c.deck.energy == 3, "Sight Glass/Prick composite costs two")
	var before := _snapshot(c)
	_reject(c, 1, 0, "missing Prick target rolls back staged Exposed and seeded refill")
	_reject(c, 1, 3, "empty-slot Prick target rolls back staged Exposed and seeded refill")
	var oracle := _oracle_draw(before[0], before[2], 1, before[5])
	var retry := _play(c, 1, 2)
	_check(retry.ok and retry.halves.size() == 2 and retry.halves[0] == _sight_result(1)
		and retry.halves[1].get("hits", []).size() == 1 and retry.halves[1].hits[0].position == 2,
		"retry commits Sight Glass and Prick once")
	_check(c.deck.hand == oracle["drawn"] and c.deck.draw_pile == oracle["draw"]
		and c.deck.discard_pile == oracle["discard"] + [c.id] and c.deck.energy == 1
		and c.deck._rng.state == oracle["rng"]
		and c.enemies.get_enemy(1).get("statuses", {}).get("exposed", 0) == 2,
		"retry exact seeded refill, Exposed, one charge and one discard")

	c = _fixture(sight, "warden_shield_bash")
	_check(c.deck.try_spend_energy(1) and c.deck.energy == 2,
		"one energy already paid before the cost-three composite")
	_reject(c, 1, 1, "cost-three Sight Glass composite needs three energy")
	c = _fixture(sight, SUPPORT_HALF)
	_check(c.deck.try_spend_energy(2) and c.deck.energy == 1, "only one energy left")
	_reject(c, 1, 0, "cost-two Sight Glass composite needs two energy")

	c = _fixture(sight, SUPPORT_HALF)
	var tpos := _position_of(c.party, "tinker")
	_check(c.party.apply_damage(tpos, c.party.get_hero(tpos).hp) and c.party.is_downed(tpos),
		"real downed Tinker")
	_reject(c, 1, 0, "downed Sight Glass owner")

	c = _fixture(sight, SUPPORT_HALF)
	var heroes: Array = c.party.get_heroes()
	c.party = CombatParty.new([heroes[2], heroes[1], heroes[0]])
	_check(_position_of(c.party, "tinker") == 1, "Tinker genuinely moved to an illegal front FROM slot")
	_reject(c, 1, 0, "Sight Glass owner at an illegal front FROM")

	c = _fixture(sight, SUPPORT_HALF)
	var forged: Dictionary = c.rest.get_snapshot()
	forged.descriptors[c.id].first_half.effects.exposed = 99
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors, 0, 2)
	_check(not c.rest.is_valid(), "preinflated Sight Glass descriptor is truly invalid")
	_reject(c, 1, 0, "forged Sight Glass descriptor cannot grant 99 Exposed")

	for field in ["exposed", "draw"]:
		c = _fixture(sight, SUPPORT_HALF)
		_check(c.rest._descriptors[c.id]["first_half"]["effects"].has(field),
			"live Rest descriptor really carries printed " + field)
		c.rest._descriptors[c.id]["first_half"]["effects"][field] = 9
		_reject(c, 1, 0, "inflated live Sight Glass " + field + " fails closed")
	c = _fixture(sight, SUPPORT_HALF)
	c.rest._descriptors[c.id]["first_half"]["to_positions"] = [1, 2, 3, 4]
	_reject(c, 1, 0, "widened live Sight Glass TO fails closed")

	# A Visor receipt that changed after the bind is stale and grants nothing.
	c = _fixture(sight, SUPPORT_HALF)
	_bind_visor(c, "tinker")
	_check(c.wardrobe.start_rest("stale-sight", c.wardrobe.get_snapshot()).ok,
		"genuine authority change after the Visor bind")
	_reject(c, 1, 0, "stale Visor patch receipt")

	# The battle party can live while the run ledger marks Tinker torn.
	c = _rest_fixture(sight, SUPPORT_HALF, 6113)
	var slots: Array = JSON.parse_string(FileAccess.get_file_as_string(
		CombatShopPatchRules.SLOTS_CATALOG))
	c.wardrobe = RunPatchWardrobe.new(c.party.get_heroes(), [], slots, 5)
	c.torn = RunTornMending.new(c.party.get_heroes())
	var start: Array = c.torn.read_state().heroes
	var finish: Array = start.duplicate(true)
	finish[_position_of(c.party, "tinker") - 1].hp = 0
	_check(c.torn.observe_battle_end("sight_glass_tear", start, finish).ok,
		"run ledger records a genuine Tinker tear")
	var state: Dictionary = c.wardrobe.get_snapshot()
	_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes, state.owned,
		state.scraps, state.gold, state.cards, state), "wardrobe refreshes the torn run heroes")
	_check(c.party.get_hero(3).hp > 0 and c.torn.read_state().heroes[2].hp == 0,
		"battle Tinker still lives while the run ledger marks her torn")
	_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn),
		"composite authenticated against the torn run ledger")
	_reject(c, 1, 0, "run-torn Tinker cannot earn stitched Sight Glass")


func _sight_glass_sequence(card_id: String, reverse: bool, seed_value: int) -> Array:
	var c := _rest_fixture(card_id if not reverse else SUPPORT_HALF,
		SUPPORT_HALF if not reverse else card_id, seed_value)
	c.deck.discard_pile.assign(["warden_strike", PRICK, "tinker_tune_up", BOMB])
	var before := _snapshot(c)
	var result := _play(c, 0 if reverse else 2, 2 if reverse else 0)
	return [before, result, _snapshot(c)]


func _test_sight_glass_replay() -> void:
	for seed_value in [0, 83, 9741]:
		for card_id in SIGHT_GLASS_IDS:
			for reverse in [false, true]:
				var first := _sight_glass_sequence(card_id, reverse, seed_value)
				_check(first[1].get("ok", false), card_id + " order " + str(reverse) + ": replay witness commits")
				_check(first == _sight_glass_sequence(card_id, reverse, seed_value),
					card_id + " order " + str(reverse) + ": same-seed Sight Glass replay")


func _bind_cuff(c: Dictionary, mode: String = "sewn_warden") -> void:
	var slots: Array = [
		{"id": "stitched_badge", "slot": "HEAD"},
		{"id": "spare_spool", "slot": "ARM"},
		{"id": "hemguard_cuff", "slot": "ARM"},
		{"id": "threadguard_wrap", "slot": "ARM"}
	]
	var owned: Array = []
	if mode == "sewn_threadguard":
		owned.append("threadguard_wrap")
	elif mode != "absent":
		owned.append("hemguard_cuff")
	c.wardrobe = RunPatchWardrobe.new(c.party.get_heroes(), owned, slots, 5)
	c.torn = RunTornMending.new(c.party.get_heroes())
	_check(c.wardrobe.is_valid() and c.torn.is_valid(), "real valid stitched cuff authorities")
	if mode not in ["absent", "unsewn"]:
		var wearer: String = "warden"
		if mode in ["sewn_seamstress", "target_cuff", "torn_seamstress", "torn_divergent", "sewn_threadguard"]:
			wearer = "seamstress"
		elif mode == "wrong":
			wearer = "tinker"
		var patch_name: String = "threadguard_wrap" if mode == "sewn_threadguard" else "hemguard_cuff"
		_check(c.wardrobe.sew(patch_name, wearer, "ARM", "stitched-cuff-sew", c.wardrobe.get_snapshot()).ok, "stitched fixture sews Cuff")
	if mode == "moved":
		_check(c.wardrobe.start_rest("rest", c.wardrobe.get_snapshot()).ok, "real Rest opens")
		_check(c.wardrobe.re_sew("hemguard_cuff", "warden", "seamstress", "rest", "cuff-move", c.wardrobe.get_snapshot()).ok, "stitched Cuff moves to seamstress")
		_check(c.wardrobe.end_rest("rest", c.wardrobe.get_snapshot()).ok, "real Rest closes")
	if mode == "torn" or mode == "torn_seamstress":
		var hero_idx: int = 1 if mode == "torn_seamstress" else 0
		var start: Array = c.torn.read_state().heroes
		var finish: Array = start.duplicate(true)
		finish[hero_idx].hp = 0
		_check(torn_observe(c.torn, start, finish), "actual stitched tear")
		var state: Dictionary = c.wardrobe.get_snapshot()
		_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes, state.owned, state.scraps, state.gold, state.cards, state), "stitched wardrobe refreshes torn hero")
		c.party._heroes.assign(c.torn.read_state().heroes)
	if mode == "torn_divergent":
		var start: Array = c.torn.read_state().heroes
		var finish: Array = start.duplicate(true)
		finish[1].hp = 0
		_check(torn_observe(c.torn, start, finish), "actual stitched tear divergent")
		var state: Dictionary = c.wardrobe.get_snapshot()
		_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes, state.owned, state.scraps, state.gold, state.cards, state), "stitched wardrobe refreshes torn divergent")
	if mode != "unbound":
		_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn), "stitched explicit Cuff binding")


func torn_observe(torn: RunTornMending, start: Array, finish: Array) -> bool:
	return torn.observe_battle_end("tear", start, finish).ok


func _cuff_sequence(seed_value: int, reverse: bool) -> Array:
	var c := _fixture(PRICK if reverse else "warden_brace", "warden_brace" if reverse else PRICK, seed_value)
	_bind_cuff(c, "sewn_warden")
	var ledger := [c.wardrobe.get_snapshot(), c.torn.read_state()]
	var before := _snapshot(c)
	_reject(c, 0, 0 if reverse else 99, "later half fails after Brace or Prick")
	var expected := before.duplicate(true)
	expected[1] = []
	expected[2] = [c.id]
	expected[3] = 1
	expected[6][0].block = 9
	expected[7][0].hp -= 3
	expected[7][0]["statuses"] = {"bleed": 3}
	_check(_play(c, 1 if reverse else 0, 0 if reverse else 1).ok, "bound Cuff composite commits either order")
	_check(_snapshot(c) == expected, "nine real Block (7+2), 3 Prick damage, exact one charge/discard and no RNG draw")
	_check(ledger == [c.wardrobe.get_snapshot(), c.torn.read_state()], "composite leaves authoritative ledgers pristine")
	return [before, _snapshot(c), ledger]


func _test_hemguard_cuff() -> void:
	for seed_value in [0, 83, 9741]:
		for reverse in [false, true]:
			_check(_cuff_sequence(seed_value, reverse) == _cuff_sequence(seed_value, reverse), "bound Cuff composite exact seeded replay in each order")

	# AC3: Brace + Prick in both orders with Cuff on Warden
	for reverse in [false, true]:
		for mode in ["absent", "unsewn", "wrong", "moved", "unbound", "sewn_warden"]:
			var c := _fixture(PRICK if reverse else "warden_brace", "warden_brace" if reverse else PRICK)
			_bind_cuff(c, mode)
			var before := _snapshot(c)
			var expected := before.duplicate(true)
			expected[1] = []
			expected[2] = [c.id]
			expected[3] = 1
			expected[6][0].block = 9 if mode == "sewn_warden" else 7
			expected[7][0].hp -= 3
			expected[7][0]["statuses"] = {"bleed": 3}
			_check(_play(c, 1 if reverse else 0, 0 if reverse else 1).ok, mode + " Brace/Prick commits both orders")
			_check(_snapshot(c) == expected, mode + " exact 7 or 9 Block, piles/energy/RNG pristine")

	# AC3: Upgraded half warden_brace_plus retains upgrade and receives +2 (10+2 = 12)
	for reverse in [false, true]:
		var c := _fixture(PRICK if reverse else "warden_brace_plus", "warden_brace_plus" if reverse else PRICK)
		_bind_cuff(c, "sewn_warden")
		var before := _snapshot(c)
		var expected := before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[6][0].block = 12
		expected[7][0].hp -= 3
		expected[7][0]["statuses"] = {"bleed": 3}
		_check(_play(c, 1 if reverse else 0, 0 if reverse else 1).ok, "Brace+/Prick commits both orders with 12 Block")
		_check(_snapshot(c) == expected, "exact 12 Block for Brace+ with Cuff")

	# AC3: Seamstress Stitch Up with Cuff on Seamstress
	for reverse in [false, true]:
		var c := _fixture(POP if reverse else "seamstress_stitch_up", "seamstress_stitch_up" if reverse else POP)
		_bind_cuff(c, "sewn_seamstress")
		var before := _snapshot(c)
		var expected := before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[6][0].block = 7
		expected[7][1].hp -= 8
		expected[8] = true
		_check(_play(c, 2 if reverse else 1, 1 if reverse else 2).ok, "Stitch Up/Pop commits with Cuff on Seamstress")
		_check(_snapshot(c) == expected, "exact 7 Block (5+2) for Stitch Up on ally with Cuff on Seamstress")

	# AC3: Upgraded seamstress_stitch_up_plus with Cuff on Seamstress (7+2 = 9)
	for reverse in [false, true]:
		var c := _fixture(POP if reverse else "seamstress_stitch_up_plus", "seamstress_stitch_up_plus" if reverse else POP)
		_bind_cuff(c, "sewn_seamstress")
		var before := _snapshot(c)
		var expected := before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[6][0].block = 9
		expected[7][1].hp -= 8
		expected[8] = true
		_check(_play(c, 2 if reverse else 1, 1 if reverse else 2).ok, "Stitch Up+/Pop commits with 9 Block")
		_check(_snapshot(c) == expected, "exact 9 Block for Stitch Up+ with Cuff")

	# AC3: Cuff on target rather than owner gives NO bonus
	for reverse in [false, true]:
		var c := _fixture(POP if reverse else "seamstress_stitch_up", "seamstress_stitch_up" if reverse else POP)
		_bind_cuff(c, "sewn_warden")
		var before := _snapshot(c)
		var expected := before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[6][0].block = 5
		expected[7][1].hp -= 8
		expected[8] = true
		_check(_play(c, 2 if reverse else 1, 1 if reverse else 2).ok, "Stitch Up targeting cuff wearer Warden gives base 5 Block")
		_check(_snapshot(c) == expected, "exact 5 Block when cuff is on target rather than card owner")

	# Replay check for Darning + Hemguard Cuff
	for seed_value: int in [0, 83, 9741]:
		for reverse: bool in [false, true]:
			for upgraded: bool in [false, true]:
				_check(_darning_cuff_sequence(seed_value, reverse, upgraded)
					== _darning_cuff_sequence(seed_value, reverse, upgraded),
					"bound Cuff Darning (upgraded: %s) exact replay order %s" % [str(upgraded), str(reverse)])

	# AC1: Darning + POP in both orders with Cuff on Seamstress (heal 4, Block 5)
	for reverse: bool in [false, true]:
		var c := _fixture(POP if reverse else "seamstress_darning", "seamstress_darning" if reverse else POP)
		_bind_cuff(c, "sewn_seamstress")
		_check(c.party.apply_damage(1, 10), "precondition wound for Darning")
		var before: Array = _snapshot(c)
		var expected: Array = before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[6][0].hp += 4
		expected[6][0].block = 5
		expected[7][1].hp -= 8
		expected[8] = true
		var res := _play(c, 2 if reverse else 1, 1 if reverse else 2)
		_check(res.ok and res.halves.size() == 2, "Darning/Pop commits both orders with Cuff on Seamstress")
		if res.ok:
			var d_half: Dictionary = res.halves[1 if reverse else 0]
			_check(d_half == {"ok": true, "effect": "ally_heal", "amount": 4, "block": 5, "affected_positions": [1]},
				"exact heal 4 and block 5 for Darning half with Cuff")
			_check(c.party.get_hero(1).block == 5, "exact 5 Block on ally with Cuff on Seamstress")
		_check(_snapshot(c) == expected, "exact party HP/Block, enemy, deck, energy and ledgers for Darning with Cuff")

	# AC1: Upgraded Darning+ + POP in both orders with Cuff on Seamstress (heal 6, Block 6)
	for reverse: bool in [false, true]:
		var c := _fixture(POP if reverse else "seamstress_darning_plus", "seamstress_darning_plus" if reverse else POP)
		_bind_cuff(c, "sewn_seamstress")
		_check(c.party.apply_damage(1, 10), "precondition wound for Darning+")
		var before: Array = _snapshot(c)
		var expected: Array = before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[6][0].hp += 6
		expected[6][0].block = 6
		expected[7][1].hp -= 8
		expected[8] = true
		var res := _play(c, 2 if reverse else 1, 1 if reverse else 2)
		_check(res.ok and res.halves.size() == 2, "Darning+/Pop commits both orders with Cuff on Seamstress")
		if res.ok:
			var d_half: Dictionary = res.halves[1 if reverse else 0]
			_check(d_half == {"ok": true, "effect": "ally_heal", "amount": 6, "block": 6, "affected_positions": [1]},
				"exact heal 6 and block 6 for Darning+ half with Cuff")
			_check(c.party.get_hero(1).block == 6, "exact 6 Block on ally with Cuff on Seamstress")
		_check(_snapshot(c) == expected, "exact party HP/Block, enemy, deck, energy and ledgers for Darning+ with Cuff")

	# AC1: Darning + Brace in both orders with Cuff on Seamstress
	for reverse: bool in [false, true]:
		var c := _fixture("warden_brace" if reverse else "seamstress_darning", "seamstress_darning" if reverse else "warden_brace")
		_bind_cuff(c, "sewn_seamstress")
		_check(c.party.apply_damage(1, 10), "precondition wound for Darning/Brace")
		var before: Array = _snapshot(c)
		var expected: Array = before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[6][0].hp += 4
		expected[6][0].block = 12
		var res := _play(c, 0 if reverse else 1, 1 if reverse else 0)
		_check(res.ok and res.halves.size() == 2, "Darning/Brace commits both orders with Cuff on Seamstress")
		if res.ok:
			var d_half: Dictionary = res.halves[1 if reverse else 0]
			_check(d_half.block == 5, "Darning half reports 5 Block")
			_check(c.party.get_hero(1).block == 12, "Warden receives 12 Block (5 Darning + 7 Brace)")
		_check(_snapshot(c) == expected, "exact party HP/Block for Darning/Brace with Cuff")

	# AC1: Upgraded Darning+ + Brace in both orders with Cuff on Seamstress
	for reverse: bool in [false, true]:
		var c := _fixture("warden_brace" if reverse else "seamstress_darning_plus", "seamstress_darning_plus" if reverse else "warden_brace")
		_bind_cuff(c, "sewn_seamstress")
		_check(c.party.apply_damage(1, 10), "precondition wound for Darning+/Brace")
		var before: Array = _snapshot(c)
		var expected: Array = before.duplicate(true)
		expected[1] = []
		expected[2] = [c.id]
		expected[3] = 1
		expected[6][0].hp += 6
		expected[6][0].block = 13
		var res := _play(c, 0 if reverse else 1, 1 if reverse else 0)
		_check(res.ok and res.halves.size() == 2, "Darning+/Brace commits both orders with Cuff on Seamstress")
		if res.ok:
			var d_half: Dictionary = res.halves[1 if reverse else 0]
			_check(d_half.block == 6, "Darning+ half reports 6 Block")
			_check(c.party.get_hero(1).block == 13, "Warden receives 13 Block (6 Darning+ + 7 Brace)")
		_check(_snapshot(c) == expected, "exact party HP/Block for Darning+/Brace with Cuff")

	# AC2: Negative modes for Darning and Darning+ (absent, unsewn, wrong, sewn_warden, unbound)
	for reverse: bool in [false, true]:
		for mode: String in ["absent", "unsewn", "wrong", "sewn_warden", "unbound"]:
			for upgraded: bool in [false, true]:
				var d_card: String = "seamstress_darning_plus" if upgraded else "seamstress_darning"
				var c := _fixture(POP if reverse else d_card, d_card if reverse else POP)
				_bind_cuff(c, mode)
				_check(c.party.apply_damage(1, 10), "precondition wound for Darning negative")
				var before: Array = _snapshot(c)
				var expected: Array = before.duplicate(true)
				expected[1] = []
				expected[2] = [c.id]
				expected[3] = 1
				var exp_h: int = 6 if upgraded else 4
				var exp_b: int = 4 if upgraded else 3
				expected[6][0].hp += exp_h
				expected[6][0].block = exp_b
				expected[7][1].hp -= 8
				expected[8] = true
				var res := _play(c, 2 if reverse else 1, 1 if reverse else 2)
				var mode_lbl: String = mode + " Darning" + ("+" if upgraded else "") + " order " + str(reverse)
				_check(res.ok and res.halves.size() == 2, mode_lbl + ": commits with unaugmented Block")
				if res.ok:
					var d_half: Dictionary = res.halves[1 if reverse else 0]
					_check(d_half.block == exp_b, mode_lbl + ": exact authored Block " + str(exp_b))
					_check(c.party.get_hero(1).block == exp_b, mode_lbl + ": party hero block agrees with authored Block")
				_check(_snapshot(c) == expected, mode_lbl + ": preserves complete state with authored Block")

	# Authored Threadguard Wrap (+1 ARM Block) alternative on Seamstress
	for reverse: bool in [false, true]:
		for upgraded: bool in [false, true]:
			var d_card: String = "seamstress_darning_plus" if upgraded else "seamstress_darning"
			var c := _fixture(POP if reverse else d_card, d_card if reverse else POP)
			_bind_cuff(c, "sewn_threadguard")
			_check(c.party.apply_damage(1, 10), "precondition wound for Threadguard Darning")
			var before: Array = _snapshot(c)
			var expected: Array = before.duplicate(true)
			expected[1] = []
			expected[2] = [c.id]
			expected[3] = 1
			var exp_h: int = 6 if upgraded else 4
			var exp_b: int = 5 if upgraded else 4
			expected[6][0].hp += exp_h
			expected[6][0].block = exp_b
			expected[7][1].hp -= 8
			expected[8] = true
			var res := _play(c, 2 if reverse else 1, 1 if reverse else 2)
			var tg_lbl: String = "Threadguard Darning" + ("+" if upgraded else "") + " order " + str(reverse)
			_check(res.ok and res.halves.size() == 2, tg_lbl + ": commits with +1 Block")
			if res.ok:
				var d_half: Dictionary = res.halves[1 if reverse else 0]
				_check(d_half.block == exp_b, tg_lbl + ": exact Block " + str(exp_b))
				_check(c.party.get_hero(1).block == exp_b, tg_lbl + ": party hero block agrees")
			_check(_snapshot(c) == expected, tg_lbl + ": state matches exact +1 Block")


func _test_cuff_rejections() -> void:
	# Torn wearer cannot play composite
	var torn := _fixture("warden_brace", PRICK)
	_bind_cuff(torn, "torn")
	_check(torn.party.is_downed(1) and torn.torn.read_state().tear_counts.warden == 1, "stitched Warden truly torn")
	_reject(torn, 0, 1, "torn Warden cannot play composite")

	# Stale / drifted wardrobe ledger fails closed
	for mode in ["null", "invalid", "stale_wardrobe", "stale_torn", "drift"]:
		var c := _fixture("warden_brace", PRICK)
		_bind_cuff(c)
		var w: Dictionary = c.wardrobe.get_snapshot()
		var t: Dictionary = c.torn.read_state()
		match mode:
			"null":
				_check(not c.service.bind_patch_wardrobe(null, c.torn), "stitched null cuff binding rejects")
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
		_reject(c, 0, 1, mode + " stitched cuff binding fails closed")
		_check(ledgers == [c.wardrobe.get_snapshot(), c.torn.read_state()], "rejected composite preserves ledgers")

	# Block overflow rollback
	var c := _fixture("warden_brace", PRICK)
	_bind_cuff(c)
	_check(c.party.gain_block(1, CombatParty.MAX_INT - 8), "Warden Block almost full")
	_reject(c, 0, 1, "first Brace 9-block overflow rejects composite before Prick damage")

	# Missing second target rolls back first half Block
	c = _fixture("warden_brace", PRICK)
	_bind_cuff(c)
	_reject(c, 0, 0, "missing second Prick target rolls back first Brace 9-block")
	_check(_play(c, 0, 1).ok and c.party.get_hero(1).block == 9 and c.deck.energy == 1,
		"retry after missing target commits once with 9 Block")

	# AC3: Final Block overflow preflight case that would have passed with printed Darning Block (3)
	# but cannot fit the cuff bonus (+2, total 5)
	c = _fixture("seamstress_darning", POP)
	_bind_cuff(c, "sewn_seamstress")
	_check(c.party.gain_block(1, CombatParty.MAX_INT - 4), "Warden Block at MAX_INT - 4 (room for 4)")
	_reject(c, 1, 2, "first Darning 5-block overflow rejects composite before POP damage or heal")

	# Reverse order: POP first, then Darning overflows -> staged POP damage rolled back completely!
	c = _fixture(POP, "seamstress_darning")
	_bind_cuff(c, "sewn_seamstress")
	_check(c.party.gain_block(1, CombatParty.MAX_INT - 4), "Warden Block at MAX_INT - 4 (room for 4)")
	_reject(c, 2, 1, "second Darning 5-block overflow rolls back first POP damage and latch")

	# AC3: Invalid second half rolls back first Darning heal and Cuff Block, retry commits once
	c = _fixture("seamstress_darning", POP)
	_bind_cuff(c, "sewn_seamstress")
	_check(c.party.apply_damage(1, 10), "real wound on Warden before invalid second half")
	_reject(c, 1, 0, "missing second POP target rolls back first Darning heal and Cuff Block")
	var retry_res := _play(c, 1, 2)
	_check(retry_res.ok and retry_res.halves.size() == 2, "retry after missing second target commits once")
	_check(c.party.get_hero(1).hp == 34 and c.party.get_hero(1).block == 5
		and c.enemies.get_enemy(2).hp == 4 and c.deck.energy == 1
		and c.deck.discard_pile == [c.id] and c.deck.hand.is_empty(),
		"retry commits exact 4 heal, 5 block, 8 damage, 1 discard, 2 energy spent")

	# AC3: Reverse order invalid second half rolls back first POP damage, retry commits once
	c = _fixture(POP, "seamstress_darning")
	_bind_cuff(c, "sewn_seamstress")
	_check(c.party.apply_damage(1, 10), "real wound on Warden before reverse invalid second half")
	_reject(c, 2, 0, "missing second Darning target rolls back first POP damage")
	var retry_res_rev := _play(c, 2, 1)
	_check(retry_res_rev.ok and retry_res_rev.halves.size() == 2, "retry reverse after missing target commits once")
	_check(c.party.get_hero(1).hp == 34 and c.party.get_hero(1).block == 5
		and c.enemies.get_enemy(2).hp == 4 and c.deck.energy == 1
		and c.deck.discard_pile == [c.id] and c.deck.hand.is_empty(),
		"retry reverse commits exact 4 heal, 5 block, 8 damage, 1 discard, 2 energy spent")

	# AC2: Downed Seamstress cannot play stitched Darning
	c = _fixture("seamstress_darning", POP)
	_bind_cuff(c, "sewn_seamstress")
	_check(c.party.apply_damage(2, 30) and c.party.is_downed(2), "real downed Seamstress")
	_reject(c, 1, 2, "downed Seamstress cannot play stitched Darning composite")

	# AC2: Torn Seamstress cannot play stitched Darning
	c = _fixture("seamstress_darning", POP)
	_bind_cuff(c, "torn_seamstress")
	_check(c.party.is_downed(2) and c.torn.read_state().tear_counts.seamstress == 1, "stitched Seamstress truly torn")
	_reject(c, 1, 2, "torn Seamstress cannot play stitched Darning composite")

	# AC2: Divergent torn Seamstress cannot play stitched Darning (Lesson 30)
	c = _fixture("seamstress_darning", POP)
	_bind_cuff(c, "torn_divergent")
	_check(c.party.get_hero(2).hp > 0 and c.torn.read_state().heroes[1].hp == 0, "divergent living party with torn ledger")
	_reject(c, 1, 2, "divergent torn Seamstress cannot play stitched Darning composite")




## P6 uses the genuine Rest ledger and the SAME pool-heal notifier across all
## ordered stitched commits. No separate receipt latches are made by this test.
func _bind_button(c: Dictionary, wearer: String = "warden") -> void:
	c.wardrobe = RunPatchWardrobe.new(c.party.get_heroes(), ["borrowed_button"],
		[{"id": "borrowed_button", "slot": "COAT"}], 4)
	c.torn = RunTornMending.new(c.party.get_heroes())
	_check(c.wardrobe.is_valid() and c.torn.is_valid(), "P6 genuine run patch authorities")
	if wearer != "":
		_check(c.wardrobe.sew("borrowed_button", wearer, "COAT",
			"stitched_p6_sew", c.wardrobe.get_snapshot()).ok,
			"P6 genuinely sewn to chosen wearer")
	_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn),
		"stitched resolver has current wardrobe/torn authentication")
	var heals := CombatSeamstressPoolHeals.new()
	_check(heals.bind_patch_wardrobe(c.wardrobe, c.torn),
		"ordinary healing service shares the current patch authorities")
	c.service.bind_borrowed_button(heals)
	c.button_heals = heals
	_check(heals._borrowed_button != null and heals._heal_receipt_number == 0,
		"real combat notifier starts unspent, with no observations")


func _button_state(c: Dictionary) -> Dictionary:
	return c.button_heals._borrowed_button.read_state()


func _test_borrowed_button_halves() -> void:
	var healing_cards := ["seamstress_mend", "seamstress_mend_plus",
		"seamstress_thimble_tea", "seamstress_thimble_tea_plus",
		"seamstress_darning", "seamstress_darning_plus",
		"seamstress_field_mend", "seamstress_field_mend_plus"]
	for card_id in healing_cards:
		var authored: Dictionary = StarterCards.new().get_definition(card_id)
		if authored.is_empty():
			authored = SeamstressPoolCards.new().get_definition(card_id)
		_check(authored.get("id") == card_id and authored.effects.get("heal", 0) > 0,
			"independent real authored heal for " + card_id)
		if authored.is_empty():
			continue
		for reverse in [false, true]:
			var c := _rest_fixture("warden_brace" if reverse else card_id,
				card_id if reverse else "warden_brace", 21106)
			_bind_button(c)
			_check(c.party.apply_damage(1, 12) and c.party.get_hero(1).hp == 28,
				"wounded living different-owner P6 wearer")
			var heal_target: int = 0 if authored.target_kind == "party_all" else 1
			var cost: int = c.rest.preview_play(c.id, c.party.get_heroes()).cost
			var outcome := _play(c, 0 if reverse else heal_target,
				heal_target if reverse else 0)
			var label: String = card_id + " order " + str(reverse)
			_check(outcome.get("ok") == true and outcome.halves.size() == 2,
				label + " genuine two-owner ordered Rest stitch commits")
			var healed: int = int(authored.effects.heal)
			var printed_block: int = int(authored.effects.get("block", 0))
			_check(c.party.get_hero(1).hp == 28 + healed,
				label + " restores actual authored HP to Warden")
			_check(c.party.get_hero(1).block == 7 + printed_block + 3,
				label + " has authored Brace/Darning plus exactly 3 P6 Block")
			_check(c.deck.energy == 3 - cost and c.deck.hand.is_empty()
				and c.deck.discard_pile == [c.id],
				label + " charges composite once and discards exactly once")
			var state := _button_state(c)
			_check(state.awards == 1 and state.block_awarded == 3
				and state.wearer_id == "warden" and state.receipts.size() == 1
				and state.receipt_id.begins_with("stitched_half_%d:" % (1 if reverse else 0)),
				label + " one authenticated half/recipient receipt and spent latch")
			_check(c.button_heals._heal_receipt_number == 1,
				label + " shares exactly one combat receipt sequence")


func _test_borrowed_button_rejections_and_latch() -> void:
	# Full-health overheal and genuine self-heal never pay the COAT.
	var c := _rest_fixture("seamstress_mend", "warden_brace", 21107)
	_bind_button(c)
	_check(_play(c, 1, 0).ok and c.party.get_hero(1).hp == 40,
		"stitched Mend at full HP is a successful 0-restoration commit")
	_check(_button_state(c).awards == 0 and _button_state(c).receipts.is_empty()
		and c.party.get_hero(1).block == 7,
		"overheal cannot generate a P6 receipt or extra Block")
	c = _rest_fixture("seamstress_mend", "warden_brace", 21108)
	_bind_button(c, "seamstress")
	_check(c.party.apply_damage(2, 10), "self-heal wearer genuinely wounded")
	_check(_play(c, 2, 0).ok and c.party.get_hero(2).hp == 25,
		"authored stitched self-heal genuinely restores 5 HP")
	_check(_button_state(c).awards == 0 and c.party.get_hero(2).block == 0,
		"self-healing stitched half never grants wearer P6 Block")
	c = _rest_fixture("seamstress_mend", "warden_brace", 21109)
	_bind_button(c, "")
	_check(c.party.apply_damage(1, 12) and _play(c, 1, 0).ok,
		"owned but unsewn patch witnesses a genuine different-owner heal")
	_check(_button_state(c).awards == 0 and c.party.get_hero(1).block == 7,
		"unsewn patch cannot grant P6 Block")

	# Failed casts must not create any receipt or consume the one-combat latch.
	for mode in ["illegal_target", "second_half", "energy", "downed", "stale"]:
		c = _rest_fixture("seamstress_mend", "warden_brace", 21110)
		_bind_button(c)
		_check(c.party.apply_damage(1, 12), mode + " genuine wounded wearer")
		match mode:
			"energy":
				_check(c.deck.try_spend_energy(2) and c.deck.energy == 1,
					"stitched cost 2 is genuinely unaffordable")
			"downed":
				_check(c.party.apply_damage(1, 40) and c.party.is_downed(1),
					"healing target truly downed")
			"stale":
				_check(c.wardrobe.start_rest("stale_p6", c.wardrobe.get_snapshot()).ok,
					"bound wardrobe advanced authentically")
		_reject(c, 0 if mode == "illegal_target" else 1,
			99 if mode == "second_half" else 0,
			"P6 " + mode + " rejects atomically")
		_check(_button_state(c).awards == 0 and _button_state(c).receipts.is_empty()
			and c.button_heals._heal_receipt_number == 0,
			"P6 " + mode + " leaves notifier and latch wholly untouched")

	# A retained service, deck and Rest composite actually commits in two turns.
	c = _rest_fixture("seamstress_mend", "warden_brace", 21111)
	_bind_button(c)
	_check(c.party.apply_damage(1, 15), "latch wearer wounded for two commits")
	_check(_play(c, 1, 0).ok and c.party.get_hero(1).block == 10,
		"first real stitched Mend/Brace awards 3 Block")
	var first_receipt: String = _button_state(c).receipt_id
	_check(c.deck.end_turn() and c.party.start_player_turn() and c.deck.start_turn()
		and c.deck.hand.has(c.id), "actual next turn redraws the same stitched copy")
	_check(c.party.get_hero(1).block == 0, "turn boundary clears first award Block")
	_check(_play(c, 1, 0).ok and c.party.get_hero(1).hp == 35
		and c.party.get_hero(1).block == 7, "second real stitched heal grants only Brace Block")
	_check(_button_state(c).awards == 1 and _button_state(c).receipts.size() == 2,
		"same combat notifier retains one award across two committed casts")
	var replay: Dictionary = c.button_heals._borrowed_button.notify_committed_heal(
		first_receipt, "seamstress", "warden", 25, 30)
	_check(replay.reason == "duplicate_receipt" and _button_state(c).awards == 1,
		"duplicate original receipt is refused by retained combat helper")

	# A genuinely different party after rebind gets one new battle-bound latch,
	# even when the long-lived ordinary/stitched service itself is retained.
	var previous_button: CombatBorrowedButton = c.button_heals._borrowed_button
	_check(c.button_heals.bind_patch_wardrobe(c.wardrobe, c.torn),
		"next combat reauthenticates unchanged run ledgers")
	var deck := CombatDeck.new([c.id], _rng_for_p6(21112))
	_check(deck.start_turn() and deck.hand == [c.id],
		"new battle genuinely holds the Rest composite")
	c.deck = deck
	c.party = CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
	_check(c.party.is_valid() and c.party.apply_damage(1, 8),
		"next combat has a new real living, wounded party")
	_check(_play(c, 1, 0).ok and _button_state(c).awards == 1
		and c.button_heals._borrowed_button != previous_button
		and c.party.get_hero(1).block == 10,
		"new combat renews the latch once on the same retained service")


func _rng_for_p6(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_borrowed_button_party_and_torn() -> void:
	# Target-free Field Mend heals several recipients, each with its own exact
	# pre/post HP; the later wounded wearer still receives the single P6 award.
	var c := _rest_fixture("seamstress_field_mend", "warden_brace", 21113)
	_bind_button(c, "tinker")
	_check(c.party.apply_damage(1, 9) and c.party.apply_damage(3, 11),
		"party-wide P6 heal has two genuinely damaged living recipients")
	var outcome := _play(c, 0, 0)
	_check(outcome.get("ok") == true and outcome.halves.size() == 2,
		"ordered field heal and Brace commit atomically with no targets")
	_check(c.party.get_hero(1).hp == 35 and c.party.get_hero(3).hp == 19
		and c.party.get_hero(2).hp == 30,
		"party-wide heal restores both actual damaged recipients, no overheal")
	_check(c.party.get_hero(3).block == 3 and c.party.get_hero(1).block == 7,
		"only patched Tinker gains 3 P6; Warden receives authored Brace")
	_check(_button_state(c).awards == 1 and _button_state(c).wearer_id == "tinker"
		and _button_state(c).receipts.size() == 2
		and c.button_heals._heal_receipt_number == 1,
		"two ordered Field Mend recipients share one half receipt sequence")

	# A real battle-end tear suspends a still-sewn COAT. A later CombatParty can
	# start that run-torn hero at positive HP; this must not restore the patch.
	c = _rest_fixture("seamstress_mend", "warden_brace", 21114)
	_bind_button(c)
	var start: Array = c.torn.read_state().heroes
	var finish: Array = start.duplicate(true)
	finish[0].hp = 0
	_check(c.torn.observe_battle_end("stitched_p6_tear", start, finish).ok,
		"wearer's run ledger records genuine battle-end tearing")
	var state: Dictionary = c.wardrobe.get_snapshot()
	_check(c.wardrobe.refresh_run_context(c.torn.read_state().heroes,
		state.owned, state.scraps, state.gold, state.cards, state),
		"wardrobe refreshes real torn run heroes without unsewing the button")
	var roster: Array = []
	for hero in c.torn.read_state().heroes:
		roster.append({"id": hero.id, "max_hp": hero.max_hp})
	c.party = CombatParty.new(roster)
	_check(c.party.is_valid() and c.party.get_hero(1).hp == 37
		and c.torn.read_state().heroes[0].hp == 0,
		"fresh battle party lives while original wearer remains run-torn")
	_check(c.service.bind_patch_wardrobe(c.wardrobe, c.torn)
		and c.button_heals.bind_patch_wardrobe(c.wardrobe, c.torn),
		"both real combat authorities rebind to the exact torn ledger")
	_check(c.party.apply_damage(1, 8), "run-torn wearer is wounded in party")
	_check(_play(c, 1, 0).ok and c.party.get_hero(1).hp == 34,
		"genuine different-owner stitched Mend heals torn-ledger wearer by 5")
	_check(c.party.get_hero(1).block == 7 and _button_state(c).awards == 0,
		"run-torn COAT remains suspended even when battle party is alive")


## Independent single-card oracle: the pool resolver's own public play on a
## separate one-card deck and fresh authored rosters, with a fresh latch.
func _pool_oracle(card_id: String, target: int, wardrobe: Variant = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var deck := CombatDeck.new([card_id], rng)
	_check(deck.start_turn() and deck.hand == [card_id], card_id + ": oracle holds the printing")
	var party := CombatParty.new(_definitions("res://data/heroes/starter_party.json"))
	var enemies := CombatEnemies.new(_definitions("res://data/enemies/starter_enemies.json"))
	var pool := CombatTinkerPoolAttacks.new()
	if wardrobe != null:
		_check(pool.bind_patch_wardrobe(wardrobe, RunTornMending.new(party.get_heroes())),
			card_id + ": oracle binds the same wardrobe")
	var result: Dictionary = pool.play_attack(deck, party, enemies, card_id, target)
	return {"result": result, "enemies": enemies.get_enemies(), "party": party.get_heroes()}


## All six single-target Tinker pool printings in both half orders, beside the
## authored Brace: the exact pool hit, one capped charge, one discard, the
## published first-attack latch and a fully unchanged RNG/draw pile.
func _test_tinker_pool_attack_halves() -> void:
	var pool := TinkerPoolCards.new()
	for id in CombatTinkerPoolAttacks.STITCHED_IDS:
		var authored: Dictionary = pool.get_definition(id)
		_check(not authored.is_empty() and authored == RunRestStitchCards.resolve_card_definition(id),
			id + ": authentic authored Tinker pool half")
		var printed: int = int(authored.get("cost", -1))
		for reverse in [false, true]:
			var label: String = id + (" after Brace" if reverse else " before Brace")
			var c := _rest_fixture(SUPPORT_HALF if reverse else id, id if reverse else SUPPORT_HALF, 7301)
			_check(_position_of(c.party, "tinker") == 3 and _position_of(c.party, "warden") == 1,
				label + ": authored party positions")
			c.deck.draw_pile.assign([PRICK, "warden_strike"])
			c.deck.discard_pile.assign([BOMB])
			var cost: int = int(c.rest.get_snapshot()["descriptors"][c.id]["cost"])
			_check(cost == mini(3, maxi(printed, 1) + 1), label + ": Rest-capped composite cost")
			var oracle := _pool_oracle(id, 2)
			_check(oracle.result.get("ok", false) and oracle.result.hits.size() == 1
				and oracle.result.hits[0].position == 2, label + ": oracle single hit")
			var before := _snapshot(c)
			var expected := before.duplicate(true)
			expected[1] = []
			expected[2] = [BOMB, c.id]
			expected[3] = before[3] - cost
			expected[6][0]["block"] += 7
			expected[7] = oracle.enemies
			expected[8] = true
			var result := _play(c, 0 if reverse else 2, 2 if reverse else 0)
			var brace := {"ok": true, "effect": "self_block", "amount": 7}
			var halves := [oracle.result, brace]
			if reverse:
				halves.reverse()
			_check(result == {"ok": true, "halves": halves}, label + ": exact authored pool hit and Brace")
			_check(_snapshot(c) == expected, label + ": exact HP, Block, piles, energy, RNG and latch")
			_check(c.deck.discard_pile.count(c.id) == 1 and not c.deck.hand.has(c.id),
				label + ": composite discarded once, no loose half in any pile")
			_check(c.attacks._tinker.bonus_for_attack(POP) == 0, label + ": real Tinker +3 already spent")
			# The composite never sneaks either printed half into the real piles.
			for pile in [c.deck.draw_pile, c.deck.hand, c.deck.discard_pile]:
				_check(not pile.has(id) and not pile.has(SUPPORT_HALF), label + ": no half leaks into piles")
		# The Rivet hit lands before its own Exposed, so its printed damage is unboosted.
		if id.begins_with("tinker_rivet_shot"):
			var hit: Dictionary = _pool_oracle(id, 1).result.hits[0]
			var printed_damage: int = 6 if id.ends_with("_plus") else 4
			_check(hit == _expected_hit(1, printed_damage + 3, 0, {"exposed": 1}),
				id + ": +3 first attack then Exposed after the hit")


## A Rest stitch always joins two owners, so the shared Tinker latches are
## proven by the published state a later starter attack reads; Rivet's
## Exposed lands after its own hit and boosts only the later half.
func _test_tinker_pool_attack_latches() -> void:
	for reverse in [false, true]:
		var c := _rest_fixture("tinker_rivet_shot" if reverse else PRICK, PRICK if reverse else "tinker_rivet_shot", 7411)
		_check(int(c.rest.get_snapshot()["descriptors"][c.id]["cost"]) == 2, "Prick/Rivet capped two")
		var result := _play(c, 1, 1)
		var prick_hit := {"ok": true, "hits": [_expected_hit(1, 4 if reverse else 3, 0, {"bleed": 3})]}
		var rivet_hit := {"ok": true, "hits": [_expected_hit(1, 7, 0, {"exposed": 1})]}
		var expected: Array = [rivet_hit, prick_hit] if reverse else [prick_hit, rivet_hit]
		var label := "Rivet then Prick" if reverse else "Prick then Rivet"
		_check(result == {"ok": true, "halves": expected},
			label + ": Rivet unboosted by its own Exposed; a later half reads it: floor(3 * 1.5)")
		_check(c.enemies.get_enemy(1).hp == 12 - 7 - (4 if reverse else 3)
			and c.enemies.get_enemy(1).statuses == {"bleed": 3, "exposed": 1}
			and c.attacks._tinker._consumed and c.deck.energy == 1 and c.deck.discard_pile == [c.id],
			label + ": exact HP, statuses, published latch and one charge")
		c.deck.hand.append(POP)
		_check(c.attacks.play_attack(c.deck, c.party, c.enemies, POP, 2)
			== {"ok": true, "hits": [_expected_hit(2, 5)]}, label + ": later starter Pop gets no second +3")

	# Rivet+ on a Blocked slot: Block absorbs the unboosted hit, then Exposed.
	var blocked := _rest_fixture(SUPPORT_HALF, "tinker_rivet_shot_plus", 7523)
	_check(blocked.enemies.gain_block(1, 10), "Rivet+ Block precondition")
	_check(_play(blocked, 0, 1) == {"ok": true, "halves": [{"ok": true, "effect": "self_block", "amount": 7},
		{"ok": true, "hits": [_expected_hit(1, 9, 9, {"exposed": 1})]}]}
		and blocked.enemies.get_enemy(1).block == 1 and blocked.enemies.get_enemy(1).hp == 12,
		"Rivet+ 6+3 fully Blocked, Exposed still applied after the hit")

	# Patch owner semantics through the same staged wearer latches.
	var c := _rest_fixture(SUPPORT_HALF, "tinker_rivet_shot", 7639)
	var wardrobe := RunPatchWardrobe.new(c.party.get_heroes(), ["button_eye", "pincushion_arm"],
		[{"id": "button_eye", "slot": "HEAD"}, {"id": "pincushion_arm", "slot": "ARM"}], 10)
	_check(wardrobe.sew("button_eye", "tinker", "HEAD", "pool-stitch-eye", wardrobe.get_snapshot()).ok
		and wardrobe.sew("pincushion_arm", "tinker", "ARM", "pool-stitch-arm", wardrobe.get_snapshot()).ok,
		"Tinker wears Button Eye and Pincushion")
	_check(c.attacks.bind_patch_wardrobe(wardrobe, RunTornMending.new(c.party.get_heroes())), "Tinker patch binding")
	var ledger := wardrobe.get_snapshot()
	_reject(c, 0, 0, "patched pool half without a target")
	var oracle := _pool_oracle("tinker_rivet_shot", 2, wardrobe)
	var result := _play(c, 0, 2)
	_check(oracle.result.get("ok", false) and result.ok and result.halves[1] == oracle.result,
		"Tinker-worn patches price the stitched pool half exactly as the pool resolver")
	_check(result.ok and result.halves[1].hits[0].damage == 4 + 3 + 1
		and result.halves[1].hits[0].statuses.get("exposed", 0) >= 2,
		"wearer +1, first-attack +3, Rivet Exposed plus Button Eye")
	_check(c.attacks._patches.latch_snapshot().get("tinker", false) and wardrobe.get_snapshot() == ledger,
		"Tinker Button Eye latch published, run ledger unchanged")

	# The pool half spent the one Button Eye and +3: a later starter Pop keeps only the ARM.
	c.deck.hand.append(POP)
	_check(c.attacks.play_attack(c.deck, c.party, c.enemies, POP, 1)
		== {"ok": true, "hits": [_expected_hit(1, 5 + 1)]}, "later Pop: no second Button Eye or +3")

	# Patches on other heroes never price Tinker's pool half.
	c = _rest_fixture(SUPPORT_HALF, "tinker_rivet_shot", 7639)
	var others := RunPatchWardrobe.new(c.party.get_heroes(), ["button_eye", "pincushion_arm"],
		[{"id": "button_eye", "slot": "HEAD"}, {"id": "pincushion_arm", "slot": "ARM"}], 10)
	_check(others.sew("button_eye", "seamstress", "HEAD", "pool-stitch-eye-2", others.get_snapshot()).ok
		and others.sew("pincushion_arm", "warden", "ARM", "pool-stitch-arm-2", others.get_snapshot()).ok,
		"patches worn by other heroes")
	_check(c.attacks.bind_patch_wardrobe(others, RunTornMending.new(c.party.get_heroes())), "other wearer binding")
	result = _play(c, 0, 2)
	_check(result == {"ok": true, "halves": [{"ok": true, "effect": "self_block", "amount": 7},
		{"ok": true, "hits": [_expected_hit(2, 7, 0, {"exposed": 1})]}]}
		and not c.attacks._patches.latch_snapshot().get("seamstress", false),
		"other wearers' patches neither boost nor spend on Tinker's pool half")


## Illegal owner/target, counterfeit records and late failures roll back
## everything; a legal retry then succeeds and same-seed replays agree.
func _test_tinker_pool_attack_failures() -> void:
	var c := _rest_fixture(SUPPORT_HALF, "tinker_long_barrel", 7741)
	_reject(c, 0, 0, "pool half needs a target")
	_reject(c, 0, 3, "pool half unoccupied slot")
	_reject(c, 0, 4, "pool half off-board slot")
	_reject(c, 0, -1, "pool half negative slot")
	_reject(c, 2, 2, "Brace before pool half forbids a target")
	c.enemies.apply_damage(2, 12)
	_reject(c, 0, 2, "pool half slain target")
	_check(_play(c, 0, 1).ok and c.enemies.get_enemy(1).hp == 0, "legal retry after rejected slain target")

	c = _rest_fixture(SUPPORT_HALF, "tinker_long_barrel", 7741)
	_check(c.party.apply_damage(3, c.party.get_hero(3).hp), "downed Tinker precondition")
	_reject(c, 0, 1, "downed Tinker owner")
	for id in ["tinker_long_barrel", "tinker_long_barrel_plus", "tinker_bobbin_cannon", "tinker_bobbin_cannon_plus"]:
		c = _rest_fixture(SUPPORT_HALF, id, 7741)
		var heroes: Array = c.party.get_heroes()
		c.party = CombatParty.new([heroes[0], heroes[2], heroes[1]])
		_check(_position_of(c.party, "tinker") == 2 and _position_of(c.party, "warden") == 1,
			id + ": Tinker displaced to slot two, Brace owner still legal")
		_reject(c, 0, 1, id + ": Tinker outside authored FROM [3]")
	c = _rest_fixture(SUPPORT_HALF, "tinker_rivet_shot", 7741)
	var defs: Array = c.party.get_heroes()
	c.party = CombatParty.new([defs[0], defs[2], defs[1]])
	_check(_position_of(c.party, "tinker") == 2 and _play(c, 0, 1).ok, "Rivet from slot two stays legal")

	c = _rest_fixture(SUPPORT_HALF, "tinker_bobbin_cannon", 7741)
	c.deck.try_spend_energy(1)
	_reject(c, 0, 1, "insufficient energy for the capped composite")
	c = _rest_fixture(SUPPORT_HALF, "tinker_bobbin_cannon", 7741)
	c.deck.discard_played(c.id)
	_reject(c, 0, 1, "unheld pool composite")
	c = _rest_fixture(SUPPORT_HALF, "tinker_rivet_shot", 7741)
	var forged: Dictionary = c.rest.get_snapshot()
	forged.descriptors[c.id].second_half.effects.exposed = 9
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors, 0, 2)
	_reject(c, 0, 1, "counterfeit pool half descriptor")
	c = _rest_fixture(SUPPORT_HALF, "tinker_rivet_shot", 7741)
	forged = c.rest.get_snapshot()
	forged.descriptors[c.id].second_half.id = "tinker_spring_trap"
	c.rest = RunRestStitchCards.new(forged.deck, forged.descriptors, 0, 2)
	_reject(c, 0, 1, "relabelled pool half stays closed")
	c = _rest_fixture(SUPPORT_HALF, "tinker_rivet_shot", 7741)
	c.rest._descriptors[c.id]["second_half"]["effects"]["damage"] = 40
	_reject(c, 0, 1, "in-memory tampered pool half")

	# A late second-half failure after a staged pool hit, Exposed and latch.
	for pair in [["tinker_rivet_shot_plus", SUPPORT_HALF, 1, 3], ["tinker_long_barrel", "warden_strike", 2, 3],
			[PRICK, "tinker_bobbin_cannon", 1, 0]]:
		c = _rest_fixture(pair[0], pair[1], 7853)
		var label: String = str(pair[0]) + "/" + str(pair[1])
		var before := _snapshot(c)
		_reject(c, pair[2], pair[3], label + ": late failure after staged pool damage")
		_check(_snapshot(c) == before and not c.attacks._tinker._consumed
			and c.enemies.get_enemy(1).get("statuses", {}).is_empty(), label + ": latch, HP and Exposed rolled back")
		var retry := _play(c, pair[2], 0 if pair[1] == SUPPORT_HALF else 1)
		_check(retry.ok and c.attacks._tinker._consumed and c.deck.discard_pile == [c.id], label + ": legal retry commits once")

	# Same-seed replay agrees exactly, including the untouched RNG.
	var runs: Array = []
	for attempt in range(2):
		c = _rest_fixture("tinker_rivet_shot", PRICK, 7967)
		c.deck.draw_pile.assign([PRICK, BOMB, "warden_strike"])
		var outcome := _play(c, 1, 1)
		runs.append([outcome, _snapshot(c)])
	_check(runs[0][0].ok and runs[0] == runs[1], "same-seed pool stitch replay is identical")


## Independent ordinary-pool public transaction on a distinct held printing and
## detached authentic rosters; no stitched helper is used to make the oracle.
func _scatter_ordinary_oracle(c: Dictionary, card_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.state = c.deck._rng.state
	var deck := CombatDeck.new([card_id], rng)
	_check(deck.start_turn() and deck.hand == [card_id],
		"ordinary Scatter oracle starts with its real authored card held")
	var heroes := CombatParty.new(c.party.get_heroes())
	var foes := CombatEnemies.new(c.enemies.get_enemies())
	foes._enemies = c.enemies.get_enemies()
	var resolver := CombatTinkerPoolAttacks.new()
	if c.get("wardrobe") != null:
		_check(resolver.bind_patch_wardrobe(c.wardrobe, c.torn),
			"independent ordinary area resolver binds the same patch authorities")
	var paid := resolver.play_attack(deck, heroes, foes, card_id, 0)
	return {"result": paid, "enemies": foes.get_enemies(), "party": heroes.get_heroes(),
		"rng": deck._rng.state}


## The selected target remains zero; each living ORIGINAL slot receives exactly
## the ordinary resolver's Weak/Exposed/Block-aware hit in either half order.
func _test_scatter_area_halves() -> void:
	for card_id in CombatTinkerPoolAttacks.STITCHED_AREA_IDS:
		var authored := TinkerPoolCards.new().get_definition(card_id)
		_check(authored == RunRestStitchCards.resolve_card_definition(card_id)
			and authored.target_kind == "enemy_all" and authored.effects.damage ==
				(4 if card_id.ends_with("_plus") else 3),
			"Scatter base/+ is authentic and has the exact 3/4 area printing")
		for reverse in [false, true]:
			var c := _rest_fixture(SUPPORT_HALF if reverse else card_id,
				card_id if reverse else SUPPORT_HALF, 8222)
			var label: String = card_id + " reverse " + str(reverse)
			_check(c.party.get_hero(3).id == "tinker" and c.deck.hand == [c.id]
				and c.enemies.get_enemies().size() >= 2,
				label + ": living Tinker, held Rest composite and multi-foe preconditions")
			var weakened: Array[Dictionary] = c.party.get_heroes()
			weakened[2]["statuses"] = {"weak": 1}
			c.party._heroes.assign(weakened)
			_check(c.enemies.gain_block(1, 3) and c.enemies.apply_statuses({2: {"exposed": 1}})
				and c.party.get_hero(3).get("statuses", {}).get("weak", 0) == 1,
				label + ": real Block, Exposed and Tinker Weak before area strike")
			var oracle := _scatter_ordinary_oracle(c, card_id)
			var original_living: Array[int] = []
			for enemy in c.enemies.get_enemies():
				if enemy.hp > 0:
					original_living.append(enemy.position)
			var hits: Array = oracle.result.get("hits", [])
			var hit_slots: Array[int] = []
			for hit in hits:
				hit_slots.append(hit.position)
			_check(oracle.result.get("ok", false) and hit_slots == original_living
				and hits.size() >= 2, label + ": independent ordinary oracle hits every living original slot")
			var before := _snapshot(c)
			var receipt := _play(c, 0, 0)
			var area_result: Dictionary = receipt.get("halves", [{}])[1 if reverse else 0]
			_check(receipt.get("ok", false) and receipt.halves.size() == 2
				and area_result == oracle.result
				and receipt.halves[0 if reverse else 1] ==
					{"ok": true, "effect": "self_block", "amount": 7},
				label + ": staged Scatter is identical to ordinary area and other-owner Brace")
			_check(c.enemies.get_enemies() == oracle.enemies
				and c.party.get_hero(1).block == int(before[6][0].block) + 7
				and c.deck.energy == before[3] - 2 and c.deck.discard_pile == [c.id]
				and c.deck.hand.is_empty() and c.deck.draw_pile == before[0]
				and c.deck._rng.state == before[5] and c.attacks._tinker._consumed,
				label + ": all area outcomes, single composite cost/discard, no RNG or draw")
			_check(c.rest.get_snapshot() == before[10],
				label + ": run-owned Rest ledger remains unchanged")
	# A slain original slot is never rerouted or given a phantom hit.
	var slain := _rest_fixture("tinker_scatter_bolts_plus", SUPPORT_HALF, 8223)
	_check(slain.enemies.apply_damage(2, 999) and slain.enemies.is_slain(2)
		and not slain.enemies.is_victorious(), "one genuinely slain foe before Scatter")
	var death_oracle := _scatter_ordinary_oracle(slain, "tinker_scatter_bolts_plus")
	var death_receipt := _play(slain, 0, 0)
	_check(death_receipt.get("ok", false)
		and death_receipt.halves[0] == death_oracle.result
		and death_receipt.halves[0].hits.size() == 1
		and death_receipt.halves[0].hits[0].position == 1
		and slain.enemies.get_enemies() == death_oracle.enemies,
		"slain middle seat is skipped, original positions and death preserved")
	# A live enemy killed by the first area hit does not suppress the later
	# original slot or alter the staged result versus the ordinary oracle.
	var lethal := _rest_fixture("tinker_scatter_bolts", SUPPORT_HALF, 8225)
	lethal.enemies._enemies[0]["hp"] = 1
	_check(lethal.enemies.get_enemy(1).hp == 1
		and lethal.enemies.get_enemy(2).hp > 6,
		"real front foe is lethal while the next original slot survives")
	var lethal_oracle := _scatter_ordinary_oracle(lethal, "tinker_scatter_bolts")
	var lethal_receipt := _play(lethal, 0, 0)
	_check(lethal_receipt.get("ok", false)
		and lethal_receipt.halves[0] == lethal_oracle.result
		and lethal_receipt.halves[0].hits.size() == 2
		and lethal_receipt.halves[0].hits[0].position == 1
		and lethal_receipt.halves[0].hits[1].position == 2
		and lethal.enemies.get_enemy(1).hp == 0
		and lethal.enemies.get_enemy(2).hp > 0
		and lethal.enemies.get_enemies() == lethal_oracle.enemies,
		"area kills front foe and still strikes original second slot without rerouting")
	# Wearer-only damage and once-per-combat Button Eye share the same latch.
	var patched := _rest_fixture("tinker_scatter_bolts", SUPPORT_HALF, 8224)
	var slots := [{"id": "button_eye", "slot": "HEAD"},
		{"id": "pincushion_arm", "slot": "ARM"}]
	patched.wardrobe = RunPatchWardrobe.new(patched.party.get_heroes(),
		["button_eye", "pincushion_arm"], slots, 10)
	patched.torn = RunTornMending.new(patched.party.get_heroes())
	_check(patched.wardrobe.sew("button_eye", "tinker", "HEAD", "scatter-eye",
		patched.wardrobe.get_snapshot()).ok
		and patched.wardrobe.sew("pincushion_arm", "tinker", "ARM", "scatter-arm",
		patched.wardrobe.get_snapshot()).ok
		and patched.attacks.bind_patch_wardrobe(patched.wardrobe, patched.torn),
		"real Tinker-worn attack patches bound before staged Scatter")
	var patched_oracle := _scatter_ordinary_oracle(patched, "tinker_scatter_bolts")
	var patched_receipt := _play(patched, 0, 0)
	_check(patched_receipt.get("ok", false)
		and patched_receipt.halves[0] == patched_oracle.result
		and patched.enemies.get_enemies() == patched_oracle.enemies
		and patched.attacks._patches.latch_snapshot().get("tinker", false),
		"staged area shares ordinary wearer bonus, first-hit Exposed and spent patch latch")


func _test_scatter_area_refusals() -> void:
	var c := _rest_fixture("tinker_scatter_bolts", SUPPORT_HALF, 8331)
	_reject(c, 1, 0, "area half rejects nonzero enemy selection")
	_reject(c, -1, 0, "area half rejects negative selection")
	_reject(c, 0, 1, "later Brace refuses any target after area")
	c = _rest_fixture(SUPPORT_HALF, "tinker_scatter_bolts_plus", 8331)
	_reject(c, 0, 2, "reversed area half rejects nonzero target")
	_check(c.party.apply_damage(3, c.party.get_hero(3).hp)
		and c.party.is_downed(3), "real downed Tinker for area rejection")
	_reject(c, 0, 0, "downed owner forbids stitched area")
	c = _rest_fixture(SUPPORT_HALF, "tinker_scatter_bolts", 8331)
	var original: Array[Dictionary] = c.party.get_heroes()
	c.party = CombatParty.new([original[0], original[2], original[1]])
	_check(c.party.get_hero(2).id == "tinker", "Tinker moved to illegal middle FROM slot")
	_reject(c, 0, 0, "misplaced owner forbids stitched Scatter")
	c = _rest_fixture("tinker_scatter_bolts_plus", SUPPORT_HALF, 8331)
	_check(c.deck.try_spend_energy(2) and c.deck.energy == 1,
		"genuine insufficient energy for two-cost Scatter composite")
	_reject(c, 0, 0, "unaffordable stitched area")
	c = _rest_fixture("tinker_scatter_bolts", SUPPORT_HALF, 8331)
	c.deck.discard_played(c.id)
	_reject(c, 0, 0, "unheld area composite")
	c = _rest_fixture("tinker_scatter_bolts", SUPPORT_HALF, 8331)
	c.rest._descriptors[c.id]["first_half"]["effects"]["damage"] = 99
	_reject(c, 0, 0, "forged in-memory area printing")
	c = _rest_fixture("tinker_scatter_bolts", SUPPORT_HALF, 8331)
	var snapshot: Dictionary = c.rest.get_snapshot()
	snapshot.descriptors[c.id].first_half.effects.damage = 99
	c.rest = RunRestStitchCards.new(snapshot.deck, snapshot.descriptors, 0, 2)
	_check(not c.rest.is_valid(), "forged canonical area descriptor rejected by ledger")
	_reject(c, 0, 0, "forged area ledger")
	c = _rest_fixture("tinker_scatter_bolts", "warden_strike", 8331)
	_reject(c, 0, 0, "later single-target half failure rolls back all staged area hits and latches")
	c = _rest_fixture("tinker_scatter_bolts", SUPPORT_HALF, 8331)
	c.enemies._enemies[0]["position"] = 3
	_reject(c, 0, 0, "invalid original enemy roster refuses whole area")
	var replay: Array = []
	for attempt in range(2):
		c = _rest_fixture("tinker_scatter_bolts_plus", SUPPORT_HALF, 8337)
		replay.append([_play(c, 0, 0), _snapshot(c)])
	_check(replay[0][0].get("ok", false) and replay[0] == replay[1],
		"same seeded area replay keeps exact resources, latches and RNG")
