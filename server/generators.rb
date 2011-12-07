#coding: utf-8

class RangeGenerator
  attr_reader :range

  def initialize start, step
    @step, @range = step, (start..start+step)
    @buf = []
    @fiber = Fiber.new do
      loop do
        unless @buf.empty?
          r = @buf.pop
          is_next = false
        else
          r = @range
          is_next = true
        end
        Fiber.yield r
        @range = (@range.max+1..@range.max+@step) if is_next
      end
    end
  end
  
  def next; @fiber.resume; end
  def push_range r; @buf = [r] + @buf; end
end

class IdGenerator
  def initialize start_id = 1
    @cur_id = start_id
    @fiber = Fiber.new do
      loop do
        Fiber.yield @cur_id
        @cur_id += 1
      end
    end
  end

  def next; @fiber.resume; end
end

