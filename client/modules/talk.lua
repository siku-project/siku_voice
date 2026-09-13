VoiceTalk = {}

local PUSH_TO_TALK_CONTROL <const> = 249
local PRESSED <const> = 1.0
local INPUT_GROUPS <const> = { 0, 1, 2 }

local holders <const> = {}
local holding = false

--- Keeps the game push-to-talk control pressed for as long as someone
--- holds the microphone, which is what makes the engine transmit.
---@return nil
local function run()
  while holding do
    for i = 1, #INPUT_GROUPS do
      SetControlNormal(INPUT_GROUPS[i], PUSH_TO_TALK_CONTROL, PRESSED)
    end

    Wait(0)
  end
end

--- Starts or stops the press depending on whether any holder remains and
--- the voice is not fully restricted.
---@return nil
local function sync()
  local wanted <const> = next(holders) ~= nil and not VoiceRestrictions.isFullyRestricted()

  if wanted == holding then
    return
  end

  holding = wanted

  if holding then
    CreateThread(run)
  end
end

--- Opens the microphone on behalf of a caller until it is released. Several
--- callers may hold it at once; it closes when the last one lets go.
---@param owner string A key naming the caller.
---@param resource? string The resource holding it, resolved when omitted.
---@return boolean held Whether the hold was stored.
function VoiceTalk.hold(owner, resource)
  if not VoiceIsName(owner) then
    return VoiceRefuse('HoldTalk', 'owner')
  end

  holders[owner] = resource or VoiceResolveOwner()
  sync()

  return true
end

--- Releases a hold.
---@param owner string The key it was held with.
---@return boolean released Whether the hold existed.
function VoiceTalk.release(owner)
  if not holders[owner] then
    return false
  end

  holders[owner] = nil
  sync()

  return true
end

--- Releases every hold a resource placed, when it stops.
---@param resource string The resource name.
---@return nil
function VoiceTalk.releaseOwner(resource)
  for owner, holder in pairs(holders) do
    if holder == resource then
      holders[owner] = nil
    end
  end

  sync()
end

--- Whether the microphone is being held open by anyone.
---@return boolean held Whether a hold is active.
function VoiceTalk.isHeld()
  return holding
end

--- Re-evaluates the press after the restrictions moved: a hold placed
--- while the voice was closed takes effect once it opens again.
---@return nil
function VoiceTalk.refresh()
  sync()
end

AddEventHandler('onResourceStop', function(resource)
  if resource ~= Siku.name then
    VoiceTalk.releaseOwner(resource)
    return
  end

  for owner in pairs(holders) do
    holders[owner] = nil
  end

  sync()
end)
