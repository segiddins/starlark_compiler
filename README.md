# Starlark Compiler

This is a gem for creating Starlark ASTs and serializing them into Starlark code.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'starlark_compiler'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install starlark_compiler

## Usage
The following code:
```ruby
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
  ast << variable_assignment('deps', array([':App_Objc'])
  ast << variable_assignment('numbers', array([1,2,3]))
  ast << function_call(
    'ios_application',
    name: string('App'),
    deps: variable_reference('deps'),
    entitlements: array([string(':App.entitlements')])
  )
  ast
end
starlark_string = StarlarkCompiler::Writer.write(ast: ast, io: +'')
```
will populate `starlark_string` with:
```python
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
```
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/segiddins/starlark_compiler. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the StarlarkCompiler project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/segiddins/starlark_compiler/blob/master/CODE_OF_CONDUCT.md).
