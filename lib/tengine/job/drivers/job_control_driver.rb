# -*- coding: utf-8 -*-

# ジョブ制御ドライバ
driver :job_control_driver do

  on :'start.job.tengine' do
    execution = Tengine::Job::Execution.find(event[:execution_id])
    jobs = nil
    # activate
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      target_edge = target_jobnet.find_descendant_edge(event[:target_edge_id])
      target_edge ||= target_jobnet.start_vertex.next_edges.first
      jobs = target_edge.transmit
    end
    # run
    jobs.each do |job|
      root_jobnet.update_with_lock do
        job.run(execution)
      end
    end
  end

  on :'finished.process.job.tengine' do
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    # finish
    root_jobnet.update_with_lock do
      job = root_jobnet.find_descendant(event[:job_id])
      job.finish(event[:exit_code], event.occurred_at)
    end
  end

end
