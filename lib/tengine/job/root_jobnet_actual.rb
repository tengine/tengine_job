# -*- coding: utf-8 -*-
require 'tengine/job'

# 実行時のルートジョブネットを表すVertex
class Tengine::Job::RootJobnetActual < Tengine::Job::JobnetActual
  include Tengine::Job::Root

  belongs_to :template, :inverse_of => :root_jobnet_actuals, :index => true, :class_name => "Tengine::Job::RootJobnetTemplate"
  has_many :executions, :inverse_of => :root_jobnet, :class_name => "Tengine::Job::Execution"


  def rerun(*args)
    options = args.extract_options!
    result = Tengine::Job::Execution.create!(:retry => true, :spot => !!options[:spot],
      :root_jobnet_id => self.id,
      :target_actual_ids => args.flatten
      )
    sender = options[:sender] || Tengine::Event.default_sender
    sender.wait_for_connection do
      sender.fire(:'start.execution.job.tengine', :properties => {
          :execution_id => result.id.to_s
        })
    end
    result
  end
end
