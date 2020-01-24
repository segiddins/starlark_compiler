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
          io << "\n\n" unless i.zero?
          write_node(o)
        end
      when AST::Node
        write_node(ast)
      else
        raise Error, "Trying to write unknown object #{ast.inspect}"
      end
      io << "\n"
    end

    def write_node(node, start_of_line: true)
      write_start_of_line if start_of_line
      delegate('write_%s', node)
    end

    def write_start_of_line
      io << '  ' * indent
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
      io << "\n" unless single_line
      final_index = single_line && call.kwargs.empty? && call.args.size.pred
      call.args.each_with_index do |arg, idx|
        indented do
          write_node(arg, start_of_line: !single_line)
          unless final_index == idx
            io << ','
            io << (single_line ? ' ' : "\n")
          end
        end
      end
      final_index = single_line && call.kwargs.size.pred
      call.kwargs.each_with_index do |(k, v), idx|
        indented do
          write_start_of_line unless single_line
          io << "#{k} = "
          write_node(v, start_of_line: false)
          unless final_index == idx
            io << ','
            io << (single_line ? ' ' : "\n")
          end
        end
      end
      write_start_of_line unless single_line
      io << ')'
    end

    def write_array(array)
      single_line = single_line?(array)
      io << '['
      array.elements.each_with_index do |node, i|
        unless i.zero?
          io << ','
          io << "\n" unless single_line
        end
        write_node(node, start_of_line: !single_line)
      end
      io << ']'
    end

    def write_dictionary(dictionary)
      single_line = single_line?(dictionary)
      io << '{'
      dictionary.elements.each_with_index do |(key, value), i|
        unless i.zero?
          io << ','
          io << "\n" unless single_line
        end
        write_node(key, start_of_line: !single_line)
        io << ': '
        write_node(value, start_of_line: false)
      end
      io << '}'
    end

    def write_binary_operator(operator)
      write_node(operator.lhs, start_of_line: false)
      io << " #{operator.operator} "
      write_node(operator.rhs, start_of_line: false)
    end

    def write_none(_none)
      io << 'None'
    end

    def write_true(_none)
      io << 'True'
    end

    def write_false(_none)
      io << 'True'
    end

    def indented
      @indent += 1
      yield
    ensure
      @indent -= 1
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
      if array.elements.all? { |e| e.is_a?(AST::String) }
        array.elements.sum { |s| s.str.length } < 50
      else
        array.elements.size <= 1 && array.elements.all?(&method(:single_line?))
      end
    end

    def single_line_dictionary?(dictionary)
      dictionary.elements.size <= 1 &&
        dictionary.elements.each_value.all?(&method(:single_line?))
    end
  end
end
