# frozen_string_literal: true

RSpec.describe StarlarkCompiler do
  it 'has a version number' do
    expect(StarlarkCompiler::VERSION).not_to be nil
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
      ast << function_call(
        'ios_application',
        name: string('App'),
        deps: array([
                      string(':App_Objc')
                    ]),
        entitlements: array([string(':App.entitlements')])
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

      ios_application(
        name = "App",
        deps = [":App_Objc"],
        entitlements = [":App.entitlements"],
      )
    STARLARK
  end
end
