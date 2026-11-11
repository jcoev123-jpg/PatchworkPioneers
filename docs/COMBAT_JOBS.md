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

Every hero ability button carries exactly one patch slot.With a patch sewn on, the slot shows that patch's own
picture (see `assets/paper/stitched/patches` and `assets/paper/stitched/ability_patches`) inside a round frame,
like ref3: a bleed patch that gives the ability +X bleed shows the bleed design. Empty, the slot shows a faint
empty frame. The hover card (job 3) says what the patch adds. One patch per ability, never two. Check that a patch
sewn on really changes the ability in the next fight; if it does not, that is the bug to fix first.

## Job 5: information corner: map, and foe details on hover (DONE 2026-11-11)

Built the new `StitchedCornerMap` and mounted it on the walk, fight and visit corridor screens, fed from the run's real route records: this floor's rooms in corridor order, visited dimming, a candle here-mark, seam arrows between rooms. During a fight a hovered foe swaps the map for its live details (kind/rank, health, moves, resists, effects now) and takes the foreground via `begin_spotlight` with a small grow, easing back when the pointer leaves; the More tray hides the corner. In the fight view the owner's lower right corner is the foes' stage and the ability bar, so the corner rides the free right edge above the figures; the walk and visit corridors keep the lower right. Also fixed an off-by-one that showed the next floor's rooms (`get_current_floor()` counts chosen doors, so the walked floor sits one index below it). Verified live on floors 1, 6, 10 and 12 (normal/elite/boss), all stops, an event, save/reload and victory.

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

## Job 8: compare with the references (TODO)

Play three fights, hold each screen next to ref1 and ref2, and fix or list every remaining difference in layout,
size of the figures, pacing of an attack, and readability.

## Job 9: floating words and icons (TODO, owner 2026-11-11)

References: `ref7_float_kill.jpg`, `ref8_float_crit.jpg` (open with `view_image`, file name only).

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
