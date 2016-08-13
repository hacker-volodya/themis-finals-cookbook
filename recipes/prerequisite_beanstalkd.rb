id = 'themis-finals'

node.default['beanstalkd']['start_during_boot'] = true
node.default['beanstalkd']['opts'] = {
  'l' => node[id]['beanstalkd']['host'],
  'p' => node[id]['beanstalkd']['port']
}

include_recipe 'beanstalkd::default'
