# Lab POC Environment Configuration
# This file contains demo-friendly settings for customer presentations

# Lab environment settings
default['golf_app']['lab_mode'] = true
default['golf_app']['demo_data'] = true
default['golf_app']['quick_setup'] = true

# Demo-specific overrides
if node['golf_app']['lab_mode']
  # Use standard HTTP port for customer demos (80 is expected)
  default['golf_app']['port'] = 80
  default['golf_app']['ssl_port'] = 443
  
  # Use standard IIS paths for better compatibility
  case node['platform']
  when 'windows'
    default['golf_app']['web_root'] = 'C:/inetpub/wwwroot/golf'
  else
    default['golf_app']['web_root'] = '/var/www/html/golf'
  end
  
  # Demo monitoring settings
  default['golf_app']['health_check'] = true
  default['golf_app']['metrics_enabled'] = true
  
  # Customer demo branding
  default['golf_app']['customer_name'] = 'Demo Customer Corp'
  default['golf_app']['poc_version'] = '1.0-POC'
end

# Compliance and monitoring
default['golf_app']['compliance_mode'] = true
default['golf_app']['audit_logging'] = true