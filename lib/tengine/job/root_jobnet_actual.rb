# -*- coding: utf-8 -*-
require 'tengine/job'

# 実行時のルートジョブネットを表すVertex
class Tengine::Job::RootJobnetActual < Tengine::Job::JobnetActual
  include Tengine::Job::Root

  belongs_to :template, :inverse_of => :root_jobnet_actuals, :index => true, :class_name => "Tengine::Job::RootJobnetTemplate"
  has_many :executions, :inverse_of => :root_jobnet, :class_name => "Tengine::Job::Execution"

  field :locking_vertex_id, :type => String                 # ロックを必要とするvertexのID(ルートジョブネット自身を指すこともあり得る)
  field :lock_key         , :type => String, :default => "" # ロックのキー
  field :lock_timeout_key , :type => String                 # ロック解放待ちでタイムアウトした際に発火するイベントのキー

  def rerun(*args)
    options = args.extract_options!
    sender = options.delete(:sender) || Tengine::Event.default_sender
    options = options.merge({
        :retry => true,
        :root_jobnet_id => self.id,
      })
    result = Tengine::Job::Execution.new(options)
    result.target_actual_ids ||= []
    result.target_actual_ids += args.flatten
    result.save!
    sender.wait_for_connection do
      sender.fire(:'start.execution.job.tengine', :properties => {
          :execution_id => result.id.to_s
        })
    end
    result
  end

  def wait_to_acquire_lock(vertex, options = {})
    acquire_lock(vertex)
    loop_with_timeout(options) do
      result = find_and_modify_lock
      unless result
        Tengine::Job.test_harness_hook("wait_to_acquire_lock")
        reload
        acquire_lock(vertex)
      end
      result
    end
    if block_given?
      reload
      release_lock
      update_with_lock(:skip_waiting => true) do
        yield
      end
    end
  end

  def find_and_modify_lock
    current_version = self.version
    hash = as_document.dup
    hash['version'] = current_version + 1
    query = { :_id => self.id, :version => current_version, :lock_key => "", }
    result = self.class.collection.find_and_modify({
        :query => query,
        :update => hash
      })
    result
  end

  def acquire_lock(vertex)
    self.lock_key = "#{Process.pid.to_s}/#{vertex.id.to_s}"
    self.lock_timeout_key = "#{self.lock_key}-#{Time.now.utc.iso8601}"
    self.locking_vertex_id = vertex.id.to_s
  end

  def release_lock
    self.lock_key = ""
    self.lock_timeout_key = nil
    self.locking_vertex_id = nil
  end

  def update_with_lock(options = {})
    skip_waiting = (options || {}).delete(:skip_waiting)
    first_time = true
    super(options) do
      reload unless first_time
      wait_for_lock_released unless skip_waiting
      yield
      first_time = false
    end
  end

  def wait_for_lock_released(options = {})
    loop_with_timeout(options) do
      locked = (self.lock_key != "")
      if locked
        Tengine::Job.test_harness_hook("waiting_for_lock_released")
        reload
      end
      !locked
    end
  end


  def loop_with_timeout(options = {})
    retry_interval = options[:interval] || 0.1 # seconds
    retry_timeout = options[:timeout] || 3 # seconds
    timeout(retry_timeout) do
      loop do
        result = yield
        return result if result
        sleep(retry_interval)
      end
    end
  end

end
