# conf

Personal configuration files. Nothing here is installed automatically — each
piece has to be linked or copied into place on a new machine, see below.

## AutoHotkey

`AutoHotkey/autostart.ahk` is the single AHK script, written for
**AutoHotkey v2**. It is organised into vim fold sections (`{{{` / `}}}`).

### Hotkeys

`^` Control · `!` Alt · `+` Shift · `#` Win

| Key | Action |
| --- | --- |
| `Win+Shift+R` | Reload the script |
| `Win+Shift+F2` | Edit the script in gvim |
| `Win+Shift+Esc` | Suspend / resume all hotkeys |
| `Win+1` | mongeau.net/q |
| `Win+Shift+C` / `E` / `W` / `P` | Calculator, Excel, Word, PowerPoint |
| `Win+Shift+V` | gvim |
| `Win+Shift+B` | Brave, new tab, cursor in the address bar |
| `Win+Shift+N` | New scratch note |
| `Win+Shift+T` | Summon the scratch window, or minimize it |
| `Alt+`&#96; | Cycle the windows of the front app |
| `Shift+Alt+Arrows` | PgUp / PgDn / Home / End |
| `Ctrl+F10` | Copy (sends `Ctrl+Insert`) |
| `Shift+F10` / `Ctrl+Shift+F10` | Paste (sends `Shift+Insert`) |
| `Ctrl+Shift+V` | Paste as plain text |
| `Ctrl+Alt+B` | Sign-off snippet |
| `Ctrl+Alt+D` | Today's date, `YYYY-MM-DD` |
| `Ctrl+Alt+P` | Rewrite the clipboard path's `\` as `/` |

Three of those have a detail worth knowing:

- **The launcher keys focus before they launch.** `Win+Shift+E` / `W` / `P` /
  `V` activate a running Excel, Word, PowerPoint or gvim instead of starting a
  second copy. The gvim key deliberately ignores the scratch window (matched on
  the `[SCRATCH]` title tag), so "open an editor" and "summon my notes" stay
  two different keys. Calculator is left alone — it is a UWP app and
  single-instance already.
- **`Alt+`&#96; is bound by scancode** (`!SC029`), not as `` !` ``. That key is
  only a backtick on a US layout; on an Italian one it prints `\`, and a
  character-based hotkey would silently fail to register. The scancode is the
  physical key above Tab whatever it prints.
- **`Ctrl+Alt+P` refuses to touch anything that isn't clearly a path.** It
  checks for `C:\…` or `\\server\share` on a single line first, so hitting it
  by accident over a regex, a `"\n"` or a LaTeX snippet leaves the clipboard
  alone rather than quietly mangling it. Quotes from Explorer's "Copy as path"
  are kept — pasted into R or a shell, a quoted path is what you want.

The F10 copy/paste pair has two details worth not re-breaking:

- They send `{Blind}{Insert}`, not `^{Insert}`. You are physically holding the
  modifier when the hotkey fires, and a plain `Send` releases and re-presses it
  around the Insert — terminals and browsers drop that. Blind mode leaves your
  modifier alone and injects the bare `Insert`.
- They are **global on purpose**. This was originally written as `if
  (A_ComputerName == <the Zbook>)`, which never scoped anything: hotkeys
  register at load time, so the `if` had no effect and the remaps were live on
  every machine. Scoping it "correctly" removes copy/paste from every other
  machine. If you ever do want it scoped, `#HotIf A_ComputerName = ...` is the
  form that works.

### Scratch notes

`Win+Shift+N` opens a dated note (`~\notes\YYYY-MM-DD-HHmm.md`) as a **tab** in
a single gvim instance running as the server `SCRATCH`, rather than starting a
new window each time. Pressing it twice inside the same minute reopens the same
note instead of littering the folder.

The notes directory is set by `NotesDir()` at the top of the section.

### Requirements

Paths are hardcoded where the executable is not resolvable by name:

| Needs | Why |
| --- | --- |
| AutoHotkey **v2** | `AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe` |
| gvim, built `+clientserver` | Not on `PATH` and no App Paths entry, so the full path is spelled out. `+clientserver` is what makes the scratch tabs work |
| Brave, Excel, Word, PowerPoint | Resolved by name through the App Paths registry key |

PowerPoint is launched as `powerpnt`, not `powerpoint` — App Paths has no
entry under the longer name.

### Installing

The script does not start itself. Register it by dropping a shortcut in the
Startup folder:

```powershell
$s = (New-Object -ComObject WScript.Shell).CreateShortcut(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\autostart-ahk.lnk")
$s.TargetPath = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$s.Arguments  = '"' + $env:USERPROFILE + '\conf\AutoHotkey\autostart.ahk"'
$s.Save()
```

The shortcut stores an absolute path, so it has to be recreated if this
repository moves. Delete that one `.lnk` to undo.

To check the script parses without running it:

```
AutoHotkey64.exe /validate AutoHotkey\autostart.ahk
```

Worth doing after any edit: v2 treats a reference to an unknown variable as a
*load-time* error, so a single typo stops the whole script from starting rather
than just breaking one hotkey.

## R

`.RProfile` holds a set of long-standing convenience helpers and session
defaults, loaded into an attached environment at startup. It has accumulated
over many years and is due for a rethink — treat it as unstable for now.
