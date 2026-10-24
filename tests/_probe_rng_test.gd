extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 6
	p.lifetime = 0.15
	p.emitting = false
	root.add_child(p)
	# Now seed (as a test would) and reuse the pre-built node.
	seed(8123)
	var before := randi()
	seed(8123)
	p.emitting = true
	p.position = Vector2(100, 100)
	await process_frame
	var after := randi()
	print("PROBE reuse_emitting equal=", before == after)

	seed(8123)
	var c := randi()
	seed(8123)
	p.emitting = false
	p.visible = false
	p.emitting = true
	p.visible = true
	await process_frame
	var d := randi()
	print("PROBE reuse_reset equal=", c == d)
	quit()
