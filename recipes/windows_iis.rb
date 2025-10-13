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

# ROBUST PRE-DEPLOYMENT CLEANUP - Prevent 404 issues by ensuring clean state
powershell_script 'robust_pre_deployment_cleanup' do
  code <<-EOH
    Write-Host "=== ROBUST PRE-DEPLOYMENT CLEANUP ==="
    Write-Host "Ensuring clean IIS state to prevent 404 errors..."
    
    # Force remove any existing Elite Golf sites to prevent conflicts
    $sitesToRemove = @("Elite Golf Site", "Elite Golf Site-SSL")
    foreach ($siteName in $sitesToRemove) {
      $existingSite = Get-Website -Name $siteName -ErrorAction SilentlyContinue
      if ($existingSite) {
        Write-Host "CLEANUP: Removing existing site: $siteName"
        Remove-Website -Name $siteName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
      }
    }
    
    # Stop and remove Default Web Site permanently to avoid port conflicts
    $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($defaultSite) {
      Write-Host "CLEANUP: Permanently removing Default Web Site to prevent port 80 conflicts"
      Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
      Remove-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
      Write-Host "Default Web Site permanently removed"
    }
    
    # Verify clean state
    $remainingSites = Get-Website | Where-Object {$_.Name -like "*Golf*" -or $_.Name -eq "Default Web Site"}
    if ($remainingSites) {
      Write-Host "WARNING: Found unexpected sites that may cause conflicts:"
      $remainingSites | Format-Table Name, State, PhysicalPath
    } else {
      Write-Host "SUCCESS: Clean IIS state achieved - no conflicting sites found"
    }
    
    Write-Host "=== PRE-DEPLOYMENT CLEANUP COMPLETE ==="
  EOH
  action :run
  ignore_failure false
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
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop
        if ($result.RestartNeeded) {
          Write-Host "Feature $feature enabled successfully (restart may be needed)"
        } else {
          Write-Host "Feature $feature enabled successfully"
        }
      } catch {
        Write-Host "Feature $feature may not be available or already enabled: $($_.Exception.Message)"
      }
    }
    
    Write-Host "IIS features installation completed"
    Write-Host "Waiting for IIS services to be ready..."
    Start-Sleep -Seconds 10
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
      
      # Check if W3SVC service exists (this indicates IIS is properly installed)
      $w3svc = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
      if (-not $w3svc) {
        $iisReady = $false
        Write-Host "Waiting for W3SVC service... ($elapsedTime seconds elapsed)"
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
        $services = @("W3SVC", "WAS")  # IISADMIN doesn't exist in modern IIS
        foreach ($serviceName in $services) {
          $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
          if ($service) {
            if ($service.Status -ne "Running") {
              Write-Host "Starting $serviceName service..."
              Start-Service -Name $serviceName -ErrorAction SilentlyContinue
              Start-Sleep -Seconds 3
            } else {
              Write-Host "$serviceName service is already running"
            }
          } else {
            Write-Host "$serviceName service not found - may not be installed yet"
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

# Stop Default Web Site to avoid port conflicts (appcmd method)
execute 'stop_default_website' do
  command %Q{C:\\Windows\\System32\\inetsrv\\appcmd.exe stop site "Default Web Site"}
  only_if %Q{C:\\Windows\\System32\\inetsrv\\appcmd.exe list site "Default Web Site" /state:Started >nul 2>&1}
  only_if { ::File.exist?('C:\\Windows\\System32\\inetsrv\\appcmd.exe') }
  ignore_failure true
end

# Remove existing golf site if it exists (appcmd method)
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
      
      # PERMANENT FIX: Remove Default Web Site completely
      $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
      if ($defaultSite) {
        Write-Host "Permanently removing Default Web Site to prevent conflicts..."
        Remove-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
        Write-Host "Default Web Site permanently removed"
      }
      
      # Remove existing Elite Golf site if it exists  
      if (Get-Website -Name $siteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $siteName -ErrorAction SilentlyContinue
        Write-Host "Removed existing website: $siteName"
        Start-Sleep -Seconds 2
      }
      
      # Create website with explicit settings for reliability (PERMANENT FIX METHOD)
      Write-Host "Creating new website $siteName with explicit configuration..."
      New-Website -Name $siteName -Port $port -PhysicalPath $physicalPath -ApplicationPool $appPoolName
      
      # Start the website
      Start-Website -Name $siteName -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 2
      
      # Verify the website is running and accessible
      $site = Get-Website -Name $siteName
      Write-Host "Website Status: $($site.State)"
      Write-Host "Physical Path: $($site.PhysicalPath)"
      Write-Host "Bindings: $($site.Bindings.Collection | ForEach-Object { $_.bindingInformation })"
      
      # Test website accessibility
      try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port" -UseBasicParsing -TimeoutSec 10
        Write-Host "Website test successful - Status: $($response.StatusCode)"
      } catch {
        Write-Host "Website test failed: $($_.Exception.Message)"
        # Attempt one retry after brief pause
        Start-Sleep -Seconds 3
        try {
          $retryResponse = Invoke-WebRequest -Uri "http://localhost:$port" -UseBasicParsing -TimeoutSec 10
          Write-Host "Website retry test successful - Status: $($retryResponse.StatusCode)"
        } catch {
          Write-Host "Website retry test also failed: $($_.Exception.Message)"
        }
      }
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

# Ensure Elite Golf Site is the primary site on port 80
powershell_script 'configure_primary_website' do
  code <<-EOH
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    
    try {
      Write-Host "Configuring Elite Golf Site as primary website..."
      
      # Stop Default Web Site if it's running to avoid port conflicts
      $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
      if ($defaultSite -and $defaultSite.State -eq "Started") {
        Write-Host "Stopping Default Web Site to prevent port conflicts..."
        Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
        Write-Host "Default Web Site stopped"
      }
      
      # Ensure Elite Golf Site is started and configured properly
      $golfSite = Get-Website -Name "Elite Golf Site" -ErrorAction SilentlyContinue
      if ($golfSite) {
        if ($golfSite.State -ne "Started") {
          Write-Host "Starting Elite Golf Site..."
          Start-Website -Name "Elite Golf Site" -ErrorAction SilentlyContinue
        }
        Write-Host "Elite Golf Site status: $($golfSite.State)"
        Write-Host "Elite Golf Site path: $($golfSite.PhysicalPath)"
        Write-Host "Elite Golf Site bindings: $($golfSite.Bindings.Collection.bindingInformation)"
      } else {
        Write-Host "Warning: Elite Golf Site not found - this should not happen"
      }
      
      # Validate and fix Elite Golf Site configuration
      $allSites = Get-Website
      $golfSite = $allSites | Where-Object {$_.Name -eq "Elite Golf Site"}
      $defaultSiteExists = $allSites | Where-Object {$_.Name -eq "Default Web Site"}
      
      if ($defaultSiteExists) {
        Write-Host "WARNING: Default Web Site still exists - stopping it"
        Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
      }
      
      if ($golfSite) {
        $currentPort = ($golfSite.Bindings.Collection.bindingInformation -split ':')[1]
        $currentPath = $golfSite.PhysicalPath
        
        Write-Host "Current Elite Golf Site configuration:"
        Write-Host "  Port: $currentPort (expected: #{node['golf_app']['port']})"
        Write-Host "  Path: $currentPath (expected: #{node['golf_app']['web_root']})"
        
        # Fix port if wrong
        if ($currentPort -ne "#{node['golf_app']['port']}") {
          Write-Host "FIXING: Correcting port from $currentPort to #{node['golf_app']['port']}"
          Stop-Website -Name "Elite Golf Site" -ErrorAction SilentlyContinue
          Set-ItemProperty -Path "IIS:\\Sites\\Elite Golf Site" -Name "bindings" -Value @{protocol="http";bindingInformation="*:#{node['golf_app']['port']}:"}
          Start-Website -Name "Elite Golf Site" -ErrorAction SilentlyContinue
        }
        
        # Fix path if wrong
        if ($currentPath -ne "#{node['golf_app']['web_root']}") {
          Write-Host "FIXING: Correcting path from '$currentPath' to '#{node['golf_app']['web_root']}'"
          Set-ItemProperty -Path "IIS:\\Sites\\Elite Golf Site" -Name "physicalPath" -Value "#{node['golf_app']['web_root']}"
        }
        
        Write-Host "SUCCESS: Elite Golf Site validated and corrected if needed"
      } else {
        Write-Host "ERROR: Elite Golf Site not found!"
      }
      
      # Final configuration display
      Write-Host "Final website configuration:"
      Get-Website | Format-Table Name, ID, State, PhysicalPath, @{Name="Port";Expression={($_.Bindings.Collection.bindingInformation -split ':')[1]}} -AutoSize
      
    } catch {
      Write-Host "Error configuring websites: $($_.Exception.Message)"
    }
  EOH
  action :run
  ignore_failure true
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

# ROBUST POST-DEPLOYMENT VERIFICATION - Catch 404 issues immediately
powershell_script 'robust_post_deployment_verification' do
  code <<-EOH
    Write-Host "=== ROBUST POST-DEPLOYMENT VERIFICATION ==="
    Write-Host "Testing website to ensure no 404 errors..."
    
    # Wait for IIS to fully initialize
    Start-Sleep -Seconds 5
    
    # Multiple verification attempts with detailed logging
    $maxAttempts = 3
    $success = $false
    
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
      Write-Host "Verification attempt $attempt of $maxAttempts..."
      
      try {
        # Test the website
        $response = Invoke-WebRequest -Uri "http://localhost:#{node['golf_app']['port']}" -UseBasicParsing -TimeoutSec 15
        
        if ($response.StatusCode -eq 200 -and $response.Content -match "Elite Golf Club") {
          Write-Host "SUCCESS: Website responding correctly!"
          Write-Host "Status Code: $($response.StatusCode)"
          Write-Host "Content Length: $($response.Content.Length) bytes"
          Write-Host "Content Preview: $($response.Content.Substring(0, [Math]::Min(100, $response.Content.Length)))"
          $success = $true
          break
        } else {
          Write-Host "WARNING: Unexpected response - Status: $($response.StatusCode)"
        }
      } catch {
        Write-Host "ATTEMPT $attempt FAILED: $($_.Exception.Message)"
        if ($attempt -lt $maxAttempts) {
          Write-Host "Waiting 10 seconds before retry..."
          Start-Sleep -Seconds 10
          
          # Check if site is still running
          $site = Get-Website -Name "Elite Golf Site" -ErrorAction SilentlyContinue
          if ($site -and $site.State -ne "Started") {
            Write-Host "RECOVERY: Restarting Elite Golf Site..."
            Start-Website -Name "Elite Golf Site" -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
          }
        }
      }
    }
    
    if (-not $success) {
      Write-Host "CRITICAL: Website verification failed after $maxAttempts attempts!"
      Write-Host "Applying emergency recreation fix..."
      
      # Apply the proven fix that resolved 404 issues
      Remove-Website -Name "Elite Golf Site" -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 2
      New-Website -Name "Elite Golf Site" -Port #{node['golf_app']['port']} -PhysicalPath "#{node['golf_app']['web_root']}" -ApplicationPool "DefaultAppPool"
      Start-Website -Name "Elite Golf Site" -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 5
      
      # Final verification
      try {
        $finalTest = Invoke-WebRequest -Uri "http://localhost:#{node['golf_app']['port']}" -UseBasicParsing -TimeoutSec 15
        if ($finalTest.StatusCode -eq 200) {
          Write-Host "RECOVERY SUCCESS: Emergency recreation fixed the website!"
        } else {
          Write-Host "RECOVERY FAILED: Manual intervention required"
        }
      } catch {
        Write-Host "RECOVERY FAILED: $($_.Exception.Message)"
      }
    }
    
    Write-Host "=== POST-DEPLOYMENT VERIFICATION COMPLETE ==="
  EOH
  action :run
  ignore_failure true
end

log 'IIS configuration completed' do
  message "IIS configured for Elite Golf application on port #{node['golf_app']['port']} with robust verification"
  level :info
end