name 'elite-golf-cookbook'
maintainer 'Elite Golf Team'
maintainer_email 'admin@elitegolf.com'
license 'Apache-2.0'
description 'Deploys a simple golf-themed web application'
long_description 'A Chef cookbook that deploys a simple web application with golf theme, supporting both Windows IIS and Linux web servers'
version '1.0.9'
chef_version '>= 14.0'

supports 'windows'
supports 'ubuntu'
supports 'centos'
supports 'redhat'

# No external cookbook dependencies required - using native Chef resources and PowerShell