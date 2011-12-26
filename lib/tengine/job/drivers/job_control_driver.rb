# -*- coding: utf-8 -*-

# ジョブ制御ドライバ
driver :job_control_driver do

  on :'start.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    # activate
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      signal.reset
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      target_job = target_jobnet.find_descendant(event[:target_job_id])
      signal.with_paths_backup do
        target_job.activate(signal) # transmitは既にされているはず。
      end
    end
    root_jobnet.reload
    if signal.callback
      block = signal.callback
      signal.callback = nil
      block.call
    end
    if signal.callback
      root_jobnet.update_with_lock(&signal.callback)
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'stop.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      signal.reset
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
      signal.reset
      job = root_jobnet.find_descendant(event[:target_job_id])
      job.finish(signal)
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'expired.job.heartbeat.tengine' do
    event.tap do |e|
      Tengine::Job::RootJobnetActual.find(e[:root_jobnet_id]).tap do |r|
        r.update_with_lock do
          r.find_descendant(e[:target_job_id]).phase_key = :stuck
        end
      end
    end
  end

  on :'restart.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      signal.reset
      job = root_jobnet.find_descendant(event[:target_job_id])
      job.reset(signal)
      job.transmit(signal)
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

end
