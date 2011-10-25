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
    actual = generate
    Tengine::Job::Execution.create!(
      (options || {}).update(:root_jobnet => actual)
      )
  end

end
