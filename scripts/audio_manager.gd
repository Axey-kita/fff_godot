extends Node

# Sound type constants
enum SoundType {
	SWING,
	WAVE,
	PARRY,
	ULT,
	HIT_PLAYER,
	HIT_ENEMY,
	PICKUP,
	ARROW,
}

var audio_stream_player: AudioStreamPlayer

func _ready():
	audio_stream_player = AudioStreamPlayer.new()
	add_child(audio_stream_player)

func play_sound(type: String):
	# Maps sound type string to log message
	# In a full implementation, would load and play the corresponding audio file
	match type:
		"swing":
			print("[Audio] 🔪 挥砍音效")
		"wave":
			print("[Audio] 🌊 波/剑气音效")
		"parry":
			print("[Audio] 🛡️ 招架音效")
		"ult":
			print("[Audio] ⚡ 大招音效")
		"hit_player":
			print("[Audio] 💥 玩家受伤音效")
		"hit_enemy":
			print("[Audio] 💥 敌人受伤音效")
		"pickup":
			print("[Audio] 📦 拾取音效")
		"arrow":
			print("[Audio] 🏹 射箭音效")
		_:
			print("[Audio] 🔇 未知音效类型: ", type)
