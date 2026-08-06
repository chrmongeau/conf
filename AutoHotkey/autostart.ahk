#Requires AutoHotkey v2.0
#SingleInstance Force

;;;;;;;;;;;;;;;; HotKeys:
; ^ Control
; ! Alt
; + Shift
; # Win

GVIM() => "C:\Program Files\Vim\vim91\gvim.exe"  ; not on PATH, so spell it out

; Activate a window, restoring it first if it was minimized. Shared by the
; launchers, the app-window cycler and the scratch note keys.
ActivateWindow(hwnd)
{
  if WinGetMinMax(hwnd) = -1
    WinRestore hwnd
  WinActivate hwnd
}


; ##### SCRIPT HYGIENE
; {{{

#SuspendExempt  ; these three must keep working while everything else is suspended

#+r::Reload

#+F2::Run Format('"{1}" "{2}"', GVIM(), A_ScriptFullPath)

#+Esc::
{
  Suspend -1
  ToolTip(A_IsSuspended ? "AHK hotkeys SUSPENDED" : "AHK hotkeys active")
  SetTimer(() => ToolTip(), -1500)
}

#SuspendExempt False

; ##### /SCRIPT HYGIENE }}}


; ##### BOOKMARKS
; {{{

#1::Run "http://mongeau.net/q"

; ##### /BOOKMARKS }}}


; ##### LAUNCHERS
; {{{

; Focus the app if it is already up, rather than starting a second copy: Excel,
; Word and gvim all launch again quite happily, which from a launcher key is
; never what you meant. "exclude" is a title fragment to ignore, so the gvim key
; does not hand you the scratch window instead of a new editor.
ActivateOrRun(exe, cmd, exclude := "")
{
  SetTitleMatchMode 2  ; exclude is a fragment, not a whole title
  if hwnd := WinExist("ahk_exe " exe, , exclude)
  {
    ActivateWindow(hwnd)
    return
  }
  Run cmd
}

#+c::Run "calc"  ; UWP and single-instance already: a second Run just focuses it
#+e::ActivateOrRun("EXCEL.EXE", "excel")
#+w::ActivateOrRun("WINWORD.EXE", "winword")
; not "powerpoint" -- App Paths registers it as powerpnt.exe
#+p::ActivateOrRun("POWERPNT.EXE", "powerpnt")
#+v::ActivateOrRun("gvim.exe", Format('"{1}"', GVIM()), ScratchTag())
;#+x::Run "D:/x"  ; temp dir

; Brave with a fresh tab, cursor already in the address bar
#+b::
{
  if WinExist("ahk_exe brave.exe")
  {
    WinActivate
    if WinWaitActive("ahk_exe brave.exe", , 2)
      Send "^t"  ; a new tab focuses the address bar on its own
    return
  }
  Run "brave.exe"
  if WinWait("ahk_exe brave.exe", , 10)
  {
    WinActivate
    if WinWaitActive("ahk_exe brave.exe", , 2)
      Send "^l"  ; fresh launch already opened a tab -- just focus the bar
  }
}

; ##### /LAUNCHERS }}}


; ##### WINDOWS
; {{{

; Windows has no per-app switcher -- Alt+Tab and Alt+Esc both walk every window
; on the desktop. This is the macOS Cmd+`: rotate through the windows of
; whatever app is in front (two Word documents, three Brave windows) and leave
; everything else where it is.
CycleAppWindows()
{
  if !(active := WinExist("A"))
    return
  wins := []
  for hwnd in WinGetList("ahk_exe " WinGetProcessName(active))
  {
    ; Most apps keep invisible helpers around -- shell hosts, IME and message
    ; windows. They carry no title and you cannot switch to them, so drop them
    ; or the cycle "moves" to nothing every other press.
    if WinGetTitle(hwnd) != ""
      wins.Push(hwnd)
  }
  if wins.Length < 2
    return
  ; WinGetList hands back the z-order, front to back. Activating the *bottom*
  ; entry rotates the stack by one, so repeated presses walk the whole app and
  ; come back around. With two windows it is a plain toggle.
  ActivateWindow(wins[wins.Length])
}

; Alt + the key above Tab, i.e. Cmd+` in the same place your hand already goes.
; Bound by scancode rather than as !` because that key is only a backtick on a
; US layout -- on an Italian one it is \ , and the hotkey would silently fail
; to register. SC029 is the physical key, whatever it happens to print.
!SC029::CycleAppWindows()

; ##### /WINDOWS }}}


; ##### SCRATCH NOTES
; {{{

; One gvim instance (server "SCRATCH") holding every quick note as a tab,
; instead of a new window per thought. Notes are real dated files, so nothing
; is lost on reboot and you can grep the folder months later.
NotesDir()   => EnvGet("USERPROFILE") "\notes"  ; C:\Users\Mongeau\notes
; The tag gvim puts in the title. Also what the #+v launcher excludes, so that
; "open gvim" and "summon the scratch window" stay two different keys.
ScratchTag() => "[SCRATCH]"
ScratchWin() => ScratchTag() " ahk_exe gvim.exe"

; Same minute => same file, so a double press reopens rather than clutters.
NewScratchNote()
{
  dir := NotesDir()
  if !DirExist(dir)
    DirCreate dir
  file := dir "\" FormatTime(, "yyyy-MM-dd-HHmm") ".md"
  ; The -c only ever takes effect on a cold start: once the server is up,
  ; --remote-tab-silent hands the file over and this client exits immediately.
  Run Format('"{1}" --servername SCRATCH -c "set titlestring=[SCRATCH]-%t" --remote-tab-silent "{2}"', GVIM(), file)
}

; New note -- starts the scratch window if it isn't up yet
#+n::
{
  SetTitleMatchMode 2
  NewScratchNote()
  if hwnd := WinWait(ScratchWin(), , 5)
    ActivateWindow(hwnd)
}

; Summon it / get it out of the way
#+t::
{
  SetTitleMatchMode 2
  if !(hwnd := WinExist(ScratchWin()))
  {
    NewScratchNote()  ; nothing running yet -- open with a fresh note
    if hwnd := WinWait(ScratchWin(), , 5)
      ActivateWindow(hwnd)
    return
  }
  if WinActive(hwnd)
    WinMinimize hwnd  ; minimize, not WinHide: a hidden window is unrecoverable
  else                ; by normal means if this script ever dies
    ActivateWindow(hwnd)
}

; ##### /SCRATCH NOTES }}}


; ##### NAVIGATION
; {{{

+!Up::SendInput "{PgUp}"
+!Down::SendInput "{PgDn}"
+!Left::SendInput "{Home}"
+!Right::SendInput "{End}"

; ##### /NAVIGATION }}}


; ##### EDITING
; {{{

; Paste without formatting (i.e., raw text)
^+v::
{
  saved := ClipboardAll()
  A_Clipboard := A_Clipboard  ; round-trip through text, dropping formatting
  if !ClipWait(1, 0)          ; nothing pasteable, put the original back
  {
    A_Clipboard := saved
    return
  }
  Send "^v"
  Sleep 300                   ; give the target app time to read the clipboard
  A_Clipboard := saved
}

; Bye!
^!b::Send "Best,{Enter}{Enter}Christian"

; Today's date, for note headers, file names and YAML front matter
^!d::SendText FormatTime(, "yyyy-MM-dd")

; Windows hands out paths with backslashes; R, gvim and every shell want
; forward slashes. Rewrite the clipboard in place, so the converted path is
; ready wherever you paste it next.
LooksLikeWindowsPath(s)
{
  if (s == "" || InStr(s, "`n") || InStr(s, "`r"))
    return false
  ; C:\... or \\server\share, optionally quoted by Explorer's "Copy as path"
  return RegExMatch(s, '^"?([A-Za-z]:\\|\\\\[^\\])') > 0
}

; Ctrl+Alt+P, next to the other Ctrl+Alt inserters. A letter rather than the
; "/" key on purpose: symbol keys sit in different places on different layouts.
^!p::
{
  path := Trim(A_Clipboard)  ; some sources tack on a trailing newline
  ; The guard is deliberate even though you asked for this explicitly: fired by
  ; accident on a regex, a "\n" or a LaTeX snippet, a blind replace would
  ; quietly corrupt the clipboard. Anything that is not clearly a path is left
  ; exactly as it was.
  if !LooksLikeWindowsPath(path)
  {
    ToolTip("clipboard is not a Windows path")
    SetTimer(() => ToolTip(), -1200)
    return
  }
  ; Any quotes Explorer's "Copy as path" added are kept: pasted into R or a
  ; shell, a quoted path is exactly what you want.
  A_Clipboard := StrReplace(path, "\", "/")
  ClipWait(1, 0)
  ToolTip("path converted to /")
  SetTimer(() => ToolTip(), -700)
}

; ##### /EDITING }}}


; ##### KEYBOARD
; {{{

; The F10 pair stands in for the Insert copy/paste pair. This was originally
; written as "if A_ComputerName == <the Zbook>", which never actually scoped
; anything -- hotkeys register at load time, so it was live on every machine,
; and by now it is relied on everywhere. Left global on purpose; put it back
; behind #HotIf A_ComputerName = ... if you ever really want it on one box.
;
; {Blind} is load-bearing. You are physically holding Ctrl (or Shift) when the
; hotkey fires; a plain Send would release and re-press it around the Insert,
; and that modifier churn is dropped by terminals and browsers. Blind mode
; leaves your physical modifier alone and sends the bare Insert, so the app
; sees a clean Ctrl+Insert / Shift+Insert.
^F10::SendInput "{Blind}{Insert}"
+F10::SendInput "{Blind}{Insert}"  ; Shift stays held -> Shift+Insert

; Same paste with Ctrl held as well -- an easy slip when Ctrl+F10 is copy, and
; apparently the habit. Release the Ctrl so the app still sees Shift+Insert
; rather than Ctrl+Shift+Insert, which means nothing to most apps.
^+F10::SendInput "{Blind}{Ctrl up}{Insert}"

; ##### /KEYBOARD }}}

; vi: set foldmethod=marker:
