require 'tengine/job'

class Tengine::Job::Signal


  module Transmittable
    def transmit(signal)
      raise NotImplementedError
    end

    def activate(signal)
      raise NotImplementedError
    end

    def complete_origin_edge(signal)
      origin_edge = signal.last
      origin_edge.complete(signal)
    end
  end

end
