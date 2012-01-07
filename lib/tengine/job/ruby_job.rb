# -*- coding: utf-8 -*-
require 'tengine/job'

# ルートジョブネットとして必要な情報に関するモジュール
module Tengine::Job::RubyJob

  class << self
    attr_accessor :default_conductor
  end

  DEFAULT_CONDUCTOR = proc do |job|
    begin
      job.run
      job.succeed
    rescue => e # StandardError以外はTengineの例外として扱います
      job.fail(:exception => e)
    end
  end
  self.default_conductor = DEFAULT_CONDUCTOR

  class << self
    def run(job, signal, conductor)
      conductor.call(JobExecutionWrapper.new(job, signal))
    end
  end

  class JobExecutionWrapper

    attr_reader :source, :signal

    def initialize(source, signal)
      @source, @signal = source, signal
    end

    def run
      ruby_job_block = @source.template_block_for(:ruby_job)
      ruby_job_block.call
    end

    def fail(options = nil)
      if exception = options.delete(:exception)
        options[:message] = "[#{exception.class.name}] #{exception.message}\n  " << exception.backtrace.join("\n  ")
      end
      @source.ruby_job_fail(signal, options)
    end

    def succeed(options = nil)
      @source.ruby_job_succeed(signal)
    end
  end

end
