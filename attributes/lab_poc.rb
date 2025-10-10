# Lab POC Environment Configuration
# This file contains demo-friendly settings for customer presentations

# Lab environment settings
default['golf_app']['lab_mode'] = true
default['golf_app']['demo_data'] = true
default['golf_app']['quick_setup'] = true

# Demo-specific overrides
if node['golf_app']['lab_mode']
  # Use non-standard ports to avoid conflicts in lab environments
  default['golf_app']['port'] = 8080
  default['golf_app']['ssl_port'] = 8443
  
  # Simplified paths for demo
  case node['platform']
  when 'windows'
    default['golf_app']['web_root'] = 'C:/demo/golf-app'
  else
    default['golf_app']['web_root'] = '/opt/demo/golf-app'
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