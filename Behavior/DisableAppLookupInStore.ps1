param (
    [switch]$Default
)

$regKey = 'HKLM:\Software\Policies\Microsoft\Windows\Explorer'
$regProperty = 'NoUseStoreOpenWith'

if ($PSBoundParameters.ContainsKey('Default')) {
    & ..\RegistryScripts\Remove-RegistryProperty.ps1 $regKey $regProperty -Quiet
} else {
    & ..\RegistryScripts\Set-RegistryProperty.ps1 $regKey $regProperty 'DWORD' 1 -Quiet
}