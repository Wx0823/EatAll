extends SceneTree
const Rules=preload("res://scripts/rules.gd")
var app:Control
var checks:=0
var failures:=0
func _initialize()->void: call_deferred("run")
func pts(raw:Array)->Array:
	var a:Array=[]
	for p in raw: a.append(Vector2i(p[0],p[1]))
	return a
func fixture(food:Array,spikes:Array=[])->Dictionary:
	return {"id":901,"title":"QA falling food","hint":"isolated fixture","width":8,"height":8,"body":pts([[2,2],[1,2],[0,2]]),"terrain":pts([[0,3],[3,6]]),"fruit":pts(food),"hazards":pts(spikes),"exit":Vector2i(7,1)}
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(note)
func pending(state:Dictionary)->int: return int(state.get("growth_pending",0))
func run()->void:
	var level:=fixture([[3,3],[3,5]])
	var original:Dictionary=Rules.initial_state(level)
	check(original.has("growth_pending") and pending(original)==0,"Initial state explicitly starts with zero pending growth")
	var before:Dictionary=original.duplicate(true)
	var fall:Dictionary=Rules.step(level,original,Vector2i.RIGHT)
	check(fall.valid and fall.fell==3,"Fixture falls three rows until real terrain")
	check(fall.ate and not fall.get("active_ate",true),"Fall food contributes total ate but not active_ate")
	check(fall.state.fruit.is_empty() and pending(fall.state)==2,"Both safe head-crossed fruits consumed with pending growth")
	check(fall.state.body.size()==3,"Rigid fall does not stretch or append body segments")
	check(fall.frames[1].fruit.size()==1 and pending(fall.frames[1])==1,"First safe fall row consumes immediately")
	check(fall.frames[2].fruit.size()==1 and pending(fall.frames[2])==1,"Empty middle row does not duplicate eating")
	var events:Array=fall.get("eat_events",[])
	check(events.size()==2,"One event per actually consumed fruit")
	if events.size()==2:
		check(events[0].frame==1 and events[0].cell==Vector2i(3,3) and events[0].direction==Vector2i.DOWN,"First fall event has exact frame/cell/down direction")
		check(events[1].frame==3 and events[1].cell==Vector2i(3,5),"Second fall event has exact later row")
	check(original==before,"Rules do not mutate input snapshot")
	var continued:Dictionary=Rules.step(level,fall.state,Vector2i.RIGHT)
	check(continued.valid and continued.state.body.size()==4 and pending(continued.state)==1,"Next active step pays one pending growth")
	var simultaneous:Dictionary=fall.state.duplicate(true)
	simultaneous.fruit.append(Vector2i(4,5))
	var active:Dictionary=Rules.step(level,simultaneous,Vector2i.RIGHT)
	check(active.valid and active.get("active_ate",false) and active.state.body.size()==4 and pending(active.state)==2,"Active food plus existing debt grows at most one and preserves the rest")
	check(active.get("eat_events",[]).size()==1 and active.eat_events[0].frame==0,"Active food event is frame zero")
	var danger_level:=fixture([[3,3]],[[1,3]])
	var danger:Dictionary=Rules.step(danger_level,Rules.initial_state(danger_level),Vector2i.RIGHT)
	check(danger.state.status=="lost" and danger.reason=="spike","Tail spike on same row triggers loss")
	check(danger.state.fruit.size()==1 and pending(danger.state)==0 and not danger.ate,"Danger wins over simultaneous head-food contact")
	check(danger.get("eat_events",[]).is_empty(),"Danger row emits no eating event")
	var scrape_level:=fixture([[2,3]])
	var scrape:Dictionary=Rules.step(scrape_level,Rules.initial_state(scrape_level),Vector2i.RIGHT)
	check(scrape.state.fruit.size()==1 and not scrape.ate,"Body-only fruit scrape does not consume")
	var pass_level:=fixture([[3,3]])
	pass_level.exit=Vector2i(3,3)
	var passing:Dictionary=Rules.step(pass_level,Rules.initial_state(pass_level),Vector2i.RIGHT)
	check(passing.state.status=="playing" and passing.state.body[0]==Vector2i(3,5),"Collected fruit and crossed exit do not win before stable landing")
	var loop:Dictionary={"id":902,"width":8,"height":8,"body":pts([[2,3],[2,2],[1,2],[1,3]]),"terrain":pts([[1,4],[2,4]]),"fruit":[],"hazards":[],"exit":Vector2i(7,1)}
	var debt:Dictionary=Rules.initial_state(loop)
	debt.growth_pending=1
	var old_tail:Dictionary=Rules.step(loop,debt,Vector2i.LEFT)
	check(not old_tail.valid and old_tail.reason=="body" and old_tail.state==debt,"Pending growth retains old tail and blocks entering it")
	var levels:Array=Rules.load_levels()
	var current:Dictionary=Rules.initial_state(levels[11])
	var dirs={"R":Vector2i.RIGHT,"L":Vector2i.LEFT,"U":Vector2i.UP,"D":Vector2i.DOWN}
	for letter in "RRDRR":
		var result:Dictionary=Rules.step(levels[11],current,dirs[letter])
		check(result.valid,"Actual L12 RRDRR reproduction step valid")
		current=result.state
	check(not current.fruit.has(Vector2i(6,6)),"Actual L12 fifth-step fall consumes fruit at6,6")
	check(current.fruit.size()==1 and current.body.size()+pending(current)==5,"L12 two collected food units conserved as body plus pending")
	app=load("res://main.tscn").instantiate()
	app.qa_mode=true
	app.save_path="user://qa/fall-food.json"
	root.add_child(app)
	app.auth.login_guest()
	app.set_process(false)
	app.audio.enabled=false
	app.skip_animations=true
	app.start_level(11)
	for letter in "RRDR": check(app.try_move(dirs[letter]),"UI setup move")
	var prefall:Dictionary=app.state.duplicate(true)
	app.skip_animations=false
	check(app.try_move(Vector2i.RIGHT),"UI accepts reproduction fall")
	app._process(2.0)
	check(app.state.fruit.size()==1 and pending(app.state)==1,"Long delta resolves fall eating once")
	for i in range(5):app._process(0.5)
	check(app.state.fruit.size()==1 and pending(app.state)==1,"Later idle frames do not duplicate pending growth")
	app.undo()
	check(app.state==prefall,"Undo restores body, food, moves and pending together")
	check(app.try_move(Vector2i.RIGHT),"Re-eat after undo is accepted")
	app._process(0.20)
	app.pause_game()
	check(app.state.fruit.size()==1 and pending(app.state)==1,"Pause midway settles each food once")
	for i in range(5):app._process(1.0)
	check(pending(app.state)==1,"Paused callbacks do not repeat consumption")
	app._close_overlay()
	app.undo()
	check(app.state==prefall,"Undo after paused fall restores exact prefall state")
	app.levels.append(level)
	app.start_level(app.levels.size()-1)
	app.set_process(false)
	app.skip_animations=false
	check(app.try_move(Vector2i.RIGHT),"Two-food animation fixture accepted")
	app._process(0.273)
	print("MULTI_FOOD_CONTACT mouth=",app.board.mouth_animation," cursor=",app.animation_food_cursor," visible_fruit=",app.board.state.fruit.size())
	check(app.board.mouth_animation=="swallow", "First fall-food swallow must not be overwritten immediately by next-food anticipation")
	app.board._process(0.06)
	app._process(0.06)
	check(app.board.mouth_animation=="swallow" and app.board._food_source_grid==Vector2(3,3),"Next anticipation window keeps first food source until actual next contact")
	app._process(0.023)
	check(app.board.mouth_animation=="swallow" and app.board._food_source_grid==Vector2(3,5),"Actual second contact switches source and starts second swallow")
	check(app.state.fruit.is_empty() and pending(app.state)==2,"Second contact consumes exactly the second pending growth unit")
	print("FALL_FOOD_QA checks=",checks," failures=",failures)
	app.queue_free()
	quit(0 if failures==0 else 1)
