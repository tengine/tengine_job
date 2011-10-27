# -*- coding: utf-8 -*-
require 'tengine/job/jobnet'

module Tengine::Job::Jobnet::JobnetStateTransition
  include Tengine::Job::Jobnet::StateTransition

  # ハンドリングするドライバ: ジョブネット制御ドライバ or ジョブ起動ドライバ
  def jobnet_transmit(signal)
    self.phase_key = :ready
    signal.fire(self, :"start.jobnet.job.tengine", {
        :target_jobnet_id => self.id,
      })
  end
  available(:jobnet_transmit, :on => :initialized,
    :ignored => [:ready, :starting, :running, :dying, :success, :error, :stuck])

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def jobnet_activate(signal)
    self.phase_key = :starting
    self.started_at = signal.event.occurred_at
    complete_origin_edge(signal) if prev_edges && !prev_edges.empty?
    (parent || signal.execution).ack(signal)
    signal.paths << self
    self.start_vertex.transmit(signal)
  end
  available(:jobnet_activate, :on => :ready,
    :ignored => [:starting, :running, :dying, :success, :error, :stuck])

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  # このackは、子要素のTengine::Job::Start#activateから呼ばれます
  def jobnet_ack(signal)
    self.phase_key = :running
  end
  available(:jobnet_ack, :on => :starting,
    :ignored => [:running, :dying, :success, :error, :stuck])

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
    self.phase_key = :success
    self.finished_at = signal.event.occurred_at
    signal.fire(self, :"success.jobnet.job.tengine", {
        :target_jobnet_id => self.id,
      })
  end
  available :jobnet_succeed, :on => [:starting, :running, :dying, :stuck], :ignored => [:success]

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def jobnet_fail(signal)
    return if self.edges.any?(&:alive?)
    self.phase_key = :error
    self.finished_at = signal.event.occurred_at
    signal.fire(self, :"error.jobnet.job.tengine", {
        :target_jobnet_id => self.id,
      })
  end
  available :jobnet_fail, :on => [:starting, :running, :dying, :stuck], :ignored => [:error]

  def jobnet_stop(signal)
    self.phase_key = :dying
    self.stopped_at = signal.event.occurred_at
    self.stop_reason = signal.event[:stop_reason]
  end
  available :jobnet_stop, :on => :running, :ignored => [:dying, :success, :error, :stuck]
end
