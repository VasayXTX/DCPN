#coding: utf-8

%w[eventmachine json yaml].each { |gem| require gem }
require File.join(File.dirname(__FILE__), 'primes_search_engine')

cnfg = YAML.load_file ARGV[0] ? ARGV[0] : 'configure.yml'

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
  def start host, port, n = 1
    puts host
    puts port
    puts n
    n.times do
      EventMachine::run do
        EventMachine::connect host, port, EM
      end
    end
  end

  private
    module EM
      include EventMachine::Protocols::ObjectProtocol

      #@@sys_info = SysInfo.get

      HANDLING = {
        :get_range => :hndl_get_range,
        :put_solution => :hndl_put_solution
      }

      def post_init
        send_object({
          'round_robin' => true,
          'cmd' => 'getRange',
          #'sys_info' => @@sys_info
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
  PClient.new.start(
    cnfg['host'],
    cnfg['port'],
    cnfg['range_nums'] ? cnfg['range_nums'] : 1
  )
rescue PException => ex
  puts ex.msg
end

