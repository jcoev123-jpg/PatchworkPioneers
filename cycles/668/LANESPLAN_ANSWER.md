@@PLAN_START@@
TITLE: Improve one existing Wren-soothing Event bargain and one Patch Stall affordability tier
MILESTONE: S6 (Stitched event consequences and corridor stop economy; side-lane follow-ons)

## Main-cycle boundary
Cycle 668 owns S15 public resistance/patch/LOST/replay witnesses and its six reserved files. The next main cycle owns Peddler Save callback reliability in scripts/app.gd and three named Peddler save/live tests. Lane 3 owns Pin Skitter foe-intent work and a Behemoth change awaiting merge. Neither side task modifies or depends directly on any of those files. No scene, corridor, visit presentation, map, Wren UI, part definition, S14/S15 combat rule or retired card code changes.

## Parallel tasks and acceptance criteria
lane4 — Improve the EXISTING Moonblack Paperweight's reassuring house-plan bargain rather than adding another small Event. Use its existing routed event catalog, the established fear outcome vocabulary and the established minimum living-doll-fray admission rule. AC1: The authored buy_quiet_house_plan keeps -16 gold, -10 FRAY per active doll, zero candle and min_fray 1, adds -8 Wren FEAR, and shortens ONLY that choice's text to a plain-language effect; confirm the exact record and preservation of the other two choices. AC2: A legal four-doll snapshot with valid Wren fear, an active frayed doll and 16 gold projects and commits both reliefs once; a zero-fear starting point clamps to zero, LOST dolls never receive fray, and underfunded/no-active-fray/missing-fear/stale/duplicate claims remain refused with no mutation or RNG. AC3: Focused authored-event and service tests stay deterministic and previously named Event records/alternatives survive; no new UI or merely advisory service fields.

lane5 — Move the EXISTING Wool Patch Cloak's shop price from 75 to 55 gold, not its +5 max-HP COAT bonus, bringing a usable intermediate protective button between the 35-gold +4 Padded Vest and 90-gold +6 Quilted Coat. AC1: Only wool_patch_cloak's price changes to 55 in the Stitched offer source; the other seven named COAT records and their prices, the +5 bonus and all catalog identities remain unchanged. AC2: A seeded three-offer Patch Stall samples an authentic 55-gold Wool Patch Cloak without duplicate entries and replays the same stock/RNG; the established budget-stock guarantee (20-gold Scrap-Lined Vest and 35-gold Padded Vest) and owned/SOLD exclusions remain. AC3: The actual routed Peddler/Patch Stall purchase path rejects 54 gold, accepts exactly 55 once, debits exactly 55 and grants the same +5 max-HP COAT benefit on legal equip; stale/double/owned requests and seeded replay retain their existing protections.

## Existing-test corrections and ownership
lane4 may correct the current hardcoded Moonblack source/preview/receipt oracles in tests/stitched_s6_moonblack_fray_offer_test.gd and tests/v3_stitched_pin_cabinet_paperweight_bedwarmer_events_test.gd, including adding a real wren_fear to the latter's test snapshots. Preserve unrelated Cabinet/Bedwarmer/Event and fail-closed coverage. lane5 may correct existing exact 75-gold Wool Patch Cloak witnesses in tests/run_stitched_patch_stall_stock_test.gd and tests/stitched_s6_peddler_patch_live_test.gd, including live purchase gold expectations, without altering unrelated coat prices/bonuses or sampler failures. No fixed catalog count or ordered ID assertion is permitted. Coders have standing authority for the smallest supporting code or test correction required by their own unchanged acceptance criteria, including an affected existing shared test, but not for edits to concurrent owner files, different features, design numbers, or unrelated systems. A newly required owner decision is deferred and recorded rather than repeatedly attempted.

## Verification and art
Use Godot 4.7.2 deterministic SceneTree tests (godot --headless --path . --script res://tests/<name>), then the standard .review/relay_v2/run_tests.py suite through the lane runner if available. A public run already loads both existing records; neither task adds a choice, keeper, drawn ware, scene or art asset. Reference images show today's in-corridor shop and title as the presentation authority; do not reproduce the older framed reference UI.
@@PLAN_END@@
@@TASK_SCOPE_START@@
{"feature":"two independent S6 side-lane updates: Moonblack Event fear relief and Wool Patch Cloak shop affordability","files":["data/events/stitched_route_effects.json","scripts/run_stitched_event_consequence.gd","tests/stitched_s6_moonblack_fray_offer_test.gd","tests/v3_stitched_pin_cabinet_paperweight_bedwarmer_events_test.gd","data/shop/stitched_patch_offers.json","tests/run_stitched_patch_stall_stock_test.gd","tests/stitched_s6_peddler_patch_live_test.gd"],"depends_on":["scripts/run_event_choice.gd","scripts/run_stitched_peddler_stock.gd","scripts/run_patch_stall_visit.gd","data/patches/m04_coat_patches.json"],"size":"medium"}
@@TASK_SCOPE_END@@

@@LANE_lane4_START@@
TITLE: Let the Moonblack house plan soothe Wren as well as frayed dolls
MILESTONE: S6

## Goal
Improve one ALREADY-AUTHORED and already-routed dark-gothic Event bargain, not the Event catalog size or a UI panel: make the Moonblack Paperweight's reassuring house plan also relieve Wren's fear. The player gets a relevant morale bargain in the corridor without a new choice, button, text forecast or art request.

## Details (all rules/numbers/names needed, copied from the docs)
Source: data/events/stitched_route_effects.json, in existing record id v3_moonblack_paperweight (title The Moonblack Paperweight), choice id buy_quiet_house_plan.
Current choice effect is {"target":"party","candle":0,"fray":-10,"gold":-16,"min_fray":1}. Keep those values, including the rule that at least one ACTIVE non-LOST doll must have FRAY >= 1. Add exactly "fear":-8 using the already-supported RunStitchedEventConsequence Wren-fear outcome. Wren fear is 0..100; negative relief clamps at zero, requires a valid input wren_fear, and must appear on the successful receipt. This is NOT the separate require_fray_or_fear gate: leave min_fray:1 in place. Change the one player-facing choice text from the old numeric "Pay 16 gold for a reassuring house plan (-10 fray each)" to "Buy a quiet house plan; ease the dolls and Wren". It names a brief effect, never a quote/forecast or numerical readout. Do not change the event's title, description or existing alternatives: lift_shadowed_map still gives +23 gold, -10 candle, +7 fray each with require_full_candle true; leave remains neutral. Keep all other entries in stitched_route_effects.json byte-for-byte apart from necessary formatting of this one row.

Design v4 uses four surviving stitched dolls, FRAY 0..200, Wren FEAR 0..100, a seeded run, and corridor Events. Existing helper scripts/run_stitched_event_consequence.gd already projects/commits both fray and Wren fear from an authored stitched_effect; do not introduce a second handler or change any S15 combat/resistance rules. A LOST doll never receives party fray relief. No event or screen UI work: the existing corridor Event choice consumes the authored catalog. Inspect actual code and tests first; if necessary, the smallest helper correction required to make the established data effect work is allowed, but DO NOT rewrite the event engine.

## Files likely touched
- data/events/stitched_route_effects.json (only the Moonblack buy_quiet_house_plan record).
- tests/stitched_s6_moonblack_fray_offer_test.gd (update its authored-schema oracle and independent Wren-fear preview, claim, clamp and refusal fixtures).
- tests/v3_stitched_pin_cabinet_paperweight_bedwarmer_events_test.gd (update the Moonblack independent authored record, funded projection/receipt, and any valid Wren-fear fixture; do not weaken Cabinet/Bedwarmer assertions).
- scripts/run_stitched_event_consequence.gd ONLY if a focused real service witness exposes a bug in the already-present fear implementation. Avoid changing it otherwise.

## Tests to add or update (deterministic, headless)
Run tests/stitched_s6_moonblack_fray_offer_test.gd and tests/v3_stitched_pin_cabinet_paperweight_bedwarmer_events_test.gd with Godot 4.7.2 headless. Explicit cases: one living doll at FRAY 1 and Wren FEAR 8 can pay 16 gold, gets raw -10 FRAY intent per active doll and Wren fear 0, with receipt fear_delta -8; at FEAR 3 it clamps to 0; at FEAR 0 no negative fear result; a LOST doll at FRAY 150 does NOT satisfy min_fray if surviving dolls have FRAY 0; 15 gold refuses; missing/invalid wren_fear refuses; choice stays unclaimed after refusal, stale snapshots do not commit, repeat claim cannot double-award; lift_shadowed_map and leave remain as authored; same snapshots/seed never advance RNG. Make all changed fixed-key or source-shape oracles accurately reflect this single addition; preserve their independent hardcoded expectations and existing fail-closed coverage. Inspect tests/run_stitched_event_consequence_test.gd as a stable reference to the existing fear contract, but do not copy expected values from the production output. Run standard full suite where the lane runner permits.

## Acceptance criteria (each objectively checkable by the tests)
AC1: With the shipped Moonblack event record loaded, buy_quiet_house_plan keeps exactly -16 gold, -10 FRAY per active doll, candle 0 and min_fray 1, adds native int fear -8 and the short plain-language text; both other choices and all previously authored event IDs remain. Prove by independent JSON schema oracle and legacy anchor tests.
AC2: With four valid ranked dolls, at least one non-LOST doll at FRAY >= 1, enough gold (16) and valid Wren fear 0..100, preview and single claim agree on wallet/fray/fear, fear clamps 8->0 and 3->0, and LOST recipients receive no fray. Underfunded (15), all survivors calm despite a frayed LOST doll, absent/invalid fear, stale and repeated requests refuse without mutation or RNG. Prove via focused deterministic service tests.
AC3: Existing Cabinet, Paperweight and Bedwarmer event catalog witnesses and alternatives remain valid, no new UI, screen, Event, quote/forecast field, S15 change or part stat is introduced. Prove by both named headless test files and full lane suite.

Standing scope authority: make the smallest supporting code and existing-test correction actually required by AC1-AC3, including affected shared tests, preserving all negative/fail-closed assertions. Do not touch the main-cycle resistance/rules/session/save/matrix files, lane3 enemies/foe intents, next-cycle app.gd/Peddler Save files, or lane5 shop/stock tests. Any genuine need for owner choice is a deferral to record, not a permission to invent another goal.

@@TASK_SCOPE_START@@
{"feature":"Moonblack Paperweight S6 Event adds Wren fear relief to its existing paid house-plan choice","files":["data/events/stitched_route_effects.json","tests/stitched_s6_moonblack_fray_offer_test.gd","tests/v3_stitched_pin_cabinet_paperweight_bedwarmer_events_test.gd","scripts/run_stitched_event_consequence.gd"],"depends_on":["scripts/run_event_choice.gd"],"size":"medium"}
@@TASK_SCOPE_END@@
@@LANE_lane4_END@@

@@LANE_lane5_START@@
TITLE: Price the Wool Patch Cloak as the mid-tier Patch Stall button
MILESTONE: S6

## Goal
Make the existing, fully-authored protective COAT button a realistic intermediate-priced corridor stop purchase without adding a service, UI, shop ware illustration or catalog member. Price-only balance, one named item and its existing exact-value regressions.

## Details (all rules/numbers/names needed, copied from the docs)
Existing Stitched Patch Stall offer source data/shop/stitched_patch_offers.json has eight distinct COAT button entries, with these currently authored prices: scrap_lined_vest 20, padded_vest 35, wool_patch_cloak 75, quilted_coat 90, chain_stitched_coat 95, double_quilt_coat 100, reinforced_patchcoat 105, thick_felt_mantle 110. Their existing max-HP bonuses come from data/patches/m04_coat_patches.json: respectively +3, +4, +5, +6, +7, +8, +9, +10. Change ONLY wool_patch_cloak from 75 to 55 gold; keep its +5 max HP and every other price, record, ability and ID unchanged. This forms a 35/55/90 gold progression among +4/+5/+6 buttons and affects the actual seeded stock and purchase, not a service forecast. In player-facing writing the legacy power trinkets are BUTTONS, never 'ability patches' (those are distinct S14 items sewn on signature abilities). No data/parts edits, no body-part ability tuning and no new art.

The existing RunStitchedPeddlerStock sampler reads this Stitched JSON (not retired initial_offers.json), produces three distinct seeded offers and enforces the existing 20/35 budget guarantee when eligible. RunPatchStallVisit supports genuine one-purchase, sold and free Leave semantics; on a real route, the patch is applied as the existing coat bonus, never a new effect. No scene, corridor visit, map, item render, caption, quote/forecast or S15 rules changes.

## Files likely touched
- data/shop/stitched_patch_offers.json (one wool_patch_cloak price).
- tests/run_stitched_patch_stall_stock_test.gd (update EXPECTED_PRICE, the Wool Cloak focused seeded exact-gold/one-short cases, and independent neighboring price oracles; retain all budget cases).
- tests/stitched_s6_peddler_patch_live_test.gd (update existing live COAT price tables and Wool Cloak 75-gold assumptions to 55, without changing +5 bonus or public route setup).

## Tests to add or update (deterministic, headless)
Run tests/run_stitched_patch_stall_stock_test.gd and tests/stitched_s6_peddler_patch_live_test.gd with Godot 4.7.2 headless. In a bounded seeded stock sweep observe one legitimate wool_patch_cloak 55 row among three unique offers, compare two freshly seeded RNG replays and preserve owned exclusions; at 55 gold a real Patch Stall callback purchases the cloak once and charges 55, at 54 gold it refuses without spending, a repeated/stale callback cannot repurchase, and a sewn/valid +5 COAT bonus remains unchanged. Ensure budget guarantee still stocks one of scrap_lined_vest 20 or padded_vest 35 while eligible and that the other seven authored offer prices are unchanged. Run tests/stitched_s6_patch_stall_salvage_test.gd as a read-only regression if feasible: it consumes the same catalog without requiring a fixed catalog total or order. Run full suite via existing relay runner if available. Do not hardcode any new total count, global ordered list or seed outcome where a legal seeded search suffices.

## Acceptance criteria (each objectively checkable by the tests)
AC1: Given the existing eight-entry Stitched source, only wool_patch_cloak price changes from 75 to native integer 55 while its COAT +5 max-HP definition and other seven record prices remain unchanged. Prove by authored-source exact-ID assertions and coat catalog inspection.
AC2: Given a caller-seeded normal three-offer Patch Stall sample and ownership ledger, the Wool Cloak appears at 55 in a bounded genuine witness, three rows remain distinct, same-seed replay and RNG match, owned offers remain excluded, and the 20/35 budget guarantee still holds. Prove by existing stock sampler test, preserving invalid-source and sold coverage.
AC3: Given a lawful funded routed Patch Stall purchase/equip, 55 gold buys the Wool Cloak once, 54 gold cannot, the gold debit and receipt are exactly 55, and +5 max HP still applies only through the established coat rules. Failed/stale/double and saved/replayed visits remain immutable. Prove by existing live Peddler patch test and relevant stock/visit tests.

Standing scope authority: make only the smallest supporting code/test correction required by AC1-AC3, including other existing affected tests if proved necessary; do not weaken fail-closed cases. Do not alter lane4 Event files, the active main-cycle S15/rules/save/session/tests, lane3 foe data/intent/tests or next-main-cycle app.gd/Peddler Save tests. If a change requires a new owner decision, defer and record it instead of broadening the goal.

@@TASK_SCOPE_START@@
{"feature":"Stitched Patch Stall Wool Patch Cloak mid-tier price and routed purchase witnesses","files":["data/shop/stitched_patch_offers.json","tests/run_stitched_patch_stall_stock_test.gd","tests/stitched_s6_peddler_patch_live_test.gd"],"depends_on":["scripts/run_stitched_peddler_stock.gd","scripts/run_patch_stall_visit.gd","data/patches/m04_coat_patches.json","tests/stitched_s6_patch_stall_salvage_test.gd"],"size":"small"}
@@TASK_SCOPE_END@@
@@LANE_lane5_END@@

@@FILE_END@@