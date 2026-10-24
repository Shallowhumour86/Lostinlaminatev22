extends SceneTree

var game: Node
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: "+description)

func click(id: String) -> void:
	game.interact(id)
	game.modal.hide()

func choose(id: String) -> void:
	game._choose(id)
	game.modal.hide()

func fresh() -> void:
	choose("new")

func get_identity() -> void:
	click("case")
	click("hotel_exit")
	click("archive_exit")
	click("records")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	fresh()
	check(game.room=="hotel", "New game starts in hotel")
	click("hotel_exit")
	check(game.room=="hotel", "Travel card gates the hotel exit")
	click("mirror")
	check(game.flags.has("memory"), "Mirror recovers the investigation lead")
	get_identity()
	check(game.flags.has("identity") and game.inventory.has("Restored identity"), "Identity can be restored")
	click("archive_return")
	click("quinn")
	choose("courier")
	choose("courier")
	check(game.inventory.count("Quinn's parcel")==1, "Courier job cannot duplicate inventory")
	click("garden_exit")
	click("dahlia")
	check(game.credits==45, "Courier delivery pays 30 credits")
	click("dahlia")
	check(game.credits==45, "Delivery cannot be farmed for money")
	click("garden_return")
	click("terminal_exit")
	choose("pay")
	check(game.debt==0 and game.credits==5, "Debt payment subtracts exactly the outstanding amount")
	click("lift")
	choose("end_depart")
	check(game.ending=="A SKY OF YOUR OWN", "Paid departure ending completes")
	fresh()
	get_identity()
	click("archive_return")
	choose("sample")
	click("archive_exit")
	click("parcel")
	click("parcel")
	check(game.credits==40 and game.flags.has("sample_delivered"), "Research reward is paid once")
	click("archive_return")
	click("garden_exit")
	click("fountain")
	click("garden_return")
	click("terminal_exit")
	click("embassy")
	choose("embassy_clear")
	check(game.debt==0 and game.credits==40 and game.flags.has("inquiry"), "Evidence clears fraudulent debt without charging credits")
	click("lift")
	choose("end_truth")
	check(game.ending=="NOTHING LOST", "Evidence and backup unlock truth ending")
	fresh()
	get_identity()
	click("archive_return")
	choose("courier")
	click("garden_exit")
	click("dahlia")
	choose("garden_offer")
	check(game.modal_body.get_child(0).text=="A place to grow", "Garden work and identity unlock the caretaker offer")
	choose("end_garden")
	check(game.ending=="A DIFFERENT KIND OF DAWN" and game.debt==0, "Garden ending completes")
	fresh()
	get_identity()
	game.player = Vector2(2.25,3.5)
	game.target = game.player
	game.credits = 123
	check(game.save_game(), "Save writes atomically to user data")
	game.credits = 0
	game.enter("hotel")
	check(game.load_game(), "Save can be loaded")
	check(game.credits==123 and game.room=="archive" and game.player==Vector2(2.25,3.5), "Save round trip preserves progress and position")
	check(not game._valid_save({}), "Malformed save is rejected")
	check(not game._valid_save({"version":1,"room":"missing"}), "Unknown room is rejected")
	check(game._clamp_position(Vector2(-100,100))==Vector2(0,7), "Movement stays on the playable floor")
	for room_id in game.Story.ROOMS:
		game.enter(room_id)
		await process_frame
		for o in game.Story.ROOMS[room_id].objects:
			check(o.at==game._clamp_position(o.at), room_id+" / "+o.id+" is reachable")
	# Navigate to every interactable from its room spawn, routing around solid scenery.
	for room_id in game.Story.ROOMS:
		for o in game.Story.ROOMS[room_id].objects:
			game.enter(room_id)
			game.modal.hide()
			game._click_at(game.iso(o.at)-Vector2(0,25))
			check(game.pending==o.id, room_id+" / "+o.id+" has an approach path")
			var safe := true
			for frame in range(500):
				game._process(1.0/60.0)
				if game.room!=room_id or game.pending.is_empty(): break
				if game._blocked(game.player): safe = false
			check(game.pending.is_empty() and safe, room_id+" / "+o.id+" click walks around obstacles and interacts")
	# Actual input-to-movement integration, rather than only teleporting a player.
	fresh()
	var before: Vector2 = game.player
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(20): await process_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(game.player.distance_to(before)>0, "Keyboard input moves the player")
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = game.iso(Vector2(3,3))
	# _unhandled_input uses mouse viewport position; direct world-coordinate inversion
	# is checked independently of host pointer position in headless mode.
	check(game.uniso(game.iso(Vector2(3,3))).distance_to(Vector2(3,3))<0.001, "Isometric click projection round trips")
	print("SMOKE RESULT: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if failures==0 else 1)
