# Windows Cleanup Script
# Prepare Windows for template conversion

Write-Host "Starting Windows cleanup..."

# Clear temp files
Write-Host "Cleaning temporary files..."
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear event logs
Write-Host "Clearing event logs..."
Get-EventLog -LogName * | ForEach-Object { Clear-EventLog -LogName $_.Log -ErrorAction SilentlyContinue }

# Clear Windows Update cache
Write-Host "Cleaning Windows Update cache..."
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue

# Disk cleanup
Write-Host "Running disk cleanup..."
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

# Defragment disk (optional, can take time)
# Write-Host "Defragmenting disk..."
# Optimize-Volume -DriveLetter C -Defrag -Verbose

# Clear PowerShell history
Write-Host "Clearing PowerShell history..."
Remove-Item -Path (Get-PSReadLineOption).HistorySavePath -ErrorAction SilentlyContinue

# Remove Packer build artifacts
Write-Host "Removing Packer build artifacts..."
Remove-Item -Path "C:\Packer" -Recurse -Force -ErrorAction SilentlyContinue

# Disable hibernation to save space
Write-Host "Disabling hibernation..."
powercfg /hibernate off

# Zero out free space (optional, improves compression)
# Write-Host "Zeroing out free space (this may take a while)..."
# $FilePath="C:\zero.tmp"
# $Volume = Get-WmiObject win32_logicaldisk -filter "DeviceID='C:'"
# $ArraySize= 64kb
# $SpaceToLeave= $Volume.Size * 0.05
# $FileSize= $Volume.FreeSpace - $SpacetoLeave
# $ZeroArray= new-object byte[]($ArraySize)
# $Stream= [io.File]::OpenWrite($FilePath)
# try {
#    $CurFileSize = 0
#     while($CurFileSize -lt $FileSize) {
#         $Stream.Write($ZeroArray,0, $ZeroArray.Length)
#         $CurFileSize +=$ZeroArray.Length
#     }
# }
# finally {
#     if($Stream) { $Stream.Close() }
#     Remove-Item $FilePath -ErrorAction SilentlyContinue
# }

Write-Host "Windows cleanup complete!"
Write-Host "System is ready for template conversion."
