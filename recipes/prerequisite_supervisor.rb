id = 'themis-finals'

node.default['supervisor']['inet_port'] = "#{node[id][:supervisor][:listen][:address]}:#{node[id][:supervisor][:listen][:port]}"
include_recipe 'supervisor::default'
