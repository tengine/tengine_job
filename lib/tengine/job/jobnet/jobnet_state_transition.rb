# -*- coding: utf-8 -*-
require 'tengine/job/jobnet'

module Tengine::Job::Jobnet::JobnetStateTransition

  # ハンドリングするドライバ: ジョブネット制御ドライバ or ジョブ起動ドライバ
  def jobnet_transmit(signal)
    case self.phase_key
    when :ready then
      self.phase_key = :starting
      signal.fire(self, :"start.jobnet.job.tengine", {
          :target_jobnet_id => self.id,
        })
    end
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def jobnet_activate(signal)
    complete_origin_edge(signal)
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  # このackは、子要素のTengine::Job::Start#activateから呼ばれます
  def jobnet_ack(signal)
    case self.phase_key
    when :ready then
      raise Tengine::Job::Vertex::PhaseError, "ack not available on ready"
    when :starting then
      self.phase_key = :running
    end
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  # このackは、子要素のTengine::Job::End#activateから呼ばれます
  def jobnet_finish(signal)
    end_vertex.prev_edge.closed? ?
      jobnet_fail(signal) :
      jobnet_succeed(signal)
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def jobnet_succeed(signal)
    case self.phase_key
    when :ready, :error then
      raise Tengine::Job::Vertex::PhaseError, "ack not available on succeed"
    when :starting, :running, :dying, :stuck then
      self.phase_key = :success
      signal.fire(self, :"success.jobnet.job.tengine", {
          :target_jobnet_id => self.id,
        })
    end
  end

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def jobnet_fail(signal)
    case self.phase_key
    when :ready, :success then
      raise Tengine::Job::Vertex::PhaseError, "ack not available on succeed"
    when :starting, :running, :dying, :stuck then
      self.phase_key = :error
      signal.fire(self, :"error.jobnet.job.tengine", {
          :target_jobnet_id => self.id,
        })
    end
  end

end
