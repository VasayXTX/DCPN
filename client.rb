#coding: utf-8

%w[eventmachine].each { |gem| require gem }
require File.join(File.dirname(__FILE__), 'primes_search_engine')

th_num, host, port = ARGV

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
          'cmd' => 'getRange1',
          'CPU' => 'Some CPU',
          'RAM' => 'Some RAM',
          'HDD' => 'Some HDD'
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
          'primes' => PSearchEngine.miller_rabin(obj['rangeDown'], obj['rangeUp'])
        }
        @last_cmd = :put_solution
        puts resp['primes'].size
        send_object resp
      end

      def hndl_put_solution obj
        EventMachine::stop_event_loop
      end
    end
end

begin
  PClient.new.start host, port
rescue PException => ex
  puts ex.msg
end

