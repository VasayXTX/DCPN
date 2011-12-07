#coding: utf-8

%w[eventmachine mongoid yaml socket].each { |gem| require gem }
[
  %w[models prime],
  %w[generators],
  %w[client_container]
].each do |path| 
  require File.join(File.dirname(__FILE__), *path)
end

class Handler

  CMDS = %w[join getRange putSolution putPartSolution]
  @@cmd_map = Hash.new do |h, k| 
    h[k] = "cmd_#{(k.gsub(/[A-Z]/) { |s| s = "_#{s.downcase}".to_sym})}"
  end
  CMDS.each { |cmd| @@cmd_map[cmd] }

  def initialize range_start, range_step
    @range_gen = RangeGenerator.new range_start, range_step
    @clients = ClientContainer.new
  end

  def handle req, client_id
    unless req['cmd'] && CMDS.include?(req['cmd'])
      return {
        'status' => 'ERROR',
        'msg' => 'Illegal request'
      }
    end
    resp = self.send @@cmd_map[req['cmd']], req, client_id
    resp.merge({ 'status' => 'OK' })
  end

  def remove_client client_id
    r = @clients.get_range client_id
    @range_gen.push_range r unless r.nil?
    @clients.pop client_id
  end

  def run_round_robin required_clients_num
    rr = @clients.c_rr
    return if rr.size < required_clients_num

    arr = ClientContainer.to_array rr

    puts "\nExchange (Round robin):\n"
    puts "RR (Before): #{arr.to_s}"

    exchange = ->(i_from, i_to, r = arr[i_from][1]['range']) do
      c_from, c_to = arr[i_from], arr[i_to]
      puts "RR (From): #{c_from[0]}\tTo: #{c_to[0]}\tr: #{r}"
      c_to[1]['range'] = r
      c_from[1]['next_id'] = c_to[0]
      TCPSocket.open(c_from[1]['host'], c_from[1]['port']) do |s|
        s.puts({
          'cmd' => 'exchange',
          'next_host' => c_to[1]['host'],
          'next_port' => c_to[1]['port']
        }.to_json)
      end
    end

    last_range = arr[arr.size - 1][1]['range'].dup
    (arr.size - 1).downto(1) { |i| exchange.(i - 1, i) }
    exchange.(arr.size - 1, 0, last_range)

    puts "RR (After): #{arr.to_s}\n\n"
  end

  private
    def parse_sys_info sys_info
      #Parsing client's system infomation
    end

    def make_db_record req, client_id
      c = @clients.find client_id
      {
        :login => c['login'],
        :host => c['host'],
        :range_down => req['range'].min.to_s,
        :range_up => req['range'].max.to_s,
        :nums => (req['primes'].map { |el| el.to_s })
      }
    end

    #--------------- Commands --------------- 

    def cmd_join req, client_id
      @clients.push(
        client_id,
        {
          'login' => req['login'],
          'host' => req['host']
        },
        req['round_robin']
      )

      {}
    end

    def cmd_get_range req, client_id
      #parse_sys_info req['sys_info']
      r = @range_gen.next
      @clients.add_range client_id, r

      { 'range' => r }
    end

    def cmd_put_solution req, client_id
      Prime.create! make_db_record(req, client_id)
      @clients.remove_range client_id

      {}
    end

    def cmd_put_part_solution req, client_id
      Prime.create! make_db_record(req, client_id)
      @clients.add_range(
        @clients.c_rr[client_id]['next_id'],
        req['next_range']
      )

      {}
    end
end

class PServer
  def self.start host, port, rr, range_start, range_step
    handler = Handler.new range_start, range_step
    EventMachine::run do
      EM.add_periodic_timer(rr['interval']) do
        handler.run_round_robin rr['clients_num']
      end
      EventMachine::start_server host, port, EMServer, handler, rr
    end
  end
  
  private
    class EMServer < EventMachine::Connection
      include EventMachine::Protocols::ObjectProtocol

      @@id_gen = IdGenerator.new

      def initialize handler, rr
        super
        @handler, @rr = handler, rr
      end

      def post_init
        @id = @@id_gen.next
        puts 'Connection'
      end

      def unbind
        @handler.remove_client @id
        puts 'Disconnection'
      end

      def receive_object obj
        send_object @handler.handle(obj, @id)
      end
    end
end

cnfg = YAML.load_file 'configure.yml'

Mongoid.configure do |c|
  name = cnfg['db']['name']
  host = cnfg['db']['host']
  c.master = Mongo::Connection.new.db(name)
end

PServer.start(
  cnfg['params']['host'],
  cnfg['params']['port'],
  cnfg['round_robin'],
  ARGV[0] ? ARGV[0].to_i : cnfg['params']['range_start'],
  ARGV[1] ? ARGV[1].to_i : cnfg['params']['range_step']
)

