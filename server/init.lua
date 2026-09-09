local REQUIRED_CORE_VERSION <const> = '1.0.0'

local dependency <const> = Siku.version.checkDependency('siku_core', REQUIRED_CORE_VERSION)

if not dependency.ok then
  Siku.print.throw(dependency.message)
end

Siku.print.success(('Linked to siku_core (%s)'):format(dependency.currentVersion))
Siku.version.checkRelease('siku-project/siku_voice')

--- The modules below this file do not exist yet while it loads: the boot
--- work waits one frame so every one of them is defined.
CreateThread(function()
  Wait(0)

  ApplyAudioSettings()
  RestoreConnectedSessions()

  local first <const>, last <const> = VoiceChannels.getReservedRange()

  Siku.print.success(('Voice ready, %d proximity mode(s), player channels %d to %d'):format(
    VoiceModes.count(),
    first,
    last
  ))
end)
