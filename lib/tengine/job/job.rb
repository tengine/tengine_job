# -*- coding: utf-8 -*-
require 'tengine/job'

# 処理を意味するVertex。実際に実行を行うTengine::Job::Scriptやジョブネットである
# Tengine::Job::Jobnetの継承元である。
class Tengine::Job::Job < Tengine::Job::Vertex
  include Tengine::Job::Connectable
  include Tengine::Job::Killing

  field :name, :type => String # ジョブの名称。

  # リソース識別子を返します
  def name_as_resource
    @name_as_resource ||= "job:#{Tengine::Event.host_name}/#{Process.pid.to_s}/#{root.id.to_s}/#{id.to_s}"
  end

  def short_inspect
    "#<%%%-30s id: %s name: %s>" % [self.class.name, self.id.to_s, name]
  end

end

