id = 'themis-finals'

include_recipe "#{id}::prerequisite_ntp"

include_recipe "#{id}::prerequisite_git"
include_recipe "#{id}::prerequisite_python"
include_recipe "#{id}::prerequisite_ruby"
include_recipe "#{id}::prerequisite_nodejs"

include_recipe "#{id}::prerequisite_nginx"
include_recipe "#{id}::prerequisite_redis"
include_recipe "#{id}::prerequisite_postgres"
include_recipe "#{id}::prerequisite_supervisor"

directory node[id]['basedir'] do
  owner node[id]['user']
  group node[id]['group']
  mode 0755
  recursive true
  action :create
end

logs_basedir = ::File.join node[id]['basedir'], 'logs'

directory logs_basedir do
  owner node[id]['user']
  group node[id]['group']
  mode 0755
  recursive true
  action :create
end

team_logos_dir = ::File.join node[id]['basedir'], 'team_logos'

directory team_logos_dir do
  owner node[id]['user']
  group node[id]['group']
  mode 0755
  recursive true
  action :create
end

# include_recipe "#{id}::sentry"
include_recipe "#{id}::backend"
include_recipe "#{id}::frontend"
include_recipe "#{id}::stream"
# include_recipe "#{id}::visualization"

namespace = "#{node[id]['supervisor']['namespace']}.master"

supervisor_group namespace do
  programs [
    "#{namespace}.stream",
    "#{namespace}.queue",
    "#{namespace}.scheduler",
    "#{namespace}.server"
  ]
  action :enable
end

cleanup_script = ::File.join node[id]['basedir'], 'cleanup_logs'

template cleanup_script do
  source 'cleanup_logs.sh.erb'
  owner node[id]['user']
  group node[id]['group']
  mode 0775
  variables(
    logs_basedir: logs_basedir,
    sentry_logs_basedir: ::File.join(node[id]['basedir'], 'sentry', 'logs')
  )
end

archive_script = ::File.join node[id]['basedir'], 'archive_logs'

template archive_script do
  source 'archive_logs.sh.erb'
  owner node[id]['user']
  group node[id]['group']
  mode 0775
  variables(
    logs_basedir: logs_basedir,
    sentry_logs_basedir: ::File.join(node[id]['basedir'], 'sentry', 'logs')
  )
end

template "#{node['nginx']['dir']}/sites-available/themis-finals.conf" do
  source 'nginx.conf.erb'
  mode 0644
  variables(
    server_name: node[id]['fqdn'],
    logs_basedir: logs_basedir,
    frontend_basedir: ::File.join(node[id]['basedir'], 'frontend'),
    visualization_basedir: node[id]['basedir'],
    backend_server_processes: node[id]['backend']['server']['processes'],
    backend_server_port_range_start: \
      node[id]['backend']['server']['port_range_start'],
    stream_processes: node[id]['stream']['processes'],
    stream_port_range_start: node[id]['stream']['port_range_start']
  )
  notifies :reload, 'service[nginx]', :delayed
  action :create
end

nginx_site 'themis-finals.conf'

include_recipe "#{id}::tools_monitoring"
