id = 'themis-finals'

node.default['rbenv']['group_users'] = [
  'root',
  node[id]['user']
]

include_recipe 'rbenv::default'
include_recipe 'rbenv::ruby_build'

ENV['CONFIGURE_OPTS'] = '--disable-install-rdoc'

rbenv_ruby node[id]['ruby']['version'] do
  ruby_version node[id]['ruby']['version']
  global true
end

rbenv_gem 'bundler' do
  ruby_version node[id]['ruby']['version']
  version '1.11.2'
end
