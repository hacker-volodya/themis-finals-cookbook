id = 'themis-finals'

basedir = ::File.join node[id]['basedir'], 'frontend'
url_repository = "https://github.com/#{node[id]['frontend']['github_repository']}"

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
  url_repository = "git@github.com:#{node[id]['frontend']['github_repository']}.git"
end

git2 basedir do
  url url_repository
  branch node[id]['frontend']['revision']
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

execute "Copy customization file at #{basedir}" do
  command 'cp customize.example.js customize.js'
  cwd basedir
  user node[id]['user']
  group node[id]['group']
  not_if "test -e #{basedir}/customize.js"
end

execute "Build assets at #{basedir}" do
  command 'npm run gulp'
  cwd basedir
  user node[id]['user']
  group node[id]['group']
  environment(
    'HOME' => "/home/#{node[id]['user']}",
    'NODE_ENV' => node.chef_environment
  )
end
