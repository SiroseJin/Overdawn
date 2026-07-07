extends Sprite2D
class_name SheetAnim
## Plays a grid spritesheet (hframes x vframes) by stepping `frame`.
## Far lighter than authoring an AnimatedSprite2D with one AtlasTexture per frame.
## Can play a sub-range starting at `start_frame` (e.g. one row of a multi-row sheet).

@export var fps: float = 30.0
@export var loop: bool = true
@export var autoplay: bool = true
@export var free_on_finish: bool = false   # one-shot effects: queue_free when done
@export var start_frame: int = 0           # first frame of the played range
@export var frame_count: int = 0           # 0 = to end of grid from start_frame

signal finished

var _t := 0.0
var _playing := false
var _start := 0
var _count := 1

func _ready() -> void:
	_start = start_frame
	var grid: int = max(1, hframes * vframes)
	_count = frame_count if frame_count > 0 else max(1, grid - _start)
	if autoplay:
		play()

func play() -> void:
	frame = _start
	_t = 0.0
	_playing = true

func _process(delta: float) -> void:
	if not _playing or fps <= 0.0:
		return
	_t += delta
	var step := 1.0 / fps
	while _t >= step:
		_t -= step
		if frame + 1 >= _start + _count:
			if loop:
				frame = _start
			else:
				_playing = false
				finished.emit()
				if free_on_finish:
					queue_free()
				return
		else:
			frame += 1
