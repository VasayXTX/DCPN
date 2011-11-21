#coding: utf-8

class Prime
  include Mongoid::Document
  field :range, type: Range
  field :nums, type: Array
end

