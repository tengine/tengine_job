# -*- coding: utf-8 -*-
require 'tengine/job'

class Tengine::Job::Signal

  class Error < StandardError
  end

  attr_reader :paths, :reservations, :execution

  def initialize(execution)
    @paths = []
    @reservations = []
    @execution = execution
  end

  def leave(obj)
    @paths << obj
    with_paths_backup do
      begin
        if obj.is_a?(Tengine::Job::Edge)
          obj.destination.transmit(self)
        elsif obj.is_a?(Tengine::Job::Vertex)
          obj.next_edges.each{|edge| edge.transmit(self)}
        else
          raise Tengine::Job::Signal::Error, "leaving unsupported object: #{obj.inspect}"
        end
      rescue Tengine::Job::Signal::Error => e
        puts "[#{e.class.name}] #{e.message}\nsignal.paths: #{@paths.inspect}"
        raise e
      end
    end
  end

  def with_paths_backup
    paths_backup = @paths.dup
    begin
      yield if block_given?
    ensure
      @paths = paths_backup
    end
  end

  class Reservation
    attr_reader :source, :event_type_name, :options
    def initialize(source, event_type_name, options = {})
      @source, @event_type_name = source, event_type_name
      @options  = options
      @options[:source_name] ||= "job:#{Tengine::Event.host_name}/#{Process.pid.to_s}/#{source.root.id.to_s}/#{source.id.to_s}"
    end

    def fire_args
      [@event_type_name, @options]
    end
  end

  def fire(source, event_type_name, properties, options = {})
    options ||= {}
    options[:properties] = properties
    properties.each do |key, value|
      if value.is_a?(BSON::ObjectId)
        properties[key] = value.to_s
      end
    end
    @reservations << Reservation.new(source, event_type_name, options)
  end

  module Transmittable
    # includeするモジュールは以下のメソッドを定義しなければならない
    def transmit(signal); raise NotImplementedError; end
    def activate(signal); raise NotImplementedError; end

    def complete_origin_edge(signal)
      origin_edge = signal.paths.last
      origin_edge ||= prev_edges.first
      begin
        origin_edge.complete(signal)
      rescue Exception => e
        puts "[#{e.class.name}] #{e.message}\nsignal.paths: #{@paths.inspect}"
        raise e
      end
    end
  end

end