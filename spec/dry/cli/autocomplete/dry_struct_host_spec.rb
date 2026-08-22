# frozen_string_literal: true

# This gem's files are lexically inside `module Dry`, so every unqualified
# constant is resolved against that namespace first. A bare `Struct` therefore
# means `Dry::Struct` in any host that has dry-struct loaded, and
# `Dry::Struct.new` takes different arguments from `::Struct.new`.
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

  it "builds its value objects from ::Struct rather than Dry::Struct" do
    output, status = load_with_dry_struct(<<~RUBY)
      print Dry::CLI::Autocomplete::SpecBuilder::CompletionSpec.superclass
    RUBY

    expect(status).to be_success, "loading failed:\n#{output}"
    expect(output).to eq("Struct")
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
