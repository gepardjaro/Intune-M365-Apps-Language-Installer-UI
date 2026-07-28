# Intune M365 Apps Language Installer UI

A language picker your users can actually use, for Microsoft 365 Apps. It ships
through Intune as a PSADT 4.1.x package.

Here's the flow: the user opens the app in Company Portal, ticks whichever
languages they want from a list of 50, and hits **Install**. The package builds an
Office Deployment Tool (ODT) config right there on the spot and installs just
those language packs. No separate Intune app per language. No ticket to the
service desk.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)
![PSADT](https://img.shields.io/badge/PSADT-4.1.x-blue)
![Intune](https://img.shields.io/badge/Intune-Win32%20app-0078D4)

---

## Contents

- [How it works](#how-it-works)
- [What you need](#what-you-need)
- [Installation](#installation)
  - [1. Build the PSADT package folder](#1-build-the-psadt-package-folder)
  - [2. Paste the Install section](#2-paste-the-install-section)
  - [3. Paste the Post-Install section](#3-paste-the-post-install-section)
  - [4. Add the company logo](#4-add-the-company-logo)
  - [5. Package and upload to Intune](#5-package-and-upload-to-intune)
- [Intune configuration](#intune-configuration)
  - [Detection rule options](#detection-rule-options)
- [The self-destructing detection key](#the-self-destructing-detection-key)
- [Repository files](#repository-files)
- [Logging](#logging)
- [Supported languages](#supported-languages)
- [Notes and known limitations](#notes-and-known-limitations)

---

## How it works

The package runs as **SYSTEM**, but the picker needs to show up in the **user's**
session. Those two things don't mix, so the work gets split across two PSADT
phases:

```
Install phase (SYSTEM)
  │
  ├─ Start-ADTProcessAsUser ──► LanguageSelector.ps1 runs in the user session
  │                              (WinForms dialog, TopMost, 50 languages)
  │                                    │
  │   ◄── waits (-WaitForChildProcesses) ┘
  │
  ├─ reads  %PUBLIC%\M365_SelectedLangs.txt   ← one locale code per line
  │      │
  │      ├─ file exists  → build LanguageConfig.xml → setup.exe /configure  → continue
  │      └─ file missing → user cancelled          → Close-ADTSession 1602
  │
Post-Install phase (SYSTEM)
  │
  ├─ create HKLM:\SOFTWARE\M365LanguagePacks  InstallComplete = "True"
  └─ spawn detached process: sleep 30s, then delete that key
```

The picker's only job is writing down what the user chose. It never touches
Office. Every bit of the actual install happens in the Install section, under
SYSTEM.

## What you need

| Requirement | Notes |
|---|---|
| **PSADT 4.1.x** | A working package folder — the toolkit's standard `Invoke-AppDeployToolkit.ps1` frontend |
| **ODT `setup.exe`** | Grab it from [Microsoft](https://www.microsoft.com/en-us/download/details.aspx?id=49117). It isn't shipped in this repo, so fetch a current copy yourself. |
| **Microsoft 365 Apps already installed** | The generated XML uses `Version="MatchInstalled"`, so it layers languages onto whatever is already there |
| **`company_logo.png`** *(optional)* | Your own branding. See [step 4](#4-add-the-company-logo). |
| **Windows PowerShell 5.1** | The snippets call `powershell.exe` (5.1) on purpose, not `pwsh` |

## Installation

### 1. Build the PSADT package folder

Drop these into your PSADT package's **`Files\`** folder:

```
YourPSADTPackage\
├── Invoke-AppDeployToolkit.ps1      ← you paste into this (steps 2 and 3)
├── PSAppDeployToolkit\              ← PSADT 4.1.x module
├── Files\
│   ├── LanguageSelector.ps1         ← from this repo
│   ├── setup.exe                    ← ODT, download from Microsoft
│   ├── company_logo.png             ← your logo (optional, see step 4)
│   └── LanguageConfig.xml           ← generated at runtime, do not create by hand
└── ...
```

Don't bother creating `LanguageConfig.xml` yourself. The Install section writes it
on every run with `Out-File -Force`, so any copy you ship just gets flattened and
ignored. One consequence worth knowing: the `Files\` folder has to be **writable
at runtime**. That's fine for the usual pattern, where the package is staged to a
local folder before `Invoke-AppDeployToolkit.exe` fires. Run it straight off a
read-only share and it will fail.

### 2. Paste the Install section

Open [`Install_Invoke-AppDeployToolkit.ps1.txt`](Install_Invoke-AppDeployToolkit.ps1.txt)
and paste the contents into `Invoke-AppDeployToolkit.ps1`, under the Install
marker:

```powershell
##================================================
## MARK: Install
##================================================
$adtSession.InstallPhase = $adtSession.DeploymentType

## <Perform Installation tasks here>
        # ↓↓↓ paste Install_Invoke-AppDeployToolkit.ps1.txt here ↓↓↓
```

What that code does, in order:

1. Resolves paths from `$adtSession.DirFiles` — that's the PSADT v4 session variable, **not** the old v3 `$dirFiles`
2. Launches `LanguageSelector.ps1` in the user session with `Start-ADTProcessAsUser … -WaitForChildProcesses`
3. Reads `%PUBLIC%\M365_SelectedLangs.txt`
4. Builds `LanguageConfig.xml`, one `<Language ID="…" />` per selection
5. Runs `setup.exe /configure` hidden
6. Deletes the handoff file
7. If there's no file, the user backed out — it calls `Close-ADTSession -ExitCode 1602`

### 3. Paste the Post-Install section

Same idea with [`Post-Install_Invoke-AppDeployToolkit.ps1.txt`](Post-Install_Invoke-AppDeployToolkit.ps1.txt),
under the Post-Install marker:

```powershell
##================================================
## MARK: Post-Install
##================================================
$adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

## <Perform Post-Installation tasks here>
        # ↓↓↓ paste Post-Install_Invoke-AppDeployToolkit.ps1.txt here ↓↓↓
```

This writes the detection marker and schedules its own deletion. There's a whole
section on why below: [The self-destructing detection key](#the-self-destructing-detection-key).

### 4. Add the company logo

**Yes, `company_logo.png` goes in `Files\`**, right next to
`LanguageSelector.ps1`. The script looks for it relative to itself:

```powershell
$LogoPath = Join-Path -Path $PSScriptRoot -ChildPath "company_logo.png"
```

So the **location matters** — same folder as the script — but the **file itself is
optional**. The load sits inside a `Test-Path` and a `try/catch`, so a missing or
broken logo just gives you a dialog with a blank white header. Nothing breaks.

| | |
|---|---|
| Filename | `company_logo.png` — exact, case-insensitive |
| Location | Same folder as `LanguageSelector.ps1` (that's `Files\`) |
| Source image | 683 × 125 works best |
| Displayed at | 342 × 63, `SizeMode = Zoom`, so the aspect ratio holds and other sizes still look fine |
| Background | The header panel is white, so pick a logo that reads on white |

No logo is committed here. Bring your own.

### 5. Package and upload to Intune

Wrap the folder with `IntuneWinAppUtil.exe` like any other PSADT package, then set
it up using the table below.

## Intune configuration

| Setting | Value |
|---|---|
| Install command | `Invoke-AppDeployToolkit.exe -DeploymentType "Install" -DeployMode "Interactive"` |
| Uninstall command | *(see [limitations](#notes-and-known-limitations) — there's no uninstall)* |
| Install behavior | **System** |
| Device restart behavior | Determine behavior based on return codes |
| Return code `1602` | Map it however suits you — it means "user cancelled the picker" |
| Detection rule | Either a **custom script** → [`Detect-M365LanguagePack.ps1`](Detect-M365LanguagePack.ps1), or a **manually configured registry rule** — see [Detection rule options](#detection-rule-options) |
| Run script as 32-bit | No |

> [!IMPORTANT]
> **Deploy mode has to be `Interactive`.** In `Silent` mode PSADT hides its own
> dialogs, which defeats the entire point of a package built around a dialog.
> Assign the app as **Available**, not Required, so users pull it from Company
> Portal when they actually want a language. A Required assignment would throw the
> picker on screen at some random moment nobody asked for.

### Detection rule options

Both options hunt for the same marker: `HKLM:\SOFTWARE\M365LanguagePacks\InstallComplete`,
written by the Post-Install section. Pick one. Don't configure both.

**Option A — custom detection script** (`Rules format: Use a custom detection script`):
upload [`Detect-M365LanguagePack.ps1`](Detect-M365LanguagePack.ps1), set *Run
script as 32-bit* to **No** and *Enforce script signature check* to **No**.

**Option B — manually configured registry rule** (`Rules format: Manually configure
detection rules` → **Add** → *Rule type: Registry*):

| Field | Value |
|---|---|
| Key path | `HKEY_LOCAL_MACHINE\SOFTWARE\M365LanguagePacks` |
| Value name | `InstallComplete` |
| Detection method | String comparison |
| Operator | Equals |
| Value | `True` |
| Associated with a 32-bit app on 64-bit clients | **No** |

*Value exists* is fine too, and a bit more forgiving since it doesn't care what the
marker says. Either way, leave the 32-bit toggle on **No**. Post-Install writes to
the native 64-bit hive, so a 32-bit rule would go looking in `WOW6432Node` and
never find anything.

Option B skips the script upload and the PowerShell round-trip on every detection
cycle, so it's the simpler pick. Keep Option A if you think you'll extend
detection later — say, to check which language packs are genuinely installed
instead of trusting a success marker.

> [!NOTE]
> The registry rule hits exactly the same timing race as the script. See
> [The self-destructing detection key](#the-self-destructing-detection-key).
> Neither option changes that.

## The self-destructing detection key

This is the trick that lets the app be run more than once. It works around a
specific Intune quirk: a Win32 app whose detection never matches shows up as
**Failed** in Company Portal, but an app whose detection matches *forever* can
never run again to add another language.

Post-Install threads that needle:

```powershell
$TempRegPath = "HKLM:\SOFTWARE\M365LanguagePacks"
New-ItemProperty -Path $TempRegPath -Name "InstallComplete" -Value "True" -PropertyType String -Force

# Detached process: wait, then remove the key
$CleanupCommand = "Start-Sleep -Seconds 30; Remove-Item -Path '$TempRegPath' -Force -Recurse ..."
Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"$CleanupCommand`""
```

Step by step:

1. Install wraps up, and Post-Install creates the marker under
   `HKLM:\SOFTWARE\M365LanguagePacks`.
2. A **detached** `powershell.exe` spawns. Detached matters here — it means PSADT
   can exit straight away instead of sitting through a 30-second sleep.
3. PSADT exits `0`. Intune runs detection, records a clean **success**, and
   Company Portal stays free of red.
4. Roughly 30 seconds later, the background process wipes the key.
5. Next detection cycle, the app reads as **not installed** and flips back to
   **Available**, ready for another round of languages.

Treat the key as a *success signal*, nothing more. It deliberately holds no record
of which languages went in.

> [!WARNING]
> **This is a race, and it can bite.** If Intune's post-install detection lands
> more than ~30 seconds after the package exits, the key is already gone. Seeing
> flaky failures? Bump `Start-Sleep -Seconds 30` up to `60`. The trade-off cuts
> the other way, though: a longer window means the app sits there looking
> "installed" for longer before it becomes available again.

## Repository files

| File | Role |
|---|---|
| [`LanguageSelector.ps1`](LanguageSelector.ps1) | The picker UI. Goes in `Files\`. Runs in the user session and writes selected locale codes to `%PUBLIC%\M365_SelectedLangs.txt`. |
| [`Install_Invoke-AppDeployToolkit.ps1.txt`](Install_Invoke-AppDeployToolkit.ps1.txt) | Paste into the **Install** section. UI launch → XML generation → ODT install. |
| [`Post-Install_Invoke-AppDeployToolkit.ps1.txt`](Post-Install_Invoke-AppDeployToolkit.ps1.txt) | Paste into the **Post-Install** section. The self-destructing detection marker. |
| [`Detect-M365LanguagePack.ps1`](Detect-M365LanguagePack.ps1) | Intune custom detection script. Checks `HKLM:\SOFTWARE\M365LanguagePacks` for the `InstallComplete` value that Post-Install writes. |

Those two files end in `.txt` on purpose. They're fragments meant to be pasted
into an existing `Invoke-AppDeployToolkit.ps1`, not scripts you run on their own.

`LanguageSelector.ps1` is saved in the Windows-1252 codepage with no byte-order
mark, which is what Windows PowerShell 5.1 expects out of the box. If you edit it,
keep that encoding. Re-save it as BOM-less UTF-8 and you'll mangle the `å` in
"Norwegian Bokmål". Only the label on screen suffers — the value the script parses
out is the locale code `nb-no`.

## Logging

The Install and Post-Install snippets use PSADT's own `Write-ADTLogEntry`, so
everything ends up in the package's normal PSADT log, wherever the toolkit's
`LogPath` points (`%WinDir%\Logs\Software` by default). No separate log file to go
hunting for.

ODT keeps its own installation log at whatever path lands in the generated
`<Logging Path="…" />` element. The Install snippet sets that to `$env:TEMP`, which
resolves to the **SYSTEM** temp folder (`C:\Windows\Temp`) because the Install
phase runs as SYSTEM.

`LanguageSelector.ps1` doesn't log at all. It writes the selection file and that's
it.

## Supported languages

50 of them, defined in the `$Languages` ordered hashtable inside
`LanguageSelector.ps1` as `Display Name = locale-code`. Add or remove entries
there and both the list box and the generated XML follow along.

Afrikaans, Albanian, Arabic, Basque, Bulgarian, Catalan, Chinese (Simplified),
Chinese (Traditional), Croatian, Czech, Danish, Dutch, English (US), Estonian,
Finnish, French, Galician, German, Greek, Hebrew, Hindi, Hungarian, Indonesian,
Irish, Italian, Japanese, Kazakh, Korean, Latvian, Lithuanian, Macedonian, Malay,
Maltese, Norwegian Bokmål, Norwegian Nynorsk, Polish, Portuguese (Brazil),
Portuguese (Portugal), Romanian, Russian, Serbian (Latin), Slovak, Slovenian,
Spanish, Swedish, Thai, Turkish, Ukrainian, Vietnamese, Welsh.

Each row shows up as `Display Name (locale-code)`, and the code gets pulled back
out with a `\((?<code_val>[^)]+)\)$` match. That regex is anchored to the end of
the string, so names with their own parentheses — "Chinese (Traditional)", for
instance — still resolve properly.

## Notes and known limitations

- **There's no uninstall.** Pulling an Office language pack back off a machine is
  never clean, and this app is built as a re-runnable installer rather than
  something with a real lifecycle. Leave the Uninstall section as the toolkit
  default.
- **No prerequisite checks.** The Install section doesn't confirm Microsoft 365
  Apps is present, and it doesn't confirm `setup.exe` exists, before it puts the
  picker on screen. On a device with no M365, the user happily picks languages and
  then ODT falls over. Scope the Intune assignment — or add a requirement rule —
  to devices that actually have M365 Apps.
- **No filter, no Select All, no grey-out for what's already installed.** The
  dialog is a plain `CheckedListBox` with all 50 entries. Languages you already
  have look identical to the rest. Re-selecting one does no harm — ODT sees it as
  already present — but nothing in the UI tells the user that.
- **No update-channel detection.** The generated XML leans on
  `Version="MatchInstalled"` rather than pinning a channel.
- **The `%PUBLIC%` handoff is world-writable.** `M365_SelectedLangs.txt` sits in a
  folder any local user can write to, and its contents go into the ODT XML with no
  escaping. The blast radius is genuinely small: a crafted value produces
  malformed XML and a dead ODT run, inside a package that was already running as
  SYSTEM. Still, if that's a concern where you work, move the handoff somewhere
  only SYSTEM can reach and check each code against the `$Languages` table before
  it goes into the XML.
- **The dialog has no close button.** `ControlBox = $false`, so it's **Install** or
  **Cancel**. Cancel — or ticking nothing at all — gives you exit code `1602`.
- **PSADT's progress dialog overlaps.** `Show-ADTInstallationProgress` from the
  Pre-Install phase stays visible while the picker is open. The picker sets
  `TopMost = $true` so it sits in front.

## License

[MIT](LICENSE)
