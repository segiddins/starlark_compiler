# frozen_string_literal: true

require 'open3'

CHECK_BUILDIFIER = begin
                     Open3.capture2e('buildifier', '--help').last.success?
                   rescue Errno::ENOENT
                     false
                   end
warn 'Skipping buildifier checks' unless CHECK_BUILDIFIER

RSpec.describe StarlarkCompiler do
  it 'has a version number' do
    expect(StarlarkCompiler::VERSION).not_to be nil
  end

  def check_buildifier(compiled, type: 'auto')
    return unless CHECK_BUILDIFIER

    buildifier, status = Open3.capture2e(%w[buildifier buildifier],
                                         '-type', type,
                                         stdin_data: compiled)
    expect(compiled).to eq buildifier
    expect(status).to be_success
  end

  it 'works' do
    ast = StarlarkCompiler::AST.build do
      ast = StarlarkCompiler::AST.new(toplevel: [])
      ast << function_call(
        'load',
        string('@bazel_build_rules_apple//rules:ios.bzl'),
        string('ios_application'),
        _ios_application: string('ios_application')
      )
      ast << function_call(
        'load',
        string('@bazel_build_rules_apple//rules:ios.bzl'),
        string('ios_application')
      )
      ast << function_call(
        'ios_library',
        name: string('App_Objc'),
        srcs: function_call('glob', array([string('Sources/**/*.swift')])) +
           ['A.swift']
      )
      ast << variable_assignment('deps', array([':App_Objc']))
      ast << variable_assignment('numbers', array([1, 2, 3]))
      ast << function_call(
        'ios_application',
        name: string('App'),
        deps: variable_reference('deps'),
        entitlements: array([string(':App.entitlements')])
      )
      ast << function_declaration(
        'newMacro',
        [variable_reference('deps'), variable_reference('data')],
        [
          function_call(
            'ios_application',
            srcs: function_call('glob', array([string('Sources/**/*.swift')])),
            deps: variable_reference('deps'),
            data: variable_reference('data')
          ),
          function_call(
            'ios_unit_test',
            srcs: function_call('glob', array([string('Tests/**/*.swift')])),
            deps: variable_reference('deps'),
            data: variable_reference('data')
          )
        ]
      )
      ast
    end

    compiled = StarlarkCompiler::Writer.write(ast: ast, io: +'')

    expect(compiled).to eq(<<~STARLARK)
      load(
          "@bazel_build_rules_apple//rules:ios.bzl",
          "ios_application",
          _ios_application = "ios_application",
      )
      load("@bazel_build_rules_apple//rules:ios.bzl", "ios_application")

      ios_library(
          name = "App_Objc",
          srcs = glob(["Sources/**/*.swift"]) + ["A.swift"],
      )

      deps = [":App_Objc"]

      numbers = [
          1,
          2,
          3,
      ]

      ios_application(
          name = "App",
          deps = deps,
          entitlements = [":App.entitlements"],
      )

      def newMacro(
          deps,
          data
      ):
          ios_application(
              srcs = glob(["Sources/**/*.swift"]),
              deps = deps,
              data = data,
          )
          ios_unit_test(
              srcs = glob(["Tests/**/*.swift"]),
              deps = deps,
              data = data,
          )
    STARLARK
    check_buildifier(compiled)
  end

  it 'indents and sorts' do
    ast = StarlarkCompiler::AST.build do
      ast = StarlarkCompiler::AST.new(toplevel: [])
      ast << function_call('load', '//tools/rules:framework.bzl',
                           'custom_apple_framework')
      ast << function_call('load', '//tools/rules:test.bzl',
                           'custom_ios_unit_test')

      ast << function_call(
        'custom_apple_framework',
        name: 'Framework',
        private_headers: function_call('glob', ['*.h']),
        srcs: function_call('glob', ['Sources/**/*.h', 'Sources/**/*.m']),
        resource_bundles: { 'FrameworkResources' =>
         function_call('glob', ['Resources/**/*'], exclude_directories: 0) },
        objc_copts: ['-fmodules-disable-diagnostic-validation'],
        deps: %w[//Frameworks/FWA //Frameworks/FWB //Frameworks/FWC],
        visibility: ['//visibility:public'],
        random_deps: {
          'Debug' => ['//A', '//B'],
          'Release' => ['//C']
        }
      )
      ast
    end

    compiled = StarlarkCompiler::Writer.write(ast: ast, io: +'')

    expect(compiled).to eq(<<~STARLARK)
      load("//tools/rules:framework.bzl", "custom_apple_framework")
      load("//tools/rules:test.bzl", "custom_ios_unit_test")

      custom_apple_framework(
          name = "Framework",
          private_headers = glob(["*.h"]),
          srcs = glob([
              "Sources/**/*.h",
              "Sources/**/*.m",
          ]),
          resource_bundles = {"FrameworkResources": glob(
              ["Resources/**/*"],
              exclude_directories = 0,
          )},
          objc_copts = ["-fmodules-disable-diagnostic-validation"],
          deps = [
              "//Frameworks/FWA",
              "//Frameworks/FWB",
              "//Frameworks/FWC",
          ],
          visibility = ["//visibility:public"],
          random_deps = {
              "Debug": [
                  "//A",
                  "//B",
              ],
              "Release": ["//C"],
          },
      )
    STARLARK
    check_buildifier(compiled)
  end

  it 'handles literals properly' do
    ast = StarlarkCompiler::AST.build do
      ast = StarlarkCompiler::AST.new(toplevel: [])
      ast << function_call('load', ':foo.bzl', 'call')
      ast << variable_assignment('foo', array([1, 2, 3]))
      ast << variable_assignment('foo2', number(1) + number(3))
      ast << variable_assignment('foo3', number(1) != number(3))
      ast << variable_assignment('foo4', true)
      ast << function_call(
        'call',
        _int: 5,
        _str: 'abc',
        _empty_str: '',
        _unicode_str: "😇 \n*\0ok",
        _true: true,
        _false: false,
        _none: nil,
        _sum: array([1, 2, 3]) + array(%w[a b c]),
        _int_array: [1, 2, 3],
        _string_array: %w[a b c],
        _long_string_array: ['//a', '//b'],
        deps: ['//Frameworks/FWA', '//Frameworks/FWB', '//Frameworks/FWC']
      )
      ast << function_call('call')
      ast << function_call('call', 'positional')
      ast << function_call('call', 1, 2)
      ast << function_call('call', 1, 2, 3)
      ast << function_call('call', a: 'b')
      ast
    end

    compiled = StarlarkCompiler::Writer.write(ast: ast, io: +'')

    expect(compiled).to eq(<<~'STARLARK')
      load(":foo.bzl", "call")

      foo = [
          1,
          2,
          3,
      ]

      foo2 = 1 + 3

      foo3 = False

      foo4 = True

      call(
          _int = 5,
          _str = "abc",
          _empty_str = "",
          _unicode_str = "😇 \n*\u0000ok",
          _true = True,
          _false = False,
          _none = None,
          _sum = [
              1,
              2,
              3,
          ] + [
              "a",
              "b",
              "c",
          ],
          _int_array = [
              1,
              2,
              3,
          ],
          _string_array = [
              "a",
              "b",
              "c",
          ],
          _long_string_array = [
              "//a",
              "//b",
          ],
          deps = [
              "//Frameworks/FWA",
              "//Frameworks/FWB",
              "//Frameworks/FWC",
          ],
      )

      call()

      call("positional")

      call(1, 2)

      call(
          1,
          2,
          3,
      )

      call(a = "b")
    STARLARK

    check_buildifier(compiled)
  end

  describe described_class::BuildFile do
    it 'works' do
      build_file = described_class.new(package: 'Frameworks/F')

      build_file.add_load(from: '@hello', of: 'foo')
      build_file.add_load(from: '@hello//:there', of: %w[abc def])
      build_file.add_load(from: '@hello', of: 'bar')
      build_file.add_load(from: '@hello//:morning', of: 'efg')

      build_file.add_variable_assignment(name: 'foovar', var: 'bar')
      build_file.add_variable_assignment(name: 'foovar2', var: %w[bar1 bar2])

      StarlarkCompiler::AST.build do
        build_file.add_variable_assignment(name: 'foovar2', var: %w[bar1 bar2])
        build_file.add_target(function_call(
                                'foo',
                                name: 'Framework',
                                deps: %w[//A //B //C],
                                srcs: function_call('glob', ['**/*.swift']),
                                some: variable_reference('foovar'),
                                testonly: 0,
                                custom_attr: { 'c' => 'b', 'a' => 'd', 1 => 3 },
                                do: nil,
                                a_bit: true
                              ))
        build_file.add_variable_assignment(
          name: 'fooTarget',
          var: function_call('foo',
                             name: 'FooTarget')
        )
        build_file.add_variable_assignment(name: 'fooBool', var: true)
        build_file.add_variable_assignment(name: 'fooNil', var: nil)
        build_file.add_variable_assignment(name: 'fooNumber', var: 10)
      end

      compiled = StarlarkCompiler::Writer.write(ast: build_file.to_starlark,
                                                io: +'')

      check_buildifier(compiled, type: 'build')

      expect(compiled).to eq(<<~'STARLARK')
        load(
            "@hello",
            "bar",
            "foo",
        )
        load("@hello//:morning", "efg")
        load(
            "@hello//:there",
            "abc",
            "def",
        )

        foovar = "bar"

        foovar2 = [
            "bar1",
            "bar2",
        ]

        fooTarget = foo(name = "FooTarget")

        fooBool = True

        fooNil = None

        fooNumber = 10

        foo(
            name = "Framework",
            testonly = 0,
            srcs = glob(["**/*.swift"]),
            a_bit = True,
            custom_attr = {
                "c": "b",
                "a": "d",
                1: 3,
            },
            do = None,
            some = foovar,
            deps = [
                "//A",
                "//B",
                "//C",
            ],
        )
      STARLARK
    end
  end
end
