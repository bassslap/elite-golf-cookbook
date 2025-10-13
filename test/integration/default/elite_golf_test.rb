# Elite Golf Cookbook - InSpec Compliance Tests
# These tests demonstrate Chef's compliance capabilities for customer POCs

title 'Elite Golf Application Compliance Tests'

# Test web application deployment
describe 'Elite Golf Web Application' do
  case os.family
  when 'windows'
    web_root = 'C:/inetpub/wwwroot/golf'
  else
    web_root = '/var/www/html/golf'
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

    # Test if port 80 is listening (default web port)
    describe port(80) do
      it { should be_listening }
    end

  else
    # Test web server is installed and running (Apache/httpd)
    describe.one do
      describe package('apache2') do
        it { should be_installed }
      end
      describe package('httpd') do
        it { should be_installed }
      end
    end

    describe.one do
      describe service('apache2') do
        it { should be_enabled }
        it { should be_running }
      end
      describe service('httpd') do
        it { should be_enabled }
        it { should be_running }
      end
    end

    # Test if port 80 is listening (default web port)
    describe port(80) do
      it { should be_listening }
    end
  end
end

# Test security compliance
describe 'Security Compliance' do
  case os.family
  when 'windows'
    web_root = 'C:/inetpub/wwwroot/golf'
    
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
    web_root = '/var/www/html/golf'
    
    # Test file permissions on Linux - basic checks
    describe file(web_root) do
      it { should exist }
      it { should be_directory }
      it { should be_readable.by('others') }
    end

    describe file("#{web_root}/index.html") do
      it { should exist }
      it { should be_file }
      it { should be_readable.by('others') }
    end
  end
end

# Test application functionality
describe 'Application Functionality' do
  # Test HTTP response
  describe http('http://localhost') do
    its('status') { should cmp 200 }
    its('body') { should match(/Elite Golf Club/) }
    its('headers.Content-Type') { should match(/text\/html/) }
  end

  # Test health check endpoint
  describe http('http://localhost/health') do
    its('status') { should cmp 200 }
    its('body') { should match(/SYSTEM HEALTHY/) }
  end

  # Test metrics endpoint
  describe http('http://localhost/metrics.json') do
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

  # Verify demo configuration contains expected values (Linux only)
  describe file('/var/www/html/golf/demo-config.txt') do
    it { should exist }
    its('content') { should match(/Lab POC Configuration/) }
    its('content') { should match(/Chef Version:/) }
  end if os.family != 'windows'

  # Verify demo configuration contains expected values (Windows)
  describe file('C:/inetpub/wwwroot/golf/demo-config.txt') do
    it { should exist }
    its('content') { should match(/Lab POC Configuration/) }
    its('content') { should match(/Chef Version:/) }
  end if os.family == 'windows'
end

# Performance and monitoring tests
describe 'Performance and Monitoring' do
  # Test that the application responds quickly
  describe http('http://localhost') do
    its('status') { should cmp 200 }
    # Response time should be reasonable for demo
  end

  # Test web root directory permissions
  case os.family
  when 'windows'
    describe directory('C:/inetpub/wwwroot/golf') do
      it { should exist }
    end
  else
    describe directory('/var/www/html/golf') do
      it { should exist }
      it { should be_readable.by('others') }
    end
  end
end