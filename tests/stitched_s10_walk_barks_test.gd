extends SceneTree
## S10: left alone in the corridor, a trailing doll speaks, and what it says follows the walk's hidden state.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var barks := StitchedWalkBarks.new()
	_check(barks.valid(), "authored bark lines load")
	for kind in ["idle", "hurt", "dark", "shadow", "tug", "whirr", "mannequins", "wren", "curio"]:
		_check(not barks.data.contexts.get(kind, []).is_empty(), "lines for " + kind)
	var stage := StitchedWalkScreen.new()
	_check(stage.begin(548), "preview walk starts")
	root.add_child(stage)
	await process_frame
	_check(stage.bark_label != null and not stage.bark_label.visible, "the dolls start quiet")
	_check(not stage.bark_timer.is_stopped() and is_equal_approx(stage.bark_timer.wait_time, float(barks.data.idle_delay)),
		"the idle wait is armed")
	var said := stage.bark()
	_check(not said.is_empty() and stage.bark_label.visible and stage.bark_label.text.contains(said.line), "an idle doll speaks one line")
	_check(said.speaker != stage.expected.viewpoint, "the voice comes from a doll behind, not the borrowed eyes")
	var again := StitchedWalkBarks.new().pick(stage.expected, stage.walk, "bright", 0, 0)
	_check(again.line == said.line and again.speaker == said.speaker, "the same walk picks the same first line")
	var second := stage.bark()
	_check(second.line != said.line or barks.data.contexts[second.context].size() == 1, "no line twice in a row")
	stage.command("look_back")
	_check(not stage.bark_label.visible and not stage.bark_timer.is_stopped(), "any command hushes the doll and restarts the wait")
	stage.command("look_back")
	stage.candle = 0
	stage.refresh()
	var dark := stage.bark()
	_check(dark.context in ["dark", "tug", "shadow", "mannequins", "whirr"], "a snuffed candle makes the dolls speak of the dark")
	stage.candle = 78
	var hurt_state: Dictionary = stage.expected.duplicate(true)
	hurt_state.dolls[2].hp = 1
	var hurt := barks.pick(hurt_state, stage.walk, "bright", 0, 0)
	if StitchedWalkBarks.context(hurt_state, stage.walk, "bright", 0) == "hurt":
		_check(hurt.speaker == hurt_state.dolls[2].id, "the doll coming apart speaks for itself")
	var shadow_state: Dictionary = stage.expected.duplicate(true)
	if shadow_state.has("shadow"):
		shadow_state.shadow.present = true
		shadow_state.shadow.removed = false
		shadow_state.shadow.step = 0
		_check(StitchedWalkBarks.context(shadow_state, stage.walk, "bright", 0) in ["tug", "shadow"],
			"an unseen extra doll colours the chatter before LOOK BACK")
	_check(StitchedWalkBarks.context(stage.expected, stage.walk, "bright", 80) in ["wren", "tug", "shadow", "mannequins", "whirr", "hurt", "curio"] \
		or stage.expected.phase != "walking", "Wren's fear reaches the dolls")
	stage.reduced_motion = true
	stage.bark()
	_check(stage.bark_label.modulate.a == 1.0, "reduced motion shows the line without a fade")
	stage.free()
	for failure in failures:
		printerr(failure)
	print("stitched_s10_walk_barks_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
