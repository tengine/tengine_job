# -*- coding: utf-8 -*-
require 'tengine/job'

# ジョブDSLをロードする際に使用される語彙に関するメソッドを定義するモジュール
module Tengine::Job::DslLoader
  include Tengine::Job::DslEvaluator

  def jobnet(name, *args, &block)
    options = args.extract_options!
    options = {
      :name => name,
      :description => args.first || name,
    }.update(options)
    auto_sequence = options.delete(:auto_sequence)
    result = __with_redirection__(options) do
      if @jobnet.nil?
        klass = Tengine::Job::RootJobnetTemplate
        options[:dsl_version] = config.dsl_version
        path, lineno = *block.source_location
        options[:dsl_filepath] = config.relative_path_from_dsl_dir(path)
        options[:dsl_lineno] = lineno.to_i
      else
        klass = Tengine::Job::JobnetTemplate
      end
      klass.new(options)
    end
    @jobnet.children << result if @jobnet
    __stack_instance_variable__(:@auto_sequence,  auto_sequence || @auto_sequence) do
      __stack_instance_variable__(:@redirections,  []) do
        __stack_instance_variable__(:@jobnet, result, &block)
        result.build_edges(@auto_sequence, @boot_job_names, @redirections)
      end
    end
    result.save! if result.parent.nil?
    result
  end

  def auto_sequence
    @auto_sequence = true
  end

  def boot_jobs(*boot_job_names)
    @auto_sequence = false
    @boot_job_names = boot_job_names
  end

  def job(name, *args)
    script, description, options = __parse_job_args__(name, args)
    options = {
      :name => name,
      :description => description,
      :script => script
    }.update(options)
    result = __with_redirection__(options) do
      Tengine::Job::ScriptTemplate.new(options)
    end
    @jobnet.children << result
    result
  end

  def hadoop_job_run(name, *args, &block)
    script, description, options = __parse_job_args__(name, args)
    options[:script] = script
    options[:jobnet_type_key] = :hadoop_job_run
    jobnet(name, description, options, &block)
  end

  def hadoop_job(name, options = {})
    result = __with_redirection__(options) do
      Tengine::Job::JobnetTemplate.new(:name => name, :jobnet_type_key => :hadoop_job)
    end
    # result.children << start  = Tengine::Job::Start.new # 生成時に自動的に追加されます
    start = result.children.first
    result.children << fork   = Tengine::Job::Fork.new
    result.children << map    = Tengine::Job::JobnetTemplate.new(:name => "Map"   , :jobnet_type_key => :map_phase   )
    result.children << reduce = Tengine::Job::JobnetTemplate.new(:name => "Reduce", :jobnet_type_key => :reduce_phase)
    result.children << join   = Tengine::Job::Join.new
    result.children << _end   = Tengine::Job::End.new
    result.edges.new(:origin_id => start.id , :destination_id => fork.id  )
    result.edges.new(:origin_id => fork.id  , :destination_id => map.id   )
    result.edges.new(:origin_id => fork.id  , :destination_id => reduce.id)
    result.edges.new(:origin_id => map.id   , :destination_id => join.id  )
    result.edges.new(:origin_id => reduce.id, :destination_id => join.id  )
    result.edges.new(:origin_id => join.id  , :destination_id => _end.id  )
    @jobnet.children << result
    result
  end

  def finally(&block)
    jobnet("finally", :job_type_key => :finally, &block)
  end

  def expansion(root_jobnet_name, options = {})
    options = {
      :name => root_jobnet_name,
    }.update(options)
    result = __with_redirection__(options) do
      Tengine::Job::Expansion.new(options)
    end
    @jobnet.children << result
    result
  end

  private
  def __parse_job_args__(name, args)
    options = args.extract_options!
    description_or_script, script = *args
    if script
      description = description_or_script
    else
      script = description_or_script
      description = name
    end
    return script, description, options
  end

  def __with_redirection__(options)
    destination_names = Array(options.delete(:to) || options.delete(:redirect_to))
    result = yield
    destination_names.each do |dest_name|
      @redirections << [result.name, dest_name]
    end
    result
  end



end
