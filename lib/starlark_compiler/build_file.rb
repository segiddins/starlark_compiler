# frozen_string_literal: true

require 'starlark_compiler/ast'
require 'starlark_compiler/writer'

module StarlarkCompiler
  class BuildFile
    def initialize(package:, workspace: Dir.pwd)
      @loads = Hash.new { |h, k| h[k] = Set.new }
      @targets = {}
      @package = package
      @workspace = workspace
      @path = File.join(@workspace, @package, 'BUILD.bazel')
    end

    def add_load(from:, of:) # rubocop:disable Naming/MethodParameterName
      @loads[from] |= Array(of)
    end

    def add_target(function_call)
      name = function_call.kwargs.fetch(:name)
      if @targets[name]
        raise Error, "Target named #{name.inspect} already exists in #{package}"
      end

      @targets[name] = function_call
    end

    def save!
      File.open(@path, 'w') do |f|
        Writer.write(ast: to_starlark, io: f)
      end
    end

    def to_starlark
      loads = @loads
              .sort_by { |k, _| k }
              .map { |f, fn| AST.build { function_call('load', f, *fn.sort) } }
      targets = @targets
                .sort_by { |k, _| k }
                .map { |_f, fn| normalize_function_call_kwargs(fn) }
      AST.new(toplevel: loads + targets)
    end

    private

    # from https://github.com/bazelbuild/buildtools/blob/90de5e7001fbdfec29d4128bb508e01169f46950/tables/tables.go#L171-L202
    KWARG_NAME_PRIORITY = {
      name: -99,
      gwt_name: -98,
      package_name: -97,
      visible_node_name: -96,
      size: -95,
      timeout: -94,
      testonly: -93,
      src: -92,
      srcdir: -91,
      srcs: -90,
      out: -89,
      outs: -88,
      hdrs: -87,
      has_services: -86,
      include: -85,
      of: -84,
      baseline: -83,
      # All others sort here, at 0.
      destdir: 1,
      exports: 2,
      runtime_deps: 3,
      deps: 4,
      implementation: 5,
      implements: 6,
      alwayslink: 7
    }.freeze
    private_constant :KWARG_NAME_PRIORITY

    def normalize_function_call_kwargs(func)
      kwargs = func.kwargs.sort_by do |k, _v|
        [KWARG_NAME_PRIORITY.fetch(k, 0), k]
      end.to_h
      func.kwargs.replace(kwargs)
      func
    end
  end
end
