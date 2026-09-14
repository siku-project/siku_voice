VoiceEndpoint = {}

local STATE_KEY <const> = 'siku:state:voiceServer'
local GLOBAL_BAG <const> = 'global'
local HIDDEN <const> = 'hidden'

local applied = nil

--- Reads a replicated value as an endpoint.
---@param value any The global state value.
---@return table? endpoint { address, port }, or nil for the built-in server.
local function toEndpoint(value)
  if type(value) ~= 'table' or not VoiceIsName(value.address) then
    return nil
  end

  local port <const> = VoiceToId(value.port)

  if not port then
    return nil
  end

  return { address = value.address, port = port }
end

--- Points the game at the voice server the server published, once per
--- distinct value. The game reconnects on its own when the address moves.
---@param value any The global state value.
---@return nil
local function apply(value)
  local endpoint <const> = toEndpoint(value)

  if not endpoint then
    if applied then
      applied = nil
      Siku.print.warn(T('server_back_to_built_in'))
    end

    return
  end

  if applied and applied.address == endpoint.address and applied.port == endpoint.port then
    return
  end

  applied = endpoint
  VoiceMumble.setServerAddress(endpoint.address, endpoint.port)
  Siku.print.info(T('server_external', VoiceEndpoint.describe(('%s:%d'):format(endpoint.address, endpoint.port))))
end

--- Whether the game was pointed at a voice server outside the FXServer.
---@return boolean external Whether an external server is in use.
function VoiceEndpoint.isExternal()
  return applied ~= nil
end

--- An address as it may be written in a log, hidden when the config asks
--- for it.
---@param address string The address.
---@return string text The address, or a hidden mention.
function VoiceEndpoint.describe(address)
  if VoiceConfig.server.hideEndpoint then
    return HIDDEN
  end

  return address
end

AddStateBagChangeHandler(STATE_KEY, GLOBAL_BAG, function(_, _, value)
  apply(value)
end)

apply(GlobalState[STATE_KEY])
