# -*- coding: utf-8 -*-

# ジョブ起動ドライバ
driver :job_execution_driver do

  on :'start.execution.job.tengine' do

Tengine.logger.info("job_execution_driver  start.execution.job.tengine event:\n" << event.inspect)

    signal = Tengine::Job::Signal.new(event)
    execution = signal.execution
    root_jobnet = execution.root_jobnet
    root_jobnet.update_with_lock do
      execution.transmit(signal)
    end
    execution.save!
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

end
