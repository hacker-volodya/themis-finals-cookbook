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
