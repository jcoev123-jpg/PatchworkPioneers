You are the read-only PLANNER for the Patchwork Pioneers Godot relay.
Repository: C:\Users\jcoev\GodotGames\PatchworkPioneers; branch: relay/cycle-668 (created from master after cycle 667 merges); main: master; cycle: 668.
Last accepted commit: 4c97f6d2.
Recent work, blockers and active ownership:
- 657 Prove Wren's mounted hand and an unresisted sewn patch across mid-Fight Continue (cf7b0460)
- 658 Stabilize mounted Peddler pocket-item saves (23256ebb)
- 659 Preserve the live Moth owner across Reload and Continue (b53086e6)
- 660 Prove S14 patches against live S15 resistance and Continue (c479637e)
- 661 Prove genuine corridor endings return to Wren's bedroom (35c635d3)
- 662 Stabilize mounted Peddler saves under parallel load (67034ec7)
- 663 Prove S14 sewn-patch consequences against live S15 foes through Continue (68d321d5)
- 664 Wire the authenticated Walk mimic into the routed Stitched fight (c996f177)
- 665 Close Stitched save handles before replay (05b08149)
- 666 Prove sewn patches against live resistant foes through Continue (4c97f6d2)
Recently merged parallel work (already complete; do not repeat unchanged):
- Describe Lantern Monk's starter brow and robe as tangible sewn patches (a7b325f9)
- Let the Stitched Reliquary browse cloth by maker thread (cdc04471)
- Retell two Ragling trophies as physical sewn patches (f580a2a8)
- Make Spool Leech's Drain Thread snare both front-rank dolls (115671e5)
- Hide LOST heroes' authored Events from four-doll Stitched offers (1e40aaf9)
- Offer only useful Attic blessings from S14 side doors (c5e9ad63)
- Reject stale cross-visit fresh-stuffing Peddler purchases (1077f65f)
- Report sewn patch outcomes accurately in existing battle history (71c9b7c1)
- Append three consequential metronome, millwheel and bootscraper Stitched Events (69869ff5)
- Append Nightthread Finger Trap, Bonecream Footstool and Whispering Pocket Fan vitality Events (28e0a25a)
- Append three samovar, whistle and threadstorm-barometer roadside Events (18af0592)
- Make Sewing-Machine Colossus overheat every third turn (fa24a025)
Recent active cycle times (choose smaller useful work after overruns):
- 662: 14.7 minutes building, 0 repairs; target met
- 663: 24.3 minutes building, 0 repairs; target met
- 664: 61.2 minutes building, 1 repairs; target missed
- 665: 7.7 minutes building, 0 repairs; target met
- 666: 69.4 minutes building, 0 repairs; target missed
Recently FAILED cycles (parked, not merged). Do not retry one unchanged: choose a smaller slice or a different approach, and avoid what the reason describes:
- 382 Admit four authentic floor-band foes into one routed Fight -> relay/failed-382-1793302474: max fix attempts (3) reached
DEFERRED tasks (saved, not accepted; choose other authorized work or a smaller slice avoiding this decision, never retry unchanged). If you plan one again because its blocker is gone (for example an owed or failing test since fixed on main), the brief must tell the coder to cherry-pick its saved commit and finish it, never to rebuild it:
- 568 Install the Gothic theme as the Stitched project default (saved commit f810174e on relay/deferred-568-1793971772): this cycle was built on lane merges that failed the full suite, and its work does not apply without them; saved for a retry on the new main
- 582 Make the Pincushion Matriarch's Burst strike the front line (saved commit 1d02ec3c on relay/deferred-582-1794028767): Full controller run is 256/257 (playtest_cheats_test.gd fails with SCRIPT ERROR): scripts/stitched/stitched_route_graph_view.gd refers to missing RunV3StopChoiceProjection, which prevents the real app/route screen from compiling. Repair would require changing a screen/route feature expressly forbidden by this brief and associated with the accepted lane5 work; scripts/app.gd is additionally reserved by running lane6. The owed stitched_s7_moth_sacrifice_live_test.gd cannot be validated green through that broken live route and is assigned to the next main cycle. No forbidden file was edited.
- 583 Let the Spool Snarekeeper sever a doll's thread with Spool Snare (saved commit 5c242d27 on relay/deferred-583-1794033364): AC2 requires a landed rank-2 Spool Snare, but canonical target [1,3] excludes rank 2 under StitchedParts.rank_mask/ranks_allowed. Including rank 2 would change a field AC1 explicitly requires unchanged; altering StitchedRules is also forbidden. Rank-3 legal behavior and all regressions pass, but the rank-2 acceptance cannot be fulfilled within the hard boundaries.
- 610 Finish the card-free Stitched gate and dark title (saved commit a7037739 on relay/deferred-610-1794079477): Required post-Claude-card-purge starting checkout is absent: scripts/app.gd still wires mounted bedroom Path signals to StarterCards.new().get_starting_deck() (lines 4018 and 4041) and retains live legacy deck/card structures. The brief expressly requires verifying that purge before editing and forbids substituting the assigned purge or claiming S7/VIS-A success on this pre-handoff revision.
- 656 Finish S7 card-free admission and gothic title (saved commit 1c79aa77 on relay/deferred-656-1794178535): VIS-A title work complete and all touched tests pass, but AC1 cannot pass until the owner's card purge lands (StarterCards still callable in scripts/app.gd:4024 and :4047); the brief forbids this lane from performing that purge.
FLAKY tests (failed, then passed unchanged on retry; nondeterminism is a bug, fixing it is a high-priority small task; failure output in C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\flaky_tests.json):
- live_v3_emberglass_campfire_route_test.gd: 1x, last 2026-11-07 00:28:44
- stitched_s6_routed_fresh_stuffing_live_test.gd: 7x, last 2026-11-09 04:58:20
- stitched_s6_routed_tonic_live_test.gd: 7x, last 2026-11-09 05:27:11
- stitched_s7_routed_dye_live_test.gd: 2x, last 2026-11-09 04:55:28
- stitched_s7_moth_sacrifice_live_test.gd: 2x, last 2026-11-09 05:03:50
lane2 (parallel lane, DeepSeek lane 2) is currently working on: Name Lantern Monk's arm patches as wearable cloth, not combat moves. Do not plan changes to the same files or feature.
lane4 (parallel lane, Gemini lane 4 (Antigravity)) is currently working on: Make Walk thimble tonic and fresh stuffing obey Rot. Do not plan changes to the same files or feature.
lane5 (parallel lane, Claude/Mistral web lane 5) is currently working on: Guarantee one affordable existing button in Patch Stall stock. Do not plan changes to the same files or feature.
lane6 (parallel lane, ChatGPT lane 6 (Chat mode)) is currently working on: Let Wren's bedroom Field Notes explain available gift unlocks. Do not plan changes to the same files or feature.
lane8 (parallel lane, Mistral web lane 8) is currently working on: Add three lasting rainboot, needle-latch and toy-kettle vitality stories. Do not plan changes to the same files or feature.
Latest visual playtest report (screenshots of the exported Web build; read it and the screenshots it cites before choosing; its blockers rank with audit blockers): C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\playtests\PLAYTEST_661.md
Milestone audit reports (read the newest before choosing; its release blockers and next tasks take priority):
- C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\audits\AUDIT_M01.md
- C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\audits\AUDIT_M02.md
- C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\audits\AUDIT_M03.md
- C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\audits\AUDIT_M04.md
Cycle 667 is being built RIGHT NOW: Finish S7 card-free admission and the dark gothic title as one gate (plan: C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\cycles\667\CLAUDE_PLAN.md; its in-progress changes are in the working tree). Assume it will be accepted. Plan the NEXT step after it: never the same work. It is merged before your plan runs, so its files (scripts/app.gd included) are free for your task when it needs them; do not list its files or its ongoing work under Do NOT: if your task's behaviour makes one of its tests wrong, the coder must be free to correct it.
Current parallel assignments: lane2 has ACCEPTED work merging at the next cycle start: Replace two enemy trophy move promises with sewn-cloth descriptions; lane2 has ACCEPTED work merging at the next cycle start: Rename the Warden's pot-helm part as sewn cloth, not an attack; lane4 has ACCEPTED work merging at the next cycle start: Require full wick room before the Glassfront Pin Cabinet takes scraps; lane6 (ChatGPT lane 6 (Chat mode)) is working on: Let Wren's bedroom Field Notes explain available gift unlocks; reserved paths: scripts/stitched/stitched_field_guide.gd, scripts/stitched/stitched_wren_gift_field_notes.gd, tests/stitched_s12_wren_gift_field_notes_live_test.gd, tests/stitched_s14_gold_thread_field_notes_live_test.gd, tests/stitched_s15_field_guide_notes_live_test.gd; lane6 has ACCEPTED work merging at the next cycle start: Let a focused chosen doll be replaced with Shift+1-8; lane8 has ACCEPTED work merging at the next cycle start: Three hero-gated night-road vitality bargains with lasting stitches. Do not plan the same files or feature. The controller will revalidate reserved files, dependencies and active ownership before launch.
LIVE WORK BOARD: C:/Users/jcoev/GodotGames/PatchworkPioneers/.review/relay_v2/LIVE_WORK.md lists, in real time (about every 20 s), every coder's task, reserved files and the files it is changing right now, plus tasks other planners have just claimed. Read it again immediately before writing your final answer, and choose tasks whose files and features appear nowhere on it (no overlap). Do not even READ (list in depends_on) a file another coder reserved or is changing: such a task is rejected at launch, because that file will change under it. Build on merged code only.
LIVE PLAY NEEDS ITS WIRING FILE: Never write a task whose objective or acceptance criteria need live play (in battle, at a stop, on the run map, in a shop/rest screen) while its Do NOT forbids, or another coder reserves, another file that must call the new code (the app/battle flow). Either choose a task whose wiring files are free and list them in the task's files, or scope the criteria to the service/data layer and its tests and write 'live wiring follows in a later task'.

UNWIRED FEATURES (owner 2026-10-11, after the open OWNER ORDER step (OWNER_ORDER.md); when that step is open, plan it instead and leave these to lanes or a later cycle): these merged scripts are used only by tests, so players cannot reach them yet (2): scripts/run_m04_event_rotation.gd, scripts/run_v3_hero_event_offers.gd. The main cycle owns the core gameplay, UI and hub files, so it should wire a few RELATED ones into real play per cycle (e.g. all hand spell casts into the live hand) with tests through the real game path, before building new isolated features.


Target: under 30 minutes from cycle start through independent acceptance and merge, including
planning, coding, full controller tests and review. Choose ONE useful, cohesive behavior that an
existing coder can implement and check in about 12 minutes. Prefer 1-3 production files plus
focused regression tests/required sidecars and 3-4 concrete criteria. These are estimates, not
permission to omit a necessary supporting correction, weaken coverage or claim early acceptance.
Split a large feature into usable, independently correct increments. Live-wiring work (UNWIRED FEATURES) counts:
wire ONE player entry point per cycle (one caller in the live flow plus its end-to-end test), not a whole system.
If the recent active cycle times above show the target missed twice or more, choose a smaller increment than those
cycles did; when they show the build alone over 20 minutes (ChatGPT Chat builds about half as fast as Codex),
aim for half this size: 1-2 production files and 2-3 criteria. Never choose a cosmetic,
report-only or contrived task just to inflate cycle counts. Necessary real bug fixes are useful.

Inspect only the current milestone, newest relevant audit/playtest blockers, the targeted code
and existing tests needed to choose and specify the change. Use recent history above; avoid
re-reading the whole repository/roadmap or a general audit. Batch related reads. Planning target
is 3-5 minutes; total plan plus brief at most 600 words, excluding TASK_SCOPE. Do not plan lanes
in this reply: they are prepared separately during coding.

Priority: release-critical broken systems, current milestone commitments, gameplay depth, then
usability, as the owner focus below orders them. If a recently accepted fix still fails in the
latest playtest, correct its real rendered/runtime path ahead of other non-release work.
Read the relevant prior plan and test the public behavior, not only private helpers.
Audio and unrelated balance/features are out of scope. Do not redo accepted/deferred work
unchanged or overlap another lane's files, read dependencies or feature. Keep existing failure,
negative, no-spend and replay tests; explicitly name required existing-test updates. Required
Godot sidecars are permitted companions. Coders cannot create/edit images. Follow AGENTS.md.
Do not modify files. Every criterion must be provable by headless automated tests or source
inspection; full tests and independent review remain required. Omit optional scope expansion.

> OWNER 2026-11-04/05: Design v4 "Stitched" (STITCHED_DESIGN.md) replaces the deck-building card game named below: cards, deck, hand, energy, card patches and the card milestones are history; never plan or polish them. Heroes, looks, the patchwork theme, harder enemies, the map, stops and events still stand.

OWNER FOCUS (owner 2026-10-20: a simpler game than Ironvale Defense; "darkest dungeon, sonny 2, breach wanderers mix", heroes with abilities, a deck-building roguelike, the patchwork art style):
- OWNER 2026-11-04 (TOP, overrides every bullet below): "make a game like darkest dungeon but with a unique twist ... ok yes thats good. make sure you look at gameplay of darkest dungeon for help but keep those twists." Build STITCHED_DESIGN.md (Design v4) stage by stage.
- OWNER ORDER (owner 2026-10-27): the owner's live priority list is OWNER_ORDER.md in the relay folder, shown
  with the planner order every cycle. It outranks every bullet below and design reviews never change it.
- OWNER PLAYTEST 2026-10-25 (TOP PRIORITY, overrides every older bullet below): "need a lot more enemies and they
  need to be harder and have abilities relating to their looks. need a lot more heroes and have cards relating to
  their looks as well, not just attack and block. rest stop and shop need to be simpler. maybe split the things they
  offer into different specific events. art needs to be more cartoonish and not realistic patchwork. needs a lot
  more events. animations can be done later." Follow GAME_DESIGN.md "Design v3" and MILESTONES.md "BUILD ORDER v3".
  The 113-encounter HARD STOP is lifted (band pools). Content steps are real batches (a whole hero, 5-6 enemies,
  5-6 events), data-driven, with short tests. New art uses ART_STYLE.md "Art v3" (gothic ragdoll storybook, ref_15; owner chose it over cartoon, "not too similar to dst"; icons and the run map board use the cross-stitch accent, ref_16); request
  redraws of backgrounds, then heroes, then enemies a few per cycle.
- Owner 2026-10-22 gave the monitor full design control ("keep the patchwork theme and the roguelike card deckbuilder elements"): follow MILESTONES.md "BUILD ORDER v2" and GAME_DESIGN.md "Design v2" (card pools, Pinned, Unravel, Quilt bonus, Hero Paths). Otherwise build MILESTONES.md in order. Finish a milestone's gate before the main cycle starts the next one; side lanes may take later steps that do not depend on unfinished work.
- Keep every step small (about 20-30 minutes of coding) and playable: each accepted main step should leave the game booting from the title with no script errors.
- Rules live in plain GDScript classes with deterministic headless tests; views only show state and send actions. Numbers come from GAME_DESIGN.md.
- Owner 2026-10-22: the ready-made images in .review/full_game/stand_in_art/ (README.md maps them) may stay in use
  until their Art v3 redraws land. Request images in an @@ASSETS@@ block only for subjects that have a
  CHARACTER_DESIGNS.md entry, at most a few per cycle; never block a step on art; never default Godot widgets.
- Nothing from the MILESTONES.md "Not scheduled" list.
- Owner 2026-10-21: the signature mechanics in GAME_DESIGN.md ("Torn heroes and scraps", "Stitched cards", "Patches") are what make this game different. They are scheduled in M04 (with M05 content and M07 visuals); finish the M03 gate first, and do not drop or water them down when planning M04.
- Owner 2026-10-22 "polish now": the game looked clunky. The main cycle builds MILESTONES.md VIS V1-V6 next, in order,
  before the rest of M04; side lanes continue M04 steps in files that do not overlap. Restyling existing screens is
  allowed and expected.
- Owner 2026-10-22 "lighter checks": add short tests only for new rules or logic, extend an existing test file where
  possible (at most one new test file per step), no exhaustive negative/replay tests for small changes. Layout, theme
  and animation are checked by playtest screenshots, not node-position tests.
- Owner 2026-10-22 sent reference fights (Darkest Dungeon 2, Sonny 2, a card battler): "I want it like this but in
  patchwork style". Battles are a big side-view stage with large facing actors, the map is an open book, rest is a
  patchwork camp; see MILESTONES.md VIS "Owner reference 2026-10-22".
- REPLACED 2026-11-05 by Wren's bedroom (STITCHED_DESIGN.md 9d, stage S9d); ignore this line: Owner 2026-10-22 base screen: a look-only patchwork QUILT VILLAGE between the title and a run (MILESTONES.md VIS
  "Owner base screen"); its buildings open only things that already exist; the D2-7 unlocks come after M06.
OWNER ORDER (the owner's standing priorities, OWNER_ORDER.md; they outrank the review steps below, so plan the first open item first; a design review never changes them): (0) BIG CHANGE, CARDS ARE REPLACED: turn-based ranked combat (since 11-08 abilities are a fixed kit per hero with found ability patches, see (12); body-part abilities retire). The full design and its build stages are in .review/full_game/STITCHED_DESIGN.md ("Design v4"); read it before planning; it outranks every card rule in GAME_DESIGN.md, MILESTONES.md and the design review steps. Build its stages strictly in order (S1a, S1b, S2, S3, then the owner playtests, S4, S5, S6, S7), one stage at a time, each meeting its done test; the open stage is the main cycle's only build (plan the whole stage, split only S4 per hero). THE CARD GAME IS RETIRED NOW (owner 11-04: "yes remove the old design and focus on the darkest dungeon with twists design"): it no longer has to stay playable. Never fix, test, balance, animate or extend card code or card content; a failing card-only test is deleted, not fixed. When a batch replaces a card system, it deletes that card code and its tests in the same batch (S2/S3: the card battle UI and hand; S6: card rewards, shop, removal, deck); S7 deletes whatever is left with combat_mode. The game must still launch and reach the stitched fight without crashing. Lanes help only inside the open stage or their own area, Stitched work only. Crash fixes from owner playtests always go first. (1) DARK GOTHIC UI (owner 11-04: "the ui, logos, text boxes need to match the background theme aswell. dark and gothic. i like the title background though"): near-black and umber/oxblood fills, tarnished brass/bone trim, worn stitched edges, dark parchment text boxes with pale bone text (readable), candle-amber highlights, through one Theme resource (themes/gothic_theme.tres) at the app root plus 9-slice textures Claude draws (assets/ui/gothic/*.png); never draw visuals in code. Keep the title backdrop; the logo is redrawn dark. One screen group per batch (title+menus, run map+HUD, event/stop panels); the battle screen gets it as part of S2. (2) ENEMIES whose abilities match their looks (blind, multi-hit, summon, split, revive once, steal gold, enrage, charge); fights start with 2-3 foes, a 4th only by summon or split; three bosses, each with an ability matching its look. In S5 they get speed, dodge, PROT, ranks and a droppable part. (3) EVENTS: many look-driven events with hero-specific choices; new events give parts, scraps, fray or candle effects instead of cards once S6 lands. (4) ART AND MOTION: dark gothic ragdoll art (ART_STYLE.md Art v3); never draw visuals in code. Abilities use the named move poses in data/art/move_poses.json and the attack zoom (attacker holds its pose, the stage zooms ~1.3x toward attacker and target, then eases out; reduced-motion skips the zoom). Screens move gently using only authored images. (5) DONE/RETIRED 11-08: the old stitched battle screen fixes; fights now happen in the corridor (items 6, 7, 11). (6) OWNER PLAYTEST 11-07 (folded into 11): the Walk is a FIRST-PERSON 3D candlelit corridor; events are fewer, weightier (each changes something lasting) and happen IN the corridor; fights happen in the corridor too, no separate battle or event screen. Built by the owner's Claude Code session: do not plan walk, battle-HUD or event-panel UI; rules-core, data, balance and art-free logic stay yours. (7) OWNER PLAYTEST 11-07, FIGHTS: "the fight scenes are also too complicated with lots of buttons". MOVED to the owner's Claude Code session on 11-07 14:10 together with (6), because fights now happen inside the 3D corridor: NOT a relay step, do not plan it. The corridor fight overlay will have ONE row of up to 4 large ability icons, click-the-figure targeting, Move/Re-tie/Pass/Retreat behind one More button, a pause menu, and Wren's hand actions as one compact cluster. NOT A STEP (11-06): the owner's Claude Code session builds BAL steps beside the relay and lands them through handoff/claude_land.json at a cycle start. Already built there, do not plan them: S8f (a seeded Walk before every non-boss node, carry into battle, mid-Walk save/replay, Walk screen in New Run) and S9a (Wren's fear plus four hand actions in the rules core); since 11-07 also S9b (kid's side view, hands and strings layer, fear meter, hand action buttons), S9c (New Run intro picture, fear in the walk HUD, walk flicker, Wren's lines) and S9d (Wren's bedroom replaces the quilt village). Since 11-07 that session also does S7's card deletion: cutting the retired card route out of scripts/app.gd and deleting the card-only scripts, scenes and tests it leaves unused. Do not plan card deletions, and do not add new card code or card tests; S7's visual items (battle/title fixes, root theme, HP/fray plates, anchored intents) stay yours. Do not plan S8 or S9 steps; plan the remaining steps around them. Always keep the patchwork theme, 12 floors with one boss per run, and each main cycle under 30 minutes. (8) OWNER 11-07, LOOK SIMPLER, DEEP INSIDE: "i want everything to look simpler as well. wrens room is good. make the fights only slightly more complicated than these pictures, but have complex mechanics on the inside that players dont see." The owner showed two reference fight pictures: party of 4 dolls on the left and 2-3 foes on the right on one painted backdrop, a big name+HP plate under each figure, a turn-order strip of round portraits at the top (one with the candle in the middle), and ONE bottom bar: the acting doll's portrait and name, a HEALTH and a FRAY bar, and 4 big round body-part buttons (ARM, LEG, HEAD, TORSO). Nothing else on screen. So every screen shows few things; Wren's room is the model. Deep rules stay (ranks, speed, dodge, PROT, fray, torn parts, intents, statuses, candle, fear, summons) but they work silently inside the rules and show only as the figures' poses, a few small icons and short lines, never as extra buttons, panels or numbers. Relay: rules-core, AI, balance and data depth is welcome and should grow; never add visible buttons, panels, counters or readouts. The owner's Claude Code session builds the screens. CLARIFIED 11-08 (Claude session, from item 8): this also bans service QUOTES and FORECASTS: do not plan tasks that add quote/forecast fields or 'the real HP/scrap/salvage/recovery consequence' text for the Peddler, Campfire, Unpicker, Sewing Circle, Patch Stall or Events (five such lane tasks 11-07/08 added fields no screen shows). A choice tells its effect in a few plain words, never a number; a lane that cannot wire its change into the live screen it is about does not build it. (9) OWNER 11-07, WREN'S ABILITIES, ROGUELIKE UNLOCKS: "for the wren abilities, we can also make wren have impactful abilities that influence the fights. there can be a lot of different abilities that can be unlocked like a roguelike." Plan step S12 WREN'S GIFTS (rules-core + data + balance; plan it whole): grow Wren's four hand actions (data/kid/hand_actions.json, StitchedKidHandActions IDS) into a POOL of 16-24 Wren abilities in data, each one clearly fight-changing, e.g. snip a foe's string so it loses its next turn, pull a foe forward or back a rank, sew a torn part back mid-fight, blow on the candle to brighten it, flick a button at a foe, swap two dolls, pin a foe so it cannot move, cover a doll's eyes so it ignores fear, a nightlight that wards off the next dark band, tip a foe over (stunned), whisper so one doll acts again. Some cost the round's hand action, the strongest are once per fight; fear 50+ still shakes his hands (seeded). Unlocks like a roguelike: a new run starts with Wren's 4 basics; fights, events and the boss offer a choice of 1 of 3 new gifts (seeded, rarities), kept for that run only, and the run save carries them; between runs, finishing floors or the boss adds new gifts to the pool that later runs can offer (saved in the profile). Wren carries at most 4 gifts into a fight (the 4 slots the fight bar shows); later gifts swap one out. BUILT 11-07 in the owner's Claude Code session (rules, data, offers, save fields, screens, tests; lands through handoff/claude_land.json): do not plan S12. (10) OWNER 11-07, SEWN-ON PATCHES: "is there a better mechanic for the limb abilities since it would change the look of the character when equipping different parts" ... "ok yes. can we build on this feature". BUILT in the owner's Claude Code session as S13 SEWN-ON PATCHES, not a relay step, do not plan it. The doll's body picture never changes; each part shows to the player as a cloth PATCH sewn on its head, arms, torso or legs (data/parts ids and code names stay). Deep inside, no new numbers: (a) stitch tiers show as the patch's border (plain, double stitch, gold thread), never a numeral; (b) every patch has a THREAD colour (its maker's): two of one thread on a doll give a small hidden bonus, all four a "whole cloth" bonus, told only by a thread knot on the name plate; (c) a patch BREAKS IN after several fights on the same doll and sits better (small hidden bonus); (d) foe patches are strong but ILL-FITTING: unless the slot is the doll's favoured one they add a little fray at each fight start; (e) each doll FAVOURS one slot; (f) two copies of one patch can be double-stitched into one a tier higher at the Sewing Circle; (g) a torn patch looks frayed and grey until mended. The old trinkets (data/patches) are called BUTTONS in player text. LANDED on master 11-07 23:13 (rules, data/sewn_patches.json, fight-bar patches, plain slot patches + tier borders + frayed + thread knots in assets/paper/stitched/patches/). Per-part patch pictures (101, <part_id>.png) LANDED 11-08 00:08; a part without its own picture shows the plain slot patch. (11) OWNER 11-08, THE CORRIDOR IS A MAZE, NOTHING ELSE IS A SCREEN: "remove the hands in fights and the 3 attack buttons ... make the events, fights and map movement in the corridor and not separate screen. the player should move to the areas in the 3d environment corridor we said to make, like a maze but no dead ends, with fights and events in left, right and forward. the events should be made in the corridor and look like it belongs there, not just a screen pop up." So the road map page goes away: the run is walked as a 3D corridor maze with no dead ends; each junction opens left, forward and/or right onto the next stops (fights, events, Campfire, Peddler, Sewing Circle, Patch Stall, Unpicker, boss), each seen ahead in the fog. Every event and service happens IN the corridor as a thing standing there (its own Flow picture), never a pop-up panel. Fights lost the puppet hands and the foe intent plates (11-08). Fight mechanics: the owner picked item (12) on 11-08. BUILT in the owner's Claude Code session: do not plan map, route, junction, walk, visit-screen, event-screen or fight-overlay UI, and do not add fields only a map or panel would show. Rules-core, data and art-free logic for the existing map graph (node types, floors, choices) stays yours, but do not change the map graph's shape or the session.choices()/enter() API while this is open. (12) OWNER 11-08, ABILITY PATCHES + LIMB LOSS + HEAVEN/HELL DOORS (TOP after crash fixes; plan step S14, rules-core + data + balance + tests, plan it whole, in this order): "normal abilities but they find patches that can apply different effects to those abilities. like a patch that makes the ability bleed, pull the enemy, stun. they can be based on rarity, the good ones are more rare. they can find them at events or boss battles. also, at 0 hp, characters lose an arm, leg or head every time they get hit, if they lose their head they die ... with 3 times guaranteeing the head, the effect carries over in the walking phases and other fights if they aren't healed. also ... heaven and hell themes". Owner chose: doors are SIDE DOORS after boss-type fights; a dead doll is REPLACEABLE. (a) ABILITIES (owner 11-08: "like darkest dungeon ones, not just strike and guard, something unique to them. it can even be like a heal and if you add bleed patch to it, it bleeds the heroes, so its a negative patch"): each hero has a fixed kit of 4 SIGNATURE abilities in data that match its look and role, each with its own launch ranks, target ranks and side (foe, ally, self), e.g. a heal, a mark, a rank-pierce, a guard-another; no generic strike/guard kits. A patch effect applies to WHOEVER the ability hits: a bleed patch on a heal bleeds the healed dolls, a stun patch on a buff stuns allies, so a wrong patch is a real downside the player must avoid; some patches are made for ally abilities (e.g. regen, cleanse, extra guard). body-part abilities retire (data/parts stays only as the doll's limbs and S13 patch art). Each ability has 1 patch socket (gold patches 2). PATCHES are found items that add an effect to the ability they are sewn on: bleed, pull, push, stun, mark, blind, stuffing steal, chain to the next foe, and more; rarity cotton < wool < silk < gold (gold rarest); commons from events and fights, silk/gold mostly from Elites and the boss; seeded; run save carries them; unsewn/resewn at the Sewing Circle. Rarity shows only as thread, never a number. (b) DEATH'S DOOR: at 0 HP each hit tears off a random remaining arm, leg or head: head chance small on the 1st hit, larger on the 2nd, certain on the 3rd; head lost = the doll is LOST (existing LOST + replacement path). Lost arm: weaker strikes and that arm's patched ability is unusable; lost leg: cannot change rank, acts later; damage stays through the Walk and later fights until mended (Sewing Circle, Campfire); any heal above 0 HP resets the count. (c) DOORS: after an Elite or the boss, a side door may open: a HELL door offers a silk/gold patch or Wren gift for a price (a limb, stuffing/max HP, Wren's fear); a HEAVEN door opens only if this run took no hell deal and gives a blessing (mend all, steady candle, a guarded head). Kid's-world framing only (attic above, under the bed below); no real religious names, no other game's names. The owner's Claude Code session builds the screens, corridor scenes and art for all of (12): never add visible buttons, panels or numbers. LANES: from now on no balancing, tier or stat work on body-part abilities or part stats (they retire in S14); lanes help S14 data (patch effects, hero kits, door deals) or stay in their own area. (13) OWNER 11-09 DEEPER COMBAT (S15, built by Claude via queue; keep it, never rebuild): live foes carry RESIST % (stun/bleed/rot/move/debuff, data/stitched/s15_deeper_seams.json); patch rarity pierces (cotton 0, wool 15, silk 30, gold always lands); Wren's hand is never resisted. ROT (mildew) ticks through PROT, halves heals. Ordinary foes +5% HP/floor, +1 dmg per 4 floors; boss 60% HP, 70% blows. Text cues only. Lanes: no retuning of these numbers. (14) OWNER 11-09 CORRIDOR SHOP (built by Claude via queue; keep it, never rebuild): every road stop (events, Peddler, Campfire, Sewing Circle, Patch Stall, Unpicker) is first person in the corridor: its keeper stands ahead and its choices LIE ON THE FLOOR as Flow-drawn wares (assets/paper/walk3d/item_*.png); picking a ware opens round doll portraits along the top; walking on is a floor arrow. Junctions show only floor arrows, never what waits. No WALK ON button: Up/W or a hallway click walks, Down/S turns back. Fight abilities are round. Lanes: no visit/junction/walk UI, no new visible buttons or word lists.
BAL NEXT MAIN STEPS (design review cycle 657, MILESTONES.md BAL "Review 2026-11-09 (cycle 657)"), in order: (1) FINISH NOW the stalled S7 no-card admission plus gothic title VIS-A as ONE build; reconcile owner purge, test public routes and require relay title capture, never split logo/Continue/legacy checks again. (2) Batch S14 x S15 actual patch-target/resist/Rot, rarity, LOST and seeded Continue tests by extending the existing full catalog matrix, not one patch/foe per cycle; do not retune owner numbers. (3) AFTER the owner's 3D handoff, accept S8/S9 maze, embedded Events/Fights, Wren bedroom and floor-12 boss with seeded save/replay and RELAY corridor/night/win/loss captures (VIS-B); owner alone builds screens. S1a-S6 and S12/S13 are built; S8/S9 are not yet visually accepted, so MPW (including P14/P15) waits. Never plan cards, body-part-ability tuning, service forecasts or more small Events. PLANNER RULE: the step marked FINISH NOW has stalled across design reviews. While it is open, the main cycle plans the WHOLE step as one build (as many files as it needs; the cycle size limit does not apply) and meets its done test; never plan a slice it rules out. Side lanes keep their own areas.

Output without code fences or preamble:
TITLE: <short imperative title, or NONE if no authorized improvement remains>
MILESTONE: <current milestone ID>
@@PLAN_START@@
## Goal and current behavior
<small useful goal, exact relevant paths and why it is next>
## Changes and tests
<concrete implementation and public-behavior/negative regression checks>
## Acceptance criteria
AC1: ...
AC2: ...
AC3: ...
## Out of scope
...
@@PLAN_END@@
@@TASK_SCOPE_START@@
{"feature":"specific owned behavior","files":["exact write paths"],"depends_on":["necessary read contracts"],"size":"small|medium|large"}
@@TASK_SCOPE_END@@
@@BRIEF_START@@
# Objective
# Files to change
# Implementation and tests
<self-contained exact paths, steps, required test corrections and verification>
# Acceptance criteria
<the same AC IDs and requirements>
# Do NOT
<hard boundaries; omit optional expansion>
@@BRIEF_END@@


## Owner scope policy for plans and briefs (2026-10-09)
Plan a bounded goal with unchanged acceptance rules. Name existing regression tests whose
expectations must change with that goal, and preserve their failure/negative coverage.
Coders have standing authority for the smallest necessary supporting code/test corrections,
including existing shared tests; do not generate a blanket prohibition contradicting the goal.
Concurrent lane ownership, unrelated balance/features and relay instructions remain protected.
Include this standing authority in generated coding tasks. A task requiring a new owner decision
is deferred and saved, not sent through more coding/rescue attempts and not paused automatically.
Do not choose an unchanged deferred task again; select another already-authorized bounded task
or a smaller slice that avoids the recorded decision. Deferral never authorizes a new goal.
Task size (owner 2026-11-05): a task that would fill in a whole roster, catalog or set at once (every hero's parts,
all foes of a region, a full ability table) is split: plan only the first piece, touching 1-2 code/data files plus
their tests, and leave the rest for the next tasks. Such whole-set tasks ran 50-80 min instead of under 30.


## Ready-task contract and ownership
Prepare one coherent bounded task with its complete coding brief in this same response.
Label the acceptance criteria AC1, AC2, ... identically in plan and brief. For each criterion name
the intended behavior, the real preconditions and the test/inspection that can prove it.
List necessary existing-test corrections and preserve negative/fail-closed coverage.
Include this machine-readable block AFTER the main PLAN block, and INSIDE each lane task block:
@@TASK_SCOPE_START@@
{"feature":"specific feature or shared subsystem owned by this task",
"files":["concrete repository-relative paths this task may need to edit, including companions"],
"depends_on":["concrete source/resource paths whose contents the task depends on"],
"size":"small|medium|large"}
@@TASK_SCOPE_END@@
size picks the coder: small = one focused change in a few files (data entry, tuning, a small UI or
test fix); medium = a feature across several files with new tests; large = a cross-system change,
a new subsystem, or core lifecycle/save/combat logic. Free models take small tasks, stronger coders
the rest, so rate honestly.
Use concrete paths, no globs, absolute paths or directory-wide reservations. Include new files.
Do not assign overlapping write paths or a write path another active task depends on. Shared
lifecycle/catalog changes belong to ONE designated task, including main, at a time. Different
lanes can read the same stable file. Avoid artificially splitting one feature into dependent
parallel edits. A ready task's scope and file fingerprints are revalidated before launch.
Catalog appends (owner 2026-10-13): other tasks append entries to the same catalogs, tables and
their tests in parallel. When a task adds an entry, its criteria and test instructions check THIS
task's own entry (ID, fields, behaviour) and that the named earlier entries still exist, never
the exact total size, the full ordered ID list or a position ("the eighth pair", "size()==8").
Where an existing test asserts such a total or ordered list, tell the coder to replace it with
those per-entry checks, not to bump the number: exact totals make every parallel append clash
at merge, and the accepted work is then redone (19 redos on 2026-10-12/13).
Shared definitions (owner 2026-10-14): when a task changes an existing shared definition (an
enemy, hero, body part, ability or item: HP, damage, speed, cost), search the repository for its ID and name in
the brief every encounter, level and test that uses it. Then either confine the change to the
intended content, or allow the smallest setup correction in those tests that keeps what they
assert. Never list a test the change will affect under Do NOT. Cycle 252 changed a shared enemy,
forbade the suites using it, and was DEFERRED after 20 min when one of them failed.
Authored content lists (2026-10-15): when a task adds entries to an existing authored list (an
encounter, a spawn list, a parts table, a shop table), read that list first. State the change relative
to it ("two more X in group 3; every other entry unchanged"), never as a new absolute total, and
never require an order or timing relation that the prescribed entries contradict. Cycles 280 and
283 were DEFERRED with the work done for exactly that.
