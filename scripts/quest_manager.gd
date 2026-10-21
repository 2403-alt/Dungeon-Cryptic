extends Node

signal quest_updated
signal quest_completed

enum QuestState {
	NOT_STARTED,
	ACTIVE,
	READY_TO_DELIVER,
	COMPLETED
}

var quest_state: QuestState = QuestState.NOT_STARTED
var required_crystals: int = 6
var collected_crystals: int = 0

func start_quest() -> void:
	if quest_state != QuestState.NOT_STARTED:
		return
	collected_crystals = 0
	quest_state = QuestState.ACTIVE
	quest_updated.emit()
	
func collect_crystal() -> bool:
	if quest_state != QuestState.ACTIVE:
		return false
	collected_crystals += 1
	if collected_crystals >= required_crystals:
		quest_state = QuestState.READY_TO_DELIVER
	quest_updated.emit()
	return true

func complete_quest() -> void:
	if quest_state != QuestState.READY_TO_DELIVER:
		return
	quest_state = QuestState.COMPLETED
	quest_updated.emit()
	quest_completed.emit()
