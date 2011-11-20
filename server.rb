#coding: utf-8

%w[socket eventmachine].each { |gem| require gem }

class RangeGenerator
  STEP = 10 ** 4
  attr_reader :range

  def initialize step = STEP
    @step, @range = step, [2, step]
    @fiber = Fiber.new do
      loop do
        Fiber.yield @range
        @range = [@range[1] + 1, @range[1] + @step]
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
    r_down, r_up = @range_gen.next
    
    {
      'rangeDown' => r_down,
      'rangeUp' => r_up,
    }
  end

  def cmd_put_solution req
    puts req['primes'].size
    {}
  end

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

HOST = '127.0.0.1'
PORT = ARGV[0] ||= 4567

PServer.start HOST, PORT

