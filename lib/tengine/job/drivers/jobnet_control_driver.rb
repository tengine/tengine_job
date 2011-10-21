# -*- coding: utf-8 -*-

# ジョブネット制御ドライバ
driver :jobnet_control_driver do

  on :'start.jobnet.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      signal.with_paths_backup do
        target_jobnet.transmit(signal)
      end
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'success.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_job = root_jobnet.find_descendant(event[:target_job_id])
      signal.with_paths_backup do
        edge = target_job.next_edges.first
        edge.transmit(signal)
      end
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'error.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_job = root_jobnet.find_descendant(event[:target_job_id])
      signal.with_paths_backup do
        edge = target_job.next_edges.first
        edge.close_followings
      end
      target_jobnet = target_job.parent
      target_jobnet.jobnet_fail(signal)
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'success.jobnet.job.tengine' do
  end

  on :'error.jobnet.job.tengine' do
  end

end
