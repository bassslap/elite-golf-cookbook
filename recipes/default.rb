#
# Cookbook:: elite-golf-cookbook
# Recipe:: default
#
# Copyright:: 2025, Elite Golf Team, All Rights Reserved.

# Create web root directory
directory node['golf_app']['web_root'] do
  recursive true
  action :create
  if platform?('windows')
    rights :full_control, 'IIS_IUSRS'
    rights :full_control, 'IUSR'
  else
    owner node['golf_app']['user']
    group node['golf_app']['group']
    mode '0755'
  end
end

# Deploy the web application files with dynamic system information
template "#{node['golf_app']['web_root']}/index.html" do
  source 'index.html.erb'
  if platform?('windows')
    rights :read, 'IIS_IUSRS'
    rights :read, 'IUSR'
  else
    owner node['golf_app']['user']
    group node['golf_app']['group']
    mode '0644'
  end
  action :create
  variables(
    hostname: node['hostname'],
    platform: node['platform'],
    platform_version: node['platform_version'],
    architecture: node['kernel']['machine'],
    chef_version: Chef::VERSION
  )
end

# Create server time update script
if platform?('windows')
  # Windows PowerShell script to update server time JSON
  template "#{node['golf_app']['web_root']}/update-time.ps1" do
    source 'update-time.ps1.erb'
    mode '0755'
    variables(
      web_root: node['golf_app']['web_root'],
      hostname: node['hostname'],
      platform: node['platform'],
      platform_version: node['platform_version'],
      timezone: node['time']['timezone']
    )
  end

  # Run the time update script immediately to create initial server-time.json
  powershell_script 'create_initial_server_time' do
    code <<-EOH
      $scriptPath = "#{node['golf_app']['web_root']}\\update-time.ps1"
      Write-Host "Running initial server time update..."
      & $scriptPath
      Write-Host "Initial server-time.json created"
    EOH
    action :run
  end

  # Create a simple background PowerShell script that runs continuously
  template "#{node['golf_app']['web_root']}/time-updater-service.ps1" do
    source 'time-updater-service.ps1.erb'
    mode '0755'
    variables(
      script_path: "#{node['golf_app']['web_root']}\\update-time.ps1"
    )
  end

  # Start the background time updater using a simple approach
  powershell_script 'start_time_updater_background' do
    code <<-EOH
      $servicePath = "#{node['golf_app']['web_root']}\\time-updater-service.ps1"
      
      # Kill any existing time updater processes
      Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like "*time-updater-service.ps1*"} | Stop-Process -Force -ErrorAction SilentlyContinue
      
      # Start new background process
      Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$servicePath`"" -WindowStyle Hidden
      
      Write-Host "Started background time updater service"
    EOH
    action :run
  end
  
  # Simple verification - just ensure initial server-time.json exists
  powershell_script 'verify_server_time_setup' do
    code <<-EOH
      $timeFile = "#{node['golf_app']['web_root']}\\server-time.json"
      
      Write-Host "Checking server time setup..."
      
      # Wait briefly for initial file creation
      Start-Sleep -Seconds 3
      
      if (Test-Path $timeFile) {
        Write-Host "✅ server-time.json file found"
        
        # Quick content check
        try {
          $content = Get-Content $timeFile -Raw -ErrorAction SilentlyContinue
          if ($content -and $content.Length -gt 10) {
            Write-Host "✅ File has content ($($content.Length) characters)"
          } else {
            Write-Host "⚠️ File exists but may be empty"
          }
        } catch {
          Write-Host "⚠️ Could not read file: $($_.Exception.Message)"
        }
        
      } else {
        Write-Host "❌ server-time.json not found - server time may not work"
        
        # Try to run update script manually once
        $updateScript = "#{node['golf_app']['web_root']}\\update-time.ps1"
        if (Test-Path $updateScript) {
          Write-Host "Trying to create time file manually..."
          try {
            & $updateScript
            if (Test-Path $timeFile) {
              Write-Host "✅ Manual creation successful"
            }
          } catch {
            Write-Host "❌ Manual creation failed: $($_.Exception.Message)"
          }
        }
      }
    EOH
    action :run
    ignore_failure true
  end
else
  # Linux shell script to update server time JSON
  template "#{node['golf_app']['web_root']}/update-time.sh" do
    source 'update-time.sh.erb'
    mode '0755'
    variables(
      web_root: node['golf_app']['web_root'],
      hostname: node['hostname'],
      platform: node['platform'],
      platform_version: node['platform_version'],
      timezone: node['time']['timezone']
    )
  end

  # Create cron job to update time every 2 seconds using systemd timer approach
  template '/etc/systemd/system/elite-golf-time.service' do
    source 'elite-golf-time.service.erb'
    mode '0644'
    variables(
      script_path: "#{node['golf_app']['web_root']}/update-time.sh"
    )
    notifies :run, 'execute[reload_systemd]', :immediately
  end

  template '/etc/systemd/system/elite-golf-time.timer' do
    source 'elite-golf-time.timer.erb'
    mode '0644'
    notifies :run, 'execute[reload_systemd]', :immediately
  end

  execute 'reload_systemd' do
    command 'systemctl daemon-reload'
    action :nothing
  end

  service 'elite-golf-time.timer' do
    action [:enable, :start]
  end
end

# Platform-specific web server configuration
if platform?('windows')
  # Configure IIS
  include_recipe 'elite-golf-cookbook::windows_iis'
else
  # Configure Apache on Linux
  include_recipe 'elite-golf-cookbook::linux_apache'
end

# Log deployment completion
log 'Elite Golf Cookbook deployment completed' do
  message "Elite Golf web application deployed to #{node['golf_app']['web_root']} using #{node['golf_app']['web_server']}"
  level :info
end
