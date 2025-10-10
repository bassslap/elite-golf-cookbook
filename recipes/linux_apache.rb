#
# Cookbook:: elite-golf-cookbook
# Recipe:: linux_apache
#
# Configures Apache for the Elite Golf web application on Linux

# Install Apache web server
package 'apache2' do
  case node['platform']
  when 'ubuntu', 'debian'
    package_name 'apache2'
  when 'centos', 'redhat', 'fedora'
    package_name 'httpd'
  end
  action :install
end

# Enable required Apache modules
%w(rewrite ssl headers deflate).each do |mod|
  execute "enable_#{mod}_module" do
    case node['platform']
    when 'ubuntu', 'debian'
      command "a2enmod #{mod}"
      not_if "apache2ctl -M | grep #{mod}"
    when 'centos', 'redhat', 'fedora'
      command "echo 'LoadModule #{mod}_module modules/mod_#{mod}.so' >> /etc/httpd/conf/httpd.conf"
      not_if "grep 'LoadModule #{mod}_module' /etc/httpd/conf/httpd.conf"
    end
  end
end

# Create virtual host configuration
template '/etc/apache2/sites-available/golf.conf' do
  source 'apache-vhost.conf.erb'
  variables(
    server_name: node['fqdn'] || 'localhost',
    document_root: node['golf_app']['web_root'],
    port: node['golf_app']['port'],
    ssl_port: node['golf_app']['ssl_port'],
    enable_ssl: node['golf_app']['enable_ssl']
  )
  case node['platform']
  when 'ubuntu', 'debian'
    path '/etc/apache2/sites-available/golf.conf'
  when 'centos', 'redhat', 'fedora'
    path '/etc/httpd/conf.d/golf.conf'
  end
  notifies :reload, 'service[apache2]', :delayed
end

# Enable the site on Ubuntu/Debian
execute 'enable_golf_site' do
  command 'a2ensite golf.conf'
  only_if { %w(ubuntu debian).include?(node['platform']) }
  not_if 'a2ensite -q golf'
  notifies :reload, 'service[apache2]', :delayed
end

# Disable default site on Ubuntu/Debian
execute 'disable_default_site' do
  command 'a2dissite 000-default'
  only_if { %w(ubuntu debian).include?(node['platform']) }
  only_if 'a2ensite -q 000-default'
  notifies :reload, 'service[apache2]', :delayed
end

# Ensure proper ownership of web directory
directory node['golf_app']['web_root'] do
  owner node['golf_app']['user']
  group node['golf_app']['group']
  mode '0755'
  recursive true
end

# Start and enable Apache service
service 'apache2' do
  case node['platform']
  when 'ubuntu', 'debian'
    service_name 'apache2'
  when 'centos', 'redhat', 'fedora'
    service_name 'httpd'
  end
  action [:enable, :start]
end

# Create SSL certificates if SSL is enabled
if node['golf_app']['enable_ssl']
  directory '/etc/ssl/certs' do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end

  directory '/etc/ssl/private' do
    owner 'root'
    group 'root'
    mode '0700'
    action :create
  end

  # Generate self-signed certificate for demo purposes
  execute 'generate_ssl_cert' do
    command <<-EOH
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/golf-key.pem \
        -out /etc/ssl/certs/golf-cert.pem \
        -subj "/C=US/ST=State/L=City/O=Elite Golf Club/CN=#{node['fqdn'] || 'localhost'}"
    EOH
    not_if { ::File.exist?('/etc/ssl/certs/golf-cert.pem') }
  end
end

log 'Apache configuration completed' do
  message "Apache configured for Elite Golf application on port #{node['golf_app']['port']}"
  level :info
end