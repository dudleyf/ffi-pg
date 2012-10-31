#!/usr/bin/env ruby

require 'pathname'
require 'rspec'
require 'shellwords'
require 'pg'

TEST_DIRECTORY = Pathname.getwd + "tmp_test_specs"

module PG::TestingHelpers


	# Set some ANSI escape code constants (Shamelessly stolen from Perl's
	# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
	ANSI_ATTRIBUTES = {
		'clear'      => 0,
		'reset'      => 0,
		'bold'       => 1,
		'dark'       => 2,
		'underline'  => 4,
		'underscore' => 4,
		'blink'      => 5,
		'reverse'    => 7,
		'concealed'  => 8,

		'black'      => 30,   'on_black'   => 40,
		'red'        => 31,   'on_red'     => 41,
		'green'      => 32,   'on_green'   => 42,
		'yellow'     => 33,   'on_yellow'  => 43,
		'blue'       => 34,   'on_blue'    => 44,
		'magenta'    => 35,   'on_magenta' => 45,
		'cyan'       => 36,   'on_cyan'    => 46,
		'white'      => 37,   'on_white'   => 47
	}


	###############
	module_function
	###############

	### Create a string that contains the ANSI codes specified and return it
	def ansi_code( *attributes )
		attributes.flatten!
		attributes.collect! {|at| at.to_s }
		# $stderr.puts "Returning ansicode for TERM = %p: %p" %
		# 	[ ENV['TERM'], attributes ]
		return '' unless /(?:vt10[03]|xterm(?:-color)?|linux|screen)/i =~ ENV['TERM']
		attributes = ANSI_ATTRIBUTES.values_at( *attributes ).compact.join(';')

		# $stderr.puts "  attr is: %p" % [attributes]
		if attributes.empty? 
			return ''
		else
			return "\e[%sm" % attributes
		end
	end


	### Colorize the given +string+ with the specified +attributes+ and return it, handling 
	### line-endings, color reset, etc.
	def colorize( *args )
		string = ''

		if block_given?
			string = yield
		else
			string = args.shift
		end

		ending = string[/(\s)$/] || ''
		string = string.rstrip

		return ansi_code( args.flatten ) + string + ansi_code( 'reset' ) + ending
	end


	### Output a message with highlighting.
	def message( *msg )
		$stderr.puts( colorize(:bold) { msg.flatten.join(' ') } )
	end


	### Output a logging message if $VERBOSE is true
	def trace( *msg )
		return unless $VERBOSE
		output = colorize( msg.flatten.join(' '), 'yellow' )
		$stderr.puts( output )
	end


	### Return the specified args as a string, quoting any that have a space.
	def quotelist( *args )
		return args.flatten.collect {|part| part.to_s =~ /\s/ ? part.to_s.inspect : part.to_s }
	end


	### Run the specified command +cmd+ with system(), failing if the execution
	### fails.
	def run( *cmd )
		cmd.flatten!

		if cmd.length > 1
			trace( quotelist(*cmd) )
		else
			trace( cmd )
		end

		system( *cmd )
		raise "Command failed: [%s]" % [cmd.join(' ')] unless $?.success?
	end


	NOFORK_PLATFORMS = %w{java}

	### Run the specified command +cmd+ after redirecting stdout and stderr to the specified 
	### +logpath+, failing if the execution fails.
	def log_and_run( logpath, *cmd )
		cmd.flatten!

		if cmd.length > 1
			trace( quotelist(*cmd) )
		else
			trace( cmd )
		end

		# Eliminate the noise of creating/tearing down the database by
		# redirecting STDERR/STDOUT to a logfile if the Ruby interpreter
		# supports fork()
		if NOFORK_PLATFORMS.include?( RUBY_PLATFORM )
      # FIXME: for some reason redirection in the system method don't
      # work, so I ended up with this lengthy hack
      logpath ||= "/dev/null"
      f = File.open logpath, 'a'
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = $stderr = f
			system( *cmd )
      $stdout = old_stdout
      $stderr = old_stderr
		else
			logfh = File.open( logpath, File::WRONLY|File::CREAT|File::APPEND )
			if pid = fork
				logfh.close
			else
				$stdout.reopen( logfh )
				$stderr.reopen( $stdout )
				$stderr.puts( ">>> " + cmd.shelljoin )
				exec( *cmd )
				$stderr.puts "After the exec()?!??!"
				exit!
			end

			Process.wait( pid )
		end

		raise "Command failed: [%s]" % [cmd.join(' ')] unless $?.success?
	end


	### Check the current directory for directories that look like they're
	### testing directories from previous tests, and tell any postgres instances
	### running in them to shut down.
	def stop_existing_postmasters
		# tmp_test_0.22329534700318
		pat = Pathname.getwd + 'tmp_test_*'
		Pathname.glob( pat.to_s ).each do |testdir|
			datadir = testdir + 'data'
			pidfile = datadir + 'postmaster.pid'
			if pidfile.exist? && pid = pidfile.read.chomp.to_i
				$stderr.puts "pidfile (%p) exists: %d" % [ pidfile, pid ]
				begin
					Process.kill( 0, pid )
				rescue Errno::ESRCH
					$stderr.puts "No postmaster running for %s" % [ datadir ]
					# Process isn't alive, so don't try to stop it
				else
					$stderr.puts "Stopping lingering database at PID %d" % [ pid ]
					run pg_bin_path('pg_ctl'), '-D', datadir.to_s, '-m', 'fast', 'stop'
				end
			else
				$stderr.puts "No pidfile (%p)" % [ pidfile ]
			end
		end
	end


  def pg_bin_path cmd
    begin
      bin_dir = `pg_config --bindir`.strip
      "#{bin_dir}/#{cmd}"
    rescue
      cmd
    end
  end

	### Set up a PostgreSQL database instance for testing.
	def setup_testing_db( description )
		puts "Setting up test database for #{description} tests"

		begin
			$stderr.puts "Creating the test DB"
			log_and_run @logfile, pg_bin_path('psql'), '-e', '-c', 'DROP DATABASE IF EXISTS test', 'postgres'
			log_and_run @logfile, pg_bin_path('createdb'), '-e', 'test'
		rescue => err
			$stderr.puts "%p during test setup: %s" % [ err.class, err.message ]
			$stderr.puts "See #{@logfile} for details."
			$stderr.puts *err.backtrace if $DEBUG
			fail
		end

		conn = PG.connect(@conninfo)
		conn.set_notice_processor do |message|
			$stderr.puts( message ) if $DEBUG
		end

		return conn
	end


	def teardown_testing_db( conn )
		puts "Tearing down test database"
		conn.finish if conn
		log_and_run @logfile, pg_bin_path('pg_ctl'), '-m', 'fast', '-D', @test_pgdata.to_s, 'stop'
	end
end


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
