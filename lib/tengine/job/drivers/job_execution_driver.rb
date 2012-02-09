# -*- coding: utf-8 -*-

ack_policy :after_all_handler_submit, :'start.execution.job.tengine'
ack_policy :after_all_handler_submit, :'stop.execution.job.tengine'

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
    execution.save!
    signal.reservations.each{|r| fire(*r.fire_args)}
    submit
  end

  on :'start.execution.job.tengine.failed.tengined' do
    # このイベントは壊れていたからfailedなのかもしれない。多重送信によ
    # りfailedなのかもしれない。あまりへんな仮定を置かない方が良い。
    e = event
    if f = e.properties
      if g = f["original_event"]
        if h = g["properties"]
          if i = h["execution_id"]
            if j = Tengine::Job::Execution.find(i)
              j.update_attributes :phase_key => :stuck
            end
          end
        end
      end
    end
  end

  on :'stop.execution.job.tengine' do
    signal = Tengine::Job::Signal.new(event)
    execution = signal.execution
    root_jobnet = execution.root_jobnet
    root_jobnet.update_with_lock do
      signal.reset
      execution.stop(signal)
    end
    execution.save!
    signal.reservations.each{|r| fire(*r.fire_args)}
    submit
  end

  on :'stop.execution.job.tengine.error.tengined' do
    # このイベントは壊れていたからfailedなのかもしれない。多重送信によ
    # りfailedなのかもしれない。あまりへんな仮定を置かない方が良い。
    e = event
    if f = e.properties
      if g = f["original_event"]
        if h = g["properties"]
          if i = h["execution_id"]
            if j = Tengine::Job::Execution.find(i)
              j.update_attributes :phase_key => :stuck
            end
          end
        end
      end
    end
  end
end
