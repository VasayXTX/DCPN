#coding: utf-8

require 'progressbar'

class PSearchEngine
  @@status = :started

  def self.miller_rabin obj
    range = obj['range']
    puts "Miller-Rabin test for #{range}"
    pbar = ProgressBar.new "Processing", 100
    pbar_step = 100.to_f / (range.max - range.min)

    res = []
    acc = obj['cur_acc'] || Math.log2(range.min).ceil
    range.each do |x|
      pbar.inc pbar_step
      is_prime, params = MillerRabin.test(
        x,
        acc,
        obj['cur_t'],
        obj['cur_s']
      )
      unless params.nil?
        params['range'] = range.min..(x - 1)
        return [res, params]
      else
        res << x if is_prime
      end
      acc = Math.log2(x+1).ceil
    end

    pbar.finish
    @@status = :finished

    [res, { 'range' => range }]
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

      def self.test num, acc, cur_t, cur_s
        return [num == 2, nil] if num.even? || num < 2

        if cur_t.nil? || cur_s.nil?
          t, s = num - 1, 1
          while (t >>= 1).even?; s += 1; end
        else
          t, s = cur_t, cur_s
        end

        (acc).times do |i|
          if PSearchEngine.get_status == :stoped
            return [
              false,
              {
                'cur_acc' => i, 
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

