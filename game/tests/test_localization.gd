extends SceneTree
const Progress=preload("res://scripts/progress.gd")
var Loc:Script
var app:Control
var checks:=0
var failures:=0
var test_path:=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error("LOCALIZATION QA: "+note)
func write_json(path:String,data:Dictionary)->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func run()->void:
	root.size=Vector2i(480,854)
	root.content_scale_size=Vector2i(480,854)
	Loc=load("res://scripts/localization.gd")
	test_path="user://qa/localization-%d.json" % OS.get_process_id()
	var cases:={"zh":"zh_CN","ZH-hANT":"zh_TW","zh-Hans-HK":"zh_CN","zh-XX":"zh_CN","zh-CN":"zh_CN","zh_SG":"zh_CN","zh-TW":"zh_TW","zh_HK":"zh_TW","zh-MO":"zh_TW","zh-Hant-CN":"zh_TW","zh-Hans-TW":"zh_CN","zh-Hant":"zh_TW","zh-Hans":"zh_CN","en-US":"en","en_GB":"en","ja_JP":"en","fr-FR":"en","":"en"}
	for raw in cases:check(Loc.normalize_locale(raw)==cases[raw],"System locale mapping "+raw)
	var legacy:Dictionary={"version":1,"completed":[0,2],"left_handed":true,"sound":false}
	write_json(test_path,legacy)
	var loaded:Dictionary=Progress.load_data(test_path,12).data
	check(loaded.get("language","missing")=="","Legacy save migrates to follow-system empty language")
	check(loaded.completed==[0,2] and loaded.left_handed and not loaded.sound,"Migration preserves other settings and progress")
	for invalid in ["pirate",42,null,{},["en"]]:
		var bad:=legacy.duplicate(true)
		bad.language=invalid
		write_json(test_path,bad)
		var clean:Dictionary=Progress.load_data(test_path,12).data
		check(clean.get("language","missing")=="" and clean.completed==[0,2],"Invalid language safely falls back without deleting completions")
	write_json(test_path,legacy)
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path=test_path
	app.auth_path=test_path+".auth"
	root.add_child(app)
	app.audio.enabled=false
	app.auth.login_guest()
	check(app.language==Loc.normalize_locale(OS.get_locale()),"First run follows actual OS normalized language")
	await verify_runtime()
	print("LOCALIZATION_QA checks=",checks," failures=",failures)
	app.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
func touch(point:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.position=root.get_screen_transform()*point
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(control:Control)->void:
	var point:=control.get_global_rect().get_center()
	touch(point,true)
	touch(point,false)
func labels(node:Node)->Array:
	var out:Array=[]
	if node is Label or node is Button:out.append(node)
	for child in node.get_children():out.append_array(labels(child))
	return out
func verify_catalog()->void:
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/translations.json"))
	var args_for:={"levels.completed":[3],"hud.chapter":[2],"hud.food":[1,3],"hud.food_open":[3,3],"hud.moves":[12],"settings.hand":["Left"],"settings.sound":["On"],"settings.language":["English"]}
	var glyphs:Dictionary={}
	for locale in ["zh_CN","zh_TW","en"]:
		check(catalog.has(locale),"Catalog contains "+locale)
		for key in catalog.zh_CN:
			check(catalog[locale].has(key),locale+" has "+key)
			var translated:String=Loc.text(key,locale,args_for.get(key,[]))
			check(not translated.strip_edges().is_empty() and translated!=key,locale+" translates "+key)
			check(not translated.contains("%s") and not translated.contains("%d"),locale+" resolves args "+key)
			for index in translated.length():
				var code:=translated.unicode_at(index)
				if code>32:glyphs[code]=true
		for id in range(1,13):
			check(not Loc.level_title(id,locale).is_empty() and not Loc.level_hint(id,locale).is_empty(),locale+" level text "+str(id))
	var native_names:=""
	for code in ["zh_CN","zh_TW","en"]:native_names+=Loc.language_name(code)
	for index in native_names.length():glyphs[native_names.unicode_at(index)]=true
	for index in "✓▲▶▼◀".length():glyphs["✓▲▶▼◀".unicode_at(index)]=true
	for code in glyphs:check(app.font.has_char(code),"Font includes U+%04X"%code)
func verify_page(node:Node)->void:
	for item in labels(node):
		var value:String=item.text
		check(not value.strip_edges().is_empty(),"Visible UI has text: "+str(item.name))
		check(not value.contains("%s") and not value.contains("%d"),"No unresolved UI placeholders: "+str(item.name))
func verify_runtime()->void:
	verify_catalog()
	var expected_completed:Array=app.progress.completed.duplicate()
	for locale in ["zh_CN","zh_TW","en"]:
		app._show_home()
		app._settings()
		await process_frame
		tap(app.overlay.get_node("Panel/Language"))
		await process_frame
		check(app.overlay_kind=="language","Native language entry opens picker")
		var names:={"zh_CN":"LocaleZhCN","zh_TW":"LocaleZhTW","en":"LocaleEn"}
		tap(app.overlay.get_node("Panel/"+names[locale]))
		await process_frame
		check(app.language==locale and app.progress.language==locale,"Native locale selection applies "+locale)
		check(app.overlay_kind=="settings","Selection returns to translated settings")
		check(app.content.get_node("Settings").text==Loc.text("home.settings",locale),"Lobby behind settings updates immediately")
		check(app.overlay.get_node("Panel/Heading").text==Loc.text("settings.title",locale),"Settings heading updates immediately")
		verify_page(app.content)
		verify_page(app.overlay)
		var saved:Dictionary=Progress.load_data(test_path,12).data
		check(saved.language==locale and saved.completed==expected_completed and saved.left_handed and not saved.sound,"Language persists without overwriting progress or settings")
		app._close_overlay()
		app.show_levels()
		verify_page(app.content)
		check(app.content.get_node("Level0").tooltip_text==Loc.level_title(1,locale),"Localized level tooltip")
		app.start_level(11)
		check(app.content.get_node("Title").text==Loc.level_title(12,locale),"Localized actual level title")
		check(app.content.get_node_or_null("Hint")==null and app.content.get_node_or_null("ControlTip")==null,"Retired level hint and control tip stay absent")
		app.skip_animations=true
		app.try_move(Vector2i.RIGHT)
		check(app.step_label.text==Loc.text("hud.moves",locale,[1]),"Dynamic move counter")
		var before:Dictionary=app.state.duplicate(true)
		var history_before:Array=app.history.duplicate(true)
		var alternate:String="en" if locale!="en" else "zh_TW"
		app._set_language(alternate)
		check(app.state==before and app.history==history_before,"Live locale change preserves board and undo history")
		check(app.content.get_node("Title").text==Loc.level_title(12,alternate),"Live level label updates immediately")
		app._set_language(locale)
		app.pause_game()
		verify_page(app.overlay)
		app._close_overlay()
		app.start_level(0)
		for direction in [Vector2i.RIGHT,Vector2i.RIGHT,Vector2i.RIGHT]:app.try_move(direction)
		check(app.state.status=="won","Actual win state for localized modal")
		verify_page(app.overlay)
		app.start_level(6)
		app.try_move(Vector2i.RIGHT)
		app.try_move(Vector2i.RIGHT)
		check(app.state.status=="lost","Actual failure state for localized modal")
		verify_page(app.overlay)
		expected_completed=app.progress.completed.duplicate()
	app._show_home()
	app._settings()
	app._language_settings()
	await process_frame
	tap(app.overlay.get_node("Panel/LocaleSystem"))
	await process_frame
	check(app.progress.language=="" and app.language==Loc.normalize_locale(OS.get_locale()),"Native follow-system resets override")
	check(Progress.load_data(test_path,12).data.language=="","Follow-system persists empty override")
	app._set_language("en")
	app.queue_free()
	await process_frame
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path=test_path
	app.auth_path=test_path+".auth"
	root.add_child(app)
	check(app.language=="en" and app.progress.language=="en","Restart respects manual language instead of OS locale")
	check(app.progress.completed==expected_completed and app.progress.left_handed and not app.progress.sound,"Restart preserves non-language fields")
	var previous:String=app.language
	check(not app._set_language("not-supported") and app.language==previous,"Unsupported API value rejected without UI mutation")
