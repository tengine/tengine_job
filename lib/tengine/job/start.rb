# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブネットの始端を表すVertex。特に状態は持たない。
class Tengine::Job::Start < Tengine::Job::Vertex

  # https://cacoo.com/diagrams/hdLgrzYsTBBpV3Wj#D26C1
  def transmit(signal)
    activate(signal)
  end

  def activate(signal)
    if parent.phase_key == :ready
      parent.phase_key = :starting
      signal.paths << self
      signal.process(self)
    end
  end

end
