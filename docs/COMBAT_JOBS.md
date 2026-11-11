# Fight screen rebuild (owner order, 2026-11-11)

The owner does not like the fights yet. They want the fight screen to read like a classic side-view, turn-based
dungeon crawler: heroes in a row on the left, foes in a row on the right, an ability bar under the heroes, and an
information corner on the right. The owner's pictures are in `owner_refs/` (use `view_image`):

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

## Job 5: information corner: map, and foe details on hover (TODO)

The lower right corner of the fight and corridor screens holds a small map of the corridor routes: the rooms and
junctions of this floor, the paths between them, which are visited, and a clear mark where the party is now (see
the map in ref2). Use the run's real route data.

During a fight, hovering a foe swaps the map for that foe's details in the same corner: name, kind, health,
its abilities by name, its resistances, and the effects on it now. That foe also comes to the foreground (bigger,
brighter, the others dimmed, with the spotlight functions `begin_spotlight` / `end_spotlight` already in
`stitched_corridor_stage.gd`) so it is easy to see. Moving the pointer away brings the map back.

## Job 6: figures react to being hit (TODO)

A struck figure reacts, and the reaction depends on the ability used: a light cut jerks it back a little, a heavy
blow knocks it far back and shakes it, bleed or rot makes it shudder, a stun leaves it slumped, a miss shows it
leaning out of the way with a clear MISS, a heal or guard makes an ally straighten or brace. Give every ability a
reaction kind in data and play that kind on the target. Where a figure has `<name>_hit_anim.png` in
`assets/paper/enemies` use it. The owner will have a reaction picture drawn for every reaction kind and figure:
load `assets/paper/<folder>/<figure>_react_<kind>.png` when it exists, fall back to moving the standing picture,
and list every missing file under `## Art needed`.

## Job 7: facing (TODO)

Heroes face right, foes face left, toward each other. Some foes face the wrong way in fights. Check every foe
picture in a fight (the cheats can start any fight) and fix the wrong ones with a flip setting in data or code,
never by editing the picture. List the foes you fixed.

## Job 8: compare with the references (TODO)

Play three fights, hold each screen next to ref1 and ref2, and fix or list every remaining difference in layout,
size of the figures, pacing of an attack, and readability.
