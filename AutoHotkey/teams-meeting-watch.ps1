<#
  Watches the Windows notification store for the Teams card posted by the
  "Meeting starting soon" Power Automate flow, and appends a line to a trigger
  file. autostart.ahk polls that file and turns the line into a popup.

  Why PowerShell and not AutoHotkey: reading *other* applications'
  notifications means Windows.UI.Notifications.Management.UserNotificationListener,
  which is WinRT. AHK cannot call WinRT, PowerShell can.

  This file is deliberately ASCII-only. Windows PowerShell 5.1 reads a script
  without a BOM as ANSI, so a literal emoji in here would arrive mangled and
  never match anything. The wording is matched; the icon is ignored.
#>
param(
  # The card's wording, minus the emoji. Substring match, case-insensitive.
  [string] $Phrase      = 'Meeting starting soon',
  # Who posted it. Only enforced with -RequireSender; see the note below.
  [string] $Sender      = 'Workflows',
  [switch] $RequireSender,
  [string] $AumidLike   = 'MSTeams_*',
  [int]    $IntervalSec = 4,
  [string] $TriggerFile = (Join-Path $env:TEMP 'ahk-meeting-alert.txt'),
  [string] $CaptureFile = (Join-Path $env:TEMP 'ahk-meeting-capture.log'),
  [string] $PidFile     = (Join-Path $env:TEMP 'ahk-meeting-watch.pid')
)

$ErrorActionPreference = 'Stop'

function Write-Log($file, $line) {
  # Every Teams toast lands here and this process runs for days, so roll the
  # file over instead of letting it grow without bound.
  if ((Test-Path $file) -and ((Get-Item $file).Length -gt 512KB)) {
    Move-Item -Path $file -Destination "$file.old" -Force
  }
  $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  Add-Content -Path $file -Value "$stamp  $line" -Encoding UTF8
}

Set-Content -Path $PidFile -Value $PID -Encoding ASCII

Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.UI.Notifications.Management.UserNotificationListener, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
[Windows.UI.Notifications.KnownNotificationBindings,           Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null

# WinRT returns IAsyncOperation and 5.1 has no await, so borrow AsTask from the
# WindowsRuntime extensions and block on it. The overload has to be picked by
# hand: there are several AsTask methods and only this one takes a bare
# IAsyncOperation.
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

$listener  = [Windows.UI.Notifications.Management.UserNotificationListener]::Current
$toastKind = [Windows.UI.Notifications.NotificationKinds]::Toast
$listType  = [System.Collections.Generic.IReadOnlyList[Windows.UI.Notifications.UserNotification]]

function Get-Notifications {
  $op = $listener.GetNotificationsAsync($toastKind)
  $t  = $asTask.MakeGenericMethod($listType).Invoke($null, @($op))
  $t.Wait(-1) | Out-Null
  $t.Result
}

function Get-NotificationText($n) {
  $b = $n.Notification.Visual.GetBinding([Windows.UI.Notifications.KnownNotificationBindings]::ToastGeneric)
  if (-not $b) { return '' }
  ($b.GetTextElements() | ForEach-Object { $_.Text }) -join ' | '
}

if ($listener.GetAccessStatus() -ne 'Allowed') {
  Write-Log $CaptureFile ("notification access is '{0}' -- turn it on under Settings > Privacy & security > Notifications" -f $listener.GetAccessStatus())
  exit 1
}

# Whatever is already sitting in the notification centre is history, not news.
# Without this, every restart would replay old cards as fresh alerts.
$seen = @{}
foreach ($n in (Get-Notifications)) { $seen[[uint32]$n.Id] = $true }
Write-Log $CaptureFile ("watching (pid {0}): phrase='{1}' sender='{2}' requireSender={3} every {4}s" -f `
  $PID, $Phrase, $Sender, $RequireSender.IsPresent, $IntervalSec)

while ($true) {
  Start-Sleep -Seconds $IntervalSec
  try { $notes = Get-Notifications }
  catch {
    # A transient listener failure must not take the watcher down: it has to
    # survive unattended for days.
    Write-Log $CaptureFile "listener error: $($_.Exception.Message)"
    continue
  }

  $current = @{}
  foreach ($n in $notes) {
    $id = [uint32] $n.Id
    $current[$id] = $true
    if ($seen.ContainsKey($id)) { continue }

    $aumid = $n.AppInfo.AppUserModelId
    if ($aumid -notlike $AumidLike) { continue }
    $text = Get-NotificationText $n

    # Every Teams toast is logged, matched or not. This log is the whole point
    # of the first run: it is how you find out what the real card looks like,
    # and whether Teams routes it through Windows at all.
    Write-Log $CaptureFile "teams toast [$aumid] $text"

    if ($text -notlike "*$Phrase*") { continue }
    # The sender check is off by default on purpose. If the toast body turns
    # out not to carry the word "Workflows", requiring it would silently
    # suppress every alert and the feature would look broken rather than
    # mismatched. Read the capture log, then switch -RequireSender on.
    if ($RequireSender -and $Sender -and ($text -notlike "*$Sender*")) {
      Write-Log $CaptureFile "  phrase matched but sender '$Sender' absent -- skipped"
      continue
    }

    Add-Content -Path $TriggerFile -Encoding UTF8 -Value ($text -replace '\s*[\r\n]+\s*', ' - ')
    Write-Log $CaptureFile "  ALERT fired"
  }
  # Forget ids that have left the notification centre, so this cannot grow
  # without bound over a long uptime.
  $seen = $current
}
