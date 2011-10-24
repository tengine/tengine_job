# -*- coding: utf-8 -*-
class Tengine::Job::Execution
  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Job::Executable

  field :target_actual_ids, :type => Array
  array_text_accessor :target_actual_ids

  field :preparation_command, :type => String
  field :actual_base_timeout_alert, :type => Integer
  field :actual_base_timeout_termination, :type => Integer
  field :estimated_time, :type => Integer
  field :keeping_stdout, :type => Boolean
  field :keeping_stderr, :type => Boolean

  belongs_to :root_jobnet, :class_name => "Tengine::Job::RootJobnetActual", :index => true, :inverse_of => :executions

  # 実開始日時から求める予定終了時刻
  def actual_estimated_end
    return nil unless started_at
    (started_at + (estimated_time || 0)).utc
  end

  def transmit(signal)
    case phase_key
    when :initialized then
      self.phase_key = :ready
    end
  end

  def activate(signal)
    case phase_key
    when :ready then
      self.phase_key = :starting
    end
  end

  def ack(signal)
    case phase_key
    when :ready then
      raise Tengine::Job::Executable::PhaseError, "ack not available on #{phase_key.inspect}"
    when :starting then
      self.phase_key = :running
    end
  end

end
