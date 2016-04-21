id = 'themis-finals'

basedir = ::File.join node[id][:basedir], 'backend'
url_repository = "https://github.com/#{node[id][:backend][:github_repository]}"

directory basedir do
  owner node[id][:user]
  group node[id][:group]
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
    url_repository = "git@github.com:#{node[id][:backend][:github_repository]}.git"
    ssh_known_hosts_entry 'github.com'
  end
end

git2 basedir do
  url url_repository
  branch node[id][:backend][:revision]
  user node[id][:user]
  group node[id][:group]
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
      user node[id][:user]
      action :set
    end
  end
end

rbenv_execute "Install dependencies at #{basedir}" do
  command 'bundle'
  ruby_version node[id][:ruby][:version]
  cwd basedir
  user node[id][:user]
  group node[id][:group]
end

god_basedir = ::File.join node[id][:basedir], 'god.d'

template "#{god_basedir}/queue.god" do
  source 'queue.god.erb'
  mode 0644
  variables(
    basedir: basedir,
    logs_basedir: ::File.join(node[id][:basedir], 'logs'),
    user: node[id][:user],
    group: node[id][:group],
    log_level: node[id][:backend][:debug] ? 'DEBUG' : 'INFO',
    stdout_sync: node[id][:backend][:debug],
    processes: node[id][:backend][:queue][:processes]
  )
  action :create
end

template "#{god_basedir}/scheduler.god" do
  source 'scheduler.god.erb'
  mode 0644
  variables(
    basedir: basedir,
    logs_basedir: ::File.join(node[id][:basedir], 'logs'),
    user: node[id][:user],
    group: node[id][:group],
    log_level: node[id][:backend][:debug] ? 'DEBUG' : 'INFO',
    stdout_sync: node[id][:backend][:debug]
  )
  action :create
end

team_logos_dir = ::File.join node[id][:basedir], 'team_logos'

template "#{god_basedir}/app.god" do
  source 'app.god.erb'
  mode 0644
  variables(
    basedir: basedir,
    logs_basedir: ::File.join(node[id][:basedir], 'logs'),
    user: node[id][:user],
    group: node[id][:group],
    log_level: node[id][:backend][:debug] ? 'DEBUG' : 'INFO',
    stdout_sync: node[id][:backend][:debug],
    rack_env: node.chef_environment,
    processes: node[id][:backend][:app][:processes],
    port_range_start: node[id][:backend][:app][:port_range_start],
    team_logos_dir: team_logos_dir
  )
  action :create
end
