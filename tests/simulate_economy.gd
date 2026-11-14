# Run with a fresh XDG_DATA_HOME so starter values match a new player.
extends SceneTree

func _initialize():
	call_deferred("run")

func simulate(data, starter, target_plots: int, style: String, visit_seconds: int, target_tier: int = 1) -> Dictionary:
	var cash: int = starter.coins
	var seeds = int(starter.seed_inventory["wheat"])
	var wood: int = starter.wood
	var stone: int = starter.stone
	var plots = 4
	var jobs: Array[int] = []
	var crops: Array = []
	var purchased = 0
	var tier = 0
	var milestones: Array = []
	var resource_tick = 0
	# Normal sales only. No mutations, big obstacle drops, or extra sectors.
	for t in range(0, 21601, 30):
		if t % visit_seconds != 0:
			continue
		# Initial four branches/four pebble piles; later collection is capped.
		var elapsed_ticks = (t - resource_tick) / 120
		var material_units = 4 if t == 0 else mini(4, elapsed_ticks)
		resource_tick += elapsed_ticks * 120
		wood += material_units * 2
		stone += material_units * 2
		cash += material_units * 10
		var remaining: Array[int] = []
		for finished in jobs:
			if finished <= t: plots += 1
			else: remaining.append(finished)
		jobs = remaining
		var growing: Array = []
		for planted in crops:
			if planted["end"] <= t: cash += int(data.CROPS[planted["crop"]]["reward"])
			else: growing.append(planted)
		crops = growing
		while crops.size() < plots:
			var crop = "wheat"
			if seeds > 0:
				seeds -= 1
			else:
				if style == "mixed" and cash >= 250:
					crop = ["wheat", "carrot", "strawberry", "pumpkin"][crops.size() % 4]
				elif style == "pumpkin" and cash >= 90:
					crop = "pumpkin"
				var cost: int = data.CROPS[crop]["cost"]
				if cash < cost: break
				cash -= cost
			crops.append({"end": t + int(data.CROPS[crop]["grow_time"]), "crop": crop})
		var next: Dictionary = data.TOOL_TIERS[tier + 1] if tier < 3 else {}
		if not next.is_empty() and cash >= int(next["cost_coins"]) and wood >= int(next["cost_wood"]) and stone >= int(next["cost_stone"]):
			cash -= int(next["cost_coins"])
			wood -= int(next["cost_wood"])
			stone -= int(next["cost_stone"])
			tier += 1
			milestones.append(t / 60.0)
			if tier >= target_tier:
				return {"minutes": t / 60.0, "plots": plots, "milestones": milestones}
		while jobs.size() < int(data.TOOL_TIERS[tier]["preparation_slots"]) and plots + jobs.size() < target_plots:
			var price = 25 + 10 * purchased
			if cash - price < plots * 8: break
			cash -= price
			purchased += 1
			jobs.append(t + int(data.PREPARATION_SECONDS))
	return {"minutes": -1, "milestones": milestones}

func run():
	var data = root.get_node("GameData")
	var starter = root.get_node("GameState")
	var success = true
	for cap in [4,8,12,20]:
		var result = simulate(data, starter, cap, "wheat", 30)
		print("Wheat / expand to %d: Copper at %.1f min" % [cap, result["minutes"]])
		success = success and result["minutes"] >= 15 and result["minutes"] <= 25
	print("Mixed / 12 plots: ", simulate(data, starter,12,"mixed",30))
	print("Pumpkins / 12 plots: ", simulate(data, starter,12,"pumpkin",30))
	print("Casual / visits every 3 minutes: ", simulate(data,starter,12,"mixed",180))
	print("Longer run / 24 plots / wheat: ", simulate(data,starter,24,"wheat",30,3))
	print("Longer run / 24 plots / mixed: ", simulate(data,starter,24,"mixed",30,3))
	quit(0 if success else 1)
