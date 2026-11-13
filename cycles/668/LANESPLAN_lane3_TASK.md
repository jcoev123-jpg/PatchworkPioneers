You plan work for the PARALLEL coding lanes of an automated build relay on Patchwork Pioneers,
a Godot 4 turn-based ranked roguelike (four stitched ragdoll heroes whose abilities come from sewn-on body parts; dark gothic patchwork art style) (repository C:\Users\jcoev\GodotGames\PatchworkPioneers). They work at the same time as the main relay cycle. Do NOT modify any files.
Read with your file tools: the main cycle's plan at C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\cycles\668\CLAUDE_PLAN.md (no lane may touch the same files or feature), and the
design docs in C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\full_game (STITCHED_DESIGN.md, MILESTONES.md, GAME_DESIGN.md, CHARACTER_DESIGNS.md, ART_STYLE.md).
No two lane tasks may edit the same shared file (content registries or catalogs, shared contract or scan tests): lanes
are merged one after another and such overlaps end in merge conflicts or stale tests. If two good tasks would
overlap, give one lane a different task or NONE.


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

Lane lane3's current task "Give wounded Pin Skitter a two-rank Quill Scatter" is ACCEPTED and merges at the next cycle start. Plan this lane's NEXT task, to start right after that merge. Assume that work is merged; prefer files it did not touch.
This lane's focus area: MEDIUM pieces from the current STITCHED_DESIGN.md stage in this lane's area (2-5 files): enemy abilities, intents and their tests, including rules that touch combat. Stay inside it.


PARALLEL LANES (answer in this same reply; it replaces separate planning messages)
These builders work at the same time as the main task, each in its own copy of the repository. They follow
AGENTS.md and CANNOT see the .review/ folder, so every lane task must be fully self-contained.
Plan ONE task for each of these lanes:
- lane id lane3: Codex lane 3 - Codex (local CLI, high effort, full repo access): give it a MEDIUM gameplay feature (2-5 files, about 30-60 minutes) with its tests
  AREA (only this lane works here): ENEMIES: new and harder enemies, elites and bosses with abilities that match their looks (data/enemies, scripts/combat_enemy_*.gd intents and special actions) and their tests
LANE AREAS (owner 2026-10-25): give each lane a task ONLY inside its own AREA above, even when another area has more open work; never give two lanes the same feature, content type or file. Plain data files of another area are off limits; when a task needs a change in another area, leave that part out and say so in the task. If a lane's area has nothing useful left, answer TITLE: NONE for it.
Work running right now in other lanes (do NOT overlap it in files or feature): the main cycle is working on: Prove five live S15 resistance families without false-green gold or miss claims; reserved paths: scripts/stitched/stitched_deeper_seams.gd, scripts/stitched/stitched_rules.gd, scripts/stitched/stitched_run_save.gd, scripts/stitched/stitched_run_session.gd, tests/stitched_s14_effect_matrix_test.gd, tests/stitched_s15_deeper_seams_test.gd; the NEXT main cycle is already planned (Current-generation mounted Peddler Save callback reliability); reserved paths: scripts/app.gd, tests/stitched_s6_peddler_save_generation_test.gd, tests/stitched_s6_routed_fresh_stuffing_live_test.gd, tests/stitched_s6_routed_tonic_live_test.gd; lane3 (Codex lane 3) is working on: Give wounded Pin Skitter a two-rank Quill Scatter; reserved paths: data/enemies/run_enemies.json, scripts/stitched/stitched_foe_intent.gd, tests/stitched_s5_pin_skitter_quill_scatter_test.gd; lane3 has ACCEPTED work merging at the next cycle start: Make the Behemoth's broken seam mark prey and blind the doll line; lane4 (Gemini lane 4 (Antigravity)) is working on: Let the Moonblack house plan soothe Wren as well as frayed dolls; reserved paths: data/events/stitched_route_effects.json, scripts/run_stitched_event_consequence.gd, tests/stitched_s6_moonblack_fray_offer_test.gd, tests/v3_stitched_pin_cabinet_paperweight_bedwarmer_events_test.gd; lane5 (Claude/Mistral web lane 5) is working on: Price the Wool Patch Cloak as the mid-tier Patch Stall button; reserved paths: data/shop/stitched_patch_offers.json, tests/run_stitched_patch_stall_stock_test.gd, tests/stitched_s6_peddler_patch_live_test.gd; lane6 (ChatGPT lane 6 (Chat mode)) is working on: Skin the existing Gothic settings CheckBox without touching App wiring; reserved paths: tests/stitched_s7_gothic_checkbox_theme_test.gd, tests/stitched_s7_gothic_checkbox_theme_test.gd.uid, themes/gothic_theme.tres
LIVE WORK BOARD: C:/Users/jcoev/GodotGames/PatchworkPioneers/.review/relay_v2/LIVE_WORK.md lists, in real time (about every 20 s), every coder's task, reserved files and the files it is changing right now, plus tasks other planners have just claimed. Read it again immediately before writing your final answer, and choose tasks whose files and features appear nowhere on it (no overlap). Do not even READ (list in depends_on) a file another coder reserved or is changing: such a task is rejected at launch, because that file will change under it. Build on merged code only.
LIVE PLAY NEEDS ITS WIRING FILE: Never write a task whose objective or acceptance criteria need live play (in battle, at a stop, on the run map, in a shop/rest screen) while its Do NOT forbids, or another coder reserves, another file that must call the new code (the app/battle flow). Either choose a task whose wiring files are free and list them in the task's files, or scope the criteria to the service/data layer and its tests and write 'live wiring follows in a later task'.

UNWIRED FEATURES (owner 2026-10-11): these merged scripts are used only by tests, so players cannot reach them (2): scripts/run_m04_event_rotation.gd, scripts/run_v3_hero_event_offers.gd. PREFER a lane task that wires one of them (or a related group) into real play through files no other coder reserves (live board), with a test through the real game path, over building another isolated module. Editing only the unwired script and its own test is NOT wiring: a wiring task changes a file the real game loads (scene, UI, session, run flow or a registry they read). If a new feature cannot be wired from free files, keep it small and name the exact wiring step needed. Never answer NONE just because wiring is blocked by reserved files (cycle 157 idled three lanes that way): give the lane its best small task inside its focus area instead (a data entry, catalog item, rule resource or test that uses only free files).

Parallel-lane work already merged:
- Append three hero-gated snuffbox, speaking-tube and pocket-watch corridor Events
- Append three doorstop, lamp-chimney and ribbon-reel hero wallet stories
- Append three lasting hero-gated household vitality Events
- Append three lasting cookie-cutter, toy-theatre and radiator roadside Events
- Append three weighty birdcage, rocking-horse and attic-porthole Stitched Events
- Append three lasting door-chain, crow-perch and mothglass Stitched hero Events
- Append three consequential metronome, millwheel and bootscraper Stitched Events
- Append Nightthread Finger Trap, Bonecream Footstool and Whispering Pocket Fan vitality Events
- Append three samovar, whistle and threadstorm-barometer roadside Events
- Three hero-gated night-road vitality bargains with lasting stitches
- Add three lasting rainboot, needle-latch and toy-kettle vitality stories
- Append three glass-dropper, dinner-fork and toy-submarine roadside bargains
Parallel-lane attempts that failed (do not repeat unchanged):
- Append four Stitched nightroad roadside salvage stories: DEFERRED decision: Assigned C:\pioneers-lane8 worktree is outside SentinelX win-julespc file_ops read/write allowlist; the repair cannot be legally read, edited
- Append three Stitched gothic roadside prop bargains: DEFERRED decision: The only failing full-lane regression is live_m04_event_wallet_batch_test.gd's obsolete seeded witness hints following the required sorted Ev
- Append three Stitched gothic candlelit object bargains: DEFERRED decision: AC4 requires the three new candlelit IDs to be members of the default RunM04EventRotation pool, but the rotation promotes candlelit records o
- Append three Stitched gothic roadside machine stories: DEFERRED decision: All four authored-data and service acceptance criteria pass, but the supplied full lane-suite result is red in existing tests/live_m04_event_
- Append three doll-scale hero-gated household roadside bargains: DEFERRED decision: Known failing live-route regression requires re-deriving and editing tests/live_frayed_debt_parcel_route_test.gd, which LIVE_WORK marks as ch
- Add three candle-and-fray doll-house roadside bargains: DEFERRED decision: duplicate of commit 5254b9e3 already merged into master, where data/events/stitched_route_effects.json and tests/v3_stitched_pin_cabinet_pape
Each lane task is one bounded gameplay/system change that moves the game toward release and does NOT overlap with
your main plan or with any other lane task (different files and features): e.g. remaining content and rules from the
design docs, non-visual logic and tests for later milestones, or a later MILESTONES.md step that does not depend on
unfinished work. A task that adds a new visible thing also gives it its visuals (see ART below); no restyles unless
the owner focus below allows them. Size: finishable and testable in under an hour.
GAMEPLAY OVER SAFETY (owner 2026-10-09): prefer work a player would notice: unfinished rules and effects,
synergies and interactions, abilities, enemies/bosses/elites, economy and shop rules, and content and
progression from the docs. Defensive-only hardening (input validation, "reject invalid/malformed", atomicity,
finite/overflow guards, refactors with no new behaviour) is allowed for at most ONE lane per round and only when it
fixes a bug a player could actually hit; otherwise plan a gameplay task. Tests cover the new behaviour and stay short.
Copy every number, rule and name the builder needs from the docs into the task.
Size each task for its builder (see the lane list): DeepSeek lanes get SMALL, tightly scoped tasks (1-3 files, about
20-30 minutes); Codex lanes get the BIGGER multi-file features (a whole hero kit, a new
mechanic, or a content set with its rules; up to about 90 minutes). The size limit above applies to DeepSeek.
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
OWNER ORDER (the owner's standing priorities, OWNER_ORDER.md; they outrank the review steps below, so plan the first open item first; a design review never changes them): (0) BIG CHANGE, CARDS ARE REPLACED: turn-based ranked combat (since 11-08 abilities are a fixed kit per hero with found ability patches, see (12); body-part abilities retire). The full design and its build stages are in .review/full_game/STITCHED_DESIGN.md ("Design v4"); read it before planning; it outranks every card rule in GAME_DESIGN.md, MILESTONES.md and the design review steps. Build its stages strictly in order (S1a, S1b, S2, S3, then the owner playtests, S4, S5, S6, S7), one stage at a time, each meeting its done test; the open stage is the main cycle's only build (plan the whole stage, split only S4 per hero). THE CARD GAME IS RETIRED NOW (owner 11-04: "yes remove the old design and focus on the darkest dungeon with twists design"): it no longer has to stay playable. Never fix, test, balance, animate or extend card code or card content; a failing card-only test is deleted, not fixed. When a batch replaces a card system, it deletes that card code and its tests in the same batch (S2/S3: the card battle UI and hand; S6: card rewards, shop, removal, deck); S7 deletes whatever is left with combat_mode. The game must still launch and reach the stitched fight without crashing. Lanes help only inside the open stage or their own area, Stitched work only. Crash fixes from owner playtests always go first. (1) DARK GOTHIC UI (owner 11-04: "the ui, logos, text boxes need to match the background theme aswell. dark and gothic. i like the title background though"): near-black and umber/oxblood fills, tarnished brass/bone trim, worn stitched edges, dark parchment text boxes with pale bone text (readable), candle-amber highlights, through one Theme resource (themes/gothic_theme.tres) at the app root plus 9-slice textures Claude draws (assets/ui/gothic/*.png); never draw visuals in code. Keep the title backdrop; the logo is redrawn dark. One screen group per batch (title+menus, run map+HUD, event/stop panels); the battle screen gets it as part of S2. (2) ENEMIES whose abilities match their looks (blind, multi-hit, summon, split, revive once, steal gold, enrage, charge); fights start with 2-3 foes, a 4th only by summon or split; three bosses, each with an ability matching its look. In S5 they get speed, dodge, PROT, ranks and a droppable part. (3) EVENTS: many look-driven events with hero-specific choices; new events give parts, scraps, fray or candle effects instead of cards once S6 lands. (4) ART AND MOTION: dark gothic ragdoll art (ART_STYLE.md Art v3); never draw visuals in code. Abilities use the named move poses in data/art/move_poses.json and the attack zoom (attacker holds its pose, the stage zooms ~1.3x toward attacker and target, then eases out; reduced-motion skips the zoom). Screens move gently using only authored images. (5) DONE/RETIRED 11-08: the old stitched battle screen fixes; fights now happen in the corridor (items 6, 7, 11). (6) OWNER PLAYTEST 11-07 (folded into 11): the Walk is a FIRST-PERSON 3D candlelit corridor; events are fewer, weightier (each changes something lasting) and happen IN the corridor; fights happen in the corridor too, no separate battle or event screen. Built by the owner's Claude Code session: do not plan walk, battle-HUD or event-panel UI; rules-core, data, balance and art-free logic stay yours. (7) OWNER PLAYTEST 11-07, FIGHTS: "the fight scenes are also too complicated with lots of buttons". MOVED to the owner's Claude Code session on 11-07 14:10 together with (6), because fights now happen inside the 3D corridor: NOT a relay step, do not plan it. The corridor fight overlay will have ONE row of up to 4 large ability icons, click-the-figure targeting, Move/Re-tie/Pass/Retreat behind one More button, a pause menu, and Wren's hand actions as one compact cluster. NOT A STEP (11-06): the owner's Claude Code session builds BAL steps beside the relay and lands them through handoff/claude_land.json at a cycle start. Already built there, do not plan them: S8f (a seeded Walk before every non-boss node, carry into battle, mid-Walk save/replay, Walk screen in New Run) and S9a (Wren's fear plus four hand actions in the rules core); since 11-07 also S9b (kid's side view, hands and strings layer, fear meter, hand action buttons), S9c (New Run intro picture, fear in the walk HUD, walk flicker, Wren's lines) and S9d (Wren's bedroom replaces the quilt village). Since 11-07 that session also does S7's card deletion: cutting the retired card route out of scripts/app.gd and deleting the card-only scripts, scenes and tests it leaves unused. Do not plan card deletions, and do not add new card code or card tests; S7's visual items (battle/title fixes, root theme, HP/fray plates, anchored intents) stay yours. Do not plan S8 or S9 steps; plan the remaining steps around them. Always keep the patchwork theme, 12 floors with one boss per run, and each main cycle under 30 minutes. (8) OWNER 11-07, LOOK SIMPLER, DEEP INSIDE: "i want everything to look simpler as well. wrens room is good. make the fights only slightly more complicated than these pictures, but have complex mechanics on the inside that players dont see." The owner showed two reference fight pictures: party of 4 dolls on the left and 2-3 foes on the right on one painted backdrop, a big name+HP plate under each figure, a turn-order strip of round portraits at the top (one with the candle in the middle), and ONE bottom bar: the acting doll's portrait and name, a HEALTH and a FRAY bar, and 4 big round body-part buttons (ARM, LEG, HEAD, TORSO). Nothing else on screen. So every screen shows few things; Wren's room is the model. Deep rules stay (ranks, speed, dodge, PROT, fray, torn parts, intents, statuses, candle, fear, summons) but they work silently inside the rules and show only as the figures' poses, a few small icons and short lines, never as extra buttons, panels or numbers. Relay: rules-core, AI, balance and data depth is welcome and should grow; never add visible buttons, panels, counters or readouts. The owner's Claude Code session builds the screens. CLARIFIED 11-08 (Claude session, from item 8): this also bans service QUOTES and FORECASTS: do not plan tasks that add quote/forecast fields or 'the real HP/scrap/salvage/recovery consequence' text for the Peddler, Campfire, Unpicker, Sewing Circle, Patch Stall or Events (five such lane tasks 11-07/08 added fields no screen shows). A choice tells its effect in a few plain words, never a number; a lane that cannot wire its change into the live screen it is about does not build it. (9) OWNER 11-07, WREN'S ABILITIES, ROGUELIKE UNLOCKS: "for the wren abilities, we can also make wren have impactful abilities that influence the fights. there can be a lot of different abilities that can be unlocked like a roguelike." Plan step S12 WREN'S GIFTS (rules-core + data + balance; plan it whole): grow Wren's four hand actions (data/kid/hand_actions.json, StitchedKidHandActions IDS) into a POOL of 16-24 Wren abilities in data, each one clearly fight-changing, e.g. snip a foe's string so it loses its next turn, pull a foe forward or back a rank, sew a torn part back mid-fight, blow on the candle to brighten it, flick a button at a foe, swap two dolls, pin a foe so it cannot move, cover a doll's eyes so it ignores fear, a nightlight that wards off the next dark band, tip a foe over (stunned), whisper so one doll acts again. Some cost the round's hand action, the strongest are once per fight; fear 50+ still shakes his hands (seeded). Unlocks like a roguelike: a new run starts with Wren's 4 basics; fights, events and the boss offer a choice of 1 of 3 new gifts (seeded, rarities), kept for that run only, and the run save carries them; between runs, finishing floors or the boss adds new gifts to the pool that later runs can offer (saved in the profile). Wren carries at most 4 gifts into a fight (the 4 slots the fight bar shows); later gifts swap one out. BUILT 11-07 in the owner's Claude Code session (rules, data, offers, save fields, screens, tests; lands through handoff/claude_land.json): do not plan S12. (10) OWNER 11-07, SEWN-ON PATCHES: "is there a better mechanic for the limb abilities since it would change the look of the character when equipping different parts" ... "ok yes. can we build on this feature". BUILT in the owner's Claude Code session as S13 SEWN-ON PATCHES, not a relay step, do not plan it. The doll's body picture never changes; each part shows to the player as a cloth PATCH sewn on its head, arms, torso or legs (data/parts ids and code names stay). Deep inside, no new numbers: (a) stitch tiers show as the patch's border (plain, double stitch, gold thread), never a numeral; (b) every patch has a THREAD colour (its maker's): two of one thread on a doll give a small hidden bonus, all four a "whole cloth" bonus, told only by a thread knot on the name plate; (c) a patch BREAKS IN after several fights on the same doll and sits better (small hidden bonus); (d) foe patches are strong but ILL-FITTING: unless the slot is the doll's favoured one they add a little fray at each fight start; (e) each doll FAVOURS one slot; (f) two copies of one patch can be double-stitched into one a tier higher at the Sewing Circle; (g) a torn patch looks frayed and grey until mended. The old trinkets (data/patches) are called BUTTONS in player text. LANDED on master 11-07 23:13 (rules, data/sewn_patches.json, fight-bar patches, plain slot patches + tier borders + frayed + thread knots in assets/paper/stitched/patches/). Per-part patch pictures (101, <part_id>.png) LANDED 11-08 00:08; a part without its own picture shows the plain slot patch. (11) OWNER 11-08, THE CORRIDOR IS A MAZE, NOTHING ELSE IS A SCREEN: "remove the hands in fights and the 3 attack buttons ... make the events, fights and map movement in the corridor and not separate screen. the player should move to the areas in the 3d environment corridor we said to make, like a maze but no dead ends, with fights and events in left, right and forward. the events should be made in the corridor and look like it belongs there, not just a screen pop up." So the road map page goes away: the run is walked as a 3D corridor maze with no dead ends; each junction opens left, forward and/or right onto the next stops (fights, events, Campfire, Peddler, Sewing Circle, Patch Stall, Unpicker, boss), each seen ahead in the fog. Every event and service happens IN the corridor as a thing standing there (its own Flow picture), never a pop-up panel. Fights lost the puppet hands and the foe intent plates (11-08). Fight mechanics: the owner picked item (12) on 11-08. BUILT in the owner's Claude Code session: do not plan map, route, junction, walk, visit-screen, event-screen or fight-overlay UI, and do not add fields only a map or panel would show. Rules-core, data and art-free logic for the existing map graph (node types, floors, choices) stays yours, but do not change the map graph's shape or the session.choices()/enter() API while this is open. (12) OWNER 11-08, ABILITY PATCHES + LIMB LOSS + HEAVEN/HELL DOORS (TOP after crash fixes; plan step S14, rules-core + data + balance + tests, plan it whole, in this order): "normal abilities but they find patches that can apply different effects to those abilities. like a patch that makes the ability bleed, pull the enemy, stun. they can be based on rarity, the good ones are more rare. they can find them at events or boss battles. also, at 0 hp, characters lose an arm, leg or head every time they get hit, if they lose their head they die ... with 3 times guaranteeing the head, the effect carries over in the walking phases and other fights if they aren't healed. also ... heaven and hell themes". Owner chose: doors are SIDE DOORS after boss-type fights; a dead doll is REPLACEABLE. (a) ABILITIES (owner 11-08: "like darkest dungeon ones, not just strike and guard, something unique to them. it can even be like a heal and if you add bleed patch to it, it bleeds the heroes, so its a negative patch"): each hero has a fixed kit of 4 SIGNATURE abilities in data that match its look and role, each with its own launch ranks, target ranks and side (foe, ally, self), e.g. a heal, a mark, a rank-pierce, a guard-another; no generic strike/guard kits. A patch effect applies to WHOEVER the ability hits: a bleed patch on a heal bleeds the healed dolls, a stun patch on a buff stuns allies, so a wrong patch is a real downside the player must avoid; some patches are made for ally abilities (e.g. regen, cleanse, extra guard). body-part abilities retire (data/parts stays only as the doll's limbs and S13 patch art). Each ability has 1 patch socket (gold patches 2). PATCHES are found items that add an effect to the ability they are sewn on: bleed, pull, push, stun, mark, blind, stuffing steal, chain to the next foe, and more; rarity cotton < wool < silk < gold (gold rarest); commons from events and fights, silk/gold mostly from Elites and the boss; seeded; run save carries them; unsewn/resewn at the Sewing Circle. Rarity shows only as thread, never a number. (b) DEATH'S DOOR: at 0 HP each hit tears off a random remaining arm, leg or head: head chance small on the 1st hit, larger on the 2nd, certain on the 3rd; head lost = the doll is LOST (existing LOST + replacement path). Lost arm: weaker strikes and that arm's patched ability is unusable; lost leg: cannot change rank, acts later; damage stays through the Walk and later fights until mended (Sewing Circle, Campfire); any heal above 0 HP resets the count. (c) DOORS: after an Elite or the boss, a side door may open: a HELL door offers a silk/gold patch or Wren gift for a price (a limb, stuffing/max HP, Wren's fear); a HEAVEN door opens only if this run took no hell deal and gives a blessing (mend all, steady candle, a guarded head). Kid's-world framing only (attic above, under the bed below); no real religious names, no other game's names. The owner's Claude Code session builds the screens, corridor scenes and art for all of (12): never add visible buttons, panels or numbers. LANES: from now on no balancing, tier or stat work on body-part abilities or part stats (they retire in S14); lanes help S14 data (patch effects, hero kits, door deals) or stay in their own area. OWNER 11-09: "the patches are things you can add on to the abilities, not abilities themselves": never call a body part or an ability a patch, and never edit or rename data/parts again. (13) OWNER 11-09 DEEPER COMBAT (S15, built by Claude via queue; keep it, never rebuild): live foes carry RESIST % (stun/bleed/rot/move/debuff, data/stitched/s15_deeper_seams.json); patch rarity pierces (cotton 0, wool 15, silk 30, gold always lands); Wren's hand is never resisted. ROT (mildew) ticks through PROT, halves heals. Ordinary foes +5% HP/floor, +1 dmg per 4 floors; boss 60% HP, 70% blows. Text cues only. Lanes: no retuning of these numbers. (14) OWNER 11-09 CORRIDOR SHOP (built by Claude via queue; keep it, never rebuild): every road stop (events, Peddler, Campfire, Sewing Circle, Patch Stall, Unpicker) is first person in the corridor: its keeper stands ahead and its choices LIE ON THE FLOOR as Flow-drawn wares (assets/paper/walk3d/item_*.png); picking a ware opens round doll portraits along the top; walking on is a floor arrow. Junctions show only floor arrows, never what waits. No WALK ON button: Up/W or a hallway click walks, Down/S turns back. Fight abilities are round. Lanes: no visit/junction/walk UI, no new visible buttons or word lists.
BAL NEXT MAIN STEPS (design review cycle 657, MILESTONES.md BAL "Review 2026-11-09 (cycle 657)"), in order: (1) FINISH NOW the stalled S7 no-card admission plus gothic title VIS-A as ONE build; reconcile owner purge, test public routes and require relay title capture, never split logo/Continue/legacy checks again. (2) Batch S14 x S15 actual patch-target/resist/Rot, rarity, LOST and seeded Continue tests by extending the existing full catalog matrix, not one patch/foe per cycle; do not retune owner numbers. (3) AFTER the owner's 3D handoff, accept S8/S9 maze, embedded Events/Fights, Wren bedroom and floor-12 boss with seeded save/replay and RELAY corridor/night/win/loss captures (VIS-B); owner alone builds screens. S1a-S6 and S12/S13 are built; S8/S9 are not yet visually accepted, so MPW (including P14/P15) waits. Never plan cards, body-part-ability tuning, service forecasts or more small Events. PLANNER RULE: the step marked FINISH NOW has stalled across design reviews. While it is open, the main cycle plans the WHOLE step as one build (as many files as it needs; the cycle size limit does not apply) and meets its done test; never plan a slice it rules out. Side lanes keep their own areas.
TEST SPEED (workflow, 2026-10-18): the full suite is the critical path of every cycle (owner target: a cycle under
30 minutes). Only when MILESTONES.md has a "TS" section with an open step and no lane holds a TS step, give exactly ONE
DeepSeek lane per round the next TS step: make the slowest remaining test file (largest seconds in C:/Users/jcoev/GodotGames/PatchworkPioneers/.review/relay_v2/test_times.json) at
least 1.3x faster (aim for 2x; never DEFER only because 2x was missed) with the SAME assertions and the same real code
paths (boot the app once per file where the cases allow it, drop duplicate loops that re-check what an earlier case
proved). Never delete a check, weaken an assertion or stub the real app. Copy the file name and its current seconds
into the task and require the before/after seconds in the report. Use milestone ID TS. A TS step counts as allowed
work under GAMEPLAY OVER SAFETY, it requests no images, and it touches only that one test file.
If a task adds catalog content (parts, abilities, foes, encounters, events, items) that changes totals asserted by shared audit tests
(for example a content scan or validation test), name those tests and their exact new
totals in the task, and give at most one lane such a task per round.
After your other blocks, output for EACH lane (put the lane id in both markers, e.g. LANE_lane2).
Each LANE block is the coder's WHOLE brief: the coder never sees your plan or any text outside its block. Put every exact
text, ID, number and record IN the block; never write 'see PLAN', 'from the PLAN block', 'as above' or 'the exact ... above':
@@LANE_<lane id>_START@@
TITLE: <short imperative title, or NONE if nothing suitable>
## Goal
## Details (all rules/numbers/names needed, copied from the docs)
## Files likely touched
## Tests to add or update (deterministic, headless)
## Acceptance criteria (each objectively checkable by the tests)
@@LANE_<lane id>_END@@


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
