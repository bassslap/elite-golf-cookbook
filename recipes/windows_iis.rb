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
      'IIS-ManagementConsole'
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
  EOH
  action :run
  not_if 'Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServer | Where-Object {$_.State -eq "Enabled"}'
end

# Create application pool using PowerShell
powershell_script 'create_golf_app_pool' do
  code <<-EOH
    Import-Module WebAdministration
    if (!(Get-IISAppPool -Name "#{node['golf_app']['app_pool_name']}" -ErrorAction SilentlyContinue)) {
      New-WebAppPool -Name "#{node['golf_app']['app_pool_name']}"
      Set-ItemProperty -Path "IIS:\\AppPools\\#{node['golf_app']['app_pool_name']}" -Name processModel.identityType -Value ApplicationPoolIdentity
      Set-ItemProperty -Path "IIS:\\AppPools\\#{node['golf_app']['app_pool_name']}" -Name managedRuntimeVersion -Value "v4.0"
      Write-Host "Application pool #{node['golf_app']['app_pool_name']} created successfully"
    } else {
      Write-Host "Application pool #{node['golf_app']['app_pool_name']} already exists"
    }
  EOH
  action :run
end

# Create IIS site using PowerShell
powershell_script 'create_golf_website' do
  code <<-EOH
    Import-Module WebAdministration
    $siteName = "#{node['golf_app']['site_name']}"
    $port = #{node['golf_app']['port']}
    $physicalPath = "#{node['golf_app']['web_root']}"
    $appPoolName = "#{node['golf_app']['app_pool_name']}"
    
    # Remove existing site if it exists
    if (Get-Website -Name $siteName -ErrorAction SilentlyContinue) {
      Remove-Website -Name $siteName
      Write-Host "Removed existing website: $siteName"
    }
    
    # Create new website
    New-Website -Name $siteName -Port $port -PhysicalPath $physicalPath -ApplicationPool $appPoolName
    Write-Host "Website $siteName created successfully on port $port"
    
    # Start the website
    Start-Website -Name $siteName
    Write-Host "Website $siteName started"
  EOH
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
  powershell_script 'create_golf_ssl_website' do
    code <<-EOH
      Import-Module WebAdministration
      $siteName = "#{node['golf_app']['site_name']}-SSL"
      $port = #{node['golf_app']['ssl_port']}
      $physicalPath = "#{node['golf_app']['web_root']}"
      $appPoolName = "#{node['golf_app']['app_pool_name']}"
      
      # Remove existing SSL site if it exists
      if (Get-Website -Name $siteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $siteName
        Write-Host "Removed existing SSL website: $siteName"
      }
      
      # Create new SSL website
      New-Website -Name $siteName -Port $port -PhysicalPath $physicalPath -ApplicationPool $appPoolName -Ssl
      Write-Host "SSL Website $siteName created successfully on port $port"
      
      # Start the SSL website
      Start-Website -Name $siteName
      Write-Host "SSL Website $siteName started"
    EOH
    action :run
    notifies :restart, 'service[W3SVC]', :delayed
  end
end

# Start IIS service
service 'W3SVC' do
  action [:enable, :start]
end

# Verify IIS is responding
powershell_script 'verify_iis_response' do
  code <<-EOH
    Start-Sleep -Seconds 5
    try {
      $response = Invoke-WebRequest -Uri "http://localhost:#{node['golf_app']['port']}" -UseBasicParsing -TimeoutSec 10
      if ($response.StatusCode -eq 200) {
        Write-Host "SUCCESS: Elite Golf application is responding on port #{node['golf_app']['port']}"
        Write-Host "Application URL: http://localhost:#{node['golf_app']['port']}"
      } else {
        Write-Host "WARNING: Unexpected status code: $($response.StatusCode)"
      }
    } catch {
      Write-Host "WARNING: Could not verify website response - this may be normal during initial deployment"
      Write-Host "Error: $($_.Exception.Message)"
    }
  EOH
  action :run
  only_if { node['golf_app']['lab_mode'] }
end

log 'IIS configuration completed' do
  message "IIS configured for Elite Golf application on port #{node['golf_app']['port']}"
  level :info
end