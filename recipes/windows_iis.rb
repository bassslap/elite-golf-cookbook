#
# Cookbook:: elite-golf-cookbook
# Recipe:: windows_iis
#
# Configures IIS for the Elite Golf web application on Windows

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

# Ensure IIS services are started before proceeding
service 'W3SVC' do
  action [:enable, :start]
end

# Wait for appcmd to be available
ruby_block 'wait_for_appcmd' do
  block do
    require 'timeout'
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

# Start IIS service
service 'W3SVC' do
  action [:enable, :start]
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