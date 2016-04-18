id = 'themis-finals'

node.default['beanstalkd']['start_during_boot'] = true
node.default['beanstalkd']['opts'] = {
  'l' => node[id][:beanstalkd][:listen][:address],
  'p' => node[id][:beanstalkd][:listen][:port]
}

include_recipe 'beanstalkd::default'
