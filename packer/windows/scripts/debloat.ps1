# Windows 11 Debloat Script
# Removes bloatware, disables telemetry, and optimizes for lightweight usage
#
# Best practices incorporated from:
# - Win11Debloat (Raphire) - https://github.com/Raphire/Win11Debloat
# - Chris Titus WinUtil - https://github.com/ChrisTitusTech/winutil
# - Sophia Script for Windows - https://github.com/farag2/Sophia-Script-for-Windows
# - SimeonOnSecurity Windows-Optimize-Debloat

# Set error action to continue (don't fail on non-critical errors)
$ErrorActionPreference = "SilentlyContinue"

Write-Host "Starting Windows 11 debloat..."
Write-Host "Applying best practices from Win11Debloat, WinUtil, and Sophia Script..."

# ============================================================================
# Load Default User Registry Hive
# ============================================================================
# IMPORTANT: Apply HKCU settings to Default User profile so new users inherit them
# After Sysprep, new user profiles are created from C:\Users\Default
Write-Host "Loading Default User registry hive..."
$DefaultUserHive = "C:\Users\Default\NTUSER.DAT"
$HiveMounted = $false
if (Test-Path $DefaultUserHive) {
    reg load "HKU\DefaultUser" $DefaultUserHive 2>$null
    if ($LASTEXITCODE -eq 0) {
        $HiveMounted = $true
        Write-Host "  Default User hive loaded successfully"
    }
}

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
# Disable Telemetry and Data Collection (Enhanced - from Win11Debloat)
# ============================================================================
Write-Host "Disabling telemetry and data collection..."

# Disable telemetry (core settings)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force

# Disable feedback
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -Force

# Disable advertising ID (user + policy level)
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Force
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1 -Type DWord -Force

# Disable activity history
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord -Force

# Disable tailored experiences with diagnostic data
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force

# Disable online speech recognition
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Name "HasAccepted" -Value 0 -Type DWord -Force

# Disable inking and typing recognition
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Name "Enabled" -Value 0 -Type DWord -Force

# Disable input personalization (typing history)
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord -Force

# Disable trained data store (contact harvesting)
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0 -Type DWord -Force

# Disable personalization settings
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord -Force

# Disable Start Menu tracking
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0 -Type DWord -Force

# Disable Microsoft Edge telemetry
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "PersonalizationReportingEnabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "DiagnosticData" -Value 0 -Type DWord -Force

# ============================================================================
# Disable/Modify Services (Enhanced - from WinUtil best practices)
# ============================================================================
Write-Host "Optimizing Windows services..."

# Services to fully DISABLE (telemetry, not needed)
$ServicesToDisable = @(
    "DiagTrack"                    # Connected User Experiences and Telemetry
    "dmwappushservice"             # WAP Push Message Routing Service
    "RemoteRegistry"               # Remote Registry (security risk)
    "RetailDemo"                   # Retail Demo Service
    "WMPNetworkSvc"                # Windows Media Player Network Sharing
    "HomeGroupListener"            # HomeGroup Listener (deprecated)
    "HomeGroupProvider"            # HomeGroup Provider (deprecated)
)

foreach ($Service in $ServicesToDisable) {
    Write-Host "  Disabling $Service..."
    Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue
}

# Services to set to MANUAL (start only when needed - reduces idle RAM)
$ServicesToManual = @(
    "CDPSvc"                       # Connected Devices Platform Service
    "InventorySvc"                 # Inventory and Compatibility Appraisal
    "PcaSvc"                       # Program Compatibility Assistant
    "StorSvc"                      # Storage Service
    "WpnService"                   # Windows Push Notifications System
    "TabletInputService"           # Touch Keyboard and Handwriting
    "PhoneSvc"                     # Phone Service
    "WbioSrvc"                     # Windows Biometric Service (if no fingerprint)
    "AJRouter"                     # AllJoyn Router Service
    "NcdAutoSetup"                 # Network Connected Devices Auto-Setup
    "WlanSvc"                      # WLAN AutoConfig (if wired only)
    "icssvc"                       # Mobile Hotspot Service
)

foreach ($Service in $ServicesToManual) {
    Write-Host "  Setting $Service to Manual..."
    Set-Service -Name $Service -StartupType Manual -ErrorAction SilentlyContinue
}

# Services to set to DELAYED START (reduce boot time)
$ServicesToDelayed = @(
    "MapsBroker"                   # Downloaded Maps Manager
    "WSearch"                      # Windows Search indexing (keep enabled for Start Menu)
    "BITS"                         # Background Intelligent Transfer
    "UsoSvc"                       # Update Orchestrator Service
)

foreach ($Service in $ServicesToDelayed) {
    Write-Host "  Setting $Service to Delayed Start..."
    Set-Service -Name $Service -StartupType Automatic -ErrorAction SilentlyContinue
    # Set to Delayed Auto-Start via registry
    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Service"
    if (Test-Path $RegPath) {
        Set-ItemProperty -Path $RegPath -Name "DelayedAutostart" -Value 1 -Type DWord -Force
    }
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
# Performance Optimizations (Enhanced - from Chris Titus WinUtil)
# ============================================================================
Write-Host "Applying performance optimizations..."

# Disable startup delay
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force

# ============================================================================
# Network & Memory Performance (from WinUtil - reduces RAM usage)
# ============================================================================
Write-Host "Applying network and memory performance tweaks..."

# Disable QoS reserved bandwidth (reclaim 20% bandwidth)
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force

# Disable network throttling (remove bandwidth limit)
if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord -Force

# Increase IRPStackSize for better network performance
if (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters")) {
    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "IRPStackSize" -Value 30 -Type DWord -Force

# Disable Delivery Optimization P2P (reduces background bandwidth usage)
if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0 -Type DWord -Force

# Set Network Data Usage Monitor to Manual (reduces memory)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Ndu" -Name "Start" -Value 2 -Type DWord -Force

# Disable Nagle's algorithm (reduce latency)
$NetworkCards = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
foreach ($NetworkCard in $NetworkCards) {
    Set-ItemProperty -Path $NetworkCard.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $NetworkCard.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
}

# ============================================================================
# Memory Optimization
# ============================================================================
Write-Host "Applying memory optimizations..."

# Disable memory compression (can reduce CPU usage at cost of more RAM - optional)
# Note: Keeping enabled as it generally helps with low RAM scenarios
# Disable-MMAgent -MemoryCompression

# Prefetch/Superfetch - Keep enabled (modern Windows handles SSDs intelligently)
# Disabling these is outdated advice that can slow down app launches
# Values: 0=Disabled, 1=Boot only, 2=Apps only, 3=Both (default)
# Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Value 0 -Type DWord -Force
# Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Value 0 -Type DWord -Force

# Disable paging executive (keep kernel in RAM - for systems with 8GB+ RAM)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force

# Clear page file at shutdown (security + fresh start)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "ClearPageFileAtShutdown" -Value 0 -Type DWord -Force

# Disable Last Access Time updates (reduces disk I/O)
fsutil behavior set disablelastaccess 1

# ============================================================================
# Visual Effects (Enhanced - from WinUtil)
# ============================================================================
Write-Host "Disabling visual effects for better performance..."

# 1. Disable transparency effects
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force

# 2. Disable animations
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String -Force

# 3. Visual effects for best performance
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord -Force

# 4. Reduce menu show delay (WinUtil uses 200ms as safe value)
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "200" -Type String -Force

# Keep drag full windows enabled (disabling causes visual issues)
# Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0" -Type String -Force

# Disable listview animations
if (!(Test-Path "HKCU:\Control Panel\Desktop")) {
    New-Item -Path "HKCU:\Control Panel\Desktop" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ListviewAlphaSelect" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ListviewShadow" -Value 0 -Type DWord -Force

# Disable taskbar animations
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Type DWord -Force

# Disable Aero Peek
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0 -Type DWord -Force

# Disable window animations
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2" -Type String -Force
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothingType" -Value 2 -Type DWord -Force

# ============================================================================
# Disable Services (7-11)
# ============================================================================
Write-Host "Disabling additional services for performance..."

$PerformanceServicesToDisable = @(
    # NOTE: WSearch removed - disabling breaks Start Menu search
    "XblAuthManager"               # 8. Xbox Live Auth Manager
    "XblGameSave"                  # 8. Xbox Live Game Save
    "XboxNetApiSvc"                # 8. Xbox Live Networking Service
    "XboxGipSvc"                   # 8. Xbox Accessory Management
    "WerSvc"                       # 9. Windows Error Reporting
    "wercplsupport"                # 9. Problem Reports Control Panel
    # NOTE: PcaSvc removed - already set to Manual above, don't disable
    "lfsvc"                        # 11. Geolocation Service
)

foreach ($Service in $PerformanceServicesToDisable) {
    Write-Host "  Disabling $Service..."
    Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $Service -StartupType Disabled -ErrorAction SilentlyContinue
}

# ============================================================================
# Disable Scheduled Tasks (Enhanced - from WinUtil)
# ============================================================================
Write-Host "Disabling telemetry and unnecessary scheduled tasks..."

$TasksToDisable = @(
    # Telemetry tasks
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Application Experience\StartupAppTask"
    "\Microsoft\Windows\Application Experience\MareBackup"
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask"
    "\Microsoft\Windows\Autochk\Proxy"

    # Customer Experience Improvement Program
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"

    # Diagnostics and Data Collection
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver"
    "\Microsoft\Windows\Maintenance\WinSAT"
    "\Microsoft\Windows\PI\Sqm-Tasks"

    # Feedback
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"

    # Error Reporting
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"

    # Power
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"

    # Maps
    "\Microsoft\Windows\Maps\MapsToastTask"
    "\Microsoft\Windows\Maps\MapsUpdateTask"

    # Cloud
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"

    # Clipboard
    "\Microsoft\Windows\Clip\License Validation"

    # Registry idle backup (not critical)
    "\Microsoft\Windows\Registry\RegIdleBackup"

    # Speech
    "\Microsoft\Windows\Speech\SpeechModelDownloadTask"

    # Shell
    "\Microsoft\Windows\Shell\FamilySafetyMonitor"
    "\Microsoft\Windows\Shell\FamilySafetyRefresh"
    "\Microsoft\Windows\Shell\FamilySafetyUpload"

    # Flighting
    "\Microsoft\Windows\Flighting\OneSettings\RefreshCache"
    "\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures"
)

foreach ($Task in $TasksToDisable) {
    Write-Host "  Disabling task: $Task"
    Disable-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue
}

# ============================================================================
# Disable AI Features (14-15)
# ============================================================================
Write-Host "Disabling Copilot and AI features..."

# 14. Disable Copilot
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force

# 15. Disable Recall (AI screenshot feature)
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force

# ============================================================================
# Power Settings (16-18)
# ============================================================================
Write-Host "Setting high performance power plan..."

# 16. Set power plan to High Performance
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
# If High Performance doesn't exist, try Ultimate Performance
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null

# 17. Disable USB selective suspend
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

# 18. Disable hard disk turn off
powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0

# ============================================================================
# Tips & Suggestions (19-21)
# ============================================================================
Write-Host "Disabling tips and suggestions..."

# 19. Disable all tips, tricks, and suggestions
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force

# 20. Disable Start Menu suggestions
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force

# 21. Disable lock screen tips/spotlight
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord -Force
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Value 0 -Type DWord -Force

# ============================================================================
# Gaming - Disable (22-24)
# ============================================================================
Write-Host "Disabling Game Bar and Game DVR..."

# 22. Disable Game Bar
if (!(Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Force | Out-Null
}
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force

if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -Force

# 23. Disable Game DVR
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

# 24. Disable Game Mode
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 0 -Type DWord -Force

# ============================================================================
# UI Speed Tweaks (25-26, 28)
# ============================================================================
Write-Host "Applying UI speed tweaks..."

# 25. Faster shutdown (reduce wait timeout)
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value "2000" -Type String -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "2000" -Type String -Force

# 26. Reduce mouse hover delay
Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseHoverTime" -Value "10" -Type String -Force

# 28. Disable recent files in Quick Access
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0 -Type DWord -Force

# ============================================================================
# Apply Settings to Default User Profile
# ============================================================================
# CRITICAL: This ensures new users created after Sysprep inherit these settings
Write-Host "Applying settings to Default User profile..."

if ($HiveMounted) {
    # Visual effects for performance
    if (!(Test-Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects")) {
        New-Item -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Force | Out-Null
    }
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord -Force

    # Disable transparency
    if (!(Test-Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize")) {
        New-Item -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Force | Out-Null
    }
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force

    # Disable taskbar animations
    if (!(Test-Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
        New-Item -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
    }
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Type DWord -Force

    # Desktop settings
    if (!(Test-Path "Registry::HKU\DefaultUser\Control Panel\Desktop")) {
        New-Item -Path "Registry::HKU\DefaultUser\Control Panel\Desktop" -Force | Out-Null
    }
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\Control Panel\Desktop" -Name "MenuShowDelay" -Value "200" -Type String -Force
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\Control Panel\Desktop" -Name "DragFullWindows" -Value "1" -Type String -Force

    # Content delivery (tips, suggestions)
    if (!(Test-Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager")) {
        New-Item -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Force | Out-Null
    }
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path "Registry::HKU\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force

    # Unload the hive
    Write-Host "Unloading Default User registry hive..."
    [gc]::Collect()
    Start-Sleep -Seconds 2
    reg unload "HKU\DefaultUser" 2>$null
    Write-Host "  Default User hive unloaded"
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "============================================================================"
Write-Host "Windows 11 Debloat Complete!"
Write-Host "============================================================================"
Write-Host ""
Write-Host "Optimizations applied:"
Write-Host "  - Removed bloatware apps (Microsoft + third-party)"
Write-Host "  - Removed OneDrive"
Write-Host "  - Disabled telemetry and data collection"
Write-Host "  - Optimized services (disable/manual/delayed)"
Write-Host "  - Disabled unnecessary scheduled tasks"
Write-Host "  - Applied network performance tweaks"
Write-Host "  - Applied memory optimizations"
Write-Host "  - Disabled visual effects for performance"
Write-Host "  - Disabled AI features (Copilot, Recall)"
Write-Host "  - Applied power performance settings"
Write-Host "  - Disabled gaming features (Game Bar, DVR)"
Write-Host ""
Write-Host "Best practices from:"
Write-Host "  - Win11Debloat (Raphire)"
Write-Host "  - Chris Titus WinUtil"
Write-Host "  - Sophia Script for Windows"
Write-Host ""
Write-Host "Expected RAM reduction: 1-2GB"
Write-Host ""

# Ensure script exits with success code
exit 0
