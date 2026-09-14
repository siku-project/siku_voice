VoiceEndpoint = {}

local STATE_KEY <const> = 'siku:state:voiceServer'
local MIN_PORT <const> = 1
local MAX_PORT <const> = 65535
local BUILT_IN <const> = 'built-in'
local HIDDEN <const> = 'external (hidden)'

local endpoint = false

--- Checks that the voice server section of the config is usable.
---@param server any The raw section.
---@return string? fault What is wrong with it, or nil when it is valid.
local function validate(server)
  if type(server) ~= 'table' then
    return 'must be a table'
  end

  if server.address == nil or server.address == false then
    return nil
  end

  if type(server.address) ~= 'string' or server.address == '' then
    return 'address must be false or a non-empty string'
  end

  if math.type(server.port) ~= 'integer' or server.port < MIN_PORT or server.port > MAX_PORT then
    return ('port must be an integer between %d and %d'):format(MIN_PORT, MAX_PORT)
  end

  return nil
end

--- The voice server the clients are told to use.
---@return table|false endpoint { address, port } for an external server, false for the built-in one.
function VoiceEndpoint.get()
  if not endpoint then
    return false
  end

  return { address = endpoint.address, port = endpoint.port }
end

--- Whether the clients use a voice server outside this FXServer.
---@return boolean external Whether an external server is configured.
function VoiceEndpoint.isExternal()
  return endpoint ~= false
end

--- The voice server as it may be written in a log.
---@return string text 'built-in', 'host:port', or a hidden mention.
function VoiceEndpoint.describe()
  if not endpoint then
    return BUILT_IN
  end

  if VoiceConfig.server.hideEndpoint then
    return HIDDEN
  end

  return ('%s:%d'):format(endpoint.address, endpoint.port)
end

--- Reads the configured voice server and replicates it to every client,
--- present and future, through the global state. A client reacts to the
--- value the moment it changes, so nothing polls.
---@return nil
function PublishVoiceServer()
  local server <const> = VoiceConfig.server
  local fault <const> = validate(server)

  if fault then
    Siku.print.error(T('server_invalid', fault))
    endpoint = false
  elseif server.address then
    endpoint = { address = server.address, port = server.port }
  else
    endpoint = false
  end

  GlobalState[STATE_KEY] = endpoint
end
