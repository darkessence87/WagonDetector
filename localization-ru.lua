﻿if GetLocale() ~= "ruRU" then
    return
end


WD_ENCOUNTER_INTERRUPTED = "Сбор статистики для текущего боя прерван"
WD_ENCOUNTER_START = "Начало боя \"%s\" пул:%d (ENCOUNTER_ID:%s)"
WD_ENCOUNTER_STOP = "Конец боя \"%s\". Время боя: %s"

WD_ENABLED = "Аддон включен"
WD_DISABLED = "Аддон выключен"
WD_LOCKED_BY = "Следующий бой заблокирован игроком %s"

WD_RESET_GUILD_ROSTER = "Статистика гильдии сброшена"

WD_HELP = "Доступные команды:\
/wd config - открывает меню конфигурации\
/wd starttest - запускает тест боя\
/wd stoptest - останавливает тест боя\
/wd wipe - сбрасывает статистику очков гильдии\
/wd interrupt - прерывает сбор статистики на текущем пуле\
/wd pull - блокирует следующий бой для других РЛов или офицеров, тем не менее они будут видеть статистику боя даже с выключенной опцией авто-трекинга\
/wd pullstop - разблокирует бои для других РЛов или офицеров\
/wd clear - полностью очищает историю"

WD_PRINT_SUCCESS = "%s [КРАСАВА] %s: %s (%d штраф очков)"
WD_PRINT_FAILURE = "%s [ВАГОН] %s: %s (%d штраф очков)"
WD_PRINT_INFO = "%s [ИНФО] %s: %s"
WD_NOTIFY_HEADER_RULE = "Список действующих правил в бою \"%s\":"
WD_NOTIFY_RULE = "[%s] %d штраф очков за %s"
WD_REVERT_STR = "Отмена"
WD_LABEL_TOTAL = "ВСЕГО"

WD_BUTTON_LOCK_GUI = "Блокировка перемещения"
WD_BUTTON_DEFAULT_CHAT = "Канал оповещений"
WD_BUTTON_ENABLE_CONFIG = "Аддон включен"
WD_BUTTON_AUTOTRACK = "Старт трекера боя автоматически при любом пуле босса"
WD_BUTTON_IMMEDIATE_NOTIFY = "Использовать мгновенные оповещения в бою"
WD_BUTTON_ENABLE_PENALTIES = "Использовать штрафы в гильдии"
WD_BUTTON_MAX_DEATHS = "Макс. смертей при сборе статистики:"
WD_BUTTON_NAME = "Имя игрока"
WD_BUTTON_RANK = "Звание"
WD_BUTTON_POINTS = "Штрафные очки"
WD_BUTTON_POINTS_SHORT = "Очки"
WD_BUTTON_PULLS = "Пулы"
WD_BUTTON_COEF = "За пул"
WD_BUTTON_TIME = "Время"
WD_BUTTON_REASON = "Причина"
WD_BUTTON_ENCOUNTER = "Бой"

WD_BUTTON_MAIN_MODULE = "Основные опции"
WD_BUTTON_ENCOUNTERS_MODULE = "Список правил"
WD_BUTTON_TRACKING_RULES_MODULE = "Список правил статистики"
WD_BUTTON_TRACKING_OVERVIEW_MODULE = "Диспел/интеррапт монитор"
WD_BUTTON_TRACKING_STATS_MODULE = "Собранная статистика"
WD_BUTTON_GUILD_ROSTER_MODULE = "Статистика гильдии"
WD_BUTTON_RAID_OVERVIEW_MODULE = "Обзор рейда"
WD_BUTTON_LAST_ENCOUNTER_MODULE = "Последний бой"
WD_BUTTON_HISTORY_MODULE = "История"
WD_BUTTON_HELP_MODULE = "Помощь"

WD_BUTTON_HISTORY_FILTER = "Фильтры:"
WD_BUTTON_CLEAR = "Очистить историю"
WD_BUTTON_DELETE = "Удалить"
WD_BUTTON_REVERT = "Отмена"
WD_BUTTON_NEW_RULE = "Новое правило"
WD_BUTTON_NOTIFY_RULES = "Объявить правила"
WD_BUTTON_EDIT = "Изменить"
WD_BUTTON_SELECT_RANK = "Мин. звание:"
WD_BUTTON_ROLE = "Роль"
WD_BUTTON_EXPORT = "Экспорт"
WD_BUTTON_EXPORT_ENCOUNTERS = "Экспорт правил боя"
WD_BUTTON_IMPORT_ENCOUNTERS = "Импорт правил боя"
WD_BUTTON_IMPORT = "Импорт"
WD_BUTTON_CANCEL = "Отмена"
WD_IMPORT_QUESTION = "Это действие перетрёт существующие правила для всего боя \"%s\". Хотите продолжить?"
WD_BUTTON_SHARE = "Поделиться"
WD_BUTTON_ACCEPT = "Принять"
WD_IMPORT_SHARED_QUESTION = "%s хочет поделиться с вами правилом"
WD_BUTTON_SHARE_ENCOUNTERS = "Поделиться правилами"
WD_IMPORT_SHARED_ENCOUNTER_QUESTION = "%s хочет поделиться с вами правилами боя \"%s\". Это действие перетрёт все существующие правила для этого боя"
WD_BUTTON_CLASS = "Класс"
WD_BUTTON_CLASS_NUMBER = "К-во"

WD_RULE_DAMAGE_TAKEN_AMOUNT = "получение >=%d урона от %s"
WD_RULE_DAMAGE_TAKEN = "получение урона от %s"
WD_RULE_DEATH = "смерть от %s"
WD_RULE_DEATH_UNIT = "смерть |cffff0000%s|r"
WD_RULE_APPLY_AURA = "получение ауры %s"
WD_RULE_REMOVE_AURA = "потеря ауры %s"
WD_RULE_AURA_STACKS = "получение %d стаков ауры %s"
WD_RULE_AURA_STACKS_ANY = "получение дополнительных%s стаков ауры %s"
WD_RULE_CAST_START = "|cffff0000%s|r начинает каст %s"
WD_RULE_CAST = "|cffff0000%s|r закончил каст %s"
WD_RULE_CAST_INTERRUPT = "прерывание |cffff0000%s|r %s"
WD_RULE_DISPEL = "рассеивание/кража %s"
WD_RULE_POTIONS = "использование зелья"
WD_RULE_FLASKS = "отсутствие фласки"
WD_RULE_FOOD = "отсутствие еды"
WD_RULE_RUNES = "отсутствие руны"

WD_RULE_ERROR_OLD_VERSION = "Версия правила слишком старая: %s. Минимальная поддерживаемая версия: %s"

WD_TRACKER_INTERRUPTED_BY = "Сбито %s's %s через %s сек"
WD_TRACKER_DISPELLED_BY = "Развеяно/украдено %s's %s через %s sec"
WD_TRACKER_CASTED_IN = "|cffff0000Каст через %s сек!|r"
WD_TRACKER_QUALITY_DESC = "Чем позже сбивается каст, тем лучше. Число показывает, какой процент каста успел пройти. Таким образом, чем выше число, тем позже сбит каст"
WD_TRACKER_BUTTON_CLEAR = "Очистить все пулы"
WD_TRACKER_BUTTON_CLEAR_SELECTED = "Очистить текущий пул"

WD_TRACKER_QT_INTERRUPTS_DESC = "качество сбивания < %s%% для %s"
WD_TRACKER_QT_DISPELS_FULL_RANGE = "рассеивание/кража вне рамок [%s-%s] мсек для %s"
WD_TRACKER_QT_DISPELS_LEFT_RANGE = "слишком быстрое рассеивание/кража (до %s мсек) для %s"
WD_TRACKER_QT_DISPELS_RIGHT_RANGE = "слишком долгое рассеивание/кража (от %s мсек) для %s"
WD_TRACKER_RT_AURA_EXISTS_DESC = "пока действует %s"
WD_TRACKER_RT_AURA_NOT_EXISTS_DESC = "пока |cffffffffНЕ|r действует %s"
WD_TRACKER_RT_UNIT_CASTING_DESC = "во время каста %s"
WD_TRACKER_RT_CUSTOM_DESC = "между <%s> и <%s>"
WD_TRACKER_RT_DEPENDENCY_DESC = "<%s> в течении %s мсек после <%s>"
WD_TRACKER_RT_DEPENDENCY_DESC_SHORT = "<%s> после <%s>"
WD_TRACKER_ST_TARGET_DAMAGE = "собирает статистику |cffffffffполученного|r |cffff0000%s|r урона"
WD_TRACKER_ST_TARGET_HEALING = "собирает статистику |cffffffffполученного|r лечения"
WD_TRACKER_ST_TARGET_INTERRUPTS = "собирает статистику сбитых |cffffffffцели|r кастов"
WD_TRACKER_ST_SOURCE_DAMAGE = "собирает статистику |cffffffffнанесенного|r урона"
WD_TRACKER_ST_SOURCE_HEALING = "собирает статистику |cffffffffисходящего|r лечения"
WD_TRACKER_ST_SOURCE_INTERRUPTS = "собирает статистику сбитых |cffffffffцелью|r кастов"

--WD_TRACKER_DONE_POPUP_LABEL = "%s done to %s by %s"
--WD_TRACKER_TAKEN_POPUP_LABEL = "%s taken by %s from %s"
