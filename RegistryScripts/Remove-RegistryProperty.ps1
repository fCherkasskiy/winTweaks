<#
.SYNOPSIS
    Removes one or more registry values (properties) from a registry key.

.DESCRIPTION
    Remove-RegistryProperty is intended to be called from other scripts to ensure one or
    more registry values are absent, in an idempotent way:
      1. PowerShell enforces that RegistryPath and PropertyName are supplied - the script
         fails if either is missing.
      2. If the registry key does not exist, there is nothing to delete - the script
         exits quietly without error (the desired end state already holds).
      3. For each property name given, if it exists on the key it is removed; if it
         doesn't exist, it is skipped without error.

    This script only removes values/properties - it never deletes the registry key
    itself.

    On failure (e.g. access denied), the script throws a terminating error so a calling
    script can catch it with try/catch. If invoked as a separate process
    (powershell.exe -File / pwsh -File), an unhandled error also produces a non-zero
    process exit code.

.PARAMETER RegistryPath
    Full PowerShell registry path, e.g. 'HKLM:\SOFTWARE\Contoso\App' or 'HKCU:\Software\App'.
    Long-form hive names (HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER, HKEY_CLASSES_ROOT,
    HKEY_USERS, HKEY_CURRENT_CONFIG) are accepted and normalized automatically.

.PARAMETER PropertyName
    One or more property (value) names to remove from the key.

.PARAMETER Quiet
    Suppresses the "OK: ..." messages written to the output stream for each property
    removed. Errors are still thrown/written regardless of this switch.

.EXAMPLE
    .\Remove-RegistryProperty.ps1 -RegistryPath 'HKCU:\Software\Contoso\App' -PropertyName 'Version'

.EXAMPLE
    .\Remove-RegistryProperty.ps1 -RegistryPath 'HKCU:\Software\Contoso\App' -PropertyName 'Version','MaxRetries','Tags'

.EXAMPLE
    # Called from another script, with failure handling
    try {
        & "$PSScriptRoot\Remove-RegistryProperty.ps1" -RegistryPath 'HKLM:\SOFTWARE\Contoso\App' `
            -PropertyName 'Tags' -Quiet
    } catch {
        Write-Error "Registry cleanup failed: $_"
        exit 1
    }
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistryPath,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string[]]$PropertyName,

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Normalize long-form hive names to their PowerShell drive equivalents
$hiveMap = @{
    'HKEY_LOCAL_MACHINE\'  = 'HKLM:\'
    'HKEY_CURRENT_USER\'   = 'HKCU:\'
    'HKEY_CLASSES_ROOT\'   = 'HKCR:\'
    'HKEY_USERS\'          = 'HKU:\'
    'HKEY_CURRENT_CONFIG\' = 'HKCC:\'
}
foreach ($longForm in $hiveMap.Keys) {
    if ($RegistryPath -like "$longForm*") {
        $RegistryPath = $RegistryPath -replace [regex]::Escape($longForm), $hiveMap[$longForm]
        break
    }
}

if ($RegistryPath -notmatch '^(HKLM|HKCU|HKCR|HKU|HKCC):\\') {
    throw "RegistryPath '$RegistryPath' is not valid. It must start with a registry drive: HKLM:\, HKCU:\, HKCR:\, HKU:\, or HKCC:\."
}

try {
    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        Write-Verbose "Registry key '$RegistryPath' does not exist. Nothing to delete."
        return
    }

    foreach ($name in $PropertyName) {
        $existing = Get-ItemProperty -LiteralPath $RegistryPath -Name $name -ErrorAction SilentlyContinue

        if ($null -eq $existing) {
            Write-Verbose "Property '$name' does not exist on '$RegistryPath'. Nothing to do."
            continue
        }

        Remove-ItemProperty -LiteralPath $RegistryPath -Name $name -Force

        if (-not $Quiet) {
            Write-Output "OK: Removed '$name' from '$RegistryPath'."
        }
    }
}
catch {
    throw "Failed to remove registry propert$(if ($PropertyName.Count -gt 1) { 'ies' } else { 'y' }) from '$RegistryPath': $($_.Exception.Message)"
}