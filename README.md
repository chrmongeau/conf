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
| `Win+Shift+M` | Show a test meeting alert |
| `Alt+`&#96; | Cycle the windows of the front app |
| `Shift+Alt+Arrows` | PgUp / PgDn / Home / End |
| `Ctrl+F10` | Copy (sends `Ctrl+Insert`) |
| `Shift+F10` / `Ctrl+Shift+F10` | Paste (sends `Shift+Insert`) |
| `Ctrl+Shift+V` | Paste as plain text |
| `Ctrl+Alt+B` | Sign-off snippet |
| `@q` / `@Q` (typed) | Sign-off: *Best,* / *Best regards,* + name |
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
- **`@q` / `@Q` are hotstrings, not hotkeys** — literally typed, replaced on the
  next space or Enter (which is then swallowed). The options matter: `C` makes
  them case-sensitive, without which `@Q` would fire the `@q` one; and there is
  deliberately no `*`, so the abbreviation only counts at a terminator and
  `@quantity` is left alone.

  `@` is chosen to survive a layout switch. Under *United States-International*
  — installed here alongside plain *US* — `'`, `"`, `` ` ``, `^` and `~` are
  dead keys, which rules out a backtick abbreviation; `@` is not one of them
  and stays plain Shift+2 in both layouts.

  Email addresses are the obvious worry, and AHK's default
  no-trigger-inside-a-word rule handles it: an `@` preceded by an alphanumeric
  never fires. `christian@quantum.com`, `foo@q.com` (where the `.` would
  otherwise terminate the abbreviation) and R's S4 slot access `obj@q` are all
  safe — which is why these are global, with no editor exclusion.
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

### Meeting alerts

A Power Automate flow announces meetings that are about to start. Teams' own
banner is easy to miss, so the flow also drops a file into OneDrive and the
script turns that into a large red always-on-top popup with a beep.

**The flow must write one file per alert** into `%OneDriveCommercial%\AHK\alerts`
— a *new* file each time, not one file rewritten, since OneDrive's "create file"
is far more predictable than an update and two meetings starting close together
then cannot overwrite each other:

| | |
| --- | --- |
| Folder | `AHK/alerts` in OneDrive |
| Name | anything sortable, e.g. `meeting-20260806-2115.txt` |
| Content | `subject \| HH:mm \| location \| webLink \| joinLink` |

Fields are split on content, not position: any field that looks like a URL
becomes a **button**, everything else is display text. So the links can be
appended in either order, an empty field costs nothing, and a meeting with no
online-meeting link just yields one fewer button. Buttons are named from the
URL — `teams.microsoft.com` → *Join Online Meeting*, an Outlook or OWA host →
*Open in Outlook*, anything else → *Open link*.

**Only `http`/`https` links get a button.** That is what keeps *Open in Outlook*
opening Outlook **on the web**: a desktop-handler URL such as `ms-outlook://`
fails the test and is ignored rather than launching a desktop client that isn't
used here. Clicking a button opens the link in the default browser and
dismisses the popup.

A link is also cut back to the first character a URL cannot contain. The join
link has no field of its own on the calendar trigger — it exists only inside the
invitation's HTML body, so the flow has to slice it out with string functions,
and that goes wrong easily. Trimming a stray `</p>` or quote here means a
slightly sloppy extraction still yields a working button. On the flow side,
slice on the full join prefix `https://teams.microsoft.com/meet/` — **not** on
the host. An invitation body carries several `teams.microsoft.com` URLs (the
Teams download link, "Meeting options", "Reset dial-in PIN"), and the join link
is rarely the first, so slicing on the host alone picks the wrong one. The
trailing slash matters too, or `/meet` also matches `meetingOptions`.

The script scans that folder every **5 minutes** (`MeetingScanMs()`). Note that
this interval comes off the warning time: a file landing just after a scan waits
a full interval, so the notice actually given is the flow's look-ahead **minus**
the scan interval **minus** OneDrive's sync latency. Five minutes is comfortable
against a 15-minute look-ahead; if the flow is ever changed to trigger closer to
the meeting, this has to come down with it. Files present at startup are
recorded as already-seen, so a reload never replays the last meeting. If
several appear at once the newest by filename wins, which is why the name
should sort chronologically. A file that cannot be read yet — OneDrive delivers
the placeholder before the contents — is left unseen and retried on the next
pass.

`Win+Shift+M` shows the popup without waiting for a meeting.

**This deliberately does not go through Teams or Windows notifications.** An
earlier version read the Windows notification store to catch the Teams card
directly; on this machine that could never work, because this build of Teams
renders its own banners and never publishes to Windows — confirmed with
do-not-disturb both on and off, and visible in Teams' settings as the
position/size controls that only a self-drawn notification can offer. That
version is in the history at commit `463fb0d`. Watching a file instead needs no
helper process at all, and cannot be broken by a Teams setting, a notification
style, or do-not-disturb.

### Requirements

Paths are hardcoded where the executable is not resolvable by name:

| Needs | Why |
| --- | --- |
| AutoHotkey **v2** | `AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe` |
| gvim, built `+clientserver` | Not on `PATH` and no App Paths entry, so the full path is spelled out. `+clientserver` is what makes the scratch tabs work |
| Brave, Excel, Word, PowerPoint | Resolved by name through the App Paths registry key |
| OneDrive, syncing | Delivers the meeting alert files. The folder is resolved from `%OneDriveCommercial%`, falling back to `%OneDrive%`, so the tenant name is not hardcoded |

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
