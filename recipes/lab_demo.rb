#
# Cookbook:: elite-golf-cookbook
# Recipe:: lab_demo
#
# Lab POC recipe with enhanced features for customer demonstrations

# Include base recipe
include_recipe 'elite-golf-cookbook::default'

# Add health check endpoint for monitoring demonstrations
cookbook_file "#{node['golf_app']['web_root']}/health" do
  source 'health.html'
  case node['platform']
  when 'windows'
    rights :read, 'IIS_IUSRS'
    rights :read, 'IUSR'
  else
    owner node['golf_app']['user']
    group node['golf_app']['group']
    mode '0644'
  end
  action :create
end

# Create metrics endpoint for compliance demonstration
template "#{node['golf_app']['web_root']}/metrics.json" do
  source 'metrics.json.erb'
  variables(
    deployment_time: Time.now.utc.iso8601,
    chef_version: Chef::VERSION,
    cookbook_version: node['golf_app']['poc_version'],
    platform: node['platform'],
    hostname: node['hostname']
  )
  case node['platform']
  when 'windows'
    rights :read, 'IIS_IUSRS'
    rights :read, 'IUSR'
  else
    owner node['golf_app']['user']
    group node['golf_app']['group']
    mode '0644'
  end
  action :create
end

# Add demo configuration file for customer visibility
file "#{node['golf_app']['web_root']}/demo-config.txt" do
  content <<~EOH
    Elite Golf Cookbook - Lab POC Configuration
    ==========================================
    
    Customer: #{node['golf_app']['customer_name']}
    POC Version: #{node['golf_app']['poc_version']}
    Deployment Date: #{Time.now.strftime('%Y-%m-%d %H:%M:%S UTC')}
    Platform: #{node['platform']} #{node['platform_version']}
    Chef Version: #{Chef::VERSION}
    Web Server: #{node['golf_app']['web_server']}
    
    Application URLs:
    - Main Site: http://#{node['ipaddress'] || 'localhost'}:#{node['golf_app']['port']}
    - Health Check: http://#{node['ipaddress'] || 'localhost'}:#{node['golf_app']['port']}/health
    - Metrics: http://#{node['ipaddress'] || 'localhost'}:#{node['golf_app']['port']}/metrics.json
    
    Configuration:
    - Web Root: #{node['golf_app']['web_root']}
    - HTTP Port: #{node['golf_app']['port']}
    - SSL Port: #{node['golf_app']['ssl_port']}
    - SSL Enabled: #{node['golf_app']['enable_ssl']}
    - Compliance Mode: #{node['golf_app']['compliance_mode']}
    
    This is a demonstration environment for Chef capabilities.
  EOH
  case node['platform']
  when 'windows'
    rights :read, 'IIS_IUSRS'
    rights :read, 'IUSR'
  else
    owner node['golf_app']['user']
    group node['golf_app']['group']
    mode '0644'
  end
  action :create
end

# Create log directory for demo purposes
directory "#{node['golf_app']['web_root']}/logs" do
  case node['platform']
  when 'windows'
    rights :full_control, 'IIS_IUSRS'
    rights :full_control, 'IUSR'
  else
    owner node['golf_app']['user']
    group node['golf_app']['group']
    mode '0755'
  end
  action :create
end

# Add deployment log
file "#{node['golf_app']['web_root']}/logs/deployment.log" do
  content "#{Time.now.utc.iso8601}: Elite Golf Cookbook POC deployed successfully on #{node['platform']}\n"
  case node['platform']
  when 'windows'
    rights :modify, 'IIS_IUSRS'
    rights :modify, 'IUSR'
  else
    owner node['golf_app']['user']
    group node['golf_app']['group']
    mode '0644'
  end
  action :create_if_missing
end

# Log POC completion
log 'Elite Golf POC deployment completed' do
  message "Lab POC deployed for #{node['golf_app']['customer_name']} - Access at http://#{node['ipaddress'] || 'localhost'}:#{node['golf_app']['port']}"
  level :info
end