# Intune M365 Apps Language Installer UI

A user-facing language picker for Microsoft 365 Apps, deployed through Intune as a
PSADT 4.1.x package.

The end user opens the app in Company Portal, ticks the languages they want from a
list of 50, and clicks **Install**. The package generates an Office Deployment Tool
(ODT) configuration on the fly and installs exactly those language packs — no
per-language Intune app, no admin ticket.

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
- [The self-destructing detection key](#the-self-destructing-detection-key)
- [Repository files](#repository-files)
- [Logging](#logging)
- [Supported languages](#supported-languages)
- [Notes and known limitations](#notes-and-known-limitations)

---

## How it works

The package runs as **SYSTEM**, but the picker has to appear in the **user's**
session — so the work is split across two PSADT phases:

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

The picker writes only its **selection** to a file; it never touches Office
itself. All installation is done by the Install section under SYSTEM.

## What you need

| Requirement | Notes |
|---|---|
| **PSADT 4.1.x** | A working package folder (the toolkit's standard `Invoke-AppDeployToolkit.ps1` frontend) |
| **ODT `setup.exe`** | Download from [Microsoft](https://www.microsoft.com/en-us/download/details.aspx?id=49117). Not redistributed in this repo — fetch your own current copy. |
| **Microsoft 365 Apps already installed** | The generated XML uses `Version="MatchInstalled"`, so it layers languages onto the existing install |
| **`company_logo.png`** *(optional)* | Your own branding. See [step 4](#4-add-the-company-logo). |
| **Windows PowerShell 5.1** | The snippets invoke `powershell.exe` (5.1) explicitly, not `pwsh` |

## Installation

### 1. Build the PSADT package folder

Copy these into your PSADT package's **`Files\`** folder:

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

`LanguageConfig.xml` is written by the Install section on every run with
`Out-File -Force`, so it does **not** need to exist beforehand. Any copy you ship
is overwritten and ignored. This does mean the `Files\` folder must be
**writable at runtime** — fine for the normal pattern where the package is
staged to a local folder before `Invoke-AppDeployToolkit.exe` is launched, but it
will fail if you run the package directly from a read-only share.

### 2. Paste the Install section

Open the contents of [`Install_Invoke-AppDeployToolkit.ps1.txt`](Install_Invoke-AppDeployToolkit.ps1.txt)
and paste it into `Invoke-AppDeployToolkit.ps1` under the Install marker:

```powershell
##================================================
## MARK: Install
##================================================
$adtSession.InstallPhase = $adtSession.DeploymentType

## <Perform Installation tasks here>
        # ↓↓↓ paste Install_Invoke-AppDeployToolkit.ps1.txt here ↓↓↓
```

What it does:

1. Resolves paths from `$adtSession.DirFiles` (the PSADT v4 session variable — **not** the v3 `$dirFiles`)
2. Launches `LanguageSelector.ps1` in the user session via `Start-ADTProcessAsUser … -WaitForChildProcesses`
3. Reads `%PUBLIC%\M365_SelectedLangs.txt`
4. Builds `LanguageConfig.xml` with one `<Language ID="…" />` per selection
5. Runs `setup.exe /configure` hidden
6. Deletes the handoff file
7. If the user cancelled (no file), calls `Close-ADTSession -ExitCode 1602`

### 3. Paste the Post-Install section

Paste [`Post-Install_Invoke-AppDeployToolkit.ps1.txt`](Post-Install_Invoke-AppDeployToolkit.ps1.txt)
under the Post-Install marker:

```powershell
##================================================
## MARK: Post-Install
##================================================
$adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

## <Perform Post-Installation tasks here>
        # ↓↓↓ paste Post-Install_Invoke-AppDeployToolkit.ps1.txt here ↓↓↓
```

This writes the detection marker and schedules its own deletion — see
[The self-destructing detection key](#the-self-destructing-detection-key).

### 4. Add the company logo

**Yes — `company_logo.png` belongs in `Files\`**, alongside `LanguageSelector.ps1`.
The script resolves it relative to itself:

```powershell
$LogoPath = Join-Path -Path $PSScriptRoot -ChildPath "company_logo.png"
```

So the **location is required** (same folder as the script), but the **file is
optional**: the load is wrapped in `Test-Path` plus a `try/catch`, so a missing
or corrupt logo just renders the dialog with an empty white header. Nothing
fails.

| | |
|---|---|
| Filename | `company_logo.png` — exact, case-insensitive |
| Location | Same folder as `LanguageSelector.ps1` (i.e. `Files\`) |
| Source image | 683 × 125 recommended |
| Displayed at | 342 × 63, `SizeMode = Zoom` (aspect ratio preserved, so other sizes still look correct) |
| Background | The header panel is white — use a logo that reads on white |

No logo is committed to this repo; supply your own.

### 5. Package and upload to Intune

Wrap the folder with `IntuneWinAppUtil.exe` as you would any PSADT package, then
configure it per the table below.

## Intune configuration

| Setting | Value |
|---|---|
| Install command | `Invoke-AppDeployToolkit.exe -DeploymentType "Install" -DeployMode "Interactive"` |
| Uninstall command | *(see [limitations](#notes-and-known-limitations) — uninstall is not implemented)* |
| Install behavior | **System** |
| Device restart behavior | Determine behavior based on return codes |
| Return code `1602` | Map as needed — this is "user cancelled the picker" |
| Detection rule | Custom script → [`Detect-M365LanguagePack.ps1`](Detect-M365LanguagePack.ps1) |
| Run script as 32-bit | No |

> [!IMPORTANT]
> **Deploy mode must be `Interactive`.** In `Silent` mode PSADT suppresses its own
> dialogs, and the whole point of this package is a dialog. Assign the app as
> **Available** (not Required) so the user launches it from Company Portal when
> they want a language — a Required assignment would fire the picker at a moment
> nobody is expecting it.

## The self-destructing detection key

This is the trick that makes the app repeatable. It solves a specific Intune
problem: a Win32 app whose detection never matches is reported as **Failed** in
Company Portal, but an app whose detection *permanently* matches can never be run
a second time to add another language.

The Post-Install section threads that needle:

```powershell
$TempRegPath = "HKLM:\SOFTWARE\M365LanguagePacks"
New-ItemProperty -Path $TempRegPath -Name "InstallComplete" -Value "True" -PropertyType String -Force

# Detached process: wait, then remove the key
$CleanupCommand = "Start-Sleep -Seconds 30; Remove-Item -Path '$TempRegPath' -Force -Recurse ..."
Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"$CleanupCommand`""
```

Sequence:

1. Install finishes; Post-Install creates the marker under
   `HKLM:\SOFTWARE\M365LanguagePacks`.
2. A **detached** `powershell.exe` is spawned — detached so PSADT can exit
   immediately without waiting on the 30-second sleep.
3. PSADT exits `0`. Intune evaluates detection and records a clean **success**,
   so there is no red failure in Company Portal.
4. ~30 seconds later the background process deletes the key.
5. On the next detection cycle the app evaluates as **not installed** and returns
   to **Available**, ready to be run again for more languages.

The key is a *success signal*, not an inventory record. It intentionally holds no
list of installed languages.

> [!WARNING]
> **This is a timing race.** If Intune's post-install detection happens to run
> more than ~30 seconds after the package exits, the key is already gone. If you
> see intermittent failures, raise the `Start-Sleep -Seconds 30` to `60`. The
> trade-off is the reverse: too long a window and the app stays "installed" for
> that much longer before becoming available again.

## Repository files

| File | Role |
|---|---|
| [`LanguageSelector.ps1`](LanguageSelector.ps1) | The picker UI. Goes in `Files\`. Runs in the user session; writes selected locale codes to `%PUBLIC%\M365_SelectedLangs.txt`. |
| [`Install_Invoke-AppDeployToolkit.ps1.txt`](Install_Invoke-AppDeployToolkit.ps1.txt) | Paste into the **Install** section. UI launch → XML generation → ODT install. |
| [`Post-Install_Invoke-AppDeployToolkit.ps1.txt`](Post-Install_Invoke-AppDeployToolkit.ps1.txt) | Paste into the **Post-Install** section. Self-destructing detection marker. |
| [`Detect-M365LanguagePack.ps1`](Detect-M365LanguagePack.ps1) | Intune custom detection script. Checks `HKLM:\SOFTWARE\M365LanguagePacks`. |

The two `.txt` files are `.txt` deliberately: they are fragments meant to be
pasted into an existing `Invoke-AppDeployToolkit.ps1`, not run on their own.

`LanguageSelector.ps1` is stored in the Windows-1252 codepage without a byte-order
mark, which is what Windows PowerShell 5.1 expects by default. If you edit it,
keep that encoding — re-saving it as BOM-less UTF-8 mangles the `å` in "Norwegian
Bokmål". Only the display label is affected; the value parsed out of the list is
the locale code `nb-no`.

## Logging

The Install and Post-Install snippets use PSADT's own `Write-ADTLogEntry`, so
everything lands in the standard PSADT log for the package (per the toolkit's
configured `LogPath`, `%WinDir%\Logs\Software` by default) rather than in a
separate log file.

ODT writes its own installation log to the path in the generated
`<Logging Path="…" />` element — `$env:TEMP` as generated by the Install snippet,
which resolves to the **SYSTEM** temp folder (`C:\Windows\Temp`) because the
Install phase runs as SYSTEM.

`LanguageSelector.ps1` itself does not log; it only writes the selection file.

## Supported languages

50 languages, defined in the `$Languages` ordered hashtable in
`LanguageSelector.ps1` as `Display Name = locale-code`. Add or remove entries
there — the list box and the generated XML both derive from it.

Afrikaans, Albanian, Arabic, Basque, Bulgarian, Catalan, Chinese (Simplified),
Chinese (Traditional), Croatian, Czech, Danish, Dutch, English (US), Estonian,
Finnish, French, Galician, German, Greek, Hebrew, Hindi, Hungarian, Indonesian,
Irish, Italian, Japanese, Kazakh, Korean, Latvian, Lithuanian, Macedonian, Malay,
Maltese, Norwegian Bokmål, Norwegian Nynorsk, Polish, Portuguese (Brazil),
Portuguese (Portugal), Romanian, Russian, Serbian (Latin), Slovak, Slovenian,
Spanish, Swedish, Thai, Turkish, Ukrainian, Vietnamese, Welsh.

The dialog displays each entry as `Display Name (locale-code)` and parses the
code back out with a `\((?<code_val>[^)]+)\)$` match — anchored to the end of the
string so names that themselves contain parentheses, like "Chinese
(Traditional)", still resolve correctly.

## Notes and known limitations

- **Registry value names differ between the two scripts.** The Post-Install
  section writes `InstallComplete`; `Detect-M365LanguagePack.ps1` reads
  `InstalledLanguages`. Both act on the same key,
  `HKLM:\SOFTWARE\M365LanguagePacks`.
- **Uninstall is not implemented.** Removing an Office language pack is not a
  clean operation, and the app is designed as a re-runnable installer rather than
  something with a lifecycle. Leave the Uninstall section as the toolkit default.
- **No prerequisite checks.** The Install section does not verify that Microsoft
  365 Apps is present or that `setup.exe` exists before launching the picker. On
  a device without M365, the user picks languages and ODT then fails. Scope the
  Intune assignment (or add a requirement rule) to devices that have M365 Apps.
- **No filter, Select All, or grey-out of installed languages.** The dialog is a
  plain `CheckedListBox` of all 50 entries. Languages already installed are shown
  the same as any other; re-selecting one is harmless (ODT treats it as already
  present) but is not signposted in the UI.
- **No update-channel detection.** The generated XML relies on
  `Version="MatchInstalled"` rather than pinning a channel.
- **`%PUBLIC%` handoff is world-writable.** `M365_SelectedLangs.txt` lives in a
  folder any local user can write, and its contents are interpolated into the
  ODT XML without escaping. The blast radius is small — a crafted value yields
  malformed XML and a failed ODT run, under a package that was already running
  as SYSTEM — but if that matters in your environment, move the handoff to a
  SYSTEM-only path and validate each code against the `$Languages` table before
  writing it into the XML.
- **Dialog has no close button.** `ControlBox = $false`; the user must click
  **Install** or **Cancel**. Cancel (or an empty selection) produces exit code
  `1602`.
- **PSADT's progress dialog overlaps.** `Show-ADTInstallationProgress` from the
  Pre-Install phase stays on screen while the picker is up. The picker sets
  `TopMost = $true` so it appears in front.

## License

[MIT](LICENSE)
