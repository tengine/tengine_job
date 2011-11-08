# -*- coding: utf-8 -*-

# スケジュール管理ドライバ
driver :schedule_driver do

  on :'start.execution.job.tengine' do
    exec = Tengine::Job::Signal.new(event).execution
    name = exec.name_as_resource
    status = Tengine::Core::Schedule::SCHEDULED
    if exec.actual_base_timeout_alert
      t1 = Time.now + (exec.actual_base_timeout_alert * 60.0)
      Tengine::Core::Schedule.create event_type_name: "alert.execution.job.tengine", scheduled_at: t1, source_name: name, status: status
    end
    if exec.actual_base_timeout_termination
      t2 = Time.now + (exec.actual_base_timeout_termination * 60.0)
      Tengine::Core::Schedule.create event_type_name: "stop.execution.job.tengine", scheduled_at: t2, source_name: name, status: status
    end
  end

  on :'success.execution.job.tengine' do
    name = Tengine::Job::Signal.new(event).execution.name_as_resource
    Tengine::Core::Schedule.where(source_name: name, status: Tengine::Core::Schedule::SCHEDULED).update_all(status: Tengine::Core::Schedule::INVALID)
  end

  on :'error.execution.job.tengine' do
    name = Tengine::Job::Signal.new(event).execution.name_as_resource
    Tengine::Core::Schedule.where(source_name: name, status: Tengine::Core::Schedule::SCHEDULED).update_all(status: Tengine::Core::Schedule::INVALID)
  end

end
