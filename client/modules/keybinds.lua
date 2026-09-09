local KEYBIND_NAME <const> = 'siku_voice_cycle'

local key <const> = VoiceConfig.proximity.keybind

if type(key) == 'string' and key ~= '' then
  Siku.keybind.add({
    name = KEYBIND_NAME,
    description = T('keybind_cycle_proximity'),
    defaultKey = key,
    onPressed = function()
      VoiceProximity.cycleMode()
    end,
  })
end
