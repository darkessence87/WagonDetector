if GetLocale() ~= "ruRU" then 
    return 
end


WD_ENCOUNTER_INTERRUPTED = "Сбор статистики для текущего боя прерван"
WD_ENCOUNTER_START = "Начало боя '%s' пул:%d (ENCOUNTER_ID:%s)"
WD_ENCOUNTER_STOP = "Конец боя '%s'. Время боя: %s"

WD_ENABLED = "Аддон включен"
WD_DISABLED = "Аддон выключен"

WD_RESET_GUILD_ROSTER = "Статистика гильдии сброшена"

WD_HELP = "Доступные команды:\
/wd config - открывает меню конфигурации\
/wd start - запускает тест боя\
/wd stop - останавливает тест боя\
/wd wipe - сбрасывает статистику очков гильдии\
/wd interrupt - прерывает сбор статистики на текущем пуле"

WD_PRINT_FAILURE = "%s [ВАГОН] %s: %s (%d штраф очков)"
WD_NOTIFY_RULE = "[%s] %d штраф очков за %s"
WD_REVERT_STR = "Отмена"

WD_BUTTON_LOCK_GUI = "Блокировка перемещения"
WD_BUTTON_DEFAULT_CHAT = "Канал оповещений"
WD_BUTTON_ENABLE_CONFIG = "Аддон включен"
WD_BUTTON_IMMEDIATE_NOTIFY = "Использовать мгновенные оповещения в бою"
WD_BUTTON_ENABLE_PENALTIES = "Использовать штрафы в гильдии"
WD_BUTTON_MAX_DEATHS = "Макс. смертей при сборе статистики:"
WD_BUTTON_NAME = 'Имя игрока'
WD_BUTTON_RANK = 'Звание'
WD_BUTTON_POINTS = 'Штрафные очки'
WD_BUTTON_POINTS_SHORT = 'PP'
WD_BUTTON_PULLS = 'Пулы'
WD_BUTTON_COEF = 'PP за пул'
WD_BUTTON_TIME = 'Время'
WD_BUTTON_REASON = 'Причина'
WD_BUTTON_ENCOUNTER = 'Бой'
WD_BUTTON_MAIN_MODULE = "Основные опции"
WD_BUTTON_ENCOUNTERS_MODULE = "Список правил"
WD_BUTTON_GUILD_ROSTER_MODULE = "Статистика гильдии"
WD_BUTTON_LAST_ENCOUNTER_MODULE = "Последний бой"
WD_BUTTON_HISTORY_MODULE = "История"
WD_BUTTON_DELETE = "Удалить"
WD_BUTTON_REVERT = "Отмена"
WD_BUTTON_NEW_RULE = "Новое правило"
WD_BUTTON_NOTIFY_RULES = "Объявить правила"
WD_BUTTON_EDIT = "Изменить"
WD_BUTTON_SELECT_RANK = "Мин. звание:"

WD_RULE_DAMAGE_TAKEN = "получение >=%d урона от %s"
WD_RULE_DAMAGE_TAKEN_AMOUNT = "получение урона от %s"
WD_RULE_DEATH = "смерть от %s"
WD_RULE_DEATH_UNIT = "смерть %s"
WD_RULE_APPLY_AURA = "получение ауры %s"
WD_RULE_REMOVE_AURA = "потеря ауры %s"
WD_RULE_AURA_STACKS = "получение %d стаков ауры %s"
WD_RULE_CAST_START = "моб %s начинает каст %s"
WD_RULE_CAST = "моб %s закончил каст %s"
WD_RULE_CAST_INTERRUPT = "%s прерван %s"
