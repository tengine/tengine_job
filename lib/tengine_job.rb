require 'tengine_core'

module Tengine
  autoload :Job, "tengine/job"
end

Tengine.dsl_loader_modules << Tengine::Job::DslLoader
