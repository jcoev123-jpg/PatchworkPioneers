extends SceneTree
## Deterministic headless test for the three gothic hero-prop crossroads
## appended to data/events/v3_hero_choice_events.json by this task:
## v3_warden_oxblood_shield_clock, v3_seamstress_crimson_shadow_choir and
## v3_yarn_ranger_moonbolas_windharp.
##
## Everything is looked up by authored event/choice ID. No catalog total,
## ordered catalog ID list or positional event index is asserted, so other
## tasks may keep appending to the same shared catalog.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

## A Design v4 Stitched roster containing all three required heroes, and a
## four-hero roster containing none of them.
const STITCHED_PARTY := ["warden", "seamstress", "yarn_ranger", "button_golem"]
const ABSENT_PARTY := ["tinker", "rag_duelist", "scarecrow", "lantern_monk"]

const FUNDED_WALLET := {"gold": 50, "scraps": 5}
const ZERO_WALLET := {"gold": 0, "scraps": 0}

## Task-local expectation table, independent of the production catalog:
## exact authored metadata, authored choice order, texts and signed deltas.
const NEW_EVENTS := {
	"v3_warden_oxblood_shield_clock": {
		"title": "The Oxblood Shield Clock",
		"description": "An enormous slate-blue shield swings as the pendulum of a crooked roadside clock; the Warden's dented pot helmet props its brass axle while small button-eyed sentries count each candlelit chime.",
		"required_hero": "warden",
		"hero_choice_ids": ["steady_shield_pendulum", "gather_clock_rivets"],
		"choice_order": ["steady_shield_pendulum", "gather_clock_rivets", "leave"],
		"choice_texts": {
			"steady_shield_pendulum": "Spend 2 scraps to steady the swinging shield (gain 28 gold)",
			"gather_clock_rivets": "Gather two bundles of loose clock rivets (+2 scraps)",
			"leave": "Let the huge shield keep its slow time",
		},
		"deltas": {
			"steady_shield_pendulum": [28, -2],
			"gather_clock_rivets": [0, 2],
			"leave": [0, 0],
		},
	},
	"v3_seamstress_crimson_shadow_choir": {
		"title": "The Crimson Shadow Choir",
		"description": "A row of plump button-eyed glove puppets sings behind a bone-cream curtain; the Seamstress's giant needle lifts scarlet strings from their velvet shoulders beneath a single plum lantern.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["sew_shadow_strings", "buy_choir_thread"],
		"choice_order": ["sew_shadow_strings", "buy_choir_thread", "leave"],
		"choice_texts": {
			"sew_shadow_strings": "Spend 1 scrap restringing the choir (gain 22 gold)",
			"buy_choir_thread": "Pay 17 gold for three reels of choir thread (+3 scraps)",
			"leave": "Lower the curtain on the quiet choir",
		},
		"deltas": {
			"sew_shadow_strings": [22, -1],
			"buy_choir_thread": [-17, 3],
			"leave": [0, 0],
		},
	},
	"v3_yarn_ranger_moonbolas_windharp": {
		"title": "The Moonbolas Windharp",
		"description": "Two giant knitting-needle poles carry a web of moss and teal wool; the Yarn Ranger's huge braided bolas have caught three brass crescent chimes above a misty toy-sized road.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["gather_windharp_knots", "trade_moonharp_braid"],
		"choice_order": ["gather_windharp_knots", "trade_moonharp_braid", "leave"],
		"choice_texts": {
			"gather_windharp_knots": "Gather two fallen moon-wool knots (+2 scraps)",
			"trade_moonharp_braid": "Trade 2 scrap bundles of braided wool for 29 gold",
			"leave": "Let the brass moons chime in the wind",
		},
		"deltas": {
			"gather_windharp_knots": [0, 2],
			"trade_moonharp_braid": [29, -2],
			"leave": [0, 0],
		},
	},
}

## Exact funded preview/settlement balances for a fresh visit per choice, in
## the brief's listed order: {event_id: {choice_id: [gold, scraps]}}.
const FUNDED_BALANCES := {
	"v3_warden_oxblood_shield_clock": {
		"steady_shield_pendulum": [78, 3],
		"gather_clock_rivets": [50, 7],
		"leave": [50, 5],
	},
	"v3_seamstress_crimson_shadow_choir": {
		"sew_shadow_strings": [72, 4],
		"buy_choir_thread": [33, 8],
		"leave": [50, 5],
	},
	"v3_yarn_ranger_moonbolas_windharp": {
		"gather_windharp_knots": [50, 7],
		"trade_moonharp_braid": [79, 3],
		"leave": [50, 5],
	},
}

## The four priced choices that must fail closed on a zero wallet.
const ZERO_UNAFFORDABLE := ["steady_shield_pendulum", "sew_shadow_strings",
	"buy_choir_thread", "trade_moonharp_braid"]

## Existing anchors that must survive this append.
const ANCHOR_IDS := ["v3_warden_shield_menders", "v3_seamstress_thread_cart",
	"v3_yarn_ranger_knit_ford"]

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary = {}
var catalog_snapshot: Dictionary = {}


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	var catalog_ok: bool = parsed is Dictionary \
		and (parsed as Dictionary).get("events") is Array \
		and not ((parsed as Dictionary).get("events") as Array).is_empty()
	_check(catalog_ok, "hero-choice catalog parses with a non-empty events array")
	seed(911)
	var expected_global := randi()
	seed(911)
	if catalog_ok:
		catalog = parsed
		catalog_snapshot = catalog.duplicate(true)
		_test_catalog_records()
		var service := RunV3HeroEventOffers.new(STITCHED_PARTY)
		_check(service.is_valid(), "genuine four-hero Stitched roster admission is valid")
		if service.is_valid():
			_test_offers_admission(service)
			_test_funded_receipts(service)
			_test_zero_wallet_rejections(service)
			_test_selection(service)
	_check(catalog == catalog_snapshot, "all operations preserve the authored catalog")
	_check(randi() == expected_global, "no operation consumes the global seeded RNG")
	for failure in failures:
		printerr(failure)
	print("v3_stitched_moonharp_hero_crossroads_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


## The engine's JSON parser hands integer literals back as integral floats,
## so an authored integer outcome is an integral value of either type.
func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number
	return false


func _records_with(event_id: String) -> Array:
	var matches: Array = []
	for record in catalog.get("events", []):
		if record is Dictionary and (record as Dictionary).get("id") == event_id:
			matches.append(record)
	return matches


func _authored(event_id: String) -> Dictionary:
	var matches := _records_with(event_id)
	return matches[0] if matches.size() == 1 else {}


func _offer_by_id(service: RunV3HeroEventOffers, event_id: String) -> Dictionary:
	for offer in service.get_offers():
		if offer is Dictionary and (offer as Dictionary).get("id") == event_id:
			return offer
	return {}


func _preview_quote(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


func _has_affordable_non_leave(record: Dictionary, wallet: Dictionary) -> bool:
	var preview := RunEventChoice.new(record).preview_wallet_choices(wallet)
	if not preview.get("ok", false):
		return false
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") != "leave" \
				and entry.get("affordable") == true:
			return true
	return false


## Dynamically derived actionable pool from the service's own current offers;
## never a hard-coded catalog size, ordered list or selection index.
func _expected_actionable(service: RunV3HeroEventOffers, lost_ids: Array,
		excluded: Array, wallet: Dictionary) -> Array[String]:
	var lost := {}
	for hero in lost_ids:
		lost[hero] = true
	var excluded_map := {}
	for offer_id in excluded:
		excluded_map[offer_id] = true
	var ids: Array[String] = []
	for offer in service.get_offers():
		var event_id: String = offer["id"]
		if lost.has(offer["required_hero"]) or excluded_map.has(event_id):
			continue
		if _has_affordable_non_leave(offer, wallet):
			ids.append(event_id)
	ids.sort()
	return ids


## AC1: the three new records exist exactly once with exact authored metadata,
## choice texts/order and two-key signed integer outcomes; the named anchors
## remain.
func _test_catalog_records() -> void:
	for anchor_id in ANCHOR_IDS:
		_check(_records_with(anchor_id).size() == 1,
			"existing anchor remains exactly once: " + anchor_id)
	for event_id in NEW_EVENTS:
		var spec: Dictionary = NEW_EVENTS[event_id]
		var matches := _records_with(event_id)
		_check(matches.size() == 1, "new event appears exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.size() == 6 and record.has("id") and record.has("title")
			and record.has("description") and record.has("required_hero")
			and record.has("hero_choice_ids") and record.has("choices"),
			"new event carries exactly the six authored fields: " + event_id)
		_check(record.get("title") == spec["title"]
			and record.get("description") == spec["description"]
			and record.get("required_hero") == spec["required_hero"],
			"new event keeps its exact authored metadata: " + event_id)
		_check(record.get("hero_choice_ids") == spec["hero_choice_ids"],
			"new event lists its exact two non-Leave hero choice IDs: " + event_id)
		var choices: Array = record.get("choices", [])
		_check(choices.size() == 3, "new event offers exactly three choices: " + event_id)
		var order: Array = spec["choice_order"]
		for index in range(order.size()):
			if index >= choices.size():
				break
			var choice: Dictionary = choices[index]
			var choice_id: String = order[index]
			var delta: Array = spec["deltas"][choice_id]
			_check(choice.size() == 3 and choice.has("id") and choice.has("text")
				and choice.has("outcome") and choice.get("id") == choice_id,
				"choice slot keeps exactly id/text/outcome with the authored ID: "
				+ event_id + "/" + choice_id)
			_check(choice.get("text") == spec["choice_texts"][choice_id],
				"choice keeps its exact authored text: " + event_id + "/" + choice_id)
			var outcome: Dictionary = choice.get("outcome", {})
			_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps")
				and _is_integral(outcome.get("gold"))
				and _is_integral(outcome.get("scraps"))
				and outcome.get("gold") == delta[0]
				and outcome.get("scraps") == delta[1],
				"outcome is exactly the two signed integer wallet keys: "
				+ event_id + "/" + choice_id)
		_check(choices.size() == 3 and choices[2].get("id") == "leave",
			"the third new choice is Leave: " + event_id)
		for choice_id in order:
			var listed_delta: Array = spec["deltas"][choice_id]
			var balance: Array = FUNDED_BALANCES[event_id][choice_id]
			_check(balance[0] == 50 + listed_delta[0]
				and balance[1] == 5 + listed_delta[1],
				"funded balance matches the signed delta from {50,5}: "
				+ event_id + "/" + choice_id)


## AC2: genuine four-hero admission, canonical offer entry, absence/lost gate
## and detached returned data through the real RunV3HeroEventOffers service.
func _test_offers_admission(service: RunV3HeroEventOffers) -> void:
	var absent := RunV3HeroEventOffers.new(ABSENT_PARTY)
	_check(absent.is_valid(), "absent-hero four-hero roster is a valid admission")
	for event_id in NEW_EVENTS:
		var authored := _authored(event_id)
		var offer := _offer_by_id(service, event_id)
		_check(not offer.is_empty(),
			"four-hero roster offers the new event: " + event_id)
		_check(offer == authored,
			"detached offer equals the authored record: " + event_id)
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit is RunEventChoice and visit.is_valid() and not visit.is_claimed(),
			"canonical offer enters a fresh Stitched-survivor visit: " + event_id)
		if visit != null:
			_check(visit.get_event() == authored,
				"visit snapshot equals the authored record: " + event_id)
		var legacy_visit := service.enter(event_id)
		_check(legacy_visit is RunEventChoice and legacy_visit.is_valid(),
			"canonical ID entry admits the new event: " + event_id)
		_check(_offer_by_id(absent, event_id).is_empty(),
			"absent-hero roster never offers the new event: " + event_id)
		_check(absent.enter(event_id) == null
			and absent.enter_stitched_survivor(event_id, []) == null,
			"absent required hero denies every entry path: " + event_id)
		var required_hero: String = NEW_EVENTS[event_id]["required_hero"]
		for lost_hero in ["warden", "seamstress", "yarn_ranger", "button_golem"]:
			var lost_visit := service.enter_stitched_survivor(event_id, [lost_hero])
			_check((lost_visit == null) == (lost_hero == required_hero),
				"lost_ids deny only the lost hero's event: "
				+ event_id + "/" + lost_hero)
	_check(service.enter_stitched_survivor("v3_moonharp_unknown_event", []) == null
		and service.enter_stitched_survivor(null, []) == null
		and service.enter_stitched_survivor("", []) == null,
		"unknown or malformed event IDs never authorize survivor entry")
	# Detached returned data: mutating a returned offer changes nothing and a
	# tampered copy never authorizes entry.
	var pristine := service.get_offers()
	var tampered := service.get_offers()
	_check(not tampered.is_empty(), "detached-offer fixture is non-empty")
	if not tampered.is_empty():
		tampered[0]["required_hero"] = "tinker"
		tampered[0]["choices"][0]["outcome"]["gold"] = 999
		_check(service.get_offers() == pristine,
			"returned offers are detached from the service")
		_check(service.enter_stitched_survivor(tampered[0], []) == null,
			"a tampered offer record never authorizes entry")
	# A tampered copy of a new record is wholly denied as catalog data.
	var forged := _authored("v3_warden_oxblood_shield_clock").duplicate(true)
	forged["choices"][0]["outcome"]["gold"] = 999
	var forged_service := RunV3HeroEventOffers.new(STITCHED_PARTY, {"events": [forged]})
	_check(not forged_service.is_valid() and forged_service.get_offers().is_empty()
		and forged_service.enter_stitched_survivor("v3_warden_oxblood_shield_clock", []) == null,
		"a tampered new record is wholly denied fail-closed")


## AC3: nine separate funded visits settle the exact expected balances through
## the existing RunEventChoice service, with free Leave, single-claim rejection
## and an unknown choice that never latches.
func _test_funded_receipts(service: RunV3HeroEventOffers) -> void:
	for event_id in NEW_EVENTS:
		var spec: Dictionary = NEW_EVENTS[event_id]
		var order: Array = spec["choice_order"]
		for choice_id in order:
			var balance: Array = FUNDED_BALANCES[event_id][choice_id]
			var delta: Array = spec["deltas"][choice_id]
			var visit := service.enter_stitched_survivor(event_id, [])
			if visit == null or not visit.is_valid():
				_check(false, "funded receipt visit opens: " + event_id + "/" + choice_id)
				continue
			var wallet := FUNDED_WALLET.duplicate(true)
			var wallet_before: Dictionary = wallet.duplicate(true)
			var preview := visit.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview is an authentic quote: " + event_id + "/" + choice_id)
			var quote := _preview_quote(preview, choice_id)
			_check(quote == {"choice_id": choice_id, "gold_delta": delta[0],
				"scraps_delta": delta[1], "affordable": true,
				"wallet": {"gold": balance[0], "scraps": balance[1]}},
				"funded preview quotes the exact delta and balance: "
				+ event_id + "/" + choice_id)
			var preview_choices: Array = preview.get("choices", [])
			_check(preview_choices.size() == order.size(),
				"funded preview shows every choice in authored order: " + event_id)
			for index in range(min(order.size(), preview_choices.size())):
				var listed_id: String = order[index]
				var listed_balance: Array = FUNDED_BALANCES[event_id][listed_id]
				_check(preview_choices[index].get("choice_id") == listed_id
					and preview_choices[index].get("wallet")
					== {"gold": listed_balance[0], "scraps": listed_balance[1]},
					"funded preview follows the listed choice order and balances: "
					+ event_id + "/" + listed_id)
			var receipt := visit.choose_with_wallet(choice_id, wallet)
			_check(receipt == {"ok": true, "event_id": event_id,
				"choice_id": choice_id,
				"wallet": {"gold": balance[0], "scraps": balance[1]}},
				"funded settlement is the exact expected balance: "
				+ event_id + "/" + choice_id)
			_check(wallet == wallet_before,
				"caller wallet stays immutable: " + event_id + "/" + choice_id)
			_check(visit.is_claimed() and not visit.is_valid(),
				"first successful choice latches the visit: "
				+ event_id + "/" + choice_id)
			var settled: Dictionary = receipt.get("wallet", {})
			_check(visit.choose_with_wallet(choice_id, settled)
				== {"ok": false, "event_id": "", "choice_id": "", "wallet": settled},
				"a claimed visit rejects a second settlement: "
				+ event_id + "/" + choice_id)
			_check(not visit.choose_with_wallet("leave", settled)["ok"],
				"a claimed visit rejects every other choice: " + event_id)
		var unknown_visit := service.enter_stitched_survivor(event_id, [])
		if unknown_visit != null:
			var unknown_wallet := FUNDED_WALLET.duplicate(true)
			_check(unknown_visit.choose_with_wallet("moonharp_phantom_choice", unknown_wallet)
				== {"ok": false, "event_id": "", "choice_id": "",
					"wallet": unknown_wallet},
				"unknown choice ID is refused unchanged: " + event_id)
			_check(unknown_visit.is_valid() and not unknown_visit.is_claimed(),
				"unknown choice never latches the visit: " + event_id)
			_check(unknown_visit.choose_with_wallet("leave", unknown_wallet)["ok"],
				"the unconsumed visit still settles its Leave: " + event_id)
		var leave_visit := service.enter_stitched_survivor(event_id, [])
		if leave_visit != null:
			var leave_wallet := FUNDED_WALLET.duplicate(true)
			_check(leave_visit.choose_with_wallet("leave", leave_wallet)
				== {"ok": true, "event_id": event_id, "choice_id": "leave",
					"wallet": {"gold": 50, "scraps": 5}},
				"free Leave settles the funded wallet unchanged: " + event_id)
			_check(leave_visit.is_claimed(), "Leave latches its own visit: " + event_id)


## AC4: zero-wallet fail-closed behaviour for the four priced choices, with the
## free choices and Leave still actionable and the visit never consumed.
func _test_zero_wallet_rejections(service: RunV3HeroEventOffers) -> void:
	for event_id in NEW_EVENTS:
		var spec: Dictionary = NEW_EVENTS[event_id]
		var order: Array = spec["choice_order"]
		for choice_id in order:
			if not ZERO_UNAFFORDABLE.has(choice_id):
				continue
			var visit := service.enter_stitched_survivor(event_id, [])
			if visit == null:
				_check(false, "zero-wallet rejection visit opens: "
					+ event_id + "/" + choice_id)
				continue
			var wallet := ZERO_WALLET.duplicate(true)
			var quote := _preview_quote(visit.preview_wallet_choices(wallet), choice_id)
			_check(quote.get("affordable") == false,
				"priced choice is unaffordable on a zero wallet: "
				+ event_id + "/" + choice_id)
			_check(visit.choose_with_wallet(choice_id, wallet)
				== {"ok": false, "event_id": "", "choice_id": "",
					"wallet": {"gold": 0, "scraps": 0}},
				"insufficient funds fail closed with the wallet unchanged: "
				+ event_id + "/" + choice_id)
			_check(visit.is_valid() and not visit.is_claimed(),
				"a failed priced choice consumes no visit: "
				+ event_id + "/" + choice_id)
			var recover_id := ""
			for candidate in order:
				if candidate != "leave" and not ZERO_UNAFFORDABLE.has(candidate):
					recover_id = candidate
					break
			if recover_id != "":
				var free_delta: Array = spec["deltas"][recover_id]
				_check(visit.choose_with_wallet(recover_id, wallet)
					== {"ok": true, "event_id": event_id, "choice_id": recover_id,
						"wallet": {"gold": free_delta[0], "scraps": free_delta[1]}},
					"the unconsumed visit still settles its free choice: "
					+ event_id + "/" + recover_id)
			else:
				_check(visit.choose_with_wallet("leave", wallet)["ok"],
					"the unconsumed visit still settles its Leave: " + event_id)
			_check(visit.is_claimed(),
				"the recovering choice latches the visit once: " + event_id)
		# Exact zero-wallet affordability per event: free choices and Leave stay
		# actionable, priced choices do not.
		var zero_visit := service.enter_stitched_survivor(event_id, [])
		if zero_visit != null:
			var zero_preview := zero_visit.preview_wallet_choices(ZERO_WALLET.duplicate(true))
			for choice_id in order:
				var zero_quote := _preview_quote(zero_preview, choice_id)
				var expected_affordable: bool = not ZERO_UNAFFORDABLE.has(choice_id)
				_check(zero_quote.get("affordable") == expected_affordable,
					"zero-wallet affordability is exact: "
					+ event_id + "/" + choice_id)


## AC4: seeded four-hero survivor selection with dynamic exclusions, seeded
## replay, one-draw accounting and zero-draw rejections that preserve RNG.
func _test_selection(service: RunV3HeroEventOffers) -> void:
	var all_offer_ids: Array[String] = []
	for offer in service.get_offers():
		all_offer_ids.append(offer["id"])
	_check(all_offer_ids.has("v3_warden_oxblood_shield_clock")
		and all_offer_ids.has("v3_seamstress_crimson_shadow_choir")
		and all_offer_ids.has("v3_yarn_ranger_moonbolas_windharp"),
		"the four-hero service currently offers all three new crossroads")
	var seed_index := 0
	for event_id in NEW_EVENTS:
		seed_index += 1
		var excluded := []
		for offer_id in all_offer_ids:
			if offer_id != event_id:
				excluded.append(offer_id)
		var excluded_snapshot: Array = excluded.duplicate()
		var wallet := FUNDED_WALLET.duplicate(true)
		var wallet_snapshot: Dictionary = wallet.duplicate(true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7100 + seed_index
		var res := service.select_stitched_survivor_event_with_preview(
			rng, [], excluded, wallet)
		var expected_record := _authored(event_id)
		_check(res.get("ok") == true and res.get("event") == expected_record,
			"dynamic exclusions isolate the target event: " + event_id)
		_check(res.get("event", {}).get("id") == event_id,
			"selection names the target crossroad: " + event_id)
		var expected_preview := RunEventChoice.new(expected_record).preview_wallet_choices(wallet)
		_check(res.get("preview") == expected_preview,
			"selection preview matches an authentic RunEventChoice preview: " + event_id)
		var pool := _expected_actionable(service, [], excluded, wallet)
		_check(pool == [event_id],
			"the dynamically derived actionable pool is exactly the target: " + event_id)
		var oracle := RandomNumberGenerator.new()
		oracle.seed = 7100 + seed_index
		oracle.randi_range(0, pool.size() - 1)
		_check(rng.state == oracle.state,
			"successful selection consumes exactly one pool-sized draw: " + event_id)
		var rng_replay := RandomNumberGenerator.new()
		rng_replay.seed = 7100 + seed_index
		var replay := service.select_stitched_survivor_event_with_preview(
			rng_replay, [], excluded, wallet)
		_check(replay == res,
			"same seed and exclusions replay identically: " + event_id)
		_check(wallet == wallet_snapshot and excluded == excluded_snapshot,
			"selection mutates neither the caller wallet nor exclusions: " + event_id)
	# A lost required hero is never selected, even as the only candidate.
	var warden_only_excluded := []
	for offer_id in all_offer_ids:
		if offer_id != "v3_warden_oxblood_shield_clock":
			warden_only_excluded.append(offer_id)
	var rng_lost := RandomNumberGenerator.new()
	rng_lost.seed = 7201
	var state_lost := rng_lost.state
	_check(service.select_stitched_survivor_event_with_preview(rng_lost,
			["warden"], warden_only_excluded, FUNDED_WALLET.duplicate(true))
		== {"ok": false, "event": {}, "preview": {}}
		and rng_lost.state == state_lost,
		"a lost Warden rejects the Warden-only pool with zero draws")
	# LOST ['warden'] still selects the surviving crossroads.
	var seamstress_only_excluded := []
	for offer_id in all_offer_ids:
		if offer_id != "v3_seamstress_crimson_shadow_choir":
			seamstress_only_excluded.append(offer_id)
	var rng_survivor := RandomNumberGenerator.new()
	rng_survivor.seed = 7202
	var res_survivor := service.select_stitched_survivor_event_with_preview(
		rng_survivor, ["warden"], seamstress_only_excluded, FUNDED_WALLET.duplicate(true))
	_check(res_survivor.get("ok") == true
		and res_survivor.get("event", {}).get("id") == "v3_seamstress_crimson_shadow_choir",
		"LOST ['warden'] still selects the surviving Seamstress crossroad")
	# An exhausted pool rejects without advancing RNG.
	var rng_exhausted := RandomNumberGenerator.new()
	rng_exhausted.seed = 7203
	var state_exhausted := rng_exhausted.state
	_check(service.select_stitched_survivor_event_with_preview(rng_exhausted,
			[], all_offer_ids, FUNDED_WALLET.duplicate(true))
		== {"ok": false, "event": {}, "preview": {}}
		and rng_exhausted.state == state_exhausted,
		"excluding every current offer rejects with zero draws")
	# Zero wallet: the Warden and Yarn free choices stay actionable while the
	# Seamstress crossroad is Leave-only.
	var zero_pool := _expected_actionable(service, [], [], ZERO_WALLET.duplicate(true))
	_check(zero_pool.has("v3_warden_oxblood_shield_clock")
		and zero_pool.has("v3_yarn_ranger_moonbolas_windharp"),
		"zero-wallet pool keeps the Warden and Yarn crossroads actionable")
	_check(not zero_pool.has("v3_seamstress_crimson_shadow_choir"),
		"zero-wallet pool omits the Leave-only Seamstress crossroad")
	for actionable_id in ["v3_warden_oxblood_shield_clock",
			"v3_yarn_ranger_moonbolas_windharp"]:
		var target_only_excluded := []
		for offer_id in all_offer_ids:
			if offer_id != actionable_id:
				target_only_excluded.append(offer_id)
		var rng_zero := RandomNumberGenerator.new()
		rng_zero.seed = 7300
		var res_zero := service.select_stitched_survivor_event_with_preview(
			rng_zero, [], target_only_excluded, ZERO_WALLET.duplicate(true))
		_check(res_zero.get("ok") == true
			and res_zero.get("event", {}).get("id") == actionable_id,
			"zero-wallet selection reaches the free-choice crossroad: " + actionable_id)
	var rng_leave_only := RandomNumberGenerator.new()
	rng_leave_only.seed = 7301
	var state_leave_only := rng_leave_only.state
	_check(service.select_stitched_survivor_event_with_preview(rng_leave_only,
			[], seamstress_only_excluded, ZERO_WALLET.duplicate(true))
		== {"ok": false, "event": {}, "preview": {}}
		and rng_leave_only.state == state_leave_only,
		"the Leave-only Seamstress pool rejects with zero draws on a zero wallet")
