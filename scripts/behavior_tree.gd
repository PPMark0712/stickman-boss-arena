class_name ArenaBT
extends RefCounted
## Small memoryful behavior tree. Actions return a status on each physics tick.

enum Status { SUCCESS, FAILURE, RUNNING }

class Task extends RefCounted:
	func tick(_delta: float) -> Status:
		return Status.FAILURE
	func reset() -> void:
		pass

class Action extends Task:
	var callback: Callable
	func _init(fn: Callable) -> void:
		callback = fn
	func tick(delta: float) -> Status:
		return callback.call(delta)

class Condition extends Task:
	var predicate: Callable
	func _init(fn: Callable) -> void:
		predicate = fn
	func tick(_delta: float) -> Status:
		return Status.SUCCESS if predicate.call() else Status.FAILURE

class Sequence extends Task:
	var children: Array
	var cursor := 0
	func _init(tasks: Array) -> void:
		children = tasks
	func tick(delta: float) -> Status:
		while cursor < children.size():
			var result: Status = children[cursor].tick(delta)
			if result == Status.RUNNING:
				return result
			if result == Status.FAILURE:
				reset()
				return result
			cursor += 1
		reset()
		return Status.SUCCESS
	func reset() -> void:
		cursor = 0
		for child in children:
			child.reset()

class Selector extends Task:
	var children: Array
	func _init(tasks: Array) -> void:
		children = tasks
	func tick(delta: float) -> Status:
		for child in children:
			var result: Status = child.tick(delta)
			if result != Status.FAILURE:
				return result
		return Status.FAILURE
	func reset() -> void:
		for child in children:
			child.reset()
