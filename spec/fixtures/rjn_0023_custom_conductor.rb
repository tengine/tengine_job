# -*- coding: utf-8 -*-
# 以下のジョブネットについてテンプレートジョブネットや
# 実行用ジョブネットを扱うフィクスチャ生成のためのクラスです。
#
# in [rjn0023]
# (S1)--e1-->(j1)--e2-->(E1)


module Rjn0023
  class << self
    attr_accessor :exception_class_name
    def raise_test_exception
      return unless exception_class_name
      raise exception_class_name.constantize
    end
  end
end

class Rjn0023CustomConductor < JobnetFixtureBuilder

  DSL = <<-EOS
    # エラーとして扱う例外をカスタマイズ
    custom_conductor = lambda do |job|
      begin
        job.run
      rescue SystemCallError, NoMemoryError, SecurityError => e
        raise # tenginedに例外処理を任せる
      rescue => e
        job.fail(:exception => e)
      else
        job.succeed
      end
    end

    jobnet("rjn0023", :conductor => custom_conductor) do
      ruby_job('j1'){ Rjn0023.raise_test_exception  }
    end
  EOS

  def create(options = {})
    root = new_root_jobnet("rjn0023", options)
    root.children << new_start
    root.children << new_ruby_job("j1"){ Rjn0023.raise_test_exception }
    root.children << new_end
    root.edges << new_edge(:S1, :j1)
    root.edges << new_edge(:j1, :E1)
    root.save!
    Tengine::Job::DslLoader.update_loaded_blocks(root)
    root
  end
end
