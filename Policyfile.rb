# Elite Golf Cookbook Policyfile
# This policy defines the cookbook and compliance requirements

name 'elite-golf-policy'

# Define the run list
run_list 'elite-golf-cookbook::lab_demo'

# Set the Chef version
chef_version '>= 14.0'

# Default source for community cookbooks
default_source :supermarket

# Local cookbook source
cookbook 'elite-golf-cookbook', path: '.'

# Include InSpec compliance profile
compliance_profile 'elite_golf_compliance', path: 'compliance/profiles/elite_golf_compliance'

# Named run lists for different environments
named_run_list :windows, 'elite-golf-cookbook::lab_demo'
named_run_list :linux, 'elite-golf-cookbook::lab_demo'
named_run_list :basic, 'elite-golf-cookbook::default'