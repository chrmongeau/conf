#Requires AutoHotkey v2.0
#SingleInstance Force

;;;;;;;;;;;;;;;; HotKeys:
; ^ Control
; ! Alt
; + Shift
; # Win

GVIM() => "C:\Program Files\Vim\vim91\gvim.exe"  ; not on PATH, so spell it out


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

#+c::Run "calc"
#+e::Run "excel"
#+w::Run "winword"
#+p::Run "powerpnt"  ; not "powerpoint" -- App Paths registers it as powerpnt.exe
#+v::Run Format('"{1}"', GVIM())
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


; ##### SCRATCH NOTES
; {{{

; One gvim instance (server "SCRATCH") holding every quick note as a tab,
; instead of a new window per thought. Notes are real dated files, so nothing
; is lost on reboot and you can grep the folder months later.
NotesDir()   => EnvGet("USERPROFILE") "\notes"  ; C:\Users\Mongeau\notes
ScratchWin() => "[SCRATCH] ahk_exe gvim.exe"

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

ShowScratch(hwnd)
{
  if WinGetMinMax(hwnd) = -1
    WinRestore hwnd
  WinActivate hwnd
}

; New note -- starts the scratch window if it isn't up yet
#+n::
{
  SetTitleMatchMode 2
  NewScratchNote()
  if hwnd := WinWait(ScratchWin(), , 5)
    ShowScratch(hwnd)
}

; Summon it / get it out of the way
#+t::
{
  SetTitleMatchMode 2
  if !(hwnd := WinExist(ScratchWin()))
  {
    NewScratchNote()  ; nothing running yet -- open with a fresh note
    if hwnd := WinWait(ScratchWin(), , 5)
      ShowScratch(hwnd)
    return
  }
  if WinActive(hwnd)
    WinMinimize hwnd  ; minimize, not WinHide: a hidden window is unrecoverable
  else                ; by normal means if this script ever dies
    ShowScratch(hwnd)
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

; ##### /EDITING }}}


; ##### R / RSTUDIO
; {{{

; Windows hands out paths with backslashes, R wants forward slashes. Rewrite
; them on paste -- but ONLY when the clipboard really is a single-line path.
; Anything else would corrupt pasted code: regexes, "\n", LaTeX, escapes.
LooksLikeWindowsPath(s)
{
  if (s == "" || InStr(s, "`n") || InStr(s, "`r"))
    return false
  ; C:\... or \\server\share, optionally quoted by Explorer's "Copy as path"
  return RegExMatch(s, '^"?([A-Za-z]:\\|\\\\[^\\])') > 0
}

#HotIf WinActive("ahk_exe rstudio.exe") || WinActive("ahk_exe Rgui.exe")
^v::
{
  if !LooksLikeWindowsPath(A_Clipboard)
  {
    Send "^v"  ; not a path, stay out of the way
    return
  }
  saved := ClipboardAll()
  A_Clipboard := StrReplace(A_Clipboard, "\", "/")
  ClipWait(1, 0)
  Send "^v"
  Sleep 300
  A_Clipboard := saved
}
#HotIf

; ##### /R }}}


; ##### PDF
; {{{

; Text copied out of a PDF arrives hard-wrapped at every line. Rejoin it, but
; keep real paragraph breaks and repair words hyphenated across a line break.
IsPdfWindow()
{
  if WinActive("ahk_exe AcroRd32.exe") || WinActive("ahk_exe Acrobat.exe")
    return true
  try return InStr(WinGetTitle("A"), ".pdf") > 0  ; in-browser PDF viewers
  return false
}

Unwrap(t)
{
  t := StrReplace(t, "`r`n", "`n")
  t := RegExReplace(t, "\n[ \t]*\n[ \t\n]*", "`r")  ; park paragraph breaks on CR
  t := RegExReplace(t, "(\w)-\n(\w)", "$1$2")       ; de-hyphenate split words
  t := RegExReplace(t, "[ \t]*\n[ \t]*", " ")       ; join the wrapped lines
  return Trim(StrReplace(t, "`r", "`n`n"))          ; and put the breaks back
}

#HotIf IsPdfWindow()
^c::
{
  saved := A_Clipboard
  A_Clipboard := ""
  Send "^c"
  if !ClipWait(1)
  {
    A_Clipboard := saved  ; nothing was selected
    return
  }
  A_Clipboard := Unwrap(A_Clipboard)
}
#HotIf

; ##### /PDF }}}


; ##### MACHINE-SPECIFIC
; {{{

; Zbook: terminal-style copy/paste on F10
#HotIf A_ComputerName = "LT210964"
^F10::SendInput "^{Insert}"
+F10::SendInput "+{Insert}"
#HotIf

; ##### /MACHINE-SPECIFIC }}}

; vi: set foldmethod=marker:
