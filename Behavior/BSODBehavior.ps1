param (
    [switch]$Default,
    [switch]$EnableEmoticon,
    [switch]$DisableDetails
)

$regKey = 'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\CrashControl'
$regPropertyDisableEmoticon = 'DisableEmoticon'
$regPropertyDisplayPararmeters = 'DisplayParameters'

if ($PSBoundParameters.ContainsKey('Default')) {
    & ..\RegistryScripts\Remove-RegistryProperty.ps1 $regKey $regPropertyDisableEmoticon -Quiet
    & ..\RegistryScripts\Remove-RegistryProperty.ps1 $regKey $regPropertyDisplayPararmeters -Quiet
} else {
    & ..\RegistryScripts\Set-RegistryProperty.ps1 $regKey $regPropertyDisableEmoticon 'DWORD' 1 -Quiet
    & ..\RegistryScripts\Set-RegistryProperty.ps1 $regKey $regPropertyDisplayPararmeters 'DWORD' 1 -Quiet
    if ($PSBoundParameters.ContainsKey('EnableEmoticon')) {
        & ..\RegistryScripts\Remove-RegistryProperty.ps1 $regKey $regPropertyDisableEmoticon -Quiet
    }
    if ($PSBoundParameters.ContainsKey('DisableDetails')) {
        & ..\RegistryScripts\Remove-RegistryProperty.ps1 $regKey $regPropertyDisplayPararmeters -Quiet
    }
}