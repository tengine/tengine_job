# -*- coding: utf-8 -*-
# 以下のジョブネットについてテンプレートジョブネットや
# 実行用ジョブネットを扱うフィクスチャ生成のためのクラスです。
#
# in [j10]
# [S] --e1-->[j11]--e2-->[E]

class Rjn0001SimpleJobnetBuilder < JobnetFixtureBuilder
  DSL = <<-EOS
    jobnet("rjn0001") do
      job("j11", "$HOME/j11.sh")
    end
  EOS

  def create(options = {})
    resource_fixture = GokuAtEc2ApNortheast.new
    resource_fixture.goku_ssh_pw
    resource_fixture.hadoop_master_node

    root = new_root_jobnet("rjn0001", options)
    root.children << new_script("j11", :script => "$HOME/j11.sh",
      :server_name => "hadoop_master_node", :credential_name => "goku_ssh_pw")
    root.prepare_end
    root.build_sequencial_edges
    root.save!
    self[:S1] = root.children[0]
    self[:E1] = root.children[2]
    self[:e1] = root.edges[0]
    self[:e2] = root.edges[1]
    root
  end
end
