# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブネットの終端を表すVertex。特に状態は持たない。
class Tengine::Job::End < Tengine::Job::Vertex

  # https://cacoo.com/diagrams/hdLgrzYsTBBpV3Wj#D26C1
  def transmit(signal)
    if parent_finally = parent.finally_vertex
      parent_finally.transmit(signal)
    else
      activate(signal)
    end
  end

  def activate(signal)
    complete_origin_edge(signal)
    jobnet = self.parent # Endのparentであるジョブネット
  end

end
