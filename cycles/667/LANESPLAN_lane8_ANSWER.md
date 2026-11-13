@@PLAN_START@@
TITLE: Append three hero-gated hearth-bellows, egg-cup and hatbox corridor bargains
MILESTONE: V3-4 Events / Stitched S6-compatible hero-choice content
LANE: lane8
STATUS: READY after the accepted glass-dropper, dinner-fork and toy-submarine lane8 batch merges

## Goal and ownership
Add three doll-scale, object-led, hero-specific wallet Events to data/events/v3_hero_choice_events.json, not to the active lane8 roadside catalog. A Tinker repairs a colossal hearth bellows, a Scarecrow protects a nest in a porcelain egg cup, and a Button Golem shoulders a suspended velvet hatbox. Each has two hero-authenticated actions and a free Leave, using only already supported signed gold/scraps outcomes. The Stitched four-hero, LOST-sensitive RunV3HeroEventOffers and one-claim RunEventChoice paths supply testable service behavior. Do not invent fray, candle, HP, card, part, fight, UI, quote or forecast rules. The owner owns the 3D corridor presentation; any additional live visit/art wiring follows separately, and this lane makes no live-screen acceptance claim.

The 667 main plan occupies S7 card-free admission and dark title (scripts/app.gd, scripts/patchwork_ui_shell.gd and their title tests). The accepted lane8 batch uses data/events/v3_roadside_events.json and its new test, not the hero-choice catalog. Lane2 parts, lane3 Behemoth, lane6 Field Notes and the previously claimed lane4 route-effect changes use different features/files. Immediately before authoring, LIVE_WORK.md (17:20:49) showed neither target file nor test reserved or changing; the new main cycle 668 was still planning. Revalidate at launch. Read-only dependencies are stable hero-offer, wallet-choice and existing hero-event tests; none is a write path. The source catalog has the six-field record shape exemplified by v3_tinker_brass_cufflink_clasp and v3_button_golem_coat_hanger_bridge. Append three objects inside the existing events array, keeping the full preceding list and named anchors unchanged. Three events, about 60-100 added JSON lines and one new test file; no scripts, existing tests or other catalogs.

## Acceptance criteria
AC1: Given the shipped hero-choice JSON, the new deterministic test locates each new record exactly once by ID and compares its title, description, required_hero, exact two hero_choice_ids, three choice texts and signed gold/scraps effects to independent constants. Existing anchor IDs remain present, without a catalog-total, position or ordered-list assertion.
AC2: Given a real four-distinct-hero Stitched party containing tinker, scarecrow and button_golem, RunV3HeroEventOffers admits all three authored records. Swapping out an event's required hero excludes that event; marking its required hero LOST refuses survivor entry while a different LOST member does not. No app/UI assertions.
AC3: Given a fresh RunEventChoice visit per branch and wallet {gold:50,scraps:5}, preview and commit agree with all nine expected receipts, Leave changes nothing, and input wallet/catalog data are untouched.
AC4: Given one-less-than-cost wallets for each charged choice, RunEventChoice refuses settlement without claiming, mutating data or consuming randomness; a subsequent funded action on the same visit succeeds and a second claim fails. Existing fail-closed/negative tests stay effective.

## Existing-test corrections and limits
No existing regression expectations require changing for an append checked by ID. In particular preserve tests/v3_hero_choice_events_test.gd, tests/v3_stitched_snuffbox_tube_watch_hero_choice_events_test.gd and tests/run_v3_hero_event_offers_test.gd, including invalid-party, forged-catalog, unaffordable-wallet and replay coverage. Do not change legacy fixed-total or fixed-seed assumptions should unrelated ones surface; report conflicts within this light lane rather than broadening its scope. Coders have standing authority for the smallest necessary supporting code/test corrections, including existing shared tests, when strictly needed to meet unchanged acceptance and preserve negative coverage; this particular parallel task's explicit no-scripts/no-existing-test envelope and other lanes' ownership still apply. A newly required owner decision means defer that decision, not a new feature. No image request: owner corridor assets are out of this data-only task.

@@PLAN_END@@
@@TASK_SCOPE_START@@
{"feature":"three hero-gated doll-scale wallet Events at hearth bellows, porcelain egg cup and suspended hatbox","files":["data/events/v3_hero_choice_events.json","tests/v3_stitched_bellows_eggcup_hatbox_hero_events_test.gd"],"depends_on":["scripts/run_v3_hero_event_offers.gd","scripts/run_event_choice.gd","tests/v3_hero_choice_events_test.gd","tests/v3_stitched_snuffbox_tube_watch_hero_choice_events_test.gd","tests/run_v3_hero_event_offers_test.gd"],"size":"small"}
@@TASK_SCOPE_END@@

@@LANE_lane8_START@@
TITLE: Append three hero-gated hearth-bellows, egg-cup and hatbox corridor bargains
MILESTONE: V3-4 Events / Stitched S6-compatible hero-choice content

## Goal
Add exactly three new story-driven, hero-gated events in ONE existing authored data catalog, data/events/v3_hero_choice_events.json, and ONE NEW SceneTree test, tests/v3_stitched_bellows_eggcup_hatbox_hero_events_test.gd. The Tinker frees a trapped hearth-bellows keeper, the Scarecrow tends a crow's porcelain nest, and the Button Golem hoists a velvet hatbox for a trapped messenger. These are look-led, candlelit, doll-scale events with distinct physical props and short choices. All economic effects use the existing gold/scraps wallet vocabulary, not new rules. This is source/service-layer event content only; the owner's corridor/visit presentation and any additional live wiring or individually illustrated props follow in a later owner-owned step. Do not assert a playable new screen or invent a panel, button or art file.

## Details (all rules/numbers/names needed)
- Stitched Design v4 replaces old cards and energy. A run has four stitched dolls, ranks 1-4, a shared thread, fray and a candle, over 12 floors. Events remain, and choices may exchange gold and sewing SCRAPS; balances cannot become negative. Do not mention a deck/hand or create new effect/gate/cost handlers.
- Use ONE catalog only: data/events/v3_hero_choice_events.json. Its root is {"events":[...]}. Copy the exact six-field hero-gated record shape from already shipped v3_tinker_brass_cufflink_clasp: id, title, description, required_hero, hero_choice_ids and choices. Each event has exactly three choice dictionaries (id, text, outcome), where outcome has only gold and scraps integer deltas. hero_choice_ids names exactly its two non-Leave choices. required_hero is an existing ID. Append the records below; do NOT rewrite, delete, reorder or recalculate previous records. Preserve v3_warden_shield_menders, v3_tinker_brass_cufflink_clasp, v3_button_golem_coat_hanger_bridge, v3_lantern_monk_iron_snuffbox_vigil, v3_yarn_ranger_copper_speaking_tube and v3_rag_duelist_stopped_pocket_watch.
- Use RunV3HeroEventOffers (scripts/run_v3_hero_event_offers.gd) to admit 4 distinct IDs from warden, seamstress, tinker, lantern_monk, rag_duelist, scarecrow, yarn_ranger and button_golem. Its enter_stitched_survivor(event_id, lost_ids) rejects an event whose required hero is LOST. RunEventChoice (scripts/run_event_choice.gd) previews and commits one chosen signed wallet result, refuses unaffordable costs, leaves original data/wallet untouched and accepts one claim per visit. Choose display text contains only a few plain words, never a numeric quote or forecast; the numbers stay in hidden outcome fields.
- EXACT three records to append inside the existing events array (these are literal authored requirements, not suggestions):

~~~json
[
  {
    "id": "v3_tinker_brass_hearth_bellows",
    "title": "The Hearth Bellows",
    "description": "A fireplace bellows as long as a wagon blocks the floorboard passage, its brass hinge ticking beside a buried ember. The Tinker's uneven goggles catch a tiny soot-cloth keeper waving from the folded leather.",
    "required_hero": "tinker",
    "hero_choice_ids": ["repair_bellows_hinge", "buy_bellows_springs"],
    "choices": [
      {
        "id": "repair_bellows_hinge",
        "text": "Rebuild the hinge; accept the keeper's purse",
        "outcome": {"gold": 28, "scraps": -2}
      },
      {
        "id": "buy_bellows_springs",
        "text": "Buy the keeper's spare spring-and-thread bundles",
        "outcome": {"gold": -19, "scraps": 3}
      },
      {
        "id": "leave",
        "text": "Let the embers sleep inside the bellows",
        "outcome": {"gold": 0, "scraps": 0}
      }
    ]
  },
  {
    "id": "v3_scarecrow_porcelain_egg_cup_nest",
    "title": "The Porcelain Egg-Cup Nest",
    "description": "A white porcelain egg cup towers over the floorboard seam, holding a nest of moss wool. The Scarecrow's black crow clings to its rim while a tiny button-eyed chick peeks through loose stitches.",
    "required_hero": "scarecrow",
    "hero_choice_ids": ["brace_egg_cup_nest", "gather_nest_wool"],
    "choices": [
      {
        "id": "brace_egg_cup_nest",
        "text": "Stitch the nest safely to the rim; take the keeper's gold",
        "outcome": {"gold": 27, "scraps": -1}
      },
      {
        "id": "gather_nest_wool",
        "text": "Gather soft wool fallen beneath the cup",
        "outcome": {"gold": 0, "scraps": 2}
      },
      {
        "id": "leave",
        "text": "Leave the crow guarding its porcelain tower",
        "outcome": {"gold": 0, "scraps": 0}
      }
    ]
  },
  {
    "id": "v3_button_golem_velvet_hatbox_lift",
    "title": "The Velvet Hatbox Lift",
    "description": "An enormous plum-velvet hatbox hangs by red ribbon straps over a stairwell void. A button-eyed messenger waits beneath its brass clasp as the Button Golem catches the swaying weight with great brass-button fists.",
    "required_hero": "button_golem",
    "hero_choice_ids": ["raise_hatbox_platform", "buy_hatbox_studs"],
    "choices": [
      {
        "id": "raise_hatbox_platform",
        "text": "Hoist the hatbox and earn the messenger's gold",
        "outcome": {"gold": 31, "scraps": -2}
      },
      {
        "id": "buy_hatbox_studs",
        "text": "Buy brass studs and strong thread from the messenger",
        "outcome": {"gold": -16, "scraps": 3}
      },
      {
        "id": "leave",
        "text": "Leave the hatbox hanging over the dark stairs",
        "outcome": {"gold": 0, "scraps": 0}
      }
    ]
  }
]
~~~

- These records add three entries relative to the existing list. Every earlier record stays unchanged. The three new event IDs and their six hero-choice IDs must be unique; all have a free choice id leave. Do NOT edit the accepted lane8 v3_roadside_events.json, any other data/events catalog, scripts/ files, existing tests, scenes, art, code-drawn visuals, shared registries or S7/S14/S15 logic. The art mood is rich ink-outlined gothic ragdoll storybook with rounded patched dolls and one candlelit accent; reference screenshots are only layout/mood reference, never copied.
- This task is deliberately small for Mistral web: approximately 60-100 added JSON data lines and one concise NEW headless test, no extra helpers. Coders have standing authority for the smallest necessary supporting corrections to keep acceptance unchanged and preserve negative/fail-closed coverage, including shared tests when actually necessary. However, this lane is explicitly restricted to these two files and may not edit scripts or existing tests; if a pre-existing failing regression truly needs another file, report the blocker rather than widening ownership. New owner decisions are deferred, not invented.

## Files likely touched
1. data/events/v3_hero_choice_events.json — append only the three literal records above, in the existing events array, preserving all earlier entries.
2. tests/v3_stitched_bellows_eggcup_hatbox_hero_events_test.gd — ONE NEW extends SceneTree deterministic service-level test.

Read-only dependencies: scripts/run_v3_hero_event_offers.gd, scripts/run_event_choice.gd, tests/v3_stitched_snuffbox_tube_watch_hero_choice_events_test.gd (copy the focused per-ID admission/receipt style), tests/v3_hero_choice_events_test.gd and tests/run_v3_hero_event_offers_test.gd (preserve existing fail-closed assertions). Do not depend on app.gd, the live corridor or another lane's files.

## Tests to add or update (deterministic, headless)
- Create only tests/v3_stitched_bellows_eggcup_hatbox_hero_events_test.gd. Parse the shipped JSON via FileAccess and JSON. Define independent expected constants with all three exact IDs, titles, descriptions, required heroes, non-Leave choice IDs, texts and outcomes; do not derive expected fields from the parsed catalog. JSON numeric tokens may be float-valued integrals, so validate integral signed values without requiring raw JSON TYPE_INT. Find each new ID exactly once and each six named older anchor exactly once; NEVER assert the size, order or complete ID set of the growing catalog.
- The canonical four-hero party is ["tinker","scarecrow","button_golem","warden"]. RunV3HeroEventOffers.new(party) must be valid and get_offers() must contain all three ID-matched records. For missing-hero checks, use ["warden","scarecrow","button_golem","seamstress"] for Tinker, ["tinker","warden","button_golem","seamstress"] for Scarecrow and ["tinker","scarecrow","warden","seamstress"] for Button Golem. Check each absent hero event is not offered or enterable. With the canonical party, enter_stitched_survivor(event_id, []) admits each, enter_stitched_survivor(event_id, [required_hero]) refuses, and losing warden (an unrelated hero) still admits. No UI assertions.
- For each of the three events, make a FRESH RunEventChoice for each branch with funded wallet {"gold":50,"scraps":5}. Check preview_wallet_choices matches the independently expected signed delta, affordability and resulting wallet; choose_with_wallet returns the same exact wallet and matching event/choice IDs. Expected receipts: Tinker repair_bellows_hinge -> {gold:78,scraps:3}, buy_bellows_springs -> {gold:31,scraps:8}, leave -> {gold:50,scraps:5}; Scarecrow brace_egg_cup_nest -> {gold:77,scraps:4}, gather_nest_wool -> {gold:50,scraps:7}, leave -> {gold:50,scraps:5}; Button Golem raise_hatbox_platform -> {gold:81,scraps:3}, buy_hatbox_studs -> {gold:34,scraps:8}, leave -> {gold:50,scraps:5}. Check the caller's wallet and source catalog text stay unchanged.
- Run the five charged-choice refusal cases on new visits: repair_bellows_hinge with {gold:50,scraps:1}; buy_bellows_springs with {gold:18,scraps:5}; brace_egg_cup_nest with {gold:50,scraps:0}; raise_hatbox_platform with {gold:50,scraps:1}; buy_hatbox_studs with {gold:15,scraps:5}. Confirm each refusal leaves wallet and visit unclaimed, and a funded retry on that SAME visit works. After any successful claim, a second claim must fail. Unknown choice must fail without claiming. Leave with zero funds must work. Keep a seeded local RNG snapshot across these wallet-only operations and assert no draw; do not assume seed-to-event mapping.
- Run the new script with Godot 4.7.2 from repository root after standard class import: godot --headless --path . --import then godot --headless --path . -s res://tests/v3_stitched_bellows_eggcup_hatbox_hero_events_test.gd. Report PASS and check count; ensure zero SCRIPT ERROR/Parse Error. Existing v3_hero_choice_events_test.gd, v3_stitched_snuffbox_tube_watch_hero_choice_events_test.gd and run_v3_hero_event_offers_test.gd are regressions to preserve; no updates expected or allowed in this light lane.

## Acceptance criteria (each objectively checkable by the tests)
AC1: Given the shipped data/events/v3_hero_choice_events.json, the new test finds v3_tinker_brass_hearth_bellows, v3_scarecrow_porcelain_egg_cup_nest and v3_button_golem_velvet_hatbox_lift exactly once and matches all specified metadata, gates, three authored choices and wallet deltas; the six named anchors remain, without any catalog total/order assertion.
AC2: Given canonical four-hero party ["tinker","scarecrow","button_golem","warden"], the real RunV3HeroEventOffers service admits all three; removing the respective required hero excludes only its dependent offer, marking it LOST rejects survivor entry and losing an unrelated member permits entry.
AC3: Given fresh authored RunEventChoice visits and starting wallet {gold:50,scraps:5}, all nine funded preview/claim receipts equal the exact wallets above; Leave is zero-delta and the catalog and original wallets are unchanged.
AC4: Given the five insufficient-cost wallets above, wallet settlement fails closed without claiming or consuming RNG; funded retry succeeds, unknown choice remains rejectable and replay after a valid claim fails. Existing negative/fail-closed tests are preserved, with no scripts, old tests, live UI or art edited.

@@TASK_SCOPE_START@@
{"feature":"three hero-gated doll-scale wallet Events at hearth bellows, porcelain egg cup and suspended hatbox","files":["data/events/v3_hero_choice_events.json","tests/v3_stitched_bellows_eggcup_hatbox_hero_events_test.gd"],"depends_on":["scripts/run_v3_hero_event_offers.gd","scripts/run_event_choice.gd","tests/v3_hero_choice_events_test.gd","tests/v3_stitched_snuffbox_tube_watch_hero_choice_events_test.gd","tests/run_v3_hero_event_offers_test.gd"],"size":"small"}
@@TASK_SCOPE_END@@
@@LANE_lane8_END@@
@@FILE_END@@