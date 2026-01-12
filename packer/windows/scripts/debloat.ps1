# Windows 11 Debloat Script
# Removes bloatware, disables telemetry, and optimizes for lightweight usage

# Set error action to continue (don't fail on non-critical errors)
$ErrorActionPreference = "SilentlyContinue"

Write-Host "Starting Windows 11 debloat..."

# ============================================================================
# Remove Bloatware Apps
# ============================================================================
Write-Host "Removing bloatware apps..."

$BloatwareApps = @(
    # Microsoft Bloatware
    "Microsoft.3DBuilder"
    "Microsoft.549981C3F5F10"          # Cortana
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingWeather"
    "Microsoft.Clipchamp"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MixedReality.Portal"
    "Microsoft.News"
    "Microsoft.Office.Lens"
    "Microsoft.Office.OneNote"
    "Microsoft.Office.Sway"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Todos"
    "Microsoft.Wallet"
    "Microsoft.Whiteboard"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCommunicationsApps"  # Mail & Calendar
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "MicrosoftCorporationII.QuickAssist"
    "MicrosoftTeams"

    # Third-party bloatware often pre-installed
    "ACGMediaPlayer"
    "ActiproSoftwareLLC"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    "Amazon.com.Amazon"
    "Asphalt8Airborne"
    "AutodeskSketchBook"
    "CasualGames"
    "COOKINGFEVER"
    "CyberLinkMediaSuiteEssentials"
    "DisneyMagicKingdoms"
    "DrawboardPDF"
    "Duolingo-LearnLanguagesforFree"
    "EclipseManager"
    "Facebook"
    "FarmVille2CountryEscape"
    "Fitbit.FitbitCoach"
    "Flipboard"
    "HiddenCity"
    "HULULLC.HULUPLUS"
    "iHeartRadio"
    "king.com.BubbleWitch3Saga"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushSodaSaga"
    "LinkedInforWindows"
    "MarchofEmpires"
    "Netflix"
    "NYTCrossword"
    "OneCalendar"
    "PandoraMediaInc"
    "PhototasticCollage"
    "PicsArt-PhotoStudio"
    "Plex"
    "PolarrPhotoEditorAcademicEdition"
    "RoyalRevolt"
    "Shazam"
    "Sidia.LiveWallpaper"
    "SlingTV"
    "Speed Test"
    "Spotify"
    "TikTok"
    "TuneInRadio"
    "Twitter"
    "Viber"
    "WinZipUniversal"
    "Wunderlist"
    "XING"
)

foreach ($App in $BloatwareApps) {
    Write-Host "  Removing $App..."
    Get-AppxPackage -Name $App -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -Like "*$App*" | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

# ============================================================================
# Remove OneDrive
# ============================================================================
Write-Host "Removing OneDrive..."

# Stop OneDrive process
Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue

# Uninstall OneDrive
$OneDriveSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
if (!(Test-Path $OneDriveSetup)) {
    $OneDriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
}
if (Test-Path $OneDriveSetup) {
    Start-Process $OneDriveSetup -ArgumentList "/uninstall" -Wait -NoNewWindow
}

# Remove OneDrive leftovers
Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\OneDriveTemp" -Recurse -Force -ErrorAction SilentlyContinue

# Remove OneDrive from Explorer sidebar
reg delete "HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f 2>$null
reg delete "HKEY_CLASSES_ROOT\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f 2>$null

# ============================================================================
# Disable Telemetry and Data Collection
# ============================================================================
Write-Host "Disabling telemetry and data collection..."

# Disable telemetry
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force

# Disable feedback
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -Force

# Disable advertising ID
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1 -Type DWord -Force

# Disable activity history
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord -Force

# ============================================================================
# Disable Unnecessary Services
# ============================================================================
Write-Host "Disabling unnecessary services..."

$ServicesToDisable = @(
    "DiagTrack"                    # Connected User Experiences and Telemetry
    "dmwappushservice"             # WAP Push Message Routing Service
    "MapsBroker"                   # Downloaded Maps Manager
    "RemoteRegistry"               # Remote Registry
    "WSearch"                      # Windows Search (if not needed)
)

foreach ($Service in $ServicesToDisable) {
    Write-Host "  Disabling $Service..."
    Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue
}

# ============================================================================
# Remove Optional Features
# ============================================================================
Write-Host "Removing optional features..."

$FeaturesToRemove = @(
    "MediaPlayback"
    "WindowsMediaPlayer"
    "WorkFolders-Client"
)

foreach ($Feature in $FeaturesToRemove) {
    Write-Host "  Removing $Feature..."
    Disable-WindowsOptionalFeature -Online -FeatureName $Feature -NoRestart -ErrorAction SilentlyContinue
}

# ============================================================================
# Disable Cortana
# ============================================================================
Write-Host "Disabling Cortana..."

if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type DWord -Force

# ============================================================================
# Optimize Start Menu and Taskbar
# ============================================================================
Write-Host "Optimizing Start Menu and Taskbar..."

# Disable web search in Start Menu
Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# Hide Task View button
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Hide Widgets
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force

# Hide Chat icon
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# ============================================================================
# Performance Optimizations
# ============================================================================
Write-Host "Applying performance optimizations..."

# Disable startup delay
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force

# Disable transparency effects (optional - improves performance)
# Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force

Write-Host "Windows 11 debloat complete!"

# Ensure script exits with success code
exit 0
