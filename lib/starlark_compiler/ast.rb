# frozen_string_literal: true

module StarlarkCompiler
  class AST
    attr_reader :toplevel

    def initialize(toplevel:)
      @toplevel = toplevel
    end

    def <<(node)
      @toplevel << node
    end

    class Builder
      def const_name_for(str)
        str = str.to_s
        return str if str !~ /_/ && str =~ /[A-Z]+.*/

        str.split('_').map(&:capitalize).join.to_sym
      end

      def respond_to_missing?(name)
        AST.constants.include?(const_name_for(name))
      end

      def method_missing(name, *args, **kwargs)
        const_name = const_name_for(name)
        begin
          v = AST.const_get(const_name)
        rescue NameError
          super
        else
          if kwargs.empty?
            v.new(*args)
          else
            v.new(*args, **kwargs)
          end
        end
      end
    end
    private_constant :Builder

    def self.build(&blk)
      Builder.new.instance_exec(&blk)
    end

    class Node
      %i[- + / * % == < <= >= >].each do |op|
        define_method(op) { |rhs| BinaryOperator.new(self, rhs, operator: op) }
      end

      # TODO: ==, eql?, hash

      private

      def node(obj)
        case obj
        when Node
          obj
        when ::String
          String.new(obj)
        when ::Array
          Array.new(obj)
        when ::Hash
          Dictionary.new(obj)
        when NilClass
          None.new
        when TrueClass
          True.new
        when FalseClass
          False.new
        when Numeric
          Number.new(obj)
        else
          raise Error, "Ruby stdlib type #{obj.inspect} not convertible to Node"
        end
      end
    end

    class None < Node
    end

    class True < Node
    end

    class False < Node
    end

    class Number < Node
      attr_reader :number
      def initialize(number)
        @number = number
      end
    end

    class String < Node
      attr_reader :str
      def initialize(str)
        @str = str
      end
    end

    class VariableReference < Node
      attr_reader :var
      def initialize(var)
        raise "Only string type is allowed as a variable reference, got #{var.class}" unless var.is_a?(::String)
        @var = var
      end
    end

    class Array < Node
      attr_reader :elements
      def initialize(elements)
        @elements = elements.map(&method(:node))
      end
    end

    class VariableAssignment < Node
      attr_reader :name, :var
      def initialize(name, var)
        @name = name
        raise "Unsupported type on rhs for assignment: #{var.class}" if [Assignment].include?(var.class)
        @var = var
      end
    end

    class FunctionCall < Node
      attr_reader :name, :args, :kwargs
      def initialize(name, *args, **kwargs)
        @name = name
        @args = args.map(&method(:node))
        @kwargs = kwargs.transform_values(&method(:node))
      end
    end

    class MethodCall < Node
    end

    class Dictionary < Node
      attr_reader :elements
      def initialize(elements)
        @elements = Hash[elements.map { |k, v| [node(k), node(v)] }]
      end
    end

    class BinaryOperator < Node
      attr_reader :lhs, :rhs, :operator
      def initialize(lhs, rhs, operator:)
        @lhs = node(lhs)
        @rhs = node(rhs)
        @operator = operator
      end
    end

    class PlusOperator < BinaryOperator
      def initialize(lhs, rhs)
        super(lhs, rhs, operator: '+')
      end
    end
  end
end
