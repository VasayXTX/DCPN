#codign: utf-8

%w[rspec socket json].each { |gem| require gem }
require File.join(File.dirname(__FILE__), '..', 'miller_rabin_test')

STEP = 1000000
PORT = 4567

TH_NUM = 10

def range_it n
  range = [2, STEP]
  while n > 0 do
    yield range
    range = [range[1] + 1, range[1] + STEP]
    n -= 1
  end
end

describe "Test cmd 'getRange'" do
  res, et_sum_rd, et_sum_ru = [], 0, 0
  range_it(TH_NUM) do |range|
    Thread.new(range) do |r|
      resp = nil
      TCPSocket.open('localhost', PORT) do |s|
        s.puts({
          'cmd' => 'getRange',
          'CPU' => 'Some CPU',
          'RAM' => 'Some RAM',
          'HDD' => 'Some HDD'
        }.to_json)
        resp = JSON.parse s.gets
        res << { :rd => resp['rangeDown'], :ru => resp['rangeUp'] }
      end
    end
    et_sum_rd += range[0]
    et_sum_ru += range[1]
  end

  Thread.list.each { |th| th.join unless th == Thread.main }

  sum_rd = (res.map { |r| r[:rd] }).inject(:+)
  sum_ru = (res.map { |r| r[:ru] }).inject(:+)
  it "Sum of the 'rangeDown' should be #{et_sum_rd}" do 
    sum_rd.should == et_sum_rd
  end
  it "Sum of the 'rangeUp' should be #{et_sum_ru}" do 
    sum_ru.should == et_sum_ru
  end
end

describe "Test cmd 'putSolution'" do
  
end


