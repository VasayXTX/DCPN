#coding: utf-8

%w[socket json].each { |gem| require gem }

class RangeGenerator
  STEP = 1000000
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
      'accurancy' => 4
    }
  end

  def cmd_put_solution h_req

  end
end

params = {
  :host => '127.0.0.1',
  :port => ARGV[0] ||= 4567,
  :step => ARGV[1] ||= RangeGenerator::STEP
}

serv = TCPServer.new params[:host], params[:port]
socks = [serv]

handler = Handler.new params[:step]

f_log = File.open 'logfile.out', 'a+'

begin
  loop do
    nsock = select(socks)
    next if nsock.nil?
    for s in nsock[0]
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
rescue Exception
  f_log.close
end

