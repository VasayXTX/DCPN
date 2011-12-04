#coding: utf-8

%w[eventmachine json yaml socket].each { |gem| require gem }
[
  %w[primes_search_engine],
  %w[sys_info]
].each do |path| 
  require File.join(File.dirname(__FILE__), *path)
end

class PException < Exception
  attr_reader :msg
  def initialize msg; @msg = msg; end
end

class PClient
  def start host, port, params, rr
    EventMachine::run do
      EventMachine::connect host, port, EM, params, rr
      Thread.new { RRServer.start rr['host'], rr['port'] } if rr
    end
    RRServer.stop if rr
    Thread.list.each { |th| th.join unless th == Thread.main }
  end

  private
    #******************************************
    #--------------- EM client ----------------
    #******************************************
    class EM < EventMachine::Connection

      include EventMachine::Protocols::ObjectProtocol

      #@@sys_info = SysInfo.get
      
      CMDS = %w[join getRange putSolution putPartSolution]
      @@hndl_cmd_map = Hash.new do |h, k|
        h[k] = "hndl_#{(k.gsub(/[A-Z]/) { |s| s = "_#{s.downcase}".to_sym})}"
      end
      CMDS.each { |cmd| @@hndl_cmd_map[cmd] }

      def initialize params, rr
        super
        @params, @rr = params, rr
        @it_num = params['range_nums'] ? params['range_nums'] : 1
      end

      def post_init; cmd_join; end

      def receive_object obj
        raise PException.new(obj['msg']) unless obj['status'] == 'OK'
        self.send @@hndl_cmd_map[@last_cmd], obj
      end

      #---------------- cmd 'join' ---------------- 
      def cmd_join
        obj = {
          'cmd' => 'join',
          'login' => @params['login'],
          'host' => @params['host']
        }
        obj['round_robin'] = @rr if @rr
        send_object(obj)
        @last_cmd = 'join'
      end

      def hndl_join obj
        cmd_get_range
      end

      #---------------- cmd 'getRange' ---------------- 
      def cmd_get_range
        obj = {
          'cmd' => 'getRange',
          #'sys_info' => @@sys_info
        }
        obj['round_robin'] = @rr if @rr
        send_object(obj)
        @last_cmd = 'get_range'
      end

      def hndl_get_range obj
        puts "Get range: #{obj}"
        primes, params = PSearchEngine.miller_rabin(obj)
        if PSearchEngine.get_status == :finished
          cmd_put_solution({
            'range' => params['range'],
            'primes' => primes
          })
          return
        end
        #puts "\n\nPrimes: #{primes}"
        #puts "Params: #{params}\n"
        range = params['range'].dup
        params['range'] = (params['range'].max+1)..obj['range'].max
        cmd_put_part_solution({
          'primes' => primes,
          'range' => range,
          'next_range' => params['range']
        }, params)
      end

      #---------------- cmd 'putSolution' ---------------- 
      def cmd_put_solution sol
        send_object({ 'cmd' => 'putSolution' }.merge(sol))
        @last_cmd = 'put_solution'
      end

      def hndl_put_solution obj
        if (@it_num -= 1) > 0
          cmd_get_range
        else
          EventMachine::stop_event_loop
        end
      end

      #---------------- cmd 'putPartSolution' ---------------- 
      def cmd_put_part_solution sol, params
        send_object({ 'cmd' => 'putPartSolution' }.merge(sol))
        @last_cmd = 'put_part_solution'
        @last_params = params
      end

      def hndl_put_part_solution obj
        RRServer.send_to @last_params
        obj_received = RRServer.take_received
        #puts "Received from prev client:\t#{obj_received}"
        hndl_get_range obj_received
      end
    end

    #******************************************
    #---- Server for round-robin algorithm ----
    #******************************************
    class RRServer
      def self.start host, port
        @@host, @@port = host, port
        @@is_received = false

        serv = TCPServer.new @@host, @@port
        socks = [serv]

        worked = true
        while worked
          nsock = select(socks)
          next if nsock == nil
          for s in nsock[0]
            if s == serv
              socks.push(s.accept)
            else
              if s.eof?
                s.close
                socks.delete(s)
              else
                data = s.gets
                h = JSON.parse data
                if h['cmd'] == 'local_exit'
                  worked = false 
                elsif h['cmd'] == 'exchange'
                  puts "#{h.to_s}"
                  @@next_host = h['next_host']
                  @@next_port = h['next_port']
                  PSearchEngine.set_status :stopped
                elsif h['cmd'] == 'receive'
                  ends = h['params']['range'].split('..').map{ |d| d.to_i }
                  h['params']['range'] = ends[0]..ends[1]
                  @@received_params = h['params']
                  @@is_received = true
                end
              end
            end
          end
        end
        socks.each { |s| s.close }
      end

      def self.stop
        TCPSocket.open(@@host, @@port) do |s|
          s.puts ({ 'cmd' => 'local_exit' }).to_json
        end
      end

      def self.send_to params
        TCPSocket.open(@@next_host, @@next_port) do |s|
          s.puts({
            'cmd' => 'receive',
            'params' => params
          }.to_json)
        end
      end

      def self.take_received
        while !@@is_received; end
        @@is_received = false

        @@received_params
      end
    end
end

cnfg = YAML.load_file ARGV[0] ? ARGV[0] : 'configure.yml'

begin
  PClient.new.start(
    cnfg['server']['host'],
    cnfg['server']['port'],
    cnfg['params'],
    cnfg['round_robin']
  )
rescue PException => ex
  puts ex.msg
end

