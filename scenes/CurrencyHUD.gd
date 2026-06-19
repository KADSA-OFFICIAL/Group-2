extends Control

@onready var gold_label = Label.new()

func _ready():
	# Setup Gold display
	gold_label.text = "Gold: 0"
	gold_label.add_theme_font_size_override("font_size", 24)
	add_child(gold_label)
	gold_label.anchor_left = 0.0
	gold_label.anchor_top = 0.0
	gold_label.offset_left = 20
	gold_label.offset_top = 20

	# Connect to CurrencySystem signals
	if CurrencySystem:
		CurrencySystem.currency_changed.connect(_on_currency_changed)
		_update_display()

func _on_currency_changed(currency_type: String, amount: int, new_balance: int):
	_update_display()

func _update_display():
	if CurrencySystem:
		var gold = CurrencySystem.get_balance("gold")
		gold_label.text = "Gold: %d" % gold
