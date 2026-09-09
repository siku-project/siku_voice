VoiceIndicator = {}

local MARKER_RING_THIN <const> = 25
local MARKER_RING_THICK <const> = 23
local GROUND_OFFSET <const> = 0.98
local RING_HEIGHT <const> = 0.5
local MARKER_FLAGS <const> = 2

local active = false
local radius = 0
local shownAt = 0

--- The marker type matching the configured style.
---@return number marker The marker type.
local function markerType()
  if VoiceConfig.indicator.style == 'thick' then
    return MARKER_RING_THICK
  end

  return MARKER_RING_THIN
end

--- The opacity at one moment of the display: fading in, holding, then
--- fading out.
---@param elapsed number Milliseconds since the ring appeared.
---@return number alpha The opacity, 0 to the configured maximum.
local function alphaAt(elapsed)
  local indicator <const> = VoiceConfig.indicator
  local fade <const> = math.max(1, math.min(indicator.fade, indicator.duration / 2))
  local remaining <const> = indicator.duration - elapsed
  local factor = 1.0

  if elapsed < fade then
    factor = elapsed / fade
  elseif remaining < fade then
    factor = remaining / fade
  end

  return math.floor(indicator.alpha * math.max(0.0, math.min(1.0, factor)))
end

--- Draws the ring at the feet of the player.
---@param alpha number The opacity.
---@return nil
local function draw(alpha)
  local coords <const> = GetEntityCoords(PlayerPedId(), false)
  local color <const> = VoiceConfig.indicator.color
  local diameter <const> = radius * 2

  DrawMarker(
    markerType(),
    coords.x, coords.y, coords.z - GROUND_OFFSET,
    0.0, 0.0, 0.0,
    0.0, 0.0, 0.0,
    diameter, diameter, RING_HEIGHT,
    color.r, color.g, color.b, alpha,
    false, false, MARKER_FLAGS, false, nil, nil, false
  )
end

--- Runs the display until its duration elapses. Showing again while it
--- runs only restarts the clock.
---@return nil
local function run()
  while active do
    local elapsed <const> = GetGameTimer() - shownAt

    if elapsed >= VoiceConfig.indicator.duration then
      break
    end

    draw(alphaAt(elapsed))
    Wait(0)
  end

  active = false
end

--- Shows the ring around the player for the configured duration.
---@param range? number The radius in meters (default: the range in effect).
---@return nil
function VoiceIndicator.show(range)
  radius = VoiceIsPositiveNumber(range) and range or VoiceProximity.getRange()
  shownAt = GetGameTimer()

  if active then
    return
  end

  active = true
  CreateThread(run)
end

--- Hides the ring right away.
---@return nil
function VoiceIndicator.hide()
  active = false
end

--- Whether the ring is being displayed.
---@return boolean visible Whether the ring is on screen.
function VoiceIndicator.isVisible()
  return active
end
