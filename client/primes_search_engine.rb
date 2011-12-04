#coding: utf-8

require 'progressbar'

class PSearchEngine
  @@status = :started

  def self.miller_rabin obj
    @@status = :finished
    range = obj['range']
    puts "Miller-Rabin test for #{range}"
    pbar = ProgressBar.new "Processing", 100
    pbar_step = 100.to_f / (range.max - range.min)

    primes = []

    puts "MR: #{obj}"
    start = if obj['acc']
              primes << range.min if MillerRabin.test(
                range.min, obj['acc'], obj['cur_t'], obj['cur_s'])
              range.min + 1
            else
              range.min
            end

    (start..range.max).each do |x|
      pbar.inc pbar_step
      is_prime, params = MillerRabin.test(x)
      unless params.nil?  #If it was stopped
        params['range'] = range.min..(x-1)
        return [primes, params]
      else
        primes << x if is_prime
      end
    end

    pbar.finish
    @@status = :finished

    [primes, { 'range' => range }]
  end

  def self.set_status status; @@status = status; end
  def self.get_status; @@status; end

  private
    module MillerRabin
      #Modular exponentiation by squaring
      def self.mod_exp_sq b, e, m
        res = 1
        while e > 0 do
          res = res * b % m if e & 1 == 1
          e >>= 1
          b = b * b % m
        end

        res
      end

      def self.test num, acc = Math.log2(num).ceil, t = nil, s = nil
        return [num == 2, nil] if num.even? || num < 2

        if t.nil? || s.nil?
          t, s = num - 1, 1
          while (t >>= 1).even?; s += 1; end
        end

        (acc).times do |i|
          if PSearchEngine.get_status == :stopped
            return [
              false,
              {
                'acc' => acc - i,
                'cur_t' => t, 
                'cur_s' => s
              }
            ]
          end
          a = rand(2..num - 1)
          x = mod_exp_sq a, t, num
          next if x == 1 || x == num - 1
          return [false, nil] unless (-> {
            (s - 1).times do
              x = x * x % num
              return false if x == 1
              return true if x == num - 1
            end
            false
          }).()
        end
        
        [true, nil]
      end
    end
end

