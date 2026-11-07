extends SceneTree
## Deterministic headless test for the hero-specific v3 roadside Events in
## data/events/v3_hero_choice_events.json.
##
## This catalog is authored data only: every event names its party hero in
## `required_hero` and lists its two non-Leave hero choices in
## `hero_choice_ids`. RunV3HeroEventOffers performs the scene-free party
## admission; app.gd's _load_wallet_event_catalog() merges its eligible offers
## into the live wallet Event catalog for an active run. The one-use
## RunEventChoice only validates/settles the authored wallet choices, so these
## checks cover exact authored metadata and wallet receipts.
##
## Lookups are by authored event/choice ID, never by catalog size, catalog order,
## a global ordered ID list or a positional event index.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

const START_GOLD := 30
const START_SCRAPS := 3

## The six party-gated V3-4 stories appended by this task. They are listed by
## authored ID (never by catalog index or catalog total) so the funded and
## zero-wallet receipt matrices below exercise each one explicitly.
const NEW_EVENT_IDS := ["v3_warden_copper_chain_ferry", "v3_seamstress_needle_oracle",
	"v3_tinker_spring_marionette", "v3_lantern_monk_mothlight_ferry",
	"v3_rag_duelist_cape_tribunal", "v3_scarecrow_raven_orchard"]
const FUNDED_GOLD := 40
const FUNDED_SCRAPS := 4

## The six gothic V3-4 hero stories appended by THIS task. They are kept in
## their own task-local expectation table (independent of the production
## catalog and of the older EVENTS map above) and are always looked up by
## authored ID, never by catalog index or catalog total.
const BATCH_EVENT_IDS := ["v3_warden_pincushion_gate", "v3_seamstress_crimson_bell_cord",
	"v3_lantern_monk_mothveil_passage", "v3_rag_duelist_cape_windmill",
	"v3_yarn_ranger_bolas_mooring", "v3_button_golem_buttonlift"]
const BATCH_EVENTS := {
	"v3_warden_pincushion_gate": {
		"title": "The Pincushion Gate",
		"description": "A dented-pot-helmet Warden braces a huge slate patch shield against a moonlit gate bristling with brass sewing pins.",
		"required_hero": "warden",
		"hero_choice_ids": ["hold_pincushion_gate", "buy_quilted_shield_lacing"],
		"choices": {
			"hold_pincushion_gate": {"text": "Hold the gate for the night watch (gain 22 gold)", "gold": 22, "scraps": 0},
			"buy_quilted_shield_lacing": {"text": "Buy quilted shield lacing (spend 14 gold; gain 2 scraps)", "gold": -14, "scraps": 2},
			"leave": {"text": "Walk away from the gate", "gold": 0, "scraps": 0},
		},
	},
	"v3_seamstress_crimson_bell_cord": {
		"title": "The Crimson Bell Cord",
		"description": "An oversized sewing needle has pinned a frayed scarlet thread-rope beneath a plum velvet bell tower.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["rethread_crimson_bell", "salvage_red_bell_thread"],
		"choices": {
			"rethread_crimson_bell": {"text": "Rethread the bell (spend 2 scraps; gain 27 gold)", "gold": 27, "scraps": -2},
			"salvage_red_bell_thread": {"text": "Collect loose red thread (gain 2 scraps)", "gold": 0, "scraps": 2},
			"leave": {"text": "Let the bell sleep", "gold": 0, "scraps": 0},
		},
	},
	"v3_lantern_monk_mothveil_passage": {
		"title": "The Mothveil Passage",
		"description": "A stout robed lantern keeper and round stitched moths illuminate a dark quilted passage in saffron and teal.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["guide_mothveil_pilgrims", "buy_amber_lantern_wicks"],
		"choices": {
			"guide_mothveil_pilgrims": {"text": "Guide lost travellers by lantern (gain 18 gold)", "gold": 18, "scraps": 0},
			"buy_amber_lantern_wicks": {"text": "Pay 16 gold for three scraps of spare wick thread", "gold": -16, "scraps": 3},
			"leave": {"text": "Pass the lantern arch", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_cape_windmill": {
		"title": "The Cape Windmill",
		"description": "A tattered oxblood cape catches in the sails of a storybook windmill; a slender needle rapier glints beneath the brass hub.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["free_cape_blades", "gather_ribbon_offcuts"],
		"choices": {
			"free_cape_blades": {"text": "Free the trapped sails using 1 scrap and earn 24 gold", "gold": 24, "scraps": -1},
			"gather_ribbon_offcuts": {"text": "Gather the fallen cape ribbons (gain 2 scraps)", "gold": 0, "scraps": 2},
			"leave": {"text": "Leave the mill to the wind", "gold": 0, "scraps": 0},
		},
	},
	"v3_yarn_ranger_bolas_mooring": {
		"title": "The Yarn-Bolas Mooring",
		"description": "Two giant knitting needles mark a river mooring tangled with moss-green wool bolas and teal bowstring.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["recover_knotted_bolas", "sell_spare_knitting_knots"],
		"choices": {
			"recover_knotted_bolas": {"text": "Untangle two useful thread bundles (gain 2 scraps)", "gold": 0, "scraps": 2},
			"sell_spare_knitting_knots": {"text": "Spend 1 scrap and earn 20 gold trading knots", "gold": 20, "scraps": -1},
			"leave": {"text": "Cross without touching the wool", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_buttonlift": {
		"title": "The Buttonlift",
		"description": "A towering button-bodied doll stands beneath a dangling brass-button lift over a stitched ravine.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["haul_buttonlift", "buy_brass_button_shanks"],
		"choices": {
			"haul_buttonlift": {"text": "Raise the stranded lift with giant button fists (gain 23 gold)", "gold": 23, "scraps": 0},
			"buy_brass_button_shanks": {"text": "Buy brass button fittings (spend 17 gold; gain 3 scraps)", "gold": -17, "scraps": 3},
			"leave": {"text": "Let the lift settle", "gold": 0, "scraps": 0},
		},
	},
}

## Independent task-local mapping of the authored records. It is never read from
## the production catalog, so a missing field or a reworded choice is caught.
## Only the named records are listed: the catalog may be appended to by other
## tasks, so no total count or full ordered ID list is asserted here.
const EVENTS := {
	"v3_warden_shield_menders": {
		"title": "The Shield-Menders",
		"description": "At a shield repair queue, a huge patched shield props up the town gate.",
		"required_hero": "warden",
		"hero_choice_ids": ["hold_the_gate", "sell_spare_rivets"],
		"choices": {
			"hold_the_gate": {"text": "Stand watch by the giant shield (+2 scraps)", "gold": 0, "scraps": 2},
			"sell_spare_rivets": {"text": "Trade a spare shield rivet (spend 1 scrap; gain 17 gold)", "gold": 17, "scraps": -1},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_seamstress_thread_cart": {
		"title": "Scarlet Thread Cart",
		"description": "The seamstress finds a wagon knotted with red-thread pennants and giant needles.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["sew_bunting", "buy_red_thread"],
		"choices": {
			"sew_bunting": {"text": "Sew the red pennant (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
			"buy_red_thread": {"text": "Buy a red-thread bundle (spend 12 gold; gain 2 scraps)", "gold": -12, "scraps": 2},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_tinker_clockwork_wagon": {
		"title": "The Clockwork Wagon",
		"description": "A clockwork trader's wagon ticks under a load of crooked buttons and gears.",
		"required_hero": "tinker",
		"hero_choice_ids": ["recover_gears", "fix_ratchet"],
		"choices": {
			"recover_gears": {"text": "Gather the fallen gears (+1 scrap)", "gold": 0, "scraps": 1},
			"fix_ratchet": {"text": "Repair the wagon ratchet (spend 2 scraps; gain 28 gold)", "gold": 28, "scraps": -2},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_lantern_monk_moth_vigil": {
		"title": "Moth Vigil",
		"description": "A warm patchwork lantern gathers moths beside a candlelit cloth shrine.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["guide_moths", "buy_wax"],
		"choices": {
			"guide_moths": {"text": "Guide the moths by lantern light (+2 scraps)", "gold": 0, "scraps": 2},
			"buy_wax": {"text": "Buy lantern wax (spend 12 gold; gain 2 scraps)", "gold": -12, "scraps": 2},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_needle_fair": {
		"title": "The Needle Fair",
		"description": "A caped duelist holds a friendly fencing fair with a long thin needle rapier.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["duel_for_purse", "trade_ribbon"],
		"choices": {
			"duel_for_purse": {"text": "Win the friendly fencing purse (+20 gold)", "gold": 20, "scraps": 0},
			"trade_ribbon": {"text": "Buy two red ribbon bundles (spend 10 gold; gain 2 scraps)", "gold": -10, "scraps": 2},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_scarecrow_crow_roost": {
		"title": "The Crow's Threshing",
		"description": "A black crow perches on a burlap-headed straw doll beside an overgrown granary.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["gather_loose_straw", "sell_crow_feathers"],
		"choices": {
			"gather_loose_straw": {"text": "Gather loose straw ties (+2 scraps)", "gold": 0, "scraps": 2},
			"sell_crow_feathers": {"text": "Trade a bundle of crow feathers (spend 1 scrap; gain 19 gold)", "gold": 19, "scraps": -1},
			"leave": {"text": "Leave the roost untouched", "gold": 0, "scraps": 0},
		},
	},
	"v3_yarn_ranger_knit_ford": {
		"title": "The Knitted Ford",
		"description": "A narrow crossing is webbed with wool bolas and two bent knitting-needle posts.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["retrieve_bolas", "purchase_wool"],
		"choices": {
			"retrieve_bolas": {"text": "Retrieve a spool tangled in the ford (+1 scrap)", "gold": 0, "scraps": 1},
			"purchase_wool": {"text": "Buy fresh coloured wool (spend 14 gold; gain 2 scraps)", "gold": -14, "scraps": 2},
			"leave": {"text": "Cross without disturbing the knitting", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_button_press": {
		"title": "The Giant Button Press",
		"description": "A rattling bronze press stamps brass buttons as a towering button-bodied golem waits.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["stamp_brass", "collect_shanks"],
		"choices": {
			"stamp_brass": {"text": "Feed the press two scrap bundles (spend 2 scraps; gain 31 gold)", "gold": 31, "scraps": -2},
			"collect_shanks": {"text": "Collect fallen button shanks (+1 scrap)", "gold": 0, "scraps": 1},
			"leave": {"text": "Leave the button press", "gold": 0, "scraps": 0},
		},
	},
	"v3_lantern_monk_evening_beacon": {
		"title": "The Evening Beacon",
		"description": "Moths ring a dim lantern pole while travellers queue to relight their stitched lamps.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["trim_evening_wick", "gather_amber_wax"],
		"choices": {
			"trim_evening_wick": {"text": "Trim the beacon wick (spend 1 scrap; gain 16 gold)", "gold": 16, "scraps": -1},
			"gather_amber_wax": {"text": "Buy two wax spools (spend 10 gold; gain 2 scraps)", "gold": -10, "scraps": 2},
			"leave": {"text": "Let the lantern burn", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_scarlet_fair": {
		"title": "The Scarlet Fencing Fair",
		"description": "A feather-hatted puppet duelist invites the party to a needle-rapier bout.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["win_scarlet_purse", "buy_fencing_ribbon"],
		"choices": {
			"win_scarlet_purse": {"text": "Win the fencing purse (+22 gold)", "gold": 22, "scraps": 0},
			"buy_fencing_ribbon": {"text": "Buy fresh fencing ribbons (spend 13 gold; gain 2 scraps)", "gold": -13, "scraps": 2},
			"leave": {"text": "Bow and leave the fair", "gold": 0, "scraps": 0},
		},
	},
	"v3_warden_moonshield_watch": {
		"title": "The Moonshield Watch",
		"description": "A button-eyed sentry stands beneath a bone-cream moon with a shield patched from midnight-blue coats.",
		"required_hero": "warden",
		"hero_choice_ids": ["polish_moonshield", "sell_guard_stitch"],
		"choices": {
			"polish_moonshield": {"text": "Pay 14 gold to polish the moonshield (+2 scraps)", "gold": -14, "scraps": 2},
			"sell_guard_stitch": {"text": "Trade a spare shield stitch (spend 1 scrap; gain 21 gold)", "gold": 21, "scraps": -1},
			"leave": {"text": "Lower the shield and move on", "gold": 0, "scraps": 0},
		},
	},
	"v3_seamstress_scarlet_loom": {
		"title": "The Scarlet Midnight Loom",
		"description": "A wide-eyed doll weaver tends a giant red needle, its loose threads glowing beside a plum velvet loom.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["retie_scarlet_loom", "trade_loom_thread"],
		"choices": {
			"retie_scarlet_loom": {"text": "Retie the snapped needle thread (+2 scraps)", "gold": 0, "scraps": 2},
			"trade_loom_thread": {"text": "Sell two spare thread bundles (spend 2 scraps; gain 24 gold)", "gold": 24, "scraps": -2},
			"leave": {"text": "Leave the loom humming", "gold": 0, "scraps": 0},
		},
	},
	"v3_tinker_gearhouse_midnight": {
		"title": "The Midnight Gearhouse",
		"description": "A hunched scrap-pack automaton sorts blunderbuss springs beneath lantern-lit copper shutters.",
		"required_hero": "tinker",
		"hero_choice_ids": ["recover_spring_teeth", "tune_gearhouse"],
		"choices": {
			"recover_spring_teeth": {"text": "Collect fallen spring teeth (+1 scrap)", "gold": 0, "scraps": 1},
			"tune_gearhouse": {"text": "Tune the scrap gears (spend 2 scraps; gain 27 gold)", "gold": 27, "scraps": -2},
			"leave": {"text": "Leave the clockwork ticking", "gold": 0, "scraps": 0},
		},
	},
	"v3_scarecrow_blackcrow_post": {
		"title": "The Blackcrow Post",
		"description": "A straw-stuffed watchman and its crow perch at a dusk-lit letterpost wrapped in worn denim.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["follow_post_crow", "buy_straw_twines"],
		"choices": {
			"follow_post_crow": {"text": "Follow the crow to a lost purse (+13 gold)", "gold": 13, "scraps": 0},
			"buy_straw_twines": {"text": "Buy twine to bind the loose straw (spend 13 gold; gain 2 scraps)", "gold": -13, "scraps": 2},
			"leave": {"text": "Let the crow keep watch", "gold": 0, "scraps": 0},
		},
	},
	"v3_yarn_ranger_bolas_bridge": {
		"title": "The Knitted Bolas Bridge",
		"description": "Knitting-needle arches stretch across a misty ford, hung with teal yarn bolas and mossy wool.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["reel_lost_bolas", "sell_needlespool"],
		"choices": {
			"reel_lost_bolas": {"text": "Reel in the drifting bolas (+2 scraps)", "gold": 0, "scraps": 2},
			"sell_needlespool": {"text": "Trade a knitting-needle spool (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
			"leave": {"text": "Cross without tangling the bridge", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_bell_foundry": {
		"title": "The Button-Bell Foundry",
		"description": "A huge round button golem braces a brass mould beneath dark-ink bells and candlelight.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["steady_button_mold", "buy_brass_thread"],
		"choices": {
			"steady_button_mold": {"text": "Steady the giant button mould (+17 gold)", "gold": 17, "scraps": 0},
			"buy_brass_thread": {"text": "Buy brass-thread spools (spend 19 gold; gain 3 scraps)", "gold": -19, "scraps": 3},
			"leave": {"text": "Leave the foundry ringing", "gold": 0, "scraps": 0},
		},
	},
	"v3_warden_buckle_checkpoint": {
		"title": "The Buckle Checkpoint",
		"description": "A shield-wide patchwork watchtower guards the threadbare road while brass buckles rattle in the wind.",
		"required_hero": "warden",
		"hero_choice_ids": ["brace_caravan", "sell_buckle_wire"],
		"choices": {
			"brace_caravan": {"text": "Brace the caravan for a 16-gold watchman's wage", "gold": 16, "scraps": 0},
			"sell_buckle_wire": {"text": "Trade two spare buckle scraps for 27 gold", "gold": 27, "scraps": -2},
			"leave": {"text": "Lower the shield and continue", "gold": 0, "scraps": 0},
		},
	},
	"v3_seamstress_crimson_mending_queue": {
		"title": "The Crimson Mending Queue",
		"description": "A long row of button-eyed dolls waits beneath a giant red needle for a fresh hem.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["sew_crimson_hem", "buy_moon_thread"],
		"choices": {
			"sew_crimson_hem": {"text": "Sew the queue's frayed hems for two scraps", "gold": 0, "scraps": 2},
			"buy_moon_thread": {"text": "Spend 16 gold on three moonlit thread scraps", "gold": -16, "scraps": 3},
			"leave": {"text": "Fold the needle away and leave", "gold": 0, "scraps": 0},
		},
	},
	"v3_tinker_gear_sideshow": {
		"title": "The Clockwork Sideshow",
		"description": "A hunched goggle-maker's blunderbuss gears turn a little mechanical puppet stage.",
		"required_hero": "tinker",
		"hero_choice_ids": ["repair_sideshow_cog", "buy_spring_caps"],
		"choices": {
			"repair_sideshow_cog": {"text": "Repair the clockwork cog for a 20-gold fee", "gold": 20, "scraps": 0},
			"buy_spring_caps": {"text": "Pay 12 gold for two spring-cap scraps", "gold": -12, "scraps": 2},
			"leave": {"text": "Let the puppet stage go quiet", "gold": 0, "scraps": 0},
		},
	},
	"v3_scarecrow_crow_lantern_post": {
		"title": "The Crow-Lantern Post",
		"description": "A black crow guards a lantern-lit granary where loose straw spills from stitched sacks.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["gather_nest_straw", "sell_woven_straw"],
		"choices": {
			"gather_nest_straw": {"text": "Gather one bundle of loose straw scraps", "gold": 0, "scraps": 1},
			"sell_woven_straw": {"text": "Trade two straw scraps for 23 gold", "gold": 23, "scraps": -2},
			"leave": {"text": "Leave the crow on its post", "gold": 0, "scraps": 0},
		},
	},
	"v3_yarn_ranger_wool_signal_station": {
		"title": "The Wool Signal Station",
		"description": "Knitting-needle signal masts span a misty ridge, hung with moss-green yarn bolas.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["retrieve_signal_wool", "sell_bolas_knots"],
		"choices": {
			"retrieve_signal_wool": {"text": "Reel in two scraps of loose signal wool", "gold": 0, "scraps": 2},
			"sell_bolas_knots": {"text": "Trade two bolas-knot scraps for 24 gold", "gold": 24, "scraps": -2},
			"leave": {"text": "Cross beneath the silent wool signals", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_rivet_bridge": {
		"title": "The Rivet Bridge",
		"description": "A giant button-bodied porter holds a brass-riveted bridge steady in the dusk.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["brace_rivet_bridge", "buy_brass_bobbins"],
		"choices": {
			"brace_rivet_bridge": {"text": "Hold the bridge for an 18-gold porter's wage", "gold": 18, "scraps": 0},
			"buy_brass_bobbins": {"text": "Spend 17 gold on three brass-thread scraps", "gold": -17, "scraps": 3},
			"leave": {"text": "Let the bridge settle and go", "gold": 0, "scraps": 0},
		},
	},
	"v3_lantern_monk_mothglass_chapel": {
		"title": "The Mothglass Chapel",
		"description": "A round saffron-robed doll tends an amber lantern under stained button-glass; moths circle a cracked wick.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["relight_saffron_wick", "collect_fallen_wax"],
		"choices": {
			"relight_saffron_wick": {"text": "Relight the saffron wick (spend 1 scrap; earn 22 gold)", "gold": 22, "scraps": -1},
			"collect_fallen_wax": {"text": "Gather the fallen lantern wax (+1 scrap)", "gold": 0, "scraps": 1},
			"leave": {"text": "Leave the chapel's moths undisturbed", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_velvet_rapier_stage": {
		"title": "The Velvet Rapier Stage",
		"description": "A caped puppet challenges the Duelist to match his crimson ribbon against a blunted needle rapier.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["win_velvet_purse", "buy_fencing_silk"],
		"choices": {
			"win_velvet_purse": {"text": "Win the velvet purse in a ribbon duel (+14 gold)", "gold": 14, "scraps": 0},
			"buy_fencing_silk": {"text": "Buy fencing silk (spend 13 gold; gain 2 scraps)", "gold": -13, "scraps": 2},
			"leave": {"text": "Leave the puppet to bow alone", "gold": 0, "scraps": 0},
		},
	},
	"v3_tinker_brass_moth_clinic": {
		"title": "The Brass-Moth Clinic",
		"description": "A bent-wing clockwork moth ticks on a gear-backed stool beneath a warm mustard lamp.",
		"required_hero": "tinker",
		"hero_choice_ids": ["repair_bent_wing", "salvage_clock_springs"],
		"choices": {
			"repair_bent_wing": {"text": "Repair the moth's wing (spend 2 scraps; earn 27 gold)", "gold": 27, "scraps": -2},
			"salvage_clock_springs": {"text": "Gather discarded clock springs (+1 scrap)", "gold": 0, "scraps": 1},
			"leave": {"text": "Leave the brass moth resting", "gold": 0, "scraps": 0},
		},
	},
	"v3_scarecrow_pumpkin_seam_census": {
		"title": "The Pumpkin-Seam Census",
		"description": "A plump burlap registrar counts pumpkin buttons while the Scarecrow's crow perches on a stitched ledger.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["register_harvest", "gather_hay_offcuts"],
		"choices": {
			"register_harvest": {"text": "Register the harvest (spend 1 scrap; earn 18 gold)", "gold": 18, "scraps": -1},
			"gather_hay_offcuts": {"text": "Gather loose hay offcuts (+2 scraps)", "gold": 0, "scraps": 2},
			"leave": {"text": "Leave the census table", "gold": 0, "scraps": 0},
		},
	},
	"v3_yarn_ranger_tangled_willow": {
		"title": "The Tangled Willow",
		"description": "Knitting-needle branches cradle teal yarn above a lantern-lit river; the Ranger's bolas can reel it down.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["retrieve_wool_cache", "buy_moss_bolas"],
		"choices": {
			"retrieve_wool_cache": {"text": "Retrieve the fallen wool cache (+10 gold)", "gold": 10, "scraps": 0},
			"buy_moss_bolas": {"text": "Buy moss-green bolas cord (spend 17 gold; gain 3 scraps)", "gold": -17, "scraps": 3},
			"leave": {"text": "Leave the willow undisturbed", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_brass_keyhole": {
		"title": "The Brass Keyhole",
		"description": "A huge moss-green door opens only when giant button fists press its rusted rivets.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["push_rivet_door", "gather_loose_buttons"],
		"choices": {
			"push_rivet_door": {"text": "Push the rivet door (spend 2 scraps; earn 29 gold)", "gold": 29, "scraps": -2},
			"gather_loose_buttons": {"text": "Gather loose button shanks (+1 scrap)", "gold": 0, "scraps": 1},
			"leave": {"text": "Leave the door closed", "gold": 0, "scraps": 0},
		},
	},
	"v3_warden_copper_chain_ferry": {
		"title": "The Copper-Chain Ferry",
		"description": "A stout button-eyed ferryman hangs from a copper chain while the Warden's enormous patched shield braces his tilting boat.",
		"required_hero": "warden",
		"hero_choice_ids": ["brace_ferry_chain", "buy_brass_buckles"],
		"choices": {
			"brace_ferry_chain": {"text": "Brace the ferry chain with the great shield (gain 20 gold)", "gold": 20, "scraps": 0},
			"buy_brass_buckles": {"text": "Buy brass shield buckles (spend 14 gold; gain 2 scraps)", "gold": -14, "scraps": 2},
			"leave": {"text": "Let the ferry drift past", "gold": 0, "scraps": 0},
		},
	},
	"v3_seamstress_needle_oracle": {
		"title": "The Needle-Eye Oracle",
		"description": "A round velvet oracle peers through a huge sewing-needle eye as scarlet threads bind a midnight-plum fortune quilt.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["untangle_oracle_thread", "buy_oracle_silk"],
		"choices": {
			"untangle_oracle_thread": {"text": "Unpick the oracle's snare (spend 1 scrap; earn 24 gold)", "gold": 24, "scraps": -1},
			"buy_oracle_silk": {"text": "Buy fortune silk (spend 18 gold; gain 3 scraps)", "gold": -18, "scraps": 3},
			"leave": {"text": "Leave the red threads tied", "gold": 0, "scraps": 0},
		},
	},
	"v3_tinker_spring_marionette": {
		"title": "The Spring Marionette",
		"description": "A stubby clockwork marionette lies beneath a brass spring chandelier, its bright button heart stalled inside a sewn chest.",
		"required_hero": "tinker",
		"hero_choice_ids": ["rewind_broken_heart", "salvage_worn_gears"],
		"choices": {
			"rewind_broken_heart": {"text": "Use two scrap bundles to rewind its heart (spend 2 scraps; gain 32 gold)", "gold": 32, "scraps": -2},
			"salvage_worn_gears": {"text": "Gather discarded spring gears (gain 2 scraps)", "gold": 0, "scraps": 2},
			"leave": {"text": "Let the marionette sleep", "gold": 0, "scraps": 0},
		},
	},
	"v3_lantern_monk_mothlight_ferry": {
		"title": "The Mothlight Ferry",
		"description": "A candlelit ferry of round stitched moth dolls follows the Lantern Monk's glowing pole across dark teal water.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["guide_moth_passengers", "buy_glowing_wicks"],
		"choices": {
			"guide_moth_passengers": {"text": "Guide the moth passengers ashore (gain 19 gold)", "gold": 19, "scraps": 0},
			"buy_glowing_wicks": {"text": "Buy spare mothlight wicks (spend 12 gold; gain 2 scraps)", "gold": -12, "scraps": 2},
			"leave": {"text": "Let the moth ferry sail away", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_cape_tribunal": {
		"title": "The Split-Cape Tribunal",
		"description": "A crimson velvet judge in a button eyepatch holds court beneath torn capes, with a thin needle rapier laid across the dais.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["mend_judges_cape", "buy_gilt_rapier_guard"],
		"choices": {
			"mend_judges_cape": {"text": "Sew the judge's split cape (spend 1 scrap; earn 23 gold)", "gold": 23, "scraps": -1},
			"buy_gilt_rapier_guard": {"text": "Buy gilt rapier-thread guards (spend 19 gold; gain 3 scraps)", "gold": -19, "scraps": 3},
			"leave": {"text": "Bow without entering the tribunal", "gold": 0, "scraps": 0},
		},
	},
	"v3_scarecrow_raven_orchard": {
		"title": "The Raven-Sewn Orchard",
		"description": "Plump pumpkin ragdolls sit among button apples while the Scarecrow's black crow watches over a row of stitched straw baskets.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["guard_raven_harvest", "trade_pitchfork_twine"],
		"choices": {
			"guard_raven_harvest": {"text": "Guard the stuffed harvest from ravens (gain 2 scraps)", "gold": 0, "scraps": 2},
			"trade_pitchfork_twine": {"text": "Trade two bundles of pitchfork twine (spend 2 scraps; gain 29 gold)", "gold": 29, "scraps": -2},
			"leave": {"text": "Leave the orchard to its crows", "gold": 0, "scraps": 0},
		},
	},
}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_snapshot: Array = []


func _initialize() -> void:
	_test_catalog_content()
	_test_deep_copy_independence()
	_test_commit_matrix()
	_test_preview_forecasts()
	_test_priced_rejections_and_recovery()
	_test_unoffered_choice_ids()
	_test_new_event_funded_receipts()
	_test_batch_event_records()
	_test_batch_event_receipts()
	_test_hero_metadata()
	_test_fixed_seed_replay()
	_check(catalog == catalog_snapshot, "shared event catalog unchanged across all test flows")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_hero_choice_events_test: ", "PASS" if passed else "FAIL", " (", checks, " checks)")
	quit(0 if passed else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _matching(event_id: String) -> Array:
	return catalog.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


func _expected(event_id: String) -> Dictionary:
	return EVENTS[event_id]


func _expected_choices(event_id: String) -> Dictionary:
	return (_expected(event_id)["choices"] as Dictionary)


func _choice_ids(record: Dictionary) -> Dictionary:
	var out := {}
	for choice in record.get("choices", []):
		if choice is Dictionary and choice.get("id") is String:
			out[choice.get("id")] = true
	return out


func _signed(choice_id: String, delta: Dictionary) -> String:
	return choice_id + "(" + str(int(delta["gold"])) + "g/" + str(int(delta["scraps"])) + "s)"


func _wallet_exact_int(wallet: Variant, expected_gold: int, expected_scraps: int) -> bool:
	if not wallet is Dictionary:
		return false
	var dict: Dictionary = wallet
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return false
	var gold: Variant = dict.get("gold")
	var scraps: Variant = dict.get("scraps")
	return (
		typeof(gold) == TYPE_INT
		and typeof(scraps) == TYPE_INT
		and int(gold) == expected_gold
		and int(scraps) == expected_scraps
	)


func _wallet_shape_ok(result: Dictionary) -> bool:
	return (
		result.size() == 4
		and result.has("ok")
		and result.has("event_id")
		and result.has("choice_id")
		and result.has("wallet")
		and result.get("wallet") is Dictionary
	)


func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return (
			is_finite(number)
			and floor(number) == number
			and number <= RunEventChoice.MAX_SAFE_FLOAT_INT
			and number >= -RunEventChoice.MAX_SAFE_FLOAT_INT
		)
	return false


func _rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _other_choice_id(expected_choices: Dictionary, choice_id: String) -> String:
	for candidate in expected_choices:
		var candidate_id: String = candidate
		if candidate_id != choice_id:
			return candidate_id
	return choice_id


func _test_catalog_content() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "v3_hero_choice_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(text != "", "v3_hero_choice_events.json is non-empty")
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, "v3_hero_choice_events.json parses through JSON")
	var data: Variant = parser.data if parse_result == OK else null
	_check(data is Dictionary, "top level is a JSON object")
	if not data is Dictionary:
		return
	var list: Variant = (data as Dictionary).get("events")
	_check(list is Array, "top level has an events array")
	if not list is Array:
		return
	_check(not (list as Array).is_empty(), "events array is non-empty")
	catalog = list
	catalog_snapshot = catalog.duplicate(true)
	for entry in catalog:
		_check(entry is Dictionary, "every event record is an object")
	for event_id in EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "exactly one authored event record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = _expected(event_id)
		_check(
			record.size() == 6
			and record.has("id")
			and record.has("title")
			and record.has("description")
			and record.has("required_hero")
			and record.has("hero_choice_ids")
			and record.has("choices"),
			"authored event has exact top-level keys: " + event_id
		)
		_check(record.get("id") == event_id, "authored id: " + event_id)
		_check(record.get("title") == expected["title"], "authored title: " + event_id)
		_check(record.get("description") == expected["description"], "authored description: " + event_id)
		_check(record.get("required_hero") == expected["required_hero"], "authored required_hero: " + event_id)
		var raw_hero: Variant = record.get("required_hero")
		_check(raw_hero is String and not (raw_hero as String).strip_edges().is_empty(),
			"required_hero is a nonblank string: " + event_id)

		# Event-level hero metadata: exactly the two authored non-Leave choices.
		var raw_hero_ids: Variant = record.get("hero_choice_ids")
		_check(raw_hero_ids is Array, "hero_choice_ids is an array: " + event_id)
		if raw_hero_ids is Array:
			var listed_ids: Array = raw_hero_ids
			_check(listed_ids.size() == 2, "hero_choice_ids lists exactly two choices: " + event_id)
			var listed_set := {}
			for listed in listed_ids:
				_check(listed is String and not (listed as String).strip_edges().is_empty(),
					"hero_choice_ids entry is a nonblank string: " + event_id)
				if listed is String:
					_check(not listed_set.has(listed), "hero_choice_ids entries are distinct: " + event_id)
					listed_set[listed] = true
			var expected_ids: Array = expected["hero_choice_ids"]
			for wanted_id in expected_ids:
				_check(listed_set.has(wanted_id),
					"hero_choice_ids names its required choice: " + event_id + "/" + str(wanted_id))
			_check(not listed_set.has("leave"), "hero_choice_ids excludes the Leave choice: " + event_id)
			var expected_non_leave := {}
			for expected_choice_id in _expected_choices(event_id):
				if expected_choice_id != "leave":
					expected_non_leave[expected_choice_id] = true
			_check(listed_set == expected_non_leave,
				"hero_choice_ids equals exactly the authored non-Leave choices: " + event_id)

		# Authored choices, keyed by ID (never by array position).
		var raw_choices: Variant = record.get("choices")
		_check(raw_choices is Array, "choices array present: " + event_id)
		if not raw_choices is Array:
			continue
		var choices: Array = raw_choices
		_check(choices.size() == 3, "exactly three authored choices: " + event_id)
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary, "every choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_dict: Dictionary = choice
			var choice_id: Variant = choice_dict.get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"nonblank string choice ID: " + event_id)
			if not choice_id is String:
				continue
			_check(not by_id.has(choice_id), "distinct choice IDs: " + event_id)
			by_id[choice_id] = choice_dict
		var wanted_choices: Dictionary = _expected_choices(event_id)
		_check(by_id.size() == wanted_choices.size(), "no unstated choice IDs: " + event_id)
		for choice_id in wanted_choices:
			var wanted: Dictionary = wanted_choices[choice_id]
			_check(by_id.has(choice_id), "required choice present: " + event_id + "/" + choice_id)
			if not by_id.has(choice_id):
				continue
			var choice_dict: Dictionary = by_id[choice_id]
			_check(
				choice_dict.size() == 3
				and choice_dict.has("id")
				and choice_dict.has("text")
				and choice_dict.has("outcome"),
				"choice has exact id/text/outcome keys: " + event_id + "/" + choice_id
			)
			_check(choice_dict.get("text") == wanted["text"],
				"exact authored choice text: " + event_id + "/" + choice_id)
			var raw_outcome: Variant = choice_dict.get("outcome")
			_check(raw_outcome is Dictionary, "choice outcome is an object: " + event_id + "/" + choice_id)
			if not raw_outcome is Dictionary:
				continue
			var outcome: Dictionary = raw_outcome
			_check(
				outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"),
				"outcome has exact gold/scraps keys: " + event_id + "/" + choice_id
			)
			var raw_gold: Variant = outcome.get("gold")
			var raw_scraps: Variant = outcome.get("scraps")
			_check(_is_integral(raw_gold) and _is_integral(raw_scraps),
				"outcome gold/scraps are integral: " + event_id + "/" + choice_id)
			if _is_integral(raw_gold) and _is_integral(raw_scraps):
				_check(
					int(raw_gold) == int(wanted["gold"]) and int(raw_scraps) == int(wanted["scraps"]),
					"exact authored gold/scraps delta " + _signed(str(choice_id), wanted)
						+ ": " + event_id + "/" + choice_id
				)
		if by_id.has("leave"):
			var leave_choice: Dictionary = by_id["leave"]
			var leave_outcome: Variant = leave_choice.get("outcome")
			_check(leave_outcome is Dictionary
				and int(leave_outcome.get("gold", 1)) == 0
				and int(leave_outcome.get("scraps", 1)) == 0,
				"Leave is the authored zero-delta choice: " + event_id)
		var service := RunEventChoice.new(record)
		_check(service.is_valid(), "authored record builds a valid selector: " + event_id)
		_check(not service.is_claimed(), "fresh selector is unclaimed: " + event_id)
		_check(service.get_event() == record, "selector keeps the authored hero metadata: " + event_id)


func _test_deep_copy_independence() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		if matches.size() != 1:
			continue
		var caller_record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = caller_record.duplicate(true)
		var service := RunEventChoice.new(caller_record)
		_check(service.is_valid() and not service.is_claimed(), "fresh selector for detach checks: " + event_id)
		var snapshot := service.get_event()
		_check(snapshot == original, "detached selector copy equals the authored input: " + event_id)
		snapshot["title"] = "mutated snapshot title"
		snapshot["required_hero"] = "mutated_hero"
		(snapshot["hero_choice_ids"] as Array).append("injected_choice")
		var snapshot_choices: Array = snapshot["choices"]
		var snapshot_first: Dictionary = snapshot_choices[0]
		snapshot_first["text"] = "mutated snapshot text"
		(snapshot_first["outcome"] as Dictionary)["gold"] = 5000
		_check(service.get_event() == original, "returned snapshot mutation stays isolated: " + event_id)
		caller_record["description"] = "mutated caller description"
		(caller_record["hero_choice_ids"] as Array).append("injected_choice")
		(caller_record["choices"] as Array).append(
			{"id": "sneaky", "text": "An appended caller choice", "outcome": {"gold": 0, "scraps": 0}})
		_check(service.get_event() == original, "caller mutation stays isolated from the selector: " + event_id)
		var live_matches := _matching(event_id)
		_check(live_matches.size() == 1 and live_matches[0] == original,
			"mutations never reach the shared catalog record: " + event_id)
		var result := service.choose_with_wallet("leave", {"gold": START_GOLD, "scraps": START_SCRAPS})
		_check(_wallet_shape_ok(result)
			and result.get("ok") == true
			and result.get("event_id") == event_id
			and result.get("choice_id") == "leave"
			and _wallet_exact_int(result.get("wallet"), START_GOLD, START_SCRAPS),
			"isolated selector still settles the untouched Leave choice: " + event_id)


func _test_commit_matrix() -> void:
	var case_index := 0
	for event_id in EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "commit matrix has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var authored_record: Dictionary = matches[0]
		var original: Dictionary = authored_record.duplicate(true)
		var expected_choices: Dictionary = _expected_choices(event_id)
		for choice_id in expected_choices:
			case_index += 1
			var delta: Dictionary = expected_choices[choice_id]
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var caller_record: Dictionary = authored_record.duplicate(true)
			var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var local_rng := RandomNumberGenerator.new()
			local_rng.seed = 81000 + case_index
			var local_state: int = local_rng.state
			var expected_global := _rng_start(81000 + case_index)
			var service := RunEventChoice.new(caller_record)
			_check(service.is_valid() and not service.is_claimed(),
				"fresh valid selector before commit: " + label)
			var result := service.choose_with_wallet(choice_id, wallet)
			var expected_gold: int = START_GOLD + int(delta["gold"])
			var expected_scraps: int = START_SCRAPS + int(delta["scraps"])
			_check(_wallet_shape_ok(result), "commit returns the 4-key wallet shape: " + label)
			_check(result.get("ok") == true, "commit succeeds: " + label)
			_check(result.get("event_id") == event_id and result.get("choice_id") == choice_id,
				"commit returns exact event and choice IDs: " + label)
			_check(_wallet_exact_int(result.get("wallet"), expected_gold, expected_scraps),
				"commit settles the exact wallet " + str(START_GOLD) + "/" + str(START_SCRAPS)
					+ " -> " + str(expected_gold) + "/" + str(expected_scraps) + ": " + label)
			_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before,
				"commit never mutates the caller wallet: " + label)
			_check(caller_record == original, "commit never mutates the caller event: " + label)
			_check(service.get_event() == original, "commit never mutates the selector snapshot: " + label)
			_check(service.is_claimed() and not service.is_valid(),
				"commit latches exactly one claim: " + label)
			_check(service.preview_wallet_choices(wallet) == {"ok": false, "event_id": "", "choices": []},
				"a claimed selector offers no further preview: " + label)
			# Returned state is fully detached from the selector and later receipts.
			var returned_wallet: Dictionary = result["wallet"]
			returned_wallet["gold"] = 999
			returned_wallet["scraps"] = 999
			result["ok"] = false
			var replay_id := _other_choice_id(expected_choices, str(choice_id))
			var replay := service.choose_with_wallet(replay_id, {"gold": expected_gold, "scraps": expected_scraps})
			_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false,
				"a second choice after success is rejected: " + label)
			_check(replay.get("event_id") == "" and replay.get("choice_id") == "",
				"a rejected replay returns empty IDs: " + label)
			_check(_wallet_exact_int(replay.get("wallet"), expected_gold, expected_scraps),
				"a rejected replay returns a detached unchanged wallet: " + label)
			(replay["wallet"] as Dictionary)["gold"] = 0
			_check(service.is_claimed() and not service.is_valid() and service.get_event() == original,
				"replay attempts keep the claim latched and the snapshot intact: " + label)
			_check(local_rng.state == local_state and randi() == expected_global,
				"commit, detach and replay spend no RNG: " + label)


func _test_preview_forecasts() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "preview has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = record.duplicate(true)
		var expected_choices: Dictionary = _expected_choices(event_id)
		var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 81100
		var local_state: int = local_rng.state
		var expected_global := _rng_start(81100)
		var service := RunEventChoice.new(record)
		var preview := service.preview_wallet_choices(wallet)
		_check(preview.size() == 3 and preview.get("ok") == true and preview.get("event_id") == event_id,
			"preview returns ok with the exact event ID: " + event_id)
		var entries: Array = preview.get("choices", [])
		_check(entries.size() == expected_choices.size(),
			"preview has one entry per authored choice: " + event_id)
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var entry := _preview_choice(preview, str(choice_id))
			_check(not entry.is_empty(), "preview names the authored choice: " + label)
			_check(entry.size() == 5 and entry.get("choice_id") == choice_id,
				"preview entry has the exact 5-key shape: " + label)
			_check(typeof(entry.get("gold_delta")) == TYPE_INT
				and typeof(entry.get("scraps_delta")) == TYPE_INT
				and entry.get("gold_delta") == int(delta["gold"])
				and entry.get("scraps_delta") == int(delta["scraps"]),
				"preview shows the exact signed authored deltas: " + label)
			_check(entry.get("affordable") == true, "preview marks the funded choice affordable: " + label)
			_check(_wallet_exact_int(entry.get("wallet"),
				START_GOLD + int(delta["gold"]), START_SCRAPS + int(delta["scraps"])),
				"preview projects the exact funded wallet: " + label)
		_check(service.is_valid() and not service.is_claimed()
			and service.get_event() == original and record == original and wallet == wallet_before,
			"preview claims nothing and mutates no input: " + event_id)
		var again := service.preview_wallet_choices(wallet)
		_check(again == preview, "repeated preview is deterministic: " + event_id)
		# Mutating one preview entry must not leak into the selector or its siblings.
		var first_entry: Dictionary = entries[0]
		var first_id: String = first_entry["choice_id"]
		var sibling_id := _other_choice_id(expected_choices, first_id)
		var sibling_delta: Dictionary = expected_choices[sibling_id]
		(first_entry["wallet"] as Dictionary)["gold"] = -500
		first_entry["gold_delta"] = -500
		var sibling := _preview_choice(preview, sibling_id)
		_check(_wallet_exact_int(sibling.get("wallet"),
			START_GOLD + int(sibling_delta["gold"]), START_SCRAPS + int(sibling_delta["scraps"])),
			"preview wallets are detached from sibling entries: " + event_id)
		_check(service.preview_wallet_choices(wallet) == again
			and service.is_valid() and not service.is_claimed()
			and service.get_event() == original and wallet == wallet_before,
			"mutating preview results never reaches the selector: " + event_id)

		# Zero wallet: priced choices stay unaffordable with an unchanged forecast;
		# free/gain choices remain affordable and forecast only their own delta.
		var zero_wallet := {"gold": 0, "scraps": 0}
		var zero_preview := service.preview_wallet_choices(zero_wallet)
		_check(zero_preview.get("ok") == true and zero_preview.get("event_id") == event_id,
			"zero-wallet preview stays readable: " + event_id)
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var priced: bool = int(delta["gold"]) < 0 or int(delta["scraps"]) < 0
			var entry := _preview_choice(zero_preview, str(choice_id))
			_check(not entry.is_empty() and entry.get("affordable") == (not priced),
				"zero-wallet affordability matches the authored cost: " + event_id + "/" + str(choice_id))
			var projected_gold: int = 0 if priced else int(delta["gold"])
			var projected_scraps: int = 0 if priced else int(delta["scraps"])
			_check(_wallet_exact_int(entry.get("wallet"), projected_gold, projected_scraps),
				"zero-wallet forecast is unchanged for priced choices and exact for free ones: "
					+ event_id + "/" + str(choice_id))
		_check(service.preview_wallet_choices(null) == {"ok": false, "event_id": "", "choices": []}
			and service.is_valid() and not service.is_claimed(),
			"a malformed preview wallet fails closed without claiming: " + event_id)
		_check(randi() == expected_global and local_rng.state == local_state,
			"previews and detach probes spend no RNG: " + event_id)


func _test_priced_rejections_and_recovery() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "priced rejection has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var authored_record: Dictionary = matches[0]
		var original: Dictionary = authored_record.duplicate(true)
		var expected_choices: Dictionary = _expected_choices(event_id)
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var priced: bool = int(delta["gold"]) < 0 or int(delta["scraps"]) < 0
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var service := RunEventChoice.new(authored_record.duplicate(true))
			if not priced:
				var gain_wallet := {"gold": 0, "scraps": 0}
				var gain := service.choose_with_wallet(choice_id, gain_wallet)
				_check(_wallet_shape_ok(gain) and gain.get("ok") == true
					and gain.get("event_id") == event_id and gain.get("choice_id") == choice_id
					and _wallet_exact_int(gain.get("wallet"), int(delta["gold"]), int(delta["scraps"])),
					"a free/gain choice settles exactly from a zero wallet: " + label)
				_check(_wallet_exact_int(gain_wallet, 0, 0),
					"a free/gain choice leaves the zero caller wallet untouched: " + label)
				continue

			var zero_wallet := {"gold": 0, "scraps": 0}
			var zero_before: Dictionary = zero_wallet.duplicate(true)
			var expected_global := _rng_start(81200)
			var rejected := service.choose_with_wallet(choice_id, zero_wallet)
			_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false,
				"a priced choice is refused at a zero wallet: " + label)
			_check(rejected.get("event_id") == "" and rejected.get("choice_id") == "",
				"the zero-wallet refusal returns empty IDs: " + label)
			_check(_wallet_exact_int(rejected.get("wallet"), 0, 0),
				"the zero-wallet refusal returns a detached unchanged wallet: " + label)
			_check(_wallet_exact_int(zero_wallet, 0, 0) and zero_wallet == zero_before,
				"the zero-wallet refusal never mutates the caller wallet: " + label)
			_check(service.is_valid() and not service.is_claimed() and service.get_event() == original,
				"the zero-wallet refusal spends no claim and keeps the snapshot: " + label)
			(rejected["wallet"] as Dictionary)["gold"] = 999
			_check(_wallet_exact_int(zero_wallet, 0, 0),
				"mutating the refused wallet never reaches the caller: " + label)

			# The same visit recovers on the neutral Leave choice, with no partial spend.
			var recovered := service.choose_with_wallet("leave", zero_wallet)
			_check(_wallet_shape_ok(recovered) and recovered.get("ok") == true
				and recovered.get("event_id") == event_id and recovered.get("choice_id") == "leave",
				"Leave recovers on the SAME visit after the refusal: " + label)
			_check(_wallet_exact_int(recovered.get("wallet"), 0, 0),
				"the recovered Leave preserves the zero wallet: " + label)
			_check(_wallet_exact_int(zero_wallet, 0, 0) and zero_wallet == zero_before,
				"the recovered Leave leaves the caller wallet untouched: " + label)
			_check(service.is_claimed() and not service.is_valid() and service.get_event() == original,
				"the recovered Leave latches exactly one claim: " + label)
			var after := service.choose_with_wallet(choice_id, {"gold": START_GOLD, "scraps": START_SCRAPS})
			_check(_wallet_shape_ok(after) and after.get("ok", true) == false
				and after.get("event_id") == "" and after.get("choice_id") == ""
				and _wallet_exact_int(after.get("wallet"), START_GOLD, START_SCRAPS),
				"a post-recovery choice is rejected even once it becomes affordable: " + label)
			_check(service.is_claimed() and service.get_event() == original,
				"post-recovery rejection keeps the single claim latched: " + label)
			_check(randi() == expected_global,
				"refusal, recovery and replay spend no RNG: " + label)


func _test_unoffered_choice_ids() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		var expected_choices: Dictionary = _expected_choices(event_id)
		_check(matches.size() == 1, "unoffered-ID case has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var bad_ids: Array = ["", " ", "unoffered", "LEAVE", "leave ", " leave", null, 7, ["leave"], {"id": "leave"}]
		for offered_id in expected_choices:
			var offered_text: String = offered_id
			bad_ids.append(offered_text.to_upper())
			bad_ids.append(offered_text + " ")
			bad_ids.append(" " + offered_text)
		# Every choice ID authored only on another event is unoffered here.
		for other_event_id in EVENTS:
			for other_choice_id in _expected_choices(other_event_id):
				if expected_choices.has(other_choice_id):
					continue
				if not bad_ids.has(other_choice_id):
					bad_ids.append(other_choice_id)
		for bad_id in bad_ids:
			var expected_global := _rng_start(81300)
			var rejected := service.choose_with_wallet(bad_id, wallet)
			_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false,
				"an unoffered choice ID is rejected: " + event_id + "/" + str(bad_id))
			_check(rejected.get("event_id") == "" and rejected.get("choice_id") == "",
				"an unoffered choice ID returns empty IDs: " + event_id + "/" + str(bad_id))
			_check(_wallet_exact_int(rejected.get("wallet"), START_GOLD, START_SCRAPS),
				"an unoffered choice ID preserves the detached wallet: " + event_id + "/" + str(bad_id))
			_check(service.is_valid() and not service.is_claimed()
				and service.get_event() == original and wallet == wallet_before,
				"an unoffered choice ID consumes no claim or input: " + event_id + "/" + str(bad_id))
			_check(randi() == expected_global,
				"an unoffered choice ID spends no RNG: " + event_id + "/" + str(bad_id))
		var claimed := service.choose_with_wallet("leave", wallet)
		_check(_wallet_shape_ok(claimed) and claimed.get("ok") == true
			and claimed.get("event_id") == event_id and claimed.get("choice_id") == "leave"
			and _wallet_exact_int(claimed.get("wallet"), START_GOLD, START_SCRAPS),
			"the offered Leave still claims once after every rejection: " + event_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the recovered Leave latches exactly one claim: " + event_id)
		var replay := service.choose_with_wallet("leave", wallet)
		_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
			and _wallet_exact_int(replay.get("wallet"), START_GOLD, START_SCRAPS),
			"the recovered Leave cannot be replayed: " + event_id)


func _test_new_event_funded_receipts() -> void:
	# Funded and zero-wallet receipt matrix for the six appended party stories,
	# keyed by authored ID and driven only through RunEventChoice (the same
	# service app.gd's live route uses), with independent expected deltas.
	var listed := {}
	for event_id in NEW_EVENT_IDS:
		_check(not listed.has(event_id), "new story ID is listed once in the matrix: " + event_id)
		listed[event_id] = true
		_check(EVENTS.has(event_id),
			"new story has an independent expected fixture: " + event_id)
	for event_id in NEW_EVENT_IDS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "funded matrix has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = record.duplicate(true)
		var expected: Dictionary = _expected(event_id)
		var expected_choices: Dictionary = _expected_choices(event_id)
		_check(record.get("required_hero") == expected["required_hero"],
			"new story keeps its exact required hero: " + event_id)
		var raw_listed: Variant = record.get("hero_choice_ids")
		_check(raw_listed is Array and raw_listed == expected["hero_choice_ids"],
			"new story keeps its exact two hero choice IDs: " + event_id)
		_check(expected_choices.has("leave")
			and int(expected_choices["leave"]["gold"]) == 0
			and int(expected_choices["leave"]["scraps"]) == 0,
			"new story keeps a zero-cost Leave: " + event_id)
		_check(expected_choices.size() == 3, "new story keeps three distinct choices: " + event_id)
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var expected_gold: int = FUNDED_GOLD + int(delta["gold"])
			var expected_scraps: int = FUNDED_SCRAPS + int(delta["scraps"])
			var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var local_rng := RandomNumberGenerator.new()
			local_rng.seed = 81400
			var local_state: int = local_rng.state
			var expected_global := _rng_start(81400)
			var service := RunEventChoice.new(record)
			var preview := service.preview_wallet_choices(wallet)
			var entry := _preview_choice(preview, str(choice_id))
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and entry.size() == 5 and entry.get("choice_id") == choice_id
				and entry.get("affordable") == true,
				"funded preview offers the authored choice: " + label)
			_check(typeof(entry.get("gold_delta")) == TYPE_INT
				and typeof(entry.get("scraps_delta")) == TYPE_INT
				and int(entry.get("gold_delta")) == int(delta["gold"])
				and int(entry.get("scraps_delta")) == int(delta["scraps"])
				and _wallet_exact_int(entry.get("wallet"), expected_gold, expected_scraps),
				"funded preview quotes the exact signed delta and projected wallet: " + label)
			var claim := service.choose_with_wallet(choice_id, wallet)
			_check(_wallet_shape_ok(claim) and claim.get("ok") == true
				and claim.get("event_id") == event_id and claim.get("choice_id") == choice_id
				and _wallet_exact_int(claim.get("wallet"), expected_gold, expected_scraps),
				"funded claim settles the exact authored wallet: " + label)
			_check(_wallet_exact_int(wallet, FUNDED_GOLD, FUNDED_SCRAPS)
				and wallet == wallet_before and service.get_event() == original,
				"funded claim leaves the caller wallet and snapshot untouched: " + label)
			_check(service.is_claimed() and not service.is_valid()
				and service.preview_wallet_choices(wallet) == {"ok": false, "event_id": "", "choices": []},
				"funded claim latches the visit once: " + label)
			var replay := service.choose_with_wallet(choice_id,
				{"gold": expected_gold, "scraps": expected_scraps})
			_check(_wallet_shape_ok(replay) and replay.get("ok") == false
				and replay.get("event_id") == "" and replay.get("choice_id") == ""
				and _wallet_exact_int(replay.get("wallet"), expected_gold, expected_scraps),
				"a replay of the settled choice is rejected unchanged: " + label)
			_check(service.is_claimed() and service.get_event() == original
				and local_rng.state == local_state and randi() == expected_global,
				"funded preview, claim and replay spend no RNG: " + label)
		# Zero wallet: every authored cost is disabled and refused, the neutral
		# Leave still works on that same visit, and nothing consumes the wallet.
		var zero_wallet := {"gold": 0, "scraps": 0}
		var zero_before: Dictionary = zero_wallet.duplicate(true)
		var first_priced := ""
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var priced: bool = int(delta["gold"]) < 0 or int(delta["scraps"]) < 0
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			if priced and first_priced.is_empty():
				first_priced = choice_id
			var probe := RunEventChoice.new(record)
			var probe_entry := _preview_choice(probe.preview_wallet_choices(zero_wallet), str(choice_id))
			_check(not probe_entry.is_empty() and probe_entry.get("affordable") == (not priced),
				"zero-wallet affordability follows the authored cost: " + label)
			if not priced:
				var free := probe.choose_with_wallet(choice_id, zero_wallet)
				_check(free.get("ok") == true
					and _wallet_exact_int(free.get("wallet"), int(delta["gold"]), int(delta["scraps"])),
					"a free/gain choice still settles from a zero wallet: " + label)
				continue
			var refused := probe.choose_with_wallet(choice_id, zero_wallet)
			_check(_wallet_shape_ok(refused) and refused.get("ok") == false
				and refused.get("event_id") == "" and refused.get("choice_id") == ""
				and _wallet_exact_int(refused.get("wallet"), 0, 0) and not probe.is_claimed(),
				"an unaffordable priced or scrap-cost choice is refused unchanged: " + label)
		_check(not first_priced.is_empty(), "new story has an authored priced choice: " + event_id)
		if first_priced.is_empty():
			continue
		var visit := RunEventChoice.new(record)
		var refusal := visit.choose_with_wallet(first_priced, zero_wallet)
		_check(_wallet_shape_ok(refusal) and refusal.get("ok") == false
			and refusal.get("event_id") == "" and refusal.get("choice_id") == "",
			"the priced refusal returns empty IDs: " + event_id + "/" + first_priced)
		_check(visit.is_valid() and not visit.is_claimed() and zero_wallet == zero_before,
			"the priced refusal consumes neither the visit nor the wallet: " + event_id)
		var recovered := visit.choose_with_wallet("leave", zero_wallet)
		_check(_wallet_shape_ok(recovered) and recovered.get("ok") == true
			and recovered.get("event_id") == event_id and recovered.get("choice_id") == "leave"
			and _wallet_exact_int(recovered.get("wallet"), 0, 0),
			"Leave still succeeds on the same zero-wallet visit: " + event_id)
		var late := visit.choose_with_wallet(first_priced,
			{"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS})
		_check(_wallet_shape_ok(late) and late.get("ok") == false
			and late.get("event_id") == "" and late.get("choice_id") == ""
			and _wallet_exact_int(late.get("wallet"), FUNDED_GOLD, FUNDED_SCRAPS)
			and visit.is_claimed() and not visit.is_valid(),
			"a settled Leave cannot be replayed or re-claimed: " + event_id)


func _test_batch_event_records() -> void:
	# Focused schema/choice-text/delta/collision proof for the six gothic
	# hero stories appended by this task. Expected values come only from the
	# independent BATCH_EVENTS table above, and every lookup is by authored ID.
	_check(BATCH_EVENT_IDS.size() == 6, "batch table lists six authored story IDs")
	var listed := {}
	for event_id in BATCH_EVENT_IDS:
		_check(not listed.has(event_id), "batch story ID is listed once: " + event_id)
		listed[event_id] = true
		_check(BATCH_EVENTS.has(event_id), "batch story has its own expected record: " + event_id)
		_check(not EVENTS.has(event_id), "batch story does not replace an older expected record: " + event_id)
	# Named earlier anchors stay present and unchanged in the shipped catalog.
	for anchor_id in ["v3_warden_shield_menders", "v3_yarn_ranger_knit_ford",
		"v3_button_golem_button_press", "v3_warden_copper_chain_ferry",
		"v3_seamstress_needle_oracle", "v3_tinker_spring_marionette",
		"v3_lantern_monk_mothlight_ferry", "v3_rag_duelist_cape_tribunal",
		"v3_scarecrow_raven_orchard"]:
		_check(_matching(anchor_id).size() == 1, "named earlier anchor still authored once: " + anchor_id)
		if EVENTS.has(anchor_id):
			var anchor_matches := _matching(anchor_id)
			if anchor_matches.size() == 1:
				_check(_anchor_view(anchor_matches[0]) == _authored_anchor(anchor_id),
					"named earlier anchor record is unchanged: " + anchor_id)
	# Catalog-wide collision counts: each batch event ID and non-Leave choice ID
	# must appear exactly once across every authored record.
	var catalog_ids := {}
	var catalog_choices := {}
	for record in catalog:
		if not record is Dictionary:
			continue
		var record_id: Variant = record.get("id")
		if record_id is String:
			catalog_ids[record_id] = int(catalog_ids.get(record_id, 0)) + 1
		for choice in record.get("choices", []):
			if choice is Dictionary and choice.get("id") is String:
				var choice_id: String = choice.get("id")
				catalog_choices[choice_id] = int(catalog_choices.get(choice_id, 0)) + 1
	for event_id in BATCH_EVENT_IDS:
		var expected: Dictionary = BATCH_EVENTS[event_id]
		var matches := _matching(event_id)
		_check(matches.size() == 1, "exactly one authored batch record: " + event_id)
		_check(int(catalog_ids.get(event_id, 0)) == 1, "batch event ID is catalog-unique: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(
			record.size() == 6
			and record.has("id") and record.has("title") and record.has("description")
			and record.has("required_hero") and record.has("hero_choice_ids")
			and record.has("choices"),
			"batch record has the exact six authored keys: " + event_id)
		_check(record.get("id") == event_id, "batch authored id: " + event_id)
		_check(record.get("title") == expected["title"], "batch authored title: " + event_id)
		var description = record.get("description")
		_check(description is String and not (description as String).strip_edges().is_empty(),
			"batch description is nonblank themed story text: " + event_id)
		_check(description == expected["description"], "batch authored description: " + event_id)
		_check(record.get("required_hero") == expected["required_hero"],
			"batch authored required_hero: " + event_id)
		_check(RunV3HeroEventOffers.HERO_IDS.has(record.get("required_hero")),
			"batch required_hero is a canonical roster hero: " + event_id)

		var raw_hero_ids: Variant = record.get("hero_choice_ids")
		_check(raw_hero_ids is Array, "batch hero_choice_ids is an array: " + event_id)
		if not raw_hero_ids is Array:
			continue
		var hero_choice_ids: Array = raw_hero_ids
		_check(hero_choice_ids == expected["hero_choice_ids"],
			"batch hero_choice_ids are the exact two authored choices: " + event_id)
		var listed_choices := {}
		for choice_id in hero_choice_ids:
			_check(choice_id is String, "batch hero choice ID is a string: " + event_id)
			if not choice_id is String:
				continue
			_check(choice_id != "leave", "batch hero_choice_ids excludes Leave: " + event_id)
			_check(not listed_choices.has(choice_id),
				"batch hero_choice_ids are distinct: " + event_id + "/" + choice_id)
			listed_choices[choice_id] = true
			_check(int(catalog_choices.get(choice_id, 0)) == 1,
				"batch hero choice ID is catalog-unique: " + event_id + "/" + choice_id)
			_check(BATCH_EVENTS[event_id]["choices"].has(choice_id),
				"batch hero choice is independently authored: " + event_id + "/" + choice_id)

		var raw_choices: Variant = record.get("choices")
		_check(raw_choices is Array, "batch choices is an array: " + event_id)
		if not raw_choices is Array:
			continue
		var choices: Array = raw_choices
		_check(choices.size() == 3, "batch record has exactly three choices: " + event_id)
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary, "batch choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_id: Variant = choice.get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"batch choice ID is a nonblank string: " + event_id)
			if not choice_id is String:
				continue
			_check(not by_id.has(choice_id), "batch choice IDs are distinct: " + event_id)
			by_id[choice_id] = choice
		var wanted: Dictionary = BATCH_EVENTS[event_id]["choices"]
		_check(by_id.size() == wanted.size(), "batch record has no unstated choices: " + event_id)
		_check(by_id.has("leave"), "batch record authors a Leave choice: " + event_id)
		var non_leave := {}
		for choice_id in by_id:
			if choice_id != "leave":
				non_leave[choice_id] = true
		_check(non_leave == listed_choices,
			"batch hero_choice_ids equal exactly the authored non-Leave choices: " + event_id)
		for choice_id in wanted:
			var want: Dictionary = wanted[choice_id]
			_check(by_id.has(choice_id), "batch required choice present: " + event_id + "/" + choice_id)
			if not by_id.has(choice_id):
				continue
			var choice: Dictionary = by_id[choice_id]
			_check(
				choice.size() == 3 and choice.has("id") and choice.has("text")
				and choice.has("outcome"),
				"batch choice has the exact id/text/outcome keys: " + event_id + "/" + choice_id)
			_check(choice.get("text") == want["text"],
				"batch choice text states the exact signed trade: " + event_id + "/" + choice_id)
			var raw_outcome: Variant = choice.get("outcome")
			_check(raw_outcome is Dictionary, "batch outcome is an object: " + event_id + "/" + choice_id)
			if not raw_outcome is Dictionary:
				continue
			var outcome: Dictionary = raw_outcome
			_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"),
				"batch outcome has exact gold/scraps keys: " + event_id + "/" + choice_id)
			var raw_gold: Variant = outcome.get("gold")
			var raw_scraps: Variant = outcome.get("scraps")
			_check(_is_integral(raw_gold) and _is_integral(raw_scraps),
				"batch outcome amounts are integral: " + event_id + "/" + choice_id)
			if _is_integral(raw_gold) and _is_integral(raw_scraps):
				_check(int(raw_gold) == int(want["gold"]) and int(raw_scraps) == int(want["scraps"]),
					"batch exact signed delta " + _signed(str(choice_id), want)
						+ ": " + event_id + "/" + choice_id)
		if by_id.has("leave"):
			var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
			_check(leave_outcome is Dictionary
				and int(leave_outcome.get("gold", 1)) == 0
				and int(leave_outcome.get("scraps", 1)) == 0,
				"batch Leave is a zero-delta departure: " + event_id)
		# The authored record is a genuine, unclaimed RunEventChoice visit.
		var service := RunEventChoice.new(record)
		_check(service.is_valid() and not service.is_claimed(),
			"batch authored record builds a fresh valid visit: " + event_id)
		_check(service.get_event() == record,
			"batch visit keeps the authored metadata: " + event_id)


func _anchor_view(record: Dictionary) -> Dictionary:
	# Normalize JSON numeric outcomes to native integers so an unchanged old
	# anchor compares by value instead of by parsed number type.
	var choices: Array = []
	for choice in record.get("choices", []):
		if not choice is Dictionary:
			continue
		var outcome: Variant = choice.get("outcome")
		choices.append({
			"id": choice.get("id"),
			"text": choice.get("text"),
			"outcome": {
				"gold": int(outcome.get("gold", 0)) if outcome is Dictionary else 0,
				"scraps": int(outcome.get("scraps", 0)) if outcome is Dictionary else 0,
			},
		})
	return {
		"id": record.get("id"),
		"title": record.get("title"),
		"description": record.get("description"),
		"required_hero": record.get("required_hero"),
		"hero_choice_ids": (record.get("hero_choice_ids", []) as Array).duplicate(),
		"choices": choices,
	}


func _authored_anchor(event_id: String) -> Dictionary:
	# Rebuild the named old anchor from the EVENTS expectation map so the
	# comparison above stays independent of the production catalog.
	var expected: Dictionary = EVENTS[event_id]
	var choices: Array = []
	for choice_id in expected["choices"]:
		var current: Dictionary = expected["choices"][choice_id]
		choices.append({
			"id": choice_id,
			"text": current["text"],
			"outcome": {"gold": int(current["gold"]), "scraps": int(current["scraps"])},
		})
	return {
		"id": event_id,
		"title": expected["title"],
		"description": expected["description"],
		"required_hero": expected["required_hero"],
		"hero_choice_ids": (expected["hero_choice_ids"] as Array).duplicate(),
		"choices": choices,
	}


func _test_batch_event_receipts() -> void:
	# Independent funded/zero-wallet receipt matrix for the six new stories,
	# one fresh RunEventChoice visit per event and choice.
	var listed := {}
	for event_id in BATCH_EVENT_IDS:
		_check(not listed.has(event_id), "batch receipt ID is listed once: " + event_id)
		listed[event_id] = true
	for event_id in BATCH_EVENT_IDS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "batch receipt has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = record.duplicate(true)
		var expected: Dictionary = BATCH_EVENTS[event_id]
		var expected_choices: Dictionary = expected["choices"]
		_check(record.get("required_hero") == expected["required_hero"]
			and record.get("hero_choice_ids") == expected["hero_choice_ids"],
			"batch receipt keeps the exact hero metadata: " + event_id)
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var expected_gold: int = FUNDED_GOLD + int(delta["gold"])
			var expected_scraps: int = FUNDED_SCRAPS + int(delta["scraps"])
			var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var local_rng := RandomNumberGenerator.new()
			local_rng.seed = 81500
			var local_state: int = local_rng.state
			var expected_global := _rng_start(81500)
			var service := RunEventChoice.new(record)
			var preview := service.preview_wallet_choices(wallet)
			var entry := _preview_choice(preview, str(choice_id))
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and entry.size() == 5 and entry.get("choice_id") == choice_id
				and entry.get("affordable") == true,
				"batch funded preview offers the authored choice: " + label)
			_check(typeof(entry.get("gold_delta")) == TYPE_INT
				and typeof(entry.get("scraps_delta")) == TYPE_INT
				and int(entry.get("gold_delta")) == int(delta["gold"])
				and int(entry.get("scraps_delta")) == int(delta["scraps"])
				and _wallet_exact_int(entry.get("wallet"), expected_gold, expected_scraps),
				"batch funded preview quotes the exact signed delta: " + label)
			var claim := service.choose_with_wallet(choice_id, wallet)
			_check(_wallet_shape_ok(claim) and claim.get("ok") == true
				and claim.get("event_id") == event_id and claim.get("choice_id") == choice_id
				and _wallet_exact_int(claim.get("wallet"), expected_gold, expected_scraps),
				"batch funded claim settles the exact authored wallet: " + label)
			_check(_wallet_exact_int(wallet, FUNDED_GOLD, FUNDED_SCRAPS)
				and wallet == wallet_before and service.get_event() == original,
				"batch funded claim leaves caller inputs untouched: " + label)
			_check(service.is_claimed() and not service.is_valid()
				and service.preview_wallet_choices(wallet) == {"ok": false, "event_id": "", "choices": []},
				"batch funded claim latches the single visit: " + label)
			var replay := service.choose_with_wallet(choice_id,
				{"gold": expected_gold, "scraps": expected_scraps})
			_check(_wallet_shape_ok(replay) and replay.get("ok") == false
				and replay.get("event_id") == "" and replay.get("choice_id") == ""
				and _wallet_exact_int(replay.get("wallet"), expected_gold, expected_scraps),
				"batch settled choice cannot be claimed twice: " + label)
			_check(service.is_claimed() and service.get_event() == original
				and local_rng.state == local_state and randi() == expected_global,
				"batch preview, claim and replay spend no RNG: " + label)
		# A fresh zero wallet refuses every authored price without spending the
		# visit or the wallet, then the neutral Leave still works on that visit.
		var zero_wallet := {"gold": 0, "scraps": 0}
		var zero_before: Dictionary = zero_wallet.duplicate(true)
		var first_priced := ""
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var priced: bool = int(delta["gold"]) < 0 or int(delta["scraps"]) < 0
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			if priced and first_priced.is_empty():
				first_priced = choice_id
			var probe := RunEventChoice.new(record)
			var probe_entry := _preview_choice(probe.preview_wallet_choices(zero_wallet), str(choice_id))
			_check(not probe_entry.is_empty() and probe_entry.get("affordable") == (not priced),
				"batch zero-wallet affordability follows the authored price: " + label)
			if not priced:
				var free := probe.choose_with_wallet(choice_id, zero_wallet)
				_check(free.get("ok") == true
					and _wallet_exact_int(free.get("wallet"), int(delta["gold"]), int(delta["scraps"])),
					"batch free/gain choice still settles from a zero wallet: " + label)
				continue
			var refused := probe.choose_with_wallet(choice_id, zero_wallet)
			_check(_wallet_shape_ok(refused) and refused.get("ok") == false
				and refused.get("event_id") == "" and refused.get("choice_id") == ""
				and _wallet_exact_int(refused.get("wallet"), 0, 0) and not probe.is_claimed()
				and probe.is_valid() and probe.get_event() == original,
				"batch unaffordable price is refused without consuming the visit: " + label)
		_check(not first_priced.is_empty(), "batch story authors a priced choice: " + event_id)
		if first_priced.is_empty():
			continue
		var visit := RunEventChoice.new(record)
		var refusal := visit.choose_with_wallet(first_priced, zero_wallet)
		_check(_wallet_shape_ok(refusal) and refusal.get("ok") == false
			and refusal.get("event_id") == "" and refusal.get("choice_id") == "",
			"batch priced refusal returns empty IDs: " + event_id + "/" + first_priced)
		_check(visit.is_valid() and not visit.is_claimed() and zero_wallet == zero_before,
			"batch priced refusal consumes neither visit nor wallet: " + event_id)
		var recovered := visit.choose_with_wallet("leave", zero_wallet)
		_check(_wallet_shape_ok(recovered) and recovered.get("ok") == true
			and recovered.get("event_id") == event_id and recovered.get("choice_id") == "leave"
			and _wallet_exact_int(recovered.get("wallet"), 0, 0),
			"batch Leave still succeeds at a zero wallet on that visit: " + event_id)
		var late := visit.choose_with_wallet(first_priced,
			{"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS})
		_check(_wallet_shape_ok(late) and late.get("ok") == false
			and late.get("event_id") == "" and late.get("choice_id") == ""
			and _wallet_exact_int(late.get("wallet"), FUNDED_GOLD, FUNDED_SCRAPS)
			and visit.is_claimed() and not visit.is_valid(),
			"batch settled Leave refuses any second claim: " + event_id)


func _test_hero_metadata() -> void:
	# Per-record authored metadata only. The catalog is append-safe, so this
	# asserts ID presence/collisions, never a global record, hero or choice
	# total, and it never demands one event per required hero.
	var event_ids := {}
	var hero_choice_ids := {}
	var named_heroes := {}
	for event_id in EVENTS:
		var matches := _matching(event_id)
		var expected: Dictionary = _expected(event_id)
		_check(matches.size() == 1, "hero metadata case has one authored record: " + event_id)
		_check(not event_ids.has(event_id), "authored event ID is globally unique: " + event_id)
		event_ids[event_id] = true
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var hero: Variant = record.get("required_hero")
		_check(hero == expected["required_hero"], "required_hero matches the authored hero: " + event_id)
		if hero is String:
			named_heroes[hero] = true
		_check(hero is String and RunV3HeroEventOffers.HERO_IDS.has(hero),
			"required_hero is a party hero known to admission: " + event_id)
		var authored := _choice_ids(record)
		var listed: Variant = record.get("hero_choice_ids")
		_check(listed is Array, "hero_choice_ids is an authored array: " + event_id)
		if not listed is Array:
			continue
		var listed_ids: Array = listed
		_check(listed_ids.size() == 2,
			"hero_choice_ids declares exactly two hero choices: " + event_id)
		var local_ids := {}
		for choice_id in listed_ids:
			_check(choice_id is String, "hero_choice_ids entries are strings: " + event_id)
			if not choice_id is String:
				continue
			_check(not local_ids.has(choice_id),
				"hero_choice_ids entries are unique within the record: " + event_id)
			local_ids[choice_id] = true
			_check(choice_id != "leave", "hero_choice_ids excludes the Leave choice: " + event_id)
			_check(authored.has(choice_id),
				"hero_choice_ids only names authored choices: " + event_id + "/" + choice_id)
			_check(not hero_choice_ids.has(choice_id),
				"hero choice ID collision across named records: " + choice_id + " (" + event_id + ")")
			hero_choice_ids[choice_id] = true
		var non_leave := {}
		for authored_choice_id in authored:
			if authored_choice_id != "leave":
				non_leave[authored_choice_id] = true
		_check(local_ids == non_leave,
			"hero_choice_ids equals exactly the authored non-Leave choices: " + event_id)
	# Every hero named by the task is represented by at least one named record;
	# membership only, so two events may legitimately share a required hero.
	for required_hero in ["warden", "seamstress", "tinker", "lantern_monk", "rag_duelist",
		"scarecrow", "yarn_ranger", "button_golem"]:
		_check(named_heroes.has(required_hero), "catalog names the required hero: " + required_hero)
	# The starter party keeps its three current heroes; authored Events may name
	# heroes a later party slice introduces.
	var party_file := FileAccess.open("res://data/heroes/starter_party.json", FileAccess.READ)
	_check(party_file != null, "the starter party file still opens")
	if party_file != null:
		var party_text := party_file.get_as_text()
		party_file.close()
		var party_parser := JSON.new()
		_check(party_parser.parse(party_text) == OK, "the starter party file still parses")
		var party: Variant = party_parser.data
		_check(party is Array, "the starter party file is still an array")
		if party is Array:
			var party_ids := {}
			for entry in party:
				if entry is Dictionary and entry.get("id") is String:
					party_ids[entry.get("id")] = true
			for starter_id in ["warden", "seamstress", "tinker"]:
				_check(party_ids.has(starter_id), "the starter party still contains " + starter_id)


func _test_fixed_seed_replay() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		var expected_choices: Dictionary = _expected_choices(event_id)
		_check(matches.size() == 1, "seeded replay has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var traces: Array = []
			for attempt in range(2):
				var local_rng := RandomNumberGenerator.new()
				local_rng.seed = 918273
				var initial_local_state: int = local_rng.state
				var expected_global := _rng_start(918273)
				var caller_record: Dictionary = matches[0].duplicate(true)
				var original_event: Dictionary = caller_record.duplicate(true)
				var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
				var wallet_before: Dictionary = wallet.duplicate(true)
				var instance := RunEventChoice.new(caller_record)
				var preflight := instance.choose_with_wallet("not_a_choice", wallet)
				var preview := instance.preview_wallet_choices(wallet)
				var claim := instance.choose_with_wallet(choice_id, wallet)
				var replay := instance.choose_with_wallet(choice_id, claim.get("wallet", {}))
				_check(_wallet_shape_ok(preflight) and preflight.get("ok") == false
					and preflight.get("wallet") == wallet_before,
					"a forged choice before the claim preserves the wallet: " + label)
				_check(preview.get("ok") == true and preview.get("event_id") == event_id,
					"the seeded preview is readable before the claim: " + label)
				_check(_wallet_shape_ok(claim) and claim.get("ok") == true
					and claim.get("event_id") == event_id and claim.get("choice_id") == choice_id
					and _wallet_exact_int(claim.get("wallet"),
						START_GOLD + int(delta["gold"]), START_SCRAPS + int(delta["scraps"])),
					"the seeded claim settles its scripted delta: " + label)
				_check(_wallet_shape_ok(replay) and replay.get("ok") == false
					and replay.get("wallet") == claim.get("wallet")
					and instance.is_claimed() and not instance.is_valid(),
					"the seeded replay fails after exactly one claim: " + label)
				_check(wallet == wallet_before and caller_record == original_event
					and instance.get_event() == original_event,
					"the seeded trace preserves caller inputs and the snapshot: " + label)
				_check(local_rng.state == initial_local_state,
					"the seeded trace leaves the local RNG state untouched: " + label
						+ " attempt " + str(attempt))
				_check(randi() == expected_global,
					"the seeded trace leaves the global RNG stream untouched: " + label
						+ " attempt " + str(attempt))
				traces.append({
					"preview": preview,
					"preflight": preflight,
					"claim": claim,
					"replay": replay,
					"is_claimed": instance.is_claimed(),
					"is_valid": instance.is_valid(),
					"event": instance.get_event(),
				})
			_check(traces.size() == 2 and traces[0] == traces[1],
				"two independent seeded instances produce identical traces: " + label)
