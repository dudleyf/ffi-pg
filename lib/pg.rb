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

      # @deprecated
      def escape_string(str)
        len = str.length
        buf = FFI::MemoryPointer.new(:char, 2*len+1)

        Libpq.PQescapeString(buf, str, len)

        # TODO: encoding
        buf.read_string
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

      @pg_conn = Libpq.PQconnectdb(conninfo)

      if @pg_conn.nil?
        raise PG::Error, "PQconnectdb() unable to allocate structure"
      end

      raise_pg_error if Libpq.PQstatus(@pg_conn) == CONNECTION_BAD

      # TODO: Set client encoding on the connection

      if block_given?
        begin
          yield self
        ensure
          Libpq.PQfinish(@pg_conn)
        end
      end
    end

    # /******     PGconn INSTANCE METHODS: Connection Control     ******/
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
      result_ptr = Libpq.PQexec(@pg_conn, command)
      Result.new(result_ptr)
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

    def escape_string(str)
      len = str.length
      buf = FFI::MemoryPointer.new(:char, 2*len+1)
      err = FFI::MemoryPointer.new(:int)

      Libpq.PQescapeStringConn(@pg_conn, buf, str, len, err)

      raise_pg_error if err.read_int != 0
      buf.read_string
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

    private

    def raise_pg_error
      raise PG::Error, Libpq.PQerrorMessage(@pg_conn), @pg_conn
    end
  end
end

module PG
  class Result
    include Enumerable
    include Libpq::ExecStatusTypeConstants
    include Libpq::ErrorMessageFieldConstants
    InvalidOid = Libpq::InvalidOid

    def initialize(pg_result)
      @pg_result = pg_result
    end

    #/******     PGresult INSTANCE METHODS: libpq     ******/
    def result_status
      Libpq.PQresultStatus(@pg_result)
    end

    def res_status(status)
      ret = Libpq.PQresStatus(status)
      # TODO: encoding
      ret
    end

    def result_error_message
      ret = Libpq.PQresultErrorMessage(@pg_result)
      # TODO: encoding
      ret
    end

    def result_error_field(field_code)
      ret = Libpq.PQresultErrorField(@pg_result, field_code)
      # TODO: encoding
      ret
    end

    def clear
      Libpq.PQclear(@pg_result)
      @pg_result = nil
    end

    def ntuples
      Libpq.PQntuples(@pg_result)
    end
    alias_method :num_tuples, :ntuples

    def nfields
      Libpq.PQnfields(@pg_result)
    end
    alias_method :num_fields, :nfields

    def fname(field_num)
      nfields = Libpq.PQnfields(@pg_result)

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "invalid field number #{field_num}"
      end

      Libpq.PQfname(@pg_result, field_num)
    end

    def fnumber(field_name)
      field_num = Libpq.PQnfields(@pg_result, field_name)

      if field_num == -1
        raise ArgumentError, "Unknown field: #{field_name}"
      end

      field_num
    end

    def ftable(field_num)
      nfields = Libpq.PQnfields(@pg_result)

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "Invalid column index: #{field_num}"
      end

      Libpq.PQftable(@pg_result, field_num)
    end

    def ftablecol(field_num)
      nfields = Libpq.PQnfields(@pg_result)

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "Invalid column index: #{field_num}"
      end

      Libpq.PQftablecol(@pg_result, field_num)
    end

    def fformat(field_num)
      nfields = Libpq.PQnfields(@pg_result)

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "Column number is out of range: #{field_num}"
      end

      Libpq.PQfformat(@pg_result, field_num)
    end

    def ftype(field_num)
      nfields = Libpq.PQnfields(@pg_result)

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "invalid field number #{field_num}"
      end

      Libpq.PQftype(@pg_result, field_num)
    end

    def fmod(field_num)
      nfields = Libpq.PQnfields(@pg_result)

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "Column number is out of range: #{field_num}"
      end

      Libpq.PQfmod(@pg_result, field_num)
    end

    def fsize(field_num)
      nfields = Libpq.PQnfields(@pg_result)

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "invalid field number #{field_num}"
      end

      Libpq.PQfsize(@pg_result, field_num)
    end

    def getvalue(tuple_num, field_num)
      ntuples = Libpq.PQntuples(@pg_result)
      nfields = Libpq.PQnfields(@pg_result)

      if tuple_num < 0 || tuple_num >= ntuples
        raise ArgumentError, "invalid tuple number #{tuple_num}"
      end

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "invalid field number #{field_num}"
      end

      return nil if null?(tuple_num, field_num)
      ret = Libpq.PQgetvalue(@pg_result, tuple_num, field_num)
      # TODO: encoding
      ret
    end

    def getisnull(tuple_num, field_num)
      ntuples = Libpq.PQntuples(@pg_result)
      nfields = Libpq.PQnfields(@pg_result)

      if tuple_num < 0 || tuple_num >= ntuples
        raise ArgumentError, "invalid tuple number #{tuple_num}"
      end

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "invalid field number #{field_num}"
      end

      1 == Libpq.PQgetisnull(@pg_result, tuple_num, field_num)
    end

    def getlength(tuple_num, field_num)
      ntuples = Libpq.PQntuples(@pg_result)
      nfields = Libpq.PQnfields(@pg_result)

      if tuple_num < 0 || tuple_num >= ntuples
        raise ArgumentError, "invalid tuple number #{tuple_num}"
      end

      if field_num < 0 || field_num >= nfields
        raise ArgumentError, "invalid field number #{field_num}"
      end

      Libpq.PQgetlength(@pg_result, tuple_num, field_num)
    end

    def nparams
      Libpq.PQnparams(@pg_result)
    end

    def paramtype(param_num)
      Libpq.PQparamtype(@pg_result, param_num)
    end

    def cmd_status
      ret = Libpq.PQcmdStatus(@pg_result)
      # TODO: encoding
      ret
    end

    def cmd_tuples
      Libpq.PQcmdTuples(@pg_result)
    end
    alias_method :cmdtuples, :cmd_tuples

    def oid_value
      oid = Libpq.PQoidValue(@pg_result)
      oid == InvalidOid ? nil : oid
    end

    #/******     PGresult INSTANCE METHODS: other     ******/
    def [](tuple_num)
      ntuples = Libpq.PQntuples(@pg_result)
      nfields = Libpq.PQnfields(@pg_result)

      if tuple_num < 0 || tuple_num >= ntuples
        raise IndexError, "Index #{tuple_num} is out of range"
      end

      tuple = {}

      (0...nfields).each do |field_num|
        field_name = Libpq.PQfname(@pg_result, field_num)
        # TODO: encoding
        if null?(tuple_num, field_num)
          tuple[field_name] = nil
        else
          val = Libpq.PQgetvalue(@pg_result, tuple_num, field_num)
          # TODO: encoding
          tuple[field_name] = val
        end
      end

      tuple
    end

    def each(&block)
      ntuples = Libpq.PQntuples(@pg_result)

      (0...ntuples).map do |tuple_num|
        yield self[tuple_num]
      end

      self
    end

    def fields
      nfields = Libpq.PQnfields(@pg_result)

      (0...nfields).map do |field_num|
        val = Libpq.PQfname(@pg_result, field_num)
        # TODO: encoding
        val
      end
    end

    def values
      ntuples = Libpq.PQntuples(@pg_result)
      nfields = Libpq.PQnfields(@pg_result)

      (0...ntuples).map do |tuple_num|
        tuple = []

        (0...nfields).map do |field_num|
          tuple[field_num] = value_at(tuple_num, field_num)
        end

        tuple
      end
    end

    def column_values(column_index)
      ntuples = Libpq.PQntuples(@pg_result)
      nfields = Libpq.PQnfields(@pg_result)

      if column_index >= nfields
        raise IndexError, "no column #{column_index} in result"
      end

      # TODO: encoding
      (0...ntuples).map do |r|
        Libpq.PQgetvalue(@pg_result, r, column_index)
      end
    end

    def field_values(field_name)
      ntuples = Libpq.PQntuples(@pg_result)
      field_num = Libpq.PQfnumber(@pg_result, field_name)

      if field_num < 0
        raise IndexError, "no such field #{field_name} in result"
      end

      # TODO: encoding
      (0...ntuples).map do |r|
        Libpq.PQgetvalue(@pg_result, r, field_num)
      end
    end

    private

    def value_at(tuple_num, field_num)
      if !null?(tuple_num, field_num)
        Libpq.PQgetvalue(@pg_result, tuple_num, field_num)
      end
    end

    def null?(tuple_num, field_num)
      1 == Libpq.PQgetisnull(@pg_result, tuple_num, field_num)
    end
  end
end

# Backwards-compatible aliases
PGconn    = PG::Connection
PGresult  = PG::Result
PGError   = PG::Error
