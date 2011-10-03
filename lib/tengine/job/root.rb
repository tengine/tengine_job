require 'tengine/job'

module Tengine::Job::Root
  extend ActiveSupport::Concern

  included do
    belongs_to :category, :inverse_of => :root_jobnet_templates, :index => true, :class_name => "Tengine::Job::Category"
    field :lock_version, :type => Integer, :default => 0
  end
end
