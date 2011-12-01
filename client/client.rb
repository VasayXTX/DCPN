#coding: utf-8

%w[eventmachine json yaml socket].each { |gem| require gem }
require File.join(File.dirname(__FILE__), 'primes_search_engine')

class SysInfo
  def self.get_h_info
    f = IO.popen('ohai')
    info = f.readlines
    info = (info.each { |str| str.chomp! }).join('')
    h_info = JSON.parse(info)
    
    h_info
  end
  private_class_method :get_h_info

  def self.get_spec_linux h_info
    {
      'memory' => {
        'total' => h_info['memory']['total'],
        'free' => h_info['memory']['free']
      },
    }
  end
  private_class_method :get_spec_linux

  def self.get_spec_windows h_info
    {
      'memory' => {
        'total' => h_info['kernel']['cs_info']['total_physical_memory'],
        'free' => h_info['kernel']['os_info']['free_physical_memory']
      },
    }
  end
  private_class_method :get_spec_windows

  def self.get
    h_info = get_h_info

    res = if h_info['os'] == 'linux'
            get_spec_linux h_info
          else
            get_spec_windows h_info
          end

    res.merge!({
      'os' => {
        'name' => h_info['os'],
        'version' => h_info['os_version']
      },
      'user' => h_info['current_user'],
      'cpu' => h_info['cpu']
    })

    res
  end
end

class PException < Exception
  attr_reader :msg
  def initialize msg; @msg = msg; end
end

class PClient
  def start host, port, n = 1, rr
    EventMachine::run do
      EventMachine::connect host, port, EM, n
      Thread.new { RRServer.start rr['host'], rr['port'] } if rr
    end
    Thread.list.each { |th| th.join unless th == Thread.main }
  end

  private
    class EM < EventMachine::Connection
      include EventMachine::Protocols::ObjectProtocol

      #@@sys_info = SysInfo.get

      HANDLING = {
        :get_range => :hndl_get_range,
        :put_solution => :hndl_put_solution
      }

      def initialize it_num
        super
        @it_num = it_num
      end

      def post_init; cmd_get_range; end

      def receive_object obj
        raise PException.new(obj['msg']) unless obj['status'] == 'OK'
        unless obj.has_key?('cmd')
          self.send HANDLING[@last_cmd], obj
        end
      end

      def cmd_get_range
        send_object({
          'round_robin' => true,
          'cmd' => 'getRange',
          #'sys_info' => @@sys_info
        })
        @last_cmd = :get_range
      end

      def hndl_get_range obj
        primes, params = PSearchEngine.miller_rabin(obj['range'])
        cmd_put_solution({
          'range' => params['range'],
          'primes' => primes
        })
      end

      def cmd_put_solution sol
        resp = {
          'cmd' => 'putSolution',
          'range' => sol['range'],
          'primes' => sol['primes']
        }
        @last_cmd = :put_solution
        send_object resp
      end

      def hndl_put_solution obj
        if (@it_num -= 1) > 0
          cmd_get_range
        else
          EventMachine::stop_event_loop
          RRServer.stop
        end
      end
    end

    #Server for round-robin algorithm
    class RRServer
      def self.start host, port
        @@host, @@port = host, port
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
                s = JSON.parse s.gets
                worked = false if s['cmd'] == 'exit'
              end
            end
          end
        end
        socks.each { |s| s.close }
      end

      def self.stop
        TCPSocket.open(@@host, @@port) do |s|
          s.puts ({ 'cmd' => 'exit' }).to_json
        end
      end
    end
end

cnfg = YAML.load_file ARGV[0] ? ARGV[0] : 'configure.yml'

begin
  PClient.new.start(
    cnfg['host'],
    cnfg['port'],
    cnfg['range_nums'] ? cnfg['range_nums'] : 1,
    cnfg['round_robin']
  )
rescue PException => ex
  puts ex.msg
end

