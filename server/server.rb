#coding: utf-8

%w[eventmachine mongoid].each { |gem| require gem }
require File.join(File.dirname(__FILE__), 'models', 'prime')

class RangeGenerator
  START = ARGV[0] ? ARGV[0].to_i : 2
  STEP = ARGV[1] ? ARGV[1].to_i : 10 ** 6
  attr_reader :range

  def initialize step = STEP
    @step, @range = step, (START..START+step)
    @fiber = Fiber.new do
      loop do
        Fiber.yield @range
        @range = (@range.max+1..@range.max+@step)
      end
    end
  end
  
  def next; @fiber.resume; end
end

class Handler
  def initialize range_step
    @resp_map = {
      'getRange' => :cmd_get_range,
      'putSolution' => :cmd_put_solution
    }
    @range_gen = RangeGenerator.new range_step
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
    parse_sys_info req['sys_info']
    { 'range' => @range_gen.next }
  end
  private :cmd_get_range

  def cmd_put_solution req
    Prime.create!(
      range_down: req['range'].min.to_s,
      range_up: req['range'].max.to_s,
      nums: (req['primes'].map { |el| el.to_s })
    )

    {}
  end
  private :cmd_put_solution

  def parse_sys_info sys_info
    #.........parsing...........
  end
  private :parse_sys_info

  def close_log; @log.close; end
end

class PServer
  def self.start host, port
    EventMachine::run do
      EventMachine::start_server host, port, EM
    end
  end
  
  private
    module EM
      include EventMachine::Protocols::ObjectProtocol

      @@handler = Handler.new RangeGenerator::STEP

      def post_init
        puts 'Connection'
      end

      def unbind
        puts 'Disconnection'
      end

      def receive_object obj
        send_object @@handler.handle(obj)
      end
    end
end

HOST, PORT = '', 4567

Mongoid.configure do |config|
  name = "primes"
  host = "localhost"
  config.master = Mongo::Connection.new.db(name)
end

PServer.start HOST, PORT

