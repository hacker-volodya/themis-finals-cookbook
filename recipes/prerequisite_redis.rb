id = 'themis-finals'

node.default['latest-redis']['listen']['address'] = node[id]['redis']['host']
node.default['latest-redis']['listen']['port'] = node[id]['redis']['port']

include_recipe 'latest-redis::default'
