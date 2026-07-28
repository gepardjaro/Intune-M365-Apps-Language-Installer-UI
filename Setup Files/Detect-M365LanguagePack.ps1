<#
.SYNOPSIS
    Intune detection script for M365 Language Pack Installer.
.DESCRIPTION
    Checks for the marker registry value written by the Post-Install section of
    Invoke-AppDeployToolkit.ps1.
    - If found: outputs "Installed" (Intune detects the app as installed)
    - If not found: exits 1 (Intune treats as not installed)

    The marker is short-lived by design: Post-Install creates it, then a detached
    process deletes it ~30 seconds later. That is long enough for Intune to record
    a successful install, after which the app returns to Available so the user can
    run it again to add more languages.
#>

$regPath = 'HKLM:\SOFTWARE\M365LanguagePacks'

if (Test-Path $regPath) {
    $installComplete = (Get-ItemProperty -Path $regPath -Name 'InstallComplete' -ErrorAction SilentlyContinue).InstallComplete
    if ($installComplete) {
        Write-Output "Installed: $installComplete"
        exit 0
    }
}

exit 1
