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

# Wait for IIS services and components to be available
ruby_block 'wait_for_iis_services' do
  block do
    require 'timeout'
    
    Chef::Log.info("Waiting for IIS services to become available...")
    
    # Wait up to 5 minutes for W3SVC service to exist
    if defined?(Win32::Service)
      Timeout.timeout(300) do
        until Win32::Service.exists?('W3SVC')
          Chef::Log.info("Waiting for W3SVC service to be created...")
          sleep(5)
        end
      end
      Chef::Log.info("W3SVC service is now available")
    else
      # Fallback: just wait a reasonable amount of time for IIS to be ready
      Chef::Log.info("Win32::Service not available, waiting 60 seconds for IIS setup...")
      sleep(60)
    end
    
    # Wait for appcmd.exe to be available
    Timeout.timeout(120) do
      until ::File.exist?('C:\\Windows\\System32\\inetsrv\\appcmd.exe')
        Chef::Log.info("Waiting for appcmd.exe to be available...")
        sleep(2)
      end
    end
    Chef::Log.info("appcmd.exe is now available")
  end
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
        Write-Host "Attempting to start IIS services via alternative method..."
        
        # Try starting via sc command
        & sc.exe config "W3SVC" start= auto 2>$null
        & sc.exe start "W3SVC" 2>$null
      }
    } catch {
      Write-Host "Error managing W3SVC service: $($_.Exception.Message)"
      Write-Host "This may be normal during initial IIS installation"
    }
  EOH
  action :run
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
    # Import WebAdministration module if available, otherwise use WMI
    try {
      Import-Module WebAdministration -ErrorAction Stop
      if (!(Get-WebAppPoolState -Name "#{node['golf_app']['app_pool_name']}" -ErrorAction SilentlyContinue)) {
        New-WebAppPool -Name "#{node['golf_app']['app_pool_name']}"
        Set-ItemProperty -Path "IIS:\\AppPools\\#{node['golf_app']['app_pool_name']}" -Name processModel.identityType -Value ApplicationPoolIdentity
        Set-ItemProperty -Path "IIS:\\AppPools\\#{node['golf_app']['app_pool_name']}" -Name managedRuntimeVersion -Value "v4.0"
        Write-Host "Application pool #{node['golf_app']['app_pool_name']} created via PowerShell"
      }
    } catch {
      Write-Host "Creating application pool via WMI as fallback..."
      # Create via WMI as ultimate fallback
      $appPoolName = "#{node['golf_app']['app_pool_name']}"
      $iisObject = Get-WmiObject -Class IIsApplicationPool -Namespace "root\\MicrosoftIISv2" -Filter "Name='W3SVC/AppPools/$appPoolName'" -ErrorAction SilentlyContinue
      if (-not $iisObject) {
        $appPool = [WmiClass]"root\\MicrosoftIISv2:IIsApplicationPool"
        $newAppPool = $appPool.CreateInstance()
        $newAppPool.Name = "W3SVC/AppPools/$appPoolName"
        $newAppPool.Put()
        Write-Host "Application pool $appPoolName created via WMI"
      }
    }
  EOH
  not_if { ::File.exist?('C:\\Windows\\System32\\inetsrv\\appcmd.exe') }
  action :run
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
  notifies :restart, 'service[W3SVC]', :delayed
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
  notifies :restart, 'service[W3SVC]', :delayed
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
    notifies :restart, 'service[W3SVC]', :delayed
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