id = 'themis-finals'

node.default['supervisor']['inet_port'] = \
  "#{node[id]['supervisor']['host']}:#{node[id]['supervisor']['port']}"
include_recipe 'supervisor::default'
