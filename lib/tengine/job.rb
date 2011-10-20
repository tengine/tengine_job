# -*- coding: utf-8 -*-
require 'tengine_job'

module Tengine::Job
  autoload :DslEvaluator        , "tengine/job/dsl_evaluator"
  autoload :DslLoader           , "tengine/job/dsl_loader"

  autoload :Signal              , 'tengine/job/signal'

  autoload :Execution           , "tengine/job/execution"

  autoload :Category            , "tengine/job/category"
  autoload :Edge                , "tengine/job/edge"
  autoload :Vertex              , "tengine/job/vertex"

  autoload :Start               , "tengine/job/start"
  autoload :End                 , "tengine/job/end"
  autoload :Junction            , "tengine/job/junction"
  autoload :Fork                , "tengine/job/fork"
  autoload :Join                , "tengine/job/join"

  autoload :Job                 , "tengine/job/job"

  autoload :Jobnet              , "tengine/job/jobnet"
  autoload :JobnetActual        , "tengine/job/jobnet_actual"
  autoload :RootJobnetActual    , "tengine/job/root_jobnet_actual"
  autoload :JobnetTemplate      , "tengine/job/jobnet_template"
  autoload :RootJobnetTemplate  , "tengine/job/root_jobnet_template"

  autoload :Expansion           , "tengine/job/expansion"

  autoload :Root                , "tengine/job/root"
  autoload :Executable          , "tengine/job/executable"
  autoload :Stoppable           , "tengine/job/stoppable"
  autoload :Killing             , "tengine/job/killing"
  autoload :Connectable         , "tengine/job/connectable"
  autoload :ScriptExecutable    , "tengine/job/script_executable"

  autoload :MmCompatibility     , "tengine/job/mm_compatibility"


  class << self
    # tengine_coreからそのプラグインへ通知を受けるための
    def notify(sender, msg)
      if (msg == :after_load_dsl) && sender.respond_to?(:config)
        Tengine::Job::Category.update_for(
          sender.config.dsl_version,
          sender.config.dsl_dir_path
          ) # RootJobnetTemplateのdsl_filepathからCategoryを生成します
      end
    end

  end
end
