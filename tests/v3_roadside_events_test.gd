extends SceneTree
## Deterministic headless test for V3-4 roadside event pack.
##
## The catalog is additive: every authored record keeps its own ID and this test
## checks required records by ID instead of asserting a whole-catalog total or a
## global ordering. Each required event is checked for its exact presentation,
## its three uniquely identified choices (including a free Leave) and both
## signed wallet fields, then driven through the shipped RunEventChoice for a
## funded and a zero wallet.
##
## Selector coverage proves the shipped admission end to end: a fresh uninjected
## RunM04EventRotation serves the generic M04 records, every merged lantern tale
## and every roadside tale exactly once while quiet_spool stays special;
## the eligible pool equals an independently derived sorted oracle of both
## shipped catalogs; a seeded selection consumes exactly one range draw and
## replays; excluding every other ID selects a named roadside record; an
## exhausted or malformed call consumes no RNG; and a broken roadside source
## rejects the whole default merge instead of offering a partial pool.
##
## The gothic batch section below adds an independent per-ID table for the six
## newest roadside tales (verbatim story, captions and signed deltas), then drives
## funded previews and claims, an empty-purse debit refusal followed by the legal
## free Leave, replay refusal, and a one-draw forced selection through the default
## selector. It never asserts a catalog total or a full ordered ID list.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const M04_EVENTS_PATH := "res://data/events/m04_events.json"

const QUIET_SPOOL_ID := "quiet_spool"

## The original generic base plus the accepted six lantern-haunted tales. They
## are named here independently of the production selector constants.
const REQUIRED_GENERIC_IDS := [
	"button_trail",
	"loose_seam",
	"thimble_well",
	"frayed_signpost",
	"needle_gate",
	"quilting_bee",
	"estate_sale",
]

const LANTERN_EVENT_IDS := [
	"lantern_moth_clearing",
	"patchwork_ferry",
	"spool_clocktower",
	"ragpicker_cart",
	"quilt_bridge",
	"button_moon_festival",
]

const EXPECTED := {
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"description": "A soaked quilt bridge stretching over a ravine.",
		"choices": ["salvage_hems", "trade_fare", "take_detour"],
		"captions": {
			"salvage_hems": "Salvage loose hems (+1 scrap)",
			"trade_fare": "Trade fare for threads (-12 gold, +2 scraps)",
			"take_detour": "Take a detour (Leave)"
		},
		"outcomes": {
			"salvage_hems": {"gold": 0, "scraps": 1},
			"trade_fare": {"gold": -12, "scraps": 2},
			"take_detour": {"gold": 0, "scraps": 0}
		}
	},
	"v3_puppet_box_office": {
		"title": "The Puppet Box Office",
		"description": "Rag puppets wait under a patchwork theatre awning.",
		"choices": ["perform", "restring", "applaud"],
		"captions": {
			"perform": "Perform a short act (+9 gold)",
			"restring": "Restring the puppets (+24 gold, -2 scraps)",
			"applaud": "Applaud and move on"
		},
		"outcomes": {
			"perform": {"gold": 9, "scraps": 0},
			"restring": {"gold": 24, "scraps": -2},
			"applaud": {"gold": 0, "scraps": 0}
		}
	},
	"v3_mismatched_mittens": {
		"title": "The Mismatched Mittens",
		"description": "A merchant untangling sewn pairs of mismatched mittens.",
		"choices": ["untangle", "trade_copper", "sell_pair"],
		"captions": {
			"untangle": "Help untangle pairs (+1 scrap)",
			"trade_copper": "Trade copper for threads (-15 gold, +2 scraps)",
			"sell_pair": "Sell a matched pair (+18 gold, -1 scrap)"
		},
		"outcomes": {
			"untangle": {"gold": 0, "scraps": 1},
			"trade_copper": {"gold": -15, "scraps": 2},
			"sell_pair": {"gold": 18, "scraps": -1}
		}
	},
	"v3_coil_and_crow": {
		"title": "The Coil and Crow",
		"description": "A crow guarding a copper-coloured thread wheel.",
		"choices": ["chase_crow", "buy_coil", "back_away"],
		"captions": {
			"chase_crow": "Chase the crow away (+6 gold)",
			"buy_coil": "Buy the thread coil (-20 gold, +3 scraps)",
			"back_away": "Back away slowly"
		},
		"outcomes": {
			"chase_crow": {"gold": 6, "scraps": 0},
			"buy_coil": {"gold": -20, "scraps": 3},
			"back_away": {"gold": 0, "scraps": 0}
		}
	},
	"v3_patchwork_lighthouse": {
		"title": "The Patchwork Lighthouse",
		"description": "Fabric fog gathers around a dim stitched beacon.",
		"choices": ["gather_threads", "repair_beacon", "pass_by"],
		"captions": {
			"gather_threads": "Gather threads in the fog (+1 scrap)",
			"repair_beacon": "Repair the beacon (+26 gold, -2 scraps)",
			"pass_by": "Pass by quietly"
		},
		"outcomes": {
			"gather_threads": {"gold": 0, "scraps": 1},
			"repair_beacon": {"gold": 26, "scraps": -2},
			"pass_by": {"gold": 0, "scraps": 0}
		}
	},
	"v3_button_orchard": {
		"title": "The Button Orchard",
		"description": "Brass buttons hang heavily on felt branches.",
		"choices": ["pick_buttons", "ribbon_trade", "sell_harvest"],
		"captions": {
			"pick_buttons": "Pick some buttons (+1 scrap)",
			"ribbon_trade": "Trade for ribbons (-14 gold, +2 scraps)",
			"sell_harvest": "Sell the harvest (+20 gold, -1 scrap)"
		},
		"outcomes": {
			"pick_buttons": {"gold": 0, "scraps": 1},
			"ribbon_trade": {"gold": -14, "scraps": 2},
			"sell_harvest": {"gold": 20, "scraps": -1}
		}
	},
	"v3_lacework_railway": {
		"title": "The Lacework Railway",
		"description": "A railway platform is suspended on braids of lace, its brass bell ringing in the fog.",
		"choices": ["mend_platform", "buy_spool_ticket", "board_silently"],
		"captions": {
			"mend_platform": "Mend a fraying platform braid (+1 scrap)",
			"buy_spool_ticket": "Buy a spool ticket (-18 gold, +2 scraps)",
			"board_silently": "Board silently (Leave)"
		},
		"outcomes": {
			"mend_platform": {"gold": 0, "scraps": 1},
			"buy_spool_ticket": {"gold": -18, "scraps": 2},
			"board_silently": {"gold": 0, "scraps": 0}
		}
	},
	"v3_moonshadow_tailor": {
		"title": "The Moonshadow Tailor",
		"description": "A tailor in a patched top hat fits velvet shadows beneath a button moon.",
		"choices": ["deliver_cloth", "trade_salvage", "refuse_fitting"],
		"captions": {
			"deliver_cloth": "Deliver washed cloth (+11 gold)",
			"trade_salvage": "Trade a salvaged scrap (+19 gold, -1 scrap)",
			"refuse_fitting": "Refuse a fitting (Leave)"
		},
		"outcomes": {
			"deliver_cloth": {"gold": 11, "scraps": 0},
			"trade_salvage": {"gold": 19, "scraps": -1},
			"refuse_fitting": {"gold": 0, "scraps": 0}
		}
	},
	"v3_sleeping_thimble_giant": {
		"title": "The Sleeping Thimble Giant",
		"description": "A giant sewing thimble snores beside a sewing-table hill, spilling copper shanks.",
		"choices": ["gather_shanks", "polish_thimble", "tiptoe_away"],
		"captions": {
			"gather_shanks": "Gather loose copper shanks (+1 scrap)",
			"polish_thimble": "Polish the thimble (+31 gold, -2 scraps)",
			"tiptoe_away": "Tiptoe away (Leave)"
		},
		"outcomes": {
			"gather_shanks": {"gold": 0, "scraps": 1},
			"polish_thimble": {"gold": 31, "scraps": -2},
			"tiptoe_away": {"gold": 0, "scraps": 0}
		}
	},
	"v3_needlefall_star": {
		"title": "The Needlefall Star",
		"description": "A falling star has pinned a silver needle through a midnight quilt field.",
		"choices": ["pocket_silver", "buy_starthread", "leave_star"],
		"captions": {
			"pocket_silver": "Pocket a silver sliver (+8 gold)",
			"buy_starthread": "Buy star-thread (-16 gold, +3 scraps)",
			"leave_star": "Leave the pin shining (Leave)"
		},
		"outcomes": {
			"pocket_silver": {"gold": 8, "scraps": 0},
			"buy_starthread": {"gold": -16, "scraps": 3},
			"leave_star": {"gold": 0, "scraps": 0}
		}
	},
	"v3_jackdaw_stitchmarket": {
		"title": "The Jackdaw Stitchmarket",
		"description": "Button-eyed jackdaws barter embroidery in a market strung between dark branches.",
		"choices": ["exchange_buttons", "trade_thread", "purse_closed"],
		"captions": {
			"exchange_buttons": "Exchange found buttons (+13 gold)",
			"trade_thread": "Trade a spare scrap for lace (+16 gold, -1 scrap)",
			"purse_closed": "Keep your purse closed (Leave)"
		},
		"outcomes": {
			"exchange_buttons": {"gold": 13, "scraps": 0},
			"trade_thread": {"gold": 16, "scraps": -1},
			"purse_closed": {"gold": 0, "scraps": 0}
		}
	},
	"v3_dreaming_quilt_fair": {
		"title": "The Dreaming Quilt Fair",
		"description": "Somnolent ragdolls parade under embroidered pennants and glowing stitched lanterns.",
		"choices": ["repair_pennants", "auction_trim", "watch_parade"],
		"captions": {
			"repair_pennants": "Repair worn pennants (+2 scraps)",
			"auction_trim": "Auction rare trim (+24 gold, -2 scraps)",
			"watch_parade": "Watch the procession (Leave)"
		},
		"outcomes": {
			"repair_pennants": {"gold": 0, "scraps": 2},
			"auction_trim": {"gold": 24, "scraps": -2},
			"watch_parade": {"gold": 0, "scraps": 0}
		}
	}
}

## The six V3-4 additions authored by this task: each closes with a free Leave.
const NEW_EVENT_IDS := [
	"v3_lacework_railway",
	"v3_moonshadow_tailor",
	"v3_sleeping_thimble_giant",
	"v3_needlefall_star",
	"v3_jackdaw_stitchmarket",
	"v3_dreaming_quilt_fair",
]

## The six gothic roadside tales appended by this task. This is an independent
## copy of the authored story, captions and signed outcomes; it never reads the
## production catalog or the selector's constants back as its oracle, and it
## asserts per-ID membership rather than a catalog total or a full ID list.

## The trade batch section adds a second independent per-ID table for the six
## newest gothic trade tales outside the source table above; it repeats the same
## funded/empty-purse claim, replay and forced-selection checks.
const GOTHIC_EXPECTED := {
	"v3_mothlace_clock": {
		"title": "The Mothlace Clock",
		"description": "A stitched clock ticks beneath a guttering candle, its moth-shaped hands shedding dusty lace.",
		"choices": [
			{"id": "wind_bell", "text": "Wind the brass bell (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "buy_cog_thread", "text": "Buy cog-thread (-18 gold, +2 scraps)", "gold": -18, "scraps": 2},
			{"id": "ignore_clock", "text": "Ignore the ticking clock (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_buttonbone_aviary": {
		"title": "The Buttonbone Aviary",
		"description": "Velvet-winged button-eyed birds hop along brass perches, hoarding shiny ribbons in their stitched nest.",
		"choices": [
			{"id": "sort_feathers", "text": "Sort fallen feathers (+11 gold)", "gold": 11, "scraps": 0},
			{"id": "trade_gilded_feather", "text": "Trade a gilded feather (+21 gold, -1 scrap)", "gold": 21, "scraps": -1},
			{"id": "leave_aviary", "text": "Leave the aviary (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_ashen_quilt_greenhouse": {
		"title": "The Ashen Quilt Greenhouse",
		"description": "Needle-leaf sprouts glow through moonlit sewn glass while pale ash drifts between the quilted beds.",
		"choices": [
			{"id": "gather_shoots", "text": "Gather glowing shoots (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "sell_lantern_soil", "text": "Sell lantern soil (+27 gold, -2 scraps)", "gold": 27, "scraps": -2},
			{"id": "close_gate", "text": "Close the greenhouse gate (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_ribbon_shadow_circus": {
		"title": "The Ribbon-Shadow Circus",
		"description": "Rag puppets cast giant shadows against a damask tent while their trailing ribbons stir the candle smoke.",
		"choices": [
			{"id": "mend_marquee", "text": "Mend the striped marquee (+14 gold)", "gold": 14, "scraps": 0},
			{"id": "buy_curtain_thread", "text": "Buy curtain thread (-20 gold, +3 scraps)", "gold": -20, "scraps": 3},
			{"id": "pass_circus", "text": "Pass the silent circus (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_velvet_patch_pier": {
		"title": "The Velvet Patch Pier",
		"description": "A lopsided pier creaks under patchwork lanterns, its velvet planks stitched to a swelling ink-black tide.",
		"choices": [
			{"id": "collect_hooks", "text": "Collect loose hooks (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "repair_moorings", "text": "Repair the moorings (+23 gold, -1 scrap)", "gold": 23, "scraps": -1},
			{"id": "walk_from_pier", "text": "Walk back from the pier (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_lullaby_stitch_chapel": {
		"title": "The Lullaby Stitch Chapel",
		"description": "Tiny thread bells hum under moss-green stitched rafters while wax candles gutter in the draft.",
		"choices": [
			{"id": "clean_lanterns", "text": "Clean the tiny lanterns (+9 gold)", "gold": 9, "scraps": 0},
			{"id": "trade_bells", "text": "Trade for thread bells (-12 gold, +2 scraps)", "gold": -12, "scraps": 2},
			{"id": "leave_chapel", "text": "Leave the humming chapel (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

const GOTHIC_EVENT_IDS := [
	"v3_mothlace_clock",
	"v3_buttonbone_aviary",
	"v3_ashen_quilt_greenhouse",
	"v3_ribbon_shadow_circus",
	"v3_velvet_patch_pier",
	"v3_lullaby_stitch_chapel",
]

## Independent per-ID seeds for the forced single-eligible selection replay.
## With one eligible ID the seed cannot pin a catalog position.
const GOTHIC_SEEDS := {
	"v3_mothlace_clock": 1020261,
	"v3_buttonbone_aviary": 1020262,
	"v3_ashen_quilt_greenhouse": 1020263,
	"v3_ribbon_shadow_circus": 1020264,
	"v3_velvet_patch_pier": 1020265,
	"v3_lullaby_stitch_chapel": 1020266,
}

## The six gothic trade tales appended by this task. As with the earlier gothic
## table this is an independent verbatim copy of the authored story, captions and
## signed outcomes: it never reads the shipped catalog or the selector constants
## back as its oracle, and it asserts per-ID membership rather than a catalog
## total or a full ordered ID list. The third choice of every tale is a free Leave.
const TRADE_EXPECTED := {
	"v3_blacklace_marionette_choir": {
		"title": "The Blacklace Marionette Choir",
		"description": "Round stitched singers hang from velvet cords beneath a bruised-plum stage canopy.",
		"choices": [
			{"id": "retie_cords", "text": "Retie the marionettes' cords (spend 2 scraps, earn 33 gold)", "gold": 33, "scraps": -2},
			{"id": "buy_spool_cord", "text": "Buy a bundle of spare cords (pay 16 gold, gain 3 scraps)", "gold": -16, "scraps": 3},
			{"id": "leave_choir", "text": "Leave the choir singing (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_copper_moth_almanac": {
		"title": "The Copper-Moth Almanac",
		"description": "A huge button-eyed moth keeps weather maps folded inside its quilted wings.",
		"choices": [
			{"id": "ink_forecast", "text": "Ink tomorrow's sky (earn 11 gold)", "gold": 11, "scraps": 0},
			{"id": "trade_silk_pages", "text": "Trade for silk pages (pay 19 gold, gain 3 scraps)", "gold": -19, "scraps": 3},
			{"id": "close_almanac", "text": "Close the almanac (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_oxblood_pin_bazaar": {
		"title": "The Oxblood Pin Bazaar",
		"description": "A stocky pincushion keeper weighs blunt silver pins under dripping lanterns.",
		"choices": [
			{"id": "sell_pin_cache", "text": "Sell recovered pins (spend 3 scraps, gain 42 gold)", "gold": 42, "scraps": -3},
			{"id": "buy_woven_sheath", "text": "Buy a woven pin sheath (pay 12 gold, gain 2 scraps)", "gold": -12, "scraps": 2},
			{"id": "leave_bazaar", "text": "Leave the bazaar (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_mossveil_hollow_bridge": {
		"title": "The Mossveil Hollow Bridge",
		"description": "A soft giant with button knuckles keeps a bridge of braided thread from unraveling.",
		"choices": [
			{"id": "mend_bridge", "text": "Mend the loose braid (earn 2 scraps)", "gold": 0, "scraps": 2},
			{"id": "claim_toll_share", "text": "Reclaim old toll buttons (spend 1 scrap, gain 17 gold)", "gold": 17, "scraps": -1},
			{"id": "leave_bridge", "text": "Leave the bridge (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_bonecream_lantern_caravan": {
		"title": "The Bone-Cream Lantern Caravan",
		"description": "Three lantern-dolls carry a moonlit wagon stitched from patterned pillowcases.",
		"choices": [
			{"id": "guide_wagon", "text": "Guide the wagon past the marsh (gain 15 gold)", "gold": 15, "scraps": 0},
			{"id": "purchase_wicks", "text": "Purchase fresh thread wicks (pay 22 gold, gain 4 scraps)", "gold": -22, "scraps": 4},
			{"id": "leave_caravan", "text": "Leave the caravan (Leave)", "gold": 0, "scraps": 0},
		],
	},
	"v3_saffron_button_harvest": {
		"title": "The Saffron Button Harvest",
		"description": "Plump scarecrow dolls gather brass buttons from black velvet pumpkin vines.",
		"choices": [
			{"id": "thread_baskets", "text": "Thread the baskets (gain 2 scraps)", "gold": 0, "scraps": 2},
			{"id": "trade_harvest", "text": "Trade the button harvest (spend 2 scraps, gain 29 gold)", "gold": 29, "scraps": -2},
			{"id": "leave_harvest", "text": "Leave the harvest (Leave)", "gold": 0, "scraps": 0},
		],
	},
}

const TRADE_EVENT_IDS := [
	"v3_blacklace_marionette_choir",
	"v3_copper_moth_almanac",
	"v3_oxblood_pin_bazaar",
	"v3_mossveil_hollow_bridge",
	"v3_bonecream_lantern_caravan",
	"v3_saffron_button_harvest",
]

## Independent per-ID seeds for the forced single-eligible selection replay.
## With one eligible ID the seed cannot pin a catalog position.
const TRADE_SEEDS := {
	"v3_blacklace_marionette_choir": 1020271,
	"v3_copper_moth_almanac": 1020272,
	"v3_oxblood_pin_bazaar": 1020273,
	"v3_mossveil_hollow_bridge": 1020274,
	"v3_bonecream_lantern_caravan": 1020275,
	"v3_saffron_button_harvest": 1020276,
}

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run_tests()
	if failures.is_empty():
		print("v3_roadside_events_test: PASS (", checks, " checks)")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("v3_roadside_events_test: FAIL (", checks, " checks)")
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + " opens through FileAccess")
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, path + " parses through JSON")
	if parse_result != OK:
		return {}
	var data: Variant = parser.data
	_check(data is Dictionary, path + " parses to a document object")
	if not data is Dictionary:
		return {}
	return data

func _run_tests() -> void:
	var data: Dictionary = _read_document(EVENTS_PATH)
	if data.is_empty():
		return

	var events: Variant = data.get("events")
	_check(events is Array, "roadside document carries an events array")
	if not events is Array:
		return

	# Unique-ID detection replaces any fixed catalog total: additive authored
	# records may join this catalog without bumping a number here.
	var parsed_events := {}
	var duplicate_ids := []
	for entry in events:
		_check(entry is Dictionary, "every roadside entry is a record object")
		if not entry is Dictionary:
			continue
		var raw_id: Variant = entry.get("id")
		_check(raw_id is String and not (raw_id as String).strip_edges().is_empty(),
			"every roadside record has a nonblank string ID")
		if not raw_id is String:
			continue
		var event_id: String = raw_id
		if parsed_events.has(event_id):
			duplicate_ids.append(event_id)
			continue
		parsed_events[event_id] = entry
	_check(duplicate_ids.is_empty(), "Roadside event IDs are unique: " + str(duplicate_ids))

	for expected_id in EXPECTED:
		_check(parsed_events.has(expected_id), "Found expected ID: " + expected_id)
		if not parsed_events.has(expected_id):
			continue

		var record: Dictionary = parsed_events[expected_id]
		var expected: Dictionary = EXPECTED[expected_id]

		_check(record.get("title", "") == expected["title"], "Matches exact title: " + expected_id)
		_check(record.get("description", "") == expected["description"],
			"Matches exact description: " + expected_id)

		var choices: Array = record.get("choices", [])
		_check(choices.size() == 3, "Has exactly 3 choices: " + expected_id)

		var choice_ids := []
		var clone := RunEventChoice.new(record)
		_check(clone.is_valid(), "Shipped RunEventChoice accepts the authored record: " + expected_id)
		var original_record := record.duplicate(true)
		for choice in choices:
			_check(choice is Dictionary, "Choice is an object: " + expected_id)
			if not choice is Dictionary:
				continue
			var cid: String = choice.get("id", "")
			choice_ids.append(cid)
			_check(choice.keys().size() == 3 and choice.has("id") and choice.has("text")
				and choice.has("outcome"), "Choice carries exactly id/text/outcome: " + expected_id + " -> " + cid)
			_check(choice.get("text", "") == expected["captions"].get(cid, ""),
				"Choice caption is the authored explanation: " + expected_id + " -> " + cid)

			var outcome: Dictionary = choice.get("outcome", {})
			_check(outcome.keys().size() == 2 and outcome.has("gold") and outcome.has("scraps"),
				"Outcome carries exactly signed gold and scraps: " + expected_id + " -> " + cid)
			var expected_outcome: Dictionary = expected["outcomes"].get(cid, {})
			_check(outcome.has("gold") and int(outcome["gold"]) == int(expected_outcome.get("gold", 0))
				and outcome.has("scraps") and int(outcome["scraps"]) == int(expected_outcome.get("scraps", 0)),
				"Matches expected outcome for: " + expected_id + " -> " + cid)

		_check(choice_ids.size() == 3, "Record exposes exactly three choice IDs: " + expected_id)
		var unique_choice_ids := {}
		for cid in choice_ids:
			unique_choice_ids[cid] = true
		_check(unique_choice_ids.size() == choice_ids.size(),
			"Choice IDs are unique inside the record: " + expected_id)
		for cid in expected["choices"]:
			_check(choice_ids.count(cid) == 1, "Expected choice ID present once: " + expected_id + " -> " + cid)

		# Every addition authored by this task keeps a free Leave that costs nothing.
		if expected_id in NEW_EVENT_IDS:
			var free_outcome: Dictionary = expected["outcomes"].get(expected["choices"][2], {})
			_check(int(free_outcome.get("gold", -1)) == 0 and int(free_outcome.get("scraps", -1)) == 0,
				"Third choice is the free Leave: " + expected_id)
			var leave_outcome: Dictionary = record["choices"][2]["outcome"]
			_check(int(leave_outcome["gold"]) == 0 and int(leave_outcome["scraps"]) == 0,
				"Authored third outcome is exactly zero: " + expected_id)

		# Test with wallet {gold: 100, scraps: 5} (sufficient funds)
		var test_wallet := {"gold": 100, "scraps": 5}
		var service_preview := RunEventChoice.new(record)
		var previews: Dictionary = service_preview.preview_wallet_choices(test_wallet)
		_check(previews.get("ok", false), "Preview successful for: " + expected_id)

		for choice in choices:
			var cid: String = choice["id"]
			var outcome: Dictionary = choice["outcome"]
			var expected_gold: int = 100 + int(outcome["gold"])
			var expected_scraps: int = 5 + int(outcome["scraps"])

			# Preview check
			var is_affordable := false
			for p in previews.get("choices", []):
				if p.get("choice_id") == cid:
					is_affordable = p.get("affordable", false)
					_check(int(p.get("gold_delta")) == int(outcome["gold"])
						and int(p.get("scraps_delta")) == int(outcome["scraps"]),
						"Preview reports both signed deltas for: " + cid)
					_check(p.get("wallet", {}) == {"gold": expected_gold, "scraps": expected_scraps},
						"Preview reports exact projected wallet for: " + cid)
					break
			_check(is_affordable, "Choice should be affordable with 100 gold, 5 scraps: " + cid)

			var service_commit := RunEventChoice.new(record)
			var commit_result := service_commit.choose_with_wallet(cid, test_wallet.duplicate(true))
			_check(commit_result.get("ok", false), "Commit successful for: " + cid)

			var new_wallet: Dictionary = commit_result.get("wallet", {})
			_check(int(new_wallet["gold"]) == expected_gold and int(new_wallet["scraps"]) == expected_scraps,
				"Wallet exact match for: " + cid)
			_check(service_commit.is_claimed(), "Service is claimed after commit")
			_check(record == original_record, "Source record unchanged by commit: " + cid)

			var second_commit := service_commit.choose_with_wallet(cid, new_wallet)
			_check(not second_commit.get("ok", true), "Second commit rejected for: " + cid)
			_check(service_commit.get_event() == original_record, "Original record deeply unchanged")
			var tampered: Dictionary = service_commit.get_event()
			tampered["title"] = "tampered"
			tampered["choices"] = []
			_check(service_commit.get_event() != tampered and service_commit.get_event() == original_record,
				"Returned event copy is detached from the authored record: " + cid)

		# Test with wallet {gold: 0, scraps: 0}
		var zero_wallet := {"gold": 0, "scraps": 0}
		var service_zero := RunEventChoice.new(record)
		var previews_zero: Dictionary = service_zero.preview_wallet_choices(zero_wallet)
		for choice in choices:
			var cid: String = choice["id"]
			var outcome: Dictionary = choice["outcome"]
			var requires_payment: bool = outcome["gold"] < 0 or outcome["scraps"] < 0

			var is_affordable := true
			for p in previews_zero.get("choices", []):
				if p.get("choice_id") == cid:
					is_affordable = p.get("affordable", true)
					break

			if requires_payment:
				_check(not is_affordable, "Choice requires payment and is unaffordable at zero: " + cid)
				var service_fail := RunEventChoice.new(record)
				var fail_result := service_fail.choose_with_wallet(cid, zero_wallet)
				_check(not fail_result.get("ok", true), "Commit rejected for insufficient funds: " + cid)
				_check(not service_fail.is_claimed(), "Claim not consumed on failed commit: " + cid)
				_check(fail_result.get("wallet", {}) == zero_wallet,
					"Rejected claim returns the unchanged zero wallet: " + cid)

				# After failure, free choices should still work
				var free_cid := ""
				var expected_free_gold := 0
				var expected_free_scraps := 0
				for c in choices:
					if c["outcome"]["gold"] >= 0 and c["outcome"]["scraps"] >= 0:
						free_cid = c["id"]
						expected_free_gold = int(c["outcome"]["gold"])
						expected_free_scraps = int(c["outcome"]["scraps"])
						break

				if free_cid != "":
					var recover_result := service_fail.choose_with_wallet(free_cid, zero_wallet)
					_check(recover_result.get("ok", false), "Recovered and committed free choice: " + free_cid)
					_check(service_fail.is_claimed(), "Service now claimed")
					var rec_wallet: Dictionary = recover_result.get("wallet", {})
					_check(int(rec_wallet["gold"]) == expected_free_gold
						and int(rec_wallet["scraps"]) == expected_free_scraps,
						"Wallet updated correctly on free choice")
			else:
				_check(is_affordable, "Free choice is affordable at zero: " + cid)

	_check_gothic_roadside_batch()
	_check_trade_roadside_batch()
	_check_injected_selector()
	_check_default_admission()
	_check_default_selection_contract()
	_check_default_merge_failures()

## AC1/AC2/AC3 for the six gothic roadside tales: verbatim authored records with
## three uniquely identified choices and one third-position free Leave, exact
## funded preview and one-shot settlement, a refused signed debit at an empty
## purse followed by its legal free Leave, replay refusal, unchanged definitions,
## wallets and RNG, and admission plus a one-draw seeded selection through the
## default shipped selector. Every assertion is per ID: no catalog total and no
## full ordered list.
func _check_gothic_roadside_batch() -> void:
	var roadside: Dictionary = _read_document(EVENTS_PATH)
	var m04: Dictionary = _read_document(M04_EVENTS_PATH)
	if roadside.is_empty() or m04.is_empty():
		return
	var roadside_snapshot: Dictionary = roadside.duplicate(true)
	var m04_snapshot: Dictionary = m04.duplicate(true)
	var roadside_events: Array = _source_events(roadside)
	var generic_events: Array = _source_events(m04)
	var source_by_id: Dictionary = _records_by_id(roadside_events)
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the default selector validates for the gothic roadside batch")
	if not rotation.is_catalog_valid():
		return
	var listing_snapshot: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() > GOTHIC_EVENT_IDS.size(),
		"the default pool holds more than the gothic batch, so exclusions are meaningful")
	# The earlier shipped roadside examples stay, and the generic and special
	# anchors keep their own homes.
	for anchor_id in ["v3_raincoat_bridge", "v3_velvet_safety_pin_gate"]:
		_check(_matches(roadside_events, anchor_id).size() == 1,
			"the earlier authored roadside anchor stays in the source once: " + anchor_id)
		_check(ids.count(anchor_id) == 1,
			"the earlier authored roadside anchor stays eligible once: " + anchor_id)
	_check(_matches(generic_events, "button_trail").size() == 1,
		"the generic button_trail record stays in its own source catalog")
	_check(ids.count("button_trail") == 1, "the generic button_trail stays eligible once")
	_check(_matches(generic_events, QUIET_SPOOL_ID).size() == 1,
		"the special quiet_spool record stays in its own source catalog")
	_check(not ids.has(QUIET_SPOOL_ID) and _matches(listing_snapshot, QUIET_SPOOL_ID).is_empty(),
		"quiet_spool never joins the gothic default rotation")
	var settlements := 0
	var refusals := 0
	var guard := RandomNumberGenerator.new()
	guard.seed = 181818
	var guard_state: int = guard.state
	for event_id in GOTHIC_EVENT_IDS:
		var contract: Dictionary = GOTHIC_EXPECTED[event_id]
		_check(_matches(roadside_events, event_id).size() == 1,
			"exactly one sourced gothic record for " + event_id)
		var source_record: Dictionary = source_by_id.get(event_id, {})
		var record_snapshot: Dictionary = source_record.duplicate(true)
		_check_gothic_record(source_record, event_id, contract, "source")
		# AC3: the no-argument shipped selector admits the record exactly once and
		# serves the verbatim authored copy.
		var admitted: Array = _matches(listing_snapshot, event_id)
		_check(admitted.size() == 1 and ids.count(event_id) == 1,
			"the default selector admits the gothic tale exactly once: " + event_id)
		if admitted.size() == 1:
			_check(admitted[0] == source_record,
				"the default selector serves the verbatim authored gothic record: " + event_id)
		# AC3: each-ID exclusions force the named tale through the real selector,
		# which must consume exactly one documented range draw.
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id) and excluded.size() == ids.size() - 1,
			"only the named gothic tale stays eligible: " + event_id)
		var seed_value: int = GOTHIC_SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "the forced gothic selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id,
			"the forced gothic selection is the named tale: " + event_id)
		_check(selected == source_record,
			"the forced gothic selection is the authentic authored record: " + event_id)
		_check(rng.state == oracle.state,
			"a gothic selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"the same seed and exclusions replay " + event_id)
		var selected_snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		selected["injected"] = true
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == selected_snapshot and detached.get("event") == source_record,
			"the selected gothic record is a detached authored copy: " + event_id)
		# AC2: wallet play starts from the record the shipped selector handed back.
		var wallet_record: Dictionary = detached.get("event", {})
		_check(wallet_record == source_record,
			"the gothic selector hands back the authentic record for wallet play: " + event_id)
		var funded := {"gold": 100, "scraps": 5}
		var funded_snapshot: Dictionary = funded.duplicate(true)
		var zero := {"gold": 0, "scraps": 0}
		var zero_snapshot: Dictionary = zero.duplicate(true)
		var forecast := RunEventChoice.new(wallet_record)
		_check(forecast.is_valid() and not forecast.is_claimed(),
			"the admitted gothic record is a fresh valid choice service: " + event_id)
		var preview: Dictionary = forecast.preview_wallet_choices(funded)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"a funded gothic preview succeeds: " + event_id)
		var rows: Dictionary = _gothic_preview_rows(preview)
		_check(rows.size() == 3, "a funded gothic preview lists all three choices: " + event_id)
		_check(guard.state == guard_state,
			"a funded gothic preview never touches the run RNG: " + event_id)
		var free_def: Dictionary = {}
		var free_ids: Array = []
		var debit_ids: Array = []
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			if int(definition["gold"]) == 0 and int(definition["scraps"]) == 0:
				free_def = definition
				free_ids.append(definition["id"])
			if int(definition["gold"]) < 0 or int(definition["scraps"]) < 0:
				debit_ids.append(definition["id"])
		_check(free_ids.size() == 1 and free_ids[0] == contract["choices"][2]["id"],
			"the third gothic choice is the only free Leave: " + event_id)
		_check(debit_ids.size() == 1, "the gothic tale prices exactly one choice: " + event_id)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var gold_delta: int = definition["gold"]
			var scraps_delta: int = definition["scraps"]
			var after := {"gold": 100 + gold_delta, "scraps": 5 + scraps_delta}
			var row: Dictionary = rows.get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"the gothic preview reports the authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"the gothic preview forecasts the exact funded balance: " + event_id + " / " + choice_id)
			var committed := RunEventChoice.new(wallet_record)
			var receipt := committed.choose_with_wallet(choice_id, funded)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": after,
			}, "the funded gothic claim settles the authored deltas once: " + event_id + " / " + choice_id)
			settlements += 1
			_check(committed.is_claimed() and not committed.is_valid(),
				"the funded gothic claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay_claim := committed.choose_with_wallet(choice_id, funded)
			_check(replay_claim == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": funded,
			}, "the settled gothic claim cannot be replayed: " + event_id + " / " + choice_id)
			var alternate_id := choice_id
			for other_def in contract["choices"]:
				var alternate: Dictionary = other_def
				if alternate["id"] != choice_id:
					alternate_id = alternate["id"]
					break
			_check(committed.choose_with_wallet(alternate_id, funded).get("ok") == false,
				"no alternate gothic choice claims a spent visit: " + event_id + " / " + choice_id)
			_check(committed.preview_wallet_choices(funded).get("ok") == false,
				"a spent gothic visit offers no further preview: " + event_id + " / " + choice_id)
		# AC2: an unfunded signed debit is refused without consuming the visit, and
		# the same visit still settles its actual free Leave exactly once.
		var scarce := RunEventChoice.new(wallet_record)
		var scarce_rows: Dictionary = _gothic_preview_rows(scarce.preview_wallet_choices(zero))
		_check(scarce_rows.size() == 3,
			"an empty-purse gothic preview lists all three choices: " + event_id)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var paid := int(definition["gold"]) < 0 or int(definition["scraps"]) < 0
			_check(scarce_rows.get(choice_id, {}).get("affordable") == (not paid),
				"zero-purse gothic affordability matches the signed outcome: "
				+ event_id + " / " + choice_id)
		var debit_id: String = debit_ids[0]
		var denied := scarce.choose_with_wallet(debit_id, zero)
		_check(denied == {
			"ok": false, "event_id": "", "choice_id": "", "wallet": zero,
		}, "an unfunded gothic debit is refused: " + event_id)
		refusals += 1
		_check(not scarce.is_claimed() and scarce.is_valid(),
			"the refused gothic debit leaves the visit open: " + event_id)
		_check(guard.state == guard_state,
			"a refused gothic debit never touches the run RNG: " + event_id)
		var leave_id: String = free_def["id"]
		var leave := scarce.choose_with_wallet(leave_id, zero)
		_check(leave == {
			"ok": true, "event_id": event_id, "choice_id": leave_id, "wallet": zero,
		}, "the same gothic visit still settles its free Leave: " + event_id)
		_check(scarce.is_claimed() and not scarce.is_valid(),
			"the free Leave consumes the gothic visit: " + event_id)
		var leave_replay := scarce.choose_with_wallet(leave_id, zero)
		_check(leave_replay == {
			"ok": false, "event_id": "", "choice_id": "", "wallet": zero,
		}, "the settled gothic free Leave cannot be replayed: " + event_id)
		var swapped := scarce.choose_with_wallet(debit_id, zero)
		_check(swapped.get("ok") == false and swapped.get("wallet") == zero,
			"no debit claims a spent gothic visit: " + event_id)
		_check(funded == funded_snapshot and zero == zero_snapshot,
			"the caller's wallets are unchanged by gothic wallet play: " + event_id)
		_check(source_record == record_snapshot,
			"the authored gothic definition is unchanged by wallet play: " + event_id)
		_check(guard.state == guard_state,
			"gothic previews, claims and refusals never touch the run RNG: " + event_id)
	# A non-vacuous batch: six events, eighteen authored choices, one price each.
	_check(GOTHIC_EXPECTED.size() == 6 and GOTHIC_EVENT_IDS.size() == 6,
		"the independent gothic table covers six events")
	_check(settlements == 18, "every gothic choice settles once when funded")
	_check(refusals == 6, "every gothic priced choice is refused at an empty purse")
	_check(guard.state == guard_state, "the gothic batch never touches the run RNG")
	_check(rotation.get_generic_events() == listing_snapshot,
		"gothic wallet play never mutates the selector listing")
	_check(roadside == roadside_snapshot and m04 == m04_snapshot,
		"gothic flows never mutate either shipped source catalog")

## AC1/AC2/AC3 for the six gothic trade tales appended by this task: verbatim
## authored records with three uniquely identified choices and one third-position
## free Leave, exact funded preview and one-shot settlement, a refused signed
## debit at an empty purse followed by its legal free Leave, a refused replay,
## unchanged definitions/wallets/RNG, and admission plus a one-draw forced
## selection through the default shipped selector. Every assertion is per ID: no
## catalog total and no full ordered list.
func _check_trade_roadside_batch() -> void:
	var roadside: Dictionary = _read_document(EVENTS_PATH)
	var m04: Dictionary = _read_document(M04_EVENTS_PATH)
	if roadside.is_empty() or m04.is_empty():
		return
	var roadside_snapshot: Dictionary = roadside.duplicate(true)
	var m04_snapshot: Dictionary = m04.duplicate(true)
	var roadside_events: Array = _source_events(roadside)
	var generic_by_id: Dictionary = _records_by_id(_source_events(m04))
	var source_by_id: Dictionary = _records_by_id(roadside_events)
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the default selector validates for the six trade tales")
	if not rotation.is_catalog_valid():
		return
	var listing_snapshot: Array = rotation.get_generic_events()
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() > TRADE_EVENT_IDS.size(),
		"the default pool holds more than the trade batch, so exclusions are meaningful")
	var guard := RandomNumberGenerator.new()
	guard.seed = 303030
	var guard_state: int = guard.state
	var settlements := 0
	var refusals := 0
	for event_id in TRADE_EVENT_IDS:
		var contract: Dictionary = TRADE_EXPECTED[event_id]
		_check(not generic_by_id.has(event_id),
			"the trade tale never reuses a generic event ID: " + event_id)
		_check(_matches(roadside_events, event_id).size() == 1,
			"exactly one sourced trade record for " + event_id)
		var source_record: Dictionary = source_by_id.get(event_id, {})
		var record_snapshot: Dictionary = source_record.duplicate(true)
		_check_gothic_record(source_record, event_id, contract, "shipped")
		var admitted: Array = _matches(listing_snapshot, event_id)
		_check(admitted.size() == 1 and ids.count(event_id) == 1,
			"the default selector admits the trade tale exactly once: " + event_id)
		if admitted.size() == 1:
			_check(admitted[0] == source_record,
				"the default selector serves the verbatim authored trade record: " + event_id)
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id) and excluded.size() == ids.size() - 1,
			"only the named trade tale stays eligible: " + event_id)
		var seed_value: int = TRADE_SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "the forced trade selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id,
			"the forced trade selection is the named tale: " + event_id)
		_check(selected == source_record,
			"the forced trade selection is the authentic authored record: " + event_id)
		_check(rng.state == oracle.state,
			"a trade selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"the same seed and exclusions replay " + event_id)
		var selected_snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		selected["injected"] = true
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = seed_value
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == selected_snapshot and detached.get("event") == source_record,
			"the selected trade record is a detached authored copy: " + event_id)
		var wallet_record: Dictionary = detached.get("event", {})
		_check(wallet_record == source_record,
			"the trade selector hands back the authentic record for wallet play: " + event_id)
		var funded := {"gold": 100, "scraps": 5}
		var funded_snapshot: Dictionary = funded.duplicate(true)
		var zero := {"gold": 0, "scraps": 0}
		var zero_snapshot: Dictionary = zero.duplicate(true)
		var forecast := RunEventChoice.new(wallet_record)
		_check(forecast.is_valid() and not forecast.is_claimed(),
			"the admitted trade record is a fresh valid choice service: " + event_id)
		var preview: Dictionary = forecast.preview_wallet_choices(funded)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"a funded trade preview succeeds: " + event_id)
		var rows: Dictionary = _gothic_preview_rows(preview)
		_check(rows.size() == 3, "a funded trade preview lists all three choices: " + event_id)
		_check(guard.state == guard_state,
			"a funded trade preview never touches the run RNG: " + event_id)
		var free_def: Dictionary = {}
		var free_ids: Array = []
		var debit_ids: Array = []
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			if int(definition["gold"]) == 0 and int(definition["scraps"]) == 0:
				free_def = definition
				free_ids.append(definition["id"])
			if int(definition["gold"]) < 0 or int(definition["scraps"]) < 0:
				debit_ids.append(definition["id"])
		_check(free_ids.size() == 1 and free_ids[0] == contract["choices"][2]["id"],
			"the third trade choice is the only free Leave: " + event_id)
		_check(debit_ids.size() >= 1, "the trade tale prices at least one choice: " + event_id)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var gold_delta: int = definition["gold"]
			var scraps_delta: int = definition["scraps"]
			var after := {"gold": 100 + gold_delta, "scraps": 5 + scraps_delta}
			var row: Dictionary = rows.get(choice_id, {})
			_check(row.get("gold_delta") == gold_delta and row.get("scraps_delta") == scraps_delta,
				"the trade preview reports the authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"the trade preview forecasts the exact funded balance: " + event_id + " / " + choice_id)
			var committed := RunEventChoice.new(wallet_record)
			var receipt := committed.choose_with_wallet(choice_id, funded)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": after,
			}, "the funded trade claim settles the authored deltas once: " + event_id + " / " + choice_id)
			settlements += 1
			_check(committed.is_claimed() and not committed.is_valid(),
				"the funded trade claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay_claim := committed.choose_with_wallet(choice_id, funded)
			_check(replay_claim == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": funded,
			}, "the settled trade claim cannot be replayed: " + event_id + " / " + choice_id)
			var alternate_id := choice_id
			for other_def in contract["choices"]:
				var alternate: Dictionary = other_def
				if alternate["id"] != choice_id:
					alternate_id = alternate["id"]
					break
			_check(committed.choose_with_wallet(alternate_id, funded).get("ok") == false,
				"no alternate trade choice claims a spent visit: " + event_id + " / " + choice_id)
			_check(committed.preview_wallet_choices(funded).get("ok") == false,
				"a spent trade visit offers no further preview: " + event_id + " / " + choice_id)
		# An unfunded signed debit is refused without consuming the visit, and the
		# same visit still settles its actual free Leave exactly once.
		var scarce := RunEventChoice.new(wallet_record)
		var scarce_rows: Dictionary = _gothic_preview_rows(scarce.preview_wallet_choices(zero))
		_check(scarce_rows.size() == 3,
			"an empty-purse trade preview lists all three choices: " + event_id)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var paid := int(definition["gold"]) < 0 or int(definition["scraps"]) < 0
			_check(scarce_rows.get(choice_id, {}).get("affordable") == (not paid),
				"zero-purse trade affordability matches the signed outcome: "
				+ event_id + " / " + choice_id)
		var debit_id: String = debit_ids[0]
		for paid_id in debit_ids:
			var denied := scarce.choose_with_wallet(paid_id, zero)
			_check(denied == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": zero,
			}, "an unfunded trade debit is refused: " + event_id + " / " + paid_id)
			refusals += 1
			_check(not scarce.is_claimed() and scarce.is_valid(),
				"the refused trade debit leaves the visit open: " + event_id + " / " + paid_id)
			_check(guard.state == guard_state,
				"a refused trade debit never touches the run RNG: " + event_id + " / " + paid_id)
		var leave_id: String = free_def["id"]
		var leave := scarce.choose_with_wallet(leave_id, zero)
		_check(leave == {
			"ok": true, "event_id": event_id, "choice_id": leave_id, "wallet": zero,
		}, "the same trade visit still settles its free Leave: " + event_id)
		_check(scarce.is_claimed() and not scarce.is_valid(),
			"the free Leave consumes the trade visit: " + event_id)
		var leave_replay := scarce.choose_with_wallet(leave_id, zero)
		_check(leave_replay == {
			"ok": false, "event_id": "", "choice_id": "", "wallet": zero,
		}, "the settled trade free Leave cannot be replayed: " + event_id)
		var swapped := scarce.choose_with_wallet(debit_id, zero)
		_check(swapped.get("ok") == false and swapped.get("wallet") == zero,
			"no debit claims a spent trade visit: " + event_id)
		_check(funded == funded_snapshot and zero == zero_snapshot,
			"the caller's wallets are unchanged by trade wallet play: " + event_id)
		_check(source_record == record_snapshot,
			"the authored trade definition is unchanged by wallet play: " + event_id)
		_check(guard.state == guard_state,
			"trade previews, claims and refusals never touch the run RNG: " + event_id)
	# A non-vacuous batch: six events, eighteen authored choices, and at least one
	# signed price per tale. The priced count is derived from the independent table.
	var expected_prices := 0
	for event_id in TRADE_EVENT_IDS:
		for choice_def in TRADE_EXPECTED[event_id]["choices"]:
			var priced: Dictionary = choice_def
			if int(priced["gold"]) < 0 or int(priced["scraps"]) < 0:
				expected_prices += 1
	_check(TRADE_EXPECTED.size() == 6 and TRADE_EVENT_IDS.size() == 6,
		"the independent trade table covers six events")
	_check(settlements == TRADE_EVENT_IDS.size() * 3,
		"every trade choice settles once when funded")
	_check(expected_prices == refusals and refusals >= TRADE_EVENT_IDS.size(),
		"every signed trade price is refused at an empty purse")
	_check(guard.state == guard_state, "the trade batch never touches the run RNG")
	_check(rotation.get_generic_events() == listing_snapshot,
		"trade wallet play never mutates the selector listing")
	_check(roadside == roadside_snapshot and m04 == m04_snapshot,
		"trade flows never mutate either shipped source catalog")

## Verbatim presentation, choice shape and signed deltas against the independent
## gothic table. `origin` only labels failure messages.
func _check_gothic_record(record: Dictionary, event_id: String, contract: Dictionary,
		origin: String) -> void:
	_check(record.size() == 4 and record.has("id") and record.has("title")
		and record.has("description") and record.has("choices"),
		"the " + origin + " gothic record carries exactly id/title/description/choices: " + event_id)
	_check(record.get("id") == event_id, "authored gothic ID: " + origin + " / " + event_id)
	_check(record.get("title") == contract["title"],
		"authored gothic title: " + origin + " / " + event_id)
	_check(record.get("description") == contract["description"],
		"authored gothic description: " + origin + " / " + event_id)
	var choices: Variant = record.get("choices")
	_check(choices is Array, "authored gothic choices array: " + origin + " / " + event_id)
	if not choices is Array:
		return
	_check((choices as Array).size() == 3,
		"exactly three gothic choices: " + origin + " / " + event_id)
	var by_id: Dictionary = {}
	for choice in (choices as Array):
		_check(choice is Dictionary,
			"every gothic choice is an object: " + origin + " / " + event_id)
		if not choice is Dictionary:
			continue
		var entry: Dictionary = choice
		var choice_id: Variant = entry.get("id")
		_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
			"every gothic choice has a nonblank string ID: " + origin + " / " + event_id)
		if not choice_id is String:
			continue
		_check(not by_id.has(choice_id),
			"gothic choice IDs are distinct: " + origin + " / " + event_id + " / " + str(choice_id))
		by_id[choice_id] = entry
	_check(by_id.size() == 3,
		"three distinct gothic choice IDs: " + origin + " / " + event_id)
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		var choice_id: String = definition["id"]
		_check(by_id.has(choice_id),
			"authored gothic choice present: " + origin + " / " + event_id + " / " + choice_id)
		if not by_id.has(choice_id):
			continue
		var entry: Dictionary = by_id[choice_id]
		_check(entry.size() == 3 and entry.has("id") and entry.has("text")
			and entry.has("outcome"),
			"exactly id/text/outcome with no extra mechanics: "
			+ origin + " / " + event_id + " / " + choice_id)
		_check(entry.get("text") == definition["text"],
			"authored gothic caption: " + origin + " / " + event_id + " / " + choice_id)
		var outcome: Variant = entry.get("outcome")
		_check(outcome is Dictionary,
			"gothic outcome is an object: " + origin + " / " + event_id + " / " + choice_id)
		if not outcome is Dictionary:
			continue
		var wallet_outcome: Dictionary = outcome
		_check(wallet_outcome.size() == 2 and wallet_outcome.has("gold")
			and wallet_outcome.has("scraps"),
			"exactly signed gold/scraps outcome keys: "
			+ origin + " / " + event_id + " / " + choice_id)
		# JSON may deliver whole numbers as floats; the authored contract is a
		# whole signed amount either way.
		var gold_amount: Variant = _signed_whole(wallet_outcome.get("gold"))
		var scraps_amount: Variant = _signed_whole(wallet_outcome.get("scraps"))
		_check(gold_amount != null and scraps_amount != null,
			"whole-number gothic outcome amounts: " + origin + " / " + event_id + " / " + choice_id)
		_check(gold_amount == definition["gold"] and scraps_amount == definition["scraps"],
			"authored gothic signed outcome: " + origin + " / " + event_id + " / " + choice_id)

## The ordered preview rows keyed by choice ID, or an empty map for a rejected
## preview. Independent of the selector and the authored source.
func _gothic_preview_rows(preview: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return out
	for entry in entries:
		if entry is Dictionary:
			out[entry["choice_id"]] = entry
	return out

## The authored signed amount as an int, or null when the JSON value is not a
## finite whole number.
func _signed_whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number and absf(number) <= 9007199254740992.0:
			return int(number)
	return null

## An injected catalog is used exactly as passed. The synthetic combination below
## is a genuine injection, and the generic-only injection proves the selector
## never appends the shipped roadside pack to a fixture on its own.
func _check_injected_selector() -> void:
	var m04: Dictionary = _read_document(M04_EVENTS_PATH)
	var roadside: Dictionary = _read_document(EVENTS_PATH)
	if m04.is_empty() or roadside.is_empty():
		return
	var combined: Array = _source_events(m04)
	combined.append_array(_source_events(roadside))
	var rotation := RunM04EventRotation.new({"events": combined})
	_check(rotation.is_catalog_valid(), "Combined catalog validates for the shipped generic rotation")
	if rotation.is_catalog_valid():
		var ids := rotation.get_generic_event_ids()
		for expected_id in EXPECTED:
			_check(ids.count(expected_id) == 1,
				"Roadside event is eligible exactly once in the combined pool: " + expected_id)
			var matches: Array = _matches(rotation.get_generic_events(), expected_id)
			_check(matches.size() == 1 and matches[0].title == EXPECTED[expected_id]["title"]
				and matches[0].description == EXPECTED[expected_id]["description"],
				"Combined pool serves the exact authored roadside record: " + expected_id)
		_check(not ids.has(QUIET_SPOOL_ID), "Quiet Spool stays on its dedicated special route")
	var generic_only := RunM04EventRotation.new(m04)
	_check(generic_only.is_catalog_valid(), "A generic-only injected catalog still validates on its own")
	var generic_ids: Array = generic_only.get_generic_event_ids()
	for expected_id in EXPECTED:
		_check(not generic_ids.has(expected_id),
			"An injected fixture is used exactly as passed, with no roadside pack appended: " + expected_id)

## AC1: a fresh uninjected selector admits the shipped generic records, the
## merged lantern-haunted tales and every roadside tale exactly once, serves the
## verbatim authored records, and never offers the separately routed special.
## Nothing here asserts a fixed pool total or a whole ordered ID list.
func _check_default_admission() -> void:
	var m04: Dictionary = _read_document(M04_EVENTS_PATH)
	var roadside: Dictionary = _read_document(EVENTS_PATH)
	if m04.is_empty() or roadside.is_empty():
		return
	var m04_by_id := _records_by_id(_source_events(m04))
	var roadside_by_id := _records_by_id(_source_events(roadside))
	for required_id in REQUIRED_GENERIC_IDS + LANTERN_EVENT_IDS:
		_check(m04_by_id.has(required_id), "the generic source still ships " + required_id)
	for expected_id in EXPECTED:
		_check(roadside_by_id.has(expected_id), "the roadside source still ships " + expected_id)
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the default shipped selector validates both authored catalogs")
	if not rotation.is_catalog_valid():
		return
	var ids: Array = rotation.get_generic_event_ids()
	var listing: Array = rotation.get_generic_events()
	for expected_id in EXPECTED:
		_check(ids.count(expected_id) == 1,
			"the default selector admits the roadside tale exactly once: " + expected_id)
		var matches: Array = _matches(listing, expected_id)
		_check(matches.size() == 1, "the default selector lists one record for " + expected_id)
		if matches.size() != 1 or not roadside_by_id.has(expected_id):
			continue
		_check(matches[0] == roadside_by_id[expected_id],
			"the default selector serves the verbatim authored roadside record: " + expected_id)
		_check(RunEventChoice.new(matches[0]).is_valid(),
			"the admitted roadside record is presentable to the event view: " + expected_id)
	for generic_id in m04_by_id:
		if generic_id == QUIET_SPOOL_ID:
			continue
		_check(ids.count(generic_id) == 1,
			"the default selector keeps the shipped generic tale eligible: " + generic_id)
		var generic_matches: Array = _matches(listing, generic_id)
		_check(generic_matches.size() == 1 and generic_matches[0] == m04_by_id[generic_id],
			"the default selector serves the unchanged generic record: " + generic_id)
	for required_id in REQUIRED_GENERIC_IDS + LANTERN_EVENT_IDS:
		_check(ids.count(required_id) == 1, "the required generic ID stays eligible: " + required_id)
	_check(not ids.has(QUIET_SPOOL_ID), "Quiet Spool never joins the default rotation")
	_check(_matches(listing, QUIET_SPOOL_ID).is_empty(), "Quiet Spool has no default rotation record")
	_check(m04_by_id.has(QUIET_SPOOL_ID), "the special Quiet Spool record stays in its own source catalog")
	var oracle_ids: Array = _expected_eligible_ids(m04, roadside)
	_check(ids == oracle_ids,
		"the default pool is exactly the sorted eligible IDs of both shipped catalogs")
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	_check(ids == sorted_ids, "the default pool is sorted by eligible ID")
	# Copy mutation of either returned value never reaches the selector or sources.
	var listing_snapshot: Array = listing.duplicate(true)
	var id_snapshot: Array = ids.duplicate()
	listing[0]["title"] = "MUTATED"
	listing[0]["choices"] = []
	listing.append({"id": "injected_by_test"})
	ids.append("injected_by_test")
	_check(rotation.get_generic_events() == listing_snapshot,
		"mutating a returned default record never reaches the selector")
	_check(rotation.get_generic_event_ids() == id_snapshot,
		"mutating a returned default ID list never reaches the selector")
	_check(m04 == _read_document(M04_EVENTS_PATH) and roadside == _read_document(EVENTS_PATH),
		"default admission never mutates either shipped source catalog")

## AC2: seeded selection from the default combined pool uses the sorted eligible
## IDs and exactly one randi_range draw, returns a detached authentic record,
## forces any named roadside tale through honest exclusions, and rejects an
## exhausted or malformed call without an RNG draw.
func _check_default_selection_contract() -> void:
	var m04: Dictionary = _read_document(M04_EVENTS_PATH)
	var roadside: Dictionary = _read_document(EVENTS_PATH)
	if m04.is_empty() or roadside.is_empty():
		return
	var roadside_by_id := _records_by_id(_source_events(roadside))
	var m04_snapshot: Dictionary = m04.duplicate(true)
	var roadside_snapshot: Dictionary = roadside.duplicate(true)
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the default selector validates for the seeded contract")
	if not rotation.is_catalog_valid():
		return
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids == _expected_eligible_ids(m04, roadside),
		"the default eligible pool matches the independent sorted oracle")
	_check(ids.size() > EXPECTED.size(),
		"the default pool holds the generic records alongside the roadside tales")
	if ids.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 20261026
	var expected_id: String = ids[oracle.randi_range(0, ids.size() - 1)]
	var result := rotation.select_event(rng)
	_check(result.get("ok") == true, "a seeded default selection succeeds")
	_check(result.get("event", {}).get("id") == expected_id,
		"the default selection matches an independent sorted seeded oracle")
	_check(rng.state == oracle.state,
		"a default selection consumes exactly one randi_range draw")
	var replay := RandomNumberGenerator.new()
	replay.seed = 20261026
	var again := rotation.select_event(replay)
	_check(again.get("event", {}).get("id") == expected_id and replay.state == rng.state,
		"the same seed replays the same default event and RNG state")
	var index := 0
	for expected_roadside in EXPECTED:
		index += 1
		_check(ids.has(expected_roadside),
			"the default pool carries the roadside ID before forcing it: " + expected_roadside)
		if not ids.has(expected_roadside):
			continue
		var excluded: Array = ids.duplicate()
		excluded.erase(expected_roadside)
		var forced_rng := RandomNumberGenerator.new()
		forced_rng.seed = 91000 + index
		var forced_oracle := RandomNumberGenerator.new()
		forced_oracle.seed = 91000 + index
		forced_oracle.randi_range(0, 0)
		var forced := rotation.select_event(forced_rng, excluded)
		_check(forced.get("ok") == true,
			"excluding every other event selects the named roadside tale: " + expected_roadside)
		var selected: Dictionary = forced.get("event", {})
		_check(selected.get("id") == expected_roadside,
			"the forced roadside selection is the named tale: " + expected_roadside)
		_check(forced_rng.state == forced_oracle.state,
			"a forced roadside selection still consumes exactly one draw: " + expected_roadside)
		_check(selected == roadside_by_id.get(expected_roadside, {}),
			"the forced roadside selection is the authentic authored record: " + expected_roadside)
		# The returned record is detached from the selector and the source.
		var selected_snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		selected["choices"] = []
		var detached_rng := RandomNumberGenerator.new()
		detached_rng.seed = 91000 + index
		var detached := rotation.select_event(detached_rng, excluded)
		_check(detached.get("event") == selected_snapshot
			and detached.get("event") == roadside_by_id.get(expected_roadside, {}),
			"the selected roadside record is a detached authored copy: " + expected_roadside)
	# An exhausted pool rejects without a draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 424242
	var guard_state: int = guard.state
	var none_result := rotation.select_event(guard, ids)
	_check(none_result.get("ok") == false and (none_result.get("event") as Dictionary).is_empty(),
		"excluding every eligible default event rejects with no event")
	_check(guard.state == guard_state, "an exhausted default pool consumes no RNG")
	# Malformed exclusions reject without a draw.
	for bad_list in [7, true, "button_trail", {}, [1], [""], ["   "], [null], [["button_trail"]]]:
		var bad_result := rotation.select_event(guard, bad_list)
		_check(bad_result.get("ok") == false and (bad_result.get("event") as Dictionary).is_empty(),
			"a malformed default exclusion list rejects: " + str(bad_list))
		_check(guard.state == guard_state,
			"a malformed default exclusion list consumes no RNG: " + str(bad_list))
		_check(rotation.select_event(bad_list).get("ok") == false,
			"a malformed default RNG value rejects: " + str(bad_list))
		_check(guard.state == guard_state,
			"a malformed default RNG value consumes no RNG: " + str(bad_list))
	# Unknown exclusions are ignored and never change the draw.
	var unknown_rng := RandomNumberGenerator.new()
	unknown_rng.seed = 616161
	var plain_rng := RandomNumberGenerator.new()
	plain_rng.seed = 616161
	var with_unknown := rotation.select_event(unknown_rng, ["v3_future_tale_not_in_catalog"])
	var plain := rotation.select_event(plain_rng)
	_check(with_unknown.get("event", {}).get("id") == plain.get("event", {}).get("id"),
		"an unknown default exclusion is ignored")
	_check(unknown_rng.state == plain_rng.state,
		"an unknown default exclusion never changes the draw")
	_check(m04 == m04_snapshot and roadside == roadside_snapshot,
		"seeded default selection never mutates either shipped source catalog")

## AC4: a broken roadside source rejects the whole default merge, so a malformed
## or partial shipped pack can never silently produce an incomplete pool.
func _check_default_merge_failures() -> void:
	var m04: Dictionary = _read_document(M04_EVENTS_PATH)
	var roadside: Dictionary = _read_document(EVENTS_PATH)
	if m04.is_empty() or roadside.is_empty():
		return
	var roadside_events: Array = _source_events(roadside)
	var cases: Array = [
		{"name": "absent roadside document", "roadside": null},
		{"name": "roadside document without events", "roadside": {}},
		{"name": "roadside events is not an array", "roadside": {"events": "v3_raincoat_bridge"}},
		{"name": "empty roadside events", "roadside": {"events": []}},
		{"name": "non-object roadside record", "roadside": {"events": [17]}},
	]
	cases.append({"name": "missing required roadside record", "roadside": {
		"events": _without_record(roadside_events, "v3_lacework_railway")}})
	var blank_title := _record_copy(roadside_events, "v3_dreaming_quilt_fair")
	blank_title["title"] = " "
	cases.append({"name": "blank roadside title", "roadside": {"events": _replace_record(
		roadside_events, "v3_dreaming_quilt_fair", blank_title)}})
	var broken_outcome := _record_copy(roadside_events, "v3_button_orchard")
	((broken_outcome["choices"] as Array)[0] as Dictionary)["outcome"] = {"gold": 1}
	cases.append({"name": "malformed roadside outcome", "roadside": {"events": _replace_record(
		roadside_events, "v3_button_orchard", broken_outcome)}})
	var duplicated: Array = roadside_events.duplicate(true)
	duplicated.append(_record_copy(roadside_events, "v3_needlefall_star"))
	cases.append({"name": "duplicated roadside record", "roadside": {"events": duplicated}})
	var crossed: Array = roadside_events.duplicate(true)
	crossed.append((m04["events"][0] as Dictionary).duplicate(true))
	cases.append({"name": "cross-catalog duplicate ID", "roadside": {"events": crossed}})
	for entry in cases:
		_check(RunM04EventRotation._combine_shipped_catalogs(m04, entry["roadside"]) == null,
			"the default shipped merge rejects: " + entry["name"])
	# The genuine pair merges, validates and admits every named roadside tale.
	var merged: Variant = RunM04EventRotation._combine_shipped_catalogs(m04, roadside)
	_check(merged is Dictionary, "the genuine shipped pair merges")
	if not merged is Dictionary:
		return
	var merged_events: Array = (merged as Dictionary).get("events", [])
	_check(merged_events.size() == (m04["events"] as Array).size() + roadside_events.size(),
		"the merge keeps every authored generic record and adds every roadside record")
	var rotation := RunM04EventRotation.new(merged)
	_check(rotation.is_catalog_valid(), "the merged shipped document validates")
	var ids: Array = rotation.get_generic_event_ids()
	for expected_id in EXPECTED:
		_check(ids.count(expected_id) == 1,
			"the merged shipped document admits exactly one " + expected_id)
	_check(not ids.has(QUIET_SPOOL_ID),
		"the merged shipped document keeps Quiet Spool on its special route")
	_check(m04 == _read_document(M04_EVENTS_PATH) and roadside == _read_document(EVENTS_PATH),
		"merging never mutates either shipped source document")

func _source_events(document: Dictionary) -> Array:
	var events: Variant = document.get("events")
	if not events is Array:
		return []
	return (events as Array).duplicate(true)

func _records_by_id(events: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for record in events:
		if not record is Dictionary:
			continue
		var raw_id: Variant = record.get("id")
		if not raw_id is String or (raw_id as String).strip_edges().is_empty():
			continue
		if by_id.has(raw_id):
			continue
		by_id[raw_id] = record
	return by_id

func _matches(listing: Array, event_id: String) -> Array:
	var found: Array = []
	for record in listing:
		if record is Dictionary and record.get("id") == event_id:
			found.append(record)
	return found

func _without_record(events: Array, drop_id: String) -> Array:
	var kept: Array = []
	for record in events:
		if record is Dictionary and record.get("id") == drop_id:
			continue
		kept.append(record)
	return kept

func _replace_record(events: Array, target_id: String, replacement: Variant) -> Array:
	var out: Array = []
	for record in events:
		if record is Dictionary and record.get("id") == target_id:
			out.append(replacement)
		else:
			out.append(record)
	return out

func _record_copy(events: Array, target_id: String) -> Dictionary:
	for record in events:
		if record is Dictionary and record.get("id") == target_id:
			return (record as Dictionary).duplicate(true)
	return {}

## The eligible IDs a default rotation must expose, derived only from the two
## independently loaded source documents: every unique, presentable generic
## record except the separately routed special, plus every roadside record.
## Sorted so the selector's ordering is verified rather than assumed.
func _expected_eligible_ids(m04: Dictionary, roadside: Dictionary) -> Array:
	var by_id: Dictionary = {}
	var order: Array = []
	for events in [_source_events(m04), _source_events(roadside)]:
		for record in events:
			if not record is Dictionary:
				continue
			var raw_id: Variant = record.get("id")
			if not raw_id is String or (raw_id as String).strip_edges().is_empty():
				continue
			if by_id.has(raw_id):
				by_id[raw_id] = null
				continue
			by_id[raw_id] = record
			order.append(raw_id)
	var ids: Array = []
	for event_id in order:
		var record: Variant = by_id[event_id]
		if not record is Dictionary:
			continue
		if event_id == QUIET_SPOOL_ID:
			continue
		if _is_presentable_by_contract(record):
			ids.append(event_id)
	ids.sort()
	return ids

## Independent presentability check built from the public RunEventChoice
## contract, so the expected default pool never mirrors the selector's internals.
func _is_presentable_by_contract(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	var service := RunEventChoice.new(record)
	if not service.is_valid():
		return false
	var preview: Dictionary = service.preview_wallet_choices({"gold": 0, "scraps": 0})
	if not preview.get("ok", false):
		return false
	var choices: Variant = (record as Dictionary).get("choices")
	var previews: Variant = preview.get("choices")
	if not choices is Array or not previews is Array:
		return false
	if (previews as Array).size() != (choices as Array).size():
		return false
	for entry in previews:
		if not entry is Dictionary:
			return false
		if (entry as Dictionary).get("gold_delta") == null:
			return false
		if (entry as Dictionary).get("scraps_delta") == null:
			return false
	return true
