require 'tengine_core'

module Tengine
  autoload :Job, "tengine/job"
end

Tengine.plugins.add(Tengine::Job)
