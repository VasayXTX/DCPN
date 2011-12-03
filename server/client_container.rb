#coding: utf-8

class ClientContainer
  attr_reader :c_simple, :c_rr

  def initialize
    @c_simple, @c_rr = {}, {}
  end

  def push client_id, client, rr = nil
    if rr
      @c_rr[client_id] = client
      @c_rr[client_id].merge! rr
    else
      @c_simple[client_id] = client
    end
  end

  def find client_id
    @c_simple[client_id] || @c_rr[client_id]
  end

  def pop client_id
    @c_rr.delete(client_id) unless @c_simple.delete(client_id)
  end

  #--------------- Ranges --------------- 
  
  def add_range client_id, r
    find(client_id)['range'] = r
  end

  def remove_range client_id
    find(client_id).delete 'range'
  end

  def get_range client_id
    find(client_id)['range']
  end

  #--------------- Class methods --------------- 

  def self.to_array c
    arr = []
    c.each_pair { |k, v| arr << [k, v] }

    arr
  end
end

