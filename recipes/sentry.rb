include_recipe 'libxml2::default'
include_recipe 'libxslt::default'
include_recipe 'libffi::default'

id = 'themis-finals'

basedir = ::File.join node[id][:basedir], 'sentry'

directory basedir do
  owner node[id][:user]
  group node[id][:group]
  mode 0755
  recursive true
  action :create
end

logs_dir = ::File.join basedir, 'logs'

directory logs_dir do
  owner node[id][:user]
  group node[id][:group]
  mode 0755
  action :create
end

virtualenv_path = ::File.join basedir, '.virtualenv'

python_virtualenv virtualenv_path do
  owner node[id][:user]
  group node[id][:group]
  interpreter node['python']['binary']
  action :create
end

requirements_file = ::File.join basedir, 'requirements.txt'

cookbook_file requirements_file do
  source 'requirements.txt'
  owner node[id][:user]
  group node[id][:group]
  mode 0644
  action :create
end

python_pip requirements_file do
  user node[id][:user]
  group node[id][:group]
  virtualenv virtualenv_path
  options '-r'
  action :install
end

postgres_root_username = 'postgres'

postgresql_connection_info = {
  host: node[id][:postgres][:listen][:address],
  port: node[id][:postgres][:listen][:port],
  username: postgres_root_username,
  password: data_bag_item('postgres', node.chef_environment)['credentials'][postgres_root_username]
}

postgresql_database node[id][:sentry][:postgres][:dbname] do
  connection postgresql_connection_info
  action :create
end

postgresql_database_user node[id][:sentry][:postgres][:username] do
  connection postgresql_connection_info
  database_name node[id][:sentry][:postgres][:dbname]
  password data_bag_item('postgres', node.chef_environment)['credentials'][node[id][:sentry][:postgres][:username]]
  privileges [:all]
  action [:create, :grant]
end

conf_file = ::File.join basedir, 'sentry.conf.py'

template conf_file do
  source 'sentry.conf.py.erb'
  owner node[id][:user]
  group node[id][:group]
  variables(
    sentry_host: node[id][:sentry][:listen][:address],
    sentry_port: node[id][:sentry][:listen][:port],
    pg_host: node[id][:postgres][:listen][:address],
    pg_port: node[id][:postgres][:listen][:port],
    pg_name: node[id][:sentry][:postgres][:dbname],
    pg_username: node[id][:sentry][:postgres][:username],
    pg_password: data_bag_item('postgres', node.chef_environment)['credentials'][node[id][:sentry][:postgres][:username]],
    redis_host: node[id][:redis][:listen][:address],
    redis_port: node[id][:redis][:listen][:port],
    redis_db: node[id][:sentry][:redis][:db]
  )
  mode 0644
end

new_conf_file = ::File.join basedir, 'config.yml'

template new_conf_file do
  source 'sentry.config.yml.erb'
  owner node[id][:user]
  group node[id][:group]
  variables(
    secret_key: data_bag_item('sentry', node.chef_environment)['secret_key'],
    redis_host: node[id][:redis][:listen][:address],
    redis_port: node[id][:redis][:listen][:port],
    redis_db: node[id][:sentry][:redis][:db]
  )
end

execute 'Run Sentry database migration' do
  command "sentry upgrade --noinput"
  cwd basedir
  user node[id][:user]
  group node[id][:group]
  environment(
    'PATH' => "#{::File.join virtualenv_path, 'bin'}:#{ENV['PATH']}",
    'SENTRY_CONF' => basedir
  )
  action :run
end

namespace = "#{node['themis-finals'][:supervisor][:namespace]}.sentry"

supervisor_service "#{namespace}.web" do
  command "#{::File.join virtualenv_path, 'bin', 'sentry'} run web"
  process_name 'web'
  numprocs 1
  numprocs_start 0
  priority 300
  autostart true
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup false
  killasgroup false
  user node[id][:user]
  redirect_stderr false
  stdout_logfile ::File.join logs_dir, 'web-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_dir, 'web-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment(
    'PATH' => "#{::File.join virtualenv_path, 'bin'}:%(ENV_PATH)s",
    'SENTRY_CONF' => basedir
  )
  directory basedir
  serverurl 'AUTO'
  action :enable
end

supervisor_service "#{namespace}.celery_worker" do
  command "#{::File.join virtualenv_path, 'bin', 'sentry'} celery worker"
  process_name 'celery_worker'
  numprocs 1
  numprocs_start 0
  priority 300
  autostart true
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup false
  killasgroup false
  user node[id][:user]
  redirect_stderr false
  stdout_logfile ::File.join logs_dir, 'celery_worker-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_dir, 'celery_worker-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment(
    'PATH' => "#{::File.join virtualenv_path, 'bin'}:%(ENV_PATH)s",
    'SENTRY_CONF' => basedir
  )
  directory basedir
  serverurl 'AUTO'
  action :enable
end

supervisor_service "#{namespace}.celery_beat" do
  command "#{::File.join virtualenv_path, 'bin', 'sentry'} celery beat"
  process_name 'celery_beat'
  numprocs 1
  numprocs_start 0
  priority 300
  autostart true
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup false
  killasgroup false
  user node[id][:user]
  redirect_stderr false
  stdout_logfile ::File.join logs_dir, 'celery_beat-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_dir, 'celery_beat-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment(
    'PATH' => "#{::File.join virtualenv_path, 'bin'}:%(ENV_PATH)s",
    'SENTRY_CONF' => basedir
  )
  directory basedir
  serverurl 'AUTO'
  action :enable
end

supervisor_group namespace do
  programs [
    "#{namespace}.web",
    "#{namespace}.celery_worker",
    "#{namespace}.celery_beat"
  ]
  action [:enable, :start]
end

cleanup_script = ::File.join node[id][:basedir], 'cleanup_sentry'

template cleanup_script do
  source 'cleanup_sentry.sh.erb'
  owner node[id][:user]
  group node[id][:group]
  mode 0775
  variables(
    virtualenv_path: virtualenv_path,
    environment: {
      'SENTRY_CONF' => basedir
    }
  )
end
