id = 'themis-finals'

basedir = ::File.join node[id][:basedir], 'visualization'
url_repository = "https://github.com/#{node[id][:visualization][:github_repository]}"

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
    url_repository = "git@github.com:#{node[id][:visualization][:github_repository]}.git"
    ssh_known_hosts_entry 'github.com'
  end
end

git2 basedir do
  url url_repository
  branch node[id][:visualization][:revision]
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
