# -*- coding: utf-8 -*-
require 'tengine/job'

# テンプレートから生成された実行時に使用されるジョブネットを表すVertex。
class Tengine::Job::JobnetActual < Tengine::Job::Jobnet
  include Tengine::Job::ScriptExecutable
  include Tengine::Job::Executable
  include Tengine::Job::Stoppable
  include Tengine::Job::Jobnet::JobStateTransition
  include Tengine::Job::Jobnet::JobnetStateTransition

  field :was_expansion, :type => Boolean # テンプレートがTenigne::Job::Expansionであった場合にtrueです。
end
