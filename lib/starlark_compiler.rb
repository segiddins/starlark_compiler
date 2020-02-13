# frozen_string_literal: true

require_relative 'starlark_compiler/version'

module StarlarkCompiler
  class Error < StandardError; end

  require_relative 'starlark_compiler/ast'
  require_relative 'starlark_compiler/build_file'
  require_relative 'starlark_compiler/writer'
end
