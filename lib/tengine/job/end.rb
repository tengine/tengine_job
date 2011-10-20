# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブネットの終端を表すVertex。特に状態は持たない。
class Tengine::Job::End < Tengine::Job::Vertex

  # https://cacoo.com/diagrams/hdLgrzYsTBBpV3Wj#D26C1
  def transmit(signal)
    start_owner_finally(signal)
  end

  def activate(signal)
    if parent.phase_key == :running
      complete_origin_edge(signal)
      parent.phase_key =
        parent.end_vertex.prev_edge.closed? ? :error : :success
      signal.paths << self
      signal.process(self)
    end
  end

end
