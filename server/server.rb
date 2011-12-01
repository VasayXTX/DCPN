#coding: utf-8

%w[eventmachine mongoid yaml].each { |gem| require gem }
require File.join(File.dirname(__FILE__), 'models', 'prime')

class RangeGenerator
  START = ARGV[0] ? ARGV[0].to_i : 2
  STEP = ARGV[1] ? ARGV[1].to_i : 10 ** 6
  attr_reader :range

  def initialize step = STEP
    @step, @range = step, (START..START+step)
    @buf = []
    @fiber = Fiber.new do
      loop do
        unless @buf.empty?
          r = @buf.pop
          is_next = false
        else
          r = @range
          is_next = true
        end
        Fiber.yield r
        @range = (@range.max+1..@range.max+@step) if is_next
      end
    end
  end
  
  def next; @fiber.resume; end
  def push range; @buf = [range] + @buf; end
end

class Handler
  def initialize range_step
    @resp_map = {
      'getRange' => :cmd_get_range,
      'putSolution' => :cmd_put_solution
    }
    @range_gen = RangeGenerator.new range_step
    @ranges = {}
  end

  def handle req
    if (cmd = @resp_map[req['cmd']]).nil?
      return {
        'status' => 'ERROR',
        'msg' => 'Illegal command'
      }
    end
    resp = self.send cmd, req

    resp.merge({ 'status' => 'OK' })
  end

  def cmd_get_range req
    #parse_sys_info req['sys_info']
    r = @range_gen.next
    @ranges[r] = true
    { 'range' => r }
  end
  private :cmd_get_range

  def cmd_put_solution req
    Prime.create!(
      range_down: req['range'].min.to_s,
      range_up: req['range'].max.to_s,
      nums: (req['primes'].map { |el| el.to_s })
    )
    @ranges.delete(req['range'])

    {}
  end
  private :cmd_put_solution

  def parse_sys_info sys_info
    #.........parsing...........
  end
  private :parse_sys_info

  def check_range range
    @range_gen.push(range) if @ranges[range]
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

      def initialize rr
        super
        @rr = rr
      end

      def post_init
        puts 'Connection'
      end

      def unbind
        @@handler.check_range(@range) if @range
        puts 'Disconnection'
      end

      def receive_object obj
        resp = @@handler.handle obj
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

