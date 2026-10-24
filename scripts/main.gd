extends Node2D

const Story = preload("res://scripts/story.gd")
const SAVE_PATH = "user://journey.json"
const TILE = Vector2(39, 20)
const ORIGIN = Vector2(625, 180)
var room: String = "hotel"
var player := Vector2(4, 5)
var target := Vector2(4, 5)
var credits: int = 15
var debt: int = 40
var inventory: Array = []
var flags: Dictionary = {}
var journal: Array = ["Wake up in the Glass Hotel. Recover your identity and find a way off Torei."]
var elapsed: float = 0.0
var steps: int = 0
var ending: String = ""
var modal: PanelContainer
var modal_body: VBoxContainer
var hud: Label
var objective: Label
var prompt: Label
var toast_label: Label
var toast_time: float = 0.0
var sidebar: Label
var audio: AudioStreamPlayer
var muted: bool = false
var ui: CanvasLayer
var pending: String = ""
var navigation := AStarGrid2D.new()
var walk_path: Array[Vector2] = []

func _ready() -> void:
	_build_ui()
	_build_audio()
	_prepare_navigation()
	_refresh()
	if not OS.get_cmdline_user_args().has("--smoke"):
		_title()

func iso(p: Vector2) -> Vector2:
	return ORIGIN + Vector2((p.x-p.y)*TILE.x, (p.x+p.y)*TILE.y)

func uniso(p: Vector2) -> Vector2:
	var v := p - ORIGIN
	return Vector2((v.x/TILE.x+v.y/TILE.y)*0.5, (v.y/TILE.y-v.x/TILE.x)*0.5)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var top := ColorRect.new()
	top.color = Color("0b1524")
	top.position = Vector2(0,0)
	top.size = Vector2(1280,94)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	hud = _label(root, Vector2(35,22), 25, Color("eee3c5"))
	objective = _label(root, Vector2(35,60), 15, Color("8faabb"))
	var brand := _label(root, Vector2(996,24), 17, Color("53d9cd"))
	brand.text = "LOST IN LAMINATE\nT H E   W A Y   U P"
	var side := ColorRect.new()
	side.position = Vector2(20,123)
	side.size = Vector2(228,506)
	side.color = Color(0.035,0.065,0.10,0.94)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(side)
	sidebar = _label(root, Vector2(36,144), 16, Color("b6cbd0"))
	sidebar.size = Vector2(197,470)
	sidebar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt = _label(root, Vector2(285,690), 20, Color("f4d4a0"))
	var footer := _label(root, Vector2(35,760), 14, Color("7996a4"))
	footer.text = "WASD / ARROWS  Move     CLICK  Walk / interact     E  Interact     J  Journal     F5 / F9  Save / load     M  Audio     ESC  Menu"
	toast_label = _label(root, Vector2(285,727), 16, Color("64dcca"))
	modal = PanelContainer.new()
	modal.position = Vector2(300,146)
	modal.size = Vector2(700,570)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f30")
	style.border_color = Color("407b85")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	modal.add_theme_stylebox_override("panel",style)
	root.add_child(modal)
	modal_body = VBoxContainer.new()
	modal_body.add_theme_constant_override("separation",14)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(modal_body)
	modal.hide()

func _label(parent: Node, at: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = at
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func _dialog(title: String, body: String, choices: Array) -> void:
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	var title_label := _label(modal_body, Vector2.ZERO, 26, Color("f1dfba"))
	title_label.text = title
	var text := _label(modal_body, Vector2.ZERO, 18, Color("c5d7de"))
	text.custom_minimum_size.x = 640
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = body
	for choice in choices:
		var b := Button.new()
		b.text = choice[0]
		b.custom_minimum_size = Vector2(640,40)
		b.add_theme_font_size_override("font_size",16)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_choose.bind(str(choice[1])))
		modal_body.add_child(b)
	modal.size = Vector2(700,570)
	modal.show()
	if modal_body.get_child_count() > 2:
		modal_body.get_child(2).grab_focus()

func _title() -> void:
	_dialog("LOST IN LAMINATE", "THE WAY UP\n\nYou wake beneath an unfamiliar ceiling on Torei. Your memories are missing. The hotel says you owe forty credits. Somewhere above the stack clouds, an orbital elevator is waiting.\n\nExplore five districts, follow the paper trail, and choose what freedom means to you. A non-explicit, standalone adaptation of the Twine setting.", [["Begin a new journey","new"],["Continue saved journey","load"],["Controls & accessibility","help"]])

func _refresh() -> void:
	var r: Dictionary = Story.ROOMS[room]
	hud.text = r.name
	objective.text = r.subtitle
	sidebar.text = "PROSPECTOR\n──────────────\nCredits    %d\nHotel debt    %d\n\nCURRENT LEAD\n%s\n\nINVENTORY\n%s" % [credits,debt,_lead(),"Nothing yet" if inventory.is_empty() else "\n".join(inventory)]
	queue_redraw()

func _lead() -> String:
	if not flags.has("identity"): return "Find proof of your identity. Start with the hotel mirror and travel case."
	if debt > 0: return "Clear your debt through work, help from the embassy, or a new life in the garden."
	return "Your account is clear. Speak to Cor at the Way Up terminal."

func note(text: String) -> void:
	if not journal.has(text): journal.append(text)
	toast_label.text = text
	toast_time = 5.0
	_refresh()

func enter(next_room: String) -> void:
	room = next_room
	player = Story.ROOMS[room].spawn
	target = player
	pending = ""
	walk_path.clear()
	_prepare_navigation()
	_refresh()

func _process(delta: float) -> void:
	elapsed += delta
	toast_time -= delta
	if toast_time < 0: toast_label.text = ""
	if not modal.visible and ending.is_empty():
		var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		direction += Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		if direction.length() > 0:
			var world_direction := Vector2(direction.x+direction.y, direction.y-direction.x).normalized()
			var candidate := _clamp_position(player+world_direction*0.3)
			if not _blocked(candidate): target = candidate
			walk_path.clear()
			pending = ""
		var old := player
		player = player.move_toward(target,delta*3.6)
		if player.distance_to(old) > 0.001: steps += 1
		if player.distance_to(target)<0.08 and not walk_path.is_empty():
			target = walk_path.pop_front()
		if not pending.is_empty() and walk_path.is_empty() and player.distance_to(target)<0.12:
			var id := pending
			pending = ""
			interact(id)
		var nearest := _nearest()
		prompt.text = "" if nearest.is_empty() else "[ E ]  " + str(nearest.name)
	else:
		prompt.text = ""
	queue_redraw()

func _clamp_position(p: Vector2) -> Vector2:
	var bounds: Vector2i = Story.ROOMS[room].size
	return p.clamp(Vector2.ZERO,Vector2(bounds)-Vector2.ONE)

func _nearest() -> Dictionary:
	var result := {}
	var distance := 1.75
	for o in Story.ROOMS[room].objects:
		var d: float = player.distance_to(o.at)
		if d < distance:
			distance = d
			result = o
	return result

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5: save_game()
			KEY_F9: load_game()
			KEY_M:
				muted = not muted
				if audio != null: audio.volume_db = -80 if muted else -23
			KEY_ESCAPE:
				if modal.visible and ending.is_empty(): modal.hide()
				else: _dialog("Pause", "Your journey waits.",[["Resume","close"],["Save journey","save"],["Load journey","load"],["Controls","help"],["Title screen","title"],["Quit game","quit"]])
			KEY_J: _dialog("Field journal", "\n\n".join(journal), [["Return","close"]])
			KEY_E, KEY_ENTER:
				if not modal.visible:
					var o := _nearest()
					if not o.is_empty(): interact(o.id)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not modal.visible:
		_click_at(get_global_mouse_position())

func _prepare_navigation() -> void:
	navigation.region = Rect2i(Vector2i.ZERO,Story.ROOMS[room].size)
	navigation.cell_size = Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for o in Story.ROOMS[room].objects:
		if o.kind not in ["door","lift"]:
			navigation.set_point_solid(Vector2i(o.at),true)
	var scenery: Array = []
	match room:
		"hotel": scenery = [Vector2i(2,5)]
		"hub": scenery = [Vector2i(5,2),Vector2i(1,1),Vector2i(9,1)]
		"garden": scenery = [Vector2i(1,1),Vector2i(7,1),Vector2i(1,6),Vector2i(7,6)]
		"archive":
			for x in range(3,8): scenery.append(Vector2i(x,1))
		"terminal": scenery = [Vector2i(1,1),Vector2i(8,1)]
	for cell in scenery: navigation.set_point_solid(cell,true)

func _blocked(p: Vector2) -> bool:
	var cell := Vector2i(p.round())
	return not navigation.is_in_boundsv(cell) or navigation.is_point_solid(cell)

func _walk_to(destination: Vector2) -> bool:
	var cell := Vector2i(_clamp_position(destination).round())
	if navigation.is_point_solid(cell): return false
	var start := Vector2i(player.round())
	var cells := navigation.get_id_path(start,cell)
	if cells.is_empty(): return false
	walk_path.clear()
	for i in range(1,cells.size()): walk_path.append(Vector2(cells[i]))
	target = Vector2(cell) if walk_path.is_empty() else walk_path.pop_front()
	return true

func _click_at(click: Vector2) -> void:
	if click.x < 260 or click.y < 100 or click.y > 680: return
	pending = ""
	for o in Story.ROOMS[room].objects:
		if click.distance_to(iso(o.at)-Vector2(0,25)) < 38:
			var candidates: Array[Vector2] = []
			for offset in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(1,1),Vector2(-1,-1)]:
				var candidate: Vector2 = o.at+offset
				if candidate==_clamp_position(candidate) and not _blocked(candidate): candidates.append(candidate)
			candidates.sort_custom(func(a,b): return player.distance_squared_to(a)<player.distance_squared_to(b))
			for candidate in candidates:
				if _walk_to(candidate):
					pending = o.id
					return
			return
	_walk_to(uniso(click))

func interact(id: String) -> void:
	if Story.ROUTES.has(id):
		if id=="hotel_exit" and not inventory.has("Travel card"):
			_dialog("A locked account", "The door scanner asks for your travel card. Your case is still beside the bed.",[["Back","close"]])
		else: enter(Story.ROUTES[id])
		return
	match id:
		"mirror":
			flags["memory"] = true
			note("A memory: you arrived on Torei to investigate a corrupted identity ledger.")
			_dialog("A familiar stranger", "The mirror catches your face in a lattice of pale light. A memory surfaces: you were a prospector investigating vanished travel records. Someone erased your own.\n\nYour reflection whispers a name: Aekora Civic Archive.",[["Remember the archive","close"]])
		"case":
			if not inventory.has("Travel card"):
				inventory.append("Travel card")
				note("Recovered a travel card. The civic archive can reconstruct its damaged signature.")
			_dialog("The travel case", "Inside your coat is a cracked travel card. The photograph is yours; the identity field is blank. You take the card and put on the coat.\n\nThe hotel door will now recognize you.", [["Take a breath","close"]])
		"concierge":
			_dialog("The concierge", "“Your room was booked by someone using your name. The balance is forty credits. You're free to leave the hotel, but departures checks will see the debt.”\n\nShe lowers her voice. “Quinn pays for courier work. And the embassy can investigate fraudulent charges.”",[["Dispute the account","dispute"],["Pay 40 credits" if debt>0 else "Confirm cleared account","pay"],["Leave the desk","close"]])
		"isabella":
			_dialog("Isabella / transit guide", "“A missing identity? I've seen that before. The archive is east of this concourse. Find the terminal with the violet light.”\n\n“The Way Up is north. You need a reconstructed identity and a settled account to board. If you'd rather stay, Sister Euphoria keeps a garden west of here.”",[["Mark the routes","guide"],["Thank her","close"]])
		"offworlder":
			if flags.has("sample_delivered"):
				_dialog("Offworld researcher", "“That sample proved the record damage wasn't accidental. Thank you. Keep your eyes open up there.”",[["Goodbye","close"]])
			else:
				_dialog("Offworld researcher", "A researcher holds out a sealed data capsule. “Would you deposit this in the archive's research box? Twenty-five credits on delivery. It contains a clean backup of the transport ledger.”",[["Accept the research capsule","sample"],["Not now","close"]])
		"quinn":
			if flags.has("parcel_delivered"):
				_dialog("Quinn / dispatch", "“Good work. Your delivery is already recorded. That's how things should work around here.”",[["Back","close"]])
			else:
				_dialog("Quinn / dispatch", "“A sealed parcel for Dahlia in the convent garden. Thirty credits, paid automatically when she confirms receipt. No deposit, no tricks. Interested?”",[["Take the courier job","courier"],["Maybe later","close"]])
		"sister":
			_dialog("Sister Euphoria", "“The city measures everything in credits. We measure what can grow.”\n\n“The pool preserves old reflections. It may hold the proof you need. And if the Way Up isn't your answer, the garden has room for another caretaker.”",[["Ask about staying in the garden","garden_offer"],["Return to the garden","close"]])
		"dahlia":
			if inventory.has("Quinn's parcel"):
				inventory.erase("Quinn's parcel")
				credits += 30
				flags["parcel_delivered"] = true
				note("Delivered Quinn's parcel to Dahlia. Earned 30 credits.")
				_dialog("Dahlia", "“Replacement parts for our irrigation pump! Quinn said you'd come.”\n\nYour card chimes: thirty credits received. Dahlia points toward the pool. “Look closely. The water remembers more than we do.”",[["Delivery complete","close"]])
			else:
				_dialog("Dahlia", "“I'm waiting for a delivery from Quinn. If you see them at the concourse, could you bring it over?”",[["Back","close"]])
		"fountain":
			flags["evidence"] = true
			note("The pool's backup proves your hotel booking was forged. Bring this evidence to the embassy.")
			_dialog("The reflection pool", "Light ripples over an old public data mirror. Your travel card triggers a recovered entry: the hotel booking was made after you had already checked in.\n\nA forged charge. You copy its signature to your card. The embassy can use this.",[["Keep the evidence","close"]])
		"records":
			if not inventory.has("Travel card"):
				_dialog("Identity terminal", "Insert your travel card. It is still in the hotel travel case.",[["Back","close"]])
			else:
				flags["identity"] = true
				if not inventory.has("Restored identity"): inventory.append("Restored identity")
				note("Identity restored: independent prospector. Your travel clearance is valid again.")
				_dialog("Identity reconstructed", "The terminal assembles fragments from a dozen transit records.\n\nPROSPECTOR / INDEPENDENT SURVEYOR\nARRIVAL: TOREI / AEKORA\nDEPARTURE CLEARANCE: VALID\n\nYou remember the view from orbit. You can go home. Or you can finish what brought you here.",[["Take the restored record","close"]])
		"parcel":
			if inventory.has("Research capsule"):
				inventory.erase("Research capsule")
				flags["sample_delivered"] = true
				credits += 25
				note("Research capsule delivered. Earned 25 credits; the backup exposes a ledger anomaly.")
				_dialog("Backup received", "The dropbox confirms an intact transport ledger. A transfer of twenty-five credits follows. The researcher will have what they need.",[["Back","close"]])
			else: _dialog("Research dropbox", "A secure receptacle for the offworld researcher's data capsules.",[["Back","close"]])
		"malice":
			_dialog("Malice / archivist", "“Memories are fragile. Records should not be.” The archivist turns a screen toward you. “Someone has been rewriting the arrival ledger. Recover your identity here, then take independent evidence to the embassy. Don't pay for someone else's fraud.”",[["Record the warning","warning"],["Leave","close"]])
		"embassy":
			if flags.has("identity") and flags.has("evidence"):
				_dialog("Embassy uplink", "The officer compares your restored identity to the pool's backup. “This charge is fraudulent. We can cancel it and open an inquiry. Will you authorize us to use your evidence?”",[["Submit evidence and clear the debt","embassy_clear"],["Keep the evidence for now","close"]])
			else:
				_dialog("Embassy uplink", "“We need a restored identity from the civic archive and independent evidence of the forged booking. Try the garden's old reflection pool.”",[["Back","close"]])
		"cor":
			_dialog("Cor / departures", "“The elevator rises at dawn. An independent identity and a clear account will get you aboard.”\n\nCor looks out at the stack clouds. “People arrive here for all sorts of reasons. Leaving should always be their choice.”",[["Settle outstanding debt","pay"],["Check departure gate","lift_check"],["Step away","close"]])
		"lift": _check_lift()
	_refresh()

func _check_lift() -> void:
	if not flags.has("identity"):
		_dialog("Identity required", "The departure scanner cannot read your damaged card. Reconstruct it at the civic archive.",[["Back","close"]])
	elif debt > 0:
		_dialog("Account on hold", "Your identity is valid, but the hotel account is still open. Pay it through Cor, or prove the booking was forged at the embassy.",[["Pay outstanding debt","pay"],["Find another way","close"]])
	else:
		_dialog("The Way Up", "The doors open. Above you, the elevator cable disappears into bright cloud. You have your name back. Now you decide what comes next.",[["Leave Torei and begin again","end_depart"],["Publish the evidence before leaving","end_truth"],["Stay a little longer","close"]])

func _choose(action: String) -> void:
	modal.hide()
	match action:
		"new":
			credits = 15
			debt = 40
			inventory.clear()
			flags.clear()
			journal = ["Wake up in the Glass Hotel. Recover your identity and find a way off Torei."]
			ending = ""
			elapsed = 0
			enter("hotel")
		"title": _title()
		"quit": get_tree().quit()
		"help": _dialog("How to play", "Move with WASD or the arrow keys. Click a floor tile to walk there. Click a person or object to approach and interact, or press E nearby.\n\nJ opens your journal. F5 saves, F9 loads. M toggles the original ambient soundtrack. Escape opens the menu. Menus support Tab, Shift+Tab and Enter.\n\nThere are no timed choices, combat, or fail states. Work is paid once; you can always explore before choosing an ending.",[["Back to the journey","close"]])
		"save": save_game()
		"load": load_game()
		"dispute": note("The concierge suggests gathering independent evidence for the embassy.")
		"guide": note("Isabella marked the routes: archive east, garden west, orbital terminal north.")
		"warning": note("Malice confirmed the arrival ledger has been altered. The embassy needs independent evidence.")
		"pay":
			if debt == 0: note("Your account is already clear.")
			elif credits >= debt:
				credits -= debt
				debt = 0
				flags["paid"] = true
				note("Hotel account paid. Departure account restrictions lifted.")
			else: _dialog("Not enough credits", "You need %d more credits. Quinn's delivery pays 30 and the research capsule pays 25. Or gather evidence and challenge the charge at the embassy." % (debt-credits),[["Back","close"]])
		"sample":
			if not flags.has("sample_delivered") and not inventory.has("Research capsule"):
				inventory.append("Research capsule")
				note("Deliver the research capsule to the civic archive's dropbox for 25 credits.")
		"courier":
			if not flags.has("parcel_delivered") and not inventory.has("Quinn's parcel"):
				inventory.append("Quinn's parcel")
				note("Bring Quinn's parcel to Dahlia in the convent garden for 30 credits.")
		"garden_offer":
			if flags.has("identity") and flags.has("parcel_delivered"):
				_dialog("A place to grow", "Sister Euphoria offers you paid work tending the garden. The convent will settle the disputed account as part of its welcome. You would stay by your own choice, with your name and travel rights intact.",[["Choose a new life in the garden","end_garden"],["Keep exploring","close"]])
			else: _dialog("First, find your roots", "“Recover your identity and help Dahlia with Quinn's delivery. Then we can talk about making a home here.”",[["Back","close"]])
		"embassy_clear":
			debt = 0
			flags["inquiry"] = true
			note("The embassy voided the fraudulent hotel charge and opened an inquiry.")
		"lift_check": _check_lift()
		"end_depart": finish("A SKY OF YOUR OWN", "The city falls away beneath the elevator. For the first time since you woke, every record on your card belongs to you. Ahead is the dark between stars, and a journey you choose.")
		"end_truth":
			if flags.has("evidence") and flags.has("sample_delivered"):
				finish("NOTHING LOST", "You send the clean research ledger and the forged booking to the embassy. By sunrise, other travelers can reclaim their names too. You board the Way Up carrying something better than a clean account: the truth.")
			else: _dialog("An incomplete case", "To publish a convincing case, recover the pool's evidence and deliver the offworld researcher's capsule to the archive. You can still leave without publishing.",[["Keep investigating","close"],["Leave Torei","end_depart"]])
		"end_garden":
			debt = 0
			finish("A DIFFERENT KIND OF DAWN", "You stay in Torei, but on your own terms. Dahlia teaches you the irrigation controls. Sister Euphoria plants a new row beside yours. The Way Up will still be there if you ever change your mind.")
	_refresh()

func finish(title: String, body: String) -> void:
	ending = title
	flags["completed"] = true
	note("Ending reached: "+title)
	_dialog(title, body+"\n\nJOURNEY COMPLETE\n%d journal entries · %d credits remaining\n\nThree endings await across different choices." % [journal.size(),credits],[["Explore before this ending","resume_end"],["Save this journey","save_end"],["Begin again","new"]])
	# Rebind ending-only choices to preserve the normal choice dispatcher.
	var explore: Button = modal_body.get_child(2)
	for c in explore.pressed.get_connections(): explore.pressed.disconnect(c.callable)
	explore.pressed.connect(func(): ending = ""; modal.hide())
	var save_button: Button = modal_body.get_child(3)
	for c in save_button.pressed.get_connections(): save_button.pressed.disconnect(c.callable)
	save_button.pressed.connect(func(): save_game())

func save_game() -> bool:
	var data := {"version":1,"room":room,"position":[player.x,player.y],"credits":credits,"debt":debt,"inventory":inventory,"flags":flags,"journal":journal,"elapsed":elapsed}
	var file := FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if file == null:
		note("Save failed: could not open the user data directory.")
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var error := DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)
	if error != OK:
		note("Save failed: could not replace the previous save.")
		return false
	toast_label.text = "Journey saved."
	toast_time = 4
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		_dialog("No saved journey", "Start a new journey, then press F5 to save your progress.",[["Begin","new"]])
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not _valid_save(data):
		_dialog("Save could not be read", "The save is invalid or uses an unsupported format. It has not been overwritten.",[["Back","close"]])
		return false
	room = data.room
	player = _clamp_position(Vector2(data.position[0],data.position[1]))
	target = player
	pending = ""
	walk_path.clear()
	_prepare_navigation()
	if _blocked(player):
		player = Story.ROOMS[room].spawn
		target = player
	credits = int(data.credits)
	debt = int(data.debt)
	inventory = data.inventory.duplicate()
	flags = data.flags.duplicate()
	journal = data.journal.duplicate()
	elapsed = float(data.get("elapsed",0))
	ending = ""
	modal.hide()
	_refresh()
	note("Journey loaded.")
	return true

func _valid_save(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("version") != 1 or not Story.ROOMS.has(data.get("room","")): return false
	if not data.get("position") is Array or data.position.size()!=2: return false
	for v in data.position:
		if not (v is float or v is int) or not is_finite(float(v)): return false
	for key in ["credits","debt"]:
		if not (data.get(key) is float or data.get(key) is int): return false
		if not is_finite(float(data[key])) or data[key]<0 or data[key]>1000000 or float(data[key])!=floor(float(data[key])): return false
	if not data.get("flags") is Dictionary: return false
	for value in data.flags.values():
		if not value is bool: return false
	var saved_elapsed = data.get("elapsed",0)
	if not (saved_elapsed is float or saved_elapsed is int): return false
	if not is_finite(float(saved_elapsed)) or saved_elapsed<0: return false
	for key in ["inventory","journal"]:
		if not data.get(key) is Array: return false
		for v in data[key]:
			if not v is String: return false
	return true

func _build_audio() -> void:
	# Synthesize an original, seamless eight-second ambient loop in memory.
	if DisplayServer.get_name()=="headless": return
	var mix_rate := 22050
	var frame_count := mix_rate*8
	var samples := PackedByteArray()
	samples.resize(frame_count*2)
	for i in range(frame_count):
		var t := float(i)/mix_rate
		var wave := (sin(TAU*110*t)+sin(TAU*165*t)*0.4+sin(TAU*220*t)*0.22)*0.15
		wave *= 0.7+sin(TAU*t/8.0)*0.15
		samples.encode_s16(i*2,int(clampf(wave,-1,1)*32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = mix_rate
	sound.data = samples
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_begin = 0
	sound.loop_end = frame_count
	audio = AudioStreamPlayer.new()
	audio.stream = sound
	audio.volume_db = -23
	add_child(audio)
	audio.play()

func _draw() -> void:
	# Original vector art: diamond tiles, architecture and animated characters.
	draw_rect(Rect2(0,94,1280,650),Color("081320"))
	for i in range(30):
		var p := Vector2(290+fmod(i*97.0,950),115+fmod(i*61.0,510))
		draw_circle(p,1.2,Color(0.3,0.7,0.75,0.2+0.15*sin(elapsed+i)))
	var r: Dictionary = Story.ROOMS[room]
	var bounds: Vector2i = r.size
	var tint := Color(r.color)
	for y in range(bounds.y):
		for x in range(bounds.x):
			var p := iso(Vector2(x,y))
			var checker := 0.18 if (x+y)%2==0 else 0.23
			var color := Color("1b293a").lerp(tint,checker)
			var diamond := PackedVector2Array([p+Vector2(-39,0),p+Vector2(0,-20),p+Vector2(39,0),p+Vector2(0,20)])
			draw_colored_polygon(diamond,color)
			draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),Color(0.3,0.65,0.7,0.12),1,true)
			if y==bounds.y-1:
				draw_colored_polygon(PackedVector2Array([p+Vector2(-39,0),p+Vector2(0,20),p+Vector2(0,34),p+Vector2(-39,14)]),Color("101d2b"))
			if x==bounds.x-1:
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,20),p+Vector2(39,0),p+Vector2(39,14),p+Vector2(0,34)]),Color("142c3a"))
	# Low rear walls keep the walkable floor unobscured.
	for x in range(bounds.x): _wall(iso(Vector2(x,0)),true,tint)
	for y in range(1,bounds.y): _wall(iso(Vector2(0,y)),false,tint)
	if room=="garden":
		for p in [Vector2(1,1),Vector2(7,1),Vector2(1,6),Vector2(7,6)]: _plant(iso(p))
	elif room=="hotel":
		_box(iso(Vector2(2,5)),Vector2(64,30),19,Color("47717f"))
		_box(iso(Vector2(2,5))-Vector2(0,21),Vector2(51,23),5,Color("b4c9c5"))
	elif room=="hub":
		_box(iso(Vector2(5,2)),Vector2(100,21),19,Color("31546b"))
		for p in [Vector2(1,1),Vector2(9,1)]: _beacon(iso(p),tint)
	elif room=="archive":
		for x in range(3,8): _box(iso(Vector2(x,1)),Vector2(25,13),52,Color("41435f"))
	elif room=="terminal":
		for p in [Vector2(1,1),Vector2(8,1)]: _beacon(iso(p),Color("e7b67a"))
	var actors: Array = []
	for o in r.objects: actors.append({"p":o.at,"object":o})
	actors.append({"p":player,"player":true})
	actors.sort_custom(func(a,b): return a.p.x+a.p.y < b.p.x+b.p.y)
	for actor in actors:
		var p := iso(actor.p)
		if actor.has("player"):
			_person(p,Color("5fdbcf"),true)
		else:
			var o: Dictionary = actor.object
			match o.kind:
				"person": _person(p,Color("d7a780") if room=="terminal" else tint.lightened(0.35),false)
				"door":
					draw_arc(p,15,0,TAU,24,Color("58d6c3"),2,true)
					draw_line(p-Vector2(0,4),p-Vector2(0,35),Color("58d6c3"),2,true)
					draw_colored_polygon(PackedVector2Array([p+Vector2(-6,-29),p+Vector2(0,-38),p+Vector2(6,-29)]),Color("a8f1df"))
				"case": _box(p,Vector2(27,15),19,Color("c3a77c"))
				"mirror":
					_box(p,Vector2(27,12),62,Color("759bac"))
					draw_line(p+Vector2(-9,-50),p+Vector2(8,-37),Color("d4fff6"),3,true)
				"terminal":
					_box(p,Vector2(24,15),36,tint)
					draw_rect(Rect2(p+Vector2(-10,-52),Vector2(27,18)),Color("73e4d7"))
					for line in range(3): draw_line(p+Vector2(-6,-48+line*4),p+Vector2(11,-48+line*4),Color("1d636b"),1)
				"pool":
					_box(p,Vector2(60,32),7,Color("8daca1"))
					_ellipse(p-Vector2(0,9),Vector2(36,15),Color("2b898c"))
					draw_arc(p-Vector2(0,10),12,0,TAU,24,Color("83e6d0"),1,true)
				"lift":
					_box(p,Vector2(72,28),95,Color("596e7a"))
					_box(p-Vector2(0,7),Vector2(45,20),72,Color("172e40"))
					draw_line(p-Vector2(0,10),p-Vector2(0,77),Color("ffdb93"),3,true)
			if player.distance_to(o.at)<1.75:
				draw_arc(p,23,0,TAU,32,Color("f0d6a0"),2,true)
			var label_pos := p-Vector2(0,77 if o.kind=="person" else 64)
			if o.kind=="lift": label_pos.y-=45
			var font := ThemeDB.fallback_font
			var text: String = o.name
			var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
			draw_rect(Rect2(label_pos-Vector2(width/2+6,14),Vector2(width+12,21)),Color(0.025,0.05,0.08,0.85))
			draw_string(font,label_pos-Vector2(width/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c2d9db"))
	if not modal.visible and player.distance_to(target)>0.15:
		draw_arc(iso(target),7,0,TAU,20,Color("83e6d0"),1.5,true)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32): points.append(center+Vector2(cos(i*TAU/32)*radius.x,sin(i*TAU/32)*radius.y))
	draw_colored_polygon(points,color)

func _box(p: Vector2, half: Vector2, height: float, color: Color) -> void:
	var a := p+Vector2(-half.x,0)
	var b := p+Vector2(0,half.y)
	var c := p+Vector2(half.x,0)
	var d := p+Vector2(0,-half.y)
	var up := Vector2(0,-height)
	draw_colored_polygon(PackedVector2Array([a,b,b+up,a+up]),color.darkened(0.28))
	draw_colored_polygon(PackedVector2Array([b,c,c+up,b+up]),color.darkened(0.48))
	draw_colored_polygon(PackedVector2Array([a+up,b+up,c+up,d+up]),color)

func _wall(p: Vector2, left: bool, tint: Color) -> void:
	var a := p+Vector2(0,-20)
	var b := p+Vector2(39,0) if left else p+Vector2(-39,0)
	draw_colored_polygon(PackedVector2Array([a,b,b-Vector2(0,48),a-Vector2(0,48)]),Color("142536").lerp(tint,0.13))
	draw_line(a-Vector2(0,48),b-Vector2(0,48),tint.lightened(0.2),2,true)

func _person(p: Vector2, color: Color, is_player: bool) -> void:
	var bob := sin(elapsed*3)*1.5
	if is_player and player.distance_to(target)>0.1: bob = sin(elapsed*13)*2.4
	_ellipse(p,Vector2(14,6),Color(0,0,0,0.35))
	var body := p+Vector2(0,-24+bob)
	draw_line(p+Vector2(-5,-2),body+Vector2(-5,8),Color("202e40"),6,true)
	draw_line(p+Vector2(5,-2),body+Vector2(5,8),Color("202e40"),6,true)
	draw_colored_polygon(PackedVector2Array([body+Vector2(-9,-12),body+Vector2(8,-12),body+Vector2(12,10),body+Vector2(-12,10)]),color)
	draw_line(body+Vector2(-12,-8),body+Vector2(-15,7),color.darkened(0.2),5,true)
	draw_line(body+Vector2(11,-8),body+Vector2(15,6),color.darkened(0.2),5,true)
	draw_circle(body-Vector2(0,21),9,Color("dab295"))
	draw_arc(body-Vector2(0,23),8,PI,TAU,12,Color("263244"),5,true)
	if is_player:
		draw_line(body+Vector2(-6,-10),body+Vector2(5,7),Color("e8e3be"),3,true)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-65),p+Vector2(5,-65),p+Vector2(0,-59)]),Color("80f0d9"))
	else:
		draw_circle(p-Vector2(0,65),3,Color("f2d394"))

func _plant(p: Vector2) -> void:
	_box(p,Vector2(19,11),15,Color("46585c"))
	for i in range(5):
		var tip := p+Vector2(sin(i*2.2)*19,-32-abs(cos(i*1.4))*22)
		draw_line(p-Vector2(0,12),tip,Color("488d73"),3,true)
		_ellipse(tip,Vector2(10,5),Color("74bc8e"))

func _beacon(p: Vector2, color: Color) -> void:
	_box(p,Vector2(11,7),65,Color("354556"))
	draw_circle(p-Vector2(0,67),6,color.lightened(0.3))
	draw_circle(p-Vector2(0,67),13,Color(color,0.08))

func _exit_tree() -> void:
	if audio != null: audio.stop()
