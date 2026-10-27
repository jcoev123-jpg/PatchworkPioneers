extends SceneTree
## Peddler v3-3: one authentic 3+1 seeded stock (one priced card per party
## hero plus one priced patch), one buy-or-Leave decision, authored quotes and
## a detached one-time receipt around the existing stock sampler and purchase
## ledger. Drives the real initial_offers.json and two identically seeded RNGs.

const PARTY := ["warden", "seamstress", "tinker"]
const DECK := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
## An authentic three-distinct-hero party that includes the Yarn Ranger, and
## the shipped Yarn Ranger Snare Net quote this task stocks.
const YARN_PARTY := ["scarecrow", "yarn_ranger", "button_golem"]
const SNARE_ID := "yarn_ranger_snare_net"
const SNARE_PRICE := 65
const SEED := 2611790

## The four already-implemented look-driven common bases this task stocks at the
## Peddler, with the rules copied from their own pool catalogs
## (lantern_monk/scarecrow/yarn_ranger/button_golem _pool_cards.gd) and the
## established 50-gold common-card candidate quote.
const LOOK_DRIVEN_STOCK_SPECS := {
	"lantern_monk_lantern_glow": {
		"owner": "lantern_monk", "price": 50, "cost": 1, "target": "party_all",
		"from": [1, 2, 3], "to": [],
		"effects": {"heal_all": 2, "cleanse_one_debuff_each_ally": 1},
		"plus_effects": {"heal_all": 3, "cleanse_one_debuff_each_ally": 1},
	},
	"scarecrow_crow_peck": {
		"owner": "scarecrow", "price": 50, "cost": 1, "target": "enemy_back",
		"from": [1, 2, 3], "to": [1, 2, 3],
		"effects": {"damage": 4, "ignore_block": true},
		"plus_effects": {"damage": 6, "ignore_block": true},
	},
	"yarn_ranger_knit_shield": {
		"owner": "yarn_ranger", "price": 50, "cost": 1, "target": "ally_single",
		"from": [1, 2, 3], "to": [],
		"effects": {"block": 6, "draw": 1}, "plus_effects": {"block": 8, "draw": 1},
	},
	"button_golem_button_roll": {
		"owner": "button_golem", "price": 50, "cost": 1, "target": "ally_single",
		"from": [1, 2, 3], "to": [],
		"effects": {"swap_with_target_ally": true, "block": 5},
		"plus_effects": {"swap_with_target_ally": true, "block": 8},
	},
}

## One authentic three-distinct-hero party per new card, each including that
## card's owner, so the seeded witness proves a genuine mixed-party 3+1 stock.
const LOOK_DRIVEN_WITNESS_PARTIES := {
	"lantern_monk_lantern_glow": ["lantern_monk", "scarecrow", "button_golem"],
	"scarecrow_crow_peck": ["scarecrow", "yarn_ranger", "button_golem"],
	"yarn_ranger_knit_shield": ["lantern_monk", "yarn_ranger", "rag_duelist"],
	"button_golem_button_roll": ["rag_duelist", "button_golem", "lantern_monk"],
}
## Bounded per-card seed sweep for the witness: every seat draws between two and
## three candidates, so a shipped offer appears within a few dozen seeds.
const LOOK_DRIVEN_SWEEP := 160

var failures: Array[String] = []
var checks: int = 0
var authored_cards: Array = []
var authored_patches: Array = []
var card_authored: Dictionary = {}
var patch_prices: Dictionary = {}


func _initialize() -> void:
	seed(918273)
	var expected_global := randi()
	seed(918273)
	var source := FileAccess.get_file_as_string("res://data/shop/initial_offers.json")
	var parsed: Variant = JSON.parse_string(source)
	_check(not source.is_empty() and parsed is Dictionary,
		"loads the actual authored shop candidate list")
	if not parsed is Dictionary:
		_finish()
		return
	var authored: Dictionary = parsed
	if not (authored.get("cards") is Array) or not (authored.get("trinkets") is Array):
		_check(false, "authored list exposes card and patch candidates")
		_finish()
		return
	authored_cards = authored["cards"]
	authored_patches = authored["trinkets"]
	_check(not authored_cards.is_empty() and not authored_patches.is_empty(),
		"authored list has priced cards and patches")
	for entry in authored_cards:
		card_authored[entry["id"]] = {"owner": entry["owner"], "price": entry["price"]}
	for entry in authored_patches:
		patch_prices[entry["id"]] = entry["price"]
	_test_open_stock()
	_test_buy_card_and_patch()
	_test_leave()
	_test_rejections_do_not_consume_leave()
	_test_invalid_construction()
	_test_replay_and_rng()
	_test_atomic_sewing()
	_test_yarn_ranger_snare_purchase()
	_test_look_driven_peddler_stock()
	_check(randi() == expected_global,
		"all stock sampling, decisions, refusals and Leave consume no global RNG")
	_finish()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("run_peddler_visit_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_peddler_visit_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_atomic_sewing() -> void:
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in raw:
		hero.max_hp = int(hero.max_hp)
	var heroes := CombatParty.new(raw).get_heroes()
	var definitions := RunAuthoredPatchDefinitions.load_definitions()
	var stock := _sampled_stock(_rng(SEED))
	var acquired: String = stock.patches[0].id
	var slot := ""
	for definition in definitions:
		if definition.id == acquired:
			slot = definition.slot
	var displaced := ""
	for definition in definitions:
		if definition.id != acquired and definition.slot == slot:
			displaced = definition.id
			break
	_check(not slot.is_empty() and not displaced.is_empty(), "real sampled patch has a distinct authored occupied-slot fixture")
	if slot.is_empty() or displaced.is_empty():
		return
	for replacement in [false, true]:
		var owned := [displaced] if replacement else []
		var visit := RunPeddlerVisit.new("peddler_atomic", PARTY, DECK, owned, 500, stock)
		var wardrobe := RunPatchWardrobe.new(heroes, owned, definitions, 2, 500, DECK, SEED, true)
		if replacement:
			_check(wardrobe.sew(displaced, "warden", slot, "prior", wardrobe.get_snapshot()).ok,
				"occupied-slot fixture is sewn through public authority")
		var bound := visit.read_state()
		var w := wardrobe.get_snapshot()
		for proposal in [
			["foreign", slot, "paid"], ["warden", "UNKNOWN", "paid"],
			["warden", "ARM" if slot != "ARM" else "HEAD", "paid"],
			["warden", slot, ""], ["warden", slot, "prior"] if replacement else ["foreign", slot, "other"]]:
			var result := RunShopPatchSewing.purchase_peddler_and_sew(visit, wardrobe, bound.node_id,
				acquired, proposal[0], proposal[1], proposal[2], bound, w)
			_check(not result.ok and visit.read_state() == bound and wardrobe.get_snapshot() == w,
				"invalid owner, slot or operation refuses both authorities before debit")
		var stale := w.duplicate(true)
		stale.gold -= 1
		_check(not RunShopPatchSewing.purchase_peddler_and_sew(visit, wardrobe, bound.node_id,
			acquired, "warden", slot, "paid", bound, stale).ok
			and visit.read_state() == bound and wardrobe.get_snapshot() == w, "stale complete wardrobe snapshot refuses atomically")
		wardrobe._worn.seamstress[slot] = acquired
		var malformed := wardrobe.get_snapshot()
		_check(not RunShopPatchSewing.purchase_peddler_and_sew(visit, wardrobe, bound.node_id,
			acquired, "warden", slot, "paid", bound, malformed).ok
			and visit.read_state() == bound and wardrobe.get_snapshot() == malformed, "unowned patch on another wearer refuses before payment")
		wardrobe._worn.seamstress[slot] = ""
		_check(wardrobe.get_snapshot() == w, "negative fixtures restore authentic wardrobe")
		var paid := RunShopPatchSewing.purchase_peddler_and_sew(visit, wardrobe, bound.node_id,
			acquired, "warden", slot, "paid", bound, w)
		_check(paid.ok and visit.is_consumed(), "one preflighted patch transaction consumes service")
		var after := wardrobe.get_snapshot()
		var expected_owned: Array = [] if replacement else owned.duplicate()
		expected_owned.append(acquired)
		_check(after.owned == expected_owned and visit.read_state().state.trinkets == expected_owned
			and after.gold == 500 - int(stock.patches[0].price) and after.worn.warden[slot] == acquired
			and after.scraps == 2 + (1 if replacement else 0), "single ledger and wardrobe agree on exact debit and settled replacement")
		_check(paid.receipt.state == visit.read_state().state and paid.receipt.price == int(stock.patches[0].price)
			and paid.sew_receipt.displaced_id == (displaced if replacement else ""), "published receipt is exact settled service state")
		var consumed := visit.read_state()
		_check(not RunShopPatchSewing.purchase_peddler_and_sew(visit, wardrobe, bound.node_id,
			acquired, "warden", slot, "paid", bound, w).ok
			and not visit.settle_displaced_patch(displaced, acquired, consumed)
			and visit.read_state() == consumed and wardrobe.get_snapshot() == after, "paid sewing and settlement cannot replay")
	var abandoned := RunPeddlerVisit.new("abandoned", PARTY, DECK, [], 500, stock)
	var original := abandoned.read_state()
	abandoned.close()
	_check(abandoned.is_consumed() and not abandoned.choose_purchase(original.node_id, original.state,
		original.stock, "card", original.stock.cards[0].id).ok, "teardown retires open service generation")


func _sampled_stock(rng: RandomNumberGenerator) -> Dictionary:
	return RunShopStockOffers.generate_peddler_stock(rng, PARTY, authored_cards,
		authored_patches, [])


## AC2: a genuine seeded Peddler stock that offers the shipped Yarn Ranger
## Snare Net opens the real visit and debits exactly 65 gold once.
func _test_yarn_ranger_snare_purchase() -> void:
	var found_seed := -1
	var found: Dictionary = {}
	var found_state := 0
	for offset in range(128):
		var candidate_seed: int = SEED + 9000 + offset
		var rng := _rng(candidate_seed)
		var stock := RunShopStockOffers.generate_peddler_stock(rng, YARN_PARTY,
			authored_cards, authored_patches, [])
		if stock.get("ok") != true:
			continue
		var cards: Array = stock["cards"]
		if cards.size() != 3 or cards[1].get("owner") != "yarn_ranger" \
				or cards[1].get("id") != SNARE_ID:
			continue
		found_seed = candidate_seed
		found = stock
		found_state = rng.state
		break
	_check(found_seed >= 0,
		"bounded deterministic sweep samples a genuine Snare Net Peddler offer")
	if found_seed < 0:
		return
	var replay_rng := _rng(found_seed)
	var replay := RunShopStockOffers.generate_peddler_stock(replay_rng, YARN_PARTY,
		authored_cards, authored_patches, [])
	_check(replay == found and replay_rng.state == found_state,
		"the sampled Snare Net stock replays with identical four-draw state")
	var ranger_offers := 0
	for offer in found["cards"]:
		if offer.get("owner") == "yarn_ranger":
			ranger_offers += 1
	_check(ranger_offers == 1,
		"the sampled stock holds exactly one Yarn Ranger card")
	_check(card_authored.has(SNARE_ID)
		and card_authored[SNARE_ID]["owner"] == "yarn_ranger"
		and card_authored[SNARE_ID]["price"] == SNARE_PRICE,
		"the shipped Snare Net stock record is the authored Yarn Ranger 65-gold quote")

	var visit := RunPeddlerVisit.new("peddler_snare", YARN_PARTY, DECK, [], 500, found)
	_check(visit.is_open(), "the sampled Snare Net stock opens a real Peddler visit")
	if not visit.is_open():
		return
	var open := visit.read_state()
	var offer: Dictionary = open["stock"]["cards"][1]
	_check(offer.get("id") == SNARE_ID and offer.get("owner") == "yarn_ranger"
		and offer.get("price") == SNARE_PRICE and offer.get("sold") == false,
		"the open visit lists the unsold 65-gold Snare Net offer")
	var receipt := visit.choose_purchase("peddler_snare", open["state"], open["stock"],
		"card", SNARE_ID)
	_check(receipt.get("ok") == true and receipt.get("kind") == "card"
		and receipt.get("id") == SNARE_ID and receipt.get("price") == SNARE_PRICE,
		"Snare Net buys with the exact authored 65-gold receipt")
	_check(receipt.get("state", {}).get("gold") == 500 - SNARE_PRICE
		and receipt.get("state", {}).get("deck") == DECK + [SNARE_ID]
		and receipt.get("state", {}).get("trinkets").is_empty(),
		"Snare Net debits exactly 65 gold once and appends only that card")
	_check(visit.is_consumed() and not visit.is_open(),
		"the Snare Net purchase closes the one-decision visit")
	var after := visit.read_state()
	_check(after["state"]["gold"] == 500 - SNARE_PRICE,
		"the wallet holds exactly one 65-gold debit")
	_assert_refused(visit, open, "peddler_snare", "card", SNARE_ID,
		"Snare Net: stale pre-buy replay")
	_assert_refused(visit, after, "peddler_snare", "card", SNARE_ID,
		"Snare Net: exact post-buy replay")
	_check(visit.read_state() == after,
		"refused Snare Net replays cannot debit again")


## The authored pool catalog that owns each v3 hero, as separate instances of
## the same shipped catalogs the stock sampler validates against.
func _owner_catalogs() -> Dictionary:
	return {
		"lantern_monk": LanternMonkPoolCards.new(),
		"rag_duelist": RagDuelistPoolCards.new(),
		"scarecrow": ScarecrowPoolCards.new(),
		"yarn_ranger": YarnRangerPoolCards.new(),
		"button_golem": ButtonGolemPoolCards.new(),
	}


## AC1/AC2: the four proven look-driven base cards this task stocks. Each shipped
## record is checked by ID against the real initial_offers.json and its own pool
## catalog (never a catalog total or a full ordered list), then a bounded seeded
## sweep must reach it as its owner's ONE Peddler card offer beside two other
## party cards and one patch, and the real visit must buy it for exactly 50 gold
## once, append only that ID, keep the other offerings and supplied stock intact
## and still allow a free Leave on a different fresh visit.
func _test_look_driven_peddler_stock() -> void:
	var catalogs := _owner_catalogs()
	var starter := StarterCards.new()
	var authored_before := authored_cards.duplicate(true)
	var patches_before := authored_patches.duplicate(true)
	var deck_before := DECK.duplicate()

	# AC1: exactly one shipped record per new ID, each an authentic unupgraded
	# common base resolved in its own authored pool catalog.
	for card_id in LOOK_DRIVEN_STOCK_SPECS:
		var spec: Dictionary = LOOK_DRIVEN_STOCK_SPECS[card_id]
		var matches: Array = authored_cards.filter(
			func(entry): return entry is Dictionary and entry.get("id") == card_id)
		_check(matches.size() == 1,
			"shipped Peddler stock lists " + card_id + " exactly once")
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var quoted: float = float(record.get("price", -1.0))
		_check(record.get("owner") == spec["owner"] and quoted == float(spec["price"])
			and record.size() == 3,
			card_id + ": authored owner and the exact 50-gold quote, with no extra field")
		_check(not card_authored.has(card_id + "_plus"),
			card_id + ": the + upgrade is never priced stock")

		var catalog: Variant = catalogs.get(spec["owner"])
		if catalog == null:
			_check(false, card_id + ": owns an authored pool catalog")
			continue
		_check(catalog.has_card(card_id) and not starter.has_card(card_id)
			and catalog.get_base_ids().has(card_id),
			card_id + ": a genuine pool base in its own hero catalog, not a starter card")
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(definition.get("id") == card_id and definition.get("owner") == spec["owner"]
			and definition.get("cost") == spec["cost"]
			and definition.get("target_kind") == spec["target"]
			and definition.get("from_positions") == spec["from"]
			and definition.get("to_positions") == spec["to"]
			and definition.get("effects") == spec["effects"]
			and definition.get("rarity") == "common"
			and definition.get("reward_eligible") == true
			and definition.get("starting_copies") == 0
			and not definition.has("upgrade_of")
			and definition.get("upgrade_id") == card_id + "_plus",
			card_id + ": authentic unupgraded common base with its authored rules")
		_check(definition.get("illustration_path")
			== "res://assets/paper/cards/" + card_id + ".png",
			card_id + ": keeps its pre-existing card art path")
		var plus: Dictionary = catalog.get_definition(card_id + "_plus")
		_check(plus.get("id") == card_id + "_plus" and plus.get("owner") == spec["owner"]
			and plus.get("effects") == spec["plus_effects"]
			and plus.get("upgrade_of") == card_id
			and plus.get("reward_eligible") == false
			and plus.get("starting_copies") == 0,
			card_id + ": the authored + stays Rest-only and unpriced")

	# AC1: every pre-existing candidate this task must not disturb survives.
	var listed_ids := {}
	for entry in authored_cards:
		listed_ids[entry["id"]] = int(listed_ids.get(entry["id"], 0)) + 1
	_check(listed_ids.size() == authored_cards.size(),
		"the shipped card catalog lists every ID at most once")
	for required in ["lantern_monk_moth_lure", "scarecrow_re_stuff",
			"yarn_ranger_unspool", "yarn_ranger_snare_net", "button_golem_pop_button"]:
		_check(card_authored.has(required) and listed_ids.get(required) == 1,
			"the earlier authored card survives exactly once: " + required)
	_check(card_authored.get(SNARE_ID, {}).get("price") == SNARE_PRICE,
		"yarn_ranger_snare_net keeps its authored 65-gold quote")
	for patch_id in ["relay_bobbin", "hearth_lining"]:
		_check(patch_prices.has(patch_id) and patch_prices[patch_id] == 100,
			"the P8 patch candidate survives as authored: " + patch_id)

	# AC2: a bounded seeded sweep per new card, then the real paid visit.
	var card_index := 0
	for card_id in LOOK_DRIVEN_STOCK_SPECS:
		var spec: Dictionary = LOOK_DRIVEN_STOCK_SPECS[card_id]
		var party: Array = LOOK_DRIVEN_WITNESS_PARTIES[card_id]
		var owner_seat: int = party.find(spec["owner"])
		_check(party.size() == 3 and owner_seat >= 0
			and party.find(party[0], 1) == -1 and party.find(party[1], 2) == -1,
			card_id + ": witness party is three distinct heroes including the owner")
		var seed_base: int = SEED + 40000 + card_index * 1000
		card_index += 1

		var witness_seed := -1
		var witness: Dictionary = {}
		var witness_state := 0
		for offset in range(LOOK_DRIVEN_SWEEP):
			var candidate_seed: int = seed_base + offset
			var rng := _rng(candidate_seed)
			var stock := RunShopStockOffers.generate_peddler_stock(rng, party,
				authored_cards, authored_patches, [])
			if stock.get("ok") != true:
				continue
			var sampled: Array = stock["cards"]
			if sampled.size() != 3 or sampled[owner_seat].get("owner") != spec["owner"] \
					or sampled[owner_seat].get("id") != card_id:
				continue
			witness_seed = candidate_seed
			witness = stock
			witness_state = rng.state
			break
		_check(witness_seed >= 0,
			card_id + ": bounded deterministic sweep samples it as its owner's Peddler offer")
		if witness_seed < 0:
			continue

		var replay_rng := _rng(witness_seed)
		var replay := RunShopStockOffers.generate_peddler_stock(replay_rng, party,
			authored_cards, authored_patches, [])
		_check(replay == witness and replay_rng.state == witness_state,
			card_id + ": the witnessed stock replays with identical four-draw state")

		var witness_before := witness.duplicate(true)
		var offers: Array = witness["cards"]
		var offered_ids := {}
		for position in range(offers.size()):
			var offer: Dictionary = offers[position]
			offered_ids[offer.get("id")] = true
			_check(offer.get("owner") == party[position],
				card_id + ": offer " + str(position) + " fills its own party seat")
			_check(card_authored.has(offer.get("id"))
				and card_authored[offer.get("id")]["owner"] == offer.get("owner")
				and card_authored[offer.get("id")]["price"] == offer.get("price"),
				card_id + ": companion offer " + str(offer.get("id"))
					+ " is an authored party card at its quote")
		_check(offered_ids.size() == 3,
			card_id + ": the three card offers are distinct")
		_check(int(offers[owner_seat].get("price")) == int(spec["price"])
			and offers[owner_seat].get("owner") == spec["owner"],
			card_id + ": the owner's seat carries it at exactly 50 gold")
		var patches: Array = witness["patches"]
		_check(patches.size() == 1 and patch_prices.has(patches[0].get("id"))
			and patches[0].get("price") == patch_prices[patches[0].get("id")],
			card_id + ": one authored patch is offered beside the three cards")

		var node: String = "peddler_" + card_id
		var visit := RunPeddlerVisit.new(node, party, DECK, [], 500, witness)
		_check(visit.is_open(),
			card_id + ": the witnessed stock opens a real Peddler visit")
		if not visit.is_open():
			continue
		var open := visit.read_state()
		var listing: Dictionary = open["stock"]["cards"][owner_seat]
		_check(listing.get("id") == card_id and listing.get("price") == spec["price"]
			and listing.get("sold") == false,
			card_id + ": the open visit lists it unsold at the authored 50-gold quote")
		var receipt := visit.choose_purchase(node, open["state"], open["stock"],
			"card", card_id)
		_check(receipt.get("ok") == true and receipt.get("kind") == "card"
			and receipt.get("id") == card_id and receipt.get("price") == spec["price"],
			card_id + ": buys with the exact authored 50-gold receipt")
		_check(receipt.get("state", {}).get("gold") == 500 - int(spec["price"])
			and receipt.get("state", {}).get("deck") == DECK + [card_id]
			and receipt.get("state", {}).get("trinkets").is_empty(),
			card_id + ": debits exactly 50 gold once and appends only that ID")
		var after_stock: Dictionary = receipt.get("stock", {})
		var others_unsold := true
		for position in range(after_stock.get("cards", []).size()):
			if position != owner_seat and after_stock["cards"][position]["sold"]:
				others_unsold = false
		_check(after_stock.get("cards", []).size() == 3
			and after_stock["cards"][owner_seat]["sold"] == true and others_unsold
			and after_stock.get("trinkets", [{}])[0].get("sold") == false,
			card_id + ": only that card is sold; the other three offers are unchanged")
		_check(visit.is_consumed() and not visit.is_open(),
			card_id + ": the paid buy closes the one-decision visit")
		_check(witness == witness_before,
			card_id + ": the visit never mutates the supplied seeded stock")

		# Negative coverage stays: neither a stale nor a repeat buy can debit.
		_assert_refused(visit, open, node, "card", card_id,
			card_id + ": stale pre-buy replay")
		var after := visit.read_state()
		_assert_refused(visit, after, node, "card", card_id,
			card_id + ": second buy with the current snapshot")
		_assert_leave_refused(visit, after, node, card_id + ": Leave after the buy")
		_check(visit.read_state() == after,
			card_id + ": refused replays cannot debit again")

		var leaving := RunPeddlerVisit.new(node + "_leave", party, DECK, [], 500,
			witness)
		var leave_open := leaving.read_state()
		var left := leaving.leave(node + "_leave", leave_open["state"],
			leave_open["stock"])
		_check(left.get("ok") == true and left.get("decision") == "leave"
			and left.get("state", {}).get("gold") == 500
			and left.get("state", {}).get("deck") == DECK
			and left.get("state", {}).get("trinkets").is_empty(),
			card_id + ": a different fresh visit from the same stock Leaves free")

	_check(DECK == deck_before, "no witness visit mutates the supplied deck")
	_check(authored_cards == authored_before and authored_patches == patches_before,
		"the shipped candidate arrays survive every witness visit unchanged")


func _state(gold: int, deck: Variant = null, trinkets: Variant = null) -> Dictionary:
	var use_deck: Array = DECK.duplicate() if deck == null else deck.duplicate()
	var use_trinkets: Array = [] if trinkets == null else trinkets.duplicate()
	return {
		"party_ids": PARTY.duplicate(),
		"deck": use_deck,
		"trinkets": use_trinkets,
		"gold": gold,
	}


## The purchase ledger's detached stock projection: authored prices intact and
## every listing still unsold until it is bought.
func _ledger_stock(stock: Dictionary) -> Dictionary:
	var cards: Array = []
	for offer in stock["cards"]:
		cards.append({"id": offer["id"], "owner": offer["owner"],
			"price": offer["price"], "sold": false})
	var trinkets: Array = []
	for offer in stock["patches"]:
		trinkets.append({"id": offer["id"], "price": offer["price"], "sold": false})
	return {"cards": cards, "trinkets": trinkets}


func _refused_receipt() -> Dictionary:
	return {"ok": false, "node_id": "", "decision": "", "state": {}, "stock": {}}


func _invalid_state() -> Dictionary:
	return {"ok": false, "node_id": "", "status": "invalid", "state": {}, "stock": {}}


func _snapshot(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


func _replaced(entry: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := entry.duplicate(true)
	copy[key] = value
	return copy


func _assert_refused(visit: RunPeddlerVisit, snapshot: Dictionary, node: Variant,
		kind: Variant, id: Variant, label: String) -> void:
	var current_before := visit.read_state()
	var result := visit.choose_purchase(node, snapshot["state"], snapshot["stock"],
		kind, id)
	_check(result == _refused_receipt(), label + ": uniform refusal, no forged receipt")
	_check(visit.read_state() == current_before,
		label + ": refusal changes nothing in the visit")


func _assert_leave_refused(visit: RunPeddlerVisit, snapshot: Dictionary,
		node: Variant, label: String) -> void:
	var current_before := visit.read_state()
	var result := visit.leave(node, snapshot["state"], snapshot["stock"])
	_check(result == _refused_receipt(), label + ": uniform refusal, no forged receipt")
	_check(visit.read_state() == current_before,
		label + ": refused Leave changes nothing in the visit")


func _test_open_stock() -> void:
	var rng := _rng(SEED)
	var stock := _sampled_stock(rng)
	var replay_rng := _rng(SEED)
	var replay := _sampled_stock(replay_rng)
	_check(stock.get("ok") == true, "authentic seeded Peddler stock generates")
	_check(stock == replay and rng.state == replay_rng.state,
		"two identically seeded generators agree on stock and draw state")
	if stock.get("ok") != true:
		return
	var cards: Array = stock["cards"]
	var patches: Array = stock["patches"]
	_check(cards.size() == 3 and patches.size() == 1,
		"Peddler exposes exactly three card choices and one patch")
	var owners: Array = []
	for offer in cards:
		var card_id: String = offer["id"]
		owners.append(offer["owner"])
		_check(card_authored.has(card_id)
			and card_authored[card_id]["owner"] == offer["owner"],
			"offer " + card_id + " keeps its authored owner")
		_check(card_authored.has(card_id)
			and card_authored[card_id]["price"] == offer["price"],
			"offer " + card_id + " keeps its authored price")
		_check(offer["price"] > 0, "offer " + card_id + " has a genuine positive price")
	_check(owners == PARTY, "exactly one card per party hero, in party order")
	_check(owners[0] != owners[1] and owners[1] != owners[2]
		and owners[0] != owners[2], "the three owners are different heroes")
	var patch: Dictionary = patches[0]
	_check(patch_prices.has(patch["id"]) and patch_prices[patch["id"]] == patch["price"],
		"patch " + str(patch["id"]) + " keeps its authored price")
	_check(patch["price"] > 0, "patch has a genuine positive price")

	var visit := RunPeddlerVisit.new("peddler_1", PARTY, DECK, [], 500, stock)
	_check(visit.is_valid() and visit.is_open() and not visit.is_consumed(),
		"authentic Peddler stock opens a visit")
	var expected := {
		"ok": true,
		"node_id": "peddler_1",
		"status": "open",
		"state": _state(500),
		"stock": _ledger_stock(stock),
	}
	_check(visit.read_state() == expected,
		"open visit exposes the exact three card, one patch and Leave ledger")

	# The supplied stock and every read projection are detached copies.
	stock["cards"][0]["price"] = 0
	stock["patches"][0]["id"] = "forged_patch"
	_check(visit.read_state() == expected,
		"mutating supplied stock after opening cannot alter the visit")
	var read := visit.read_state()
	read["state"]["deck"].clear()
	read["state"]["trinkets"].append("leaked_patch")
	read["state"]["gold"] = 99999
	read["stock"]["cards"][0]["price"] = 1
	read["stock"]["cards"][1]["sold"] = true
	read["node_id"] = "other"
	read["status"] = "left"
	_check(visit.read_state() == expected,
		"mutating a read projection cannot alter the open visit")
	_check(visit.is_open(), "detachment checks leave the visit open for one decision")


func _test_buy_card_and_patch() -> void:
	var stock := _sampled_stock(_rng(SEED + 1))
	_check(stock.get("ok") == true and stock["cards"].size() == 3,
		"buy fixture has authentic Peddler stock")
	if stock.get("ok") != true:
		return
	var cards: Array = stock["cards"]
	var patch: Dictionary = stock["patches"][0]
	var base_stock := _ledger_stock(stock)

	# Each of the three offered cards is independently buyable for its quote.
	for offer in cards:
		var card: Dictionary = offer
		var visit := RunPeddlerVisit.new("peddler_card", PARTY, DECK, [], 500, stock)
		var before := visit.read_state()
		_check(before.get("status") == "open", "card " + card["id"] + ": fresh open visit")
		var receipt := visit.choose_purchase("peddler_card", before["state"],
			before["stock"], "card", card["id"])
		var expected_state := _state(500 - int(card["price"]), DECK + [card["id"]])
		var expected_stock: Dictionary = base_stock.duplicate(true)
		for listing in expected_stock["cards"]:
			if listing["id"] == card["id"]:
				listing["sold"] = true
		var expected_receipt := {
			"ok": true,
			"node_id": "peddler_card",
			"decision": "buy",
			"kind": "card",
			"id": card["id"],
			"price": card["price"],
			"state": expected_state,
			"stock": expected_stock,
		}
		_check(receipt == expected_receipt,
			"card " + card["id"] + ": exact one-use buy receipt with authored quote")
		_check(visit.read_state() == {"ok": true, "node_id": "peddler_card",
			"status": "used", "state": expected_state, "stock": expected_stock},
			"card " + card["id"] + ": wallet debited once and only that copy added")
		_check(visit.is_consumed() and not visit.is_open(),
			"card " + card["id"] + ": buy closes the single decision")
		# Receipt copies never alias the visit.
		receipt["state"]["deck"].clear()
		receipt["state"]["gold"] = 99999
		receipt["stock"]["cards"][0]["price"] = 0
		receipt["stock"]["cards"][0]["sold"] = false
		_check(visit.read_state()["state"] == expected_state
			and visit.read_state()["stock"] == expected_stock,
			"card " + card["id"] + ": mutating the receipt cannot alter the visit")
		_assert_refused(visit, before, "peddler_card", "card", cards[0]["id"],
			"card " + card["id"] + ": replay with the stale pre-buy snapshot")
		var after := visit.read_state()
		_assert_refused(visit, after, "peddler_card", "card", cards[0]["id"],
			"card " + card["id"] + ": second buy with the current snapshot")
		_assert_refused(visit, after, "peddler_card", "trinket", patch["id"],
			"card " + card["id"] + ": patch after a card buy")
		_assert_leave_refused(visit, after, "peddler_card",
			"card " + card["id"] + ": Leave after a buy")

	# Paying the one patch appends only the owned patch at its quote.
	var visit := RunPeddlerVisit.new("peddler_patch", PARTY, DECK, [], 500, stock)
	var before := visit.read_state()
	var receipt := visit.choose_purchase("peddler_patch", before["state"],
		before["stock"], "trinket", patch["id"])
	var expected_state := _state(500 - int(patch["price"]), DECK, [patch["id"]])
	var expected_stock: Dictionary = base_stock.duplicate(true)
	expected_stock["trinkets"][0]["sold"] = true
	_check(receipt == {
		"ok": true,
		"node_id": "peddler_patch",
		"decision": "buy",
		"kind": "trinket",
		"id": patch["id"],
		"price": patch["price"],
		"state": expected_state,
		"stock": expected_stock,
	}, "patch: exact one-use buy receipt with authored quote")
	_check(visit.read_state() == {"ok": true, "node_id": "peddler_patch",
		"status": "used", "state": expected_state, "stock": expected_stock},
		"patch: wallet debited once, patch ledger gained it and deck untouched")
	_check(visit.read_state()["state"]["deck"] == DECK,
		"patch: no card is added to the deck")
	receipt["state"]["trinkets"].clear()
	receipt["state"]["gold"] = 0
	receipt["stock"]["trinkets"][0]["sold"] = false
	_check(visit.read_state()["state"] == expected_state
		and visit.read_state()["stock"] == expected_stock,
		"patch: mutating the receipt cannot alter the visit")
	var after := visit.read_state()
	_assert_refused(visit, before, "peddler_patch", "trinket", patch["id"],
		"patch: replay with the stale pre-buy snapshot")
	_assert_refused(visit, after, "peddler_patch", "card", cards[1]["id"],
		"patch: card after a patch buy")
	_assert_leave_refused(visit, after, "peddler_patch", "patch: Leave after a buy")


func _test_leave() -> void:
	var stock := _sampled_stock(_rng(SEED + 2))
	_check(stock.get("ok") == true, "Leave fixture has authentic Peddler stock")
	if stock.get("ok") != true:
		return
	var visit := RunPeddlerVisit.new("peddler_leave", PARTY, DECK, [], 500, stock)
	var before := visit.read_state()
	var receipt := visit.leave("peddler_leave", before["state"], before["stock"])
	_check(receipt == {
		"ok": true,
		"node_id": "peddler_leave",
		"decision": "leave",
		"state": _state(500),
		"stock": _ledger_stock(stock),
	}, "Leave returns an exact no-spend receipt")
	_check(visit.read_state() == {"ok": true, "node_id": "peddler_leave",
		"status": "left", "state": _state(500), "stock": _ledger_stock(stock)},
		"Leave closes the visit with unchanged wallet, deck and patches")
	_check(receipt["state"]["gold"] == 500 and receipt["state"]["deck"] == DECK
		and receipt["state"]["trinkets"].is_empty(), "Leave spends nothing")
	_assert_leave_refused(visit, visit.read_state(), "peddler_leave",
		"duplicate Leave")
	_assert_refused(visit, visit.read_state(), "peddler_leave", "card",
		stock["cards"][0]["id"], "buy after Leave")
	receipt["state"]["gold"] = 0
	receipt["state"]["deck"].clear()
	receipt["stock"]["cards"][0]["sold"] = true
	_check(visit.read_state()["state"] == _state(500)
		and visit.read_state()["stock"] == _ledger_stock(stock),
		"mutating the Leave receipt cannot alter the visit")


func _test_rejections_do_not_consume_leave() -> void:
	var stock := _sampled_stock(_rng(SEED + 3))
	_check(stock.get("ok") == true, "negative fixture starts from authentic stock")
	if stock.get("ok") != true:
		return
	var visit := RunPeddlerVisit.new("peddler_refuse", PARTY, DECK, [], 500, stock)
	var snapshot := visit.read_state()
	var card_id: String = stock["cards"][0]["id"]
	var patch_id: String = stock["patches"][0]["id"]

	# Wrong or malformed node IDs.
	for wrong_node in ["other", "", " ", " peddler_refuse", "peddler_refuse ",
			"PEDDLER_REFUSE", 42, null, [], {}]:
		var label := "node " + str(wrong_node)
		_assert_refused(visit, snapshot, wrong_node, "card", card_id, label)
		_assert_refused(visit, snapshot, wrong_node, "trinket", patch_id,
			label + " patch")
		_assert_leave_refused(visit, snapshot, wrong_node, label + " Leave")
	_check(visit.is_open(), "wrong-node refusals leave the visit open")

	# Stale or forged state snapshots.
	var bad_states: Array = []
	var richer: Dictionary = snapshot["state"].duplicate(true)
	richer["gold"] = 501
	bad_states.append(richer)
	var poorer: Dictionary = snapshot["state"].duplicate(true)
	poorer["gold"] = 499
	bad_states.append(poorer)
	var more_cards: Dictionary = snapshot["state"].duplicate(true)
	more_cards["deck"].append("warden_strike")
	bad_states.append(more_cards)
	var fewer_cards: Dictionary = snapshot["state"].duplicate(true)
	fewer_cards["deck"].pop_back()
	bad_states.append(fewer_cards)
	var owned_patch: Dictionary = snapshot["state"].duplicate(true)
	owned_patch["trinkets"] = [patch_id]
	bad_states.append(owned_patch)
	var reordered_party: Dictionary = snapshot["state"].duplicate(true)
	reordered_party["party_ids"].reverse()
	bad_states.append(reordered_party)
	var missing_gold: Dictionary = snapshot["state"].duplicate(true)
	missing_gold.erase("gold")
	bad_states.append(missing_gold)
	var extra_field: Dictionary = snapshot["state"].duplicate(true)
	extra_field["free_cards"] = 3
	bad_states.append(extra_field)
	for bad in [[], null, "state", 7, true]:
		bad_states.append(bad)

	# Stale or forged stock snapshots.
	var bad_stocks: Array = []
	var dearer_card: Dictionary = snapshot["stock"].duplicate(true)
	dearer_card["cards"][0]["price"] += 1
	bad_stocks.append(dearer_card)
	var sold_card: Dictionary = snapshot["stock"].duplicate(true)
	sold_card["cards"][1]["sold"] = true
	bad_stocks.append(sold_card)
	var reordered_cards: Dictionary = snapshot["stock"].duplicate(true)
	reordered_cards["cards"].reverse()
	bad_stocks.append(reordered_cards)
	var forged_patch: Dictionary = snapshot["stock"].duplicate(true)
	forged_patch["trinkets"][0]["price"] += 1
	bad_stocks.append(forged_patch)
	var sold_patch: Dictionary = snapshot["stock"].duplicate(true)
	sold_patch["trinkets"][0]["sold"] = true
	bad_stocks.append(sold_patch)
	var unknown_patch: Dictionary = snapshot["stock"].duplicate(true)
	unknown_patch["trinkets"][0]["id"] = "unknown_patch"
	bad_stocks.append(unknown_patch)
	var no_cards: Dictionary = snapshot["stock"].duplicate(true)
	no_cards.erase("cards")
	bad_stocks.append(no_cards)
	var no_trinkets: Dictionary = snapshot["stock"].duplicate(true)
	no_trinkets.erase("trinkets")
	bad_stocks.append(no_trinkets)
	for bad in [[], null, "stock", 7, true]:
		bad_stocks.append(bad)

	for i in range(bad_states.size()):
		var state_only := {"state": bad_states[i], "stock": snapshot["stock"]}
		_assert_refused(visit, state_only, "peddler_refuse", "card", card_id,
			"altered state snapshot %d" % i)
		_assert_refused(visit, state_only, "peddler_refuse", "trinket", patch_id,
			"altered state snapshot %d patch" % i)
		_assert_leave_refused(visit, state_only, "peddler_refuse",
			"altered state snapshot %d Leave" % i)
	for i in range(bad_stocks.size()):
		var stock_only := {"state": snapshot["state"], "stock": bad_stocks[i]}
		_assert_refused(visit, stock_only, "peddler_refuse", "card", card_id,
			"altered stock snapshot %d" % i)
		_assert_refused(visit, stock_only, "peddler_refuse", "trinket", patch_id,
			"altered stock snapshot %d patch" % i)
		_assert_leave_refused(visit, stock_only, "peddler_refuse",
			"altered stock snapshot %d Leave" % i)
	_check(visit.is_open(), "stale/forged snapshot refusals leave the visit open")

	# Unoffered, unknown, sold and malformed choices.
	var offered: Array = []
	for offer in stock["cards"]:
		offered.append(offer["id"])
	var unoffered := ""
	for known_id in card_authored:
		if not offered.has(known_id):
			unoffered = known_id
			break
	_check(not unoffered.is_empty(), "a real authored but unoffered card exists")
	for action in [["card", "unknown_card"], ["card", unoffered],
			["card", patch_id], ["trinket", "unknown_patch"],
			["trinket", card_id], ["patch", patch_id], ["card", ""],
			["trinket", "  "], ["card", 42], ["trinket", null],
			["", card_id], [null, card_id], [42, card_id]]:
		_assert_refused(visit, snapshot, "peddler_refuse", action[0], action[1],
			"unavailable/malformed choice " + str(action))

	var sold := RunPeddlerVisit.new("peddler_sold", PARTY, DECK, [patch_id], 500, stock)
	var sold_open := sold.read_state()
	_check(sold.is_open() and sold_open["stock"]["trinkets"][0]["sold"] == true,
		"owned patch is genuinely sold before any action")
	_assert_refused(sold, sold_open, "peddler_sold", "trinket", patch_id,
		"sold patch choice")
	_check(sold.is_open(), "sold patch refusal does not consume the visit")
	var card_buy := sold.choose_purchase("peddler_sold", sold_open["state"],
		sold_open["stock"], "card", sold_open["stock"]["cards"][0]["id"])
	_check(card_buy.get("ok") == true and sold.is_consumed(),
		"a card remains buyable beside a sold patch")

	# Unaffordable offers refuse without spending and never latch.
	for kind in ["card", "trinket"]:
		var offers: Array = stock["cards"] if kind == "card" else stock["patches"]
		for offer in offers:
			var short_gold: int = int(offer["price"]) - 1
			var poor := RunPeddlerVisit.new("peddler_poor", PARTY, DECK, [],
				short_gold, stock)
			var poor_open := poor.read_state()
			_check(poor.is_open(), "one-gold-short visit opens: " + str(offer["id"]))
			_assert_refused(poor, poor_open, "peddler_poor", kind, offer["id"],
				"unaffordable " + str(offer["id"]))
			var left := poor.leave("peddler_poor", poor_open["state"],
				poor_open["stock"])
			_check(left.get("ok") == true and left.get("decision") == "leave"
				and left["state"] == poor_open["state"],
				"unaffordable " + str(offer["id"]) + ": failed buy still permits one Leave")
			_assert_leave_refused(poor, poor_open, "peddler_poor",
				"unaffordable " + str(offer["id"]) + ": second Leave")

	# Every earlier refusal left exactly one legal no-spend Leave.
	var accepted := visit.leave("peddler_refuse", snapshot["state"], snapshot["stock"])
	_check(accepted == {
		"ok": true,
		"node_id": "peddler_refuse",
		"decision": "leave",
		"state": _state(500),
		"stock": _ledger_stock(stock),
	}, "all refused attempts leave exactly one no-spend Leave available")
	_assert_leave_refused(visit, snapshot, "peddler_refuse", "Leave after the one Leave")
	_assert_refused(visit, snapshot, "peddler_refuse", "card", card_id,
		"buy after the accepted Leave")


func _assert_invalid(label: String, node: Variant, party: Variant, deck: Variant,
		owned: Variant, gold: Variant, stock: Variant) -> void:
	var party_before: Variant = _snapshot(party)
	var deck_before: Variant = _snapshot(deck)
	var owned_before: Variant = _snapshot(owned)
	var stock_before: Variant = _snapshot(stock)
	var visit := RunPeddlerVisit.new(node, party, deck, owned, gold, stock)
	_check(visit.read_state() == _invalid_state(),
		label + ": invalid visit publishes nothing")
	_check(not visit.is_valid() and not visit.is_open() and not visit.is_consumed(),
		label + ": invalid visit reports no decision")
	_check(visit.choose_purchase("peddler", _state(500), {}, "card", "warden_strike")
		== _refused_receipt(), label + ": invalid visit refuses every buy")
	_check(visit.leave("peddler", _state(500), {}) == _refused_receipt(),
		label + ": invalid visit refuses Leave")
	_check(party == party_before and deck == deck_before and owned == owned_before
		and stock == stock_before, label + ": rejected construction leaves inputs untouched")


func _test_invalid_construction() -> void:
	var stock := _sampled_stock(_rng(SEED + 4))
	_check(stock.get("ok") == true and stock["cards"].size() == 3
		and stock["patches"].size() == 1,
		"invalid-construction fixture has authentic 3+1 stock")
	if stock.get("ok") != true:
		return
	var cards: Array = stock["cards"]
	var patches: Array = stock["patches"]

	# Non-vacuous: the shared ledger admits the authentic stock and refuses an
	# incomplete one on its own.
	_check(RunShopPurchases.new(PARTY, DECK, [], 500, cards, patches,
		"peddler").is_valid(), "shared peddler ledger admits the authentic 3+1 stock")
	_check(not RunShopPurchases.new(PARTY, DECK, [], 500, cards.slice(0, 2),
		patches, "peddler").is_valid(),
		"shared ledger independently refuses an incomplete 3+1 stock")

	for bad_node in [null, 1, true, "", "  ", " peddler", "peddler ",
			"\tpeddler", [], {}]:
		_assert_invalid("node " + str(bad_node), bad_node, PARTY, DECK, [], 500, stock)

	var bad_stocks: Array = [
		null, "stock", 7, true, [], {},
		{"ok": false, "cards": [], "patches": []},
		{"ok": "true", "cards": cards, "patches": patches},
		{"ok": true, "patches": patches},
		{"ok": true, "cards": cards},
		{"ok": true, "cards": [], "patches": patches},
		{"ok": true, "cards": cards, "patches": []},
		{"ok": true, "cards": cards.slice(0, 2), "patches": patches},
		{"ok": true, "cards": cards, "patches": patches + [patches[0].duplicate(true)]},
		{"ok": true, "cards": cards, "trinkets": patches},
		{"ok": true, "cards": [cards[0].duplicate(true), cards[0].duplicate(true),
			cards[2]], "patches": patches},
		{"ok": true, "cards": [_replaced(cards[0], "owner", "seamstress"), cards[1],
			cards[2]], "patches": patches},
		{"ok": true, "cards": [_replaced(cards[0], "owner", "unknown_hero"), cards[1],
			cards[2]], "patches": patches},
		{"ok": true, "cards": [_replaced(cards[1], "owner", cards[0]["owner"]),
			cards[0], cards[2]], "patches": patches},
		{"ok": true, "cards": [_replaced(cards[0], "price", -1), cards[1], cards[2]],
			"patches": patches},
		{"ok": true, "cards": [_replaced(cards[0], "price", 50.5), cards[1], cards[2]],
			"patches": patches},
		{"ok": true, "cards": [_replaced(cards[0], "price", "50"), cards[1], cards[2]],
			"patches": patches},
		{"ok": true, "cards": [_replaced(cards[0], "id", ""), cards[1], cards[2]],
			"patches": patches},
		{"ok": true, "cards": [_replaced(cards[0], "sold", false), cards[1], cards[2]],
			"patches": patches},
		{"ok": true, "cards": cards, "patches": [_replaced(patches[0], "price", -1)]},
		{"ok": true, "cards": cards, "patches": [_replaced(patches[0], "price", 100.5)]},
		{"ok": true, "cards": cards, "patches": [_replaced(patches[0], "id", "")]},
		{"ok": true, "cards": cards, "patches": [_replaced(patches[0], "sold", false)]},
	]
	for i in range(bad_stocks.size()):
		_assert_invalid("stock %d" % i, "peddler", PARTY, DECK, [], 500,
			bad_stocks[i])

	_assert_invalid("two-hero party", "peddler", [PARTY[0], PARTY[1]], DECK, [], 500, stock)
	_assert_invalid("duplicate party", "peddler", [PARTY[0], PARTY[0], PARTY[2]],
		DECK, [], 500, stock)
	_assert_invalid("non-array party", "peddler", "warden", DECK, [], 500, stock)
	_assert_invalid("non-array deck", "peddler", PARTY, "deck", [], 500, stock)
	_assert_invalid("blank deck card", "peddler", PARTY, [DECK[0], "", DECK[2]], [],
		500, stock)
	_assert_invalid("non-array owned", "peddler", PARTY, DECK, "owned", 500, stock)
	_assert_invalid("malformed owned patch", "peddler", PARTY, DECK, [42], 500, stock)
	_assert_invalid("negative gold", "peddler", PARTY, DECK, [], -1, stock)
	_assert_invalid("float gold", "peddler", PARTY, DECK, [], 500.0, stock)
	_assert_invalid("string gold", "peddler", PARTY, DECK, [], "500", stock)
	_assert_invalid("null gold", "peddler", PARTY, DECK, [], null, stock)


func _test_replay_and_rng() -> void:
	var rng_a := _rng(SEED + 5)
	var rng_b := _rng(SEED + 5)
	var stock_a := _sampled_stock(rng_a)
	var stock_b := _sampled_stock(rng_b)
	var after_stock := rng_a.state
	_check(stock_a.get("ok") == true and stock_a == stock_b
		and after_stock == rng_b.state,
		"identically seeded generators produce identical 3+1 stock and draw state")
	if stock_a.get("ok") != true:
		return
	var a := RunPeddlerVisit.new("peddler_replay", PARTY, DECK, [], 500, stock_a)
	var b := RunPeddlerVisit.new("peddler_replay", PARTY, DECK, [], 500, stock_b)
	var open_a := a.read_state()
	var open_b := b.read_state()
	_check(open_a == open_b, "independent authentic visits open to identical state")
	var offer: Dictionary = stock_a["cards"][1]
	var buy_a := a.choose_purchase("peddler_replay", open_a["state"],
		open_a["stock"], "card", offer["id"])
	var buy_b := b.choose_purchase("peddler_replay", open_b["state"],
		open_b["stock"], "card", offer["id"])
	_check(buy_a == buy_b and a.read_state() == b.read_state(),
		"identically seeded visits replay the same accepted receipt")
	var after := a.read_state()
	_assert_refused(a, open_a, "peddler_replay", "card", offer["id"],
		"stale replay after commit")
	_assert_refused(a, after, "peddler_replay", "card", offer["id"],
		"exact replay after commit")
	_assert_refused(a, after, "peddler_replay", "trinket",
		stock_a["patches"][0]["id"], "other patch after commit")
	_assert_leave_refused(a, after, "peddler_replay", "Leave after commit")
	_check(a.read_state() == after, "replays never alter the committed receipt")

	# A failed buy on a fresh visit still leaves the one legitimate Leave.
	var c := RunPeddlerVisit.new("peddler_replay", PARTY, DECK, [], 37, stock_a)
	var open_c := c.read_state()
	_assert_refused(c, open_c, "peddler_replay", "card", "not_offered",
		"unknown choice before the one Leave")
	_assert_refused(c, open_c, "forged_node", "card", offer["id"],
		"mismatched node before the one Leave")
	var left := c.leave("peddler_replay", open_c["state"], open_c["stock"])
	_check(left.get("ok") == true and left.get("decision") == "leave"
		and left["state"] == open_c["state"],
		"failed buys still permit the one no-spend Leave")
	_check(c.leave("peddler_replay", open_c["state"], open_c["stock"])
		== _refused_receipt(), "second Leave after that one is refused")
	_check(rng_a.state == after_stock and rng_b.state == after_stock,
		"every visit action and Leave consumed no run RNG")
