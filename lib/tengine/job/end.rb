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
    parent_finally = parent.finally_vertex
    if parent_finally && (parent.phase_key != :dying)
      parent_finally.transmit(signal)
    else
      parent.finish(signal)
    end
  end

  def reset(signal)
    parent = self.parent # Endのparentであるジョブネット
    unless (signal.execution.spot && (signal.execution.target_actual_ids || []).map(&:to_s).include?(parent.id.to_s))
      if f = parent.finally_vertex
        f.reset(signal)
      end
      if edge = (parent.next_edges || []).first
        edge.reset(signal)
      end
    end
  end

end
