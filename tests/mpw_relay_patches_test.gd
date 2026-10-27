extends SceneTree
## Authored P8 records and independent seeded existing-slot stock contract.
##
## Stock weight is relative to ONE ordinary eligible patch, whose weight is the
## 100% baseline below. A 10% weight therefore means one tenth of an ordinary
## patch's weight; it is not a share of the whole Shop stock. The independent
## ticket oracle below also checks the actual seeded four-draw stream.

const CATALOG_PATH := "res://data/patches/mpw_synergy_patches.json"
const ORDINARY_PATCH_WEIGHT_BASELINE := 100
const RARE_STOCK_WEIGHT_PERCENT := 10
const RARE_SHOP_PRICE_GOLD := 100

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run()
	_stock_weights()
	for failure in failures:
		printerr(failure)
	print("mpw_relay_patches_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _entries_for(records: Array, id: String) -> Array:
	return records.filter(func(record): return record is Dictionary and record.get("id") == id)


## Returns the single record for an ID, or an empty dictionary when the ID is
## missing or duplicated; the caller then fails every field check instead of
## silently passing on a null.
func _single(records: Array, id: String) -> Dictionary:
	var found: Array = _entries_for(records, id)
	return found[0] if found.size() == 1 else {}


func _expect(record: Dictionary, id: String, expected: Dictionary) -> void:
	_check(not record.is_empty(), "P8 record exists exactly once: " + id)
	if record.is_empty():
		return
	for field in expected:
		_check(record.has(field), id + " declares field: " + field)
		if not record.has(field):
			continue
		_check(record[field] == expected[field],
			id + "." + field + " is " + str(expected[field])
			+ " (found " + str(record[field]) + ")")


func _loaded_slots() -> Dictionary:
	var slots := {}
	for entry in RunAuthoredPatchDefinitions.load_definitions():
		if entry is Dictionary and typeof(entry.get("id")) == TYPE_STRING:
			slots[entry["id"]] = entry.get("slot")
	return slots


func _stock_weights() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var frozen := source.duplicate(true)
	var party := ["warden", "seamstress", "tinker"]
	var pools := {}
	for owner in party:
		pools[owner] = []
	for card in source.cards:
		if pools.has(card.owner):
			pools[card.owner].append(card.id)
	for owner in party:
		pools[owner].sort()
	var ids: Array[String] = []
	for patch in source.trinkets:
		ids.append(patch.id)
	ids.sort()
	for id in ["relay_bobbin", "hearth_lining"]:
		var quotes: Array = source.trinkets.filter(func(entry): return entry.id == id)
		_check(quotes.size() == 1 and quotes[0].price == 100, "P8 has one authored 100 gold price: " + id)
	var tickets: Array[String] = []
	for id in ids:
		for ticket in range(10 if id in ["relay_bobbin", "hearth_lining"] else 100):
			tickets.append(id)
	var seen := {}
	for seed_value in range(1, 1025):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var reference := RandomNumberGenerator.new()
		reference.seed = seed_value
		for owner in party:
			reference.randi_range(0, pools[owner].size() - 1)
		var expected: String = tickets[reference.randi_range(0, tickets.size() - 1)]
		var result := RunShopStockOffers.generate_peddler_stock(rng, party, source.cards, source.trinkets, [])
		_check(result.ok and result.cards.size() == 3 and result.patches.size() == 1
			and result.patches[0].id == expected and rng.state == reference.state,
			"P8 full-catalog independent 10:100 ticket oracle and exact four-draw state: " + str(seed_value))
		if result.ok:
			seen[result.patches[0].id] = true
	for id in ["relay_bobbin", "hearth_lining"]:
		_check(seen.has(id), "seeded existing slot actually reaches " + id)
		for invalid in [{"id": id, "price": -1}, {"id": id, "price": 0.5}, {"id": id}]:
			var bad: Array = source.trinkets.duplicate(true)
			bad = bad.filter(func(entry): return entry.id != id)
			bad.append(invalid)
			var rng := RandomNumberGenerator.new()
			rng.seed = 317
			var before := rng.state
			var rejected := RunShopStockOffers.generate_peddler_stock(rng, party, source.cards, bad, [])
			_check(rejected == {"ok": false, "cards": [], "patches": []} and rng.state == before,
				"malformed rare candidate rejects before any draw: " + id)
	_check(source == frozen, "weighted stock leaves entire authored supplier source unchanged")


func _run() -> void:
	var source := FileAccess.get_file_as_string(CATALOG_PATH)
	_check(not source.is_empty(), "P8 catalog is readable: " + CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(source)
	_check(typeof(parsed) == TYPE_ARRAY, "P8 catalog parses to a JSON array")
	if typeof(parsed) != TYPE_ARRAY:
		return
	var records: Array = parsed
	_check(not records.is_empty(), "P8 catalog contains authored records")

	# Whole-file shape: every entry is an object with a well-formed, unique ID.
	# Checked by ID rather than by list length, ordering or array index.
	var counts := {}
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			_check(false, "every P8 record is a JSON object")
			continue
		var record_id: Variant = record.get("id")
		_check(RunPatchWardrobe._id(record_id),
			"P8 record has a well-formed stable ID: " + str(record_id))
		if RunPatchWardrobe._id(record_id):
			counts[record_id] = int(counts.get(record_id, 0)) + 1
	for record_id in counts:
		_check(counts[record_id] == 1, "P8 ID occurs exactly once: " + str(record_id))

	var relay := _single(records, "relay_bobbin")
	_expect(relay, "relay_bobbin", {
		"slot": "HEAD",
		"rarity": "rare",
		"effect": "different_hero_pinned_token_shared_energy",
		"trigger": "different_living_hero_consumes_pin_placed_by_wearer",
		"pin_must_be_placed_by_wearer": true,
		"consumer_must_be_living": true,
		"consumer_must_differ_from_wearer": true,
		"wearer_must_be_living": true,
		"wearer_must_be_untorn": true,
		"requires_confirmed_receipt": true,
		"shared_energy": 1,
		"shared_energy_cap": 3,
		"uses_per_combat": 1,
		"shop_price_gold": RARE_SHOP_PRICE_GOLD,
		"stock_weight_percent": RARE_STOCK_WEIGHT_PERCENT,
		"stock_weight_basis": "ordinary_patch",
		"stock_competes_for_existing_slot": true,
	})
	_check(not relay.is_empty()
		and float(relay.get("stock_weight_percent", 0.0))
			/ float(ORDINARY_PATCH_WEIGHT_BASELINE) == 0.1,
		"relay_bobbin stock weight is 10% of one ordinary patch (baseline 100)")

	var hearth := _single(records, "hearth_lining")
	_expect(hearth, "hearth_lining", {
		"slot": "COAT",
		"rarity": "rare",
		"effect": "earned_quilt_bonus_wearer_heal",
		"trigger": "first_earned_quilt_bonus_in_combat",
		"requires_earned_bonus": true,
		"wearer_must_be_living": true,
		"wearer_must_be_untorn": true,
		"heal": 2,
		"heal_cap": "max_hp",
		"uses_per_combat": 1,
		"shop_price_gold": RARE_SHOP_PRICE_GOLD,
		"stock_weight_percent": RARE_STOCK_WEIGHT_PERCENT,
		"stock_weight_basis": "ordinary_patch",
		"stock_competes_for_existing_slot": true,
	})
	_check(not hearth.is_empty()
		and float(hearth.get("stock_weight_percent", 0.0))
			/ float(ORDINARY_PATCH_WEIGHT_BASELINE) == 0.1,
		"hearth_lining stock weight is 10% of one ordinary patch (baseline 100)")

	# The two P8 records compete for HEAD and COAT respectively; they never add
	# a third slot or a duplicate record.
	_check(relay.get("slot") != hearth.get("slot"),
		"the two P8 records occupy different wardrobe slots")

	# The P8 catalog is now registered; its IDs are present in loaded catalogs.
	var loaded := _loaded_slots()
	_check(not loaded.is_empty(), "existing authored catalogs still load")
	for id in ["relay_bobbin", "hearth_lining"]:
		_check(counts.has(id), "P8 catalog still declares: " + id)
		_check(loaded.has(id), "P8 ID is now in the authored catalogs: " + id)
	for record_id in counts:
		_check(loaded.has(record_id),
			"P8 ID is present in the authored catalogs: " + str(record_id))

	# Earlier authored powers must keep loading and keep their slots.
	var earlier := {
		"button_eye": "HEAD",
		"frayfinder_mitt": "ARM",
		"borrowed_button": "COAT",
	}
	for id in earlier:
		_check(loaded.get(id) == earlier[id],
			"earlier authored power still loads in its slot: " + id)
