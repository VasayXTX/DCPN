#coding: utf-8

%w[eventmachine json].each { |gem| require gem }
require File.join(File.dirname(__FILE__), 'primes_search_engine')

HOST, PORT = ARGV[0], ARGV[1]
N = ARGV[2] ? ARGV[2].to_i : 1

class SysInfo
  def self.get
    f = IO.popen('ohai')
    info = f.readlines
    info = (info.each { |str| str.chomp! }).join('')
    h_info = JSON.parse(info)

    {
      'os' => {
        'name' => h_info['os'],
        'version' => h_info['os_version']
      },
      'platform' => {
        'name' => h_info['platform'],
        'version' => h_info['platform_version']
      },
      'user' => h_info['current_user'],
      'memory' => {
        'total' => h_info['memory']['total'],
        'free' => h_info['memory']['free']
      },
      'cpu' => h_info['cpu']
    }
  end
end

class PException < Exception
  attr_reader :msg
  def initialize msg; @msg = msg; end
end

class PClient
  def start host, port, n = 1
    n.times do
      EventMachine::run do
        EventMachine::connect host, port, EM
      end
    end
  end

  private
    module EM
      include EventMachine::Protocols::ObjectProtocol

      HANDLING = {
        :get_range => :hndl_get_range,
        :put_solution => :hndl_put_solution
      }

      def post_init
        send_object({
          'cmd' => 'getRange',
          'sys_info' => SysInfo.get
        })
        @last_cmd = :get_range
      end

      def receive_object obj
        raise PException.new(obj['msg']) unless obj['status'] == 'OK'
        unless obj.has_key?('cmd')
          self.send HANDLING[@last_cmd], obj
        else
        end
      end

      def hndl_get_range obj
        resp = {
          'cmd' => 'putSolution',
          'range' => obj['range'],
          'primes' => PSearchEngine.miller_rabin(obj['range'])
        }
        @last_cmd = :put_solution
        send_object resp
      end

      def hndl_put_solution obj
        EventMachine::stop_event_loop
      end
    end
end

begin
  PClient.new.start HOST, PORT, N
rescue PException => ex
  puts ex.msg
end

