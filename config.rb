def init_config()
  config = YAML.load(File.open('config/xoffers.yml'))
  config.each do |network, network_config|
    network = Network.find_or_create_by! name: network
    network_config['servers'].each do |server|
      Server.find_or_create_by! network: network, address: server
    end
    network_config['channels'].each do |channel|
      Channel.find_or_create_by! network: network, name: channel
    end
  end
end
