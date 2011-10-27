# -*- coding: utf-8 -*-
require 'tengine/job/jobnet'

module Tengine::Job::Jobnet::JobStateTransition

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def job_transmit(signal)
    case self.phase_key
    when :initialized then
      self.phase_key = :ready
      self.started_at = signal.event.occurred_at
      signal.fire(self, :"start.job.job.tengine", {
          :target_jobnet_id => parent.id,
          :target_job_id => self.id,
        })
    end
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_activate(signal)
    case self.phase_key
    when :ready then
      complete_origin_edge(signal)
      self.phase_key = :starting
      self.started_at = signal.event.occurred_at
      parent.ack(signal)
      # 実際にSSHでスクリプトを実行
      execute(signal.execution)
    when :initialized then
      raise Tengine::Job::Executable::PhaseError, "activate not available on #{phase_key.inspect}"
    end
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  # スクリプトのプロセスのPIDを取得できたときに実行されます
  def job_ack(signal)
    case self.phase_key
    when :starting then
      self.phase_key = :running
    when :initialized, :ready then
      raise Tengine::Job::Executable::PhaseError, "ack not available on #{phase_key.inspect}"
    end
  end

  def job_finish(signal)
    self.exit_status = signal.event[:exit_status]
    self.finished_at = signal.event.occurred_at
    (self.exit_status.to_s == '0') ?
      job_succeed(signal) :
      job_fail(signal)
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_succeed(signal)
    case self.phase_key
    when :ready, :error then
      raise Tengine::Job::Executable::PhaseError, "succeed not available on succeed"
    when :starting, :running, :dying, :stuck then
      self.phase_key = :success
      self.finished_at = signal.event.occurred_at
      signal.fire(self, :"success.job.job.tengine", {
          :exit_status => self.exit_status,
          :target_jobnet_id => parent.id,
          :target_job_id => self.id,
        })
    end
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_fail(signal)
    case self.phase_key
    when :ready, :success then
      raise Tengine::Job::Executable::PhaseError, "fail not available on succeed"
    when :starting, :running, :dying, :stuck then
      self.phase_key = :error
      self.finished_at = signal.event.occurred_at
      signal.fire(self, :"error.job.job.tengine", {
          :exit_status => self.exit_status,
          :target_jobnet_id => parent.id,
          :target_job_id => self.id,
        })
    end
  end

end
