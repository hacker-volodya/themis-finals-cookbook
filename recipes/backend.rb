id = 'themis-finals'

basedir = ::File.join node[id]['basedir'], 'backend'
url_repository = "https://github.com/#{node[id]['backend']['github_repository']}"

directory basedir do
  owner node[id]['user']
  group node[id]['group']
  mode 0755
  recursive true
  action :create
end

if node.chef_environment.start_with? 'development'
  ssh_data_bag_item = nil
  begin
    ssh_data_bag_item = data_bag_item('ssh', node.chef_environment)
  rescue
  end

  ssh_key_map = (ssh_data_bag_item.nil?) ? {} : ssh_data_bag_item.to_hash.fetch('keys', {})

  if ssh_key_map.size > 0
    url_repository = "git@github.com:#{node[id]['backend']['github_repository']}.git"
    ssh_known_hosts_entry 'github.com'
  end
end

git2 basedir do
  url url_repository
  branch node[id]['backend']['revision']
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

rbenv_execute "Install dependencies at #{basedir}" do
  command 'bundle'
  ruby_version node[id]['ruby']['version']
  cwd basedir
  user node[id]['user']
  group node[id]['group']
end

aws_data_bag_item = nil
begin
  aws_data_bag_item = data_bag_item('aws', node.chef_environment)
rescue
end

aws_credentials = (aws_data_bag_item.nil?) ? {} : aws_data_bag_item.to_hash.fetch('credentials', {})

post_scoreboard = node[id]['post_scoreboard'] && aws_credentials.key?('access_key_id') && aws_credentials.key?('secret_access_key') && aws_credentials.key?('bucket') && aws_credentials.key?('region')

dotenv_file = ::File.join basedir, '.env'

template dotenv_file do
  source 'dotenv.erb'
  user node[id]['user']
  group node[id]['group']
  mode 0600
  variables(
    aws_access_key_id: aws_credentials.fetch('access_key_id', nil),
    aws_secret_access_key: aws_credentials.fetch('secret_access_key', nil),
    aws_bucket: aws_credentials.fetch('bucket', nil),
    aws_region: aws_credentials.fetch('region', nil),
    redis_host: node[id]['redis']['host'],
    redis_port: node[id]['redis']['port'],
    pg_host: node[id]['postgres']['host'],
    pg_port: node[id]['postgres']['port'],
    pg_username: node[id]['postgres']['username'],
    pg_password: data_bag_item('postgres', node.chef_environment)['credentials'][node[id]['postgres']['username']],
    pg_database: node[id]['postgres']['dbname'],
    stream_redis_db: node[id]['stream']['redis_db'],
    queue_redis_db: node[id]['backend']['queue']['redis_db'],
    stream_redis_channel_namespace: node[id]['stream']['redis_channel_namespace']
  )
  action :create
end

dump_db_script = ::File.join node[id]['basedir'], 'dump_main_db'

template dump_db_script do
  source 'dump_db.sh.erb'
  owner node[id]['user']
  group node[id]['group']
  mode 0775
  variables(
    pg_host: node[id]['postgres']['host'],
    pg_port: node[id]['postgres']['port'],
    pg_username: node[id]['postgres']['username'],
    pg_password: data_bag_item('postgres', node.chef_environment)['credentials'][node[id]['postgres']['username']],
    pg_dbname: node[id]['postgres']['dbname']
  )
end

logs_basedir = ::File.join node[id]['basedir'], 'logs'

supervisor_service "#{node[id]['supervisor']['namespace']}.master.beanstalk" do
  command 'sh script/beanstalk'
  process_name 'beanstalk-%(process_num)s'
  numprocs node[id]['backend']['beanstalk']['processes']
  numprocs_start 0
  priority 300
  autostart false
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup true
  killasgroup true
  user node[id]['user']
  redirect_stderr false
  stdout_logfile ::File.join logs_basedir, 'beanstalk-%(process_num)s-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_basedir, 'beanstalk-%(process_num)s-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment(
    'PATH' => '/usr/bin/env:/opt/rbenv/shims:%(ENV_PATH)s',
    'CTFTIME_SCOREBOARD' => post_scoreboard,
    'AWS_ACCESS_KEY_ID' => aws_credentials.fetch('access_key_id', nil),
    'AWS_SECRET_ACCESS_KEY' => aws_credentials.fetch('secret_access_key', nil),
    'AWS_REGION' => aws_credentials.fetch('region', nil),
    'AWS_BUCKET' => aws_credentials.fetch('bucket', nil),
    'APP_INSTANCE' => '%(process_num)s',
    'LOG_LEVEL' => node[id]['backend']['debug'] ? 'DEBUG' : 'INFO',
    'STDOUT_SYNC' => node[id]['backend']['debug'],
    'BEANSTALKD_URI' => "#{node[id]['beanstalkd']['host']}:#{node[id]['beanstalkd']['port']}",
    'BEANSTALKD_TUBE_NAMESPACE' => node[id]['beanstalkd']['tube_namespace'],
    'REDIS_HOST' => node[id]['redis']['host'],
    'REDIS_PORT' => node[id]['redis']['port'],
    'PG_HOST' => node[id]['postgres']['host'],
    'PG_PORT' => node[id]['postgres']['port'],
    'PG_USERNAME' => node[id]['postgres']['username'],
    'PG_PASSWORD' => data_bag_item('postgres', node.chef_environment)['credentials'][node[id]['postgres']['username']],
    'PG_DATABASE' => node[id]['postgres']['dbname'],
    'THEMIS_FINALS_MASTER_FQDN' => node[id]['fqdn'],
    'THEMIS_FINALS_MASTER_KEY' => data_bag_item('themis-finals', node.chef_environment)['keys']['master'],
    'THEMIS_FINALS_KEY_NONCE_SIZE' => node[id]['key_nonce_size'],
    'THEMIS_FINALS_AUTH_TOKEN_HEADER' => node[id]['auth_token_header'],
    'THEMIS_FINALS_STREAM_REDIS_DB' => node[id]['stream']['redis_db'],
    'THEMIS_FINALS_QUEUE_REDIS_DB' => node[id]['backend']['queue']['redis_db'],
    'THEMIS_FINALS_STREAM_REDIS_CHANNEL_NAMESPACE' => node[id]['stream']['redis_channel_namespace']
  )
  directory basedir
  serverurl 'AUTO'
  action :enable
end

supervisor_service "#{node[id]['supervisor']['namespace']}.master.queue" do
  command 'sh script/queue'
  process_name 'queue-%(process_num)s'
  numprocs node[id]['backend']['queue']['processes']
  numprocs_start 0
  priority 300
  autostart false
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup true
  killasgroup true
  user node[id]['user']
  redirect_stderr false
  stdout_logfile ::File.join logs_basedir, 'queue-%(process_num)s-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_basedir, 'queue-%(process_num)s-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment(
    'PATH' => '/usr/bin/env:/opt/rbenv/shims:%(ENV_PATH)s',
    'CTFTIME_SCOREBOARD' => post_scoreboard,
    'AWS_ACCESS_KEY_ID' => aws_credentials.fetch('access_key_id', nil),
    'AWS_SECRET_ACCESS_KEY' => aws_credentials.fetch('secret_access_key', nil),
    'AWS_REGION' => aws_credentials.fetch('region', nil),
    'AWS_BUCKET' => aws_credentials.fetch('bucket', nil),
    'INSTANCE' => '%(process_num)s',
    'LOG_LEVEL' => node[id]['backend']['debug'] ? 'DEBUG' : 'INFO',
    'STDOUT_SYNC' => node[id]['backend']['debug'],
    'BEANSTALKD_URI' => "#{node[id]['beanstalkd']['host']}:#{node[id]['beanstalkd']['port']}",
    'BEANSTALKD_TUBE_NAMESPACE' => node[id]['beanstalkd']['tube_namespace'],
    'REDIS_HOST' => node[id]['redis']['host'],
    'REDIS_PORT' => node[id]['redis']['port'],
    'PG_HOST' => node[id]['postgres']['host'],
    'PG_PORT' => node[id]['postgres']['port'],
    'PG_USERNAME' => node[id]['postgres']['username'],
    'PG_PASSWORD' => data_bag_item('postgres', node.chef_environment)['credentials'][node[id]['postgres']['username']],
    'PG_DATABASE' => node[id]['postgres']['dbname'],
    'THEMIS_FINALS_MASTER_FQDN' => node[id]['fqdn'],
    'THEMIS_FINALS_MASTER_KEY' => data_bag_item('themis-finals', node.chef_environment)['keys']['master'],
    'THEMIS_FINALS_KEY_NONCE_SIZE' => node[id]['key_nonce_size'],
    'THEMIS_FINALS_AUTH_TOKEN_HEADER' => node[id]['auth_token_header'],
    'THEMIS_FINALS_STREAM_REDIS_DB' => node[id]['stream']['redis_db'],
    'THEMIS_FINALS_QUEUE_REDIS_DB' => node[id]['backend']['queue']['redis_db'],
    'THEMIS_FINALS_STREAM_REDIS_CHANNEL_NAMESPACE' => node[id]['stream']['redis_channel_namespace']
  )
  directory basedir
  serverurl 'AUTO'
  action :enable
end

supervisor_service "#{node[id]['supervisor']['namespace']}.master.scheduler" do
  command 'sh script/scheduler'
  process_name 'scheduler'
  numprocs 1
  numprocs_start 0
  priority 300
  autostart false
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup true
  killasgroup true
  user node[id]['user']
  redirect_stderr false
  stdout_logfile ::File.join logs_basedir, 'scheduler-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_basedir, 'scheduler-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment(
    'PATH' => '/usr/bin/env:/opt/rbenv/shims:%(ENV_PATH)s',
    'LOG_LEVEL' => node[id]['backend']['debug'] ? 'DEBUG' : 'INFO',
    'STDOUT_SYNC' => node[id]['backend']['debug'],
    'BEANSTALKD_URI' => "#{node[id]['beanstalkd']['host']}:#{node[id]['beanstalkd']['port']}",
    'BEANSTALKD_TUBE_NAMESPACE' => node[id]['beanstalkd']['tube_namespace'],
    'REDIS_HOST' => node[id]['redis']['host'],
    'REDIS_PORT' => node[id]['redis']['port'],
    'PG_HOST' => node[id]['postgres']['host'],
    'PG_PORT' => node[id]['postgres']['port'],
    'PG_USERNAME' => node[id]['postgres']['username'],
    'PG_PASSWORD' => data_bag_item('postgres', node.chef_environment)['credentials'][node[id]['postgres']['username']],
    'PG_DATABASE' => node[id]['postgres']['dbname'],
    'THEMIS_FINALS_MASTER_FQDN' => node[id]['fqdn'],
    'THEMIS_FINALS_STREAM_REDIS_DB' => node[id]['stream']['redis_db'],
    'THEMIS_FINALS_QUEUE_REDIS_DB' => node[id]['backend']['queue']['redis_db'],
    'THEMIS_FINALS_STREAM_REDIS_CHANNEL_NAMESPACE' => node[id]['stream']['redis_channel_namespace']
  )
  directory basedir
  serverurl 'AUTO'
  action :enable
end

team_logos_dir = ::File.join node[id]['basedir'], 'team_logos'

supervisor_service "#{node[id]['supervisor']['namespace']}.master.server" do
  command 'sh script/server'
  process_name 'server-%(process_num)s'
  numprocs node[id]['backend']['server']['processes']
  numprocs_start 0
  priority 300
  autostart false
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup true
  killasgroup true
  user node[id]['user']
  redirect_stderr false
  stdout_logfile ::File.join logs_basedir, 'server-%(process_num)s-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_basedir, 'server-%(process_num)s-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment(
    'PATH' => '/usr/bin/env:/opt/rbenv/shims:%(ENV_PATH)s',
    'TEAM_LOGOS_DIR' => team_logos_dir,
    'HOST' => '127.0.0.1',
    'PORT' => node[id]['backend']['server']['port_range_start'],
    'INSTANCE' => '%(process_num)s',
    'LOG_LEVEL' => node[id]['backend']['debug'] ? 'DEBUG' : 'INFO',
    'STDOUT_SYNC' => node[id]['backend']['debug'],
    'RACK_ENV' => node.chef_environment,
    'BEANSTALKD_URI' => "#{node[id]['beanstalkd']['host']}:#{node[id]['beanstalkd']['port']}",
    'BEANSTALKD_TUBE_NAMESPACE' => node[id]['beanstalkd']['tube_namespace'],
    'REDIS_HOST' => node[id]['redis']['host'],
    'REDIS_PORT' => node[id]['redis']['port'],
    'PG_HOST' => node[id]['postgres']['host'],
    'PG_PORT' => node[id]['postgres']['port'],
    'PG_USERNAME' => node[id]['postgres']['username'],
    'PG_PASSWORD' => data_bag_item('postgres', node.chef_environment)['credentials'][node[id]['postgres']['username']],
    'PG_DATABASE' => node[id]['postgres']['dbname'],
    'THEMIS_FINALS_MASTER_FQDN' => node[id]['fqdn'],
    'THEMIS_FINALS_CHECKER_KEY' => data_bag_item('themis-finals', node.chef_environment)['keys']['checker'],
    'THEMIS_FINALS_KEY_NONCE_SIZE' => node[id]['key_nonce_size'],
    'THEMIS_FINALS_AUTH_TOKEN_HEADER' => node[id]['auth_token_header'],
    'THEMIS_FINALS_STREAM_REDIS_DB' => node[id]['stream']['redis_db'],
    'THEMIS_FINALS_QUEUE_REDIS_DB' => node[id]['backend']['queue']['redis_db'],
    'THEMIS_FINALS_STREAM_REDIS_CHANNEL_NAMESPACE' => node[id]['stream']['redis_channel_namespace']
  )
  directory basedir
  serverurl 'AUTO'
  action :enable
end
