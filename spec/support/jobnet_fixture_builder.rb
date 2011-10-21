class JobnetFixtureBuilder
  def initialize
    reset
  end

  def reset
    @instances = {}
    @start_count = 0
    @end_count = 0
    @fork_count = 0
    @join_count = 0
    @edge_count = 0
  end


  def [](instance_name)
    @instances[instance_name.to_sym]
  end

  def []=(instance_name, instance)
    @instances[instance_name.to_sym] = instance
  end

  def create_template(options = {})
    reset
    @mode = :template
    create(options)
  end

  def create_actual(options = {})
    template = create_template
    reset
    @mode = :actual
    options = (options || {}).update(:template => template)
    create(options)
  end

  def context
    self
  end

  def vertex(vertex_name)
    cached = self[vertex_name.to_sym]
    raise ArgumentError, "no vertex found for #{vertex_name.inspect}" unless cached
    self[:root].vertex(cached.id)
  end

  def edge(edge_name)
    cached = self[edge_name.to_sym]
    raise ArgumentError, "no edge found for #{edge_name.inspect}" unless cached
    self[:root].edge(cached.id)
  end

  def create(options = {})
    raise NotImplementedError, "You must use inherited class of FixtureBuilder"
  end

  MODE_AND_METHOD_TO_CLASS = {
    [:template, :root_jobnet] => Tengine::Job::RootJobnetTemplate,
    [:actual  , :root_jobnet] => Tengine::Job::RootJobnetActual  ,
    [:template, :jobnet     ] => Tengine::Job::JobnetTemplate    ,
    [:actual  , :jobnet     ] => Tengine::Job::JobnetActual      ,
    [:template, :script     ] => Tengine::Job::JobnetTemplate    ,
    [:actual  , :script     ] => Tengine::Job::JobnetActual      ,
    [:template, :finally    ] => Tengine::Job::JobnetTemplate    ,
    [:actual  , :finally    ] => Tengine::Job::JobnetActual      ,
  }.freeze

  %w[root_jobnet jobnet script].each do |method_name|
    root_assign = method_name =~ /^root_/ ? "@instances[:root] = result" : ""

    class_eval(<<-EOS)
      def new_#{method_name}(name, attrs = {}, &block)
        klass = MODE_AND_METHOD_TO_CLASS[ [@mode, :#{method_name}] ]
        attrs[:name] = name.to_s
        result = klass.new(attrs, &block)
        @instances[name.to_sym] = result
        #{root_assign}
        result
      end
    EOS
  end

  def new_finally
    klass = MODE_AND_METHOD_TO_CLASS[ [@mode, :finally] ]
    result = klass.new(:name => "_finally", :jobnet_type_key => :finally)
    result
  end


  ABBREVIATES = {
    'start' => 'S',
    'end'   => 'E',
    'fork'  => 'F',
    'join'  => 'J',
  }.freeze

  %w[start end fork join].each do |method_name|
    class_eval(<<-EOS)
      def new_#{method_name}(attrs = {}, &block)
        @#{method_name}_count += 1
        name = ABBREVIATES["#{method_name}"] + @#{method_name}_count.to_s
        klass = Tengine::Job::#{method_name.camelcase}
        result = klass.new(attrs, &block)
        @instances[name.to_sym] = result
        result
      end
    EOS
  end

  def new_edge(origin, dest)
    origin_vertex = origin.is_a?(Symbol) ? self[origin] : origin
    dest_vertex   = dest  .is_a?(Symbol) ? self[dest  ] : dest
    raise "no origin vertex found: #{origin.inspect}" unless origin_vertex
    raise "no dest   vertex found: #{dest.inspect  }" unless dest_vertex
    @edge_count += 1
    name = "e#{@edge_count}"
    result = Tengine::Job::Edge.new(:origin_id => origin_vertex.id, :destination_id => dest_vertex.id)
    @instances[name.to_sym] = result
    result
  end

end
