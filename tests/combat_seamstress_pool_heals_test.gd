extends SceneTree
## Deterministic D2-1 pool-heal contract, using real catalog, deck and party.

const CASES := {
	"seamstress_darning": {"cost": 1, "from": [1, 2, 3], "kind": "ally_single",
		"effects": {"heal": 4, "block": 3}},
	"seamstress_darning_plus": {"cost": 1, "from": [1, 2, 3], "kind": "ally_single",
		"effects": {"heal": 6, "block": 4}},
	"seamstress_thimble_tea": {"cost": 0, "from": [2, 3], "kind": "ally_single",
		"effects": {"heal": 3}},
	"seamstress_thimble_tea_plus": {"cost": 0, "from": [2, 3], "kind": "ally_single",
		"effects": {"heal": 4}},
	"seamstress_field_mend": {"cost": 2, "from": [2, 3], "kind": "party_all",
		"effects": {"heal": 4}},
	"seamstress_field_mend_plus": {"cost": 2, "from": [2, 3], "kind": "party_all",
		"effects": {"heal": 6}},
}

var checks: int = 0
var failures: Array[String] = []
var catalog := SeamstressPoolCards.new()
var resolver := CombatSeamstressPoolHeals.new()


func _initialize() -> void:
	_test_authored_definitions_and_all_six()
	_test_full_hp_and_two_copies()
	_test_owner_moves_and_downed_field_mend()
	_test_atomic_rejections()
	_test_patch_binding_cases()
	_test_m05_block_patch_cases()
	_test_borrowed_button_all_six()
	_test_borrowed_button_latch_and_replay()
	_test_borrowed_button_starter_mixed_orders()
	_test_borrowed_button_starter_negatives()
	_test_borrowed_button_negative_cases()
	_test_replay()
	for failure: String in failures:
		printerr(failure)
	print("combat_seamstress_pool_heals_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _party(order: Array[String] = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	_check(raw is Array, "real starter_party.json is an array")
	if not raw is Array:
		return CombatParty.new([])
	var by_id: Dictionary = {}
	for record in raw:
		if record is Dictionary:
			by_id[record.get("id", "")] = record
	var definitions: Array = []
	for hero_id: String in order:
		_check(by_id.has(hero_id), "authored party contains " + hero_id)
		if not by_id.has(hero_id):
			return CombatParty.new([])
		var hero: Dictionary = by_id[hero_id].duplicate(true)
		var maximum: Variant = hero.get("max_hp")
		_check((maximum is float or maximum is int) and float(maximum) == floor(float(maximum)),
			"authored HP is integral for " + hero_id)
		if not (maximum is float or maximum is int):
			return CombatParty.new([])
		hero["max_hp"] = int(maximum)
		definitions.append(hero)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"real three-hero CombatParty is valid")
	for position in range(1, 4):
		var hero: Dictionary = party.get_hero(position)
		_check(hero.get("id") == order[position - 1] and hero.get("position") == position
			and hero.get("hp") == hero.get("max_hp"), "real hero identity, slot and HP")
	return party


func _deck(cards: Array[String], seed_value: int = 42, start: bool = true) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	if start:
		_check(deck.start_turn() and deck.turn_active
			and deck.energy == CombatState.TURN_ENERGY, "real five-draw, three-energy turn")
		_check(deck.hand.size() == mini(CombatDeck.TURN_DRAW, cards.size()),
			"deck drew five or all remaining cards")
	return deck


func _snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	return {
		"heroes": party.get_heroes(),
		"draw": deck.draw_pile.duplicate(),
		"hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"turn_active": deck.turn_active,
		"energy": deck.energy,
		"state_turn": deck.combat_state.player_turn_active,
		"state_energy": deck.combat_state.energy,
		"rng": deck._rng.state,
	}


func _expected(before: Dictionary, card_id: String, target: int, bonus: int = 0, block_bonus: int = 0) -> Dictionary:
	# Oracle uses named design expectations, not the implementation's effects.
	var after: Dictionary = before.duplicate(true)
	var spec: Dictionary = CASES[card_id]
	var effects: Dictionary = spec["effects"]
	after["energy"] -= spec["cost"]
	after["state_energy"] -= spec["cost"]
	if spec["kind"] == "party_all":
		for hero: Dictionary in after["heroes"]:
			if hero["hp"] > 0:
				hero["hp"] = mini(hero["max_hp"], hero["hp"] + effects["heal"] + bonus)
	else:
		var hero: Dictionary = after["heroes"][target - 1]
		hero["hp"] = mini(hero["max_hp"], hero["hp"] + effects["heal"] + bonus)
		hero["block"] += effects.get("block", 0) + block_bonus
	after["hand"].remove_at(after["hand"].find(card_id))
	after["discard"].append(card_id)
	return after


func _played(deck: CombatDeck, party: CombatParty, id: String, target: int,
		label: String, bonus: int = 0, service = null, block_bonus: int = 0) -> void:
	var before: Dictionary = _snapshot(deck, party)
	_check(deck.turn_active and party.is_valid() and deck.hand.has(id),
		label + ": authentic precondition (active hand, valid party)")
	_check(deck.energy >= CASES[id]["cost"], label + ": affordable before action")
	var expected: Dictionary = _expected(before, id, target, bonus, block_bonus)
	var player = service if service != null else resolver
	_check(player.play_card(deck, party, id, target), label + ": succeeds")
	_check(_snapshot(deck, party) == expected,
		label + ": exact HP, Block, caps, all piles, three-energy budget and RNG")
	_check(deck.hand.count(id) == before["hand"].count(id) - 1
		and deck.discard_pile.count(id) == before["discard"].count(id) + 1,
		label + ": exactly one matching copy is discarded")


func _rejected(deck: CombatDeck, party: CombatParty, id: String, target: int,
		label: String, service = null) -> void:
	var before: Dictionary = _snapshot(deck, party)
	var player = service if service != null else resolver
	_check(not player.play_card(deck, party, id, target), label + ": rejects")
	_check(_snapshot(deck, party) == before,
		label + ": atomic rejection preserves HP, Block, piles, energy and RNG")


func _wound_all(party: CombatParty) -> void:
	_check(party.apply_damage(1, 9) and party.apply_damage(2, 5)
		and party.apply_damage(3, 8), "all three living heroes genuinely wounded")
	_check(party.gain_block(1, 2) and party.gain_block(3, 3),
		"preexisting Block belongs to two different recipients")
	_check(party.get_hero(1)["hp"] == 31 and party.get_hero(3)["block"] == 3,
		"wound/Block fixture verified before resolution")


func _test_authored_definitions_and_all_six() -> void:
	for id: String in CASES:
		var spec: Dictionary = CASES[id]
		var definition: Dictionary = catalog.get_definition(id)
		_check(not definition.is_empty() and catalog.has_card(id),
			id + ": authentic catalog entry exists")
		_check(definition.get("id") == id and definition.get("owner") == "seamstress",
			id + ": authoritative ID and owner")
		_check(definition.get("cost") == spec["cost"]
			and definition.get("from_positions") == spec["from"]
			and definition.get("target_kind") == spec["kind"]
			and definition.get("to_positions") == []
			and definition.get("effects") == spec["effects"],
			id + ": all printed cost, slots, target kind and effect amounts")
		var party := _party()
		_wound_all(party)
		# Seven real cards leave two in the draw pile; four copies guarantee
		# at least two copies in the initial five-card hand for any seed.
		var deck := _deck([id, id, id, id, "filler-a", "filler-b", "filler-c"])
		_check(deck.hand.count(id) >= 2 and deck.draw_pile.size() == 2,
			id + ": real shuffled hand has duplicates and remaining draw order")
		var target: int = 0 if spec["kind"] == "party_all" else (3 if id in [
			"seamstress_thimble_tea", "seamstress_thimble_tea_plus"] else 1)
		_played(deck, party, id, target, id)


func _test_full_hp_and_two_copies() -> void:
	var party := _party()
	_check(party.gain_block(2, 7), "full-HP target has prior Block")
	var id := "seamstress_darning_plus"
	var deck := _deck([id, id, "filler-a", "filler-b", "filler-c"])
	_check(party.get_hero(2)["hp"] == 30 and deck.hand.count(id) == 2,
		"full-HP Seamstress and two copies really in hand")
	_played(deck, party, id, 2, "Darning+ on full-HP self")
	_check(party.get_hero(2)["hp"] == 30 and party.get_hero(2)["block"] == 11,
		"full HP still pays once and gains exactly four Block")
	_check(deck.hand.count(id) == 1 and deck.energy == 2,
		"other Darning+ copy remains playable")
	_played(deck, party, id, 2, "second Darning+ copy")
	_check(party.get_hero(2)["block"] == 15 and deck.energy == 1,
		"both paid plays stack Block without overhealing")


func _test_owner_moves_and_downed_field_mend() -> void:
	var party := _party(["seamstress", "warden", "tinker"])
	_check(party.apply_damage(3, 10) and party.get_hero(1)["id"] == "seamstress",
		"Seamstress legally occupies front slot")
	var deck := _deck(["seamstress_darning"])
	_played(deck, party, "seamstress_darning", 3, "Darning legal from front")

	party = _party(["warden", "tinker", "seamstress"])
	_check(party.apply_damage(1, 8) and party.get_hero(3)["id"] == "seamstress",
		"Seamstress moved to back slot with wounded Warden")
	deck = _deck(["seamstress_thimble_tea_plus", "seamstress_field_mend"])
	_played(deck, party, "seamstress_thimble_tea_plus", 1,
		"Tea+ follows owner identity in back slot")
	_played(deck, party, "seamstress_field_mend", 0,
		"Field Mend follows owner identity in back slot")

	party = _party()
	_check(party.apply_damage(1, 40) and party.is_downed(1),
		"Field Mend target is actually downed at zero HP")
	_check(party.apply_damage(2, 10) and party.apply_damage(3, 9)
		and party.gain_block(3, 4), "other two living Field Mend targets wounded")
	deck = _deck(["seamstress_field_mend_plus"])
	_played(deck, party, "seamstress_field_mend_plus", 0,
		"Field Mend+ skips downed slot and heals other two")
	_check(party.is_downed(1) and party.get_hero(1)["hp"] == 0
		and party.get_hero(3)["block"] == 4,
		"Field Mend+ neither revives a downed hero nor changes existing Block")


func _test_atomic_rejections() -> void:
	var party := _party()
	var deck := _deck(["seamstress_darning", "seamstress_thimble_tea",
		"seamstress_field_mend", "seamstress_running_stitch", "other"])
	_check(deck.hand.has("seamstress_darning") and deck.hand.has("seamstress_field_mend"),
		"negative case has authentic three healing cards")
	_rejected(deck, party, "seamstress_darning", 0, "Darning missing selection")
	_rejected(deck, party, "seamstress_thimble_tea", 0, "Tea missing selection")
	for target in [-1, 4]:
		_rejected(deck, party, "seamstress_darning", target, "Darning invalid slot " + str(target))
		_rejected(deck, party, "seamstress_thimble_tea", target, "Tea invalid slot " + str(target))
	for target in [-1, 1, 4]:
		_rejected(deck, party, "seamstress_field_mend", target,
			"party_all forbids selected slot " + str(target))
	_rejected(deck, party, "seamstress_field_mend_plus", 0, "upgrade absent from hand")
	_rejected(deck, party, "seamstress_darning_plus", 1, "Darning upgrade absent from hand")
	_rejected(deck, party, "seamstress_running_stitch", 1,
		"real but unhandled pool attack ID rejected")
	_rejected(deck, party, "seamstress_not_a_card", 1,
		"unknown card ID rejected even when present in hand")

	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"chosen ally is genuinely downed")
	_rejected(deck, party, "seamstress_darning", 3, "Darning cannot revive")
	_rejected(deck, party, "seamstress_thimble_tea", 3, "Tea cannot revive")

	party = _party(["seamstress", "warden", "tinker"])
	deck = _deck(["seamstress_thimble_tea", "seamstress_field_mend"])
	_check(party.get_hero(1)["id"] == "seamstress", "wrong-slot owner fixture")
	_rejected(deck, party, "seamstress_thimble_tea", 2, "Tea owner at illegal front slot")
	_rejected(deck, party, "seamstress_field_mend", 0, "Field owner at illegal front slot")

	party = _party()
	deck = _deck(["seamstress_darning", "seamstress_thimble_tea",
		"seamstress_field_mend"])
	_check(party.apply_damage(2, 30) and party.is_downed(2), "owner truly downed")
	_rejected(deck, party, "seamstress_darning", 1, "downed owner Darning")
	_rejected(deck, party, "seamstress_thimble_tea", 1, "downed owner Tea")
	_rejected(deck, party, "seamstress_field_mend", 0, "downed owner Field")

	party = _party()
	deck = _deck(["seamstress_darning", "seamstress_field_mend"])
	_check(deck.try_spend_energy(2) and deck.energy == 1, "Field cannot afford two energy")
	_rejected(deck, party, "seamstress_field_mend", 0, "Field insufficient energy")
	_check(deck.try_spend_energy(1) and deck.energy == 0, "Darning cannot afford one energy")
	_rejected(deck, party, "seamstress_darning", 1, "Darning exhausted energy")
	var zero_deck := _deck(["seamstress_thimble_tea"])
	_check(zero_deck.try_spend_energy(3) and zero_deck.energy == 0,
		"zero-cost exception truly has no energy")
	_played(zero_deck, party, "seamstress_thimble_tea", 1,
		"Tea legitimately plays with exhausted energy")

	party = _party()
	_check(party.apply_damage(1, 7) and party.gain_block(1, CombatParty.MAX_INT - 2),
		"Darning overflow fixture has wounded recipient near MAX_INT")
	deck = _deck(["seamstress_darning", "seamstress_darning_plus"])
	_rejected(deck, party, "seamstress_darning", 1,
		"Block overflow preflight rejects before healing")
	_rejected(deck, party, "seamstress_darning_plus", 1,
		"Block overflow preflight rejects upgrade before healing")

	party = _party()
	deck = _deck(["seamstress_darning"], 71, false)
	_check(not deck.turn_active and deck.energy == 0 and deck.hand.is_empty(),
		"turn really inactive with card still in draw")
	_rejected(deck, party, "seamstress_darning", 1, "inactive turn")
	_check(deck.start_turn(), "inactive fixture can start after rejection")
	_rejected(deck, CombatParty.new([]), "seamstress_darning", 1, "invalid party")
	_check(not resolver.play_card(null, party, "seamstress_darning", 1)
		and not resolver.play_card(deck, null, "seamstress_darning", 1),
		"null authorities safely reject")


func _load_patch_definitions() -> Array:
	var files := [
		CombatShopPatchRules.SLOTS_CATALOG,
		"res://data/patches/m05_head_patches.json",
		"res://data/patches/m05_arm_support_patches.json",
		"res://data/patches/m04_attack_patches.json",
		"res://data/patches/m05_coat_patches.json",
	]
	var definitions: Array = []
	var seen := {}
	for file_path: String in files:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
		_check(raw is Array and not (raw as Array).is_empty(), file_path + " is a readable array")
		if raw is Array:
			for entry in raw:
				if entry is Dictionary and entry.has("id") and entry.has("slot"):
					var pid: String = str(entry["id"])
					if not seen.has(pid):
						seen[pid] = true
						definitions.append({"id": pid, "slot": str(entry["slot"])})
	_check(seen.has("reinforced_browband"), "shipped reinforced_browband definition present")
	_check(seen.has("hemguard_cuff"), "shipped hemguard_cuff definition present")
	return definitions


## Real, unmodified ledgers: starter roster, authored patch catalog, one genuine sewing
## operation. Nothing here replaces stock, definitions or an authored card record.
func _patch_fixture(wearer: String = "seamstress", sew: bool = true,
		owned: Array = ["stitched_badge", "spare_spool"]) -> Dictionary:
	var definitions: Array = _load_patch_definitions()
	var party := _party()
	var heroes: Array = party.get_heroes()
	var torn := RunTornMending.new(heroes)
	var wardrobe := RunPatchWardrobe.new(heroes, owned, definitions, 0, 0, [], 4242)
	_check(torn.is_valid() and wardrobe.is_valid(),
		"real RunTornMending and RunPatchWardrobe initialize validly")
	if not torn.is_valid() or not wardrobe.is_valid():
		return {}
	if sew:
		var snapshot: Dictionary = wardrobe.get_snapshot()
		var sewn: Dictionary = wardrobe.sew("spare_spool", wearer, "ARM",
			"sew_spool_" + wearer, snapshot)
		_check(sewn.get("ok") == true
			and wardrobe.get_snapshot().worn[wearer].ARM == "spare_spool",
			"genuine Spare Spool sews into " + wearer + " ARM")
	return {"party": party, "torn": torn, "wardrobe": wardrobe}


func _m05_block_fixture(wearer: String = "seamstress", sew_head: bool = false,
		sew_arm: bool = false,
		owned: Array = ["reinforced_browband", "hemguard_cuff"]) -> Dictionary:
	var definitions: Array = _load_patch_definitions()
	var party := _party()
	var heroes: Array = party.get_heroes()
	var torn := RunTornMending.new(heroes)
	var wardrobe := RunPatchWardrobe.new(heroes, owned, definitions, 0, 0, [], 4242)
	_check(torn.is_valid() and wardrobe.is_valid(),
		"real RunTornMending and RunPatchWardrobe initialize validly for M05 Block")
	if not torn.is_valid() or not wardrobe.is_valid():
		return {}
	if sew_head and owned.has("reinforced_browband"):
		var snap: Dictionary = wardrobe.get_snapshot()
		var sewn: Dictionary = wardrobe.sew("reinforced_browband", wearer, "HEAD",
			"sew_head_" + wearer, snap)
		_check(sewn.get("ok") == true
			and wardrobe.get_snapshot().worn[wearer].HEAD == "reinforced_browband",
			"genuine reinforced_browband sews into " + wearer + " HEAD")
	if sew_arm and owned.has("hemguard_cuff"):
		var snap: Dictionary = wardrobe.get_snapshot()
		var sewn: Dictionary = wardrobe.sew("hemguard_cuff", wearer, "ARM",
			"sew_arm_" + wearer, snap)
		_check(sewn.get("ok") == true
			and wardrobe.get_snapshot().worn[wearer].ARM == "hemguard_cuff",
			"genuine hemguard_cuff sews into " + wearer + " ARM")
	return {"party": party, "torn": torn, "wardrobe": wardrobe}


func _patch_wound(party: CombatParty) -> void:
	_check(party.apply_damage(1, 12) and party.apply_damage(2, 14)
		and party.apply_damage(3, 10),
		"all three living heroes have room above the patched heal")
	_check(party.gain_block(1, 2) and party.gain_block(3, 3),
		"unrelated preexisting Block belongs to two recipients")


## A genuine active Spare Spool read through the same CombatShopPatchRules projection
## the mounted presenter binds: every heal gains exactly 2, Block is untouched.
func _test_patch_binding_cases() -> void:
	for id: String in CASES:
		var spec: Dictionary = CASES[id]
		var fixture := _patch_fixture()
		if fixture.is_empty():
			return
		var wardrobe: RunPatchWardrobe = fixture.wardrobe
		var torn: RunTornMending = fixture.torn
		var projection: Dictionary = wardrobe.project_active(torn.read_state())
		_check(projection.get("ok") == true
			and projection.active.seamstress.has("spare_spool"),
			id + ": authoritative projection marks Seamstress's Spool active")
		var service := CombatSeamstressPoolHeals.new()
		_check(service.bind_patch_wardrobe(wardrobe, torn)
			and service.is_patch_binding_valid(),
			id + ": active Spool binds from the real combat-start ledgers")
		var rules := CombatShopPatchRules.new()
		_check(rules.bind_wardrobe(wardrobe, torn)
			and rules.healing_card_bonus("seamstress", id) == 2
			and rules.project_card_healing("seamstress", id) == spec.effects.heal + 2
			and rules.project_card_healing("seamstress", "seamstress_running_stitch") == 0
			and rules.healing_card_bonus("warden", id) == 0,
			id + ": projection adds exactly 2 HP and no unrelated effect")
		var party: CombatParty = fixture.party
		_patch_wound(party)
		var deck := _deck([id, id, id, id, "filler-a", "filler-b", "filler-c"])
		var target: int = 0 if spec.kind == "party_all" else (3 if id in [
			"seamstress_thimble_tea", "seamstress_thimble_tea_plus"] else 1)
		var block_before: int = party.get_hero(target).block if target > 0 else 0
		_played(deck, party, id, target, id + " with active Spare Spool", 2, service)
		if spec.effects.has("block"):
			_check(party.get_hero(target).block == block_before + spec.effects.block,
				id + ": authored Block is never inflated by the Spool")

	# Owned but sewn to another hero: no bonus at all.
	var wrong := _patch_fixture("warden")
	if wrong.is_empty():
		return
	var wrong_service := CombatSeamstressPoolHeals.new()
	_check(wrong_service.bind_patch_wardrobe(wrong.wardrobe, wrong.torn)
		and wrong_service.is_patch_binding_valid(),
		"Spool sewn to Warden binds as the authoritative wardrobe")
	var wrong_rules := CombatShopPatchRules.new()
	_check(wrong_rules.bind_wardrobe(wrong.wardrobe, wrong.torn)
		and wrong_rules.active_snapshot()["warden"] == ["spare_spool"]
		and wrong_rules.active_snapshot()["seamstress"] == []
		and wrong_rules.healing_card_bonus("seamstress", "seamstress_darning") == 0
		and wrong_rules.project_card_healing("seamstress", "seamstress_darning") == 4,
		"Spool on Warden grants no Seamstress projection")
	var wrong_party: CombatParty = wrong.party
	_patch_wound(wrong_party)
	_played(_deck(["seamstress_darning", "seamstress_darning", "filler-a",
		"filler-b", "filler-c"]), wrong_party, "seamstress_darning", 1,
		"wrong-wearer Darning", 0, wrong_service)
	_patch_wound(wrong_party)
	_played(_deck(["seamstress_field_mend", "filler-a", "filler-b",
		"filler-c", "filler-d"]), wrong_party, "seamstress_field_mend", 0,
		"wrong-wearer Field Mend", 0, wrong_service)

	# Owned and unsewn: the authored assignment exists nowhere, so nothing is active.
	var unsewn := _patch_fixture("seamstress", false)
	if unsewn.is_empty():
		return
	_check(unsewn.wardrobe.get_snapshot().owned.has("spare_spool")
		and unsewn.wardrobe.project_active(unsewn.torn.read_state()).active.seamstress.is_empty(),
		"owned but unsewn Spool has no active projection")
	var unsewn_service := CombatSeamstressPoolHeals.new()
	_check(unsewn_service.bind_patch_wardrobe(unsewn.wardrobe, unsewn.torn)
		and unsewn_service.is_patch_binding_valid(),
		"unsewn wardrobe still binds without an active patch")
	var unsewn_rules := CombatShopPatchRules.new()
	_check(unsewn_rules.bind_wardrobe(unsewn.wardrobe, unsewn.torn)
		and unsewn_rules.healing_card_bonus("seamstress", "seamstress_thimble_tea_plus") == 0,
		"unsewn Spool grants no healing bonus")
	var unsewn_party: CombatParty = unsewn.party
	_patch_wound(unsewn_party)
	_played(_deck(["seamstress_thimble_tea_plus", "filler-a", "filler-b",
		"filler-c", "filler-d"]), unsewn_party, "seamstress_thimble_tea_plus", 1,
		"unsewn Tea+", 0, unsewn_service)

	# Torn (downed) Seamstress: the worn assignment remains, its benefit does not.
	var torn_fixture := _patch_fixture()
	if torn_fixture.is_empty():
		return
	var torn_wardrobe: RunPatchWardrobe = torn_fixture.wardrobe
	var torn: RunTornMending = torn_fixture.torn
	var start: Array = torn.read_state().heroes
	var end: Array = start.duplicate(true)
	end[1].hp = 0
	_check(torn.observe_battle_end("fight_torn_spool", start, end).get("ok") == true
		and torn.read_state().heroes[1].hp == 0,
		"Seamstress is genuinely torn down to zero HP")
	var refresh: Dictionary = torn_wardrobe.get_snapshot()
	_check(torn_wardrobe.refresh_run_context(torn.read_state().heroes, refresh.owned,
		refresh.scraps, refresh.gold, refresh.cards, refresh),
		"wardrobe adopts the torn roster without losing the sewn assignment")
	var torn_projection: Dictionary = torn_wardrobe.project_active(torn.read_state())
	_check(torn_projection.get("ok") == true
		and torn_projection.worn.seamstress.ARM == "spare_spool"
		and torn_projection.active.seamstress.is_empty(),
		"torn Seamstress keeps the Spool sewn but has no active projection")
	var torn_service := CombatSeamstressPoolHeals.new()
	_check(torn_service.bind_patch_wardrobe(torn_wardrobe, torn)
		and torn_service.is_patch_binding_valid(),
		"torn roster still binds an authenticated projection")
	var torn_rules := CombatShopPatchRules.new()
	_check(torn_rules.bind_wardrobe(torn_wardrobe, torn)
		and torn_rules.healing_card_bonus("seamstress", "seamstress_field_mend_plus") == 0
		and torn_rules.project_card_healing("seamstress", "seamstress_field_mend_plus") == 0,
		"torn wearer adds no heal bonus to any authored healing card")
	var torn_party: CombatParty = torn_fixture.party
	_check(torn_party.apply_damage(2, 9999) and torn_party.is_downed(2),
		"combat owner is genuinely downed in the torn fixture")
	_rejected(_deck(["seamstress_darning", "seamstress_field_mend"]), torn_party,
		"seamstress_darning", 1, "torn/downed owner", torn_service)

	# Invalid bindings fail closed before spending and never mutate either ledger.
	var invalid := _patch_fixture()
	if invalid.is_empty():
		return
	var ledger_before: Array = [invalid.wardrobe.get_snapshot(), invalid.torn.read_state()]
	var invalid_service := CombatSeamstressPoolHeals.new()
	_check(not invalid_service.bind_patch_wardrobe(null, invalid.torn)
		and not invalid_service.is_patch_binding_valid(),
		"null wardrobe binding fails closed")
	var stale_snapshot: Dictionary = invalid.wardrobe.get_snapshot()
	invalid.wardrobe._gold += 1
	var drifted_snapshot: Dictionary = invalid.wardrobe.get_snapshot()
	var torn_state_before: Dictionary = invalid.torn.read_state()
	var stale_service := CombatSeamstressPoolHeals.new()
	_check(not stale_service.bind_patch_wardrobe(invalid.wardrobe, invalid.torn,
		stale_snapshot, invalid.torn.read_state())
		and not stale_service.is_patch_binding_valid(),
		"stale expected wardrobe snapshot rejects binding")
	_check(not CombatSeamstressPoolHeals.new().bind_patch_wardrobe(invalid.wardrobe,
		invalid.torn, drifted_snapshot, {})
		and invalid.wardrobe.get_snapshot() == drifted_snapshot
		and invalid.torn.read_state() == torn_state_before,
		"stale expected torn snapshot rejects binding without ledger mutation")
	invalid.wardrobe._gold -= 1
	var invalid_party := _party()
	_patch_wound(invalid_party)
	var invalid_deck := _deck(["seamstress_darning", "seamstress_field_mend"])
	_rejected(invalid_deck, invalid_party, "seamstress_darning", 1,
		"invalid binding Darning", invalid_service)
	_rejected(invalid_deck, invalid_party, "seamstress_field_mend", 0,
		"invalid binding Field Mend", stale_service)

	# Drift after admission invalidates the bound projection until a fresh binding.
	var drift_service := CombatSeamstressPoolHeals.new()
	_check(drift_service.bind_patch_wardrobe(invalid.wardrobe, invalid.torn)
		and drift_service.is_patch_binding_valid(),
		"fresh real ledgers bind and recover")
	invalid.wardrobe._gold += 1
	_check(not drift_service.is_patch_binding_valid(),
		"drifted wardrobe invalidates the already-bound projection")
	_rejected(invalid_deck, invalid_party, "seamstress_darning", 1,
		"drifted binding Darning", drift_service)
	invalid.wardrobe._gold -= 1
	_check(drift_service.is_patch_binding_valid(),
		"restored real ledger is current again without silent repair")
	_check([invalid.wardrobe.get_snapshot(), invalid.torn.read_state()] == ledger_before,
		"binding attempts and rejections never mutate the authoritative ledgers")


func _test_m05_block_patch_cases() -> void:
	# AC1: HEAD only (reinforced_browband) adds +2 Block to Darning and Darning+
	var head_fix := _m05_block_fixture("seamstress", true, false)
	_check(not head_fix.is_empty(), "HEAD-only fixture created")
	var head_service := CombatSeamstressPoolHeals.new()
	_check(head_service.bind_patch_wardrobe(head_fix.wardrobe, head_fix.torn)
		and head_service.is_patch_binding_valid(),
		"HEAD-only wardrobe binds validly")
	var head_party: CombatParty = head_fix.party
	_patch_wound(head_party)
	var head_deck := _deck(["seamstress_darning", "seamstress_darning_plus", "filler-a", "filler-b", "filler-c"])
	# Darning base block 3 + 2 = 5, heal 4
	_played(head_deck, head_party, "seamstress_darning", 1, "HEAD-only Darning to ally 1", 0, head_service, 2)
	# Darning+ base block 4 + 2 = 6, heal 6
	_played(head_deck, head_party, "seamstress_darning_plus", 3, "HEAD-only Darning+ to ally 3", 0, head_service, 2)

	# AC1: Full-HP target with HEAD only
	var head_full_party := _party()
	var head_full_deck := _deck(["seamstress_darning"])
	_played(head_full_deck, head_full_party, "seamstress_darning", 2, "HEAD-only Darning on full-HP self", 0, head_service, 2)
	_check(head_full_party.get_hero(2)["hp"] == 30 and head_full_party.get_hero(2)["block"] == 5,
		"HEAD-only Darning grants Block 5 to full-HP self without overhealing")

	# AC2: ARM only (hemguard_cuff) adds +2 Block to Darning and Darning+
	var arm_fix := _m05_block_fixture("seamstress", false, true)
	_check(not arm_fix.is_empty(), "ARM-only fixture created")
	var arm_service := CombatSeamstressPoolHeals.new()
	_check(arm_service.bind_patch_wardrobe(arm_fix.wardrobe, arm_fix.torn)
		and arm_service.is_patch_binding_valid(),
		"ARM-only wardrobe binds validly")
	var arm_party: CombatParty = arm_fix.party
	_patch_wound(arm_party)
	var arm_deck := _deck(["seamstress_darning", "seamstress_darning_plus", "filler-a", "filler-b", "filler-c"])
	# Darning base block 3 + 2 = 5, heal 4
	_played(arm_deck, arm_party, "seamstress_darning", 1, "ARM-only Darning to ally 1", 0, arm_service, 2)
	# Darning+ base block 4 + 2 = 6, heal 6
	_played(arm_deck, arm_party, "seamstress_darning_plus", 3, "ARM-only Darning+ to ally 3", 0, arm_service, 2)

	# AC2: Both HEAD and ARM sewn produce printed Block + 4 (Darning: 7, Darning+: 8)
	var both_fix := _m05_block_fixture("seamstress", true, true)
	_check(not both_fix.is_empty(), "both-patch fixture created")
	var both_service := CombatSeamstressPoolHeals.new()
	_check(both_service.bind_patch_wardrobe(both_fix.wardrobe, both_fix.torn)
		and both_service.is_patch_binding_valid(),
		"both-patch wardrobe binds validly")
	var both_party: CombatParty = both_fix.party
	_patch_wound(both_party)
	var both_deck := _deck(["seamstress_darning", "seamstress_darning_plus", "filler-a", "filler-b", "filler-c"])
	# Darning base block 3 + 4 = 7, heal 4
	_played(both_deck, both_party, "seamstress_darning", 1, "both-patch Darning to ally 1", 0, both_service, 4)
	# Darning+ base block 4 + 4 = 8, heal 6
	_played(both_deck, both_party, "seamstress_darning_plus", 3, "both-patch Darning+ to ally 3", 0, both_service, 4)

	# AC2: Both patches: 2 consecutive plays of Darning in same turn
	var two_party := _party()
	_patch_wound(two_party)
	var two_deck := _deck(["seamstress_darning", "seamstress_darning", "filler-a", "filler-b", "filler-c"])
	_check(two_deck.energy == 3 and two_deck.hand.count("seamstress_darning") == 2, "two Darning copies ready")
	_played(two_deck, two_party, "seamstress_darning", 2, "both-patch first Darning copy", 0, both_service, 4)
	_check(two_deck.energy == 2 and two_deck.hand.count("seamstress_darning") == 1 and two_deck.discard_pile.count("seamstress_darning") == 1,
		"first Darning spent exactly 1 energy and discarded exactly 1 copy")
	_played(two_deck, two_party, "seamstress_darning", 2, "both-patch second Darning copy", 0, both_service, 4)
	_check(two_deck.energy == 1 and two_deck.hand.count("seamstress_darning") == 0 and two_deck.discard_pile.count("seamstress_darning") == 2,
		"second Darning spent exactly 1 energy and discarded second copy")
	_check(two_party.get_hero(2)["block"] == 14, "consecutive plays stacked Block to 14 (7 + 7)")

	# AC3: Owned but unsewn grants no Block bonus (Block 3 and 4)
	var unsewn_fix := _m05_block_fixture("seamstress", false, false)
	var unsewn_service := CombatSeamstressPoolHeals.new()
	_check(unsewn_service.bind_patch_wardrobe(unsewn_fix.wardrobe, unsewn_fix.torn)
		and unsewn_service.is_patch_binding_valid(),
		"unsewn M05 wardrobe binds validly")
	var unsewn_party: CombatParty = unsewn_fix.party
	_patch_wound(unsewn_party)
	var unsewn_deck := _deck(["seamstress_darning", "seamstress_darning_plus", "filler-a", "filler-b", "filler-c"])
	_played(unsewn_deck, unsewn_party, "seamstress_darning", 1, "unsewn M05 Darning", 0, unsewn_service, 0)
	_played(unsewn_deck, unsewn_party, "seamstress_darning_plus", 3, "unsewn M05 Darning+", 0, unsewn_service, 0)

	# AC3: Patches sewn to Warden instead of Seamstress grant no Block bonus
	var warden_fix := _m05_block_fixture("warden", true, true)
	var warden_service := CombatSeamstressPoolHeals.new()
	_check(warden_service.bind_patch_wardrobe(warden_fix.wardrobe, warden_fix.torn)
		and warden_service.is_patch_binding_valid(),
		"Warden-worn M05 wardrobe binds validly")
	var warden_party: CombatParty = warden_fix.party
	_patch_wound(warden_party)
	var warden_deck := _deck(["seamstress_darning", "seamstress_darning_plus", "filler-a", "filler-b", "filler-c"])
	_played(warden_deck, warden_party, "seamstress_darning", 1, "Warden-worn M05 Darning", 0, warden_service, 0)
	_played(warden_deck, warden_party, "seamstress_darning_plus", 3, "Warden-worn M05 Darning+", 0, warden_service, 0)

	# AC3: Tea and Field Mend gain NO Block even with both patches sewn to Seamstress
	var spells_party: CombatParty = both_fix.party
	_patch_wound(spells_party)
	var spells_deck := _deck(["seamstress_thimble_tea", "seamstress_thimble_tea_plus",
		"seamstress_field_mend", "filler-a", "filler-b"])
	var b1_before: int = spells_party.get_hero(1)["block"]
	var b2_before: int = spells_party.get_hero(2)["block"]
	var b3_before: int = spells_party.get_hero(3)["block"]
	_played(spells_deck, spells_party, "seamstress_thimble_tea", 1, "patched Tea has no Block", 0, both_service, 0)
	_played(spells_deck, spells_party, "seamstress_thimble_tea_plus", 3, "patched Tea+ has no Block", 0, both_service, 0)
	_played(spells_deck, spells_party, "seamstress_field_mend", 0, "patched Field Mend has no Block", 0, both_service, 0)
	_check(spells_party.get_hero(1)["block"] == b1_before and spells_party.get_hero(2)["block"] == b2_before
		and spells_party.get_hero(3)["block"] == b3_before,
		"Tea and Field Mend never added any Block to any hero")

	# Field Mend+ also gains no Block (tested on fresh deck)
	var fm_party: CombatParty = _party()
	_patch_wound(fm_party)
	var fm_deck := _deck(["seamstress_field_mend_plus"])
	var fm_b1: int = fm_party.get_hero(1)["block"]
	var fm_b2: int = fm_party.get_hero(2)["block"]
	var fm_b3: int = fm_party.get_hero(3)["block"]
	_played(fm_deck, fm_party, "seamstress_field_mend_plus", 0, "patched Field Mend+ has no Block", 0, both_service, 0)
	_check(fm_party.get_hero(1)["block"] == fm_b1 and fm_party.get_hero(2)["block"] == fm_b2
		and fm_party.get_hero(3)["block"] == fm_b3,
		"Field Mend+ never added any Block to any hero")

	# AC3: Final Block overflow preflight check
	# With both patches, Darning grants 7 Block.
	# If ally 1 has MAX_INT - 6 Block, 7 > 6 so it must overflow and reject before any heal or spend.
	var of_party := _party()
	_check(of_party.apply_damage(1, 10), "target 1 is wounded")
	_check(of_party.gain_block(1, CombatParty.MAX_INT - 6), "target 1 has MAX_INT - 6 Block")
	var of_deck := _deck(["seamstress_darning", "seamstress_darning_plus", "filler-a", "filler-b", "filler-c"])
	_rejected(of_deck, of_party, "seamstress_darning", 1, "both-patch Darning final-Block overflow", both_service)
	# For Darning+, final block is 8. If target 3 has MAX_INT - 7 Block, 8 > 7 so it overflows and rejects.
	_check(of_party.apply_damage(3, 10), "target 3 is wounded")
	_check(of_party.gain_block(3, CombatParty.MAX_INT - 7), "target 3 has MAX_INT - 7 Block")
	_rejected(of_deck, of_party, "seamstress_darning_plus", 3, "both-patch Darning+ final-Block overflow", both_service)

	# AC3: Invalid targeting and energy with both patches
	var inv_party := _party()
	var inv_deck := _deck(["seamstress_darning", "seamstress_darning", "seamstress_darning", "filler-a", "filler-b"])
	_rejected(inv_deck, inv_party, "seamstress_darning", 0, "both-patch Darning invalid target 0", both_service)
	_rejected(inv_deck, inv_party, "seamstress_darning", 4, "both-patch Darning invalid target 4", both_service)
	_check(inv_party.apply_damage(3, 26) and inv_party.is_downed(3), "target 3 truly downed")
	_rejected(inv_deck, inv_party, "seamstress_darning", 3, "both-patch Darning downed target", both_service)
	_check(inv_deck.try_spend_energy(3) and inv_deck.energy == 0, "energy exhausted")
	_rejected(inv_deck, inv_party, "seamstress_darning", 1, "both-patch Darning exhausted energy", both_service)

	# AC3: Genuine torn ledger state transition (downed wearer)
	var torn_block_fix := _m05_block_fixture("seamstress", true, true)
	var tb_wardrobe: RunPatchWardrobe = torn_block_fix.wardrobe
	var tb_torn: RunTornMending = torn_block_fix.torn
	var tb_start: Array = tb_torn.read_state().heroes
	var tb_end: Array = tb_start.duplicate(true)
	tb_end[1].hp = 0
	_check(tb_torn.observe_battle_end("fight_torn_block", tb_start, tb_end).get("ok") == true
		and tb_torn.read_state().heroes[1].hp == 0,
		"Seamstress genuinely torn to 0 HP in torn ledger")
	var tb_refresh: Dictionary = tb_wardrobe.get_snapshot()
	_check(tb_wardrobe.refresh_run_context(tb_torn.read_state().heroes, tb_refresh.owned,
		tb_refresh.scraps, tb_refresh.gold, tb_refresh.cards, tb_refresh),
		"wardrobe refreshed with torn roster")
	var tb_proj: Dictionary = tb_wardrobe.project_active(tb_torn.read_state())
	_check(tb_proj.active.seamstress.is_empty(), "torn Seamstress has no active M05 patches")
	var tb_service := CombatSeamstressPoolHeals.new()
	_check(tb_service.bind_patch_wardrobe(tb_wardrobe, tb_torn) and tb_service.is_patch_binding_valid(),
		"torn M05 wardrobe binds validly")
	# Divergent state test (Lesson 41): combat party has living Seamstress, but run torn ledger marks her torn
	var div_party := _party()
	_patch_wound(div_party)
	var div_deck := _deck(["seamstress_darning", "seamstress_darning_plus", "filler-a", "filler-b", "filler-c"])
	# Plays with base Block 3 and 4, NO patch bonus:
	_played(div_deck, div_party, "seamstress_darning", 1, "divergent torn Seamstress Darning grants no bonus", 0, tb_service, 0)
	_played(div_deck, div_party, "seamstress_darning_plus", 3, "divergent torn Seamstress Darning+ grants no bonus", 0, tb_service, 0)

	# If Seamstress is actually downed in combat party, play rejects atomically:
	_check(div_party.apply_damage(2, 9999) and div_party.is_downed(2), "combat owner downed")
	_rejected(div_deck, div_party, "seamstress_darning", 1, "downed owner in party rejects atomically", tb_service)

	# AC4: Coexistence of HEAD reinforced_browband (+2 Block) and ARM spare_spool (+2 Heal)
	var co_defs: Array = _load_patch_definitions()
	var co_party := _party()
	var co_heroes: Array = co_party.get_heroes()
	var co_torn := RunTornMending.new(co_heroes)
	var co_wardrobe := RunPatchWardrobe.new(co_heroes, ["reinforced_browband", "spare_spool"], co_defs, 0, 0, [], 4242)
	var co_snap: Dictionary = co_wardrobe.get_snapshot()
	_check(co_wardrobe.sew("reinforced_browband", "seamstress", "HEAD", "sew_co_head", co_snap).get("ok") == true,
		"reinforced_browband sewn to HEAD")
	co_snap = co_wardrobe.get_snapshot()
	_check(co_wardrobe.sew("spare_spool", "seamstress", "ARM", "sew_co_arm", co_snap).get("ok") == true,
		"spare_spool sewn to ARM")
	var co_service := CombatSeamstressPoolHeals.new()
	_check(co_service.bind_patch_wardrobe(co_wardrobe, co_torn) and co_service.is_patch_binding_valid(),
		"coexisting HEAD browband and ARM spool bind validly")
	_patch_wound(co_party)
	var co_deck := _deck(["seamstress_darning", "seamstress_darning_plus", "filler-a", "filler-b", "filler-c"])
	# Darning: heal 4 + 2 = 6, Block 3 + 2 = 5
	_played(co_deck, co_party, "seamstress_darning", 1, "coexisting browband and spool Darning", 2, co_service, 2)
	# Darning+: heal 6 + 2 = 8, Block 4 + 2 = 6
	_played(co_deck, co_party, "seamstress_darning_plus", 3, "coexisting browband and spool Darning+", 2, co_service, 2)



## Borrowed Button is worn and sewn through the real run ledgers. The same
## authenticated combat owns every subsequent card receipt and single-use latch.
func _button_fixture(wearer: String = "warden", sew: bool = true,
		owned: Array = ["borrowed_button"]) -> Dictionary:
	var party := _party()
	var heroes := party.get_heroes()
	var torn := RunTornMending.new(heroes)
	var wardrobe := RunPatchWardrobe.new(heroes, owned, _load_patch_definitions(),
		0, 0, [], 4242)
	_check(torn.is_valid() and wardrobe.is_valid(), "Borrowed Button run authorities valid")
	if not torn.is_valid() or not wardrobe.is_valid():
		return {}
	if sew:
		var sewn := wardrobe.sew("borrowed_button", wearer, "COAT",
			"sew_button_" + wearer, wardrobe.get_snapshot())
		_check(sewn.get("ok") == true
			and wardrobe.get_snapshot().worn[wearer].COAT == "borrowed_button",
			"authentic COAT sewing committed on " + wearer)
	return {"party": party, "wardrobe": wardrobe, "torn": torn}


func _button_service(fixture: Dictionary) -> CombatSeamstressPoolHeals:
	var service := CombatSeamstressPoolHeals.new()
	_check(service.bind_patch_wardrobe(fixture.wardrobe, fixture.torn)
		and service.is_patch_binding_valid(),
		"all combat patch authorities authenticate before a COAT cast")
	return service


## The independent oracle adds exactly one COAT grant after authored healing and
## Darning's printed Block; unchanged deck piles/energy/RNG are checked as a whole.
func _button_play(deck: CombatDeck, party: CombatParty, service: CombatSeamstressPoolHeals,
		id: String, target: int, wearer_position: int, earns_button: bool,
		label: String, heal_bonus: int = 0, block_bonus: int = 0) -> void:
	var before := _snapshot(deck, party)
	_check(deck.turn_active and deck.hand.has(id) and deck.energy >= CASES[id].cost,
		label + ": genuinely held and affordable")
	var expected := _expected(before, id, target, heal_bonus, block_bonus)
	if earns_button:
		expected.heroes[wearer_position - 1].block += 3
	_check(service.play_card(deck, party, id, target), label + ": real held copy commits")
	_check(_snapshot(deck, party) == expected,
		label + ": exact healing/Block plus single +3, one charge/discard and unchanged RNG")
	_check(deck.hand.count(id) == before.hand.count(id) - 1
		and deck.discard_pile.count(id) == before.discard.count(id) + 1,
		label + ": exactly one copy spent")


func _test_borrowed_button_all_six() -> void:
	var index := 0
	for id: String in CASES:
		var wearer: String = "warden" if index % 2 == 0 else "tinker"
		var position: int = 1 if wearer == "warden" else 3
		var fixture := _button_fixture(wearer)
		if fixture.is_empty():
			return
		var party: CombatParty = fixture.party
		var projection: Dictionary = fixture.wardrobe.project_active(fixture.torn.read_state())
		_check(projection.get("ok") == true
			and projection.active[wearer].has("borrowed_button"),
			id + ": genuine COAT active on a living other hero")
		_wound_all(party)
		var service := _button_service(fixture)
		var deck := _deck([id, id, "filler-a", "filler-b", "filler-c"], 809 + index)
		var target: int = 0 if CASES[id].kind == "party_all" else position
		_button_play(deck, party, service, id, target, position, true,
			id + " authentic COAT " + wearer)
		var state := service._borrowed_button.read_state()
		_check(state.ok and state.awards == 1 and state.block_awarded == 3
			and state.wearer_id == wearer and state.receipt_id == "seamstress_pool_heal:1:%d" % position,
			id + ": recipient-specific deterministic committed receipt awards once")
		_check(state.receipts.size() == (3 if target == 0 else 1),
			id + ": all and only actual living recipients are reported")
		index += 1

	# Preserve combined M04 Spare Spool heal and M05 HEAD/ARM Darning Block.
	var coexist := _button_fixture("warden", true,
		["borrowed_button", "spare_spool", "reinforced_browband", "hemguard_cuff"])
	var w: RunPatchWardrobe = coexist.wardrobe
	for entry in [["spare_spool", "ARM"], ["reinforced_browband", "HEAD"]]:
		_check(w.sew(entry[0], "seamstress", entry[1], "button_co_" + entry[0],
			w.get_snapshot()).get("ok") == true, "authentic supporting patch sewed " + entry[0])
	var co_service := _button_service(coexist)
	var co_party: CombatParty = coexist.party
	_wound_all(co_party)
	_button_play(_deck(["seamstress_darning"]), co_party, co_service,
		"seamstress_darning", 1, 1, true,
		"Spool +2 heal, HEAD +2 printed Block, COAT +3 separate", 2, 2)

	# A downed recipient is omitted even when Field Mend heals two other heroes.
	var skip := _button_fixture("tinker")
	var skip_party: CombatParty = skip.party
	_check(skip_party.apply_damage(1, 9999) and skip_party.is_downed(1)
		and skip_party.apply_damage(2, 9) and skip_party.apply_damage(3, 9),
		"Field Mend has exactly two living wounded recipients")
	_button_play(_deck(["seamstress_field_mend_plus"]), skip_party,
		_button_service(skip), "seamstress_field_mend_plus", 0, 3, true,
		"Field Mend+ skips fallen Warden and pays living Tinker")
	_check(skip_party.get_hero(1).hp == 0, "Field Mend never revives downed Warden")


func _test_borrowed_button_latch_and_replay() -> void:
	var fixture := _button_fixture("warden")
	var service := _button_service(fixture)
	var party: CombatParty = fixture.party
	_wound_all(party)
	var deck := _deck(["seamstress_thimble_tea", "seamstress_darning",
		"seamstress_field_mend", "filler-a", "filler-b"], 7701)
	_button_play(deck, party, service, "seamstress_thimble_tea", 1, 1, true,
		"first Tea earns only COAT award")
	var first_button: CombatBorrowedButton = service._borrowed_button
	_check(service.bind_patch_wardrobe(fixture.wardrobe, fixture.torn)
		and service._borrowed_button == first_button
		and first_button.read_state().awards == 1,
		"same-combat redundant authority bind preserves the already spent latch")
	_button_play(deck, party, service, "seamstress_darning", 1, 1, false,
		"second positive Darning cannot duplicate COAT")
	_button_play(deck, party, service, "seamstress_field_mend", 0, 1, false,
		"third positive multi-ally Mend cannot duplicate COAT")
	var button: CombatBorrowedButton = service._borrowed_button
	var state := button.read_state()
	_check(state.ok and state.awards == 1 and state.receipts.size() == 5,
		"three legal commits produce five distinct recipient receipts and just one award")
	_check(state.receipts == ["seamstress_pool_heal:1:1",
		"seamstress_pool_heal:2:1", "seamstress_pool_heal:3:1",
		"seamstress_pool_heal:3:2", "seamstress_pool_heal:3:3"],
		"receipt identities are deterministic, ordered and unique")
	var committed := _snapshot(deck, party)
	var duplicate := button.notify_committed_heal(state.receipt_id, "seamstress",
		"warden", 31, party.get_hero(1).hp)
	var stale := button.notify_committed_heal("forged-old-observation", "seamstress",
		"warden", 1, 2)
	_check(not duplicate.ok and duplicate.reason == "duplicate_receipt"
		and not stale.ok and stale.reason == "stale_observation",
		"replayed and stale claimed receipts are refused by existing helper")
	_check(_snapshot(deck, party) == committed and button.read_state().awards == 1,
		"forged/replayed receipt cannot change battle or award another Block")

	# A fresh party paired with an explicit rebind is a new battle even when the
	# unchanged run ledgers are shared by consecutive combats.
	var same_run_party := _party()
	_check(same_run_party.apply_damage(1, 9), "second battle uses newly wounded party")
	_check(service.bind_patch_wardrobe(fixture.wardrobe, fixture.torn),
		"same run ledgers reauthenticate for a distinct battle party")
	_button_play(_deck(["seamstress_thimble_tea"]), same_run_party, service,
		"seamstress_thimble_tea", 1, 1, true,
		"new combat party re-arms despite unchanged run ledgers")
	_check(service._borrowed_button != button
		and service._borrowed_button.read_state().awards == 1,
		"new party owns new notifier without resetting prior-combat receipts")

	# Only an explicit genuinely new-combat rebind can rearm this service's latch.
	var next_fixture := _button_fixture("tinker")
	_check(service.bind_patch_wardrobe(next_fixture.wardrobe, next_fixture.torn),
		"second combat supplies a fresh genuine run authority")
	var next_party: CombatParty = next_fixture.party
	_check(next_party.apply_damage(3, 12), "new combat Tinker is wounded")
	_button_play(_deck(["seamstress_thimble_tea"]), next_party, service,
		"seamstress_thimble_tea", 3, 3, true, "new combat re-arms once")
	_check(service._borrowed_button.read_state().awards == 1
		and service._borrowed_button.read_state().wearer_id == "tinker"
		and service._borrowed_button != button,
		"fresh combat owns a new helper/latch, old helper remains spent")


## Independent Mend oracle: the support resolver performs the only HP/energy/card
## mutation, then the pool-owned notifier observes its real committed result.
func _starter_button_play(deck: CombatDeck, party: CombatParty,
		service: CombatSeamstressPoolHeals, starter: CombatStarterSupportPlay,
		id: String, target: int, award: bool, label: String) -> void:
	var before := _snapshot(deck, party)
	var amount := 7 if id == "seamstress_mend_plus" else 5
	_check(deck.turn_active and deck.hand.has(id) and deck.energy >= 1
		and party.get_hero(target).hp > 0, label + ": held, affordable, living target")
	var expected := before.duplicate(true)
	expected.heroes[target - 1].hp = mini(
		expected.heroes[target - 1].max_hp, expected.heroes[target - 1].hp + amount)
	if award:
		expected.heroes[target - 1].block += 3
	expected.energy -= 1
	expected.state_energy -= 1
	expected.hand.remove_at(expected.hand.find(id))
	expected.discard.append(id)
	var before_hp: int = party.get_hero(target).hp
	_check(starter.play_card(deck, party, id, target), label + ": actual starter card committed")
	var result := service.notify_committed_starter_mend(
		deck, party, id, target, before_hp, party.get_hero(target).hp,
		before.hand.count(id), before.discard.size(), before.energy)
	_check(result.get("awarded") == award and result.get("block", 0) == (3 if award else 0),
		label + ": shared COAT authority returns exact conditional Block")
	_check(_snapshot(deck, party) == expected,
		label + ": exact HP, +3 only once, one energy/discard, unchanged RNG")
	_check(deck.hand.count(id) == before.hand.count(id) - 1
		and deck.discard_pile.count(id) == before.discard.count(id) + 1,
		label + ": only one held copy consumed")


func _test_borrowed_button_starter_mixed_orders() -> void:
	for starter_first in [true, false]:
		var fixture := _button_fixture("warden")
		if fixture.is_empty():
			return
		var party: CombatParty = fixture.party
		_check(party.apply_damage(1, 16) and party.get_hero(1).hp == 24,
			"mixed-order Warden has enough missing HP for both authentic heals")
		var service := _button_service(fixture)
		var starter := CombatStarterSupportPlay.new()
		_check(starter.bind_patch_wardrobe(fixture.wardrobe, fixture.torn),
			"starter resolver shares the identical genuine patch authorities")
		var id := "seamstress_mend" if starter_first else "seamstress_mend_plus"
		var deck := _deck([id, "seamstress_darning", "filler-a", "filler-b", "filler-c"])
		var label := "starter then pool" if starter_first else "pool then starter"
		if starter_first:
			_starter_button_play(deck, party, service, starter, id, 1, true, label + ": first")
		else:
			_button_play(deck, party, service, "seamstress_darning", 1, 1, true, label + ": first")
		var button: CombatBorrowedButton = service._borrowed_button
		_check(service.bind_patch_wardrobe(fixture.wardrobe, fixture.torn)
			and service._borrowed_button == button and button.read_state().awards == 1,
			label + ": same-party rebind cannot replenish COAT")
		if starter_first:
			_button_play(deck, party, service, "seamstress_darning", 1, 1, false, label + ": second")
		else:
			_starter_button_play(deck, party, service, starter, id, 1, false, label + ": second")
		var state := button.read_state()
		var first_receipt := "starter_mend:1:1" if starter_first else "seamstress_pool_heal:1:1"
		var second_receipt := "seamstress_pool_heal:2:1" if starter_first else "starter_mend:2:1"
		_check(state.ok and state.awards == 1 and state.block_awarded == 3
			and state.wearer_id == "warden" and state.receipt_id == first_receipt
			and state.receipts == [first_receipt, second_receipt],
			label + ": one shared latch and two unique cross-route receipts")
		var before_replay := _snapshot(deck, party)
		var duplicate := button.notify_committed_heal(first_receipt, "seamstress",
			"warden", 24, party.get_hero(1).hp)
		var forged := button.notify_committed_heal("stale_starter_observation", "seamstress",
			"warden", 12, 13)
		var corrected := button.notify_committed_heal("stale_starter_observation",
			"seamstress", "warden", 24, party.get_hero(1).hp)
		_check(not duplicate.ok and duplicate.reason == "duplicate_receipt"
			and not forged.ok and forged.reason == "stale_observation"
			and not corrected.ok and corrected.reason == "duplicate_receipt"
			and _snapshot(deck, party) == before_replay and button.read_state().awards == 1,
			label + ": stale and replayed observations cannot redeem or mutate state")
		# A distinctly new CombatParty on the same run ledgers re-arms the exact helper.
		var new_party := _party()
		_check(new_party.apply_damage(1, 12), label + ": new combat wearer wounded")
		_check(service.bind_patch_wardrobe(fixture.wardrobe, fixture.torn),
			label + ": new party uses authentic unchanged run authorities")
		var fresh_deck := _deck(["seamstress_mend_plus"])
		_starter_button_play(fresh_deck, new_party, service, starter,
			"seamstress_mend_plus", 1, true, label + ": new fight")
		_check(service._borrowed_button != button
			and service._borrowed_button.read_state().awards == 1
			and service._borrowed_button.read_state().receipt_id == "starter_mend:1:1",
			label + ": distinct fight has a fresh single-use notifier")


func _test_borrowed_button_starter_negatives() -> void:
	for scenario in ["full_hp", "unsewn", "wrong_wearer", "self", "downed_healer",
			"downed_recipient", "insufficient_energy", "invalid_binding"]:
		var wearer := "seamstress" if scenario == "self" else (
			"tinker" if scenario == "wrong_wearer" else "warden")
		var fixture := _button_fixture(wearer, scenario != "unsewn")
		if fixture.is_empty():
			return
		var party: CombatParty = fixture.party
		var service := _button_service(fixture)
		var starter := CombatStarterSupportPlay.new()
		_check(starter.bind_patch_wardrobe(fixture.wardrobe, fixture.torn),
			scenario + ": genuine starter wardrobe binding")
		var target := 2 if scenario == "self" else 1
		if scenario != "full_hp":
			_check(party.apply_damage(target, 9), scenario + ": missing HP exists")
		if scenario == "downed_healer":
			_check(party.apply_damage(2, 9999), "downed Seamstress cannot play")
		if scenario == "downed_recipient":
			_check(party.apply_damage(target, 9999), "downed Warden cannot receive Mend")
		if scenario == "invalid_binding":
			fixture.wardrobe._gold += 1
		var deck := _deck(["seamstress_mend"])
		if scenario == "insufficient_energy":
			_check(deck.try_spend_energy(3), "no energy remains for Mend")
		var before := _snapshot(deck, party)
		if scenario in ["downed_healer", "downed_recipient", "insufficient_energy",
				"invalid_binding"]:
			_check(not starter.play_card(deck, party, "seamstress_mend", target),
				scenario + ": real starter cast refused")
			_check(_snapshot(deck, party) == before
				and service._borrowed_button.read_state().receipts.is_empty(),
				scenario + ": refused transaction preserves HP, Block, piles, RNG and latch")
		else:
			_check(starter.play_card(deck, party, "seamstress_mend", target),
				scenario + ": legal starter Mend commits")
			var result := service.notify_committed_starter_mend(
				deck, party, "seamstress_mend", target, before.heroes[target - 1].hp,
				party.get_hero(target).hp, before.hand.count("seamstress_mend"),
				before.discard.size(), before.energy)
			_check(not result.get("awarded", false)
				and party.get_hero(target).block == before.heroes[target - 1].block
				and service._borrowed_button.read_state().awards == 0,
				scenario + ": no COAT award for zero heal, self or wrong/unsewn wearer")
	var fixture := _button_fixture("warden")
	var party: CombatParty = fixture.party
	var service := _button_service(fixture)
	_check(party.apply_damage(1, 9), "invalid observation test wearer wounded")
	var pending_deck := _deck(["seamstress_mend"])
	var before := _snapshot(pending_deck, party)
	var invalid := service.notify_committed_starter_mend(pending_deck, party,
		"seamstress_stitch_up", 1, 31, 32, 1, 0, 3)
	var stale := service.notify_committed_starter_mend(pending_deck, party,
		"seamstress_mend", 1, 31, 32, before.hand.count("seamstress_mend"),
		before.discard.size(), before.energy)
	_check(not invalid.get("ok", false) and not stale.get("ok", false)
		and service._borrowed_button.read_state().awards == 0
		and party.get_hero(1).block == 0,
		"non-heal ID and stale HP cannot manufacture a Block award")


func _test_borrowed_button_negative_cases() -> void:
	for scenario in ["unsewn", "wrong_wearer", "self", "full_hp", "downed", "torn", "invalid"]:
		var wearer := "seamstress" if scenario == "self" else (
			"tinker" if scenario == "wrong_wearer" else "warden")
		var fixture := _button_fixture(wearer, scenario != "unsewn")
		if fixture.is_empty():
			return
		var party: CombatParty = fixture.party
		var target := 2 if scenario == "self" else 1
		var service := _button_service(fixture)
		if scenario == "torn":
			var start: Array = fixture.torn.read_state().heroes
			var end: Array = start.duplicate(true)
			end[0].hp = 0
			_check(fixture.torn.observe_battle_end("button_tear", start, end).get("ok") == true,
				"torn COAT wearer has genuine committed run tear")
			var original: Dictionary = fixture.wardrobe.get_snapshot()
			_check(fixture.wardrobe.refresh_run_context(fixture.torn.read_state().heroes,
				original.owned, original.scraps, original.gold, original.cards, original),
				"wardrobe refreshed to authentic torn ledger")
			var next_defs := []
			for hero: Dictionary in fixture.torn.read_state().heroes:
				next_defs.append({"id": hero.id, "max_hp": hero.max_hp})
			party = CombatParty.new(next_defs)
			_check(party.is_valid(), "fresh party uses torn maximum HP")
			service = _button_service(fixture)
		if scenario == "downed":
			_check(party.apply_damage(1, 9999) and party.is_downed(1),
				"downed patch wearer is truly at zero HP")
		elif scenario != "full_hp":
			_check(party.apply_damage(target, 10), scenario + ": recipient wounded")
		if scenario == "invalid":
			var invalid_deck := _deck(["seamstress_darning", "seamstress_field_mend"])
			_rejected(invalid_deck, party, "seamstress_darning", 0,
				"COAT bad single target atomic rejection", service)
			_rejected(invalid_deck, party, "seamstress_field_mend", 1,
				"COAT bad party_all target atomic rejection", service)
			_check(invalid_deck.try_spend_energy(3), "COAT energy exhausted")
			_rejected(invalid_deck, party, "seamstress_darning", 1,
				"COAT insufficient energy atomic rejection", service)
			_check(service._borrowed_button.read_state().receipts.is_empty(),
				"failed actions generate no COAT receipts")
			continue
		if scenario == "downed":
			# A legal Field Mend excludes the downed COAT wearer.
			_check(party.apply_damage(3, 10), "living other recipient wounded")
			_button_play(_deck(["seamstress_field_mend"]), party, service,
				"seamstress_field_mend", 0, 1, false, "downed wearer stays unawarded")
		else:
			_button_play(_deck(["seamstress_thimble_tea"]), party, service,
				"seamstress_thimble_tea", target, 1, false,
				scenario + ": legal heal never qualifies")
		_check(service._borrowed_button.read_state().awards == 0,
			scenario + ": no Borrowed Button grant")
	# An invalid explicit authority bind poisons otherwise available cards.
	var failed := _button_fixture()
	var failed_service := _button_service(failed)
	_check(not failed_service.bind_patch_wardrobe(null, failed.torn)
		and not failed_service.is_patch_binding_valid(), "explicit null bind fails closed")
	var failed_party: CombatParty = failed.party
	_check(failed_party.apply_damage(1, 8), "failed-binding recipient wounded")
	_rejected(_deck(["seamstress_thimble_tea"]), failed_party,
		"seamstress_thimble_tea", 1, "failed binding refuses card", failed_service)
	# Drift in a previously valid ledger similarly refuses the entire cast.
	var drift := _button_fixture()
	var drift_service := _button_service(drift)
	var drift_party: CombatParty = drift.party
	_check(drift_party.apply_damage(1, 8), "stale-binding recipient wounded")
	drift.wardrobe._gold += 1
	_rejected(_deck(["seamstress_darning"]), drift_party,
		"seamstress_darning", 1, "stale wardrobe refuses card", drift_service)


func _sequence(seed_value: int) -> Array:
	var party := _party()
	_wound_all(party)
	var deck := _deck(["seamstress_darning", "seamstress_thimble_tea",
		"seamstress_field_mend", "filler-a", "filler-b"], seed_value)
	var trace: Array = [_snapshot(deck, party)]
	_check(deck.hand.has("seamstress_darning") and deck.hand.has("seamstress_thimble_tea")
		and deck.hand.has("seamstress_field_mend"), "replay draws all three actual cards")
	_played(deck, party, "seamstress_darning", 1, "replay Darning")
	trace.append(_snapshot(deck, party))
	_played(deck, party, "seamstress_thimble_tea", 3, "replay Tea")
	trace.append(_snapshot(deck, party))
	_played(deck, party, "seamstress_field_mend", 0, "replay Field")
	trace.append(_snapshot(deck, party))
	_check(deck.energy == 0 and deck.discard_pile.size() == 3,
		"replay uses full three-energy budget and discards three genuine copies")
	_check(deck.end_turn() and party.start_player_turn() and deck.start_turn(),
		"real turn boundary discards hand, clears Block and refills via seeded RNG")
	trace.append(_snapshot(deck, party))
	_check(party.get_hero(1)["block"] == 0 and party.get_hero(3)["block"] == 0,
		"next player turn resets accumulated Block")
	return trace


func _test_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var first: Array = _sequence(seed_value)
		var second: Array = _sequence(seed_value)
		_check(first.size() == 5 and second.size() == 5,
			"both runs record real initial, three plays and next-turn snapshots")
		_check(first == second,
			"same seeded run replays hand, energy, every hero, discard, draw and RNG")
