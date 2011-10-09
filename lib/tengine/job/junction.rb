# -*- coding: utf-8 -*-
require 'tengine/job'

# ForkやJoinの継承元となるVertex。特に状態は持たない。
class Tengine::Job::Junction < Tengine::Job::Vertex

  def activate_if_possible
    possible? ? activate : []
  end

  def possible?
    previous_edges.all?{|edge| edge.status_key == :transmitted}
  end

  def activate
    next_edges.map{|edge| edge.transmit}.flatten.compact
  end


end
