module PG
  class Error < StandardError
    attr_accessor :connection
    attr_accessor :result

    def initialize(message, connection=nil, result=nil)
      super(message)
      @connection = connection
      @result = result
    end
  end
end

module PG
  class Connection
    include Libpq::ErrorMessageFieldConstants
    include Libpq::ConnStatusTypeConstants
    include Libpq::PostgresPollingStatusTypeConstants
    include Libpq::ExecStatusTypeConstants
    include Libpq::PGTransactionStatusTypeConstants
    include Libpq::PGVerbosityConstants
    include Libpq::PGPingConstants

    class << self
      # The order the options are passed to the ::connect method.
      CONNECT_ARGUMENT_ORDER = %w[host port options tty dbname user password]

      alias_method :connect, :new
      alias_method :open, :new
      alias_method :setdb, :new
      alias_method :setdblogin, :new

      ### Quote the given +value+ for use in a connection-parameter string.
      ### @param [String] value  the option value to be quoted.
      ### @return [String]
      def quote_connstr( value )
        return "'" + value.to_s.gsub( /[\\']/ ) {|m| '\\' + m } + "'"
      end

      ### Parse the connection +args+ into a connection-parameter string
      ### @param [Array<String>] args  the connection parameters
      ### @return [String]  a connection parameters string
      def parse_connect_args( *args )
        return '' if args.empty?

        # This will be swapped soon for code that makes options like those required for
        # PQconnectdbParams()/PQconnectStartParams(). For now, stick to an options string for
        # PQconnectdb()/PQconnectStart().
        connopts = []

        # Handle an options hash first
        if args.last.is_a?( Hash )
          opthash = args.pop
          opthash.each do |key, val|
            connopts.push( "%s=%s" % [key, PG::Connection.quote_connstr(val)] )
          end
        end

        # Option string style
        if args.length == 1 && args.first.to_s.index( '=' )
          connopts.unshift( args.first )

        # Append positional parameters
        else
          args.each_with_index do |val, i|
            next unless val # Skip nil placeholders

            key = CONNECT_ARGUMENT_ORDER[ i ] or
              raise ArgumentError, "Extra positional parameter %d: %p" % [ i+1, val ]
            connopts.push( "%s=%s" % [key, PG::Connection.quote_connstr(val.to_s)] )
          end
        end

        return connopts.join(' ')
      end

      def escape_string
      end
      alias_method :escape, :escape_string

      def escape_bytea
      end

      def unescape_bytea
      end

      def isthreadsafe
      end

      def encrypt_password
      end

      def quote_ident
      end

      def connect_start
      end

      def conndefaults
      end
    end # class << self

    def initialize(*args, &block)
      conninfo = self.class.parse_connect_args(*args)

      @conn = Libpq.PQconnectdb(conninfo)

      if @conn.nil?
        raise PG::Error, "PQconnectdb() unable to allocate structure"
      end

      if Libpq.PQstatus(@conn) == CONNECTION_BAD
        raise PG::Error, Libpq.PQErrorMessage(@conn), @conn
      end

      # TODO: Set client encoding on the connection

      if block_given?
        begin
          yield self
        ensure
          Libpq.PQfinish(@conn)
        end
      end
    end

    # /******     PGconn INSTANCE METHODS: Connection Control     ******/
    def initialize
    end

    def connect_poll
    end

    def finish
    end
    alias_method :close, :finish

    def reset
    end

    def reset_start
    end

    def reset_poll
    end

    def conndefaults
    end

    # /******     PGconn INSTANCE METHODS: Connection Status     ******/
    def db
    end

    def user
    end

    def pass
    end

    def host
    end

    def port
    end

    def tty
    end

    def options
    end

    def status
    end

    def transaction_status
    end

    def parameter_status
    end

    def protocol_version
    end

    def server_version
    end

    def error_message
    end

    def socket
    end

    def backend_pid
    end

    def connection_needs_password
    end

    def connection_used_password
    end

    def getssl
    end

    def exec(command, params={}, result_format=0, &block)
      result_ptr = Libpq.PQexec(@conn, command)
      result = Result.new(result_ptr)
    end
    alias_method :query, :exec

    def prepare
    end

    def exec_prepared
    end

    def describe_prepared
    end

    def describe_portal
    end

    def make_empty_pgresult
    end

    def escape_string
    end
    alias_method :escape, :escape_string

    def escape_bytea
    end

    def unescape_bytea
    end

    #/******     PGconn INSTANCE METHODS: Asynchronous Command Processing     ******/
    def send_query
    end

    def send_prepare
    end

    def send_query_prepared
    end

    def send_describe_prepared
    end

    def send_describe_portal
    end

    def get_result
    end

    def consume_input
    end

    def is_busy
    end

    def setnonblocking
    end

    def isnonblocking
    end
    alias_method :nonblocking?, :isnonblocking

    def flush
    end

    #/******     PGconn INSTANCE METHODS: Cancelling Queries in Progress     ******/
    def cancel
    end

    #/******     PGconn INSTANCE METHODS: NOTIFY     ******/
    def notifies
    end

    #/******     PGconn INSTANCE METHODS: COPY     ******/
    def put_copy_data
    end

    def put_copy_end
    end

    def get_copy_data
    end

    #/******     PGconn INSTANCE METHODS: Control Functions     ******/
    def set_error_verbosity
    end

    def trace
    end

    def untrace
    end

    #/******     PGconn INSTANCE METHODS: Notice Processing     ******/
    def set_notice_receiver
    end

    def set_notice_processor
    end

    #/******     PGconn INSTANCE METHODS: Other    ******/
    def get_client_encoding
    end

    def set_client_encoding
    end

    def transaction
    end

    def block
    end

    def wait_for_notify
    end
    alias_method :notifies_wait, :wait_for_notify

    def quote_ident
    end

    def async_exec
    end
    alias_method :async_query, :async_exec

    def get_last_result
    end

    #/******     PGconn INSTANCE METHODS: Large Object Support     ******/
    def lo_creat
    end
    alias_method :locreat, :lo_creat

    def lo_create
    end
    alias_method :locreate, :lo_create

    def lo_import
    end
    alias_method :loimport, :lo_import

    def lo_export
    end
    alias_method :loexport, :lo_export

    def lo_open
    end
    alias_method :loopen, :lo_open

    def lo_write
    end
    alias_method :lowrite, :lo_write

    def lo_read
    end
    alias_method :loread, :lo_read

    def lo_lseek
    end
    alias_method :lolseek, :lo_lseek
    alias_method :loseek, :lo_lseek
    alias_method :lo_seek, :lo_lseek

    def lo_tell
    end
    alias_method :lotell, :lo_tell

    def lo_truncate
    end
    alias_method :lotruncate, :lo_truncate

    def lo_close
    end
    alias_method :loclose, :lo_close

    def lo_unlink
    end
    alias_method :lounlink, :lo_unlink
  end
end

module PG
  class Result
    include Enumerable
    include Libpq::ExecStatusTypeConstants
    include Libpq::ErrorMessageFieldConstants
    InvalidOid = Libpq::InvalidOid

    def initialize(result)
      @result = result
    end

    #/******     PGresult INSTANCE METHODS: libpq     ******/
    def result_status
    end

    def res_status
    end

    def result_error_message
    end

    def result_error_field
    end

    def clear
    end

    def ntuples
    end
    alias_method :num_tuples, :ntuples

    def nfields
    end
    alias_method :num_fields, :nfields

    def fname
    end

    def fnumber
    end

    def ftable
    end

    def ftablecol
    end

    def fformat
    end

    def ftype
    end

    def fmod
    end

    def fsize
    end

    def getvalue
    end

    def getisnull
    end

    def getlength
    end

    def nparams
    end

    def paramtype
    end

    def cmd_status
    end

    def cmd_tuples
    end
    alias_method :cmdtuples, :cmd_tuples

    def oid_value
    end

    #/******     PGresult INSTANCE METHODS: other     ******/
    def []
    end

    def each
    end

    def fields
    end

    def values
      ntuples = Libpq.PQntuples(@result)
      nfields = Libpq.PQnfields(@result)

      (0...ntuples).map do |r|
        [].tap do |row|
          (0...nfields).map { |f| row[f] = value_at(r, f) }
        end
      end
    end

    def column_values
    end

    def field_values
    end

    private

    def value_at(tuple, field)
      if Libpq.PQgetisnull(@result, tuple, field) == 0
        Libpq.PQgetvalue(@result, tuple, field)
      else
        nil
      end
    end
  end
end

# Backwards-compatible aliases
PGconn = PG::Connection
PGresult = PG::Result
