# -*- coding: utf-8 -*-

# ジョブ制御ドライバ
driver :job_control_driver do

  on :'start.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    # activate
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      target_job = target_jobnet.find_descendant(event[:target_job_id])
      signal.with_paths_backup do
        target_job.activate(signal) # transmitは既にされているはず。
      end
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'stop.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      target_job = target_jobnet.find_descendant(event[:target_job_id])
      signal.with_paths_backup do
        target_job.stop(signal)
      end
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'finished.process.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    # finish
    root_jobnet.update_with_lock do
      job = root_jobnet.find_descendant(event[:target_job_id])
      job.finish(signal)
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'restart.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      job = root_jobnet.find_descendant(event[:target_job_id])
      job.reset(signal)
      job.transmit(signal)
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

end
