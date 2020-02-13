# frozen_string_literal: true

module StarlarkCompiler
  class Writer
    def self.write(ast:, io: nil)
      if io.nil?

      end

      new(ast: ast, io: io).write
    end

    private_class_method :new

    attr_accessor :ast, :io, :indent

    def initialize(ast:, io:)
      @ast = ast
      @io = io
      @indent = 0
    end

    def write
      case ast
      when AST
        ast.toplevel.each_with_index do |o, i|
          unless i.zero?
            write_newline
            write_newline unless o.is_a?(AST::FunctionCall) && o.name == 'load'
          end
          write_node(o)
        end
      when AST::Node
        write_node(ast)
      else
        raise Error, "Trying to write unknown object #{ast.inspect}"
      end
      write_newline
    end

    def write_node(node)
      delegate('write_%s', node)
    end

    def write_newline
      io << "\n"
      io << '    ' * indent
    end

    def write_string(str)
      io << str.str.inspect
    end

    def write_number(number)
      io << number.number.to_s
    end

    def delegate(template, obj)
      snake_case = lambda do |str|
        return str.downcase if str =~ /^[A-Z_]+$/

        str.gsub(/\B[A-Z]/, '_\&').squeeze('_') =~ /_*(.*)/
        $+.downcase
      end
      cls = obj.class
      while cls && (cls != AST::Node)
        name = cls.name.split('::').last
        method = template % snake_case[name]
        return send(method, obj) if respond_to?(method)

        cls = cls.superclass
      end
      raise "No #{template} for #{obj.class}"
    end

    def write_function_call(call)
      single_line = single_line?(call)
      io << call.name << '('
      final_index = single_line && call.kwargs.empty? && call.args.size.pred
      call.args.each_with_index do |arg, idx|
        indented(single_line: single_line) do |indenter|
          indenter.write_newline
          write_node(arg)
          indenter.write_comma unless final_index == idx
        end
      end
      final_index = single_line && call.kwargs.size.pred
      call.kwargs.each_with_index do |(k, v), idx|
        indented(single_line: single_line) do |indenter|
          indenter.write_newline
          io << "#{k} = "
          write_node(v)
          indenter.write_comma unless final_index == idx
        end
      end
      write_newline unless single_line
      io << ')'
    end

    def write_array(array)
      single_line = single_line?(array)
      io << '['
      end_index = array.elements.size.pred
      array.elements.each_with_index do |node, i|
        indented(single_line: single_line) do |indenter|
          indenter.write_newline
          write_node(node)
          indenter.write_comma unless i == end_index && single_line
        end
      end
      write_newline unless single_line
      io << ']'
    end

    def write_dictionary(dictionary)
      single_line = single_line?(dictionary)
      io << '{'
      end_index = dictionary.elements.size.pred
      dictionary.elements.each_with_index do |(key, value), i|
        indented(single_line: single_line) do |indenter|
          indenter.write_newline
          write_node(key)
          io << ': '
          write_node(value)
          indenter.write_comma unless i == end_index && single_line
        end
      end
      write_newline unless single_line
      io << '}'
    end

    def write_binary_operator(operator)
      write_node(operator.lhs)
      io << " #{operator.operator} "
      write_node(operator.rhs)
    end

    def write_none(_none)
      io << 'None'
    end

    def write_true(_none)
      io << 'True'
    end

    def write_false(_none)
      io << 'False'
    end

    Indenter = Struct.new(:writer, :should_indent) do
      def write_newline
        writer.write_newline if should_indent
      end

      def write_comma
        writer.io << (should_indent ? ',' : ', ')
      end
    end
    private_constant :Indenter

    def indented(single_line:)
      should_indent = !single_line
      @indent += 1 if should_indent
      yield Indenter.new(self, should_indent)
    ensure
      @indent -= 1 if should_indent
    end

    def single_line?(node)
      return true unless node

      delegate('single_line_%s?', node)
    end

    def single_line_string?(str)
      str.str.size <= 50
    end

    def single_line_number?(_)
      true
    end

    def single_line_binary_operator?(operator)
      single_line?(operator.lhs) && single_line?(operator.rhs)
    end

    def single_line_function_call?(call)
      if call.args.empty?
        call.kwargs.size <= 1 &&
          call.kwargs.each_value.all? { |v| single_line?(v) }
      elsif call.kwargs.empty?
        call.args.size <= 2 && call.args.all? { |v| single_line?(v) } ||
          (call.args.size == 1 && call.args.first.respond_to?(:elements))
      end
    end

    def single_line_array?(array)
      array.elements.size <= 1 &&
        array.elements.all?(&method(:single_line?))
    end

    def single_line_dictionary?(dictionary)
      dictionary.elements.size <= 1 &&
        dictionary.elements.each_key.all?(&method(:single_line?))
    end
  end
end
