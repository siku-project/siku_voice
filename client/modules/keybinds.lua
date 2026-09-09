local TALK_KEYBIND <const> = 'siku_voice_talk'
local CYCLE_KEYBIND <const> = 'siku_voice_cycle'
local TALK_OWNER <const> = 'keybind'

--- Registers a keybind when the config names a key for it.
---@param name string The keybind name.
---@param key any The configured default key, or false.
---@param description string The label shown in the game settings.
---@param onPressed function Called on press.
---@param onReleased? function Called on release.
---@return nil
local function bind(name, key, description, onPressed, onReleased)
  if type(key) ~= 'string' or key == '' then
    return
  end

  Siku.keybind.add({
    name = name,
    description = description,
    defaultKey = key,
    onPressed = onPressed,
    onReleased = onReleased,
  })
end

bind(TALK_KEYBIND, VoiceConfig.keybinds.pushToTalk, T('keybind_push_to_talk'), function()
  VoiceTalk.hold(TALK_OWNER, Siku.name)
end, function()
  VoiceTalk.release(TALK_OWNER)
end)

bind(CYCLE_KEYBIND, VoiceConfig.keybinds.cycleProximity, T('keybind_cycle_proximity'), function()
  VoiceProximity.cycleMode()
end)
