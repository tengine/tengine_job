# -*- coding: utf-8 -*-
require 'tengine_job'

module Tengine::Job
  autoload :DslEvaluator        , "tengine/job/dsl_evaluator"
  autoload :DslLoader           , "tengine/job/dsl_loader"

  autoload :Category            , "tengine/job/category"
  autoload :Edge                , "tengine/job/edge"
  autoload :Vertex              , "tengine/job/vertex"

  autoload :Start               , "tengine/job/start"
  autoload :End                 , "tengine/job/end"
  autoload :Junction            , "tengine/job/junction"
  autoload :Fork                , "tengine/job/fork"
  autoload :Join                , "tengine/job/join"

  autoload :Job                 , "tengine/job/job"

  autoload :Script              , "tengine/job/script"
  autoload :ScriptActual        , "tengine/job/script_actual"
  autoload :ScriptTemplate      , "tengine/job/script_template"

  autoload :Jobnet              , "tengine/job/jobnet"
  autoload :JobnetActual        , "tengine/job/jobnet_actual"
  autoload :RootJobnetActual    , "tengine/job/root_jobnet_actual"
  autoload :JobnetTemplate      , "tengine/job/jobnet_template"
  autoload :RootJobnetTemplate  , "tengine/job/root_jobnet_template"

  autoload :Expansion           , "tengine/job/expansion"

  autoload :Root                , "tengine/job/root"
  autoload :RuntimeAttrs        , "tengine/job/runtime_attrs"
  autoload :Stoppable           , "tengine/job/stoppable"
  autoload :Connectable         , "tengine/job/connectable"

  autoload :MmCompatibility     , "tengine/job/mm_compatibility"


  class << self
    def notify(sender, msg)
      if sender.is_a?(Tengine::Core::Bootstrap) && (msg == :after_load_dsl)
        # Tengine::Job::Category.update_for(sender.config.dsl_version) # RootJobnetTemplateのdsl_filepathからCategoryを生成します
      end
    end

  end
end
