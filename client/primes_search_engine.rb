#coding: utf-8

require 'progressbar'

class PSearchEngine
  def self.miller_rabin range
    puts "Miller-Rabin test for #{range}"
    pbar = ProgressBar.new "Processing", 100
    pbar_step = 100.to_f / (range.max - range.min)
    res = range.to_a.select do |x|
      pbar.inc pbar_step
      MillerRabin.test(x, Math.log2(x).ceil)
    end
    pbar.finish

    res
  end

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

      def self.test num, accuracy
        return num == 2 if num.even? || num < 2

        t, s = num - 1, 1
        while (t >>= 1).even?; s += 1; end

        (accuracy).times do
          a = rand(2..num - 1)
          x = mod_exp_sq a, t, num
          next if x == 1 || x == num - 1
          return false unless (-> {
            (s - 1).times do
              x = x * x % num
              return false if x == 1
              return true if x == num - 1
            end
            false
          }).()
        end
        
        true
      end
    end
end

