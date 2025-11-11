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
