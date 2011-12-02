#coding: utf-8

class ClientContainer
  attr_reader :c_simple, :c_rr

  def initialize
    @c_simple, @c_rr = {}, {}
  end

  def push client_id, client, rr = nil
    if rr
      @c_rr[client_id] = client
    else
      @c_simple[client_id] = client
    end
  end

  def get client_id
    return @c_rr[client_id] if @c_rr.has_key?(client_id)
    @c_simple[client_id]
  end

  def pop client_id
    @c_rr.delete(client_id) unless @c_simple.delete(client_id)
  end

  def get_size
    @c_simple.size + @c_rr.size
  end
end

