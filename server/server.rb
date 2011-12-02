#coding: utf-8

%w[eventmachine mongoid yaml].each { |gem| require gem }
[
  %w[models prime],
  %w[generators],
  %w[client_container]
].each do |path| 
  require File.join(File.dirname(__FILE__), *path)
end

class Handler

  CMDS = %w[join getRange putSolution]
  @@cmd_map = Hash.new do |h, k| 
    h[k] = "cmd_#{(k.gsub(/[A-Z]/) { |s| s = "_#{s.downcase}".to_sym})}"
  end
  CMDS.each { |cmd| @@cmd_map[cmd] }

  def initialize range_step
    @range_gen = RangeGenerator.new range_step
    @clients = ClientContainer.new
    @ranges = {}
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

  def check_range r
    @range_gen.push_range(r) if @ranges[r]
  end

  def unbind_client client_id
    @clients.pop client_id
  end

  private
    def parse_sys_info sys_info
      #.........parsing...........
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
      @ranges[r] = true

      { 'range' => r }
    end

    def cmd_put_solution req, client_id
      c = @clients.get client_id
      Prime.create!(
        login: c['login'],
        host: c['host'],
        range_down: req['range'].min.to_s,
        range_up: req['range'].max.to_s,
        nums: (req['primes'].map { |el| el.to_s })
      )
      @ranges.delete(req['range'])

      {}
    end
end

class PServer
  def self.start host, port, rr
    EventMachine::run do
      EventMachine::start_server host, port, EM, rr
    end
  end
  
  private
    class EM < EventMachine::Connection
      include EventMachine::Protocols::ObjectProtocol

      @@handler = Handler.new RangeGenerator::STEP
      @@id_gen = IdGenerator.new

      def initialize rr
        super
        @rr = rr
      end

      def post_init
        @id = @@id_gen.next

        puts 'Connection'
      end

      def unbind
        @@handler.check_range(@range) if @range
        @@handler.unbind_client @id

        puts 'Disconnection'
      end

      def receive_object obj
        resp = @@handler.handle obj, @id
        @range = resp['range']
        send_object resp
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
  cnfg['host'],
  cnfg['port'],
  cnfg['round_robin']
)

