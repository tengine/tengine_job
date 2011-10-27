# -*- coding: utf-8 -*-
require 'tengine/job/jobnet'

module Tengine::Job::Jobnet::JobStateTransition
  include Tengine::Job::Jobnet::StateTransition

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def job_transmit(signal)
    self.phase_key = :ready
    self.started_at = signal.event.occurred_at
    signal.fire(self, :"start.job.job.tengine", {
        :target_jobnet_id => parent.id,
        :target_job_id => self.id,
      })
  end
  available(:job_transmit, :on => :initialized,
    :ignored => [:ready, :starting, :running, :dying, :success, :error, :stuck])

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_activate(signal)
    complete_origin_edge(signal)
    self.phase_key = :starting
    self.started_at = signal.event.occurred_at
    parent.ack(signal)
    # 実際にSSHでスクリプトを実行
    run(signal.execution)
  end
  available(:job_activate, :on => :ready,
    :ignored => [:starting, :running, :dying, :success, :error, :stuck])

  # ハンドリングするドライバ: ジョブ制御ドライバ
  # スクリプトのプロセスのPIDを取得できたときに実行されます
  def job_ack(signal)
    self.phase_key = :running
  end
  available(:job_ack, :on => :starting,
    :ignored => [:running, :dying, :success, :error, :stuck])

  def job_finish(signal)
    self.exit_status = signal.event[:exit_status]
    self.finished_at = signal.event.occurred_at
    (self.exit_status.to_s == '0') ?
    job_succeed(signal) :
      job_fail(signal)
  end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_succeed(signal)
    self.phase_key = :success
    self.finished_at = signal.event.occurred_at
    signal.fire(self, :"success.job.job.tengine", {
        :exit_status => self.exit_status,
        :target_jobnet_id => parent.id,
        :target_job_id => self.id,
      })
  end
  available :job_succeed, :on => [:starting, :running, :dying, :stuck], :ignored => [:success]

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def job_fail(signal)
    self.phase_key = :error
    self.finished_at = signal.event.occurred_at
    signal.fire(self, :"error.job.job.tengine", {
        :exit_status => self.exit_status,
        :target_jobnet_id => parent.id,
        :target_job_id => self.id,
      })
  end
  available :job_fail, :on => [:starting, :running, :dying, :stuck], :ignored => [:error]

  def job_fire_stop(signal)
    return if self.phase_key == :initialized
    signal.fire(self, :"stop.job.job.tengine", {
        :target_jobnet_id => parent.id,
        :target_job_id => self.id,
      })
  end

  def job_stop(signal)
    self.phase_key = :dying
    self.stopped_at = signal.event.occurred_at
    self.stop_reason = signal.event[:stop_reason]
    kill(signal.execution)
  end
  available :job_stop, :on => [:ready, :starting, :running], :ignored => [:initialized, :dying, :success, :error, :stuck]

end
