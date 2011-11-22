#coding: utf-8

class Prime
  include Mongoid::Document
  field :range_down, type: String
  field :range_up, type: String
  field :nums, type: Array  #Array of strings
end

