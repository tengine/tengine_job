# -*- coding: utf-8 -*-

# ジョブネット制御ドライバ
driver :jobnet_control_driver do

  on :'start.jobnet.job.tengine' do
    execution = Tengine::Job::Execution.find(event[:execution_id])
    signal = Tengine::Job::Signal.new(execution)
    # activate
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      signal.with_paths_backup do
        target_jobnet.transmit(signal)
      end
    end
    signal.reservations.each do |reservation|
      fire(*reservation.fire_args)
    end
  end

  on :'finished.job.job.tengine' do
  end

  on :'finished.jobnet.job.tengine' do
  end

end
