require 'libpq'

module PG
  require 'pg/constants'
  include Constants

  # Library version
  VERSION = '0.14.1'

  # VCS revision
  REVISION = %q$Revision$

  class << self
    # Get the PG library version. If +include_buildnum+ is +true+, include the build ID.
    def version_string( include_buildnum=false )
      vstring = "%s %s" % [ self.name, VERSION ]
      vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
      return vstring
    end

    # Convenience alias for PG::Connection.new.
    def connect( *args )
      return PG::Connection.new( *args )
    end

    def isthreadsafe
      1 == Libpq.PQisthreadsafe()
    end

    alias_method :is_threadsafe?, :isthreadsafe
    alias_method :threadsafe?, :isthreadsafe
  end

  require 'pg/error'
  require 'pg/bind_parameters'
  require 'pg/connection'
  require 'pg/result'
end
