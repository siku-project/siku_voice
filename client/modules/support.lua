local NATIVE_AUDIO_CONVAR <const> = 'voice_useNativeAudio'

--- Resolves who is calling into this resource: the resource behind an
--- export when there is one, this resource otherwise. Everything a caller
--- registers is tagged with it, so it can be released when that caller
--- stops.
---@return string owner The resource name.
function VoiceResolveOwner()
  return GetInvokingResource() or Siku.name
end

--- Reads a value as an id: a whole number above zero, the shape of a
--- server id and of a channel number. A float carrying a whole value is
--- accepted, since numbers crossing an export may lose their integer type.
---@param value any The value to read.
---@return number? id The id as an integer, or nil when the value is not one.
function VoiceToId(value)
  if type(value) ~= 'number' then
    return nil
  end

  local id <const> = math.tointeger(value)

  if not id or id <= 0 then
    return nil
  end

  return id
end

--- Whether a value is a number above zero.
---@param value any The value to test.
---@return boolean valid Whether the value is a positive number.
function VoiceIsPositiveNumber(value)
  return type(value) == 'number' and value > 0
end

--- Whether a value is a non-empty string.
---@param value any The value to test.
---@return boolean valid Whether the value is a usable name.
function VoiceIsName(value)
  return type(value) == 'string' and value ~= ''
end

--- Whether the game renders voices as native audio entities, the mode
--- audio effects depend on.
---@return boolean native Whether native audio is active.
function VoiceIsNativeAudio()
  return GetConvar(NATIVE_AUDIO_CONVAR, 'false') == 'true'
end

--- Reports an invalid argument given to the public API and refuses it.
---@param context string What was being called.
---@param name string The argument name.
---@return boolean refused Always false, so a caller can return it directly.
function VoiceRefuse(context, name)
  Siku.print.warn(T('invalid_argument', context, name))

  return false
end
