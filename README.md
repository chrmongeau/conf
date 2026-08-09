# conf

Personal configuration files, deployed by [chezmoi]. Every target is
`$HOME`-relative, so nothing here hardcodes a machine, a user or an employer
path.

[chezmoi]: https://www.chezmoi.io

## Installing

```sh
# new machine — clones this repo and deploys everything
chezmoi init --apply https://github.com/chrmongeau/conf.git

# existing machine — pull the repo, then deploy what changed
chezmoi update

# ...and --init as well, whenever .chezmoi.toml.tmpl has changed
chezmoi update --init
```

**`chezmoi init <url>` does nothing once the source directory exists.** It
does not pull and it does not regenerate the config, so re-running the
install line to pick up a fix leaves the machine exactly as it was and the
fix appears not to work. `update` is the pull; `--init` is what re-renders
the config from its template. When in doubt, `chezmoi update --init` is
always safe.

chezmoi itself: `winget install twpayne.chezmoi` on Windows, or the `.deb`
from the [releases page] on Debian and Ubuntu.

[releases page]: https://github.com/twpayne/chezmoi/releases

**On a fresh Windows install, PowerShell refuses to run scripts at all** —
`LocalMachine` is `Restricted`, and the `run_once_` scripts die with
`UnauthorizedAccess` before executing a line. The config template handles it
by invoking them with `-ExecutionPolicy Bypass`, which applies to that one
invocation and changes nothing about the machine's policy. A machine where
this seems not to be a problem is one where somebody set `CurrentUser` to
`RemoteSigned` at some point — check with `Get-ExecutionPolicy -List` before
concluding the default works.

That fix covers chezmoi only. A PowerShell profile of your own stays blocked
until you set the policy yourself, which is a real change to the machine and
deliberately not something an apply does for you.

`chezmoi diff` shows what an apply *would* change and writes nothing, which
is the right thing to run first on a machine that has been edited by hand.
`chezmoi status` is the terse version of the same question. Neither needs a
network connection.

`init` clones into `~/.local/share/chezmoi`, and `home/.chezmoi.toml.tmpl`
then writes `~/.config/chezmoi/chezmoi.toml` pointing back at it. That config
is machine-local and untracked — it names a path that differs on every
machine, the one thing that cannot live in the repository it points at.

`sourceDir` is derived from `.chezmoi.sourceDir` rather than written
literally, so a checkout kept somewhere you actually work in survives a
re-init instead of being quietly reset to the default location. The template
takes the parent, because `.chezmoi.sourceDir` resolves to the `home/`
subdirectory that `.chezmoiroot` selects.

### How it is laid out

`.chezmoiroot` points chezmoi at `home/`, so only that subtree is treated as
configuration. This file, `examples/` and `StrokesPlus.xml` sit outside it
and are never deployed.

Inside `home/`, names encode what happens to the file:

| Name | Becomes | Why |
| --- | --- | --- |
| `dot_Rprofile` | `~/.Rprofile` | leading dots in the source tree hide files from tooling |
| `dot_claude/executable_statusline.sh` | `~/.claude/statusline.sh`, mode 755 | the one file that needs `+x` |
| `dot_claude/settings.json.tmpl` | rendered per machine | Windows carries a smaller plugin set |
| `.chezmoiignore` | — | drops targets that do not belong on this machine |
| `.chezmoiexternal.toml` | — | the vim config, cloned from its own repository |
| `run_once_after_*.ps1.tmpl` | — | setup that is not a file: see below |

The two `run_once_` scripts set `R_USER` and register the AutoHotkey startup
shortcut. They are Windows-only, achieved by rendering to nothing elsewhere —
chezmoi skips an empty script. They record only *successful* runs, so a
failure is retried on the next apply rather than silently marked done.

**Things that stay manual**, because they hold machine-local or private
values and are gitignored: `~/.config/git/config.personal` and
`~/.claude/settings.local.json`. `examples/` holds a starting point for each.

## AutoHotkey

`home/dot_config/autohotkey/autostart.ahk` is the single AHK script, written
for **AutoHotkey v2**. It is organised into vim fold sections (`{{{` /
`}}}`).

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

**The flow must write one file per alert** into
`%OneDriveCommercial%\AHK\alerts` — a *new* file each time, not one file
rewritten, since OneDrive's "create file" is far more predictable than an update
and two meetings starting close together then cannot overwrite each other:

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

`chezmoi apply` writes the script to `~/.config/autohotkey/` and
`run_once_after_20-windows-ahk-startup.ps1` registers the Startup shortcut
that launches it. AutoHotkey v2 must already be installed — the script exits
with an error naming the winget command if it is not, and the next apply
retries.

The script is **not** run out of this repository. Doing so would save a copy
but tie the login to wherever the checkout happens to sit: moving or deleting
it would silently kill every hotkey at the next login. It is self-contained —
no `#Include`, no `A_ScriptDir` — so its location does not affect behaviour.

The shortcut stores an absolute path, so it has to be recreated if `$HOME`
moves. Delete the one `.lnk` to undo, and `chezmoi state delete-bucket
--bucket=scriptState` to let the registering script run again.

To check the script parses without running it:

```
AutoHotkey64.exe /validate %USERPROFILE%\.config\autohotkey\autostart.ahk
```

Worth doing after any edit: v2 treats a reference to an unknown variable as a
*load-time* error, so a single typo stops the whole script from starting rather
than just breaking one hotkey.

## Git

The config lives in `~/.config/git/`, not as `~/.gitconfig` — git has looked
there for years, and it keeps half a dozen fragments out of `$HOME`. It is
portable across Linux, WSL and Git for Windows; everything platform- or
identity-specific is split into separate files pulled in with `[include]`, and
only the non-identity ones belong in this repo.

Every include is a **relative** path. Git resolves those against the directory
of the including file, so nothing depends on `~` expanding and the directory
works wherever it lands.

### What is here, and what deliberately is not

| File | In the repo? | Why |
| --- | --- | --- |
| `dot_config/git/config` | **yes** | Portable settings. Carries the name but no address |
| `dot_config/git/config.winfs` | **yes** | `core.fileMode=false` for repos on `/mnt/c`, used from WSL. Pure settings |
| `dot_config/git/ignore` | **yes** | Global excludes. Git's default `core.excludesFile`, so nothing points at it |
| `dot_config/git/attributes` | **yes** | Global attributes. Git's default `core.attributesFile` |
| `examples/git-config.personal.example` | **yes** | Template for the file below |
| `config.personal` | no | Default email **and** the rule that overrides it. Kept out so no address is ever committed as file content |
| `config.fao` | no | The work email, one line, pulled in by that rule |
| `config.local` | no | Per-machine: credential username, editor, NTFS quirks. Genuinely differs between machines |

The `.gitignore` at the repo root lists the excluded patterns, so copying one in
by accident cannot turn into a commit. The patterns carry no leading slash, so
they match at any depth — inside `home/dot_config/git/` as much as at the
root.

Worth knowing: the personal address is already in this repo's **commit
metadata** from earlier commits. Keeping it out of a tracked file stops it being
added as greppable file content, but it does not retroactively hide it.

### Installing

`chezmoi apply` writes `config`, `ignore` and `attributes` into
`~/.config/git/`. `config.winfs` is deployed **only on WSL** — the
`.chezmoiignore` template drops it elsewhere, since `checkStat` and
`trustctime` only make sense where WSL git and Git for Windows share one
checkout. Hostname cannot make that decision: WSL and Windows report the same
name on one box, so the test is the kernel release string.

`config.personal` stays manual and gitignored — copy it in and edit the
address:

```sh
cp examples/git-config.personal.example ~/.config/git/config.personal
```

**If `~/.gitconfig` exists it wins**, so migrating means moving the old file,
not just creating the new one — otherwise nothing appears to change.

`config.fao` and `config.local` are optional — git ignores a missing include
silently. Without `config.personal` there is no `user.email` at all and git
refuses to commit, which is the intended failure rather than committing under
the wrong address.

### How the work identity is picked

`config` contains no address and no condition — it just pulls in
`config.personal`, which holds the default address *and* the rule: anything
whose remote URL contains `fao` gets `config.fao` instead.

Two conditions are needed, not one, because git treats `/` as significant in
these globs exactly as `.gitignore` does:

| Pattern | Matches `fao` in |
| --- | --- |
| `**/*fao*/**` | a directory component — `github.com/un-fao/x` |
| `**/*fao*` | the repo name itself — `github.com/me/faostat` |

Neither covers both alone. `**fao**` matches **nothing** — `**` is only special
as a whole path component. Both forms also match `ssh` remotes
(`git@github.com:un-fao/x.git`), which the older `**/un-fao/**` pattern did not.

Everything ideally lives in one file, but it cannot: `[includeIf]` can only name
a **path**, git has no syntax for a conditional value, and a file that includes
itself dies with `exceeded maximum include depth (10)`. So the work address sits
in its own one-line file. Two files is the floor.

Verified on both gits — org-`fao`, repo-name-`fao` and `ssh` remotes all resolve
to the work address; everything else to the personal one.

Checking what applies where is `git config --show-origin --get user.email`, or
the `whence` alias for everything at once. Note that `git config --global --get`
does **not** expand includes — git turns them off whenever a specific file is
named — so it reports an empty address and that is not a fault. Drop `--global`,
or use `git var GIT_AUTHOR_IDENT` to see what a commit would really use.

## Claude Code

`home/dot_claude/` holds the shareable part of `~/.claude` — about 14 KB out
of a directory that is otherwise ~445 MB of live state (transcripts,
credentials, plugin caches, and `projects/`, which also holds the memories).
None of that belongs in a repo, so the config is deployed into the directory
rather than the directory being the repo.

| File | Holds |
| --- | --- |
| `settings.json.tmpl` | Model, theme, editor mode, permissions, statusline |
| `executable_statusline.sh` | Two-line status bar; needs `jq` |
| `CLAUDE.md` | Global instructions, loaded every session |

`settings.json` is a template for one reason: Windows runs a smaller plugin
set, because `document-skills` needs LibreOffice, pandoc, poppler and Node,
and its marketplace is only registered where it is used. Everything else in
the file is identical on every machine.

`settings.local.json` is **not** deployed — see
`examples/settings.local.example.json`.

**`attribution.commit` and `attribution.pr` are set to empty strings.** That
removes the `Co-Authored-By` trailer and the *Generated with Claude Code*
footer at the source — the instruction never reaches the model, so it cannot
be forgotten in a long session. It is a settings key, not a request, which is
why it belongs here rather than in `CLAUDE.md`.

**No hooks are configured, and that is deliberate.** A wrap-width hook and a
`git push` confirmation hook were both built and both removed. The width one
had no way to tell prose from a table or a diagram, so it rejected content
that genuinely cannot be wrapped. The push one turned every push into a
question, which stalls any unattended run at the one moment nobody is
watching. Rules that need judgment about *what* is being written, or that
must not block when no one is at the keyboard, belong in `CLAUDE.md` rather
than in the harness.

`editorMode` puts the prompt input in vim mode, with `jj` remapped to Escape
in insert mode — the same habit as the vim config. `autoCompactWindow` defers
auto-compaction to 800k tokens, which only makes sense while the model is a
1M-context one; on a 200k model the threshold is never reached and compaction
effectively stops.

`effortLevel` and `alwaysThinkingEnabled` are set to what is already the
default in 2.1.226 — thinking is on unless explicitly `false`, and effort
resolution falls back to `high`. They are written out anyway so an upstream
change of default does not silently change behaviour here.

Without `jq`, `statusline.sh` prints an install hint instead of a status bar
rather than failing silently. It reads `resets_at` as Unix epoch seconds,
which is what Claude Code pipes in, and hides the plan-limit segment until
the first API response of the session supplies one.

`settings.local.json` is for anything machine-specific and is gitignored,
along with `.credentials.json` and `.claude.json`. Permission rules are the
usual reason to need it — they tend to embed absolute paths and machine
names.

Keep `CLAUDE.md` short. Every line is re-read at the start of every session,
in every project, so a line earns its place only if it changes behaviour;
description of the user or narrative about past sessions does not.

### Skills

`enabledPlugins` in `settings.json` names what should be active, but it only
enables — a new machine needs them installed first. `claude-plugins-official`
is registered automatically; the marketplace holding the document skills is
not.

```sh
claude plugin install frontend-design@claude-plugins-official
claude plugin install skill-creator@claude-plugins-official
claude plugin marketplace add anthropics/skills
claude plugin install document-skills@anthropic-agent-skills
```

`fao-design-system` is deliberately **not** tracked here. It lives in
`~/.claude/skills/fao-design-system`, next to the zip it was unpacked from,
and it stays out of this repo because it bundles FAO's Design System v3.6.8
minified CSS and the official logos — brand assets that do not belong in a
public repository. Copy the directory across by hand, or re-unpack the zip.

### The document-skills plugin

`xlsx`, `docx`, `pptx` and `pdf` add no capability that `openpyxl` and
`python-docx` lack. What they add is the failure knowledge — that `openpyxl`
writes formulas with no cached value, that Word fragments a visible phrase
across `<w:r>` runs so a find-and-replace on the XML matches nothing, that an
untracked redline is invisible in the accepted view — plus helper scripts for
each.

Their `SKILL.md` files say the dependencies are preinstalled. That refers to
Anthropic's container, not to a Debian or WSL box. Installing them:

```sh
sudo apt install libreoffice-calc libreoffice-writer tesseract-ocr
pip3 install --user --break-system-packages pdfplumber markitdown \
  defusedxml reportlab pikepdf
npm config set prefix ~/.npm-global && npm install -g docx pptxgenjs
```

**`soffice` being on `PATH` does not mean the skills work.** A LibreOffice
install can lack Calc and Writer while still providing `soffice`; every
spreadsheet then fails to load with "source file could not be loaded", and
`recalc.py` reports that as a timeout because it waits out its clock for
output that never comes. Check for `localc` and `lowriter`, not `soffice`.

**`NODE_PATH` belongs in `.profile`, not `.bashrc`.** The skills call
`require('docx')` bare, and Node does not search the npm global prefix on its
own. `.bashrc` returns early for non-interactive shells, which is how tool
commands run, so an export at the end of that file never executes.

`pip3` needs `--break-system-packages` on Debian 12+: the interpreter is
marked externally managed and refuses a plain install. `--user` keeps it out
of the system tree, so neither flag needs `sudo`.

None of this exists on the Windows install, which has no LibreOffice, pandoc,
poppler or Node. Run document work from WSL against the `/mnt/c` path — the
files sit on the Windows filesystem either way.

## R

`.Rprofile` holds a set of long-standing convenience helpers, assigned into an
environment that is `attach()`ed at startup so they are always available. It has
accumulated over many years and is due for a rethink — treat it as unstable for
now.

The **case matters**: R looks for `.Rprofile`, and a file named `.RProfile` is
silently ignored on Linux and WSL while working fine on Windows and macOS, whose
filesystems are case-insensitive. It was spelled the second way here for years
without anyone noticing.

### Installing

`chezmoi apply` writes `~/.Rprofile`, and on Windows
`run_once_after_10-windows-r-user.ps1` sets the environment variable that
makes R look there at all.

**Windows needs `R_USER`.** R does not treat `%USERPROFILE%` as `~` there: it
uses the shell's "personal" folder, which OneDrive redirects to Documents. So
`~` reported `…\OneDrive - <org>\Documents` and the profile had to sit there,
outside `$HOME` and under a path containing the employer's name. `R_USER`
overrides that, which is what keeps every file in this repository addressable
as `$HOME/<something>`. It does not disturb the package library — that lives
under `AppData\Local\R` and is unaffected — but `~` also governs `.Rhistory`
and Rgui's file dialogs, so those move with it.

The variable only applies to processes started after it is set, so an open
terminal or a running RStudio keeps the old value until restarted. The copy
in the Documents folder is kept as a fallback until RStudio is confirmed to
honour `R_USER`; once it is, that copy should be deleted rather than left to
drift.

Most of the profile is wrapped in `interactive()`, so `Rscript` legitimately
shows none of it — check with `R --interactive`, or by testing whether
`.startup` appears in `search()`.

## Vim

**Not in this repo.** The vim configuration lives in its own:
[chrmongeau/vimfiles](https://github.com/chrmongeau/vimfiles).

That split is deliberate. Everything else here is a file *deployed* to a
destination; vimfiles is a runtime directory that has to *be* the destination —
`autoload/`, `after/`, `colors/` are only found if vim's `runtimepath` points at
them. Cloning keeps it editable and committable in place, which a copy would
throw away and a submodule would duplicate.

chezmoi handles it as a `git-repo` external in `home/.chezmoiexternal.toml`,
so `chezmoi init --apply` clones it along with everything else. No separate
step, and nothing to forget.

| Platform | Clone to | Entry point |
| --- | --- | --- |
| Windows | `~\vimfiles` | `~\_vimrc`, a one-line stub: `source $HOME/vimfiles/vimrc` |
| Linux / WSL | `~/.vim` | none needed — vim reads `~/.vim/vimrc` natively since 7.4 |

Those destinations are **vim's own defaults**, not a preference: the
compiled-in `'runtimepath'` is `$HOME/vimfiles` on MS-Windows and
`$HOME/.vim` on Unix, so a stock Windows vim never reads `.vim`. The
external file is templated on `.chezmoi.os` for that reason.

`refreshPeriod = "168h"` makes a `chezmoi apply` pull vimfiles at most
weekly; `chezmoi apply -R` forces it. Without a refresh period the clone
is created once and **never pulled again**, which is a quiet way to run a
year-old vim config.

Two things in this repo depend on vim being present, so they are worth
checking after a fresh install: the scratch notes need **gvim built
`+clientserver`** (see Requirements), and `~/.config/git/config.local` sets
`core.editor = vim`, so an unconfigured vim means bare commit-message
editing.
