# -*- coding: utf-8 -*-
require 'tengine/job'

class Tengine::Job::Category
  include Mongoid::Document
  field :dsl_version, :type => String # DSLをロードしたときのバージョン。Tengine::Core::Config#dsl_version が設定されます。
  field :name       , :type => String # カテゴリ名。ディレクトリ名を元に設定されるので、"/"などは使用不可。
  field :caption    , :type => String # カテゴリの表示名。各ディレクトリ名に対応する表示名。通常dictionary.ymlに定義する。

  with_options(:class_name => "Tengine::Job::Category") do |c|
    c.belongs_to :parent, :inverse_of => :children, :index => true
    c.has_many   :children, :inverse_of => :parent, :order => [:name, :asc]
  end

  class << self
    def update_for(dsl_version, base_dir)
      root_jobnets = Tengine::Job::RootJobnetTemplate.all(:conditions => {:dsl_version => dsl_version})
      root_jobnets.each do |root_jobnet|
        dirs = File.dirname(root_jobnet.dsl_filepath || "").split('/')
        parent_category = nil
        dic_dir = base_dir
        dirs.each do |dir|
          caption = nil
          dic_path = File.expand_path("dictionary.yml", dic_dir)
          if File.exist?(dic_path)
            # TODO dictionary.yml が不正な形の場合の処理が必要
            hash = YAML.load_file(dic_path)
            caption = hash[dir]
          end
          category = Tengine::Job::Category.find_or_create_by(
            :name => dir,
            :caption => caption || dir,
            :parent_id => parent_category ? parent_category.id : nil,
            :dsl_version => dsl_version)
          dic_dir = File.join(dic_dir, dir)
          parent_category = category
        end
      end

    end
  end

end
