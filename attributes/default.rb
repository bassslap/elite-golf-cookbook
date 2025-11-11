# Default attributes for elite-golf-cookbook

# Common settings
default['golf_app']['app_name'] = 'Elite Golf Club'
default['golf_app']['port'] = 80
default['golf_app']['ssl_port'] = 443

# Platform-specific paths
if platform?('windows')
  default['golf_app']['web_root'] = 'C:/inetpub/wwwroot/golf'
  default['golf_app']['web_server'] = 'iis'
  default['golf_app']['site_name'] = 'Elite Golf Site'
  default['golf_app']['app_pool_name'] = 'EliteGolfAppPool'
else
  default['golf_app']['web_root'] = '/var/www/html/golf'
  default['golf_app']['web_server'] = 'apache'
  default['golf_app']['user'] = 'www-data'
  default['golf_app']['group'] = 'www-data'
end

# Application settings
default['golf_app']['enable_ssl'] = false
default['golf_app']['maintenance_mode'] = false\


# Enable audit cookbook and configure reporting for Automate
default['audit']['compliance_phase'] = true
default['audit']['fetcher'] = 'chef-automate'
default['audit']['reporter'] = %w(chef-server-automate cli)
