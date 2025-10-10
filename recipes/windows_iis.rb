#
# Cookbook:: elite-golf-cookbook
# Recipe:: windows_iis
#
# Configures IIS for the Elite Golf web application on Windows

# Install IIS features
%w(IIS-WebServerRole IIS-WebServer IIS-CommonHttpFeatures IIS-DefaultDocument 
   IIS-DirectoryBrowsing IIS-ASPNET45 IIS-NetFxExtensibility45 IIS-ISAPIExtensions 
   IIS-ISAPIFilter IIS-HttpCompressionStatic IIS-Security IIS-RequestFiltering 
   IIS-StaticContent IIS-HttpRedirect IIS-HttpErrors IIS-HttpLogging).each do |feature|
  windows_feature feature do
    action :install
    install_method :windows_feature_powershell
  end
end

# Create application pool
iis_pool node['golf_app']['app_pool_name'] do
  runtime_version 'v4.0'
  pipeline_mode :Integrated
  action [:add, :config]
end

# Create IIS site
iis_site node['golf_app']['site_name'] do
  protocol :http
  port node['golf_app']['port']
  path node['golf_app']['web_root']
  application_pool node['golf_app']['app_pool_name']
  action [:add, :start]
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
  iis_site "#{node['golf_app']['site_name']}-ssl" do
    protocol :https
    port node['golf_app']['ssl_port']
    path node['golf_app']['web_root']
    application_pool node['golf_app']['app_pool_name']
    action [:add, :start]
  end
end

# Start IIS service
service 'W3SVC' do
  action [:enable, :start]
end

log 'IIS configuration completed' do
  message "IIS configured for Elite Golf application on port #{node['golf_app']['port']}"
  level :info
end