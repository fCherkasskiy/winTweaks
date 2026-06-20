<#
.SYNOPSIS
    Creates or updates a single registry value, creating the parent key if necessary.

.DESCRIPTION
    Set-RegistryProperty is intended to be called from other scripts to manage a single
    registry value in an idempotent way:
      1. PowerShell enforces that RegistryPath, PropertyName, PropertyType, and
         PropertyValue are all supplied - the script throws/fails if any are missing.
      2. Creates the registry key (and any missing parent keys) if it does not exist.
      3. Creates the property/value if it does not exist on the key.
      4. Updates the property/value if it already exists.

    On failure, the script throws a terminating error so a calling script can catch it
    with try/catch. If this script is invoked as a separate process
    (powershell.exe -File / pwsh -File), an unhandled error also produces a non-zero
    process exit code.

.PARAMETER RegistryPath
    Full PowerShell registry path, e.g. 'HKLM:\SOFTWARE\Contoso\App' or 'HKCU:\Software\App'.
    Long-form hive names (HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER, HKEY_CLASSES_ROOT,
    HKEY_USERS, HKEY_CURRENT_CONFIG) are accepted and normalized automatically.

.PARAMETER PropertyName
    Name of the registry value to create or update.

.PARAMETER PropertyType
    One of: String, ExpandString, Binary, DWord, MultiString, QWord

.PARAMETER PropertyValue
    The value to set.
      - DWord / QWord         : any value convertible to Int32 / Int64
      - String / ExpandString : any value convertible to string
      - MultiString           : a string array, or a single string with entries separated by ';'
      - Binary                : a byte[], or a string of decimal byte values separated by
                                 commas/spaces (e.g. "1,2,255")

.PARAMETER Quiet
    Suppresses the "OK: ..." success message written to the output stream. Errors are
    still thrown/written regardless of this switch. Useful when calling this script from
    another script that doesn't want the success line mixed into its own output.

.EXAMPLE
    .\Set-RegistryProperty.ps1 -RegistryPath 'HKLM:\SOFTWARE\Contoso\App' -PropertyName 'Version' -PropertyType String -PropertyValue '1.2.3'

.EXAMPLE
    .\Set-RegistryProperty.ps1 -RegistryPath 'HKCU:\Software\Contoso\App' -PropertyName 'MaxRetries' -PropertyType DWord -PropertyValue 5

.EXAMPLE
    # Called from another script, with failure handling
    try {
        & "$PSScriptRoot\Set-RegistryProperty.ps1" -RegistryPath 'HKLM:\SOFTWARE\Contoso\App' `
            -PropertyName 'Tags' -PropertyType MultiString -PropertyValue @('alpha','beta')
    } catch {
        Write-Error "Registry update failed: $_"
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
    [string]$PropertyName,

    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
    [string]$PropertyType,

    [Parameter(Mandatory = $true, Position = 3)]
    [object]$PropertyValue,

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

function Convert-RegistryValue {
    param(
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][AllowNull()][object]$Value
    )

    switch ($Type) {
        'DWord' {
            try { return [int32]$Value }
            catch { throw "PropertyValue '$Value' cannot be converted to DWord (Int32)." }
        }
        'QWord' {
            try { return [int64]$Value }
            catch { throw "PropertyValue '$Value' cannot be converted to QWord (Int64)." }
        }
        'Binary' {
            if ($Value -is [byte[]]) { return $Value }
            try {
                $bytes = ($Value -split '[,\s]+') | Where-Object { $_ -ne '' } | ForEach-Object { [byte]$_ }
                return [byte[]]$bytes
            } catch {
                throw "PropertyValue '$Value' cannot be converted to Binary (byte[]). Pass a byte[] or comma/space separated decimal byte values, e.g. '1,2,255'."
            }
        }
        'MultiString' {
            if ($Value -is [array]) { return [string[]]$Value }
            return [string[]]($Value -split ';' | Where-Object { $_ -ne '' })
        }
        default {
            # String, ExpandString
            return [string]$Value
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        Write-Verbose "Registry key '$RegistryPath' does not exist. Creating it."
        New-Item -Path $RegistryPath -Force | Out-Null
    } else {
        Write-Verbose "Registry key '$RegistryPath' already exists."
    }

    $convertedValue = Convert-RegistryValue -Type $PropertyType -Value $PropertyValue

    $existing = Get-ItemProperty -LiteralPath $RegistryPath -Name $PropertyName -ErrorAction SilentlyContinue

    if ($null -eq $existing) {
        Write-Verbose "Property '$PropertyName' does not exist. Creating it as $PropertyType."
        New-ItemProperty -LiteralPath $RegistryPath -Name $PropertyName -PropertyType $PropertyType -Value $convertedValue -Force | Out-Null
    } else {
        Write-Verbose "Property '$PropertyName' already exists. Updating its value."
        Set-ItemProperty -LiteralPath $RegistryPath -Name $PropertyName -Value $convertedValue -Force
    }

    if (-not $Quiet) {
        Write-Output "OK: '$RegistryPath' -> '$PropertyName' = '$PropertyValue' ($PropertyType)"
    }
}
catch {
    throw "Failed to set registry property '$PropertyName' at '$RegistryPath': $($_.Exception.Message)"
}