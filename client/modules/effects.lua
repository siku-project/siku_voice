VoiceEffects = {}

local INVALID_SUBMIX <const> = -1
local MASTER_OUTPUT <const> = 0
local EFFECT_SLOT <const> = 0
local OUTPUT_SLOT <const> = 0
local DEFAULT_PARAMETER <const> = 'default'
local ENABLED <const> = 1

local OUTPUT_DEFAULTS <const> = {
  frontLeft = 1.0,
  frontRight = 1.0,
  rearLeft = 0.0,
  rearRight = 0.0,
  channel5 = 1.0,
  channel6 = 1.0,
}

local effects <const> = {}
local unsupportedReported = false

--- Checks that an effect definition is usable.
---@param definition any The raw definition.
---@return string? fault What is wrong with it, or nil when it is valid.
local function validateDefinition(definition)
  if type(definition) ~= 'table' then
    return 'must be a table'
  end

  if definition.parameters ~= nil and type(definition.parameters) ~= 'table' then
    return 'parameters must be a table'
  end

  if definition.output ~= nil and type(definition.output) ~= 'table' then
    return 'output must be a table'
  end

  return nil
end

--- Reads one speaker volume, clamped, falling back to the default.
---@param output table The output definition.
---@param key string The speaker key.
---@return number volume The volume, 0 to 1.
local function outputVolume(output, key)
  local value <const> = output[key]

  if type(value) ~= 'number' then
    return OUTPUT_DEFAULTS[key]
  end

  return math.min(1.0, math.max(0.0, value)) + 0.0
end

--- Applies the radio filter and its parameters to a submix.
---@param submix number The submix id.
---@param parameters table The parameters by name.
---@return nil
local function applyRadioFx(submix, parameters)
  SetAudioSubmixEffectRadioFx(submix, EFFECT_SLOT)
  SetAudioSubmixEffectParamInt(submix, EFFECT_SLOT, GetHashKey(DEFAULT_PARAMETER), ENABLED)

  for name, value in pairs(parameters) do
    if math.type(value) == 'integer' then
      SetAudioSubmixEffectParamInt(submix, EFFECT_SLOT, GetHashKey(name), value)
    elseif type(value) == 'number' then
      SetAudioSubmixEffectParamFloat(submix, EFFECT_SLOT, GetHashKey(name), value)
    end
  end
end

--- Builds the game submix behind an effect.
---@param name string The effect name, which names the submix.
---@param definition table The validated definition.
---@return number? submix The submix id, or nil when the game refused it.
local function buildSubmix(name, definition)
  local submix <const> = CreateAudioSubmix(name)

  if submix == INVALID_SUBMIX then
    Siku.print.error(T('effect_create_failed', name))
    return nil
  end

  if definition.radioFx then
    applyRadioFx(submix, definition.parameters or {})
  end

  local output <const> = definition.output or {}

  AddAudioSubmixOutput(submix, MASTER_OUTPUT)
  SetAudioSubmixOutputVolumes(
    submix,
    OUTPUT_SLOT,
    outputVolume(output, 'frontLeft'),
    outputVolume(output, 'frontRight'),
    outputVolume(output, 'rearLeft'),
    outputVolume(output, 'rearRight'),
    outputVolume(output, 'channel5'),
    outputVolume(output, 'channel6')
  )

  return submix
end

--- Whether effects can work at all on this client.
---@return boolean supported Whether native audio is active.
function VoiceEffects.isSupported()
  return VoiceIsNativeAudio()
end

--- Registers an effect, creating its submix. An existing name is replaced.
---@param name string The effect name.
---@param definition table The definition { radioFx?, parameters?, output? }.
---@return boolean registered Whether the effect is available.
function VoiceEffects.register(name, definition)
  if not VoiceIsName(name) then
    return VoiceRefuse('RegisterEffect', 'name')
  end

  local fault <const> = validateDefinition(definition)

  if fault then
    Siku.print.error(T('effect_invalid', name, fault))
    return false
  end

  if not VoiceEffects.isSupported() then
    if not unsupportedReported then
      unsupportedReported = true
      Siku.print.warn(T('effect_unsupported', name))
    end

    return false
  end

  local submix <const> = buildSubmix(name, definition)

  if not submix then
    return false
  end

  effects[name] = submix

  return true
end

--- Gets the submix behind an effect.
---@param name any The effect name.
---@return number? submix The submix id, or nil when unknown.
function VoiceEffects.get(name)
  if type(name) ~= 'string' then
    return nil
  end

  return effects[name]
end

--- Whether an effect is available.
---@param name any The effect name.
---@return boolean available Whether the effect exists on this client.
function VoiceEffects.has(name)
  return VoiceEffects.get(name) ~= nil
end

--- Lists the available effect names.
---@return table names The effect names, sorted.
function VoiceEffects.list()
  local names <const> = {}

  for name in pairs(effects) do
    names[#names + 1] = name
  end

  table.sort(names)

  return names
end

--- Registers every configured effect still missing. Run at load, and again
--- once the voice connects, in case the audio mode was not replicated yet
--- when the script loaded.
---@return nil
function VoiceEffects.ensureConfigured()
  for name, definition in pairs(VoiceConfig.effects) do
    if not effects[name] then
      VoiceEffects.register(name, definition)
    end
  end
end

VoiceEffects.ensureConfigured()
