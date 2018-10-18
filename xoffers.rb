require 'active_record'
require 'cinch'
require 'yaml'
require 'sinatra'
require 'sinatra/json'

require_relative 'config'

Dir['models/*.rb'].each { |file| require_relative file }

DB_CONFIG = YAML.safe_load(File.open('config/database.yml'))['development']
ActiveRecord::Base.establish_connection(DB_CONFIG)

# ActiveRecord::Base.logger = Logger.new STDOUT

init_config

threads = []

def find_or_create_user(network, user)
  User.find_or_create_by network: network, name: user
rescue ActiveRecord::RecordNotUnique
  retry
end

def find_or_create_pack(user, number)
  Pack.find_or_create_by user: user, number: number
rescue ActiveRecord::RecordNotUnique
  retry
end

MAX_QUEUE_LENGTH = 1000
QUEUE = Queue.new

def enqueue(task)
  if QUEUE.length < MAX_QUEUE_LENGTH
    QUEUE.push task
  else
    print '!'
  end

  dl_queue = DL_QUEUES[task[:network]]
  return if dl_queue.empty?
  qe = dl_queue.pop
  case qe[:type]
  when :download
    puts "Requesting pack ##{qe[:number]} from #{qe[:user]}"
    User(qe[:user]).send "XDCC SEND ##{qe[:number]}"
  when :resume
    puts "Requesting resume for file #{qe[:name]} from #{qe[:user]} on port #{qe[:port]} at position #{qe[:position]}"
    User(qe[:user]).ctcp "DCC RESUME #{qe[:name]} #{qe[:port]} #{qe[:position]}"
  end
end

DL_QUEUES = {}

Network.all.each do |network|
  DL_QUEUES[network.name] = Queue.new
  server = network.servers.first
  users = User.joins(:network).where('networks.name = ?', network.name).map(&:name)
  threads << Thread.new do
    channels = network.channels.map(&:name)

    bot = Cinch::Bot.new do
      configure do |c|
        c.server = server.address
        c.channels = channels
        c.nicks = %w[habilos ciklo acusta jihnn sortr]
        c.user = c.nicks.first
        c.realname = c.nicks.first
      end

      on :leaving do |_m, user|
        enqueue type: :offline,
                network: network.name,
                user: user.name
      end

      on :'366' do |m|
        enqueue type: :names,
                network: network.name,
                users: m.channel.users.keys.map(&:name)
      end

      on :channel, /.*?#(\d+).*? +(\d+)x \[ *(.*?)\] (.*)/ do |m, number, gets, size, name|
        name.gsub! /\x1f|\x02|\x12|\x0f|\x16|\x03(?:\d{1,2}(?:,\d{1,2})?)?/, ''
        # puts "OFFER: chan=#{m.channel.name}, nick=#{m.user.name}, number=#{number}, gets=#{gets}, name=#{name}, size=#{size}"
        enqueue type: :offer,
                network: network.name,
                user: m.user.name,
                number: number,
                gets: gets,
                name: name,
                size: size
      end

      # ... 0 of 15 slots open, Queue: 23/50, Min: 25.0kB/s, Record: 91176.8kB/s
      on :channel, /.*?(\d+) packs .*? +(\d+) of (\d+) slots open/ do |m, count, open_slots, slots|
        # puts "SLOTS: chan=#{m.channel.name}, nick=#{m.user.name}, packs=#{count}, open=#{open_slots}, slots=#{slots}"
        enqueue type: :slots,
                network: network.name,
                user: m.user.name,
                count: count,
                open_slots: open_slots,
                slots: slots
      end

      on :channel, /.*?Bandwidth Usage.+?Current: (.+), Record: (.+)/ do |m, current_speed, max_speed|
        # puts "SPEED: chan=#{m.channel.name}, nick=#{m.user.name}, current=#{current_speed}, max=#{max_speed}"
        enqueue type: :speed,
                network: network.name,
                user: m.user.name,
                current_speed: current_speed,
                max_speed: max_speed
      end

      on :channel, /.*?Total Offered: +(.+) +Total Transferred: +(.+)/ do |m, size, traffic|
        # puts "STATS: chan=#{m.channel.name}, nick=#{m.user.name}, size=#{size}, traffic=#{traffic}"
        enqueue type: :stats,
                network: network.name,
                user: m.user.name,
                size: size,
                traffic: traffic
      end

      on :private do |m|
        puts "PRIVMSG from #{m.user.try(:name)}: #{m.message}"
        # DCC SEND <filename> <ip> 0 <filesize> <token>
        if m.ctcp_command == 'DCC' && m.ctcp_args[0] == 'SEND' && m.ctcp_args.count == 6
          ip = m.ctcp_args[2].to_i
          ip = [24, 16, 8, 0].collect { |b| (ip >> b) & 255 }.join('.')
          enqueue type: :reverse_dcc,
                  network: network.name,
                  user: m.user.name,
                  name: m.ctcp_args[1],
                  size: m.ctcp_args[4],
                  ip: ip,
                  token: m.ctcp_args[5]
        end
        # DCC ACCEPT <filename> <port> <position>
        if m.ctcp_command == 'DCC' && m.ctcp_args[0] == 'ACCEPT' && m.ctcp_args.count == 4
          enqueue type: :dcc_accept,
                  network: network.name,
                  user: m.user.name,
                  name: m.ctcp_args[1],
                  port: m.ctcp_args[2],
                  position: m.ctcp_args[3]
        end
      end

      on :dcc_send do |m, dcc|
        enqueue type: :dcc,
                network: network.name,
                user: m.user.name,
                name: dcc.filename,
                size: dcc.size,
                ip: dcc.ip,
                port: dcc.port
      end
    end

    # bot.loggers.level = :warn
    bot.start
  end
end

Thread.new { db_connector }

def db_connector
  ActiveRecord::Base.establish_connection(DB_CONFIG)

  Download.update_all status: nil

  networks = Network.all.each_with_object({}) do |n, nh|
    users = n.users.each_with_object({}) do |u, uh|
      uh[u.name] = u
    end
    nh[n.name] = { network: n, users: users }
  end

  loop do
    begin
      task = QUEUE.pop
      network = networks[task[:network]]
      user = network[:users][task[:user]]
      ActiveRecord::Base.transaction do
        if task[:user].present?
          user = find_or_create_user(network[:network], task[:user]) if user.nil?
          network[:users][task[:user]] = user
        end
        case task[:type]
        when :offer
          pack = find_or_create_pack(user, task[:number])
          pack.update name: task[:name], download_count: task[:gets], size: task[:size]
          user.update online: true
        when :slots
          user.update pack_count: task[:count], open_slot_count: task[:open_slots], total_slot_count: task[:slots], online: true
        when :speed
          user.update max_speed: task[:max_speed], current_speed: task[:current_speed], online: true
        when :stats
          user.update offered_size: task[:size], transferred_size: task[:traffic], online: true
        when :offline
          user.update online: false
        when :online
          user.update online: true
        when :dcc
          puts "Receiving DCC SEND for #{task[:name]} on IP #{task[:ip]} and port #{task[:port]} with size #{task[:size]}"
          dl = Download.first
          if dl.present?
            if dl.user.name != task[:user]
              puts 'DCC send from this user unexpected. Ignored.'
              next
            end
            dl.update ip: task[:ip], port: task[:port]
            if dl.name != task[:name]
              dl.update status: :wrong_filename
            elsif dl.size.present? && dl.size != task[:size]
              dl.update status: :wrong_filesize
            elsif dl.position != 0
              dl.update status: :requesting_resume
              DL_QUEUES[task[:network]].push(type: :resume, user: task[:user], name: task[:name], port: dl.port, position: dl.position)
            else
              dl.update status: :started, size: task[:size]
            end
          end
        when :reverse_dcc
          dl = Download.first
          network = Network.find_by name: task[:network]
          user = User.find_by name: task[:user], network: network
          user.update passive: true
          if dl.present?
            if dl.user != user
              puts 'DCC send from this user unexpected. Ignored.'
              next
            end
            if dl.name != task[:name]
              dl.update status: :wrong_filename
            else
              dl.update size: task[:size], ip: task[:ip], status: :reverse_dcc, port: task[:token]
            end
          end
        when :dcc_accept
          dl = Download.first
          if dl.present?
            if dl.user.name != task[:user]
              puts 'DCC send from this user unexpected. Ignored.'
              next
            end
            if dl.name != task[:name]
              dl.update status: :wrong_filename
            else
              dl.update status: :resume_accepted, position: task[:position], port: task[:port]
            end
          end
        when :names
          task[:users].each do |nick|
            user = network[:users][nick]
            user.update online: true if user.present?
          end
        end
      end
    rescue => e
      puts e
      puts e.backtrace
    end
  end
end

# make sure db connection is returned to pool in threaded mode
after { ActiveRecord::Base.clear_active_connections! }

set :show_exceptions, false

get '/' do
  @s = params['s']
  if @s.present?
    likes = @s.split(/ /).map { |e| "%#{e}%" }
    where = Array.new(likes.count, 'name like ?').join(' and ')
    @results = Pack.where(where, *likes).order(:name, download_count: :desc)
  end
  @stats = { networks: Network.count, channels: Channel.count, users: User.count, packs: Pack.count }
  haml :index
end

get '/cleanup' do
  Pack.delete_all(['updated_at < ?', 1.month.ago])
  User.delete_all(['updated_at < ?', 1.month.ago])
  redirect "/", 303
end

post '/queue' do
  pack = Pack.find params['q']
  Download.create! name: pack.name, user: pack.user
  redirect "/?s=#{params['s']}", 303
end

get '/queue' do
  @queue = Download.all.order(:created_at)
  haml :queue
end

delete '/queue/:id' do
  Download.destroy params[:id]
  redirect '/queue'
end

get '/job' do
  dl = Download.first
  json id: dl.id, name: dl.name if dl.present?
end

def request_download(id, position)
  download = Download.find id
  pack = Pack.joins(user: :network)
             .where(user: download.user, name: download.name)
             .order(updated_at: :desc)
             .first
  download.update position: position, status: :requested
  DL_QUEUES[pack.user.network.name].push(type: :download, user: pack.user.name, number: pack.number)
  json id: download.id, name: download.name, status: download.status, position: position
end

post '/job/:id/:position' do
  request_download params[:id], params[:position]
end

post '/job/:id' do
  request_download params[:id], 0
end

get '/job/:id' do
  download = Download.find params[:id]
  json id: download.id,
       name: download.name,
       status: download.status,
       size: download.size,
       position: download.position,
       ip: download.ip,
       port: download.port
end

patch '/job/:id/:position' do
  download = Download.find params[:id]
  download.update status: :downloading, position: params[:position]
end

delete '/job/:id' do
  Download.destroy params[:id]
  204
end

error ActiveRecord::RecordNotFound do
  404
end
