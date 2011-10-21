# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tengine/rspec'

describe 'job_control_driver' do
  include Tengine::RSpec::Extension

  target_dsl File.expand_path("../../../../../lib/tengine/job/drivers/jobnet_control_driver.rb", File.dirname(__FILE__))
  driver :jobnet_control_driver

  # in [rjn0007]
  # (S1)--e1-->[j1000]--e2-->[j2000]--e3-->(E1)
  #
  # in [j1000]
  # (S2)--e4-->[j1100]--e5-->[j1200]--e6-->(E2)
  #
  # in [j1100]
  # (S3)--e7-->(j1110)--e8-->(E3)
  #
  # in [j1200]
  # (S4)--e9-->(j1210)--e10-->(E4)
  #
  # in [j1000:finally (=j1f00)]
  # (S5)--e11-->[j1f10]--e12-->(E5)
  #
  # in [j1f10]
  # (S6)--e13-->(j1f11)--e14-->(E6)
  #
  # in [j1000:finally:finally (=j1ff0)]
  # (S7)--e15-->(j1ff1)--e16-->(E7)
  #
  # in [j2000]
  # (S8)--e17-->(j2100)--e18-->(E8)
  #
  # in [jf000:finally (=jf000)]
  # (S9)--e19-->(jf100)--e20-->(E9)
  #
  context "rjn0007" do
    before do
      Tengine::Job::Vertex.delete_all
      builder = Rjn0007NestedAndFinallyBuilder.new
      @root = builder.create_actual
      @ctx = builder.context
      @execution = Tengine::Job::Execution.create!({
          :root_jobnet_id => @root.id,
        })
      @base_props = {
        :execution_id => @execution.id.to_s,
        :root_jobnet_id => @root.id.to_s,
        :target_jobnet_id => @root.id.to_s,
      }
    end

    context "j1100が終了して" do
      it "j1100が成功した場合、j1200を実行するイベントが発火される" do
        @root.phase_key = :running
        @ctx.vertex(:j1000).phase_key = :running
        @ctx.vertex(:j1100).phase_key = :success
        @ctx.vertex(:j1110).phase_key = :success
        @ctx.vertex(:j1200).phase_key = :ready
        @ctx.vertex(:j1000).finally_vertex.phase_key = :ready
        [:e1, :e4, :e7, :e8].each{|name| @ctx.edge(name).status_key = :transmitted}
        @root.save!
        tengine.should_fire(:"start.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1200].id.to_s,
          }))
        tengine.receive(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
          }))
        @root.reload
        [:e1, :e4, :e5, :e7, :e8].each{|name| @ctx.edge(name).status_key = :transmitted}
        [:e2, :e3, :e6          ].each{|name| @ctx.edge(name).status_key = :active     }
        @ctx.vertex(:j1100).phase_key.should == :success
        @ctx.vertex(:j1200).phase_key.should == :ready
        @ctx.vertex(:j1000).finally_vertex.phase_key.should == :ready
      end

      it "j1100が失敗した場合、j1200ではなく、j1f00が実行するイベントが発火される" do
        @root.phase_key = :running
        @ctx.vertex(:j1000).phase_key = :running
        @ctx.vertex(:j1100).phase_key = :error
        @ctx.vertex(:j1110).phase_key = :error
        @ctx.vertex(:j1200).phase_key = :ready
        @ctx.vertex(:j1000).finally_vertex.phase_key = :ready
        [:e1, :e4, :e7].each{ |name| @ctx.edge(name).status_key = :transmitted}
        [:e8          ].each{ |name| @ctx.edge(name).status_key = :closed     }
        [:e5, :e6     ].each{ |name| @ctx.edge(name).status_key = :active     }
        @root.save!
        tengine.should_fire(:"start.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1000].finally_vertex.id.to_s,
          }))
        tengine.receive(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1100].id.to_s,
          }))
        @root.reload
        [:e1, :e4, :e7].each{ |name| [name, @ctx.edge(name).status_key].should == [name, :transmitted]}
        [:e5, :e6, :e8].each{ |name| [name, @ctx.edge(name).status_key].should == [name, :closed     ]}
        [:e2, :e3     ].each{ |name| [name, @ctx.edge(name).status_key].should == [name, :active     ]}
        @ctx.vertex(:j1100).phase_key.should == :error
        @ctx.vertex(:j1200).phase_key.should == :ready
        @ctx.vertex(:j1000).finally_vertex.phase_key.should == :ready
      end
    end

    context "j1200が終了して、j1f00が実行される" do
      it "j1200が成功した場合、j1f00が実行するイベントが発火される" do
        @root.phase_key = :running
        @ctx.vertex(:j1000).phase_key = :running
        @ctx.vertex(:j1100).phase_key = :success
        @ctx.vertex(:j1110).phase_key = :success
        @ctx.vertex(:j1200).phase_key = :success
        @ctx.vertex(:j1210).phase_key = :success
        @ctx.vertex(:j1000).finally_vertex.phase_key = :ready
        [:e1, :e4, :e5, :e7, :e8, :e9, :e10].each{|name| @ctx.edge(name).status_key = :transmitted}
        [:e2, :e3, :e6,                    ].each{|name| @ctx.edge(name).status_key = :active     }
        @root.save!
        tengine.should_fire(:"start.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1000].finally_vertex.id.to_s,
          }))
        tengine.receive(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1200].id.to_s,
          }))
        @root.reload
        [:e1, :e4, :e5, :e6, :e7, :e8, :e9, :e10].each{|name| @ctx.edge(name).status_key = :transmitted}
        [:e2, :e3                               ].each{|name| @ctx.edge(name).status_key = :active     }
        @ctx.vertex(:j1100).phase_key.should == :success
        @ctx.vertex(:j1110).phase_key.should == :success
        @ctx.vertex(:j1200).phase_key.should == :success
        @ctx.vertex(:j1210).phase_key.should == :success
        @ctx.vertex(:j1000).finally_vertex.phase_key.should == :ready
      end

      it "j1200が失敗した場合、j1f00が実行するイベントが発火される" do
        @root.phase_key = :running
        @ctx.vertex(:j1000).phase_key = :running
        @ctx.vertex(:j1100).phase_key = :success
        @ctx.vertex(:j1110).phase_key = :success
        @ctx.vertex(:j1200).phase_key = :error
        @ctx.vertex(:j1210).phase_key = :error
        @ctx.vertex(:j1000).finally_vertex.phase_key = :ready
        [:e1, :e4, :e5, :e7, :e8, :e9].each{|name| @ctx.edge(name).status_key = :transmitted}
        [:e10                        ].each{|name| @ctx.edge(name).status_key = :closed     }
        @root.save!
        tengine.should_fire(:"start.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1000].finally_vertex.id.to_s,
          }))
        tengine.receive(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1200].id.to_s,
          }))
        @root.reload
        [:e1, :e4, :e5, :e7, :e8].each{|name| @ctx.edge(name).status_key = :transmitted}
        [:e6, :e10              ].each{|name| @ctx.edge(name).status_key = :closed     }
        [:e2, :e3               ].each{|name| @ctx.edge(name).status_key = :active     }
        @ctx.vertex(:j1100).phase_key.should == :success
        @ctx.vertex(:j1110).phase_key.should == :success
        @ctx.vertex(:j1200).phase_key.should == :error
        @ctx.vertex(:j1210).phase_key.should == :error
        @ctx.vertex(:j1000).finally_vertex.phase_key.should == :ready
      end
    end

    context "j1f00が終了" do
      before { pending }
      it "j1f00が成功した場合" do
        @root.phase_key = :running
        @ctx.vertex(:j1000).phase_key = :running
        @ctx.vertex(:j1100).phase_key = :success
        @ctx.vertex(:j1110).phase_key = :success
        @ctx.vertex(:j1200).phase_key = :success
        @ctx.vertex(:j1210).phase_key = :success
        @ctx.vertex(:j1000).finally_vertex.phase_key = :success
        @ctx.vertex(:j1000).finally_vertex.finally_vertex.phase_key = :success
        @ctx.vertex(:j1ff1).phase_key = :success
        [:e2, :e3, :e17, :e18, :e19, :e20].each{|name| @ctx.edge(name).status_key = :active     }
        [:e1, :e4, :e5, :e6, :e7, :e8, :e9, :e10, :e11, :e12, :e13, :e14, :e15, :e16].
          each{|name| @ctx.edge(name).status_key = :transmitted}
        @root.save!
        tengine.should_fire(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1000].id.to_s,
          }))
        tengine.receive(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx.vertex(:j1000).finally_vertex.id.to_s,
          }))
        @root.reload
        [:e2, :e3, :e17, :e18, :e19, :e20].each{|name| @ctx.edge(name).status_key.should == :active     }
        [:e1, :e4, :e5, :e6, :e7, :e8, :e9, :e10, :e11, :e12, :e13, :e14, :e15, :e16].
          each{|name| @ctx.edge(name).status_key.should == :transmitted}
        @ctx.vertex(:j1100).phase_key.should == :success
        @ctx.vertex(:j1110).phase_key.should == :success
        @ctx.vertex(:j1200).phase_key.should == :success
        @ctx.vertex(:j1210).phase_key.should == :success
        @ctx.vertex(:j1000).finally_vertex.phase_key.should == :success
        @ctx.vertex(:j2000).phase_key.should == :starting
      end

      it "j1f00が失敗した場合" do
        @root.phase_key = :running
        @ctx.vertex(:j1000).phase_key = :running
        @ctx.vertex(:j1100).phase_key = :success
        @ctx.vertex(:j1110).phase_key = :success
        @ctx.vertex(:j1200).phase_key = :success
        @ctx.vertex(:j1210).phase_key = :success
        @ctx.vertex(:j1000).finally_vertex.phase_key = :error
        @ctx.vertex(:j1000).finally_vertex.finally_vertex.phase_key = :error
        @ctx.vertex(:j1ff1).phase_key = :error
        [:e2, :e3, :e17, :e18, :e19, :e20].each{|name| @ctx.edge(name).status_key = :active     }
        [:e12, :e16].each{|name| @ctx.edge(name).status_key = :closed}
        [:e1, :e4, :e5, :e6, :e7, :e8, :e9, :e10, :e11, :e13, :e14, :e15].
          each{|name| @ctx.edge(name).status_key = :transmitted}
        @root.save!
        tengine.should_fire(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx[:j1000].id.to_s,
          }))
        tengine.receive(:"finished.jobnet.job.tengine", :properties => @base_props.merge({
            :target_jobnet_id => @ctx.vertex(:j1000).finally_vertex.id.to_s,
          }))
        @root.reload
        [:e2, :e3, :e17, :e18, :e19, :e20].each{|name| @ctx.edge(name).status_key.should == :active     }
        [:e12, :e16].each{|name| @ctx.edge(name).status_key.should == :closed}
        [:e1, :e4, :e5, :e6, :e7, :e8, :e9, :e10, :e11, :e13, :e14, :e15].
          each{|name| @ctx.edge(name).status_key.should == :transmitted}
        @ctx.vertex(:j1100).phase_key.should == :success
        @ctx.vertex(:j1110).phase_key.should == :success
        @ctx.vertex(:j1200).phase_key.should == :success
        @ctx.vertex(:j1210).phase_key.should == :success
        @ctx.vertex(:j1000).finally_vertex.phase_key.should == :success
        @ctx.vertex(:j1000).finally_vertex.finally_vertex.phase_key.should == :error
        @ctx.vertex(:j1ff1).phase_key.should == :error
        @ctx.vertex(:root).finally_vertex.phase_key.should == :starting
      end
    end

#     context "j1f00が終了して、上位のステータスが更新される" do
#       it "j1f10が成功した場合、j1ff0が実行される" do
#       end

#       it "j1f10が失敗した場合、j1ff0が実行される" do
#       end
#     end

#     context "j1f10が終了して、" do
#       it "j1f10が成功した場合、j1ff0が実行される" do
#       end

#       it "j1f10が失敗した場合、j1ff0が実行される" do
#       end
#     end

#     context "j1000が終了して、" do
#       it "j1000が成功した場合、j2000を実行するイベントが発火される" do
#       end

#       it "j1f10が失敗した場合、jf000を実行するイベントが発火される" do
#       end
#     end

  end



end
