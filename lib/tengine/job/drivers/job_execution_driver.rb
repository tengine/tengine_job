# -*- coding: utf-8 -*-

# ジョブ起動ドライバ
driver :job_execution_driver do

  on :'start.execution.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    execution = signal.execution
    template = execution.root_jobnet_template
    unless execution.root_jobnet_actual_id
      root_jobnet = template.generate
      root_jobnet.save!
      execution.root_jobnet_actual_id = root_jobnet.id
      execution.save!
    end
    root_jobnet.update_with_lock do
      signal.reset
      execution.transmit(signal)
    end
    execution.save!
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'stop.execution.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    execution = signal.execution
    root_jobnet = execution.root_jobnet_actual
    root_jobnet.update_with_lock do
      signal.reset
      execution.stop(signal)
    end
    execution.save!
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

end
