extends SceneTree
## Prueba headless del juego real (escena + física Jolt):
##   godot --headless --path . -s res://tests/smoke.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Tuning.reset(false) # valores por defecto, ignora lo guardado desde el panel
	Records.save_path = "user://test_save.cfg" # no pisar los récords reales
	Records.reset()
	await test_moon_airtime()
	await test_recoil_asymmetric()
	await test_headshot()
	await test_body_kill()
	await test_enemy_blocks_gun()
	await test_rests_on_sight()
	await test_ground_lift(0.0)
	await test_ground_lift(PI)
	await test_bounce()
	await test_air_lift()
	await test_game_over_no_ammo()
	test_level_generator()
	test_records()
	await test_game_over_saves_attempt()
	await test_world_streams()
	await test_fall_in_gap()
	await test_stress()
	print("SMOKE OK" if failures == 0 else "SMOKE FAIL (%d)" % failures)
	quit(1 if failures > 0 else 0)


# --- helpers ---

func spawn(level_seed := 1234) -> Node:
	Engine.time_scale = 1.0
	var m: Node = load("res://main.tscn").instantiate()
	m.level_seed = level_seed
	root.add_child(m)
	await physics_frame
	await physics_frame
	return m


func despawn(m: Node) -> void:
	Engine.time_scale = 1.0
	m.queue_free()
	await process_frame


func wait_s(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


## Dispara desde la posición inicial con el cañón en el ángulo dado.
func shoot_from_start(m: Node, a: float) -> void:
	m._idle_angle = a - Config.IDLE_SPIN / float(Engine.physics_ticks_per_second)
	m._queued_shots = 1
	await physics_frame
	await physics_frame


## Pone el arma en juego, quieta, en una pose dada.
func place_gun(m: Node, pos: Vector2, a: float) -> void:
	m.state = m.State.PLAYING
	m.hud.hide_start()
	var g: Gun = m.gun
	g.freeze = false
	g.global_transform = Transform3D(Basis(Vector3.BACK, a), Vector3(pos.x, pos.y, 0))
	g.linear_velocity = Vector3.ZERO
	g.angular_velocity = Vector3.ZERO
	await physics_frame


func aim_angle(m: Node, target: Vector3) -> float:
	var p: Vector3 = m.gun.global_position
	return atan2(target.y - (p.y + Gun.MUZZLE.y), target.x - p.x)


# --- tests ---

func test_moon_airtime() -> void:
	print("vuelo lunar")
	var m := await spawn()
	m.enemies.map(func(e): e.queue_free())
	m.enemies.clear()
	await place_gun(m, Vector2(-3.0, 2.4), -PI / 2.0) # cañón al piso, en el aire
	m._queued_shots = 1
	await physics_frame
	var t0 := Time.get_ticks_msec()
	var peak := 0.0
	while not m.gun.grounded and Time.get_ticks_msec() - t0 < 6000:
		peak = maxf(peak, m.gun.global_position.y)
		await physics_frame
	var airtime := (Time.get_ticks_msec() - t0) / 1000.0
	check(airtime > 2.0, "tiempo en el aire de un salto: %.2fs (antes ~1s)" % airtime)
	check(peak < 9.0, "altura máxima razonable para la cámara: %.1fm" % peak)
	await despawn(m)


func test_recoil_asymmetric() -> void:
	print("retroceso asimétrico")
	var m := await spawn()
	m.enemies.map(func(e): e.queue_free())
	m.enemies.clear()
	await shoot_from_start(m, 0.0) # cañón hacia adelante
	var back_vx: float = m.gun.linear_velocity.x
	await despawn(m)
	m = await spawn()
	await shoot_from_start(m, PI) # cañón hacia atrás
	var fwd_vx: float = m.gun.linear_velocity.x
	var r: float = Tuning.values.recoil_speed
	check(back_vx < -0.5, "disparar adelante empuja atrás (vx=%.2f)" % back_vx)
	check(fwd_vx > r * 0.9, "disparar atrás empuja adelante (vx=%.2f)" % fwd_vx)
	check(absf(back_vx) < fwd_vx * 0.6, "empuje hacia atrás es menor (%.2f vs %.2f)" % [absf(back_vx), fwd_vx])
	check(m.ammo == Config.START_AMMO - 1, "gasta una bala (%d)" % m.ammo)
	await despawn(m)


func test_headshot() -> void:
	print("headshot")
	var m := await spawn()
	var e: Enemy = m.enemies[0]
	await shoot_from_start(m, aim_angle(m, e.global_position + Vector3(0, Enemy.HEAD_Y, 0)))
	check(not e.alive, "personaje muerto")
	check(m.headshots == 1, "cuenta headshot")
	check(m.ammo == Config.START_AMMO - 1 + Config.HEADSHOT_REWARD, "balas +%d (%d)" % [Config.HEADSHOT_REWARD, m.ammo])
	await wait_s(0.2)
	check(Engine.time_scale < 0.5, "slow-mo activo (%.2f)" % Engine.time_scale)
	var y0: float = e.global_position.y
	await wait_s(1.2)
	check(is_equal_approx(Engine.time_scale, 1.0), "slow-mo terminó")
	check(not is_instance_valid(e) or e.global_position.y != y0 or e.rotation.z != 0.0, "el cuerpo se movió (ragdoll)")
	await despawn(m)


func test_body_kill() -> void:
	print("kill al cuerpo")
	var m := await spawn()
	var e: Enemy = m.enemies[0]
	await shoot_from_start(m, aim_angle(m, e.global_position + Vector3(0, 0.8, 0)))
	check(not e.alive, "personaje muerto")
	check(m.headshots == 0, "no es headshot")
	check(m.ammo == Config.START_AMMO - 1 + Config.KILL_REWARD, "balas +%d (%d)" % [Config.KILL_REWARD, m.ammo])
	check(is_equal_approx(Engine.time_scale, 1.0), "sin slow-mo")
	await despawn(m)


func test_enemy_blocks_gun() -> void:
	print("el arma choca con los personajes")
	var m := await spawn()
	var e: Enemy = m.enemies[0]
	# Arma a la altura del pecho, cañón hacia atrás => sale disparada hacia el personaje.
	# Sin lift en el aire, para que vaya derecho al cuerpo y no le pase por arriba.
	Tuning.values.air_lift = 0.0
	await place_gun(m, Vector2(1.5, 1.0), PI)
	m._queued_shots = 1
	await wait_s(1.5)
	var gx: float = m.gun.global_position.x
	Tuning.reset(false)
	check(e.alive, "el personaje sigue vivo")
	check(gx < e.global_position.x, "el arma no lo atravesó (arma x=%.2f, personaje x=%.2f)" % [gx, e.global_position.x])
	await despawn(m)


## Ángulo respecto de la horizontal, en grados (0 = plana).
func tilt_deg(g: Gun) -> float:
	var a := absf(wrapf(g.angle(), -PI / 2.0, PI / 2.0))
	return rad_to_deg(a)


func test_rests_on_sight() -> void:
	print("dada vuelta se apoya en la mirilla (física real, sin enderezado)")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 0.5), PI) # corredera hacia abajo
	await wait_s(3.0)
	var g: Gun = m.gun
	check(g.linear_velocity.length() < 0.3, "quedó quieta (v=%.2f)" % g.linear_velocity.length())
	check(tilt_deg(g) > 2.0, "no queda plana: inclinada %.1f°" % tilt_deg(g))
	check(absf(g.angle()) > PI / 2.0, "sigue dada vuelta, nadie la enderezó (%.0f°)" % rad_to_deg(g.angle()))
	await despawn(m)


func test_ground_lift(start_angle: float) -> void:
	print("disparo apoyada en el piso => lift (ángulo inicial %.0f°)" % rad_to_deg(start_angle))
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 0.5), start_angle)
	await wait_s(3.0)
	var g: Gun = m.gun
	check(g.grounded, "está apoyada")
	m._queued_shots = 1
	await physics_frame
	await physics_frame
	check(g.linear_velocity.y >= Tuning.values.ground_lift * 0.9 and g.linear_velocity.y < Tuning.values.ground_lift * 1.3, "el tiro la levanta (vy=%.2f)" % g.linear_velocity.y)
	await despawn(m)


func test_bounce() -> void:
	print("rebote")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 3.0), 0.0)
	var max_up := 0.0
	var touched := false
	for i in 240:
		await physics_frame
		touched = touched or m.gun.grounded
		if touched:
			max_up = maxf(max_up, m.gun.linear_velocity.y)
	check(max_up > 1.0, "rebota contra el piso (vy máx después del golpe %.2f)" % max_up)
	await despawn(m)


func test_air_lift() -> void:
	print("lift en el aire: todo tiro levanta")
	for a in [0.0, PI, PI / 2.0]: # cañón adelante, atrás y hacia arriba
		var m := await spawn()
		await place_gun(m, Vector2(-3.0, 4.0), a)
		m.gun.linear_velocity = Vector3(0, -8.0, 0) # cayendo
		m._queued_shots = 1
		await physics_frame
		await physics_frame
		var vy: float = m.gun.linear_velocity.y
		check(vy >= Tuning.values.air_lift * 0.9, "cañón a %.0f°, cayendo: el tiro levanta (vy=%.2f)" % [rad_to_deg(a), vy])
		await despawn(m)


func test_game_over_no_ammo() -> void:
	print("game over sin balas")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 0.6), 0.0)
	m.ammo = 0
	await wait_s(4.0)
	check(m.state == m.State.OVER, "terminó la partida")
	await despawn(m)


func test_stress() -> void:
	print("estrés: 120 disparos")
	var m := await spawn()
	m.ammo = 9999
	var ok := true
	for i in 120:
		m._queued_shots = 1
		await wait_s(0.12)
		if m.state == m.State.OVER:
			break
		var p: Vector3 = m.gun.global_position
		var blk := Level.block_at(m.blocks, p.x)
		var floor_y: float = blk.top if not blk.is_empty() else -INF # en un hueco puede caer
		if not p.is_finite() or p.y < floor_y - 0.3:
			ok = false
			print("    pos rara: ", p, " piso ", floor_y)
			break
	check(ok, "sin NaN ni atravesar el piso (distancia %dm)" % m.distance)
	await despawn(m)


func test_level_generator() -> void:
	print("generador del piso")
	var lv := Level.new(7)
	var bs := []
	while bs.is_empty() or bs[-1].x1 < 3000.0:
		bs.append(lv.next_block())
	var gaps := 0
	var max_gap := 0.0
	var max_up := 0.0
	var max_down := 0.0
	var heights := {}
	var enemy_xs := []
	var types := {}
	var specials := {}
	for i in bs.size():
		var b: Dictionary = bs[i]
		heights[snappedf(b.top, 0.5)] = true
		specials[b.special] = true
		for it in b.items:
			types[it.type] = types.get(it.type, 0) + 1
			if it.type in ["hawk", "bat", "ammo"]:
				if it.y < b.top + 1.0 and b.special != "air":
					check(false, "bicho volador metido en el piso en x=%.1f" % it.x)
				continue
			enemy_xs.append(it.x)
			if it.x < b.x0 + 0.5 or it.x > b.x1 - 0.5 or it.y != b.top:
				check(false, "%s fuera del bloque en x=%.1f" % [it.type, it.x])
		if i > 0 and b.special == "" and bs[i - 1].special == "": # el piso normal
			var gap: float = b.x0 - bs[i - 1].x1
			if gap > 0.01:
				gaps += 1
			max_gap = maxf(max_gap, gap)
			max_up = maxf(max_up, b.top - bs[i - 1].top)
			max_down = maxf(max_down, bs[i - 1].top - b.top)
	var b0: Dictionary = bs[0]
	check(b0.top == 0.0 and b0.items.map(func(it): return it.x) == Level.ENEMY_XS and b0.items.all(func(it): return it.type == "plain"), "el arranque es fijo: piso plano y los 3 personajes")
	check(bs[1].x0 == b0.x1, "no hay hueco pegado al arranque")
	check(gaps > 50, "hay huecos (%d en 3km)" % gaps)
	check(max_gap <= Level.GAP_LEN.y + Level.GAP_RAMP_MAX + 0.01, "huecos cruzables (máx %.1fm)" % max_gap)
	check(heights.size() >= 20, "alturas variadas (%d niveles distintos)" % heights.size())
	check(max_up <= Level.MAX_STEP_UP + 0.01, "paredes trepables (máx %.1fm)" % max_up)
	check(max_down <= Level.MAX_STEP_DOWN + 0.01, "bajadas acotadas (máx %.1fm)" % max_down)
	var min_sep := INF
	for i in range(1, enemy_xs.size()):
		min_sep = minf(min_sep, enemy_xs[i] - enemy_xs[i - 1])
	check(enemy_xs.size() > 150, "personajes infinitos (%d en 3km)" % enemy_xs.size())
	check(min_sep >= 2.0, "espaciados (mínimo %.1fm entre dos)" % min_sep)
	for t in ["plain", "sword", "shield", "helmet", "chest", "trap", "spring", "hawk", "bat", "ammo"]:
		check(types.get(t, 0) > 0, "aparece %s (%d)" % [t, types.get(t, 0)])
	check(types.get("trap", 0) < types.get("chest", 0), "trampas: menos que cofres (%d de %d)" % [types.get("trap", 0), types.get("chest", 0) + types.get("trap", 0)])
	for sp in Level.SPECIALS:
		check(specials.has(sp), "aparece el nivel %s" % sp)
	var other := Level.new(99)
	other.next_block()
	var lv2 := Level.new(99)
	lv2.next_block()
	check(other.next_block().top == lv2.next_block().top, "misma semilla => mismo piso")


func test_world_streams() -> void:
	print("el mundo se genera adelante y se libera atrás")
	var m := await spawn()
	var start_blocks: int = m.blocks.size()
	await place_gun(m, Vector2(500.0, 8.0), 0.0)
	await process_frame
	await process_frame
	var last: Dictionary = m.blocks[-1]
	check(last.x1 > 500.0 + m.GEN_AHEAD - 1.0, "hay piso generado por delante (hasta x=%.0f)" % last.x1)
	check(m.blocks[0].x1 > 500.0 - m.KEEP_BEHIND - 15.0, "lo de atrás se liberó (primer bloque termina en x=%.0f)" % m.blocks[0].x1)
	check(m.blocks.size() < 40, "cantidad de bloques acotada (%d)" % m.blocks.size())
	var ahead := 0
	for e in m.enemies:
		if is_instance_valid(e) and e.global_position.x > 500.0:
			ahead += 1
	check(ahead >= 3, "hay personajes por delante (%d)" % ahead)
	await despawn(m)


func test_fall_in_gap() -> void:
	print("caer en un hueco => game over")
	var m := await spawn()
	var gap_x := 0.0
	for i in range(1, m.blocks.size()):
		if m.blocks[i].x0 - m.blocks[i - 1].x1 > 1.0:
			gap_x = (m.blocks[i].x0 + m.blocks[i - 1].x1) / 2.0
			break
	check(gap_x > 0.0, "hay un hueco cerca del arranque (x=%.1f)" % gap_x)
	await place_gun(m, Vector2(gap_x, 3.0), -PI / 2.0)
	await wait_s(4.0)
	check(m.state == m.State.OVER, "terminó la partida al caer")
	await despawn(m)


func test_records() -> void:
	print("récords y leaderboard")
	Records.reset()
	var r1 := Records.add({"dist": 100, "height": 5, "ammo": 9, "kills": 1, "headshots": 0})
	var r2 := Records.add({"dist": 300, "height": 3, "ammo": 7, "kills": 2, "headshots": 1})
	var r3 := Records.add({"dist": 50, "height": 12, "ammo": 4, "kills": 0, "headshots": 0})
	check(r1.rank == 1 and r2.rank == 1 and r3.rank == 3, "rank por distancia (%d, %d, %d)" % [r1.rank, r2.rank, r3.rank])
	check(Records.attempts.map(func(a): return a.dist) == [300, 100, 50], "leaderboard ordenado por distancia")
	check(Records.best.dist == 300 and Records.best.height == 12 and Records.best.ammo == 9, "récords por separado: dist 300, altura 12, balas 9")
	check(r3.new.height and not r3.new.dist and not r3.new.ammo, "marca solo el récord nuevo (altura)")
	Records.load_saved(true)
	check(Records.attempts.size() == 3 and Records.best.height == 12, "persiste en disco")
	for i in 30:
		Records.add({"dist": i, "height": 0, "ammo": 0, "kills": 0, "headshots": 0})
	check(Records.attempts.size() == Records.MAX_ATTEMPTS, "guarda como máximo %d intentos" % Records.MAX_ATTEMPTS)
	check(Records.best.dist == 300, "el récord no se pierde al recortar la lista")
	Records.reset()


func test_game_over_saves_attempt() -> void:
	print("game over guarda el intento")
	Records.reset()
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 6.0), 0.0)
	m.ammo = 0
	m.max_ammo = 8
	await wait_s(7.0) # rebota un rato; a los 6 s sin balas termina igual
	check(m.state == m.State.OVER, "terminó la partida")
	check(Records.attempts.size() == 1, "quedó guardado")
	var a: Dictionary = Records.attempts[0] if Records.attempts.size() > 0 else {}
	check(a.get("height", 0) >= 5, "altura máxima registrada (%dm)" % a.get("height", 0))
	check(a.get("ammo", 0) == 8, "balas máximas registradas (%d)" % a.get("ammo", 0))
	check(m.hud._over.visible and m.hud._over_board.get_child_count() >= 8, "game over muestra el leaderboard")
	await despawn(m)
	Records.reset()
