# Setup WinRM for Packer
# This script enables and configures WinRM for remote provisioning

Write-Host "Configuring WinRM for Packer..."

# Enable WinRM service
Write-Host "Enabling WinRM service..."
winrm quickconfig -q
winrm quickconfig -transport:http

# Configure WinRM
Write-Host "Configuring WinRM settings..."
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'

# Configure firewall
Write-Host "Configuring firewall for WinRM..."
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow

# Start WinRM service
Write-Host "Starting WinRM service..."
net stop winrm
sc.exe config winrm start=auto
net start winrm

Write-Host "WinRM configuration complete!"
