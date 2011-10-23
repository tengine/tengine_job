# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブネットの終端を表すVertex。特に状態は持たない。
class Tengine::Job::End < Tengine::Job::Vertex

  # https://cacoo.com/diagrams/hdLgrzYsTBBpV3Wj#D26C1
  def transmit(signal)
    activate(signal)
  end

  def activate(signal)
    complete_origin_edge(signal, :except_closed => true)
    parent = self.parent # Endのparentであるジョブネット
    if parent_finally = parent.finally_vertex
      parent_finally.transmit(signal)
    else
      parent.finish(signal)
    end
  end

end
