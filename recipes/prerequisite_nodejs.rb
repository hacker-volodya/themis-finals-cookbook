node.default['latest-nodejs']['install'] = 'current'
node.default['latest-nodejs']['binary'] = true

include_recipe 'latest-nodejs::default'
