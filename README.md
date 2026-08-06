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
| `Shift+Alt+Arrows` | PgUp / PgDn / Home / End |
| `Ctrl+Shift+V` | Paste as plain text |
| `Ctrl+Alt+B` | Sign-off snippet |

Three hotkeys only act in a particular context:

- **`Ctrl+V` in RStudio / Rgui** rewrites `\` to `/`, so a path copied from
  Explorer pastes straight into R. It only fires when the clipboard is a
  single-line Windows path, so pasted code containing escapes (`"\\d"`,
  `"\n"`, LaTeX) is left alone.
- **`Ctrl+C` in a PDF** (Adobe Reader, or any window whose title contains
  `.pdf`) rejoins the hard-wrapped lines, keeps paragraph breaks, and repairs
  words hyphenated across a line break.
- **`Ctrl+F10` / `Shift+F10`** map to `Ctrl+Insert` / `Shift+Insert`, on the
  Zbook only. Machine-specific bindings are scoped with `#HotIf
  A_ComputerName = ...` — a plain `if` will not work, because hotkeys are
  registered at load time and would end up active everywhere.

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
| Brave, RStudio, Adobe Reader | Resolved by name through the App Paths registry key |

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
