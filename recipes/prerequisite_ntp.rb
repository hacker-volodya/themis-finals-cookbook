node.default['ntp']['servers'] = (0..3).map { |n| "#{n}.pool.ntp.org" }
include_recipe 'ntp::default'
