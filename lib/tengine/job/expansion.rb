# -*- coding: utf-8 -*-
require 'tengine/job'

# ルートジョブネットを他のジョブネット内に展開するための特殊なテンプレート用Vertex。
class Tengine::Job::Expansion < Tengine::Job::Job
  def actual_class
    Tengine::Job::JobnetActual
  end
  def root_jobnet_template
    @root_jobnet_template ||= Tengine::Job::RootJobnetTemplate.by_name(name)
  end

  def generating_children; root_jobnet_template.children; end
  def generating_edges; root_jobnet_template.edges; end

  def generate(klass = actual_class)
    result = super
    result.was_expansion = true
    result
  end
end
