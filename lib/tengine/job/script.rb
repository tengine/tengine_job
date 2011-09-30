require 'tengine/job'

class Tengine::Job::Script < Tengine::Job::Job
  field :script, :type => String
end
