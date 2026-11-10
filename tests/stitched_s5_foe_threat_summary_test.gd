extends SceneTree
## Deterministic S5 check that a look-driven Stitched foe intent is explained in words:
## the pure StitchedFoeThreatSummary table, and the already-mounted 140x58 intent ticket
## that discloses it. No battle simulation, RNG roll or new visual object is used.

const ATTACK_TEXTURE_PATH := "res://assets/paper/ui/intent_attack.png"
const DEFEND_TEXTURE_PATH := "res://assets/paper/ui/intent_defend.png"
const BUFF_TEXTURE_PATH := "res://assets/paper/ui/intent_buff.png"
const DEBUFF_TEXTURE_PATH := "res://assets/paper/ui/intent_debuff.png"

# Authored catalog shapes (real names/numbers), used as detached projections.
const BEHEMOTH_MAUL := {
	"foe_id": "patchwork_behemoth", "foe_name": "Patchwork Behemoth",
	"ability_id": "behemoth_maul", "ability_name": "Behemoth Maul", "ability_kind": "melee",
	"target_side": "hero", "target_rank": 1, "affected_ranks": [1], "multi": false,
	"base_damage": [8, 12], "base_acc": 85, "base_crit": 0,
	"base_effects": {"tear": 1}, "pass": false, "stun": false,
}
const NEEDLE_BARRAGE := {
	"foe_id": "sewing_machine_colossus", "foe_name": "Sewing-Machine Colossus",
	"ability_id": "colossus_barrage", "ability_name": "Needle Barrage", "ability_kind": "ranged",
	"target_side": "hero", "target_rank": 1, "affected_ranks": [1, 2, 3], "multi": true,
	"base_damage": [2, 3], "base_acc": 80, "base_crit": 0,
	"base_effects": {"bleed": 1}, "pass": false, "stun": false,
}
const QUEEN_DUST := {
	"foe_id": "moth_queen", "foe_name": "Moth Queen",
	"ability_id": "queen_dust", "ability_name": "Queen Dust", "ability_kind": "ranged",
	"target_side": "hero", "target_rank": 1, "affected_ranks": [1, 2, 3, 4], "multi": true,
	"base_damage": [3, 5], "base_acc": 85, "base_crit": 0,
	"base_effects": {"weak": 1, "blind": 1}, "pass": false, "stun": false,
}
const IRON_TREAD := {
	"foe_id": "sewing_machine_colossus", "foe_name": "Sewing-Machine Colossus",
	"ability_id": "colossus_guard", "ability_name": "Iron Tread", "ability_kind": "buff",
	"target_side": "foe", "target_rank": 1, "affected_ranks": [1], "multi": false,
	"base_damage": [0, 0], "base_acc": 100, "base_crit": 0,
	"base_effects": {"thorns": 4}, "pass": false, "stun": false,
}
const PIN_CROWN_DIVE := {
	"foe_id": "moth_queen", "foe_name": "Moth Queen",
	"ability_id": "queen_dive", "ability_name": "Pin Crown Dive", "ability_kind": "melee",
	"target_side": "hero", "target_rank": 1, "affected_ranks": [1], "multi": false,
	"base_damage": [6, 8], "base_acc": 85, "base_crit": 0,
	"base_effects": {"tangled": 2, "snip": 1}, "pass": false, "stun": false,
}
const THREAD_TAG := {
	"foe_id": "spool_hexer", "foe_name": "Spool Hexer",
	"ability_id": "thread_tag", "ability_name": "Thread Tag", "ability_kind": "debuff",
	"target_side": "hero", "target_rank": 1, "affected_ranks": [1], "multi": false,
	"base_damage": [0, 0], "base_acc": 90, "base_crit": 0,
	"base_effects": {"mark": 3}, "pass": false, "stun": false,
}
const STATUS_COMPOSITE := {
	"foe_id": "fixture_needle_crone", "foe_name": "Needle Crone",
	"ability_id": "fixture_crone_hex", "ability_name": "Crone Hex", "ability_kind": "debuff",
	"target_side": "hero", "target_rank": 2, "affected_ranks": [2, 3], "multi": true,
	"base_damage": [0, 0], "base_acc": 90, "base_crit": 0,
	"base_effects": {"snip": 1, "fray": 4, "mark": 1}, "pass": false, "stun": false,
}
const GUARD_BLESSING := {
	"foe_id": "fixture_guard_doll", "foe_name": "Guard Doll",
	"ability_id": "fixture_guard", "ability_name": "Shield Stitch", "ability_kind": "guard",
	"target_side": "foe", "target_rank": 2, "affected_ranks": [2], "multi": false,
	"base_damage": [0, 0], "base_acc": 100, "base_crit": 0,
	"base_effects": {"guard": 2}, "pass": false, "stun": false,
}

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	# This test pins the summary's complete wording, including the Fray note
	# that only the retired fray meter (StitchedRules.fray_enabled) ever shows.
	StitchedRules.fray_enabled = true
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _kind_texture(kind: String) -> Texture2D:
	match kind:
		"melee", "ranged":
			return load(ATTACK_TEXTURE_PATH) as Texture2D
		"guard":
			return load(DEFEND_TEXTURE_PATH) as Texture2D
		"buff", "heal":
			return load(BUFF_TEXTURE_PATH) as Texture2D
		"debuff":
			return load(DEBUFF_TEXTURE_PATH) as Texture2D
	return null


func _caption_fits(label: Label) -> bool:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return false
	var pixels := label.get_theme_font_size("font_size")
	return "\n" not in label.text and label.clip_text and (
		font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x + 0.5
		and font.get_height(pixels) <= label.size.y + 0.5)


## Asserts a summary is readable, deterministic, non-mutating, and says exactly the
## wanted facts and none of the forbidden ones. Returns the summary text.
func _verify_summary(intent: Dictionary, wanted: Array, unwanted: Array, note: String) -> String:
	var copy := intent.duplicate(true)
	var text := StitchedFoeThreatSummary.summary(intent)
	_check(not text.is_empty(), "%s: summary is readable text" % note)
	_check(text == StitchedFoeThreatSummary.summary(intent),
		"%s: repeated summary text is identical (no clock, roll or hidden state)" % note)
	_check(intent == copy, "%s: summary never mutates the supplied projection" % note)
	for token in wanted:
		_check(text.contains(str(token)), "%s: says '%s'" % [note, str(token)])
	var lower := text.to_lower()
	for token in unwanted:
		_check(not lower.contains(str(token).to_lower()),
			"%s: never says '%s'" % [note, str(token)])
	return text


func _test_summary_table() -> void:
	# Single-target damaging strike with a look-driven Tear.
	_verify_summary(BEHEMOTH_MAUL, [
		"THREAT HERO RANK 1", "85% ACC", "IF LANDED 8–12 DMG", "IF HIT:",
		"Tear", "seeded random non-torso part",
	], ["RANKS", "guaranteed", "always", "0–0"], "Behemoth Maul")
	# Multi-rank ranged barrage.
	_verify_summary(NEEDLE_BARRAGE, [
		"THREAT HERO RANKS 1,2,3", "80% ACC each", "IF LANDED 2–3 DMG each",
		"IF HIT:", "Bleed 1", "1 HP at turn start, ignores PROT",
	], ["guaranteed", "always", "Queen Dust"], "Needle Barrage")
	# Multi-rank control: Weak and Blind, with their established consequences.
	_verify_summary(QUEEN_DUST, [
		"THREAT HERO RANKS 1,2,3,4", "85% ACC each", "IF LANDED 3–5 DMG each",
		"Weak 1", "attack damage -25%", "Blind 1", "next attack misses",
	], ["Bleed", "Thorns", "Snip", "Mark", "guaranteed", "always"], "Queen Dust")
	# Zero-direct-damage self buff: no hit roll, no invented strike.
	_verify_summary(IRON_TREAD, [
		"THREAT FOE RANK 1", "SELF/ALLY ACTION (no hit roll)", "NO DIRECT DMG",
		"Thorns 4", "4 damage back to each attacker",
	], ["IF HIT", "ACC", "0–0", "guaranteed", "always", "strike"], "Iron Tread")
	# Look-driven Snip plus Tangled on one doll.
	_verify_summary(PIN_CROWN_DIVE, [
		"THREAT HERO RANK 1", "IF LANDED 6–8 DMG", "IF HIT:", "Snip",
		"RE-TIE (a turn) before move, heal or guard can cross", "Tangled 2",
		"cannot move; incoming damage +2",
	], ["guaranteed", "always", "strike"], "Pin Crown Dive")
	# A zero-damage mark debuff is conditional and never a damaging strike.
	_verify_summary(THREAD_TAG, [
		"THREAT HERO RANK 1", "NO DIRECT DMG", "IF HIT:", "Mark 3",
		"bonus damage only to mark-hunting attacks",
	], ["0–0", "guaranteed", "always", "strike", "Bleed", "Thorns"],
		"Thread Tag")
	# Status-only composite across two ranks: ranks, magnitudes, side and conditioning.
	_verify_summary(STATUS_COMPOSITE, [
		"THREAT HERO RANKS 2,3", "NO DIRECT DMG", "IF HIT:", "Snip", "RE-TIE",
		"Fray +4", "rises toward 200", "Mark 1", "mark-hunting",
	], ["0–0", "guaranteed", "always", "strike", "Bleed", "Thorns"],
		"status-only composite")
	# An allied guard names the protected rank and takes no enemy hit roll.
	_verify_summary(GUARD_BLESSING, [
		"THREAT FOE RANK 2", "SELF/ALLY ACTION (no hit roll)", "NO DIRECT DMG",
		"Guard 2", "intercepts hits aimed at the guarded ally",
	], ["IF HIT", "ACC", "guaranteed", "always", "strike"], "Guard blessing")
	# Dodge needs both the authored value and its duration.
	var no_duration := {"target_side": "foe", "affected_ranks": [1], "multi": false,
		"base_damage": [0, 0], "base_acc": 100, "base_effects": {"dodge": 8}}
	_verify_summary(no_duration, ["THREAT FOE RANK 1", "NO DIRECT DMG"],
		["Dodge", "if hit", "guaranteed"], "dodge without duration")
	var with_duration := {"target_side": "foe", "affected_ranks": [1, 2], "multi": true,
		"base_damage": [0, 0], "base_acc": 100,
		"base_effects": {"dodge": 8, "duration": 1}}
	_verify_summary(with_duration, ["THREAT FOE RANKS 1,2", "Dodge +8 for 1 turn"],
		["if hit", "guaranteed"], "dodge with duration")
	# Push, Pull and Heal stay one-rank/restore-only statements.
	var movement := {"target_side": "hero", "affected_ranks": [3], "multi": false,
		"base_damage": [0, 0], "base_acc": 88, "base_effects": {"pull": 1}}
	_verify_summary(movement, ["THREAT HERO RANK 3", "Pull: one rank forward when legal and uncut"],
		["guaranteed", "two ranks"], "pull")
	var healing := {"target_side": "foe", "affected_ranks": [3], "multi": false,
		"base_damage": [0, 0], "base_acc": 100, "base_effects": {"heal": 5}}
	_verify_summary(healing, ["Heal 5", "restores 5 HP where authored"],
		["if hit", "guaranteed"], "ally heal")
	# Fray rises by the authored amount, bounded by the 0-200 meter.
	for entry in [{"fray": 4}, {"fray": 12}, {"stun_resist": 1}]:
		var intent := {"target_side": "hero", "affected_ranks": [1], "multi": false,
			"base_damage": [0, 0], "base_acc": 90, "base_effects": entry}
		var text := StitchedFoeThreatSummary.summary(intent)
		if entry.has("fray"):
			_check(text.contains("Fray +%d: rises toward 200" % int(entry["fray"])),
				"fray %d is bounded by the 0-200 meter" % int(entry["fray"]))
		else:
			# An unlisted effect name is never turned into an invented status.
			_check(not text.contains("Stun") and not text.contains("Resist")
				and text.contains("NO AUTHORED") == false,
				"an unlisted effect key invents no status text")


func _test_fail_closed() -> void:
	var good := BEHEMOTH_MAUL.duplicate(true)
	_check(StitchedFoeThreatSummary.summary({}) == "", "empty intent has no threat text")
	var cases := [
		{"affected_ranks": []},
		{"affected_ranks": [0, 2, 5]},
		{"affected_ranks": [2, 5]},
		{"affected_ranks": ["2"]},
		{"affected_ranks": [2.0]},
		{"affected_ranks": 2},
		{"target_side": ""},
		{"target_side": "heap"},
		{"target_side": "ally"},
	]
	for tweak in cases:
		var broken: Dictionary = good.duplicate(true)
		broken.merge(tweak, true)
		_check(StitchedFoeThreatSummary.summary(broken) == "",
			"malformed or missing %s never fabricates a threat" % str(tweak))
	for state in ["pass", "stun"]:
		var skipped := good.duplicate(true)
		skipped["pass"] = state == "pass"
		skipped["stun"] = state == "stun"
		_check(StitchedFoeThreatSummary.summary(skipped) == "",
			"%s supplies no threat text even with leftover base data" % state.to_upper())
	# Unknown keys add no wording at all; the exact authored values stay in the base line.
	var unknown := BEHEMOTH_MAUL.duplicate(true)
	unknown["base_effects"] = {"moon_lace": 2}
	var missing := BEHEMOTH_MAUL.duplicate(true)
	missing.erase("base_effects")
	_check(StitchedFoeThreatSummary.summary(unknown) == StitchedFoeThreatSummary.summary(missing),
		"an unknown effect key adds no invented status text")
	_check(not StitchedFoeThreatSummary.summary(unknown).contains("moon_lace"),
		"an unknown effect key is not echoed as if it were a status")
	# The helper never draws RNG and has no battle, scene or clock dependency.
	var quiet := QUEEN_DUST.duplicate(true)
	seed(6132026)
	var expected_global := randi()
	seed(6132026)
	StitchedFoeThreatSummary.summary(quiet)
	StitchedFoeThreatSummary.summary(unknown)
	StitchedFoeThreatSummary.summary({})
	_check(randi() == expected_global, "summary consumes no global RNG")
	_check(quiet == QUEEN_DUST, "summary leaves the supplied multi-rank projection untouched")
	_check(StitchedFoeThreatSummary.new() is RefCounted,
		"summary is a pure RefCounted helper, not a scene node")


func _verify_mounted(ticket: StitchedFoeIntentPlate, intent: Dictionary, rank: int, note: String) -> void:
	var copy := intent.duplicate(true)
	var threat := StitchedFoeThreatSummary.summary(intent)
	ticket.present_intent(intent, rank)
	var damage: Array = intent["base_damage"]
	var effects: Dictionary = intent["base_effects"]
	var keys := effects.keys()
	keys.sort()
	var effect_labels: Array[String] = []
	for key in keys:
		effect_labels.append("%s %+d" % [str(key), int(effects[key])])
	var base_line := "BASE DMG %d–%d · BASE ACC %d%% · BASE CRIT %+d · BASE EFFECTS %s" % [
		int(damage[0]), int(damage[1]), int(intent["base_acc"]), int(intent["base_crit"]),
		", ".join(effect_labels)]
	var side_label := "HERO" if str(intent["target_side"]) == "hero" else "FOE"
	var rank_words: Array[String] = []
	for affected in intent["affected_ranks"]:
		rank_words.append(str(affected))
	_check(ticket.visible and ticket.foe_id == str(intent["foe_id"]),
		"%s: mounted ticket shows the real foe" % note)
	_check(ticket.tooltip_text.contains(base_line),
		"%s: keeps every exact BASE DMG/ACC/CRIT/EFFECTS value" % note)
	_check(not threat.is_empty() and ticket.tooltip_text.contains(threat),
		"%s: disclosure carries the pure threat wording" % note)
	_check(ticket.tooltip_text.count("THREAT ") == 1,
		"%s: exactly one threat sentence is disclosed" % note)
	_check(ticket.tooltip_text.contains("Current intent; may change if ranks or statuses change"),
		"%s: keeps the provisional-intent disclosure" % note)
	_check(not ticket.primary.text.is_empty() and _caption_fits(ticket.primary)
		and (ticket.primary.text == str(intent["ability_name"]).to_upper()
			or (ticket.primary.text.ends_with("…")
				and ticket.tooltip_text.contains(str(intent["ability_name"])))),
		"%s: title still names the authored ability (complete in disclosure)" % note)
	_check(ticket.secondary.text.begins_with(side_label + " RANK")
		and not ticket.secondary.text.contains("…")
		and not ticket.secondary.text.contains("BASE"),
		"%s: keeps the complete ordinary rank caption" % note)
	for word in rank_words:
		_check(ticket.secondary.text.contains(word), "%s: caption keeps rank %s" % [note, word])
	_check(ticket.size == Vector2(140, 58) and ticket.texture == StitchedFoeIntentPlate.PLATE_TEXTURE
		and ticket.self_modulate == Color("62464a") and ticket.patch_margin_left == 22
		and ticket.patch_margin_right == 22 and ticket.patch_margin_top == 11
		and ticket.patch_margin_bottom == 11,
		"%s: keeps the authored 140x58 NinePatch plate and margins" % note)
	_check(ticket.glyph != null and ticket.glyph.visible
		and ticket.glyph.texture == _kind_texture(str(intent["ability_kind"])),
		"%s: keeps the authored look-driven glyph" % note)
	_check(ticket.primary.size.x == 100 and ticket.primary.size.y >= 29
		and ticket.secondary.size.x == 132 and ticket.secondary.size.y >= 24,
		"%s: keeps its authored label sizes (%s / %s)" % [note, ticket.primary.size, ticket.secondary.size])
	_check(ticket.primary.position.x == 36 and _caption_fits(ticket.primary),
		"%s: keeps the glyph-aware title row pixel-fit" % note)
	_check(_caption_fits(ticket.secondary),
		"%s: keeps the complete rank caption pixel-fit" % note)
	_check(ticket.get_tooltip(Vector2(8, 8)).is_empty(),
		"%s: suppresses Godot's generic hover popup" % note)
	_check(intent == copy, "%s: presenting never mutates the projection" % note)


func _test_mounted_ticket() -> void:
	var host := Control.new()
	host.name = "ThreatTicketHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var ticket := StitchedFoeIntentPlate.new()
	ticket.position = Vector2(450, 245)
	host.add_child(ticket)
	await process_frame
	_check(ticket.glyph != null and ticket.primary != null and ticket.secondary != null,
		"precondition: mounted ticket built its glyph and two label rows")
	if ticket.glyph == null or ticket.primary == null or ticket.secondary == null:
		host.free()
		return
	var fixtures := [
		[BEHEMOTH_MAUL, 1, "mounted Behemoth Maul Tear"],
		[PIN_CROWN_DIVE, 1, "mounted Pin Crown Dive Snip"],
		[NEEDLE_BARRAGE, 1, "mounted Needle Barrage"],
		[QUEEN_DUST, 1, "mounted Queen Dust"],
		[THREAD_TAG, 1, "mounted Thread Tag Mark"],
		[IRON_TREAD, 1, "mounted Iron Tread Thorns"],
		[GUARD_BLESSING, 2, "mounted Guard blessing"],
		[STATUS_COMPOSITE, 2, "mounted Snip/Fray/Mark composite"],
	]
	for fixture in fixtures:
		_verify_mounted(ticket, fixture[0], int(fixture[1]), str(fixture[2]))
	# A newer projection fully replaces the previous threat wording.
	var fresh := NEEDLE_BARRAGE.duplicate(true)
	ticket.present_intent(fresh, 1)
	_check(ticket.tooltip_text.contains("Needle Barrage") and ticket.tooltip_text.contains("Bleed 1")
		and not ticket.tooltip_text.contains("Tear") and not ticket.tooltip_text.contains("Behemoth"),
		"a multi-rank barrage replaces the earlier single-target threat")
	ticket.present_intent(BEHEMOTH_MAUL, 1)
	_check(ticket.tooltip_text.contains("Behemoth Maul") and ticket.tooltip_text.contains("Tear")
		and not ticket.tooltip_text.contains("Bleed 1")
		and not ticket.tooltip_text.contains("HERO RANKS")
		and ticket.tooltip_text.contains("HERO RANK 1"),
		"returning to a single-target intent leaves no stale multi-rank hazard")
	ticket.present_intent(IRON_TREAD, 1)
	_check(ticket.tooltip_text.contains("Thorns 4")
		and not ticket.tooltip_text.contains("Tear") and not ticket.tooltip_text.contains("IF HIT"),
		"a self buff replaces the previous attack hazard without a hit-roll claim")
	# PASS and STUN disclose no threat at all.
	var pass_intent := BEHEMOTH_MAUL.duplicate(true)
	pass_intent["pass"] = true
	pass_intent["affected_ranks"] = []
	pass_intent["target_side"] = ""
	pass_intent["target_rank"] = 0
	ticket.present_intent(pass_intent, 1)
	_check(ticket.visible and ticket.primary.text == "PASS" and ticket.secondary.text == "NO ACTION"
		and not ticket.tooltip_text.contains("THREAT") and not ticket.tooltip_text.contains("Tear")
		and not ticket.tooltip_text.contains("BASE"),
		"PASS clears the earlier threat, base numbers and any fake target")
	var stun_intent := BEHEMOTH_MAUL.duplicate(true)
	stun_intent["stun"] = true
	stun_intent["affected_ranks"] = []
	stun_intent["target_side"] = ""
	ticket.present_intent(stun_intent, 1)
	_check(ticket.visible and ticket.primary.text == "STUN" and ticket.secondary.text == "NO ACTION"
		and not ticket.tooltip_text.contains("THREAT") and not ticket.tooltip_text.contains("Tear"),
		"STUN clears the earlier threat without inventing an action")
	# Malformed target data fails closed but keeps the exact authored base line.
	var no_target := BEHEMOTH_MAUL.duplicate(true)
	no_target["target_side"] = "foe"
	no_target["affected_ranks"] = [0, 2, 5]
	ticket.present_intent(no_target, 1)
	_check(ticket.secondary.text == "NO TARGET"
		and ticket.tooltip_text.contains("No currently legal target")
		and not ticket.tooltip_text.contains("THREAT")
		and ticket.tooltip_text.contains("BASE DMG 8–12"),
		"malformed ranks fabricate neither target nor threat but keep the exact base line")
	# Invalid seats and empty intents wipe the ticket entirely.
	for bad_rank in [0, 5]:
		ticket.present_intent(BEHEMOTH_MAUL, bad_rank)
		_check(not ticket.visible and ticket.tooltip_text.is_empty()
			and ticket.primary.text.is_empty() and ticket.secondary.text.is_empty(),
			"invalid foe rank %d clears the ticket and its threat" % bad_rank)
	ticket.present_intent(BEHEMOTH_MAUL, 1)
	_check(ticket.visible and ticket.tooltip_text.contains("THREAT HERO RANK 1"),
		"a later legal intent presents its own threat after an invalid one")
	ticket.present_intent({}, 1)
	_check(not ticket.visible and ticket.tooltip_text.is_empty() and ticket.glyph.texture == null
		and not ticket.glyph.visible and ticket.primary.text.is_empty()
		and ticket.secondary.text.is_empty(),
		"an empty intent clears every stale threat, glyph and caption")
	ticket.present_intent(QUEEN_DUST, 1)
	ticket.clear_intent()
	_check(not ticket.visible and ticket.tooltip_text.is_empty() and ticket.foe_id.is_empty()
		and ticket.foe_rank == 0 and ticket.ability_kind.is_empty()
		and ticket.glyph.texture == null and not ticket.glyph.visible
		and ticket.primary.text.is_empty() and ticket.secondary.text.is_empty(),
		"clear_intent removes the disclosed threat completely")
	host.free()


func _test_live_battle_screen() -> void:
	# The real Stitched battle screen already mounts these tickets; prove that the very
	# same live projection now explains itself through the screen's own disclosure panel.
	var host := Control.new()
	host.name = "ThreatLiveHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(StitchedBattleScreen.read_preview()),
		"precondition: the real seeded Stitched battle accepts the preview")
	host.add_child(stage)
	await process_frame
	if stage.battle == null:
		_check(false, "precondition: mounted live battle exists")
		host.free()
		return
	var snapshot := stage.battle.state_snapshot()
	var rng := stage.battle.rng_state()
	var receipts := stage.receipts.duplicate(true)
	var witnessed := 0
	for rank in range(1, 5):
		var ticket: StitchedFoeIntentPlate = stage._foe_tickets[rank]
		if not ticket.visible:
			continue
		witnessed += 1
		var intent: Dictionary = stage._foe_intents.get(rank, {})
		var threat := StitchedFoeThreatSummary.summary(intent)
		_check(not threat.is_empty() and ticket.tooltip_text.contains(threat)
			and threat.begins_with("THREAT "),
			"live rank %d ticket explains its own projected hazard" % rank)
		ticket.mouse_entered.emit()
		_check(stage._intent_disclosure.visible
			and stage._intent_disclosure_label.text == ticket.tooltip_text
			and stage._intent_disclosure_label.get_line_count()
				<= stage._intent_disclosure_label.get_visible_line_count(),
			"live rank %d hover shows the whole richer disclosure without clipping" % rank)
		ticket.mouse_exited.emit()
		_check(not stage._intent_disclosure.visible,
			"live rank %d leaving hover dismisses the disclosure" % rank)
	_check(witnessed >= 2, "non-vacuous: two or more live foe tickets carry a threat")
	_check(stage.battle.state_snapshot() == snapshot and stage.battle.rng_state() == rng
		and stage.receipts == receipts,
		"live intent disclosure spends no turn, receipt or RNG")
	host.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_test_summary_table()
	_test_fail_closed()
	await _test_mounted_ticket()
	await _test_live_battle_screen()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_foe_threat_summary_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
