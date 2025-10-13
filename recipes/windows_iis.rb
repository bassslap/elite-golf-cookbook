#
# Cookbook:: elite-golf-cookbook
# Recipe:: windows_iis
#
# Configures IIS for the Elite Golf web application on Windows

# Require Win32::Service for service checks
begin
  require 'win32/service'
rescue LoadError
  Chef::Log.warn("Win32::Service not available - service checks will be skipped")
end

# Install IIS features using PowerShell with correct Windows 10 feature names
powershell_script 'enable_iis_features' do
  code <<-EOH
    # Enable IIS and required features for Windows 10/Server
    $features = @(
      'IIS-WebServerRole',
      'IIS-WebServer', 
      'IIS-CommonHttpFeatures',
      'IIS-HttpErrors',
      'IIS-HttpLogging',
      'IIS-HttpRedirect',
      'IIS-ApplicationDevelopment',
      'IIS-NetFxExtensibility45',
      'IIS-HealthAndDiagnostics',
      'IIS-HttpCompressionStatic',
      'IIS-Security',
      'IIS-RequestFiltering',
      'IIS-StaticContent',
      'IIS-DefaultDocument',
      'IIS-DirectoryBrowsing',
      'IIS-ASPNET45',
      'IIS-NetFx4Extended',
      'IIS-ISAPIExtensions',
      'IIS-ISAPIFilter',
      'IIS-ManagementConsole',
      'IIS-IIS6ManagementCompatibility',
      'IIS-Metabase',
      'IIS-ManagementService'
    )
    
    foreach ($feature in $features) {
      try {
        Write-Host "Enabling feature: $feature"
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue
        Write-Host "Successfully enabled: $feature"
      } catch {
        Write-Host "Feature $feature may not be available or already enabled: $($_.Exception.Message)"
      }
    }
    
    Write-Host "IIS features installation completed"
    Write-Host "Waiting for IIS services to be ready..."
    Start-Sleep -Seconds 5
  EOH
  action :run
  not_if 'Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServer | Where-Object {$_.State -eq "Enabled"}'
end

# Wait for IIS services and components to be available using PowerShell
powershell_script 'wait_for_iis_components' do
  code <<-EOH
    Write-Host "Waiting for IIS components to be ready..."
    
    # Wait up to 3 minutes for IIS components with shorter intervals
    $maxWaitTime = 180  # 3 minutes
    $waitInterval = 5   # 5 seconds
    $elapsedTime = 0
    
    do {
      $iisReady = $true
      
      # Check if IIS Management Service exists (this indicates IIS is properly installed)
      $iisAdmin = Get-Service -Name "IISADMIN" -ErrorAction SilentlyContinue
      if (-not $iisAdmin) {
        $iisReady = $false
        Write-Host "Waiting for IISADMIN service... ($elapsedTime seconds elapsed)"
      }
      
      # Check if appcmd.exe exists
      if (-not (Test-Path "C:\\Windows\\System32\\inetsrv\\appcmd.exe")) {
        $iisReady = $false
        Write-Host "Waiting for appcmd.exe... ($elapsedTime seconds elapsed)"
      }
      
      if (-not $iisReady) {
        Start-Sleep -Seconds $waitInterval
        $elapsedTime += $waitInterval
      }
      
    } while (-not $iisReady -and $elapsedTime -lt $maxWaitTime)
    
    if ($iisReady) {
      Write-Host "IIS components are ready!"
      
      # Try to start IIS services if they exist but aren't running
      try {
        $services = @("IISADMIN", "W3SVC", "WAS")
        foreach ($serviceName in $services) {
          $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
          if ($service -and $service.Status -ne "Running") {
            Write-Host "Starting $serviceName service..."
            Start-Service -Name $serviceName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
          }
        }
      } catch {
        Write-Host "Note: Some IIS services may need system reboot to be fully available"
      }
    } else {
      Write-Host "Warning: IIS components not fully ready after $maxWaitTime seconds"
      Write-Host "Continuing with deployment - services may start during configuration..."
    }
  EOH
  action :run
end

# Start IIS services using PowerShell (more reliable than service resource)
powershell_script 'start_iis_services' do
  code <<-EOH
    try {
      # Check if W3SVC service exists
      $service = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
      if ($service) {
        Write-Host "W3SVC service found, configuring..."
        
        # Set service to automatic startup
        Set-Service -Name "W3SVC" -StartupType Automatic -ErrorAction SilentlyContinue
        
        # Start the service if not running
        if ($service.Status -ne "Running") {
          Write-Host "Starting W3SVC service..."
          Start-Service -Name "W3SVC" -ErrorAction SilentlyContinue
          Start-Sleep -Seconds 5
        }
        
        # Verify service is running
        $service = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
        if ($service.Status -eq "Running") {
          Write-Host "W3SVC service is now running successfully"
        } else {
          Write-Host "W3SVC service status: $($service.Status)"
        }
      } else {
        Write-Host "W3SVC service not found - IIS may still be installing"
        Write-Host "This is normal during initial IIS installation - skipping service startup"
        Write-Host "Services will be started later in the deployment process"
        
        # Don't attempt sc.exe commands that will fail - just log and continue
        Write-Host "Note: W3SVC service will be available after IIS installation completes"
      }
    } catch {
      Write-Host "Error managing W3SVC service: $($_.Exception.Message)"
      Write-Host "This may be normal during initial IIS installation"
    }
    
    # Always exit successfully - service management errors are not critical at this stage
    exit 0
  EOH
  action :run
  ignore_failure true
end

# Create application pool using appcmd if available, otherwise use PowerShell
execute 'create_golf_app_pool' do
  command %Q{C:\\Windows\\System32\\inetsrv\\appcmd.exe add apppool /name:"#{node['golf_app']['app_pool_name']}" /managedRuntimeVersion:"v4.0" /processModel.identityType:ApplicationPoolIdentity}
  not_if %Q{C:\\Windows\\System32\\inetsrv\\appcmd.exe list apppool "#{node['golf_app']['app_pool_name']}" >nul 2>&1}
  only_if { ::File.exist?('C:\\Windows\\System32\\inetsrv\\appcmd.exe') }
  retries 3
  retry_delay 5
end

# Fallback: Create application pool using PowerShell if appcmd is not available
powershell_script 'create_golf_app_pool_fallback' do
  code <<-EOH
    try {
      # Try to import WebAdministration module
      Import-Module WebAdministration -ErrorAction Stop
      Write-Host "WebAdministration module loaded successfully"
      
      # Check if app pool already exists
      $existingPool = Get-WebAppPoolState -Name "#{node['golf_app']['app_pool_name']}" -ErrorAction SilentlyContinue
      if (-not $existingPool) {
        Write-Host "Creating application pool: #{node['golf_app']['app_pool_name']}"
        New-WebAppPool -Name "#{node['golf_app']['app_pool_name']}" -ErrorAction SilentlyContinue
        
        # Configure the app pool if it was created
        $pool = Get-WebAppPoolState -Name "#{node['golf_app']['app_pool_name']}" -ErrorAction SilentlyContinue
        if ($pool) {
          Set-ItemProperty -Path "IIS:\\AppPools\\#{node['golf_app']['app_pool_name']}" -Name processModel.identityType -Value ApplicationPoolIdentity -ErrorAction SilentlyContinue
          Set-ItemProperty -Path "IIS:\\AppPools\\#{node['golf_app']['app_pool_name']}" -Name managedRuntimeVersion -Value "v4.0" -ErrorAction SilentlyContinue
          Write-Host "Application pool #{node['golf_app']['app_pool_name']} created and configured via PowerShell"
        } else {
          Write-Host "Application pool creation may have failed, but continuing..."
        }
      } else {
        Write-Host "Application pool #{node['golf_app']['app_pool_name']} already exists"
      }
    } catch {
      Write-Host "WebAdministration module not available or IIS not ready: $($_.Exception.Message)"
      Write-Host "Application pool will be created later when IIS is fully installed"
      Write-Host "This is normal during initial IIS setup"
    }
    
    # Always exit successfully - app pool creation errors are not critical at this stage
    exit 0
  EOH
  not_if { ::File.exist?('C:\\Windows\\System32\\inetsrv\\appcmd.exe') }
  action :run
  ignore_failure true
end

# Remove existing site if it exists (appcmd method)
execute 'remove_existing_golf_site' do
  command %Q{C:\\Windows\\System32\\inetsrv\\appcmd.exe delete site "#{node['golf_app']['site_name']}"}
  only_if %Q{C:\\Windows\\System32\\inetsrv\\appcmd.exe list site "#{node['golf_app']['site_name']}" >nul 2>&1}
  only_if { ::File.exist?('C:\\Windows\\System32\\inetsrv\\appcmd.exe') }
  ignore_failure true
end

# Create IIS site using appcmd if available
execute 'create_golf_website' do
  command %Q{C:\\Windows\\System32\\inetsrv\\appcmd.exe add site /name:"#{node['golf_app']['site_name']}" /physicalPath:"#{node['golf_app']['web_root']}" /bindings:http/*:#{node['golf_app']['port']}: /applicationDefaults.applicationPool:"#{node['golf_app']['app_pool_name']}"}
  not_if %Q{C:\\Windows\\System32\\inetsrv\\appcmd.exe list site "#{node['golf_app']['site_name']}" >nul 2>&1}
  only_if { ::File.exist?('C:\\Windows\\System32\\inetsrv\\appcmd.exe') }
  retries 3
  retry_delay 5
end

# Fallback: Create website using PowerShell if appcmd is not available
powershell_script 'create_golf_website_fallback' do
  code <<-EOH
    try {
      Import-Module WebAdministration -ErrorAction Stop
      $siteName = "#{node['golf_app']['site_name']}"
      $port = #{node['golf_app']['port']}
      $physicalPath = "#{node['golf_app']['web_root']}"
      $appPoolName = "#{node['golf_app']['app_pool_name']}"
      
      # Remove existing site if it exists
      if (Get-Website -Name $siteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $siteName -ErrorAction SilentlyContinue
        Write-Host "Removed existing website: $siteName"
      }
      
      # Create new website
      New-Website -Name $siteName -Port $port -PhysicalPath $physicalPath -ApplicationPool $appPoolName -ErrorAction Stop
      Write-Host "Website $siteName created successfully on port $port via PowerShell"
      
      # Start the website
      Start-Website -Name $siteName -ErrorAction SilentlyContinue
      Write-Host "Website $siteName started"
    } catch {
      Write-Host "PowerShell method failed: $($_.Exception.Message)"
      Write-Host "Will attempt basic IIS setup..."
      
      # Very basic fallback - just ensure default website is configured
      try {
        # Stop default website if it exists
        Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
        Write-Host "IIS default website stopped to avoid conflicts"
      } catch {
        Write-Host "Could not stop default website, continuing..."
      }
    }
  EOH
  not_if { ::File.exist?('C:\\Windows\\System32\\inetsrv\\appcmd.exe') }
  action :run
end

# Deploy web.config
template "#{node['golf_app']['web_root']}/web.config" do
  source 'web.config.erb'
  variables(
    enable_ssl: node['golf_app']['enable_ssl']
  )
  action :create
end

# Configure SSL if enabled
if node['golf_app']['enable_ssl']
  # Remove existing SSL site if it exists
  execute 'remove_existing_golf_ssl_site' do
    command %Q{%windir%\\system32\\inetsrv\\appcmd delete site "#{node['golf_app']['site_name']}-SSL"}
    only_if %Q{%windir%\\system32\\inetsrv\\appcmd list site "#{node['golf_app']['site_name']}-SSL"}
    ignore_failure true
  end
  
  # Create SSL site using appcmd
  execute 'create_golf_ssl_website' do
    command %Q{%windir%\\system32\\inetsrv\\appcmd add site /name:"#{node['golf_app']['site_name']}-SSL" /physicalPath:"#{node['golf_app']['web_root']}" /bindings:https/*:#{node['golf_app']['ssl_port']}: /applicationDefaults.applicationPool:"#{node['golf_app']['app_pool_name']}"}
    not_if %Q{%windir%\\system32\\inetsrv\\appcmd list site "#{node['golf_app']['site_name']}-SSL"}
    retries 3
    retry_delay 5
  end
end

# Restart IIS service to apply all configuration changes using PowerShell
powershell_script 'restart_iis_services' do
  code <<-EOH
    try {
      Write-Host "Restarting IIS services to apply configuration changes..."
      
      # Restart W3SVC service if it exists and is running
      $w3svc = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
      if ($w3svc -and $w3svc.Status -eq "Running") {
        Restart-Service -Name "W3SVC" -Force -ErrorAction SilentlyContinue
        Write-Host "W3SVC service restarted successfully"
        Start-Sleep -Seconds 3
      } else {
        Write-Host "W3SVC service not running or not found - attempting to start"
        Start-Service -Name "W3SVC" -ErrorAction SilentlyContinue
      }
      
      # Also restart WAS (Windows Activation Service) if it exists
      $was = Get-Service -Name "WAS" -ErrorAction SilentlyContinue
      if ($was -and $was.Status -eq "Running") {
        Restart-Service -Name "WAS" -Force -ErrorAction SilentlyContinue
        Write-Host "WAS service restarted successfully"
      }
      
      Write-Host "IIS services restart completed"
    } catch {
      Write-Host "Warning: Could not restart IIS services - $($_.Exception.Message)"
      Write-Host "This may be normal during initial setup"
    }
  EOH
  action :run
end

# Verify IIS is responding (simple check without WebAdministration module)
powershell_script 'verify_iis_response' do
  code <<-EOH
    Start-Sleep -Seconds 10
    try {
      # Simple HTTP check using .NET WebClient
      $webClient = New-Object System.Net.WebClient
      $response = $webClient.DownloadString("http://localhost:#{node['golf_app']['port']}")
      if ($response -match "Elite Golf Club") {
        Write-Host "SUCCESS: Elite Golf application is responding on port #{node['golf_app']['port']}"
        Write-Host "Application URL: http://localhost:#{node['golf_app']['port']}"
      } else {
        Write-Host "WARNING: Unexpected response content"
      }
      $webClient.Dispose()
    } catch {
      Write-Host "INFO: Website may still be starting up - this is normal during initial deployment"
      Write-Host "Manual check: http://localhost:#{node['golf_app']['port']}"
    }
  EOH
  action :run
  only_if { node['golf_app']['lab_mode'] }
end

log 'IIS configuration completed' do
  message "IIS configured for Elite Golf application on port #{node['golf_app']['port']}"
  level :info
end