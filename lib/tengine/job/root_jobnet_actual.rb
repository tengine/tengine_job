# -*- coding: utf-8 -*-
require 'tengine/job'

# 実行時のルートジョブネットを表すVertex
class Tengine::Job::RootJobnetActual < Tengine::Job::JobnetActual
  include Tengine::Job::Root

  belongs_to :template, :inverse_of => :root_jobnet_actuals, :index => true, :class_name => "Tengine::Job::RootJobnetTemplate"
  has_many :executions, :inverse_of => :root_jobnet, :class_name => "Tengine::Job::Execution"
end
