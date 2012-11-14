#!/usr/bin/env ruby

require 'pathname'
require 'rspec'
require 'shellwords'
require 'pg'

TEST_DIRECTORY = Pathname.getwd + "tmp_test_specs"

require 'lib/helpers'

RSpec.configure do |config|
	ruby_version_vec = RUBY_VERSION.split('.').map {|c| c.to_i }.pack( "N*" )

	config.include( PG::TestingHelpers )
	config.treat_symbols_as_metadata_keys_with_true_values = true

	config.mock_with :rspec
	config.filter_run_excluding :ruby_19 if ruby_version_vec <= [1,9,1].pack( "N*" )

	config.filter_run_excluding :postgresql_90 unless
		PG::Connection.instance_methods.map( &:to_sym ).include?( :escape_literal )
	config.filter_run_excluding :postgresql_91 unless
		PG.respond_to?( :library_version )
end

