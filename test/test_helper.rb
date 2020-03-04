# frozen_string_literal: true

ENV["Y2DIR"] = File.expand_path("../src", __dir__)

# localization agnostic tests
ENV["LC_ALL"] = "en_US.utf-8"
ENV["LANG"] = "en_US.utf-8"

require "yast"
require "yast/rspec"

# force utf-8 encoding for external
Encoding.default_external = Encoding::UTF_8

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # If you misremember a method name both in code and in tests,
    # will save you.
    # https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/partial-doubles
    #
    # With graceful degradation for RSpec 2
    mocks.verify_partial_doubles = true if mocks.respond_to?(:verify_partial_doubles=)
  end
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  src_location = File.expand_path("../src", __dir__)
  # track all ruby files under src
  SimpleCov.track_files("#{src_location}/**/*.rb")

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end
