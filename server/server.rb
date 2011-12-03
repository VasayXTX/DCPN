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

  def initialize range_step
    @range_gen = RangeGenerator.new range_step
    @clients = ClientContainer.new
  end

  def handle req, client_id
    if (cmd = @@cmd_map[req['cmd']]).nil?
      return {
        'status' => 'ERROR',
        'msg' => 'Illegal command'
      }
    end

    resp = self.send cmd, req, client_id

    resp.merge({ 'status' => 'OK' })
  end

  def remove_client client_id
    r = @clients.get_range client_id
    @range_gen.push_range r unless r.nil?
    @clients.pop client_id
  end

  def run_round_robin required_clients_num
    #puts "Simple clients: #{@clients.c_simple.size}\tRR clients: #{@clients.c_rr.size}\n"
    rr = @clients.c_rr
    return if rr.size < required_clients_num

    #puts "Exchange (Round robin):\n"

    arr = ClientContainer.to_array rr

    #puts "Before RR: #{arr.to_s}"

    exchange = ->(h, p, h_next, p_next) do
      TCPSocket.open(h, p) do |s|
        s.puts({
          'cmd' => 'exchange',
          'next_host' => h_next,
          'next_port' => p_next
        }.to_json)
      end
    end

    c_first, c_last = arr[0], arr[arr.size-1]
    foo = c_last[1]['range'].dup
    (arr.size - 1).downto(1) do |i|
      c_cur, c_prev = arr[i], arr[i-1]
      c_cur[1]['range'] = c_prev[1]['range']
      c_prev[1]['next_id'] = c_cur[0]
      exchange.(
        c_prev[1]['host'],
        c_prev[1]['port'],
        c_cur[1]['host'],
        c_cur[1]['port']
      )
    end
    c_first[1]['range'] = foo
    c_last[1]['next_id'] = c_first[0]
    exchange.(
      c_last[1]['host'],
      c_last[1]['port'],
      c_first[1]['host'],
      c_first[1]['port']
    )

    #puts "After RR: #{arr.to_s}"
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
      new_r = (req['range'].max + 1)..r.max unless r.max == req['range'].max
      @clients.set_range @clients.c_rr[client_id]['next_id'], new_r
      puts @clients.c_rr.to_s
      
      {}
    end
end

class PServer
  def self.start host, port, rr
    handler = Handler.new RangeGenerator::STEP
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
  cnfg['round_robin']
)

