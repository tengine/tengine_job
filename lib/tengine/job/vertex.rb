# -*- coding: utf-8 -*-
require 'tengine/job'

# Edgeとともにジョブネットを構成するグラフの「頂点」を表すモデル
# 自身がツリー構造を
class Tengine::Job::Vertex
  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Job::Signal::Transmittable
  include Tengine::Job::NamePath

  self.cyclic = true
  with_options(:class_name => self.name, :cyclic => true) do |c|
    c.embedded_in :parent  , :inverse_of => :children
    c.embeds_many :children, :inverse_of => :parent
  end

#   def short_inspect
#     "#<%%%-30s id: %s>" % [self.class.name, self.id.to_s]
#   end
#   alias_method :long_inspect, :inspect
#   alias_method :inspect, :short_inspect

  def previous_edges
    return nil unless parent
    parent.edges.select{|edge| edge.destination_id == self.id}
  end
  alias_method :prev_edges, :previous_edges

  def next_edges
    return nil unless parent
    parent.edges.select{|edge| edge.origin_id == self.id}
  end

  def root
    (parent = self.parent) ? parent.root : self
  end

  def ancestors
    if parent = self.parent
      parent.ancestors + [parent]
    else
      []
    end
  end


  IGNORED_FIELD_NAMES = ["_type", "_id"].freeze

  def actual_class; self.class; end
  def generate(klass = actual_class)
    field_names = self.class.fields.keys - IGNORED_FIELD_NAMES
    attrs = field_names.inject({}){|d, name| d[name] = send(name); d }
    result = klass.new(attrs)
    src_to_generated = {}
    self.children.each do |child|
      generated = child.generate
      src_to_generated[child.id] = generated.id
      result.children << generated
    end
    if respond_to?(:edges)
      edges.each do |edge|
        generated = edge.class.new
        generated.origin_id = src_to_generated[edge.origin_id]
        generated.destination_id = src_to_generated[edge.destination_id]
        result.edges << generated
      end
    end
    result
  end




  # def ancestors_until_expansion
  #   if (parent = self.parent) && !self.was_expansion?
  #     parent.ancestors_until_expansion + [parent]
  #   else
  #     []
  #   end
  # end
  # TODO expansionをちゃんと実装する際にコメントアウトを外します
  alias_method :ancestors_until_expansion, :ancestors

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
