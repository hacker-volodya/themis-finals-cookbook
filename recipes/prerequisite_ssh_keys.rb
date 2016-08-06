id = 'themis-finals'

ssh_data_bag_item = {}
begin
  ssh_data_bag_item = data_bag_item('ssh', node.chef_environment)
rescue
end

ssh_key_map = (ssh_data_bag_item.nil?) ? {} : ssh_data_bag_item.to_hash.fetch('keys', {})

ssh_key_map.each do |key_type, key_contents|
  ssh_user_private_key key_type do
    key key_contents
    user node[id]['user']
  end
end
