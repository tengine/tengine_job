require 'tengine/job'

module Tengine::Job::NamePath

  NAME_PATH_SEPARATOR = '/'.freeze

  def name_path
    name = respond_to?(:name) ? self.name : self.class.name.split('::').last.underscore
    parent ? "#{parent.name_path}#{NAME_PATH_SEPARATOR}#{name}" :
      "#{NAME_PATH_SEPARATOR}#{name}"
  end

end
