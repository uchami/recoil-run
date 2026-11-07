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
	await test_sounds()
	await test_shield_and_helmet()
	await test_sword()
	await test_spring()
	await test_sky_spawner()
	await test_altitude_zones()
	await test_plane()
	await test_rocket()
	await test_bat()
	await test_hawk()
	await test_chest()
	await test_safe_chests()
	await test_trap_chest()
	await test_power_streak()
	await test_powers()
	await test_hurt_without_ammo()
	await test_special_levels()
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
	check(gaps > 30, "hay huecos (%d en 3km)" % gaps)
	check(max_gap <= Level.GAP_LEN.y + Level.GAP_RAMP_MAX + 0.01, "huecos cruzables (máx %.1fm)" % max_gap)
	check(heights.size() >= 20, "alturas variadas (%d niveles distintos)" % heights.size())
	check(max_up <= Level.MAX_STEP_UP + 0.01, "paredes trepables (máx %.1fm)" % max_up)
	check(max_down <= Level.MAX_STEP_DOWN + 0.01, "bajadas acotadas (máx %.1fm)" % max_down)
	var min_sep := INF
	for i in range(1, enemy_xs.size()):
		min_sep = minf(min_sep, enemy_xs[i] - enemy_xs[i - 1])
	check(enemy_xs.size() > 150, "personajes infinitos (%d en 3km)" % enemy_xs.size())
	check(min_sep >= 2.0, "espaciados (mínimo %.1fm entre dos)" % min_sep)
	for t in ["plain", "sword", "shield", "helmet", "chest", "trap", "spring", "bat", "ammo"]:
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


# --- mecánicas nuevas ---

func clear_world(m: Node) -> void:
	for e in m.enemies + m.entities:
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	m.entities.clear()


func put(m: Node, type: String, x: float, y := 0.0) -> Node:
	m._spawn_item({"type": type, "x": x, "y": y})
	if type in ["plain", "sword", "shield", "helmet"]:
		return m.enemies[-1]
	return m.entities[-1]


## Pone el arma quieta en pos apuntando a target y dispara en el mismo paso.
func fire_at(m: Node, pos: Vector2, target: Vector3) -> void:
	if m.state != m.State.PLAYING:
		await place_gun(m, pos, 0.0)
	var g: Gun = m.gun
	var a := atan2(target.y - (pos.y + Gun.MUZZLE.y), target.x - pos.x)
	g.global_transform = Transform3D(Basis(Vector3.BACK, a), Vector3(pos.x, pos.y, 0))
	g.linear_velocity = Vector3.ZERO
	g.angular_velocity = Vector3.ZERO
	m._queued_shots = 1
	await physics_frame
	await physics_frame


func test_sounds() -> void:
	print("sonidos")
	var m := await spawn()
	check(m.sfx._streams.size() == Sfx.NAMES.size(), "cargan todos los sonidos (%d/%d)" % [m.sfx._streams.size(), Sfx.NAMES.size()])
	await shoot_from_start(m, 0.0)
	check("shot" in m.sfx.played, "suena el disparo")
	await despawn(m)


func test_shield_and_helmet() -> void:
	print("escudo y casco")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var e: Enemy = put(m, "shield", 4.0)
	await physics_frame
	await fire_at(m, Vector2(-1.0, 0.9), e.global_position + Vector3(0, 0.8, 0))
	check(e.alive, "escudo: el tiro al torso rebota")
	check("clank" in m.sfx.played, "suena clank")
	await fire_at(m, Vector2(-1.0, 1.7), e.global_position + Vector3(0, Enemy.HEAD_Y, 0))
	check(not e.alive and m.headshots == 1, "escudo: a la cabeza lo mata (headshot)")
	await despawn(m)

	m = await spawn()
	clear_world(m)
	await physics_frame
	e = put(m, "helmet", 4.0)
	await physics_frame
	await fire_at(m, Vector2(-1.0, 1.7), e.global_position + Vector3(0, Enemy.HEAD_Y, 0))
	check(e.alive, "casco: el tiro a la cabeza rebota")
	await fire_at(m, Vector2(-1.0, 0.9), e.global_position + Vector3(0, 0.8, 0))
	check(not e.alive and m.headshots == 0, "casco: al torso lo mata")
	await despawn(m)


func test_sword() -> void:
	print("espadachín")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var e: Enemy = put(m, "sword", 4.0)
	m.ammo = 5
	await place_gun(m, Vector2(3.0, 0.6), 0.0) # al lado del espadachín
	var t0 := Time.get_ticks_msec()
	while m.ammo == 5 and Time.get_ticks_msec() - t0 < 1500:
		await physics_frame
	check(m.ammo == 4, "te pega: -1 bala (%d)" % m.ammo)
	await physics_frame
	await physics_frame
	check(m.gun.linear_velocity.x < -1.0, "te empuja lejos (vx=%.1f)" % m.gun.linear_velocity.x)
	check("hurt" in m.sfx.played, "suena el golpe")
	await despawn(m)


func test_spring() -> void:
	print("resorte vertical")
	var res := []
	for speed in [3.0, 9.0]:
		var m := await spawn()
		clear_world(m)
		await physics_frame
		put(m, "spring", 4.0)
		await place_gun(m, Vector2(1.0, 1.3), 0.0)
		m.gun.linear_velocity = Vector3(speed, 0.0, 0.0)
		var min_vx := 0.0
		var max_spin := -1.0
		for i in 90:
			await physics_frame
			min_vx = minf(min_vx, m.gun.linear_velocity.x)
			if max_spin < 0.0 and m.gun.linear_velocity.x < -1.0: # justo después del choque
				max_spin = absf(m.gun.angular_velocity.z)
		check(min_vx < -Config.SPRING_BASE_PUSH, "choque a %.0f m/s: te devuelve (vx=%.1f)" % [speed, min_vx])
		check(m.gun.global_position.x < 3.0, "no lo atravesás (x=%.1f)" % m.gun.global_position.x)
		res.append([min_vx, max_spin])
		await despawn(m)
	check(res[1][0] < res[0][0] - 3.0, "choque fuerte empuja más (%.1f vs %.1f)" % [res[1][0], res[0][0]])
	check(res[1][1] > res[0][1] + 3.0, "choque fuerte te hace girar más (%.1f vs %.1f rad/s)" % [res[1][1], res[0][1]])


func test_sky_spawner() -> void:
	print("bichos a cualquier altura")
	var m := await spawn()
	clear_world(m)
	await place_gun(m, Vector2(0.0, 30.0), 0.0)
	var ys := []
	for i in 400: # vuela hacia adelante a 30 m de altura
		m.gun.global_position = Vector3(i * 0.25, 30.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await process_frame
	for n in m.entities:
		if is_instance_valid(n) and (n is Flyer or n is Airplane or n is Rocket):
			ys.append(n.global_position.y)
	check(ys.size() >= 4, "aparecen bichos mientras avanzás (%d en 100 m)" % ys.size())
	check(ys.all(func(y): return y > 25.0), "a tu altura, no en el piso (%s)" % str(ys.map(func(y): return snappedf(y, 0.1))))
	await despawn(m)


func test_bat() -> void:
	print("murciélago")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var b: Flyer = put(m, "bat", 0.0, 4.0)
	m.ammo = 5
	await place_gun(m, Vector2(b.global_position.x, b.global_position.y), 0.0)
	for i in 30: # lo seguimos hasta chocarlo (revolotea)
		if not b.alive:
			break
		m.gun.global_position = b.global_position
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.ammo == 4, "si te choca: -1 bala (%d)" % m.ammo)
	check(not b.alive, "y se muere")
	await despawn(m)
	m = await spawn()
	clear_world(m)
	await physics_frame
	b = put(m, "bat", 5.0, 3.0)
	await physics_frame
	await fire_at(m, Vector2(0.0, 3.0), b.global_position)
	check(not b.alive, "se lo puede matar de un tiro")
	check(m.ammo == Config.START_AMMO - 1 + Config.FLYER_REWARD, "da +%d" % Config.FLYER_REWARD)
	await despawn(m)


func test_hawk() -> void:
	print("halcón")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var h: Flyer = put(m, "hawk", 8.0, 6.0)
	await place_gun(m, Vector2(0.0, 2.0), 0.0)
	await physics_frame
	var seen: Vector3 = m.gun.global_position
	await wait_s(0.5)
	check(h._dir != Vector3.ZERO, "te ve y arranca")
	var dir: Vector3 = h._dir
	var expected := Vector3(seen.x - 8.0, seen.y - 6.0, 0).normalized()
	check(dir.dot(expected) > 0.97, "va hacia donde te vio (dot %.2f)" % dir.dot(expected))
	var p0 := h.global_position
	await wait_s(1.0)
	var v := (h.global_position - p0).length()
	check(v < Config.HAWK_SPEED * 1.3 and v > Config.HAWK_SPEED * 0.6, "lento (%.1f m/s)" % v)
	await despawn(m)
	# golpe: -1 bala y te hace girar
	m = await spawn()
	clear_world(m)
	await physics_frame
	h = put(m, "hawk", 2.0, 3.0)
	m.ammo = 5
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var spun := 0.0
	var t0 := Time.get_ticks_msec()
	while m.ammo == 5 and Time.get_ticks_msec() - t0 < 2500:
		m.gun.global_position = Vector3(0.0, 3.0, 0.0) # lo esperamos quietos
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	await physics_frame
	await physics_frame
	spun = absf(m.gun.angular_velocity.z)
	check(m.ammo == 4, "si te toca: -1 bala (%d)" % m.ammo)
	check(spun > Config.HAWK_SPIN * 0.5, "te hace girar (%.1f rad/s)" % spun)
	await despawn(m)


func test_chest() -> void:
	print("cofre")
	var outcomes := {"balas": 0, "poder": 0}
	for k in 8:
		var m := await spawn()
		clear_world(m)
		await physics_frame
		var c: Chest = put(m, "chest", 6.0)
		await physics_frame
		var center := c.global_position + Vector3(0, Chest.world_size().y * 0.5, 0)
		var before := 0
		for i in Config.CHEST_AMMO:
			if i == Config.CHEST_AMMO - 1:
				before = m.ammo - 1
				m.last_power = ""
			await fire_at(m, Vector2(-1.0, 1.5), center)
			if i == 0 and k == 0:
				check(c.ammo == Config.CHEST_AMMO - 1, "cada tiro le saca una bala (%d)" % c.ammo)
		if k == 0:
			check(c.ammo == 0, "muere con %d tiros" % Config.CHEST_AMMO)
			check(not m.entities.any(func(n): return is_instance_valid(n) and n is Mimic), "no es trampa")
			check(Chest.world_size().x >= 4.9, "es grande (%.1f m de ancho)" % Chest.world_size().x)
		if m.last_power != "":
			outcomes.poder += 1
		elif m.ammo == before + Config.CHEST_REWARD:
			outcomes.balas += 1
		Engine.time_scale = 1.0
		await despawn(m)
	check(outcomes.balas + outcomes.poder == 8, "siempre da algo: %s" % str(outcomes))
	check(outcomes.balas > 0 and outcomes.poder > 0, "a veces balas, a veces poder")


func test_safe_chests() -> void:
	print("los primeros %d cofres nunca son trampa" % Config.SAFE_CHESTS)
	Records.reset()
	var mimics := 0
	for k in Config.SAFE_CHESTS + 1:
		var m := await spawn()
		clear_world(m)
		await physics_frame
		var c: Chest = put(m, "trap", 6.0) # todos trampa...
		await physics_frame
		var center := c.global_position + Vector3(0, Chest.world_size().y * 0.5, 0)
		for i in Config.CHEST_AMMO:
			await fire_at(m, Vector2(-1.0, 1.5), center)
		await physics_frame
		var opened: bool = m.entities.any(func(n): return is_instance_valid(n) and n is Mimic)
		if k < Config.SAFE_CHESTS:
			mimics += 1 if opened else 0
		else:
			check(opened, "el cofre nº %d ya puede ser trampa" % (k + 1))
		Engine.time_scale = 1.0
		await despawn(m)
	check(mimics == 0, "...pero los primeros %d no muerden (%d mordieron)" % [Config.SAFE_CHESTS, mimics])
	check(Records.stat("chests_killed") == Config.SAFE_CHESTS + 1, "cuenta guardada en el teléfono (%d)" % Records.stat("chests_killed"))
	Records.load_saved(true)
	check(Records.stat("chests_killed") == Config.SAFE_CHESTS + 1, "y sobrevive a reiniciar el juego")
	Records.reset()


func test_trap_chest() -> void:
	print("cofre trampa")
	Records.stats["chests_killed"] = Config.SAFE_CHESTS # ya mató los primeros
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var c: Chest = put(m, "trap", 8.0)
	await physics_frame
	var center := c.global_position + Vector3(0, Chest.world_size().y * 0.5, 0)
	for i in Config.CHEST_AMMO:
		await fire_at(m, Vector2(-1.0, 1.5), center)
	await physics_frame
	var mimics: Array = m.entities.filter(func(n): return is_instance_valid(n) and n is Mimic)
	check(mimics.size() == 1, "al morir abre la boca (mimic)")
	if mimics.is_empty():
		await despawn(m)
		return
	var mm: Mimic = mimics[0]
	check(mm.ammo == Config.MIMIC_AMMO, "vuelve con %d balas" % mm.ammo)
	var d0: float = mm.global_position.distance_to(m.gun.global_position)
	m.ammo = 6
	var hold: Vector3 = m.gun.global_position
	for i in 120: # 1 s con el arma quieta
		m.gun.global_position = hold
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	var d1: float = mm.global_position.distance_to(m.gun.global_position)
	check(d1 < d0 - Config.MIMIC_SPEED * 0.7 or m.ammo < 6, "te persigue (%.1f -> %.1f m)" % [d0, d1])
	var t0 := Time.get_ticks_msec()
	while m.ammo == 6 and Time.get_ticks_msec() - t0 < 4000:
		await physics_frame
	check(m.ammo == 6 - Config.MIMIC_DAMAGE, "si te toca: -%d balas (%d)" % [Config.MIMIC_DAMAGE, m.ammo])
	# matarlo: 2 tiros, te da 5
	m.ammo = 10
	m._hurt_cd = 99.0
	for i in Config.MIMIC_AMMO:
		await fire_at(m, Vector2(-6.0, 1.5), mm.global_position + Vector3(0, 1.5, 0))
	check(not mm.alive, "muere con %d tiros" % Config.MIMIC_AMMO)
	check(m.ammo == 10 - Config.MIMIC_AMMO + Config.MIMIC_REWARD, "te da %d balas (%d)" % [Config.MIMIC_REWARD, m.ammo])
	await despawn(m)


## Dispara una secuencia: "h" = headshot, "b" = kill al cuerpo, "m" = tiro errado.
## Devuelve en qué tiro (1-based) se aplicó un poder, o 0.
func shoot_sequence(seq: String) -> int:
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var got := 0
	for i in seq.length():
		var k := seq[i]
		m.last_power = ""
		if k == "m":
			await fire_at(m, Vector2(0.0, 3.0), Vector3(10.0, 12.0, 0.0)) # al cielo
		else:
			var e: Enemy = put(m, "plain", 4.0 + i * 1.2)
			await physics_frame
			var target := e.global_position + (Vector3(0, Enemy.HEAD_Y, 0) if k == "h" else Vector3(0, 0.7, 0))
			await fire_at(m, Vector2(0.0, target.y), target)
		Engine.time_scale = 1.0
		m._slowmo_left = 0.0
		if m.last_power != "" and got == 0:
			got = i + 1
	await despawn(m)
	return got


func test_power_streak() -> void:
	print("rachas => poder automático")
	check(await shoot_sequence("hhh") == 3, "3 headshots seguidos: poder al 3º")
	check(await shoot_sequence("hmhmh") == 5, "la racha de headshots perdona los tiros errados")
	check(await shoot_sequence("hbmhh") == 0, "un kill al cuerpo corta la racha de headshots")
	check(await shoot_sequence("bbb") == 3, "3 kills en 3 tiros: poder al 3º")
	check(await shoot_sequence("bbmb") == 0, "la racha de kills no perdona los errados")
	check(await shoot_sequence("hhhhh") == 3, "al dar un poder se reinician las rachas (no da otro al 4º/5º)")
	var m := await spawn()
	check(m.entities.all(func(n): return not (is_instance_valid(n) and n is Pickup)), "no hay que recogerlo: se aplica solo")
	await despawn(m)


func test_powers() -> void:
	print("poderes")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 3.0), 0.0)
	m.ammo = 2
	m._activate_power("infinite", Vector3.ZERO)
	for i in 4:
		m._queued_shots = 1
		await physics_frame
	check(m.ammo == 2, "balas infinitas: no gasta (%d)" % m.ammo)
	m._activate_power("laser", Vector3.ZERO)
	await process_frame
	await process_frame
	check(m._laser.visible, "láser visible")
	var a: int = m.ammo
	m._activate_power("ammo15", Vector3.ZERO)
	check(m.ammo == a + 15, "+15 balas")
	m._activate_power("untouchable", Vector3.ZERO)
	var b: int = m.ammo
	m._hurt_cd = 0.0
	m.hurt(2, Vector3.ZERO)
	check(m.ammo == b, "intocable: no te sacan balas")
	m.powers.infinite = 0.01
	await wait_s(0.1)
	check(not m.power_on("infinite"), "los poderes se terminan")
	await despawn(m)


func test_hurt_without_ammo() -> void:
	print("golpe sin balas = muerte")
	var m := await spawn()
	await place_gun(m, Vector2(-3.0, 3.0), 0.0)
	m.ammo = 1
	m.hurt(1, Vector3.ZERO)
	check(m.ammo == 0 and m.state == m.State.PLAYING, "con 1 bala: quedás en 0 pero vivo")
	m._hurt_cd = 0.0
	m.hurt(1, Vector3.ZERO)
	check(m.state == m.State.OVER, "sin balas: el golpe te mata")
	await despawn(m)


func test_special_levels() -> void:
	print("niveles especiales")
	for sp in ["stairs_down", "stairs_up", "air"]:
		var lv := Level.new(5, sp)
		var bs := [lv.next_block()]
		while bs[-1].x1 < 400.0:
			bs.append(lv.next_block())
		var sb := bs.filter(func(b): return b.special == sp)
		check(sb.size() > 0, "%s arranca apenas termina el arranque" % sp)
		if sp == "air":
			var gap: float = sb[0].x0 - bs[0].x1
			check(gap >= Level.AIR_LEN - 15.0, "aéreo: %.0fm sin piso" % gap)
			check(absf(sb[0].top - bs[0].top) < 0.01, "aéreo: salida a la misma altura")
			check(sb[0].items.filter(func(it): return it.type == "ammo").size() > 15, "aéreo: balas flotando")
			continue
		var length: float = sb[-1].x1 - sb[0].x0
		var dh: float = sb[-1].top - bs[0].top
		check(length >= Level.STAIRS_LEN - 10.0, "%s: %.0fm de largo" % [sp, length])
		check(dh < -40.0 if sp == "stairs_down" else dh > 40.0, "%s: cambio de altura %.0fm" % [sp, dh])
		var gaps := 0
		for i in range(1, sb.size()):
			if sb[i].x0 - sb[i - 1].x1 > 0.5:
				gaps += 1
		check(gaps > 5, "%s: con huecos (%d)" % [sp, gaps])
		# el piso normal sigue alrededor de la nueva altura
		var after := bs.filter(func(b): return b.special == "" and b.x0 >= sb[-1].x1)
		if not after.is_empty():
			check(absf(after[0].top - sb[-1].top) <= Level.MAX_STEP_DOWN + 0.1, "%s: después sigue desde esa altura (%.1f -> %.1f)" % [sp, sb[-1].top, after[0].top])
	# probar nivel desde AJUSTES
	Level.debug_special = "air"
	var m := await spawn()
	check(m.level.special == "" and m.blocks.size() >= 2 and m.blocks[1].special == "air", "PROBAR NIVEL arranca con ese nivel")
	check(Level.debug_special == "", "y vale para una sola partida")
	await despawn(m)


func test_altitude_zones() -> void:
	print("zonas por altura")
	var m := await spawn()
	var counts := {}
	for alt in [5.0, 30.0, 60.0]:
		var c := {}
		for i in 400:
			var t: String = m.sky_type(alt)
			c[t] = c.get(t, 0) + 1
		counts[alt] = c
	check(counts[5.0].keys().all(func(k): return k in ["hawk", "bat"]), "abajo: halcones y murciélagos %s" % str(counts[5.0]))
	check(counts[30.0].has("plane") and counts[30.0].has("hawk") and not counts[30.0].has("rocket"), "alto: aviones con halcones %s" % str(counts[30.0]))
	check(counts[60.0].has("rocket") and counts[60.0].has("plane") and not counts[60.0].has("hawk") and not counts[60.0].has("bat"), "más alto: cohetes con aviones, sin pájaros %s" % str(counts[60.0]))
	# cielo de noche
	await place_gun(m, Vector2(0.0, 2.0), 0.0)
	await wait_s(0.3)
	check(m.space_t < 0.05, "abajo el cielo es violeta (%.2f)" % m.space_t)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		m.gun.global_position = Vector3(0.0, Config.ROCKET_ALT + 10.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await process_frame
	check(m.space_t > 0.9, "arriba de todo: negro con estrellas (%.2f)" % m.space_t)
	check(m.camera.get_node("Stars").visible, "se ven las estrellas")
	await despawn(m)


func test_plane() -> void:
	print("avión")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var pl: Airplane = put(m, "plane", 12.0, 3.0)
	m.ammo = 10
	m._hurt_cd = 99.0
	for i in Config.PLANE_AMMO:
		await fire_at(m, Vector2(0.0, 3.0), pl.global_position)
	check(not pl.alive, "lo derribás con %d tiros" % Config.PLANE_AMMO)
	check(m.ammo == 10 - Config.PLANE_AMMO + Config.PLANE_REWARD, "te da %d balas (%d)" % [Config.PLANE_REWARD, m.ammo])
	check("explosion" in m.sfx.played, "explota")
	await despawn(m)
	m = await spawn()
	clear_world(m)
	await physics_frame
	pl = put(m, "plane", 6.0, 3.0)
	m.ammo = 10
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var t0 := Time.get_ticks_msec()
	while m.ammo == 10 and Time.get_ticks_msec() - t0 < 2500:
		m.gun.global_position = Vector3(0.0, 3.0, 0.0)
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.ammo == 10 - Config.PLANE_DAMAGE, "si te choca: -%d balas (%d)" % [Config.PLANE_DAMAGE, m.ammo])
	await despawn(m)


func test_rocket() -> void:
	print("cohete")
	var m := await spawn()
	clear_world(m)
	await physics_frame
	var r: Rocket = put(m, "rocket", 14.0, 8.0)
	m.ammo = 10
	await place_gun(m, Vector2(0.0, 3.0), 0.0)
	var seen: Vector3 = m.gun.global_position
	var t0 := Time.get_ticks_msec()
	while m.ammo == 10 and Time.get_ticks_msec() - t0 < 3000:
		m.gun.global_position = seen
		m.gun.linear_velocity = Vector3.ZERO
		await physics_frame
	check(m.ammo == 10 - Config.ROCKET_DAMAGE, "va hacia vos y explota: -%d balas (%d)" % [Config.ROCKET_DAMAGE, m.ammo])
	check(not is_instance_valid(r) or not r.alive, "el cohete explotó")
	check("explosion" in m.sfx.played, "suena la explosión")
	await despawn(m)
	m = await spawn()
	clear_world(m)
	await physics_frame
	r = put(m, "rocket", 30.0, 3.0) # lejos: todavía no te vio
	await fire_at(m, Vector2(0.0, 3.0), r.global_position)
	check(not is_instance_valid(r) or not r.alive, "un tiro lo explota")
	check(m.ammo == Config.START_AMMO - 1 + Config.ROCKET_REWARD, "+%d" % Config.ROCKET_REWARD)
	await despawn(m)
