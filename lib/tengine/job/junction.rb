# -*- coding: utf-8 -*-
require 'tengine/job'

# ForkやJoinの継承元となるVertex。特に状態は持たない。
class Tengine::Job::Junction < Tengine::Job::Vertex

  # https://cacoo.com/diagrams/hdLgrzYsTBBpV3Wj#D26C1
  def transmit(signal)
    complete_origin_edge(signal)
    activate(signal) if prev_edges.all?(:transmitted?)
  end

  def activate(signal)
    signal.leave(self)
  end

end
