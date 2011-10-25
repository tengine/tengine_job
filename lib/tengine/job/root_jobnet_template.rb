# -*- coding: utf-8 -*-
require 'tengine/job'

# DSLを評価して登録されるルートジョブネットを表すVertex
class Tengine::Job::RootJobnetTemplate < Tengine::Job::JobnetTemplate
  include Tengine::Job::Root

  field :dsl_filepath, :type => String  # ルートジョブネットを定義した際にロードされたDSLのファイル名(Tengine::Core::Config#dsl_dir_pathからの相対パス)
  field :dsl_lineno  , :type => Integer # ルートジョブネットを定義するjobnetメソッドの呼び出しの、ロードされたDSLのファイルでの行番号
  field :dsl_version , :type => String  # ルートジョブネットを定義した際のDSLのバージョン

  def actual_class
    Tengine::Job::RootJobnetActual
  end
  def generate(klass = actual_class)
    result = super(klass)
    result.template = self
    result
  end

  def execute(options = {})
    event_sender = options.delete(:sender) || self
    actual = generate
    result = Tengine::Job::Execution.create!(
      (options || {}).update(:root_jobnet => actual)
      )
    event_sender.fire(:"start.execution.job.tengine", :properties => {
        :execution_id => result.id,
        :root_jobnet_id => actual.id,
        :target_jobnet_id => actual.id
      })
    result
  end

end
