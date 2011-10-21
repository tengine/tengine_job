# -*- coding: utf-8 -*-

# ジョブ制御ドライバ
driver :job_control_driver do

  on :'start.job.tengine' do
    execution = Tengine::Job::Execution.find(event[:execution_id])
    signal = Tengine::Job::Signal.new(execution)
    # activate
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      target_job = target_jobnet.find_descendant(event[:target_job_id])
      signal.with_paths_backup do
        target_job.activate(signal) # transmitは既にされているはず。
      end
    end
    root_jobnet.reload # update_with_lockした内容があるのでリロードしないとlock_versionが食い違ってしまいます

    signal.reservations.each do |reservation|
      fire(*reservation.fire_args)
    end
  end

  on :'finished.process.job.tengine' do
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    # finish
    root_jobnet.update_with_lock do
      job = root_jobnet.find_descendant(event[:target_job_id])
      job.finish(event[:exit_status], event.occurred_at)
    end
    fire(:'finished.job.tengine', :properties => event.properties)
  end

end
