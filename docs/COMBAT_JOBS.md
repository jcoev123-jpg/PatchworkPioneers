# Fight screen rebuild (owner order, 2026-11-11)

The owner does not like the fights yet. They want the fight screen to read like a classic side-view, turn-based
dungeon crawler: heroes in a row on the left, foes in a row on the right, an ability bar under the heroes, and an
information corner on the right. The owner's pictures are shown by `view_image` (pass the file name only, for example `ref2_fight_screen.png`):

- `ref1_attack_moment.png`: an attack. The attacker and the struck foe are big and bright in the foreground, the
  rest is dark and blurred, the damage number sits on the struck foe, the foe recoils.
- `ref2_fight_screen.png`: the layout wanted. Ability bar with a hover card, bars under each figure, map in the
  lower right corner.
- `ref3_patch_slot_bleed.png`: a patch slot showing a bleed patch (in the game:
  `assets/paper/stitched/ui/patch_slot_bleed.png`).
- `ref4_our_bars_now.png`: OUR screen now. Wrong: the name is written on the HP bar.
- `ref5_target_marker.png`: the felt marker that shows who an ability can hit (in the game:
  `assets/paper/stitched/ui/target_marker_red.png` and `target_marker_green.png`).
- `ref6_statuses_on_bar.png`: status icons sit in a row on top of the HP bar.

These pictures show the look and layout wanted. Never copy their names, characters, words or art into the game.

## How to work

Do the FIRST job below that is not marked DONE. Build it, `restart_game`, play a fight and look at it, run the
tests for the files you touched. When it works on screen, change its heading here to `(DONE <date>)` and add one
line on what you built. If you could only do part, write `(PART <date>)` and what is left, so the next player
finishes it. If there is time left, play on and fix bugs as usual. Everything here is ordered by the owner, so the
"no new panels or numbers" rule does not forbid what these jobs ask for; it still forbids anything extra.

All pictures must come from picture files (no shapes drawn by code). Use pictures the game already has
(`assets/paper/ui`, `assets/paper/stitched/...`). If a job needs a picture that does not exist, wire the code to
load the expected file when it exists and fall back to the nearest existing picture, and list the file under
`## Art needed` in your report with one line describing the picture. The pictures are drawn afterwards.

## Job 1: target markers (DONE 2026-11-11)

The existing HP plates now show red foe / green ally marker textures for engine-legal targets, with a tinted existing-art fallback until the dedicated files arrive; cancellation or commitment removes them. Verified in a live normal fight and mounted targeting tests.

When the player clicks an ability, every figure that ability may be used on gets the felt marker around its HP bar:
`target_marker_red.png` on foes for a harmful ability, `target_marker_green.png` on allies for a helping ability
(heal, guard, cleanse and so on). Figures it cannot reach get nothing. Keep the yellow highlight we have: it shows
the one figure the pointer is on, or the one chosen. Markers go away when the ability is used or cancelled.

## Job 2: HP bars (DONE 2026-11-11)

Removed on-bar figure names and put the canonical active-status emblems above each HP strip, with an existing felt/text fallback for missing icons. HP remains numeric even for Hanging dolls; status rows refresh on every combat state change and the full name and effect details remain accessible on figure inspection until job 5 adds the information corner.

No name on or beside the HP bar (see ref4, that is the fault). The bar shows health only. Status effects (bleed,
rot, stun, guard, marks and so on) show as their small icons in a row sitting on top of the bar, as in ref6. The
name is shown in the information corner instead (job 5).

## Job 3: ability hover card (DONE 2026-11-11)

Built: hovering (or keyboard-focusing) a hero ability button shows a felt card above the bar with the real values (kind, damage range, crit, per-foe hit chance, heal, effects with duration, launch/target ranks, sewn patch adds); it hides when the pointer leaves. Verified in a live normal fight.

Hovering a hero's ability button shows a small card beside it, as in ref2, with everything about the ability: its
name, what it does in plain numbers (damage range, chance to hit, heal amount), every effect it applies and for
how long, which places in the row it can be used from and which places it can hit, uses left if it is limited, and
what its sewn-on patch adds. Use the real values the fight uses, not text written by hand. The card goes away when
the pointer leaves.

## Job 4: one patch slot on every hero ability (PART 2026-11-11)

Built one round, faint-when-empty socket on each signature ability and a patch-picture badge with existing-art fallback when occupied; the hover card includes its effects. Verified a live Heel Knot sewn onto Pot Helm Command pushed Moth Scribe from rank 3 to rank 4 in the next fight, plus 38 mounted kit-bar checks. Still to reconcile: the existing gold-patch rule and protected regression coverage permit two effects per ability; the view keeps a single slot but those legacy effects remain in play until the owner resolves that rule conflict.

(2026-11-12 play pass): Completed a live Sewing Circle sew of Mildew Spore onto Warden's Pot Helm Command for 2 scraps after a boss cheat-finish. The next fight showed the sewn-patch label on that ability, and using it applied ROT 2 to Spindle Ram. The gold two-effect rule conflict still prevents marking this job DONE.

(2026-11-12 web play pass): Sewed Heel Knot onto Warden's Pot Helm Command at the live Sewing Circle and inspected normal, elite and boss fight screens. The one-socket visual and ability hover details remain intact. Gold still permits two effects through the legacy loadout and Sewing Circle rules; their protected regressions explicitly expect this. Job stays PART pending an owner-approved rules migration. No gameplay rule changed while the active S15 lane owns the run session.

(2026-11-12 09:07 play pass): Sewed Red Lint onto Warden's Pot Helm Command with 2 scraps, then used it against Thread Biter in the next normal battle. The fight button identified the sewn patch and the held beat showed RED LINT plus BLEED on the target; therefore one-slot display and real patch application are live-confirmed. Job stays PART only because the existing gold two-effect rule conflicts with the one-patch requirement and its protected tests cannot be rewritten here.

(2026-11-12 09:27 play pass): Sewed Heel Knot onto Pot Helm Command at the Sewing Circle, then used it in a normal fight to push the Moth Scribe from rank 3 to rank 4 and apply Mark. The ability showed one occupied badge and the real sewn effect in its hover card. Job remains PART: gold still retains two effects under protected rules and tests, pending an owner-approved migration.

(2026-11-12 11:00 play pass): Added debug-only patch/summon/status/hp/defeat setup helpers and regression checks. Live normal fight: Red Lint appeared as one occupied badge on Warden's Pot Helm Command; the command then applied Mark and Bleed to Crochet Hook Harrier. The summoned fourth Ragling carried the requested Bleed and HP. Job stays PART: the protected two-effect gold rule is unchanged, and the required one-patch migration remains a design decision.

(2026-11-12 15:31 play pass): Rechecked Red Lint on Pot Helm Command in a live floor-1 elite fight: one occupied ability badge was present and using the move applied both its native Mark and the sewn Bleed 2 to Zipper Hauler. The same socket remained visible in the floor-12 boss fight. Debug summon/status/hp, normal/elite/boss transitions, victory and defeat also mounted correctly; focused cheat, combat, continuation and S14 patch tests pass. Job stays PART: the gold two-effect rules/test contract still needs an owner-approved decision.

(2026-11-12 16:28 play pass): In a live floor-6 elite fight, Red Lint again occupied Warden's single visible Pot Helm Command slot; the same sewn ability was present against the floor-12 Colossus. The debugger's fourth-foe summon and HP/Bleed setup stayed consistent. A separate party-picker tooltip fix now names the four fixed signature moves without body-slot labels (2,794 mounted checks). Job remains PART: the gold two-effect contract still needs an owner-approved migration.

(2026-11-12 19:00 web play pass): Debug-sewed Red Lint onto Pot Helm Command, confirmed the one occupied button socket in a live floor-1 normal fight, and used it on Thistle Patch Doll. The held spotlight visibly stacked the native MARK with sewn BLEED and RED LINT over the foe; its settled statuses included BLEED and MARK. Job stays PART because protected gold two-effect rules still conflict with the owner-requested one-patch limit.

(2026-11-12 late web play pass): Inspected the one-slot ability layout in normal, elite and floor-12 boss battles; verified the Red Lint debug sew resolves to Warden's real fixed Pot Helm Command ability. Reproduced boss VICTORY and DEFEAT endings and checked the Wren's Room aftermath. Job remains PART: gold still accepts two effects under protected rules, so enforcing one effect requires the owner's migration decision; no battle rule was changed in this pass.

(2026-11-12 22:27 play pass): Debug-sewed Red Lint onto Pot Helm Command, then used it against Felt Bulwark in a floor-1 normal fight. The one occupied socket remained on the ability; the target received the native MARK 2 and sewn BLEED 2. Also chose Borrow spools at the Threadmill Loft, actually sewed Guard Stitch onto Pot Helm Command, and in the next fight saw GUARD 1 on Warden (the attacker), not on the struck Razor Ribbon Wraith. Floor-6 elite and floor-12 boss fights were inspected. Job remains PART for the pre-existing gold two-effect contract, which needs an owner-approved migration; no combat rules changed.

(2026-11-12 late play pass): Mid-fight debug sewing refreshes the existing battle and single patch badge without replacing the mounted stage, turn or receipt queue. Live Red Lint appeared on Warden's Pot Helm Command and applied BLEED 2 beside its native MARK 2 against Spool Stalker; the focused cheat regression passes. Job remains PART until the owner decides how to migrate legacy gold two-effect sockets.

(2026-11-12 23:12 web play pass): Inspected title, party, Wren intro/room, floor-1 corridor, floor-10 wicker tunnel, Peddler and Patch Stall purchases, Sewing Circle, camp, Unpicker, Needle Gate choice, floor-1 normal four-foe fight, floor-6 elite and floor-12 boss, victory and defeat. Debug-sewed Red Lint onto Pot Helm Command during combat; its one occupied socket remained visible on later floors and the mounted turn advanced after a real command. Committed real abilities in normal, elite and boss fights, with the normal strike photographed during its held spotlight; no visible FRAY words or Wren hand actions appeared. Job stays PART because gold's protected two-effect rule remains unresolved; no battle balance or protected test was changed.

(2026-11-13 play pass): Verified the live Sewing Circle can unsew Red Lint and sew it onto Pot Helm Command for 2 scraps, and that the next normal and floor-12 boss fights both label Warden's command as sewn with Red Lint. Played a full normal-fight hero round (Moth Wink, Needle Prick, Cog Shot, Pot Helm Command) and checked that settled attacker/target positions return to their original ranks after the held foe turns. Inspected floor-6 elite, floor-10 Walk, other visits and the boss screen; the disabled fray meter and Wren's hands did not appear. Job remains PART pending the owner's saved gold two-effect socket migration decision; the protected legacy rule was not changed.

(2026-11-13 00:13 web play pass): Rechecked the single occupied Red Lint socket on Pot Helm Command, its mounted normal-fight Bleed effect, floor-6 elite and floor-12 boss layouts, and three real hero attacks with held beats. The 4th-seat summon and debug bleed/HP setup still work; a 0-HP hero enters HANGING. Title, party picker, Wren intro/room, corridor and thread tug, save/Continue, visits, events, victory and defeat were also exercised. Peddler price/gold visibility remains a separate owner-design question because new visible numbers are forbidden. Job 4 stays PART solely for the existing gold two-effect save migration decision; no protected rule was altered.

Every hero ability button carries exactly one patch slot. With a patch sewn on, the slot shows that patch's own
picture (see `assets/paper/stitched/patches` and `assets/paper/stitched/ability_patches`) inside a round frame,
like ref3: a bleed patch that gives the ability +X bleed shows the bleed design. Empty, the slot shows a faint
empty frame. The hover card (job 3) says what the patch adds. One patch per ability, never two. Check that a patch
sewn on really changes the ability in the next fight; if it does not, that is the bug to fix first.

(2026-11-13 00:30 web play pass): Inspected title, party picker, Wren intro, floor-1 corridor, Peddler, camp, Unpicker, Patch Stall, Needle Gate, a normal battle, floor-6 elite, floor-10 wicker Walk and floor-12 boss. Unsewed Red Lint from Warden's Pot Helm Command at the Sewing Circle, then spent 2 scraps to sew it back onto that exact signature, with the occupied option restored. A real Wick Spark hit the Moth Queen for 4 HP and applied Bleed 1 in the boss fight; the prior Cog Shot advanced without an evident hit, so it was not labelled a bug. The 0-HP Seamstress showed HANGING, no visible FRAY or Wren hand actions appeared, and the boss F1 twice is intentional. Job 4 remains PART: the older gold two-effect rule requires an owner-approved migration and protected-test reconciliation.

## Job 5: information corner: map, and foe details on hover (DONE 2026-11-12)

Built the `StitchedCornerMap` on the walk, fight and visit screens, fed from real run routes, with visited rooms and current candle marker. Foe hover replaces it with live details and spotlights that foe, then restores the map on exit. Corrected the floor index and moved the fight map to the lower-right at `Rect2(968, 542, 306, 170)`; shortened the bottom bar to keep controls and foe HP plates clear.

(11-12 review): RunMap nodes within one floor are **parallel alternatives**; its actual outgoing edges connect to the next floor. Removed misleading same-floor seam arrows and changed unchosen-room tooltips from "ahead" to "alternate route". Added coverage for this and for cancelled hover-return tweens.

(11-12 completion): The corner now shows the next floor and its actual directed outgoing seams, including crossed branches, without inventing same-floor links. The last floor shows no next-floor row. A missing route-thread texture falls back to existing felt art. Verified on live fight, Peddler, and floor-12 boss screens and by mounted route-map tests.

(11-12 play review): Foe hover details now shrink the existing card font only when long move/resistance rows would hide the final live-status line; shorter foes keep the standard font. Verified in the mounted corner-map test and live normal fight. Job 5 remains DONE.

(11-12 19:53 play pass): Dense foe descriptions now grow the existing detail corner upward by up to 88px while keeping its right and lower edges fixed; shorter foes retain the compact size, and the route map regains its original footprint on hover exit. Moth Queen and Scissor Crab details were inspected live after restart; the corner, fight, victory handoff and Continue regressions pass. Job 5 remains DONE.

The lower right cornerof the fight and corridor screens holds a small map of the corridor routes: the rooms and
junctions of this floor, the paths between them, which are visited, and a clear mark where the party is now (see
the map in ref2). Use the run's real route data.

During a fight, hovering a foe swaps the map for that foe's details in the same corner: name, kind, health,
its abilities by name, its resistances, and the effects on it now. That foe also comes to the foreground (bigger,
brighter, the others dimmed, with the spotlight functions `begin_spotlight` / `end_spotlight` already in
`stitched_corridor_stage.gd`) so it is easy to see. Moving the pointer away brings the map back.

## Job 6: figures react to being hit (DONE 2026-11-11)

Built receipt-driven six-kind reactions with per-ability metadata in `data/art/ability_fx.json`, dedicated authored art lookup, old enemy hit-frame fallback, and distinct knockback/tilt/shake motions when new art is absent. A miss visibly says MISS, a heal or guard braces an ally, and final kills retain their held reaction before returning to idle/scrap. Live-tested normal, elite and boss fights through victory with hero and foe attacks, plus title/party, walk, Wren, shops and event screens; added deterministic reaction/hover-state assertionswithout changing the rules or RNG. The existing stage spotlight, zoom, held-attack timing and input shield remain in charge.

A struck figure reacts,and the reaction depends on the ability used: a light cut jerks it back a little, a heavy
blow knocks it far back and shakes it, bleed or rot makes it shudder, a stun leaves it slumped, a miss shows it
leaning out of the way with a clear MISS, a heal or guard makes an ally straighten or brace. Give every ability a
reaction kind in data and play that kind on the target. Where a figure has `<name>_hit_anim.png` in
`assets/paper/enemies` use it. The owner will have a reaction picture drawn for every reaction kind and figure:
load `assets/paper/<folder>/<figure>_react_<kind>.png` when it exists, fall back to moving the standing picture,
and list every missing file under `## Art needed`.

## Art needed (Job 6; 2026-11-11)

109 required reaction images remain missing across 46 registered figures (the sixth kind, brace, is hero-only).File name for each entry below:
`assets/paper/<actor_path>_react_<kind>.png`, where `actor_path` includes
`heroes/`, `enemies/` or `boss/` as listed in `LiveEnemyRoster.ACTOR_ART`.
This groups every required missing filename without a 109-line repeated path list.Existing
129 reaction imports remain untouched; missing art uses a sprite/recoil fallback.

- `brace` — every `heroes/*` actor in `LiveEnemyRoster.ACTOR_ART` (8): helped doll straightens or raises protection.
- `shudder` — every actor (46): stitched body shivers under bleed or rot.
- `stun` — every `enemies/*` and `boss/*` actor in the roster (38): head slumps, limbs go limp.
- `hit` (8) — `heroes/warden`, `enemies/moth_swarm_broodling`, `enemies/button_guard`, `enemies/spool_hexer`, `enemies/zipper_snake`, `enemies/moth_swarm`, `enemies/needle_wasp`, `enemies/spindle_ram`: light jerk backward.
- `heavy` (4) — `enemies/fray_scavenger`, `enemies/spool_hexer`, `enemies/crochet_hook_harrier`, `enemies/spool_leech`: large stagger from a forceful blow.
- `dodge` (5) — `enemies/fray_scavenger`, `enemies/spool_hexer`, `boss/patchwork_behemoth`, `enemies/quilt_termite`, `enemies/felt_bulwark`: lean away, unharmed.

## Job 7: facing (PART 2026-11-11)

Corrected the mirrored stills of Thimble Beetle, Thread Biter, Clothespin Crusher and Crochet Hook Harrier without touching art. Restarted and confirmed the beetle, biter and harrier now point left in live floor-6/8 battles, with facing regression checks passing. More foe types still need visual inspection; some nearly frontal artwork cannot be made side-facing by mirroring.

(PART 2nd pass 2026-11-11): inspected floors 1-10 fights. Face-on foes that mirroring cannot fix: Moth Scribe, Thistle Patch Doll, Razor Ribbon Wraith, Bobbin Bat, Moth Swarm. Code now loads `<still>_side.png` (left-facing, unmirrored) when it exists together with its idle strip (`StitchedCorridorFight.side_art_path` / `has_side_art`); until the art is drawn nothing changes. Left: draw those five side stills.

Heroes face right, foes face left, toward each other. Some foes face the wrong way in fights. Check every foe
picture in a fight (the cheats can start any fight) and fix the wrong ones with a flip setting in data or code,
never by editing the picture. List the foes you fixed.

## Job 8: compare with the references (PART 2026-11-11)

Played floor-1 normal, floor-5 normal, floor-10 elite and boss against ref1/ref2. Widened ranks 1-3 when no fourth foe is present (0.62 to 0.82 metres), retaining compact spacing for an actual fourth seat; verified live `f5a_spaced` and the focused-attack, victory handoff and Continue tests. Still to reconcile: the map is now in the lower-right corner but lacks the reference's real cross-floor paths and junctions; the bottom bar remains shallower, and some outcome lettering and icon art awaits job 9.

Play three fights, hold each screen next to ref1 and ref2, and fix or list every remaining difference in layout,
size of the figures, pacing of an attack, and readability.

(2026-11-12 web play pass): Recentered the side-view camera and widened the three-foe spread, with a modest ordinary-foe scale adjustment; a mounted projection test now checks visible separation between consecutive foe ranks. Extended the existing felt command rail upward without moving its controls, HP plates or route map. Confirmed in a live floor-6 elite fight; corridor focus, victory and Continue regressions pass. Still PART because the reference's deeper command layout and several broad silhouettes require further visual review.

(2026-11-12 16:06 play fix): Confirmed fixed-width health plates drifted right of the projected doll feet across a full four-on-four fight; the final foe's plate was over 200px from its figure. Compact plates now size to the nearest seat spacing, stay beneath their own figures, and preserve readable numbers and status icons. Verified live after restart (`eight_plates_fixed`) with the rear foe plate centered at x=992.5 and regression checks for all eight seats. Job remains PART for the other reference differences.

## Job 9: floating words and icons (PART 2026-11-11)

Built receipt-driven held-beat callouts: numeric hit/crit damage, red UNSTITCHED kill, HANGING, direct and redirected statuses, RESIST, guard, heal, cleanse, sewn-on patch names, and up/down-arrow image slots for buffs/debuffs. They follow the true struck figure above HP bars, stack without overlapping, fade within the existing hold, respect the input shield, and fall back to words when art is missing. Verified real damage + bleed on the elite Needle Briar Guard and 18 deterministic checks; corridor, reaction, Continue, and victory regressions pass. Confirmed nonterminal death-door tears show SEAM TORN! without naming a limb. 11-11 pass: added receipt-confirmed THORNS/RIPOSTE damage and DRAIN healing on the acting figure (never on its target); 25 deterministic callout checks and focus/Continue/victory regressions pass, with a live elite Needle Prick showing damage plus RESIST. 11-11 continued play pass: the battle screen now observes settled turn-start bleed, rot and regen changes and status expiry on untouched units, with floats above the unit affected. Terminal doll LOST! is distinguished from a foe's UNSTITCHED!, and confirmed counter-killed attackers and counter-torn seams receive their own cues. Tests cover truthful tick/expiry attribution, lost/kill and Continue. Still to build: ticks on units also changed by a simultaneous ability (currently withheld rather than misattributed), tick-only pass/skip beats, summon/split notices, and full live visual proof of crit, kill, guard, heal, sewn patch and counter/drain. Protected battle rules and clocks remain unchanged.

(11-12 pass): Tick-only pass/skip receipts now hold confirmed Bleed/Rot/Regen/expiry words over the affected seat under a spotlight, without inventing an ability or changing the rules. Added a mounted tween-and-spotlight regression (37 checks); corridor, victory handoff and Continue tests pass. Live visual confirmation of this rare tick-only path is still pending, as are overlapping ability/tick attribution and summon/split announcements.

(11-12 code review): Corrected tick numbers for overlapping Regen → Bleed → Rot, matching the rules' actual HP settlement order; a truly LOST doll now retains its figure and 0-HP plate for the held blow so its LOST! callout is not silently discarded. Both are covered by mounted deterministic regressions (42 checks). This job remains PART: simultaneous action/tick attribution, summon/split notices, missing icon art and live visual coverage still need work.

(11-12 play pass): Added receipt-confirmed PUSHED BACK, PULLED FORWARD and THREAD CUT! notices to the held target beat. Failed moves and refused cuts remain silent; five new mounted checks pass (47 total). Restarted and saw Warden's Rim Toss push Moth Scribe from rank 3 to rank 4: damage and PUSHED BACK appeared over its moved figure during the spotlight. Remaining: overlapping ability/tick attribution, summon/split announcements, icon art and live proof of pull/cut and the other rare outcomes.

(11-12 overlap pass): When an ability strikes the next unit to tick, reconcile its single result's post-hit HP with actual Regen/Bleed/Rot clock order, exclude any status rewritten by the ability, and float only proven tick/expiry cues on that same figure. Six new deterministic checks pass (53 total); ambiguous multi-hits, redirected effects, counter/actor HP and inconsistent settlements remain withheld rather than guessed. Still PART: summon/split announcements, remaining ambiguous overlaps, icon art and rare live outcomes.

(11-12 code review): Frozen per-turn unit observations now deep-copy nested statuses (the rules' side lists expose mutable unit references), so actual live ticks remain visible. Unchanged seats must also reconcile their simulated HP against the settled HP before floating a tick. Mounted regression covers both, with 57 floating-outcome checks passing. Job remains PART for summon/split, unresolved ambiguous overlaps, missing art and rare live outcomes.

(11-12 reduced-motion pass): Reduced-motion fights now show receipt-confirmed floating words for strikes, status-only pass ticks and final kills, without lunges or delaying input; the spotlight still pulses. Interrupting a held beat clears stale words. Three new mounted checks (60 total), corridor focus, victory handoff and Continue regressions pass. Job remains PART for the other outstanding cases and live reduced-motion visual proof.

(11-12 play pass): A foe killed by an untouched Bleed/Rot turn-start clock now keeps its final numeric tick and UNSTITCHED! over the held figure, even though the rules clear its statuses on death. Regen-before-Bleed, Bleed-before-Rot, and false-death cases have six new deterministic checks (67 total); corridor, victory handoff and Continue regressions pass. Job remains PART for ambiguous multi-hit attribution, summon/split notices, missing art and rare live outcomes.

(11-12 small-fix pass): Summon/split notices are blocked: the stitched rules (`stitched_rules.gd`, not editable by small fixes) emit no summon or split receipt (`grep` of `scripts/stitched` finds only the field-guide sentence; `summon` / `split_on_death` exist only in the legacy `combat_*` scripts), so `_float_events` in `stitched_corridor_fight.gd` has nothing to confirm. DESIGN: the rules must report a fourth foe arriving, with its seat, before a notice can float. Live check: floor 1 normal fight and floor 12 boss fight show no overlap or cut-off text; the boss's two turn-ribbon tags (F1, F1) are its two turns, not a bug. The fatal-tick case was not reproduced live.

(2026-11-12 09:07 play pass): The fatal-tick case is NOW reproduced live (`tinker_after`): Felt Bulwark reached 0 HP from Bleed at turn start while Scissor Crab used Pinch; the correct held seat showed `BLEED -1`, `UNSTITCHED!` and a 0/18 plate, without a phantom hit attribution. A separate `monk_hit_beat` captured `CRIT! 7` and BLEED on the target. `sewn_patch_hit` confirmed RESIST, BLEED and RED LINT stacking on Thread Biter. Job remains PART for missing summon/split receipts, other ambiguous overlaps, remaining icon art and further rare-outcome visual coverage.

(2026-11-12 18:00 play pass): In a floor-12 boss hit, the centered move title collided with a three-outcome stack (MARK, RESIST, RED LINT). Moved the move title just below the turn ribbon and reserved a clear vertical band before floating words, without shifting HP plates or the bottom rail; the mounted four-cue collision check and live boss strike confirm separation. Job remains PART for the other receipt/art limitations above.

(2026-11-12 evening play pass): Added a rules-confirmed fourth-seat arrival receipt for summoned/split foes. The debug summon now preserves the mounted battle instead of discarding its receipt in a screen rebuild; the existing non-ability spotlight holds SUMMONED! or SPLIT! above the new foe. Invalid, blocked and stale arrivals remain silent. Mounted regression checks and the live `summon_float` normal fight show the cue above Ragling without disrupting the next actor; protected combat-rule tests pass. Job remains PART: no naturally authored summon/split ability currently triggers this receipt, ambiguous multi-hit clock attribution and rare-outcome/icon coverage remain.

References:`ref7_float_kill.jpg`,`ref8_float_crit.jpg` (open with `view_image`, file name only).

Whenever something happens to a figure in a fight, a big word and, where one exists, an icon float up over that
figure during the held beat, then fade. Like the references: large, bold, slightly tilted hand-inked lettering in
the game's own font, with the damage or heal number beside or under it, readable against the darkened background.
Cover EVERY outcome and effect the game already has, and only those (read them from the fight rules and the
receipts; do not invent new effects or rules):

- outcomes: a normal hit (number only), `CRIT!` with the number, `MISS` / `DODGE`, a kill (`UNSTITCHED!`, the
  biggest and longest, in red, with the kill picture if one exists), a heal (number in a soft colour), a limb coming
  off at 0 HP, a summon or split arriving;
- every status when it is put on a figure, with its picture from `assets/paper/stitched/icons/status_*.png`:
  `BLEED`, `ROT`, `STUN`, `GUARD`, `MARK`, `BLIND`, `TANGLED`, `HANGING` and any other status in the rules;
- every status tick (the bleed / rot number with its icon), a status that is resisted (`RESIST`), and a status that
  wears off or is cleansed;
- stat changes: a strengthening shows its word with an up-arrow picture, a weakening with a down-arrow picture;
- a sewn-on patch firing: the patch's name with the patch's own picture.

Rules for it: one colour per family (damage warm orange, crit brighter and bigger, kill red, bleed dark red, rot
sickly green, stun yellow, guard / strengthen blue, weaken orange, heal pale green). Several things on one figure
in the same beat stack upward, never on top of each other, and never cover the HP bars or the ability bar. The
words stay up for the whole hold (about 1.2 s) and never delay the turn. Words are text in the game font; icons
are picture files only, no shapes drawn by code. Where an icon or the kill picture is missing, show the word alone
and list the file under `## Art needed` (expected names: `assets/paper/stitched/icons/status_<id>.png`,
`float_up.png`, `float_down.png`, `float_kill.png`, `float_crit.png` in the same folder). Never show a limb word
(HEAD, ARM, TORSO, LEG) and never call an ability a patch. Reduced motion: no drift, just show and fade.
Check on screen with a hit, a crit, a miss, a kill, a bleed tick, a stun, a guard, a heal and a patch firing
(use `burst` during the beat), hero turns and foe turns.
