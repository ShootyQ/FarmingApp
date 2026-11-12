extends Control

# FarmingApp: Prototype Farm
# No paywalls, real-time crop timers, responsive layout

const CROPS = {
	"wheat": {
		"name": "Wheat 🌾",
		"cost": 10,
		"reward": 25,
		"grow_time": 4.0
	},
	"carrot": {
		"name": "Carrot 🥕",
		"cost": 25,
		"reward": 60,
		"grow_time": 8.0
	},
	"strawberry": {
		"name": "Berry 🍓",
		"cost": 50,
		"reward": 130,
		"grow_time": 15.0
	}
}

var coins: int = 50
var selected_crop: String = "wheat"

# 6 farm plots state
# state: "empty", "growing", "ready"
var plots_data = []

@onready var coins_label = $Margin/VBox/TopBar/CoinsLabel
@onready var status_label = $Margin/VBox/TopBar/StatusLabel
@onready var plots_container = $Margin/VBox/PlotGrid
@onready var seed_wheat_btn = $Margin/VBox/BottomBar/SeedWheat
@onready var seed_carrot_btn = $Margin/VBox/BottomBar/SeedCarrot
@onready var seed_berry_btn = $Margin/VBox/BottomBar/SeedBerry

func _ready():
	_init_plots()
	_update_ui()
	seed_wheat_btn.pressed.connect(func(): _select_crop("wheat"))
	seed_carrot_btn.pressed.connect(func(): _select_crop("carrot"))
	seed_berry_btn.pressed.connect(func(): _select_crop("strawberry"))
	_select_crop("wheat")

func _process(delta: float):
	for i in range(plots_data.size()):
		var p = plots_data[i]
		if p["state"] == "growing":
			p["progress"] += delta
			var plot_btn = plots_container.get_child(i) as Button
			var crop_info = CROPS[p["crop"]]
			var pct = clamp(p["progress"] / crop_info["grow_time"], 0.0, 1.0)
			
			if pct >= 1.0:
				p["state"] = "ready"
				plot_btn.text = "%s\nREADY TO HARVEST!\nTap to collect +%d" % [crop_info["name"], crop_info["reward"]]
				plot_btn.modulate = Color(1.0, 0.95, 0.4)
			else:
				var remaining = ceil(crop_info["grow_time"] - p["progress"])
				plot_btn.text = "%s (Growing)\n%ds left" % [crop_info["name"], remaining]
				plot_btn.modulate = Color(0.7, 0.9, 0.6)

func _init_plots():
	plots_data.clear()
	for i in range(6):
		plots_data.append({
			"state": "empty",
			"crop": "",
			"progress": 0.0
		})
		var btn = plots_container.get_child(i) as Button
		var plot_idx = i
		btn.pressed.connect(func(): _on_plot_pressed(plot_idx))
		_render_plot(plot_idx)

func _select_crop(crop_key: String):
	selected_crop = crop_key
	seed_wheat_btn.button_pressed = (crop_key == "wheat")
	seed_carrot_btn.button_pressed = (crop_key == "carrot")
	seed_berry_btn.button_pressed = (crop_key == "strawberry")
	status_label.text = "Selected: %s (Cost: %d)" % [CROPS[crop_key]["name"], CROPS[crop_key]["cost"]]

func _on_plot_pressed(idx: int):
	var p = plots_data[idx]
	if p["state"] == "empty":
		var cost = CROPS[selected_crop]["cost"]
		if coins >= cost:
			coins -= cost
			p["state"] = "growing"
			p["crop"] = selected_crop
			p["progress"] = 0.0
			status_label.text = "Planted %s!" % CROPS[selected_crop]["name"]
			_update_ui()
		else:
			status_label.text = "Not enough coins! Need %d" % cost
	elif p["state"] == "ready":
		var crop_info = CROPS[p["crop"]]
		coins += crop_info["reward"]
		status_label.text = "Harvested %s! Earned +%d coins" % [crop_info["name"], crop_info["reward"]]
		p["state"] = "empty"
		p["crop"] = ""
		p["progress"] = 0.0
		_render_plot(idx)
		_update_ui()
	elif p["state"] == "growing":
		status_label.text = "Crop is still growing..."

func _render_plot(idx: int):
	var plot_btn = plots_container.get_child(idx) as Button
	var p = plots_data[idx]
	if p["state"] == "empty":
		plot_btn.text = "🟫 Soil Plot %d\n[Tap to Plant]" % (idx + 1)
		plot_btn.modulate = Color(0.85, 0.75, 0.65)

func _update_ui():
	coins_label.text = "🪙 Coins: %d" % coins
