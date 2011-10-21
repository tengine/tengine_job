# -*- coding: utf-8 -*-
require 'tengine/job'
require 'selectable_attr'

# Vertexとともにジョブネットを構成するグラフの「辺」を表すモデル
# Tengine::Job::Jobnetにembeddedされます。
class Tengine::Job::Edge
  include SelectableAttr::Base
  include Mongoid::Document
  include Tengine::Job::Signal::Transmittable

  class StatusError < StandardError
  end

  embedded_in :owner, :class_name => "Tengine::Job::Jobnet", :inverse_of => :edges

  field :status_cd     , :type => Integer, :default => 0 # ステータス。とりうる値は後述を参照してください。詳しくはtengine_jobパッケージ設計書の「edge状態遷移」を参照してください。
  field :origin_id     , :type => BSON::ObjectId # 辺の遷移元となるvertexのid
  field :destination_id, :type => BSON::ObjectId # 辺の遷移先となるvertexのid

  validates :origin_id, :presence => true
  validates :destination_id, :presence => true

  selectable_attr :status_cd do
    entry  0, :active      , "active"      , :alive => true
    entry 10, :transmitting, "transmitting", :alive => true
    entry 20, :transmitted , "transmitted" , :alive => false
    entry 30, :suspended   , "suspended"   , :alive => true
    entry 31, :keeping     , "keeping"     , :alive => true
    entry 40, :closed      , "closed"      , :alive => false
  end

  def alive?; !!status_entry[:alive]; end

  status_keys.each do |status_key|
    class_eval(<<-END_OF_METHOD)
      def #{status_key}?; status_key == #{status_key.inspect}; end
    END_OF_METHOD
  end

  def origin
    owner.children.detect{|c| c.id == origin_id}
  end

  def destination
    owner.children.detect{|c| c.id == destination_id}
  end

  # https://cacoo.com/diagrams/hdLgrzYsTBBpV3Wj#3E9EA
  def transmit(signal)
    case status_key
    when :active then
      self.status_key = :transmitting
      signal.leave(self)
    when :suspended then
      self.status_key = :keeping
    when :closed
      raise Tengine::Job::Edge::StatusError, "transmit not available #{status_key.inspect} at edge #{id.to_s} from #{origin.name_path} to #{destination.name_path}"
    end
  end

  def complete(signal)
    case status_key
    when :transmitting then
      self.status_key = :transmitted
    when :active, :suspended, :keeping, :closed then
      raise Tengine::Job::Edge::StatusError, "transmit not available on #{status_key.inspect} at edge #{id.to_s} from #{origin.name_path} to #{destination.name_path}"
    end
  end

  def close_followings
    accept_visitor(Tengine::Job::Edge::Closer.new)
  end

  def accept_visitor(visitor)
    visitor.visit(self)
  end

  class Closer
    def visit(obj)
      if obj.is_a?(Tengine::Job::Vertex)
        obj.next_edges.each{|edge| edge.accept_visitor(self)}
      elsif obj.is_a?(Tengine::Job::Edge)
        obj.status_key = :closed
        obj.destination.accept_visitor(self)
      else
        raise "Unsupported class #{obj.inspect}"
      end
    end

  end


end
