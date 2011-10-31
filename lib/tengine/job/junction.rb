# -*- coding: utf-8 -*-
require 'tengine/job'

# ForkやJoinの継承元となるVertex。特に状態は持たない。
class Tengine::Job::Junction < Tengine::Job::Vertex

  # https://cacoo.com/diagrams/hdLgrzYsTBBpV3Wj#D26C1
  def transmit(signal)
    complete_origin_edge(signal, :except_closed => true)
    # transmitted?で判断すると、closedなものに対する処理を考慮できないので、alive?を使って判断します
    # activate(signal) if prev_edges.all?(&:transmitted?)
    activate(signal) unless prev_edges.any?(&:alive?)
  end

  def activatable?
    prev_edges.all?(&:transmitted?)
  end

  def activate(signal)
    signal.leave(self)
  end

end
