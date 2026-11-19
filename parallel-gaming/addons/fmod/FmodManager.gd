@tool
extends Node

var performance_display: PerformancesDisplay

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	performance_display = PerformancesDisplay.new()
	add_child(performance_display)

func _exit_tree() -> void:
	remove_child(performance_display)
	performance_display.free()

func _process(delta):
	FmodServer.update()
	
func _notification(what):
	# Local patch (Red Painter): this FmodServer build has no notification()
	# under Godot 4.7, which spammed script errors in the editor.
	if FmodServer.has_method("notification"):
		FmodServer.notification(what)
