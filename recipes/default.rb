node.default['ntp']['servers'] = (0..3).map { |n| "#{n}.pool.ntp.org" }
include_recipe 'ntp::default'
include_recipe 'resolver::default'

include_recipe 'latest-git::default'
include_recipe 'latest-nodejs::default'

include_recipe 'modern_nginx::default'

id = 'themis-finals'

node.default['postgresql']['version'] = node[id][:postgres][:version]
node.default['postgresql']['enable_pgdg_apt'] = true
node.default['postgresql']['server']['packages'] = [
  "postgresql-#{node[id][:postgres][:version]}",
  "postgresql-server-dev-#{node[id][:postgres][:version]}",
]
node.default['postgresql']['contrib']['packages'] = [
  "postgresql-contrib-#{node[id][:postgres][:version]}"
]
node.default['postgresql']['client']['packages'] = [
  "postgresql-client-#{node[id][:postgres][:version]}",
  "libpq-dev"
]
node.default['postgresql']['dir'] = "/etc/postgresql/#{node[id][:postgres][:version]}/main"
node.default['postgresql']['config']['listen_addresses'] = node[id][:postgres][:listen][:address]
node.default['postgresql']['config']['port'] = node[id][:postgres][:listen][:port]

require 'digest/md5'

postgres_root_username = 'postgres'
postgres_pwd_digest = Digest::MD5.hexdigest("#{data_bag_item('postgres', node.chef_environment)['credentials'][postgres_root_username]}#{postgres_root_username}")
node.default['postgresql']['password'][postgres_root_username] = "md5#{postgres_pwd_digest}"

include_recipe 'postgresql::server'
include_recipe 'postgresql::client'
include_recipe 'database::postgresql'

postgresql_connection_info = {
  host: node[id][:postgres][:listen][:address],
  port: node[id][:postgres][:listen][:port],
  username: postgres_root_username,
  password: data_bag_item('postgres', node.chef_environment)['credentials'][postgres_root_username]
}

postgresql_database node[id][:postgres][:dbname] do
  connection postgresql_connection_info
  action :create
end

postgresql_database_user node[id][:postgres][:username] do
  connection postgresql_connection_info
  database_name node[id][:postgres][:dbname]
  password data_bag_item('postgres', node.chef_environment)['credentials'][node[id][:postgres][:username]]
  privileges [:all]
  action [:create, :grant]
end

node.default['latest-redis']['listen']['address'] = node[id][:redis][:listen][:address]
node.default['latest-redis']['listen']['port'] = node[id][:redis][:listen][:port]

include_recipe 'latest-redis::default'

include_recipe 'python::default'
include_recipe 'python::pip'
include_recipe 'python::virtualenv'

node.default['beanstalkd']['start_during_boot'] = true
node.default['beanstalkd']['opts'] = {
  'l' => node[id][:beanstalkd][:listen][:address],
  'p' => node[id][:beanstalkd][:listen][:port]
}

include_recipe 'beanstalkd::default'

node.default['rbenv']['group_users'] = [
  'root',
  node[id][:user]
]

include_recipe 'rbenv::default'
include_recipe 'rbenv::ruby_build'

directory node[id][:basedir] do
  owner node[id][:user]
  group node[id][:group]
  mode 0755
  recursive true
  action :create
end

ENV['CONFIGURE_OPTS'] = '--disable-install-rdoc'

rbenv_ruby node[id][:ruby_version] do
  ruby_version node[id][:ruby_version]
  global true
end

rbenv_gem 'bundler' do
  ruby_version node[id][:ruby_version]
end

rbenv_gem 'god' do
  ruby_version node[id][:ruby_version]
end

url_repository = "https://github.com/#{node[id][:repository]}"

if node.chef_environment.start_with? 'development'
  ssh_key_map = data_bag_item('ssh', node.chef_environment).to_hash.fetch('keys', {})

  if ssh_key_map.size > 0
    url_repository = "git@github.com:#{node[id][:repository]}.git"
    ssh_known_hosts_entry 'github.com'
  end

  ssh_key_map.each do |key_type, key_contents|
    ssh_user_private_key key_type do
      key key_contents
      user node[id][:user]
    end
  end
end

git2 node[id][:basedir] do
  url url_repository
  branch node[id][:revision]
  user node[id][:user]
  group node[id][:group]
  action :create
end

if node.chef_environment.start_with? 'development'
  data_bag_item('git', node.chef_environment).to_hash.fetch('config', {}).each do |key, value|
    git_config "Git config #{key} at #{node[id][:basedir]}" do
      key key
      value value
      scope 'local'
      path node[id][:basedir]
      user node[id][:user]
      action :set
    end
  end
end

rbenv_execute 'Install bundle' do
  command 'bundle'
  ruby_version node[id][:ruby_version]
  cwd node[id][:basedir]
  user node[id][:user]
  group node[id][:group]
end

template "#{node[id][:basedir]}/god.d/queue.god" do
  source 'queue.god.erb'
  mode 0644
end

template "#{node[id][:basedir]}/god.d/scheduler.god" do
  source 'scheduler.god.erb'
  mode '0644'
end

template "#{node[id][:basedir]}/god.d/backend.god" do
  source 'backend.god.erb'
  mode '0644'
end

template "#{node[id][:basedir]}/god.d/stream.god" do
  source 'stream.god.erb'
  mode '0644'
end

python_pip 'twine'
python_pip 'wheel'

template "#{node[:nginx][:dir]}/sites-available/themis-finals.conf" do
  source 'nginx.conf.erb'
  mode '0644'
  notifies :reload, 'service[nginx]', :delayed
end

nginx_site 'themis-finals.conf'

nodejs_npm '.' do
  path "#{node[id][:basedir]}/www"
  json true
  user node[id][:user]
  group node[id][:group]
end

execute 'Copy customization file' do
  command 'cp customize.js.example customize.js'
  cwd "#{node[id][:basedir]}/www"
  user node[id][:user]
  group node[id][:group]
  not_if "test -e #{node[id][:basedir]}/www/customize.js"
end

execute 'Build assets' do
  command 'npm run gulp'
  cwd "#{node[id][:basedir]}/www"
  user node[id][:user]
  group node[id][:group]

  default_env = {
    'HOME' => "/home/#{node[id][:user]}"
  }
  if node[id][:production]
    default_env['NODE_ENV'] = 'production'
  end

  environment default_env
end

nodejs_npm '.' do
  path "#{node[id][:basedir]}/stream"
  json true
  user node[id][:user]
  group node[id][:group]
end
