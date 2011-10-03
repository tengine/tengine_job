# -*- coding: utf-8 -*-
require 'tengine/job'

# DSLを評価して登録されるルートジョブネットを表すVertex
class Tengine::Job::RootJobnetTemplate < Tengine::Job::JobnetTemplate
  include Tengine::Job::Root

  field :dsl_filepath, :type => String  # ルートジョブネットを定義した際にロードされたDSLのファイル名(Tengine::Core::Config#dsl_dir_pathからの相対パス)
  field :dsl_lineno  , :type => Integer # ルートジョブネットを定義するjobnetメソッドの呼び出しの、ロードされたDSLのファイルでの行番号
  field :dsl_version , :type => String  # ルートジョブネットを定義した際のDSLのバージョン
end
