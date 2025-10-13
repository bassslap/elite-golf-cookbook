# Elite Golf Cookbook

A Chef cookbook that deploys a simple, elegant golf-themed web application with cross-platform support for both Windows IIS and Linux Apache web servers. **Designed specifically for customer POC demonstrations and lab environments.**

## Description

This cookbook creates a beautiful golf club website featuring:
- Responsive HTML5 design with CSS3 styling
- Custom SVG golf club illustration
- Cross-platform support (Windows IIS & Linux Apache)
- **Lab POC mode with demo-friendly configurations**
- **Health check and metrics endpoints for monitoring demonstrations**
- **Chef InSpec compliance tests for security validation**
- **Quick deployment scripts for customer demos**
- Configurable attributes for different environments
- SSL/HTTPS support
- Professional golf club branding

## 🎯 Lab POC Features

This cookbook includes special features designed for customer demonstrations:

- **Quick Demo Scripts**: One-click deployment for Windows and Linux
- **Health Monitoring**: Real-time system status dashboard
- **Metrics API**: JSON endpoint showing deployment status and compliance
- **Multiple Environments**: Development, demo, and production simulation configs
- **Compliance Testing**: Automated InSpec tests for security validation
- **Customer Branding**: Customizable customer name and POC versioning

## Supported Platforms

- **Windows Server** (with IIS)
- **Ubuntu** (with Apache2)
- **CentOS/RHEL** (with Apache/httpd)
- **Debian** (with Apache2)

## Dependencies

### Windows
- `iis` cookbook (automatically included for Windows platforms)

### Linux
- Apache2 web server (automatically installed)

## Attributes

### Common Settings
- `node['golf_app']['app_name']` - Application name (default: 'Elite Golf Club')
- `node['golf_app']['port']` - HTTP port (default: 80)
- `node['golf_app']['ssl_port']` - HTTPS port (default: 443)
- `node['golf_app']['enable_ssl']` - Enable SSL/HTTPS (default: false)
- `node['golf_app']['maintenance_mode']` - Enable maintenance mode (default: false)

### Platform-Specific Settings

#### Windows (IIS)
- `node['golf_app']['web_root']` - Web root directory (default: 'C:/inetpub/wwwroot/golf')
- `node['golf_app']['site_name']` - IIS site name (default: 'Elite Golf Site')
- `node['golf_app']['app_pool_name']` - Application pool name (default: 'EliteGolfAppPool')

#### Linux (Apache)
- `node['golf_app']['web_root']` - Web root directory (default: '/var/www/html/golf')
- `node['golf_app']['user']` - Web server user (default: 'www-data')
- `node['golf_app']['group']` - Web server group (default: 'www-data')

## 🚀 Quick Demo Deployment

For customer POC demonstrations, use the provided demo scripts:

### Linux Demo Deployment
```bash
# Make script executable
chmod +x demo-scripts/deploy-linux-demo.sh

# Run with defaults
./demo-scripts/deploy-linux-demo.sh

# Run with custom customer name and port
./demo-scripts/deploy-linux-demo.sh "Acme Corp" 9000

# Run with Chef Zero for full Chef Server simulation
./demo-scripts/deploy-linux-demo.sh "Acme Corp" 8080 zero
```

### Windows Demo Deployment
```cmd
REM Run with defaults
demo-scripts\deploy-windows-demo.bat

REM Run with custom customer name and port
demo-scripts\deploy-windows-demo.bat "Acme Corp" 9000

REM Run with Chef Zero for full Chef Server simulation
demo-scripts\deploy-windows-demo.bat "Acme Corp" 8080 zero
```

### Demo Endpoints
After deployment, access these demo URLs:
- **Main Application**: `http://localhost:8080`
- **Health Check**: `http://localhost:8080/health` (Real-time monitoring dashboard)
- **Metrics API**: `http://localhost:8080/metrics.json` (JSON deployment status)
- **Demo Config**: `http://localhost:8080/demo-config.txt` (Configuration summary)

## Usage

### Basic Usage

Add the cookbook to your node's run list:

```json
{
  "run_list": ["recipe[elite-golf-cookbook]"]
}
```

### Custom Configuration

Override default attributes in your node configuration:

```json
{
  "golf_app": {
    "port": 8080,
    "enable_ssl": true,
    "web_root": "/var/www/elite-golf"
  },
  "run_list": ["recipe[elite-golf-cookbook]"]
}
```

### Lab POC Mode

For demonstration environments:

```json
{
  "golf_app": {
    "lab_mode": true,
    "customer_name": "Acme Corporation",
    "port": 8080,
    "enable_ssl": false,
    "quick_setup": true,
    "compliance_mode": true,
    "health_check": true,
    "metrics_enabled": true
  },
  "run_list": ["recipe[elite-golf-cookbook::lab_demo]"]
}
```

### Environment-Specific Configuration

#### Development Environment
```json
{
  "golf_app": {
    "port": 3000,
    "enable_ssl": false
  }
}
```

#### Production Environment
```json
{
  "golf_app": {
    "port": 80,
    "ssl_port": 443,
    "enable_ssl": true
  }
}
```

## Recipes

### `elite-golf-cookbook::default`
The main recipe that:
- Creates the web root directory with proper permissions
- Deploys the HTML application files
- Detects platform and includes appropriate sub-recipes
- Configures platform-specific web server settings

### `elite-golf-cookbook::lab_demo` ⭐
**POC-specific recipe** that includes all default functionality plus:
- Health check endpoint deployment
- Metrics API with real-time status
- Demo configuration file generation
- Enhanced logging for demonstrations
- Customer branding integration

### `elite-golf-cookbook::windows_iis`
Windows-specific recipe that:
- Installs required IIS features
- Creates and configures application pool
- Sets up IIS site with proper bindings
- Deploys web.config for IIS configuration
- Configures SSL if enabled

### `elite-golf-cookbook::linux_apache`
Linux-specific recipe that:
- Installs Apache web server
- Enables required Apache modules
- Creates virtual host configuration
- Sets up SSL certificates (self-signed for demo)
- Configures proper file permissions

## Compliance Testing

This cookbook includes comprehensive Chef InSpec tests for compliance demonstration:

```bash
# Run compliance tests after deployment
inspec exec test/integration/default/elite_golf_test.rb -t local://

# Run specific test categories
inspec exec test/integration/default/elite_golf_test.rb -t local:// --controls "Web Server Configuration"
```

### Test Categories:
- **Application Deployment**: Verifies all files are properly deployed
- **Web Server Configuration**: Validates web server setup and services
- **Security Compliance**: Checks file permissions and security settings
- **Application Functionality**: Tests HTTP responses and endpoints
- **Chef Compliance**: Validates Chef execution and configuration
- **Performance Monitoring**: Verifies monitoring endpoints and logs

## Environment Files

Pre-configured environments for different demonstration scenarios:

- **`environments/development.json`**: Local development and testing
- **`environments/customer-demo.json`**: Customer POC demonstrations
- **`environments/production-simulation.json`**: Production-like environment simulation

Use with:
```bash
chef-client --environment customer-demo --json-attributes node.json
```

## File Structure

```
elite-golf-cookbook/
├── attributes/
│   └── default.rb              # Default attribute values
├── files/
│   └── default/
│       └── index.html          # Main web application
├── recipes/
│   ├── default.rb              # Main recipe
│   ├── windows_iis.rb          # Windows IIS configuration
│   └── linux_apache.rb         # Linux Apache configuration
├── templates/
│   ├── web.config.erb          # IIS web.config template
│   └── apache-vhost.conf.erb   # Apache virtual host template
├── metadata.rb                 # Cookbook metadata
└── README.md                   # This file
```

## 🔧 Development & Deployment Workflow

**IMPORTANT:** Follow this workflow when making changes to ensure proper versioning and deployment.

### Making Changes to the Cookbook

#### 1. **Update Version Number**
```bash
# Edit metadata.rb and increment the version
nano metadata.rb
# Change: version '1.0.3' to version '1.0.4' (or appropriate semantic version)
```

#### 2. **Commit Changes to Git**
```bash
# Add all changes
git add .

# Commit with descriptive message
git commit -m "Description of changes - Update to version X.X.X"

# Push to remote repository
git push origin main
```

#### 3. **Deploy to Workstation and Chef Server**
```bash
# On your Chef workstation (ubuntu@workstation-linux-01)
cd ~/chef-repo/cookbooks/elite-golf-cookbook

# Pull latest changes
git pull origin main

# Upload to Chef Server
cd ~/chef-repo
knife cookbook upload elite-golf-cookbook --cookbook-path ./cookbooks

# Verify upload
knife cookbook show elite-golf-cookbook
```

#### 4. **Deploy to Target Nodes**
```bash
# Run chef-client on specific node
knife ssh "name:node-name" "chef-client" -x administrator

# Or run on multiple nodes
knife ssh "recipe:elite-golf-cookbook" "chef-client" -x username

# Monitor in Chef Automate for results
```

### Version Management Guidelines

- **Patch versions (1.0.X)**: Bug fixes, small improvements, config changes
- **Minor versions (1.X.0)**: New features, recipe additions, significant enhancements  
- **Major versions (X.0.0)**: Breaking changes, platform support changes, major refactoring

### Pre-Deployment Checklist

- [ ] Version number updated in `metadata.rb`
- [ ] Changes committed to git with descriptive message
- [ ] Changes pushed to remote repository
- [ ] Cookbook uploaded to Chef Server with new version
- [ ] Target nodes identified for deployment
- [ ] Chef Automate dashboard ready for monitoring
- [ ] Rollback plan prepared (previous cookbook version noted)

### Emergency Rollback Procedure

If deployment fails:

```bash
# Upload previous version (replace X.X.X with last known good version)
knife cookbook upload elite-golf-cookbook@X.X.X --cookbook-path ./cookbooks

# Force chef-client run with previous version
knife ssh "name:node-name" "chef-client" -x administrator

# Or pin to specific version in environment/node attributes
# "cookbook_versions": { "elite-golf-cookbook": "= X.X.X" }
```

### Testing Workflow

1. **Development**: Test locally with `chef-client --local-mode`
2. **Staging**: Deploy to test nodes first
3. **Production**: Deploy to production nodes after validation
4. **Verification**: Check health endpoints and Chef Automate compliance

## Deployment Examples

### Windows Server with Chef Client

```powershell
# Install Chef Client
# Download and install from chef.io

# Create node configuration
$nodeConfig = @"
{
  "golf_app": {
    "port": 80,
    "enable_ssl": true,
    "site_name": "Elite Golf Production"
  },
  "run_list": ["recipe[elite-golf-cookbook]"]
}
"@

$nodeConfig | Out-File -FilePath C:\chef\node.json -Encoding UTF8

# Run Chef Client
chef-client -j C:\chef\node.json
```

### Ubuntu Server with Chef Client

```bash
# Install Chef Client
curl -L https://omnitruck.chef.io/install.sh | sudo bash

# Create node configuration
sudo mkdir -p /etc/chef
cat << EOF | sudo tee /etc/chef/node.json
{
  "golf_app": {
    "port": 80,
    "enable_ssl": true,
    "web_root": "/var/www/html/golf"
  },
  "run_list": ["recipe[elite-golf-cookbook]"]
}
EOF

# Run Chef Client
sudo chef-client -j /etc/chef/node.json
```

### Using Chef Zero (Local Development)

```bash
# Start Chef Zero server
chef-zero --port 8889 &

# Upload cookbook
knife cookbook upload elite-golf-cookbook --chef-repo-path .

# Bootstrap local node
knife bootstrap localhost --ssh-user $USER --sudo --node-name golf-dev \
  --run-list "recipe[elite-golf-cookbook]"
```

## Testing

### Manual Testing

After deployment, verify the application:

1. **Windows**: Open browser to `http://localhost` or `https://localhost` if SSL is enabled
2. **Linux**: Open browser to `http://your-server-ip` or `https://your-server-ip` if SSL is enabled

You should see the Elite Golf Club website with:
- Professional golf-themed design
- Responsive layout
- Custom golf club SVG illustration
- Feature cards describing club amenities

### Troubleshooting

#### Deployment Workflow Issues

**Cookbook Upload Errors:**
```bash
# Error: Cannot find cookbook
# Solution: Check cookbook path
knife cookbook upload elite-golf-cookbook --cookbook-path ./cookbooks

# Error: Version already exists  
# Solution: Update version in metadata.rb first
nano metadata.rb  # Increment version number
```

**Git Workflow Issues:**
```bash
# Error: Local changes conflict with git pull
git stash          # Stash local changes
git pull origin main
git stash pop      # Restore changes if needed

# Error: Push rejected
git pull origin main  # Pull latest changes first
git push origin main  # Then push
```

**Chef Client Deployment Issues:**
```bash
# Check cookbook version on server
knife cookbook show elite-golf-cookbook

# Check node run status
knife node show node-name

# Force chef-client run
knife ssh "name:node-name" "chef-client" -x administrator -t 300
```

#### Windows Issues
- Ensure IIS features are properly installed
- Check application pool status in IIS Manager
- Verify file permissions for IIS_IUSRS and IUSR accounts
- Check Windows Event Logs for IIS errors

#### Linux Issues
- Verify Apache is running: `sudo systemctl status apache2`
- Check Apache error logs: `sudo tail -f /var/log/apache2/error.log`
- Ensure proper file permissions: `ls -la /var/www/html/golf/`
- Test Apache configuration: `sudo apache2ctl configtest`

#### Common Issues

**Windows-Specific Issues:**
- **IIS dependency errors**: This cookbook now uses native PowerShell commands instead of the IIS cookbook to avoid dependency issues
- **Application pool errors**: Check if the application pool is running in IIS Manager
- **Port conflicts**: Change the port in attributes if default port is in use (common in lab environments)
- **Permission errors**: Ensure IIS_IUSRS has read access to the web root directory

**Linux-Specific Issues:**
- **Permission errors**: Verify web server user has read access to web files
- **Apache module errors**: Ensure all required modules are installed and enabled

**General Issues:**
- **SSL certificate errors**: For production, replace self-signed certificates with proper SSL certificates
- **Chef cookbook dependency errors**: This cookbook has been updated to minimize external dependencies

## Customization

### Changing the Golf Club Design

The golf club SVG is embedded in the HTML file. To customize:
1. Edit `files/default/index.html`
2. Modify the SVG code within the `<svg class="golf-club-svg">` element
3. Redeploy with Chef

### Adding Additional Pages

1. Create new HTML files in `files/default/`
2. Update the recipe to deploy additional files
3. Modify templates to include new pages in web server configuration

### Branding Customization

Edit the HTML file to change:
- Club name and tagline
- Color scheme (CSS variables)
- Feature descriptions
- Footer information

## Security Considerations

### Production Deployment
- Replace self-signed SSL certificates with proper certificates from a trusted CA
- Configure firewall rules to allow only necessary ports
- Regularly update the operating system and web server software
- Consider implementing additional security headers
- Set up proper backup procedures for web content

### SSL Configuration
- For production use, obtain SSL certificates from a trusted Certificate Authority
- Configure strong SSL ciphers and protocols
- Enable HTTP Strict Transport Security (HSTS)
- Redirect all HTTP traffic to HTTPS

## License

Apache License 2.0

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both Windows and Linux platforms
5. Submit a pull request

## Support

For issues and questions:
- Check the troubleshooting section above
- Review Chef logs for detailed error information
- Ensure all prerequisites are met for your platform

---

**Elite Golf Cookbook** - Deployed with Chef, Designed for Excellence