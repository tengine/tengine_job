# -*- coding: utf-8 -*-
require 'tengine/job/jobnet'

module Tengine::Job::Jobnet::RubyJobStateTransition
  include Tengine::Job::Jobnet::StateTransition

  # ハンドリングするドライバ: ジョブネット制御ドライバ
  def ruby_job_transmit(signal)
    self.phase_key = :ready
    self.started_at = signal.event.occurred_at
    signal.fire(self, :"start.job.job.tengine", {
        :target_jobnet_id => parent.id,
        :target_jobnet_name_path => parent.name_path,
        :target_job_id => self.id,
        :target_job_name_path => self.name_path,
      })
  end
  available(:ruby_job_transmit, :on => :initialized,
    :ignored => [:ready, :running, :success, :error, :stuck])

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def ruby_job_activate(signal)
    case phase_key
    when :ready then
      complete_origin_edge(signal)
      self.phase_key = :running
      self.started_at = signal.event.occurred_at
      execution = signal.execution
      if execution.retry
        if execution.target_actual_ids.include?(self.id.to_s)
          execution.ack(signal)
        elsif execution.target_actuals.map{|t| t.parent.id.to_s if t.parent }.include?(self.parent.id.to_s)
          # 自身とTengine::Job::Execution#target_actual_idsに含まれるジョブ／ジョブネットと親が同じならば、ackしない
        else
          parent.ack(signal)
        end
      else
        parent.ack(signal) # 再実行でない場合
      end
      # このコールバックはjob_control_driverでupdate_with_lockの外側から
      # 再度呼び出してもらうためにcallbackを設定しています
      signal.callback = lambda{ root.vertex(self.id).activate(signal) }
    when :running then
      signal.callback = lambda do
        ruby_job_block = template_block_for(:ruby_job)
        begin
          ruby_job_block.call
          ruby_job_succeed(signal)
        rescue Exception => e
          ruby_job_fail(signal, :message => "[#{e.class.name}] #{e.message}\n  " << e.backtrace.join("\n  "))
        end
      end
    end
  end
  available(:ruby_job_activate, :on => [:ready, :running],
    :ignored => [:dying, :success, :error, :stuck])

  # ハンドリングするドライバ: ジョブ制御ドライバ
  # スクリプトのプロセスのPIDを取得できたときに実行されます
  def ruby_job_ack(signal)
    raise Tengine::Job::Executable::PhaseError, "\#{name_path} \#{self.class.name}##{method_name} not available for ruby_job"
  end

  # 使用されないはずなのでコメントアウト
  # def ruby_job_finish(signal)
  # end

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def ruby_job_succeed(signal)
    self.phase_key = :success
    self.finished_at = signal.event.occurred_at
    signal.fire(self, :"success.job.job.tengine", {
        :target_jobnet_id => parent.id,
        :target_jobnet_name_path => parent.name_path,
        :target_job_id => self.id,
        :target_job_name_path => self.name_path,
      })
  end
  available :ruby_job_succeed, :on => [:starting, :running, :dying, :stuck], :ignored => [:success]

  # ハンドリングするドライバ: ジョブ制御ドライバ
  def ruby_job_fail(signal, options = nil)
    self.phase_key = :error
    if msg = signal.event[:message]
      self.error_messages ||= []
      self.error_messages += [msg]
    end
    if options && (msg = options[:message])
      self.error_messages ||= []
      self.error_messages += [msg]
    end
    self.finished_at = signal.event.occurred_at
    event_options = {
      :target_jobnet_id => parent.id,
      :target_jobnet_name_path => parent.name_path,
      :target_job_id => self.id,
      :target_job_name_path => self.name_path,
    }
    event_options.update(options) if options
    signal.fire(self, :"error.job.job.tengine", event_options)
  end
  available :ruby_job_fail, :on => [:starting, :running, :dying, :stuck], :ignored => [:error]

  def ruby_job_fire_stop(signal)
    signal.fire(self, :"stop.job.job.tengine", {
        :stop_reason => signal.event[:stop_reason],
        :target_jobnet_id => parent.id,
        :target_jobnet_name_path => parent.name_path,
        :target_job_id => self.id,
        :target_job_name_path => self.name_path,
      })
  end
  available :ruby_job_fire_stop, :on => [:ready], :ignored => [:initialized, :dying, :running, :success, :error, :stuck]

  def ruby_job_stop(signal, &block)
    case phase_key
    when :ready then
      self.phase_key = :initialized
      self.stopped_at = signal.event.occurred_at
      self.stop_reason = signal.event[:stop_reason]
      next_edges.first.transmit(signal)
    end
  end
  available :ruby_job_stop, :on => [:ready], :ignored => [:initialized, :running, :dying, :success, :error, :stuck]

  def ruby_job_reset(signal, &block)
    self.phase_key = :initialized
    if signal.execution.in_scope?(self)
      next_edges.first.reset(signal)
    end
  end
  available :ruby_job_reset, :on => [:initialized, :success, :error, :stuck]

end
