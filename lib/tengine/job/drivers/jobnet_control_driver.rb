# -*- coding: utf-8 -*-

# ジョブネット制御ドライバ
driver :jobnet_control_driver do

  on :'start.jobnet.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      signal.reset
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      signal.with_paths_backup do
        target_jobnet.activate(signal)
      end
    end
    signal.execution.save! if event[:root_jobnet_id] == event[:target_jobnet_id]
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'success.job.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      signal.reset
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
      signal.reset
      target_job = root_jobnet.vertex(event[:target_job_id])
      signal.with_paths_backup do
        edge = target_job.next_edges.first
        edge.close_followings
        edge.transmit(signal)
      end
      # target_jobnet = target_job.parent
      # target_jobnet.jobnet_fail(signal)
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'success.jobnet.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      signal.reset
      target_jobnet = root_jobnet.vertex(event[:target_jobnet_id])
      signal.with_paths_backup do
        case target_jobnet.jobnet_type_key
        when :finally then
          parent = target_jobnet.parent
          edge = parent.end_vertex.prev_edges.first
          (edge.closed? || edge.closing?) ?
            parent.fail(signal) :
            parent.succeed(signal)
        else
          if edge = (target_jobnet.next_edges || []).first
            edge.transmit(signal)
          else
            (target_jobnet.parent || signal.execution).succeed(signal)
          end
        end
      end
    end
    signal.execution.save! if event[:root_jobnet_id] == event[:target_jobnet_id]
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

  on :'error.jobnet.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      signal.reset
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      signal.with_paths_backup do
        case target_jobnet.jobnet_type_key
        when :finally then
          target_jobnet.parent.fail(signal)
        else
          if edge = (target_jobnet.next_edges || []).first
            edge.close_followings
            edge.transmit(signal)
          else
            (target_jobnet.parent || signal.execution).fail(signal)
          end
        end
      end
      # if target_parent = target_jobnet.parent
      #   target_parent.end_vertex.transmit(signal)
      # end
    end
    signal.execution.save! if event[:root_jobnet_id] == event[:target_jobnet_id]
    signal.reservations.each{|r| fire(*r.fire_args)}
  end


  on :'stop.jobnet.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    root_jobnet = Tengine::Job::RootJobnetActual.find(event[:root_jobnet_id])
    root_jobnet.update_with_lock do
      signal.reset
      target_jobnet = root_jobnet.find_descendant(event[:target_jobnet_id]) || root_jobnet
      target_jobnet.stop(signal)
    end
    signal.reservations.each{|r| fire(*r.fire_args)}
  end

end
