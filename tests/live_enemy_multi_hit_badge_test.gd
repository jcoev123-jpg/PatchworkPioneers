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


## The real mounted view's presentation clock must touch only the authored image alpha.
## Authentic catalog-backed action dictionaries are passed through show_intent throughout.
func _assert_icon_pulse(crab_action: Dictionary, wasp_action: Dictionary) -> void:
	badge.set_reduced_motion_override(false)
	badge.show_intent(crab_action, false, false, "front")
	var initial := _presentation(badge)
	var patch := badge.patch_rect()
	var icon := badge.icon_texture_rect()
	var icon_space := badge.icon_rect()
	var dimensions := badge.size
	var location := badge.position
	var minimum := badge.custom_minimum_size
	var original_art := badge.icon_texture
	var original_tooltip := badge.tooltip_text
	_check(badge.is_inside_tree() and badge.is_visible_in_tree()
		and original_art != null and icon.has_area() and icon_space.encloses(icon)
		and badge.intent_type == "attack" and badge.hit_count == 2
		and badge.is_processing() and badge.icon_pulse_active(),
		"authentic mounted image-backed attack enables icon-only animation")
	_check(badge.get_child_count() == 0
		and badge.mouse_filter == Control.MOUSE_FILTER_PASS
		and badge.focus_mode == Control.FOCUS_NONE,
		"sewn badge remains one input-inert drawing surface with no roster buttons changed")
	_check(is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"fresh announcement begins fully opaque, without a previous phase")
	badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.25)
	var quarter := badge.icon_pulse_alpha()
	badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.25)
	var dimmed := badge.icon_pulse_alpha()
	_check(quarter < 1.0 and quarter > LiveEnemyIntentBadge.ICON_PULSE_MIN_ALPHA
		and is_equal_approx(dimmed, LiveEnemyIntentBadge.ICON_PULSE_MIN_ALPHA),
		"deterministic quarter/half periods soften only the imported icon within 0.78..1 alpha")
	_check(_presentation(badge) == initial and badge.icon_texture == original_art
		and badge.tooltip_text == original_tooltip and badge.patch_rect() == patch
		and badge.icon_rect() == icon_space and badge.icon_texture_rect() == icon
		and badge.size == dimensions and badge.position == location
		and badge.custom_minimum_size == minimum,
		"icon pulse leaves patch, texture destination, caption, policy, outer rect and authority identical")
	_check(root.size == Vector2i(1280, 720),
		"mounted viewport remains 1280x720 with unchanged intent layout")
	badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.5)
	_check(is_equal_approx(badge.icon_pulse_alpha(), 1.0)
		and _presentation(badge) == initial,
		"completed deterministic cycle restores full alpha without changing a combat announcement")

	badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.5)
	badge.show_intent(wasp_action, false, false, "lowest_living_hp")
	_check(badge.is_processing() and badge.icon_pulse_active()
		and is_equal_approx(badge.icon_pulse_alpha(), 1.0)
		and badge.hit_count == 2 and badge.amount == 8 and badge.target_position == 2
		and badge.policy_cue == "Aim low HP" and badge.icon_mode == "attack",
		"new authenticated target, amount and policy reset the icon phase without stale contents")
	badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.5)
	badge.show_intent({"type": "block", "amount": 3, "enemy_position": 1}, false)
	_check(badge.icon_texture != null and badge.icon_texture != original_art
		and badge.icon_art_path() == LiveEnemyIntentBadge.icon_path_for("block")
		and badge.icon_pulse_active() and badge.is_processing()
		and is_equal_approx(badge.icon_pulse_alpha(), 1.0)
		and badge.readable_text == "Block +3" and badge.tooltip_text == "3 Block on the acting enemy.",
		"new block action chooses authored defend icon with fresh phase and original wording")

	badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.5)
	badge.hide()
	_check(not badge.is_visible_in_tree() and not badge.is_processing()
		and not badge.icon_pulse_active() and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"hidden badge stops processing and loses its old opacity phase")
	badge.advance_icon_pulse(0.7)
	badge.show()
	_check(badge.is_visible_in_tree() and badge.is_processing()
		and badge.icon_pulse_active() and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"reopened badge resumes at the full-alpha start rather than stale half-phase")

	badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.5)
	badge.get_parent().remove_child(badge)
	_check(not badge.is_inside_tree() and not badge.is_processing()
		and not badge.icon_pulse_active() and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"detached badge stops its clock and returns to the exact static icon")
	badge.advance_icon_pulse(0.9)
	root.add_child(badge)
	_check(badge.is_inside_tree() and badge.is_visible_in_tree()
		and badge.icon_pulse_active() and badge.is_processing()
		and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"remounting restores a fresh cycle with no texture or phase leak")

	badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.5)
	badge.set_reduced_motion_override(true)
	_check(not badge.is_processing() and not badge.icon_pulse_active()
		and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"reduced motion immediately disables icon pulse and restores the baseline")
	badge.advance_icon_pulse(1.1)
	_check(is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"manual time cannot animate reduced-motion artwork")
	badge.set_reduced_motion_override(false)
	_check(badge.is_processing() and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"lifting override begins a new clean image-backed cycle")
	var old_setting: Variant = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	badge.set_reduced_motion_override(null)
	_check(not badge.icon_pulse_active() and not badge.is_processing()
		and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"shipped accessibility setting also suppresses pulse without test override")
	ProjectSettings.set_setting("accessibility/reduced_motion", old_setting)
	badge.set_reduced_motion_override(false)

	var saved_root := badge.icon_root
	badge.icon_root = "res://assets/paper/ui/no_such_icons/"
	badge.show_intent(crab_action, false)
	_check(badge.icon_mode == "attack" and badge.intent_type == "attack"
		and badge.icon_texture == null and badge.icon_texture_rect() == Rect2()
		and not badge.is_processing() and not badge.icon_pulse_active()
		and is_equal_approx(badge.icon_pulse_alpha(), 1.0)
		and _two_hit_caption(badge.readable_text),
		"missing authored art keeps readable drawn-glyph fallback strictly static")
	badge.icon_root = saved_root
	badge.show_intent(crab_action, false)
	_check(badge.icon_texture == original_art and badge.icon_pulse_active()
		and badge.is_processing() and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"returning from missing artwork selects the current art with zero stale phase")
	for row in [[crab_action, true, false, "SLAIN"], [crab_action, false, true, "UNRAVELLED"],
			[{}, false, false, "NO ACTION"]]:
		badge.advance_icon_pulse(LiveEnemyIntentBadge.ICON_PULSE_PERIOD * 0.5)
		badge.show_intent(row[0], row[1], row[2])
		_check(badge.readable_text == row[3] and badge.intent_type.is_empty()
			and not badge.icon_pulse_active() and not badge.is_processing()
			and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
			"%s retires image pulse with an inert, unchanged caption" % row[3])
	badge.show_intent(crab_action, false)
	_check(badge.icon_texture == original_art and badge.icon_pulse_active()
		and badge.is_processing() and is_equal_approx(badge.icon_pulse_alpha(), 1.0),
		"real next attack after retirement restarts with a fresh icon and no false state")


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

	# An opt-in four-foe fight uses the same shipped normalized Needle Wasp A-2,
	# only the genuine enemy source is slot four; the hero lineup remains three.
	var fourth_wasp := wasp_action.duplicate(true)
	fourth_wasp["enemy_position"] = CombatEnemies.OPT_IN_MAX_ENEMIES
	var fourth_before := fourth_wasp.duplicate(true)
	_check(LiveEnemyIntentBadge.is_two_hit_attack(fourth_wasp),
		"authentic source-four Wasp attack is accepted without changing the hero target guard")
	badge.show_intent(fourth_wasp, false)
	_check(badge.readable_text == "Hit 8 (2 hits): Middle" and badge.hit_count == 2
		and badge.hit_damage == 4 and badge.target_position == 2
		and badge.tooltip_text.contains("8A-2: two hits")
		and badge.tooltip_text.contains("4 + 4 base damage")
		and badge.tooltip_text.contains("Hero 2 (middle)")
		and fourth_wasp == fourth_before,
		"source-four genuine Wasp shows its exact two-packet caption, target and hover")
	badge.show_intent(fourth_wasp, false, false, "lowest_living_hp")
	_check(badge.policy_cue == "Aim low HP" and _two_hit_caption(badge.readable_text)
		and badge.tooltip_text.contains("Target policy (AIM LOW HP)")
		and badge.tooltip_text.contains("4 + 4 base damage"),
		"source-four Wasp keeps the real target policy and split on its compact ticket")
	_assert_layout(badge, LiveEnemyIntentBadge.COMPACT_MIN_FONT, "fourth-slot Wasp")
	replay_badge.show_intent(fourth_wasp, false, false, "lowest_living_hp")
	_check(_presentation(badge) == _presentation(replay_badge),
		"two genuine source-four Wasp presentations replay exactly")
	for malformed_source in [0, 5, -1, "4", 4.0, true, null]:
		var bad_source := fourth_wasp.duplicate(true)
		bad_source["enemy_position"] = malformed_source
		_check(not LiveEnemyIntentBadge.is_two_hit_attack(bad_source),
			"invalid fifth or malformed source never authorizes two hits: " + str(malformed_source))
		_assert_single_hit(badge, bad_source, 8, 2, "invalid source " + str(malformed_source))
	var bad_hero := fourth_wasp.duplicate(true)
	bad_hero["target_position"] = 4
	_check(not LiveEnemyIntentBadge.is_two_hit_attack(bad_hero),
		"fourth enemy is legal but fourth hero is not")
	_assert_single_hit(badge, bad_hero, 8, 4, "invalid fourth hero target")
	for malformed in [0, 1, 3, true, "2", null, 2.0]:
		var bad_hits := fourth_wasp.duplicate(true)
		bad_hits["hits"] = malformed
		_assert_single_hit(badge, bad_hits, 8, 2, "source-four malformed hits " + str(malformed))
	var extra_fourth := fourth_wasp.duplicate(true)
	extra_fourth["extra_packet"] = true
	_assert_single_hit(badge, extra_fourth, 8, 2, "source-four unknown key")
	badge.show_intent(fourth_wasp, false, false, "lowest_living_hp", -1, {}, true)
	_check(badge.blind_miss and badge.hit_count == 2 and badge.hit_damage == 4
		and badge.readable_text == "BLIND · MISS"
		and badge.tooltip_text.contains("Neither of the two authored hit packets resolves"),
		"source-four genuine Blind suppresses both packet effects without erasing packet metadata")
	badge.show_intent(fourth_wasp, false, true)
	_check(badge.readable_text == "UNRAVELLED" and badge.hit_count == 1,
		"source-four Unravelled suppresses the attack")
	badge.show_intent(fourth_wasp, true)
	_check(badge.readable_text == "SLAIN" and badge.hit_count == 1,
		"source-four slain suppresses the attack")
	badge.show_intent(fourth_wasp, false)
	_check(badge.readable_text == "Hit 8 (2 hits): Middle" and fourth_wasp == fourth_before,
		"normal source-four two-hit caption returns after Blind, skip and death")

	# Blind is an opt-in view of the same two authentic catalog attacks. It
	# announces that the entire attempted action misses without resolving either
	# of the authored packets, and restores the exact baseline once consumed.
	for row in [[crab_action, 6, 1, "front", "Scissor Crab"],
			[wasp_action, 8, 2, "lowest_living_hp", "Needle Wasp"]]:
		var action: Dictionary = row[0]
		var base: int = row[1]
		var hero: int = row[2]
		var policy: String = row[3]
		var reason: String = row[4]
		var original: Dictionary = action.duplicate(true)
		badge.show_intent(action, false, false, policy)
		var unblinded: Array = _presentation(badge)
		badge.show_intent(action, false, false, policy, -1, {}, true)
		_check(badge.blind_miss and badge.readable_text == "BLIND · MISS"
			and badge.intent_type == "attack" and badge.icon_mode == "attack"
			and badge.amount == base and badge.target_position == hero
			and badge.hit_count == 2 and badge.hit_damage == int(base / 2.0)
			and badge.policy_cue.is_empty() and badge.policy_rect() == Rect2(),
			reason + ": Blind announces a genuine two-packet attack as a miss without changing action")
		_check(badge.tooltip_text.contains("entire next attempted attack")
			and badge.tooltip_text.contains(LiveEnemyIntentBadge.hero_target_label(hero))
			and badge.tooltip_text.contains("Neither of the two authored hit packets resolves")
			and badge.tooltip_text.contains("Without Blind:") and badge.tooltip_text.contains("two hits")
			and badge.tooltip_text.contains("independently")
			and badge.tooltip_text.contains("%d + %d base damage" % [int(base / 2.0), int(base / 2.0)])
			and badge.tooltip_text.contains("Target policy (")
			and badge.tooltip_text.contains("No hero HP or Block is lost"),
			reason + ": miss hover names authentic target, entire skipped attack, raw packets and policy")
		_assert_layout(badge, LiveEnemyIntentBadge.CAPTION_MIN_FONT, reason + " Blind miss")
		replay_badge.show_intent(action, false, false, policy, -1, {}, true)
		_check(_presentation(badge) == _presentation(replay_badge) and action == original,
			reason + ": Blind rendering is deterministic and leaves the source announcement intact")
		badge.show_intent(action, false, false, policy)
		_check(not badge.blind_miss and _presentation(badge) == unblinded,
			reason + ": consumed Blind restores exact two-hit badge, policy and tooltip")
	# Blind remains pending across defensive or status actions, and skipped/slain
	# states take precedence even when their caller supplies the true status bit.
	var block_action := {"type": "block", "amount": 3, "enemy_position": 1}
	badge.show_intent(block_action, false, false, "", -1, {}, true)
	_check(not badge.blind_miss and badge.readable_text == "Block +3"
		and badge.tooltip_text == "3 Block on the acting enemy.",
		"Blind waits through a Block announcement without manufacturing a miss")
	badge.show_intent(crab_action, false, false, "front", -1, {}, true)
	_check(badge.blind_miss, "same source still previews miss on its next authored attack")
	badge.show_intent(crab_action, false, true, "front", -1, {}, true)
	_check(not badge.blind_miss and badge.readable_text == "UNRAVELLED"
		and badge.tooltip_text == "Unravelled: next action is skipped.",
		"Unravelled skip takes precedence over Blind without false damage")
	badge.show_intent(crab_action, true, false, "front", -1, {}, true)
	_check(not badge.blind_miss and badge.readable_text == "SLAIN"
		and badge.tooltip_text == "Slain: no action.",
		"slain source never announces a Blind miss")
	badge.show_intent({}, false, false, "", -1, {}, true)
	_check(not badge.blind_miss and badge.readable_text == "NO ACTION",
		"missing action never borrows the source's waiting Blind")
	badge.show_intent(wasp_action, false, false, "lowest_living_hp", 2, {}, true)
	_check(badge.blind_miss and badge.enrage_bonus == 4
		and badge.tooltip_text.contains("2 Enrage (2/3 stacks)") == false
		and badge.tooltip_text.contains("+ 4 Enrage (2/3 stacks)")
		and badge.tooltip_text.contains("split into 6 + 6 base damage"),
		"Blind still preserves real once-only Enrage power in the conditional two-packet hover")
	badge.show_intent(wasp_action, false, false, "lowest_living_hp", 2)
	_check(not badge.blind_miss and badge.hit_count == 2 and badge.enrage_bonus == 4
		and _two_hit_caption(badge.readable_text),
		"cleared Blind restores the unchanged Enrage two-hit presentation")

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

	# An authentic, catalog-backed Scissor Crab or Needle Wasp two-packet attack
	# never becomes two damaging hits when a trusted one-shot Blind is waiting.
	for row in [[crab_action, 6, 1, "Scissor Crab", "front"],
			[wasp_action, 8, 2, "Needle Wasp", "lowest_living_hp"]]:
		var attack: Dictionary = row[0]
		var base: int = row[1]
		var hero: int = row[2]
		var name: String = row[3]
		var policy: String = row[4]
		var before_action := attack.duplicate(true)
		badge.show_intent(attack, false, false, policy, -1, {}, true)
		_check(badge.blind_miss and badge.readable_text == "BLIND · MISS"
			and badge.icon_mode == "attack" and badge.intent_type == "attack"
			and badge.amount == base and badge.target_position == hero
			and badge.hit_count == 2 and badge.hit_damage == int(base / 2.0)
			and not badge.tooltip_text.contains("guaranteed HP loss"),
			name + ": trusted Blind replaces damage promise without changing real two-hit data")
		_check(badge.tooltip_text.contains("entire next attempted attack")
			and badge.tooltip_text.contains("Neither of the two authored hit packets resolves")
			and badge.tooltip_text.contains(LiveEnemyIntentBadge.hero_target_label(hero))
			and badge.tooltip_text.contains("Without Blind:")
			and badge.tooltip_text.contains("two hits")
			and badge.tooltip_text.contains("split into %d + %d base damage" % [base / 2, base / 2])
			and badge.tooltip_text.contains("Target policy (%s)" % LiveEnemyIntentBadge.POLICY_LABELS[policy].to_upper())
			and attack == before_action,
			name + ": hover explains complete missed attempt, real packets, target and policy without mutation")
		_assert_layout(badge, LiveEnemyIntentBadge.CAPTION_MIN_FONT, name + " Blind MISS")
		# A display refresh alone never spends Blind; only an executed attack can.
		badge.show_intent(attack, false, false, policy, -1, {}, true)
		_check(badge.blind_miss and badge.readable_text == "BLIND · MISS",
			name + ": repeated read-only rendering retains Blind until combat consumes it")
		badge.show_intent(attack, false, false, policy)
		_check(not badge.blind_miss and _two_hit_caption(badge.readable_text)
			and badge.tooltip_text.contains("two hits") and not badge.tooltip_text.contains("Blind:"),
			name + ": consumed or switched source restores genuine unblinded A-2 announcement")
	# Enrage still belongs to the stored source, never a phantom third packet.
	badge.show_intent(crab_action, false, false, "front", 2, {}, true)
	_check(badge.blind_miss and badge.hit_count == 2 and badge.hit_damage == 5
		and badge.enrage_bonus == 4 and badge.tooltip_text.contains("+ 4 Enrage (2/3 stacks)")
		and badge.tooltip_text.contains("split into 5 + 5 base damage")
		and badge.tooltip_text.contains("Neither of the two authored hit packets resolves"),
		"Blind takes precedence over two-hit Enrage without losing its stored power or packet contract")
	_assert_layout(badge, LiveEnemyIntentBadge.CAPTION_MIN_FONT, "Blind with Enrage")
	# A non-attack announcement leaves the enemy's next-attack miss token waiting,
	# not a false miss for Block, Bleed, or a pushed/snip target.
	for nonattack in [
			{"type": "block", "amount": 4, "enemy_position": 1},
			wasp_bleed,
			{"type": "shove", "amount": 0, "direction": 1,
				"target_position": 2, "enemy_position": 1},
			{"type": "snip_block", "amount": 0, "target_position": 1, "enemy_position": 1},
			{"type": "buff", "amount": 2, "enemy_position": 1}]:
		badge.show_intent(nonattack, false, false, "", -1, {}, true)
		_check(not badge.blind_miss and not badge.readable_text.contains("MISS")
			and not badge.tooltip_text.contains("Blind:")
			and badge.intent_type == nonattack.type,
			"Blind waiting across " + nonattack.type + " does not erase its ordinary action")
		badge.show_intent(wasp_action, false, false, "lowest_living_hp", -1, {}, true)
		_check(badge.blind_miss and badge.hit_count == 2,
			"nonattack leaves the next authentic two-hit attack blinded")
	# Skip and slain have priority even when the source's Blind token still exists.
	badge.show_intent(crab_action, false, true, "front", -1, {}, true)
	_check(not badge.blind_miss and badge.readable_text == "UNRAVELLED"
		and badge.tooltip_text == "Unravelled: next action is skipped.",
		"Unravelled skip overrides Blind on the unchanged sewn badge")
	badge.show_intent(crab_action, true, false, "front", -1, {}, true)
	_check(not badge.blind_miss and badge.readable_text == "SLAIN"
		and badge.tooltip_text == "Slain: no action.",
		"slain enemy never promises a Blind miss")
	badge.show_intent({}, false, false, "", -1, {}, true)
	_check(not badge.blind_miss and badge.readable_text == "NO ACTION",
		"missing announcement never retains stale Blind")
	# The presenter authenticates only the literal integer one-shot status.
	var roster_art := preload("res://scripts/live_enemy_roster.gd")
	for bad in [null, 0, 2, -1, true, false, "1", 1.0, [], {}]:
		_check(not roster_art._has_attack_blind({"hp": 12,
			"statuses": {"blind_next_attack": bad}}),
			"invalid/missing Blind count is never interpreted as a live miss: " + str(bad))
	_check(roster_art._has_attack_blind({"hp": 12,
		"statuses": {"blind_next_attack": 1}})
		and not roster_art._has_attack_blind({"hp": 12, "statuses": []}),
		"source view distinguishes literal 1 from malformed status dictionaries")
	badge.show_intent(crab_action, false, false, "front")
	_check(not badge.blind_miss and _two_hit_caption(badge.readable_text),
		"after Blind source changes, exact normal two-hit caption remains")

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
	# The same mounted ribbon announces the real Imp's newly executable Blind.
	var imp := _record(_records(), "inkbrush_imp")
	_check(not imp.is_empty() and imp.intent.target == "lowest_living_hp",
		"authored Inkbrush Imp is present with lowest-HP living target policy")
	var blind := {"type": "debuff", "amount": 1, "status": "blind_next_attack",
		"target_position": 3, "enemy_position": 1}
	badge.show_intent(blind, false, false, "lowest_living_hp")
	_check(badge.intent_type == "debuff" and badge.action_status == "blind_next_attack"
		and badge.amount == 1 and badge.target_position == 3
		and badge.readable_text.contains("Blind 1")
		and badge.tooltip_text.contains("Hero 3 (back)")
		and badge.tooltip_text.contains("next attempted attack misses once"),
		"mounted Imp Blind 1 names the real recipient and exact one-shot consequence")
	_assert_layout(badge, LiveEnemyIntentBadge.COMPACT_MIN_FONT, "mounted Imp Blind")
	badge.show_intent(crab_action, false, false, "front")
	_check(badge.action_status.is_empty() and _two_hit_caption(badge.readable_text),
		"subsequent reused ribbon restores original two-hit icon and text")
	await _assert_icon_pulse(crab_action, wasp_action)
	_assert_named_two_hit_attacks(crab, wasp, crab_action)
	_finish()


func _assert_named_two_hit_attacks(crab: Dictionary, wasp: Dictionary, unnamed_crab_action: Dictionary) -> void:
	# AC1: derive from normalized Scissor Crab and Needle Wasp actions
	var crab_alt := _authored_alternative(crab, "attack", 6)
	var crab_weighted := CombatEnemyIntents.weighted_action(crab_alt)
	_check(not crab_weighted.is_empty(),
		"Scissor Crab attack normalizes through weighted_action contract")
	var crab_body: Dictionary = crab_weighted.get("action", {}).duplicate(true)
	crab_body["move"] = "attack2"
	crab_body["target_position"] = 1
	_check(CombatEnemyIntents.valid_action(crab_body),
		"underlying named two-hit action body is accepted by CombatEnemyIntents.valid_action")

	var wasp_alt := _authored_alternative(wasp, "attack", 8)
	var wasp_weighted := CombatEnemyIntents.weighted_action(wasp_alt)
	_check(not wasp_weighted.is_empty(),
		"Needle Wasp attack normalizes through weighted_action contract")
	var wasp_body: Dictionary = wasp_weighted.get("action", {}).duplicate(true)
	wasp_body["move"] = "attack3"
	wasp_body["target_position"] = 2
	_check(CombatEnemyIntents.valid_action(wasp_body),
		"underlying named attack3 action body is accepted by CombatEnemyIntents.valid_action")

	# Canonical copied announcement adding only enemy_position
	var named_crab := crab_body.duplicate(true)
	named_crab["enemy_position"] = 1
	var named_wasp := wasp_body.duplicate(true)
	named_wasp["enemy_position"] = 2

	# AC1: predicate returns true for canonical copied announcement with optional enemy_position 1..4
	_check(LiveEnemyIntentBadge.is_two_hit_attack(named_crab),
		"is_two_hit_attack accepts canonical copied named two-hit Crab action")
	_check(LiveEnemyIntentBadge.is_two_hit_attack(crab_body),
		"is_two_hit_attack accepts canonical named two-hit Crab action without enemy_position")
	_check(LiveEnemyIntentBadge.is_two_hit_attack(named_wasp),
		"is_two_hit_attack accepts canonical copied named attack3 Wasp action")
	for pos in range(1, 5):
		var pos_crab := crab_body.duplicate(true)
		pos_crab["enemy_position"] = pos
		_check(LiveEnemyIntentBadge.is_two_hit_attack(pos_crab),
			"is_two_hit_attack accepts legal enemy_position %d with named move" % pos)

	# AC2: compare normal 6->3+3 and odd 7->4+3 cases on already-mounted badge
	var odd_crab_body: Dictionary = crab_body.duplicate(true)
	odd_crab_body["amount"] = 7
	_check(CombatEnemyIntents.valid_action(odd_crab_body),
		"odd 7 named two-hit action body is accepted by CombatEnemyIntents.valid_action")
	var odd_crab := odd_crab_body.duplicate(true)
	odd_crab["enemy_position"] = 1
	_check(LiveEnemyIntentBadge.is_two_hit_attack(odd_crab),
		"is_two_hit_attack accepts odd 7 named two-hit Crab action")

	# Display normal 6->3+3
	var crab_before := named_crab.duplicate(true)
	badge.show_intent(named_crab, false)
	_check(named_crab == crab_before, "show_intent never mutates named action")
	_check(badge.hit_count == 2 and badge.hit_damage == 3 and badge.amount == 6
		and badge.target_position == 1 and badge.intent_type == "attack"
		and badge.icon_mode == "attack"
		and badge.readable_text == "Hit 6 (2 hits): Front"
		and _two_hit_caption(badge.readable_text)
		and badge.tooltip_text.contains("6A-2: two hits")
		and badge.tooltip_text.contains("3 + 3 base damage")
		and badge.tooltip_text.contains("Hero 1 (front)")
		and badge.tooltip_text.contains("not guaranteed to deal 12 HP of damage"),
		"mounted badge truthfully presents normal 6->3+3 named two-hit attack")
	_assert_layout(badge, LiveEnemyIntentBadge.CAPTION_MIN_FONT, "named 6->3+3")

	# Display odd 7->4+3
	var odd_before := odd_crab.duplicate(true)
	badge.show_intent(odd_crab, false)
	_check(odd_crab == odd_before, "show_intent never mutates odd named action")
	_check(badge.hit_count == 2 and badge.hit_damage == 4 and badge.amount == 7
		and badge.target_position == 1 and badge.intent_type == "attack"
		and badge.icon_mode == "attack"
		and badge.readable_text == "Hit 7 (2 hits): Front"
		and _two_hit_caption(badge.readable_text)
		and badge.tooltip_text.contains("7A-2: two hits")
		and badge.tooltip_text.contains("4 + 3 base damage")
		and badge.tooltip_text.contains("Hero 1 (front)")
		and badge.tooltip_text.contains("not guaranteed to deal 14 HP of damage"),
		"mounted badge truthfully presents odd-first 7->4+3 named two-hit attack")
	_assert_layout(badge, LiveEnemyIntentBadge.CAPTION_MIN_FONT, "named 7->4+3")
	_check(LiveEnemyIntentBadge.two_hit_damages(6) == [3, 3]
		and LiveEnemyIntentBadge.two_hit_damages(7) == [4, 3],
		"compare: 6 splits 3+3 evenly while 7 splits 4+3 with odd point first")

	# Display with policy
	badge.show_intent(named_crab, false, false, "front")
	_check(badge.policy_cue == "Front" and badge.hit_count == 2 and badge.hit_damage == 3
		and _two_hit_caption(badge.readable_text)
		and badge.tooltip_text.contains("Target policy (FRONT)")
		and badge.tooltip_text.contains("3 + 3 base damage"),
		"named two-hit attack with Front policy keeps compact ticket and 3+3 packet split")
	_assert_layout(badge, LiveEnemyIntentBadge.COMPACT_MIN_FONT, "named 6 Front")

	# Display with Enrage
	badge.show_intent(named_crab, false, false, "front", 2)
	_check(badge.hit_count == 2 and badge.enrage_bonus == 4 and badge.hit_damage == 5
		and _two_hit_caption(badge.readable_text)
		and badge.tooltip_text.contains("Base 6")
		and badge.tooltip_text.contains("+ 4 Enrage (2/3 stacks)")
		and badge.tooltip_text.contains("split into 5 + 5 base damage"),
		"named two-hit attack with Enrage adds bonus once before splitting into 5+5")
	_assert_layout(badge, LiveEnemyIntentBadge.COMPACT_MIN_FONT, "named 6 Enrage Front")

	# Verified move name retention
	badge.show_intent(named_crab, false)
	_check(badge.move_name == "", "badge.move_name is initially empty")
	badge.append_verified_move_name("Snip Claws")
	_check(badge.move_name == "Snip Claws"
		and badge.tooltip_text.contains("\nMove: Snip Claws")
		and badge.tooltip_text.ends_with("\nMove: Snip Claws"),
		"optional verified move name is retained in badge.move_name and tooltip_text suffix")
	badge.append_verified_move_name("Duplicate Move")
	_check(badge.move_name == "Snip Claws", "duplicate verified move name does not overwrite")
	badge.show_intent(named_crab, false)
	_check(badge.move_name == "" and not badge.tooltip_text.contains("Move: Snip Claws"),
		"fresh show_intent clears verified move name cleanly")

	# Seeded RNG and replayability
	var rng := RandomNumberGenerator.new()
	rng.seed = 556677
	var rng_seed := rng.seed
	var rng_state := rng.state
	seed(887766)
	var global_expected := randi()
	seed(887766)

	badge.show_intent(named_crab, false, false, "front")
	var snap1 := _presentation(badge)
	replay_badge.show_intent(named_crab, false, false, "front")
	var snap2 := _presentation(replay_badge)
	_check(snap1 == snap2, "two mounted badges render named two-hit attack identically")

	badge.show_intent(named_crab, false, false, "front")
	var snap3 := _presentation(badge)
	_check(snap1 == snap3, "replaying named two-hit attack produces identical presentation")
	_check(named_crab == crab_before, "show_intent never mutates passed named action")
	_check(rng.seed == rng_seed and rng.state == rng_state,
		"show_intent leaves seeded RNG seed and state unchanged")
	_check(randi() == global_expected, "show_intent leaves global RNG untouched")

	# Existing unnamed two-hit receipt remains identical
	badge.show_intent(unnamed_crab_action, false)
	_check(badge.hit_count == 2 and badge.hit_damage == 3
		and badge.readable_text == "Hit 6 (2 hits): Front"
		and badge.tooltip_text.contains("6A-2: two hits"),
		"existing unnamed two-hit receipt remains completely identical")

	# AC3: negative tests for named attacks
	# Hits other than integer 2
	for bad_hits in [0, 1, 3, -1, 4, true, false, "2", null, [], {}, 2.0]:
		var bad_hits_action := named_crab.duplicate(true)
		bad_hits_action["hits"] = bad_hits
		_check(not LiveEnemyIntentBadge.is_two_hit_attack(bad_hits_action),
			"is_two_hit_attack rejects named attack with non-2 hits: " + str(bad_hits))
		_assert_single_hit(badge, bad_hits_action, 6, 1, "named attack bad hits " + str(bad_hits))

	# Invalid move IDs
	for bad_move in ["attack1", "attack4", "strike", "", 2, null, true, false, [], {}]:
		var bad_move_action := named_crab.duplicate(true)
		bad_move_action["move"] = bad_move
		_check(not LiveEnemyIntentBadge.is_two_hit_attack(bad_move_action),
			"is_two_hit_attack rejects named attack with invalid move: " + str(bad_move))
		_assert_single_hit(badge, bad_move_action, 6, 1, "named attack invalid move " + str(bad_move))

	# Target not in 1..3
	for bad_target in [0, 4, -1, 5]:
		var bad_target_action := named_crab.duplicate(true)
		bad_target_action["target_position"] = bad_target
		_check(not LiveEnemyIntentBadge.is_two_hit_attack(bad_target_action),
			"is_two_hit_attack rejects target not in 1..3: " + str(bad_target))
		_assert_single_hit(badge, bad_target_action, 6, bad_target, "named attack bad target " + str(bad_target))
	for bad_target in ["1", 1.0, null, true]:
		var bad_target_action := named_crab.duplicate(true)
		bad_target_action["target_position"] = bad_target
		_check(not LiveEnemyIntentBadge.is_two_hit_attack(bad_target_action),
			"is_two_hit_attack rejects non-int target: " + str(bad_target))

	# Source not in 1..4
	for bad_source in [0, 5, -1, "4", 4.0, true, null]:
		var bad_source_action := named_crab.duplicate(true)
		bad_source_action["enemy_position"] = bad_source
		_check(not LiveEnemyIntentBadge.is_two_hit_attack(bad_source_action),
			"invalid source with move never authorizes two hits: " + str(bad_source))
		_assert_single_hit(badge, bad_source_action, 6, 1, "invalid source with move " + str(bad_source))

	# Unknown metadata / extra keys
	for extra in ["bonus", "extra_packet", "shield", "power"]:
		var bad_extra := named_crab.duplicate(true)
		bad_extra[extra] = 1
		_check(not LiveEnemyIntentBadge.is_two_hit_attack(bad_extra),
			"is_two_hit_attack rejects unknown key %s on named attack" % extra)
		_assert_single_hit(badge, bad_extra, 6, 1, "unknown key %s on named attack" % extra)

	# Blind state
	badge.show_intent(named_crab, false, false, "front", -1, {}, true)
	_check(badge.blind_miss and badge.hit_count == 2 and badge.hit_damage == 3
		and badge.readable_text == "BLIND · MISS"
		and badge.tooltip_text.contains("Neither of the two authored hit packets resolves")
		and badge.tooltip_text.contains("entire next attempted attack")
		and not badge.tooltip_text.contains("guaranteed HP loss"),
		"named two-hit attack with Blind shows BLIND · MISS and preserves 2 packets without damage")
	_assert_layout(badge, LiveEnemyIntentBadge.CAPTION_MIN_FONT, "named Blind miss")

	# Unravelled state
	badge.show_intent(named_crab, false, true, "front")
	_check(badge.readable_text == "UNRAVELLED" and badge.hit_count == 1
		and badge.tooltip_text == "Unravelled: next action is skipped.",
		"named two-hit attack with Unravelled skip shows UNRAVELLED")
	_assert_reset(badge, "named Unravelled")

	# Slain state
	badge.show_intent(named_crab, true, false, "front")
	_check(badge.readable_text == "SLAIN" and badge.hit_count == 1
		and badge.tooltip_text == "Slain: no action.",
		"named two-hit attack on slain enemy shows SLAIN")
	_assert_reset(badge, "named slain")

	# Restoration after non-acting visual
	badge.show_intent(named_crab, false)
	_check(badge.readable_text == "Hit 6 (2 hits): Front" and badge.hit_count == 2
		and badge.hit_damage == 3,
		"normal named two-hit display returns after Blind, skip and death")


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_multi_hit_badge_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
