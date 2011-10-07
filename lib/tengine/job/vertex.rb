# -*- coding: utf-8 -*-
require 'tengine/job'

# Edgeとともにジョブネットを構成するグラフの「頂点」を表すモデル
# 自身がツリー構造を
class Tengine::Job::Vertex
  include Mongoid::Document

  self.cyclic = true
  with_options(:class_name => self.name, :cyclic => true) do |c|
    c.embedded_in :parent  , :inverse_of => :children
    c.embeds_many :children, :inverse_of => :parent
  end

  def short_inspect
    "#<%%%-30s id: %s>" % [self.class.name, self.id.to_s]
  end
  alias_method :long_inspect, :inspect
  alias_method :inspect, :short_inspect

  def previous_edges
    return nil unless parent
    parent.edges.select{|edge| edge.destination_id == self.id}
  end
  alias_method :prev_edges, :previous_edges

  def next_edges
    return nil unless parent
    parent.edges.select{|edge| edge.origin_id == self.id}
  end


  def accept_visitor(visitor)
    visitor.visit(self)
  end

  class AnyVisitor
    def initialize(&block)
      @block = block
    end
    def visit(vertex)
      if result = @block.call(vertex)
        return result
      end
      vertex.children.each do |child|
        if result = child.accept_visitor(self)
          return result
        end
      end
      return nil
    end
  end

end
