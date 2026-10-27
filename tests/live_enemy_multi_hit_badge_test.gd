extends SceneTree
## Mounted deterministic regression: the already-shipped enemy-intent badge must show the
## same genuine two-hit attack CombatEnemyPhase really resolves for Scissor Crab and Needle
## Wasp. It reads the unchanged on-disk catalog and drives the existing show_intent view;
## no new scheduler, attack resolver, preview or catalog entry is introduced.

const CATALOG_PATH := "res://data/enemies/run_enemies.json"
const POLICIES := ["front", "lowest_living_hp", "exposed", "random"]

var checks := 0
var failures: Array[String] = []
var badge: LiveEnemyIntentBadge = null
var replay_badge: LiveEnemyIntentBadge = null


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _mount_badge() -> LiveEnemyIntentBadge:
	var mounted := LiveEnemyIntentBadge.new()
	root.add_child(mounted)
	mounted.size = Vector2(LiveEnemyIntentBadge.BADGE_WIDTH, LiveEnemyIntentBadge.BADGE_HEIGHT)
	return mounted


func _records() -> Array:
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Array and not parsed.is_empty(),
		"the shipped normal enemy catalog parses as a nonempty record array")
	return parsed if parsed is Array else []


func _record(records: Array, id: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry in records:
		if entry is Dictionary and entry.get("id") == id:
			matches.append(entry)
	_check(matches.size() == 1, "the catalog lists %s exactly once by ID" % id)
	return matches[0] if matches.size() == 1 else {}


func _integral(value: Variant) -> int:
	if value is int:
		return value
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return -1


func _authored_alternative(record: Dictionary, kind: String, amount: int) -> Dictionary:
	var intent: Variant = record.get("intent", {})
	var actions: Variant = intent.get("actions") if intent is Dictionary else null
	var matches: Array[Dictionary] = []
	if actions is Array:
		for action in actions:
			if action is Dictionary and action.get("type") == kind \
					and _integral(action.get("amount")) == amount:
				matches.append(action)
	_check(matches.size() == 1, "%s authors exactly one %s alternative with amount %d" % [
		record.get("id", "?"), kind, amount])
	return matches[0] if matches.size() == 1 else {}


func _announced(record: Dictionary, kind: String, amount: int, target: int) -> Dictionary:
	var alternative := _authored_alternative(record, kind, amount)
	var normalized := CombatEnemyIntents.weighted_action(alternative)
	_check(not normalized.is_empty(),
		"%s %s alternative validates through the live weighted-action contract" % [
			record.get("id", "?"), kind])
	var action: Dictionary = {}
	if normalized.get("action") is Dictionary:
		action = normalized["action"].duplicate(true)
	action["enemy_position"] = 1
	action["target_position"] = target
	return action


func _assert_authored(record: Dictionary, base: int) -> void:
	var attack := _authored_alternative(record, "attack", base)
	var normalized := CombatEnemyIntents.weighted_action(attack)
	var body: Dictionary = normalized.get("action", {}) if normalized.get("action") is Dictionary else {}
	_check(not attack.is_empty() and not normalized.is_empty()
		and body.get("type") == "attack"
		and body.get("amount") is int and int(body["amount"]) == base
		and body.get("hits") is int and int(body["hits"]) == 2
		and normalized.get("weight") is int and int(normalized["weight"]) == 3,
		"%s keeps its unchanged authored attack base %d, hits 2 and weight 3" % [
			record.get("id", "?"), base])


## A displayed two-hit caption must be one of the accepted player-readable forms: the
## literal "2 hits" for a full caption, or the brief's unambiguous A-2 notation when the
## compact form shares the band with a policy ticket.
func _two_hit_caption(text: String) -> bool:
	return text.contains("2 hits") or text.contains("A-2")


## The full hover for a genuine two-hit attack names both independently resolved packets,
## the real hero and the pre-mitigation split. It must never promise twice the amount as
## guaranteed HP loss.
func _assert_two_hit_tooltip(target: LiveEnemyIntentBadge, base: int, hero: int,
		reason: String) -> void:
	var tip := target.tooltip_text
	var first := int((base + 1) / 2.0)
	var second := int(base / 2.0)
	_check(tip.contains("two hits") and tip.contains("independently")
		and tip.contains(LiveEnemyIntentBadge.hero_target_label(hero))
		and tip.contains("%d + %d base damage" % [first, second])
		and tip.contains("Block") and tip.contains("Guard")
		and tip.contains("not guaranteed to deal %d HP of damage" % (base * 2))
		and not tip.contains("%d guaranteed HP loss" % (base * 2))
		and not tip.contains("%d HP loss guaranteed" % (base * 2)),
		reason + ": hover explains two independently resolved base packets and never doubles the total")


func _assert_layout(target: LiveEnemyIntentBadge, min_font: int, reason: String) -> void:
	var bounds := Rect2(Vector2.ZERO, target.size)
	var text := target.caption_text_rect()
	var plaque := target.caption_rect()
	_check(text.has_area() and plaque.has_area()
		and target.caption_text_area().grow(0.5).encloses(text)
		and plaque.grow(0.5).encloses(text)
		and bounds.grow(0.5).encloses(plaque)
		and plaque.position.x > target.patch_rect().end.x
		and target.caption_font_size() >= min_font
		and target.caption_font_size() <= LiveEnemyIntentBadge.CAPTION_MAX_FONT,
		reason + ": caption stays inside its sewn plaque and the 192x28 badge")
	if target.policy_cue.is_empty():
		_check(target.policy_rect() == Rect2() and target.policy_text_rect() == Rect2(),
			reason + ": an unticketed announcement paints no policy ticket")
		return
	var tag := target.policy_rect()
	var tag_text := target.policy_text_rect()
	_check(tag.has_area() and tag_text.has_area() and bounds.grow(0.5).encloses(tag)
		and tag.grow(0.5).encloses(tag_text)
		and not text.intersects(tag) and not plaque.intersects(tag)
		and tag.end.x <= target.caption_area_rect().end.x + 0.01,
		reason + ": the policy keeps its own clear ticket beside the fitted caption")


func _assert_single_hit(target: LiveEnemyIntentBadge, action: Dictionary, base: int,
		hero: int, reason: String) -> void:
	target.show_intent(action, false)
	_check(target.hit_count == 1 and target.hit_damage == -1
		and target.readable_text == "Hit %d: %s" % [base,
			LiveEnemyIntentBadge.rank_caption(hero)]
		and target.tooltip_text == "%d damage aimed at %s." % [base,
			LiveEnemyIntentBadge.hero_target_label(hero)]
		and not _two_hit_caption(target.readable_text)
		and not target.tooltip_text.contains("two hits"),
		reason + ": never forges a second hit")


func _assert_reset(target: LiveEnemyIntentBadge, reason: String) -> void:
	_check(target.hit_count == 1 and target.hit_damage == -1
		and not _two_hit_caption(target.readable_text)
		and not target.tooltip_text.contains("two hits"),
		reason + ": no stale two-hit caption or hover survives")


func _presentation(target: LiveEnemyIntentBadge) -> Array:
	return [target.readable_text, target.tooltip_text, target.icon_mode, target.intent_type,
		target.amount, target.target_position, target.policy_cue, target.enrage_bonus,
		target.hit_count, target.hit_damage, target.caption_font_size(),
		target.caption_text_rect(), target.caption_rect(), target.policy_rect(),
		target.policy_text_rect(), target.icon_art_path()]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	badge = _mount_badge()
	replay_badge = _mount_badge()
	await process_frame
	var records := _records()
	var crab := _record(records, "scissor_crab")
	var wasp := _record(records, "needle_wasp")
	_check(not crab.is_empty() and not wasp.is_empty()
		and crab.get("max_hp") == 26 and wasp.get("max_hp") == 22
		and crab.get("intent", {}).get("target") == "front"
		and wasp.get("intent", {}).get("target") == "lowest_living_hp"
		and wasp.get("bleed_on_attack") is bool and wasp.get("bleed_on_attack") == true,
		"authentic Scissor Crab and Needle Wasp records keep their HP, target policy and sting flag")
	if crab.is_empty() or wasp.is_empty():
		_finish()
		return
	_assert_authored(crab, 6)
	_assert_authored(wasp, 8)
	# The announced action body is the catalog's own normalized alternative with the
	# concrete source and target the bound scheduler publishes, never a preview shape.
	var crab_action := _announced(crab, "attack", 6, 1)
	var wasp_action := _announced(wasp, "attack", 8, 2)
	_check(LiveEnemyIntentBadge.is_two_hit_attack(crab_action)
		and LiveEnemyIntentBadge.is_two_hit_attack(wasp_action)
		and LiveEnemyIntentBadge.two_hit_damages(6) == [3, 3]
		and LiveEnemyIntentBadge.two_hit_damages(8) == [4, 4]
		and LiveEnemyIntentBadge.two_hit_damages(7) == [4, 3],
		"the view recognizes only the canonical two-hit shape and splits odd totals first")

	# AC1: each unchanged on-disk record displays both hits, its base total and its real hero.
	for row in [[crab_action, 6, 1, "Scissor Crab"], [wasp_action, 8, 2, "Needle Wasp"]]:
		var action: Dictionary = row[0]
		var base: int = row[1]
		var hero: int = row[2]
		var reason: String = row[3]
		var original := action.duplicate(true)
		badge.show_intent(action, false)
		_check(action == original, reason + ": showing the copied announcement never mutates it")
		_check(badge.intent_type == "attack" and badge.icon_mode == "attack"
			and badge.amount == base and badge.target_position == hero
			and badge.hit_count == 2 and badge.hit_damage == int(base / 2.0)
			and _two_hit_caption(badge.readable_text)
			and badge.readable_text.contains(str(base)),
			reason + ": displays base %d and both hits instead of one apparent hit" % base)
		_assert_two_hit_tooltip(badge, base, hero, reason)
		_assert_layout(badge, LiveEnemyIntentBadge.CAPTION_MIN_FONT, reason)

	# AC2: every supported policy cue keeps both the two-hit fact and the separate ticket
	# inside the existing 192x28 band, for both authentic target policies.
	for row in [[crab_action, 6, 1, "Scissor Crab"], [wasp_action, 8, 2, "Needle Wasp"]]:
		var action: Dictionary = row[0]
		var base: int = row[1]
		var hero: int = row[2]
		var reason: String = row[3]
		for policy in POLICIES:
			var label: String = LiveEnemyIntentBadge.POLICY_LABELS[policy]
			badge.show_intent(action, false, false, policy)
			_check(badge.hit_count == 2 and badge.hit_damage == int(base / 2.0)
				and badge.policy_cue == label
				and _two_hit_caption(badge.readable_text)
				and badge.readable_text.contains(str(base))
				and badge.caption_font_size() >= LiveEnemyIntentBadge.COMPACT_MIN_FONT,
				reason + " with %s policy keeps the base and both hits readable" % label)
			_check(badge.tooltip_text.contains("Target policy (%s)" % label.to_upper())
				and badge.tooltip_text.contains(LiveEnemyIntentBadge.POLICY_DESCRIPTIONS[policy]),
				reason + " with %s policy keeps the full policy hover" % label)
			_assert_two_hit_tooltip(badge, base, hero, reason + " with " + label)
			_assert_layout(badge, LiveEnemyIntentBadge.COMPACT_MIN_FONT,
				reason + " with " + label)

	# AC3: malformed or irrelevant hits metadata is not presented as a real extra hit.
	var canonical := crab_action.duplicate(true)
	for malformed in [0, 1, 3, -2, true, false, "2", null, [], {}, 2.5]:
		var action := canonical.duplicate(true)
		action["hits"] = malformed
		_assert_single_hit(badge, action, 6, 1, "malformed hits " + str(malformed))
	var extra_key := canonical.duplicate(true)
	extra_key["bonus"] = 1
	_assert_single_hit(badge, extra_key, 6, 1, "invented extra key with hits 2")

	# AC3: one mounted badge reused across every announcement kind never leaks the cue.
	badge.show_intent(crab_action, false)
	_check(badge.hit_count == 2 and _two_hit_caption(badge.readable_text),
		"reused badge starts this sequence on the genuine two-hit caption")
	var ordinary := {"type": "attack", "amount": 5, "target_position": 2, "enemy_position": 1}
	badge.show_intent(ordinary, false)
	_check(badge.hit_count == 1 and badge.hit_damage == -1
		and badge.readable_text == "Hit 5: Middle"
		and badge.tooltip_text == "5 damage aimed at Hero 2 (middle).",
		"an ordinary hits-absent attack restores the exact single-hit wording")
	_assert_reset(badge, "ordinary attack")
	for row in [
		[{"type": "block", "amount": 3, "enemy_position": 1},
			"Block +3", "3 Block on the acting enemy."],
		[{"type": "debuff", "amount": 1, "status": "weak", "target_position": 3,
			"enemy_position": 1}, "Weak 1: Back",
			"Weak 1 to Hero 3 (back) — for 1 turn, -25% outgoing attack damage; damage is rounded down, minimum 0."],
		[{"type": "shove", "amount": 0, "target_position": 2, "direction": 1,
			"enemy_position": 1}, "Shove Middle back", "Push back Hero 2 (middle)."]]:
		var action: Dictionary = row[0]
		badge.show_intent(action, false)
		_check(badge.readable_text == String(row[1]) and badge.tooltip_text == String(row[2]),
			action.type + " restores its exact unchanged caption and hover")
		_assert_reset(badge, action.type)
	badge.show_intent(crab_action, false)
	badge.show_intent(crab_action, false, true, "front")
	_check(badge.readable_text == "UNRAVELLED"
		and badge.tooltip_text == "Unravelled: next action is skipped.", "skip restores Unravelled")
	_assert_reset(badge, "skip")
	badge.show_intent(crab_action, false)
	badge.show_intent(crab_action, true)
	_check(badge.readable_text == "SLAIN" and badge.tooltip_text == "Slain: no action.",
		"slain restores the inert caption")
	_assert_reset(badge, "slain")
	badge.show_intent(crab_action, false)
	badge.show_intent({}, false)
	_check(badge.readable_text == "NO ACTION" and badge.tooltip_text == "No action.",
		"no action restores the inert caption")
	_assert_reset(badge, "no action")

	# AC2: an optional Enrage bonus stays a once-per-total base bonus, split per packet;
	# the single-hit Enrage readout remains exactly as before.
	badge.show_intent(crab_action, false, false, "", 2)
	_check(badge.hit_count == 2 and badge.hit_damage == 5 and badge.enrage_bonus == 4
		and _two_hit_caption(badge.readable_text) and badge.readable_text.contains("+4")
		and badge.tooltip_text.contains("Base 6")
		and badge.tooltip_text.contains("+ 4 Enrage (2/3 stacks)")
		and badge.tooltip_text.contains("= 10 total attack power BEFORE Weak/Exposed adjustment, Guard redirection and hero Block")
		and badge.tooltip_text.contains("split into 5 + 5 base damage")
		and badge.tooltip_text.contains("added to the total once, never +4 per packet")
		and badge.tooltip_text.contains("not guaranteed to deal 20 HP of damage"),
		"two-hit Enrage explains the bonus once in the total and per resolved packet")
	_assert_layout(badge, LiveEnemyIntentBadge.CAPTION_MIN_FONT, "two-hit Enrage")
	badge.show_intent(crab_action, false, false, "lowest_living_hp", 2)
	_check(badge.hit_count == 2 and badge.policy_cue == "Aim low HP"
		and _two_hit_caption(badge.readable_text) and badge.readable_text.contains("+4")
		and badge.caption_font_size() >= LiveEnemyIntentBadge.COMPACT_MIN_FONT,
		"two-hit Enrage beside the longest policy keeps base, bonus and both hits")
	_assert_layout(badge, LiveEnemyIntentBadge.COMPACT_MIN_FONT, "two-hit Enrage with Aim low HP")
	badge.show_intent({"type": "attack", "amount": 3, "target_position": 1,
		"enemy_position": 1}, false, false, "", 2)
	_check(badge.hit_count == 1 and badge.hit_damage == -1 and badge.enrage_bonus == 4
		and badge.readable_text == "Hit 3 +4 Enrage"
		and badge.tooltip_text == "Base 3 aimed at Hero 1 (front) + 4 Enrage (2/3 stacks) = 7 attack power BEFORE Weak/Exposed adjustment, Guard redirection and hero Block; not guaranteed HP loss.",
		"the existing single-hit Enrage readout is unchanged")

	# Existing contact Help and the separate authored Bleed 2 debuff remain intact.
	var sting_help: String = LiveEnemyIntentBadge.CONTACT_HELP["bleed_on_attack"]
	_check(sting_help.contains("actual recipient") and sting_help.contains("Block")
		and sting_help.contains("Fully Blocked hits")
		and sting_help.contains("separate from an announced Bleed debuff"),
		"the passive help still requires actual post-Block HP loss and stays separate")
	badge.show_intent(wasp_action, false, false, "lowest_living_hp", -1,
		{"bleed_on_attack": true})
	_check(badge.hit_count == 2 and _two_hit_caption(badge.readable_text)
		and badge.tooltip_text.contains("two hits")
		and badge.tooltip_text.contains("Passive (not the announced action): " + sting_help)
		and badge.tooltip_text.contains("separate from an announced Bleed debuff"),
		"two-hit Wasp hover keeps the conditional sting as supplementary help")
	badge.show_intent(wasp_action, false, false, "lowest_living_hp")
	_check(not badge.tooltip_text.contains("Passive ("),
		"an unflagged Wasp announcement gains no invented passive help")
	var wasp_bleed := _announced(wasp, "debuff", 2, 3)
	_check(wasp_bleed.get("status") == "bleed" and wasp_bleed.get("hits") == null,
		"the Wasp's separate Bleed 2 debuff remains its own single announcement")
	badge.show_intent(wasp_bleed, false, false, "lowest_living_hp", -1,
		{"bleed_on_attack": true})
	_check(badge.hit_count == 1 and badge.readable_text == "Bleed 2 → 3"
		and badge.tooltip_text.begins_with("Bleed 2 to Hero 3 (back)")
		and badge.tooltip_text.contains("separate from an announced Bleed debuff"),
		"the separate Bleed 2 debuff keeps its own amount, rule and passive separation")
	_assert_reset(badge, "separate Bleed 2")

	# Existing icon and policy fallbacks stay reachable on the genuine two-hit form.
	var saved_root: String = badge.icon_root
	badge.icon_root = "res://assets/paper/ui/absent/"
	badge.show_intent(wasp_action, false, false, "lowest_living_hp")
	_check(badge.icon_mode == "attack" and badge.icon_texture == null
		and badge.icon_texture_rect() == Rect2()
		and _two_hit_caption(badge.readable_text)
		and badge.tooltip_text.contains("two hits"),
		"unavailable attack art keeps the sewn glyph without losing the two-hit cue")
	badge.icon_root = saved_root
	badge.show_intent(wasp_action, false, false, "lowest_living_hp")
	_check(badge.icon_mode == "attack"
		and (badge.icon_texture == null or badge.icon_texture_rect().has_area())
		and _two_hit_caption(badge.readable_text),
		"restoring the art root keeps the committed icon or its drawn fallback")
	badge.show_intent(crab_action, false, false, "boss_secret")
	_check(badge.policy_cue.is_empty() and badge.policy_rect() == Rect2()
		and _two_hit_caption(badge.readable_text),
		"an unknown policy adds no ticket and keeps the genuine two-hit fact")
	badge.show_intent(crab_action, false, false)
	_check(badge.policy_cue.is_empty() and badge.policy_rect() == Rect2()
		and _two_hit_caption(badge.readable_text),
		"an empty policy adds no ticket and keeps the genuine two-hit fact")

	# AC3: presentation is pure and replayable - copied action, authored definition,
	# seeded run RNG and global RNG all stay untouched, and identical input matches.
	var definition_before := crab.duplicate(true)
	var action_before := crab_action.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 334334
	var rng_seed := rng.seed
	var rng_state := rng.state
	seed(20261027)
	var global_expected := randi()
	seed(20261027)
	badge.show_intent(crab_action, false, false, "front")
	var first := _presentation(badge)
	replay_badge.show_intent(crab_action, false, false, "front")
	var second := _presentation(replay_badge)
	_check(first == second,
		"two mounted badges present the identical genuine announcement identically")
	badge.show_intent(crab_action, false, false, "front")
	_check(_presentation(badge) == first, "replaying the same announcement reproduces its output")
	_check(crab_action == action_before and crab == definition_before,
		"show_intent never mutates the copied action or the authored enemy definition")
	_check(rng.seed == rng_seed and rng.state == rng_state,
		"show_intent leaves a seeded run RNG's seed and state untouched")
	_check(randi() == global_expected, "show_intent leaves the global RNG untouched")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_multi_hit_badge_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
