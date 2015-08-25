; ##### BOOKMARKS
; {{{

#1::Run http://mail.mongeau.net/
#2::Run http://repubblica.it/
#3::Run http://corriere.it/

; ##### /BOOKMARKS }}}

; ##### SHORTCUTS
; {{{

; http://www.autohotkey.com/docs/misc/CLSID-List.htm
;#^e::Run ::{20d04fe0-3aea-1069-a2d8-08002b30309d}

#^c::Run calc
#^e::Run excel
#^w::Run winword
#^x::Run D:/x ; temp dir
#^v::Run %ProgramFiles%\vim\vim74\gvim

;#^f::
;Winshow, faeroes
;WinActivate, faeroes
;return

; ##### /SHORTCUTS }}}


; ##### WINDOW
; {{{

;SetWinDelay, -1 ; -1 No delay, 0 -> lowest, 100 -> default

MoveWindow(inc_x, inc_y)
{
	WinGetPos, X, Y, , , A
	WinMove, A,, X+inc_x, Y+inc_y
}
	
#Up:: MoveWindow(0,-50)
#Down:: MoveWindow(0,50)
#Left:: MoveWindow(-50,0)
#Right:: MoveWindow(50,0)

; ##### /WINDOW }}}


; ##### EVIEWS
; {{{

;GroupAdd, test, EViews
;#IfWinActive, EViews
#IfWinActive, ahk_class #32770

:*:#d::
Send {Left}^+{Left}^c@isperiod(`"^v`")
return

:*:#s::
Send {Left}^+{Left}^c(@date>@dateval(`"^v`"))
return

#IfWinActive
; ##### /EVIEWS }}}

; vi: set foldmethod=marker:

