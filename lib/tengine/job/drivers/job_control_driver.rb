# -*- coding: utf-8 -*-

# ジョブ制御ドライバ
driver :job_control_driver do

  on :'start.job.tengine' do
    job = nil
    # activate
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_jobnet = root_jobnet.find_decendant(event[:target_jobnet_id])
      target_edge = target_jobnet.find_decendant_edge(event[:target_edge_id])
      job = target_edge.transmit
    end
    # run
    root_jobnet.update_with_lock do
      job.run
    end
  end

  on :'finished.process.job.tengine' do
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    # finish
    root_jobnet.update_with_lock do
      job = root_jobnet.find_decendant(event[:job_id])
      job.finish(event[:exit_code], event.occurred_at)
    end
  end

end
