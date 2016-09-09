id = 'themis-finals'

basedir = ::File.join node[id]['basedir'], 'stream'
url_repository = "https://github.com/#{node[id]['stream']['github_repository']}"

directory basedir do
  owner node[id]['user']
  group node[id]['group']
  mode 0755
  recursive true
  action :create
end

if node.chef_environment.start_with? 'development'
  ssh_private_key node[id]['user']
  ssh_known_hosts_entry 'github.com'
  url_repository = "git@github.com:#{node[id]['stream']['github_repository']}.git"
end

git2 basedir do
  url url_repository
  branch node[id]['stream']['revision']
  user node[id]['user']
  group node[id]['group']
  action :create
end

if node.chef_environment.start_with? 'development'
  git_data_bag_item = nil
  begin
    git_data_bag_item = data_bag_item('git', node.chef_environment)
  rescue
  end

  git_options = (git_data_bag_item.nil?) ? {} : git_data_bag_item.to_hash.fetch('config', {})

  git_options.each do |key, value|
    git_config "git-config #{key} at #{basedir}" do
      key key
      value value
      scope 'local'
      path basedir
      user node[id]['user']
      action :set
    end
  end
end

nodejs_npm "Install dependencies at #{basedir}" do
  package '.'
  path basedir
  json true
  user node[id]['user']
  group node[id]['group']
end

logs_basedir = ::File.join node[id]['basedir'], 'logs'

supervisor_service "#{node[id]['supervisor_namespace']}.master.stream" do
  command 'node ./dist/server.js'
  process_name 'stream-%(process_num)s'
  numprocs node[id]['stream']['processes']
  numprocs_start 0
  priority 300
  autostart false
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup false
  killasgroup false
  user node[id]['user']
  redirect_stderr false
  stdout_logfile ::File.join logs_basedir, 'stream-%(process_num)s-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_basedir, 'stream-%(process_num)s-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment(
    'HOST' => '127.0.0.1',
    'PORT' => node[id]['stream']['port_range_start'],
    'INSTANCE' => '%(process_num)s',
    'LOG_LEVEL' => node[id]['stream']['debug'] ? 'debug' : 'info',
    'REDIS_HOST' => node['latest-redis']['listen']['address'],
    'REDIS_PORT' => node['latest-redis']['listen']['port'],
    'PG_HOST' => node[id]['postgres']['host'],
    'PG_PORT' => node[id]['postgres']['port'],
    'PG_USERNAME' => node[id]['postgres']['username'],
    'PG_PASSWORD' => data_bag_item('postgres', node.chef_environment)['credentials'][node[id]['postgres']['username']],
    'PG_DATABASE' => node[id]['postgres']['dbname'],
    'THEMIS_FINALS_STREAM_REDIS_DB' => node[id]['stream']['redis_db'],
    'THEMIS_FINALS_STREAM_REDIS_CHANNEL_NAMESPACE' => node[id]['stream']['redis_channel_namespace']
  )
  directory basedir
  serverurl 'AUTO'
  action :enable
end

execute 'Build stream scripts' do
  command 'npm run build'
  cwd basedir
  user node[id]['user']
  group node[id]['group']
  environment(
    'HOME' => "/home/#{node[id]['user']}"
  )
end
