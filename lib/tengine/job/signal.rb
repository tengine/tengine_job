# -*- coding: utf-8 -*-
require 'tengine/job'

class Tengine::Job::Signal

  class Error < StandardError
  end

  attr_reader :driver, :event, :paths

  def initialize(driver, event)
    @driver = driver
    @event = event
    @paths = []
  end

  def leave(obj)
    @paths << obj
    paths_backup = @paths.dup
    begin
      if obj.is_a?(Tengine::Job::Edge)
        obj.destination.transmit(self)
      elsif obj.is_a?(Tengine::Job::Vertex)
        # このnext_edges毎にスレッドで並列に動かすとかアリかも
        obj.next_edges.each{|edge| edge.transmit(self)}
      else
        raise Tengine::Job::Signal::Error, "leaving unsupported object: #{obj.inspect}"
      end
    ensure
      @paths = paths_backup
    end
  end

  def fire(event_type_name, options = {})
  end

  module Transmittable
    # includeするモジュールは以下のメソッドを定義しなければならない
    def transmit(signal); raise NotImplementedError; end
    def activate(signal); raise NotImplementedError; end

    def complete_origin_edge(signal)
      origin_edge = signal.paths.last
      origin_edge.complete(signal)
    end
  end

end
