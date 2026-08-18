PalmPilots = PalmPilots or {}

PalmPilots.Constants = {
    MOD_ID = "PalmPilots",
    MODULE = "PalmPilots",
    ITEM_TYPE = "PalmPilots.PalmPilot",
    WORLD_MODEL = "PalmPilot_Ground",
    SCHEMA_VERSION = 9,
    MAX_TASK_TEXT = 120,
    MAX_NOTE_TITLE = 80,
    MAX_NOTE_BODY = 4000,
    MAX_DEVICE_NAME = 32,
    MAX_TASK_LISTS = 100,
    MAX_CHECKLIST_ITEMS = 200,
    MAX_NOTES = 100,
    -- Keep vanilla's heavy-duty battery unit for Insert/Remove Battery recipe
    -- compatibility, while a full PalmPilot lasts 24 in-game hours when open.
    BATTERY_USE_DELTA = 0.007,
    BATTERY_LIFE_MS = 24 * 60 * 60 * 1000,
    BEAM_RANGE = 3.0,
    DEVICE_SCAN_RANGE = 3,
    BEAM_TIMEOUT_MS = 30000,
    BEAM_MAX_PENDING_PER_PLAYER = 4,
}
