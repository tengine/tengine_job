# -*- coding: utf-8 -*-
include Tengine::Core::SafeUpdatable

# ジョブ起動ドライバ
driver :job_execution_driver do

  on :'start.execution.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    execution = signal.execution
    root_jobnet = execution.root_jobnet
    root_jobnet.update_with_lock do
      signal.reset
      execution.transmit(signal)
    end
    execution.safely(safemode(Tengine::Job::Execution.collection)).save!
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'stop.execution.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    execution = signal.execution
    root_jobnet = execution.root_jobnet
    root_jobnet.update_with_lock do
      signal.reset
      execution.stop(signal)
    end
    execution.safely(safemode(Tengine::Job::Execution.collection)).save!
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

end
