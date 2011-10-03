# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブとして実際にスクリプトをに関するVertex。
# 実際に実行するのは Tengine::Job::ScriptActual、
# そのテンプレートは、Tengine::Job::ScriptTemplate
class Tengine::Job::Script < Tengine::Job::Job

  field :script, :type => String # 実行するスクリプトのパス
end
