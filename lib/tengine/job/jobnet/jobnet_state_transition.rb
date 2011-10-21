# -*- coding: utf-8 -*-
require 'tengine/job/jobnet'

module Tengine::Job::Jobnet::JobnetStateTransition

  # ハンドリングするドライバ: ジョブネット制御ドライバ or ジョブ起動ドライバ
  def jobnet_transmit(signal)
    case self.phase_key
    when :ready then
      self.started_at = signal.event.occurred_at
      self.phase_key = :starting
      activate(signal)
    end
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def jobnet_activate(signal)
    complete_origin_edge(signal) if prev_edges && !prev_edges.empty?
    self.start_vertex.transmit(signal)
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  # このackは、子要素のTengine::Job::Start#activateから呼ばれます
  def jobnet_ack(signal)
    case phase_key
    when :ready then
      raise Tengine::Job::Executable::PhaseError, "ack not available on #{phase_key.inspect}"
    when :starting then
      self.phase_key = :running
    end
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  # このackは、子要素のTengine::Job::End#activateから呼ばれます
  def jobnet_finish(signal)
    edge = end_vertex.prev_edges.first
    edge.closed? ?
      jobnet_fail(signal) :
      jobnet_succeed(signal)
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def jobnet_succeed(signal)
    case phase_key
    when :ready, :error then
      raise Tengine::Job::Executable::PhaseError, "ack not available on #{phase_key.inspect}"
    when :starting, :running, :dying, :stuck then
      self.phase_key = :success
      self.finished_at = signal.event.occurred_at
      signal.fire(self, :"success.jobnet.job.tengine", {
          :target_jobnet_id => self.id,
        })
    end
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def jobnet_fail(signal)
    case phase_key
    when :ready, :success then
      raise Tengine::Job::Executable::PhaseError, "ack not available on #{phase_key.inspect}"
    when :starting, :running, :dying, :stuck then
      return if self.edges.any?(&:alive?)
      self.phase_key = :error
      self.finished_at = signal.event.occurred_at
      signal.fire(self, :"error.jobnet.job.tengine", {
          :target_jobnet_id => self.id,
        })
    end
  end

end
