# frozen_string_literal: true

# This gem's files are lexically inside `module Dry`, so every unqualified
# constant is resolved against that namespace first. A bare `Struct` therefore
# meant `Dry::Struct` in any host that had dry-struct loaded, and
# `Dry::Struct.new` takes different arguments from `::Struct.new`. The value
# objects are `::Data` now, and the leading colons matter for the same reason:
# no `Dry::Data` exists today, but one released gem would be enough.
#
# The failure cannot appear in this suite's normal runs, because dry-struct is
# not in this gem's bundle. It appears in the host, at the moment somebody
# invokes the completion command, and it reads as "this gem is broken".
#
# That is most dry-rb applications, so it is worth a spec of its own. The
# subprocess is the point: it loads dry-struct FIRST, the way a host does,
# which is the only ordering that reproduces the collision.
RSpec.describe "loading inside a host that uses dry-struct" do
  def load_with_dry_struct(snippet)
    lib = File.expand_path("../../../../lib", __dir__)
    script = <<~RUBY
      require "dry/struct"
      require "dry/cli/autocomplete/spec_builder"
      #{snippet}
    RUBY
    output = IO.popen([RbConfig.ruby, "-I#{lib}", "-e", script], err: %i[child out], &:read)
    [output, $CHILD_STATUS || $?]
  end

  it "loads at all, which is the thing that used to fail" do
    output, status = load_with_dry_struct(<<~RUBY)
      print "loaded"
    RUBY

    expect(status).to be_success, "loading failed:\n#{output}"
    expect(output).to eq("loaded")
  end

  it "builds its value objects from core Data, not anything in Dry" do
    output, status = load_with_dry_struct(<<~RUBY)
      klass = Dry::CLI::Autocomplete::SpecBuilder::CompletionSpec
      print [klass.superclass, klass.name.start_with?("Dry::CLI::Autocomplete")].inspect
    RUBY

    expect(status).to be_success, "loading failed:\n#{output}"
    expect(output).to eq("[Data, true]")
  end

  it "keeps every value object out of the Dry::Struct hierarchy" do
    output, status = load_with_dry_struct(<<~RUBY)
      names = %w[CompletionSpec Node OptionSpec ArgumentSpec]
      print names.select { |n|
        Dry::CLI::Autocomplete::SpecBuilder.const_get(n).ancestors.include?(Dry::Struct)
      }.inspect
    RUBY

    expect(status).to be_success, "loading failed:\n#{output}"
    expect(output).to eq("[]")
  end
end
