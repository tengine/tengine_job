# -*- coding: utf-8 -*-
require 'tengine/job/jobnet'

module Tengine::Job::Jobnet::JobStateTransition

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def job_transmit(signal)
    case self.phase_key
    when :ready then
      self.phase_key = :starting
      signal.fire(:"start.job.job.tengine", {
          :target_jobnet_id => parent.id,
          :target_job_id => self.id,
        })
    end
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_activate(signal)
    complete_origin_edge(signal)
    # 実際にSSHでスクリプトを実行
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  # スクリプトのプロセスのPIDを取得できたときに実行されます
  def job_ack(signal)
    case self.phase_key
    when :ready then
      raise Tengine::Job::Vertex::PhaseError, "ack not available on ready"
    when :starting then
      self.phase_key = :running
    end
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_succeed(signal)
    case self.phase_key
    when :ready, :error then
      raise Tengine::Job::Vertex::PhaseError, "ack not available on succeed"
    when :starting, :running, :dying, :stuck then
      self.phase_key = :success
      signal.fire(:"success.job.job.tengine", {
          :target_jobnet_id => parent.id,
          :target_job_id => self.id,
        })
    end
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_fail(signal)
    case self.phase_key
    when :ready, :success then
      raise Tengine::Job::Vertex::PhaseError, "ack not available on succeed"
    when :starting, :running, :dying, :stuck then
      self.phase_key = :error
      signal.fire(:"error.job.job.tengine", {
          :target_jobnet_id => parent.id,
          :target_job_id => self.id,
        })
    end
  end

end
