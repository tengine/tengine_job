# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブDSLで定義されるジョブネットを表すVertex。
class Tengine::Job::JobnetTemplate < Tengine::Job::Jobnet

  def actual_class
    Tengine::Job::JobnetActual
  end
end
