# -*- coding: utf-8 -*-
require 'tengine_job'

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

module Rjn0023
  class << self
    attr_accessor :exception_class_name
    def raise_test_exception
      return unless exception_class_name
      raise exception_class_name.constantize
    end
  end
end

jobnet("rjn0023", :conductor => custom_conductor) do
  ruby_job('j1'){ Rjn0023.raise_test_exception  }
end
