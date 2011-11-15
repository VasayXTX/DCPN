#codign: utf-8

%w[rspec socket json].each { |gem| require gem }
require File.join(File.dirname(__FILE__), '..', 'miller_rabin_test')

STEP = 10 ** 6
PORT = 4567
HOST = 'localhost'

TH_NUM = 10

def range_it n
  range = [2, STEP]
  while n > 0 do
    yield range
    range = [range[1] + 1, range[1] + STEP]
    n -= 1
  end
end

ranges = []

describe "Test cmd 'getRange'" do
  et_sum_rd, et_sum_ru = 0, 0
  ans = []
  range_it(TH_NUM) do |range|
    Thread.new(range) do |r|
      resp = nil
      TCPSocket.open(HOST, PORT) do |s|
        s.puts({
          'cmd' => 'getRange',
          'CPU' => 'Some CPU',
          'RAM' => 'Some RAM',
          'HDD' => 'Some HDD'
        }.to_json)
        resp = JSON.parse s.gets
        ranges << { :rd => resp['rangeDown'], :ru => resp['rangeUp'] }
        ans << resp['status']
      end
    end
    et_sum_rd += range[0]
    et_sum_ru += range[1]
  end

  Thread.list.each { |th| th.join unless th == Thread.main }

  it "All statuses should be 'OK', also sum of the 'rangeDown' should be #{et_sum_rd} and sum of the 'rangeUp' should be #{et_sum_ru}" do
    ans.each { |a| a.should == 'OK' }
    sum_rd = (ranges.map { |r| r[:rd] }).inject(:+)
    sum_ru = (ranges.map { |r| r[:ru] }).inject(:+)
    sum_rd.should == et_sum_rd
    sum_ru.should == et_sum_ru
  end
end

=begin
describe "Test cmd 'putSolution'" do
  ans = []
  ranges.each do |range|
    Thread.new(range) do |r|
      r[:primes] = []
      for i in r[:rd]..r[:ru] do
        r[:primes] << i if miller_rabin_test(i, Math.log2(i).ceil)
      end
      TCPSocket.open(HOST, PORT) do |s|
        s.puts({
          'cmd' => 'putSolution',
          'primes' => range[:primes]
        }.to_json)
        foo = s.gets
        ans << JSON.parse(foo)['status']
      end
    end
  end
  it "Status should be 'OK' for all queries" do
    ans.each { |a| a.should == 'OK' }
  end
end

describe "Test cmd 'getPrimes'" do
  
end
=end

