#coding: utf-8

%w[socket json].each { |gem| require gem }

class RangeGenerator
  STEP = 10 ** 6
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
  def initialize range_step, log_name
    @log = File.open log_name, 'a+'
    @resp_map = {
      'getRange' => :cmd_get_range,
      'putSolution' => :cmd_put_solution
    }
    @range_gen = RangeGenerator.new range_step
  end

  def handle req
    h = JSON.parse req
    unless cmd = @resp_map[h['cmd']]
      return { 'status' => 'ERROR', 'msg' => 'Illegal command' }.to_json
    end
    resp = self.send cmd.to_sym, h

    resp.merge({ 'status' => 'OK' }).to_json
  end

  def cmd_get_range h_req
    r_down, r_up = @range_gen.next
    
    {
      'rangeDown' => r_down,
      'rangeUp' => r_up,
    }
  end

  def cmd_put_solution h_req
    @log.puts h_req['primes'].to_s
    {}
  end

  def close_log; @log.close; end
end

params = {
  :host => '127.0.0.1',
  :port => ARGV[0] ||= 4567,
  :step => ARGV[1] ||= RangeGenerator::STEP
}

serv = TCPServer.new params[:host], params[:port]
socks = [serv]

handler = Handler.new params[:step], 'logfile'

begin
  loop do
    i_sock = select(socks)[0]
    next if i_sock.nil?
    for s in i_sock
      if s == serv
        socks << s.accept
      else
        if s.eof?
          s.close
          socks.delete(s)
        else
          s.puts handler.handle(s.gets)
        end
      end
    end
  end
rescue Interrupt, SystemExit
  puts 'Server was stopped'
  handler.close_log
rescue Exception => ex
  puts ex.message
  handler.close_log
end

