id = 'themis-finals'

node.default['latest-redis']['listen']['address'] = node[id][:redis][:listen][:address]
node.default['latest-redis']['listen']['port'] = node[id][:redis][:listen][:port]

include_recipe 'latest-redis::default'
