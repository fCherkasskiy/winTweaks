param (
    [string]$Action = "AeroLite"
)

function AeroLite {
    New-Item -Name "..\temp" -ItemType Directory -Force
    $aerolite = "..\temp\aero.theme"
    Copy-Item -Path "C:\Windows\Resources\Themes\aero.theme" -Destination "$aerolite"
    (Get-Content $aerolite) -replace 'DisplayName=.*',  'DisplayName=Aero Lite' | Set-Content $aerolite
    (Get-Content $aerolite) -replace 'Path=.*',         'Path=%ResourceDir%\Themes\Aero\AeroLite.msstyles' | Set-Content $aerolite
    Invoke-Item $aerolite
}
function WindowsCustomTheme {
    Write-Error "Not Implemented. Use the Settings Application to choose a theme or use your Custom Theme"
}

if($Action -eq "AeroLite") {
    AeroLite
} elseif($Action -eq "Default") {
    WindowsCustomTheme
} else {
    throw [System.ArgumentException]::new("Argument must be `"AeroLite`" or `"Default`"", "Action")
}

