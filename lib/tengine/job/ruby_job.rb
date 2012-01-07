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
      job.fail(:message => "[#{e.class.name}] #{e.message}\n  " << e.backtrace.join("\n  "))
    end
  end
  self.default_conductor = DEFAULT_CONDUCTOR

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
      @source.ruby_job_fail(signal, options)
    end

    def succeed(options = nil)
      @source.ruby_job_succeed(signal)
    end

  end


end
