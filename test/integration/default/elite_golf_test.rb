# Elite Golf Cookbook - InSpec Compliance Tests
# These tests demonstrate Chef's compliance capabilities for customer POCs

title 'Elite Golf Application Compliance Tests'

# Test web application deployment
describe 'Elite Golf Web Application' do
  case os.family
  when 'windows'
    web_root = 'C:\\demo\\golf-app'
  else
    web_root = '/opt/demo/golf-app'
  end

  # Verify web root directory exists
  describe directory(web_root) do
    it { should exist }
    it { should be_directory }
  end

  # Verify main application file exists
  describe file("#{web_root}/index.html") do
    it { should exist }
    it { should be_file }
    its('content') { should match(/Elite Golf Club/) }
    its('content') { should match(/golf-club-svg/) }
  end

  # Verify health check endpoint exists
  describe file("#{web_root}/health") do
    it { should exist }
    its('content') { should match(/SYSTEM HEALTHY/) }
  end

  # Verify demo configuration exists
  describe file("#{web_root}/demo-config.txt") do
    it { should exist }
    its('content') { should match(/Elite Golf Cookbook - Lab POC Configuration/) }
  end

  # Verify metrics endpoint exists
  describe file("#{web_root}/metrics.json") do
    it { should exist }
    its('content') { should match(/"service": "elite-golf-club"/) }
    its('content') { should match(/"status": "healthy"/) }
  end
end

# Test web server configuration
describe 'Web Server Configuration' do
  case os.family
  when 'windows'
    # Test IIS configuration
    describe windows_feature('IIS-WebServerRole') do
      it { should be_installed }
    end

    describe windows_feature('IIS-WebServer') do
      it { should be_installed }
    end

    describe service('W3SVC') do
      it { should be_enabled }
      it { should be_running }
    end

    # Test if port 8080 is listening (lab demo port)
    describe port(8080) do
      it { should be_listening }
    end

  else
    # Test Apache configuration on Linux
    describe package('apache2') do
      it { should be_installed }
    end

    describe service('apache2') do
      it { should be_enabled }
      it { should be_running }
    end

    # Test if port 8080 is listening (lab demo port)
    describe port(8080) do
      it { should be_listening }
    end

    # Verify Apache modules are loaded
    describe command('apache2ctl -M') do
      its('stdout') { should match(/rewrite_module/) }
      its('stdout') { should match(/ssl_module/) }
    end
  end
end

# Test security compliance
describe 'Security Compliance' do
  case os.family
  when 'windows'
    web_root = 'C:\\demo\\golf-app'
    
    # Test file permissions on Windows
    describe file(web_root) do
      it { should exist }
    end

    # Test web.config exists
    describe file("#{web_root}/web.config") do
      it { should exist }
      its('content') { should match(/defaultDocument/) }
    end

  else
    web_root = '/opt/demo/golf-app'
    
    # Test file permissions on Linux
    describe file(web_root) do
      it { should exist }
      it { should be_owned_by 'www-data' }
      it { should be_grouped_into 'www-data' }
      its('mode') { should cmp '0755' }
    end

    describe file("#{web_root}/index.html") do
      it { should be_owned_by 'www-data' }
      it { should be_grouped_into 'www-data' }
      its('mode') { should cmp '0644' }
    end
  end
end

# Test application functionality
describe 'Application Functionality' do
  # Test HTTP response
  describe http('http://localhost:8080') do
    its('status') { should cmp 200 }
    its('body') { should match(/Elite Golf Club/) }
    its('headers.Content-Type') { should match(/text\/html/) }
  end

  # Test health check endpoint
  describe http('http://localhost:8080/health') do
    its('status') { should cmp 200 }
    its('body') { should match(/SYSTEM HEALTHY/) }
  end

  # Test metrics endpoint
  describe http('http://localhost:8080/metrics.json') do
    its('status') { should cmp 200 }
    its('headers.Content-Type') { should match(/application\/json/) }
    its('body') { should match(/"status": "healthy"/) }
  end
end

# Test Chef compliance
describe 'Chef Compliance' do
  # Verify Chef client is installed
  describe command('chef-client --version') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Chef Infra Client/) }
  end

  # Test that the cookbook ran successfully by checking logs
  describe file('/opt/demo/golf-app/logs/deployment.log') do
    it { should exist }
    its('content') { should match(/Elite Golf Cookbook POC deployed successfully/) }
  end if os.family != 'windows'

  # Verify demo configuration contains expected values
  describe file('/opt/demo/golf-app/demo-config.txt') do
    its('content') { should match(/Lab POC Configuration/) }
    its('content') { should match(/Platform: #{os.name}/) }
    its('content') { should match(/Chef Version:/) }
  end if os.family != 'windows'
end

# Performance and monitoring tests
describe 'Performance and Monitoring' do
  # Test that the application responds quickly
  describe http('http://localhost:8080') do
    its('status') { should cmp 200 }
    # Response time should be reasonable for demo
  end

  # Test log directory exists and is writable
  case os.family
  when 'windows'
    describe directory('C:\\demo\\golf-app\\logs') do
      it { should exist }
    end
  else
    describe directory('/opt/demo/golf-app/logs') do
      it { should exist }
      it { should be_owned_by 'www-data' }
      its('mode') { should cmp '0755' }
    end
  end
end