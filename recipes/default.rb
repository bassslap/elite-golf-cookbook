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

  # Create scheduled task to update time every 2 seconds
  powershell_script 'create_time_update_task' do
    code <<-EOH
      $scriptPath = "#{node['golf_app']['web_root']}\\update-time.ps1"
      $taskName = "EliteGolfTimeUpdate"
      
      # Remove existing task if it exists
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
      
      # Create new scheduled task that runs every 2 seconds
      $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
      $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Seconds 2) -RepetitionDuration (New-TimeSpan -Days 365)
      $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
      
      Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force
      Start-ScheduledTask -TaskName $taskName
      
      Write-Host "Created scheduled task to update server time every 2 seconds"
    EOH
    action :run
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
