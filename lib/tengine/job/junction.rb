# -*- coding: utf-8 -*-
require 'tengine/job'

# ForkやJoinの継承元となるVertex。特に状態は持たない。
class Tengine::Job::Junction < Tengine::Job::Vertex

  # https://cacoo.com/diagrams/hdLgrzYsTBBpV3Wj#D26C1
  def activate(signal)
    complete_origin_edge(signal)
    return unless prev_edges.all?(:transmitted?)
    next_edges.each{|edge| edge.transmit(signal)}
  end

end
