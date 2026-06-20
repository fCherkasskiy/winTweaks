param (
    [ValidateRange(0, 100)] [Int32]$BackgroundTransparency,
    [ValidateRange(0, 100)] [Int32]$DimDesktop,
    [switch]$Default
)

$regKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MultitaskingView\AltTabViewHost'

function Set-BackgroundTransparency{
    param([ValidateRange(0, 100)] [Int32]$transparency = 70)
    $regProperty = 'Grid_backgroundPercent'
    if ($transparency -eq 70){
        & ..\RegistryScripts\Remove-RegistryProperty.ps1 $regKey $regProperty -Quiet
    } else {
        & ..\RegistryScripts\Set-RegistryProperty.ps1 $regKey $regProperty 'DWORD' $transparency -Quiet
    }
}

function Set-DimDesktop{
    param([ValidateRange(0, 100)] [Int32]$dim = 0)
    $regProperty = 'BackgroundDimmingLayer_percent'
    if ($dim -eq 0){
        & ..\RegistryScripts\Remove-RegistryProperty.ps1 $regKey $regProperty -Quiet
    } else {
        & ..\RegistryScripts\Set-RegistryProperty.ps1 $regKey $regProperty 'DWORD' $dim -Quiet
        
    }
}

if ($PSBoundParameters.ContainsKey('Default')) {
    Set-BackgroundTransparency
    DimDesktop
    exit
}
if ($PSBoundParameters.ContainsKey('BackgroundTransparency')) {
    Set-BackgroundTransparency $BackgroundTransparency
}
if ($PSBoundParameters.ContainsKey('DimDesktop')) {
    Set-DimDesktop $DimDesktop
}


