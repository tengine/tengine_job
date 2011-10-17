# -*- coding: utf-8 -*-
require 'spec_helper'
require 'tmpdir'
require 'fileutils'

describe Tengine::Job::Category do

  describe :update_for do

    context "RootJobnetTemplateのdsl_filepathからCategoryを登録します" do

      before do
        Tengine::Job::Vertex.delete_all
        Tengine::Job::Category.delete_all
        @root1 = Tengine::Job::RootJobnetTemplate.create!({
            :name => "root_jobnet_template01",
            :dsl_filepath => "foo/bar1/jobnet01.rb",
            :dsl_lineno => 4,
            :dsl_version => "1"
          })
        @root2 = Tengine::Job::RootJobnetTemplate.create!({
            :name => "root_jobnet_template01",
            :dsl_filepath => "foo/bar2/jobnet01.rb",
            :dsl_lineno => 4,
            :dsl_version => "2"
          })
        @root3 = Tengine::Job::RootJobnetTemplate.create!({
            :name => "root_jobnet_template01",
            :dsl_filepath => "foo/bar3/jobnet2.rb",
            :dsl_lineno => 4,
            :dsl_version => "2"
          })
        @base_dir = Dir.tmpdir
        FileUtils.mkdir_p(File.expand_path("foo/bar2", @base_dir))
        FileUtils.mkdir_p(File.expand_path("foo/bar3", @base_dir))
        File.open(File.expand_path("dictionary.yml", @base_dir), "w"){|f| YAML.dump({"foo" => "ほげ"}, f)}
        File.open(File.expand_path("foo/dictionary.yml", @base_dir), "w"){|f|
          YAML.dump({"bar1" => "ばー1", "bar2" => "ばー2"}, f)}
      end

      context "指定されたバージョンのRootJobneTTemplateからカテゴリを生成します" do
        it "バージョンが1の場合" do
          expect{
            Tengine::Job::Category.update_for("1", @base_dir)
          }.to change(Tengine::Job::Category, :count).by(2)
          foo = Tengine::Job::Category.first(:conditions => {:parent_id => nil})
          foo.name.should == "foo"
          foo.caption.should == "ほげ"
          foo.should_not be_nil
          foo.children.count.should == 1
          foo.children.first.tap do |c|
            c.name.should == "bar1"
            c.caption.should == "ばー1"
            c.parent_id.should == foo.id
            c.dsl_version.should == "1"
            @root1.reload
            @root1.category_id.should == c.id
          end
        end

        it "バージョンが2の場合" do
          expect{
            Tengine::Job::Category.update_for("2", @base_dir)
          }.to change(Tengine::Job::Category, :count).by(3)
          foo = Tengine::Job::Category.first(:conditions => {:parent_id => nil})
          foo.name.should == "foo"
          foo.caption.should == "ほげ"
          foo.should_not be_nil
          foo.children.count.should == 2
          foo.children.first.tap do |c|
            c.name.should == "bar2"
            c.caption.should == "ばー2"
            c.parent_id.should == foo.id
            c.dsl_version.should == "2"
            @root2.reload
            @root2.category_id.should == c.id
          end
          foo.children.last.tap do |c|
            c.name.should == "bar3"
            c.caption.should == "bar3"
            c.parent_id.should == foo.id
            c.dsl_version.should == "2"
            @root3.reload
            @root3.category_id.should == c.id
          end
        end
      end

      it "Tengine::Job.notifyでジョブDSLのロード終了を通知された場合" do
        mock_config = mock(:config)
        mock_config.should_receive(:dsl_version).and_return("2")
        mock_config.should_receive(:dsl_dir_path).and_return(@base_dir)
        mock_sender = mock(:sender)
        mock_sender.should_receive(:respond_to?).with(:config).and_return(true)
        mock_sender.should_receive(:config).twice.and_return(mock_config)
        expect{
          Tengine::Job.notify(mock_sender, :after_load_dsl)
        }.to change(Tengine::Job::Category, :count).by(3)
        foo = Tengine::Job::Category.first(:conditions => {:parent_id => nil})
        foo.name.should == "foo"
        foo.caption.should == "ほげ"
        foo.should_not be_nil
        foo.children.count.should == 2
        foo.children.first.tap do |c|
          c.name.should == "bar2"
          c.caption.should == "ばー2"
          c.parent_id.should == foo.id
          c.dsl_version.should == "2"
          @root2.reload
          @root2.category_id.should == c.id
        end
        foo.children.last.tap do |c|
          c.name.should == "bar3"
          c.caption.should == "bar3"
          c.parent_id.should == foo.id
          c.dsl_version.should == "2"
          @root3.reload
          @root3.category_id.should == c.id
        end
      end

    end

  end

end
