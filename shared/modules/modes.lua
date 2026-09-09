VoiceModes = {}

local ordered <const> = {}
local byName <const> = {}
local defaultName

--- Checks that a mode definition is usable.
---@param definition any The raw definition from the config.
---@return string? fault What is wrong with it, or nil when it is valid.
local function validateDefinition(definition)
  if type(definition) ~= 'table' then
    return 'must be a table'
  end

  if type(definition.name) ~= 'string' or definition.name == '' then
    return 'name must be a non-empty string'
  end

  if byName[definition.name] then
    return ("name '%s' is already used"):format(definition.name)
  end

  if type(definition.range) ~= 'number' or definition.range <= 0 then
    return 'range must be a positive number'
  end

  return nil
end

--- Resolves the mode players start with, falling back to the first one
--- when the configured name matches nothing.
---@return string name The default mode name.
local function resolveDefault()
  local configured <const> = VoiceConfig.proximity.defaultMode

  if byName[configured] then
    return configured
  end

  local fallback <const> = ordered[1].name

  Siku.print.warn(T('mode_default_unknown', tostring(configured), fallback))

  return fallback
end

for index, definition in ipairs(VoiceConfig.proximity.modes) do
  local fault <const> = validateDefinition(definition)

  if fault then
    Siku.print.error(T('mode_invalid_definition', index, fault))
  else
    local mode <const> = {
      name = definition.name,
      range = definition.range + 0.0,
      index = #ordered + 1,
    }

    ordered[mode.index] = mode
    byName[mode.name] = mode
  end
end

if #ordered == 0 then
  Siku.print.throw('No valid proximity mode is configured')
end

defaultName = resolveDefault()

--- Gets a mode by name.
---@param name any The mode name.
---@return table? mode The mode { name, range, index }, or nil when unknown.
function VoiceModes.get(name)
  if type(name) ~= 'string' then
    return nil
  end

  return byName[name]
end

--- Gets the mode players start with.
---@return table mode The default mode.
function VoiceModes.getDefault()
  return byName[defaultName]
end

--- Gets the mode following another one in cycling order, wrapping around.
---@param name string The current mode name.
---@return table mode The next mode.
function VoiceModes.getNext(name)
  local current <const> = byName[name]

  if not current then
    return ordered[1]
  end

  return ordered[(current.index % #ordered) + 1]
end

--- Lists every mode in cycling order.
---@return table modes A list of { name, range, index } copies.
function VoiceModes.list()
  local result <const> = {}

  for index = 1, #ordered do
    local mode <const> = ordered[index]

    result[index] = { name = mode.name, range = mode.range, index = mode.index }
  end

  return result
end

--- Counts the configured modes.
---@return number count How many modes exist.
function VoiceModes.count()
  return #ordered
end
