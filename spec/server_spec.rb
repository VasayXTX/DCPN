#codign: utf-8

%w[rspec socket json].each { |gem| require gem }
require File.join(File.dirname(__FILE__), '..', 'miller_rabin_test')

STEP = 1000000
PORT = 4567

def range_it n
  range = [2, STEP]
  counter = 0
  while counter < n do
    yield range
    range = [range[1] + 1, range[1] + STEP]
    counter += 1
  end
end

describe "Test cmd 'getRange'" do
  range_it(10) do |range|
    it "get range #{range} for processing" do
      Thread.new(range) do |r|
        TCPSocket.open('localhost', PORT) do |s|
          s.puts({
            'cmd' => 'getRange',
            'CPU' => 'Some CPU',
            'RAM' => 'Some RAM',
            'HDD' => 'Some HDD'
          }.to_json)
          resp = JSON.parse s.gets
          puts resp.to_s
          resp.should eq({
            'status' => 'OK',
            'rangeDown' =>  r[0],
            'rangeUp' =>  r[1],
            'accurancy' => 4
          })
        end
      end
    end
  end
  Thread.list.each { |th| th.join unless th == Thread.main }
end

