# TODO: README

require 'libc'

module PG
  class Connection
    # The order the options are passed to the ::connect method.
    CONNECT_ARGUMENT_ORDER = %w[host port options tty dbname user password]

    ### Quote the given +value+ for use in a connection-parameter string.
    def self.quote_connstr( value )
      return "'" + value.to_s.gsub( /[\\']/ ) {|m| '\\' + m } + "'"
    end

    ### Parse the connection +args+ into a connection-parameter string. See PG::Connection.new
    ### for valid arguments.
    def self.parse_connect_args( *args )
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

    # Backward-compatibility aliases for stuff that's moved into PG.
    class << self
      define_method( :isthreadsafe, &PG.method(:isthreadsafe) )
    end

    # @deprecated
    def self.escape_string(str)
      len = str.length
      buf = FFI::MemoryPointer.new(:char, 2*len+1)

      Libpq.PQescapeString(buf, str, len)

      # TODO: encoding
      buf.read_string
    end
    class << self
      alias_method :escape, :escape_string
    end

    def self.escape_bytea(str)
      from = FFI::MemoryPointer.from_string(str)
      from_len = str.length
      to_len = FFI::MemoryPointer.new(:int)

      to = Libpq.PQescapeBytea(from, from_len, to_len)

      ret = to.read_bytes(to_len.read_int - 1)
      Libpq.PQfreemem(to)
      ret
    end

    def self.unescape_bytea(str)
      from_len = str.length
      to_len = FFI::MemoryPointer.new(:int)

      to = Libpq.PQunescapeBytea(@pg_conn, str, from_len, to_len)

      ret = to.read_bytes(to_len.read_int - 1)
      Libpq.PQfreemem(to)
    end

    def self.encrypt_password(pass, user)
      PG::Error.check_type(user, String)
      PG::Error.check_type(pass, String)

      Libpq.PQencryptPassword(pass, user)
    end

    def self.quote_ident(str)
      '"' + str.gsub(/"/, '""') + '"'
    end

    def self.connect_start(*args, &block)
      instance = allocate
      instance.init_pg_conn_async(*args, &block)
    end

    # call-seq:
    #    PG::Connection.conndefaults() -> Array
    #
    # Returns an array of hashes. Each hash has the keys:
    # [+:keyword+]
    #   the name of the option
    # [+:envvar+]
    #   the environment variable to fall back to
    # [+:compiled+]
    #   the compiled in option as a secondary fallback
    # [+:val+]
    #   the option's current value, or +nil+ if not known
    # [+:label+]
    #   the label for the field
    # [+:dispchar+]
    #   "" for normal, "D" for debug, and "*" for password
    # [+:dispsize+]
    #   field size
    def self.conndefaults
      conndefaults = Libpq.PQconndefaults()
      ret = []
      i = 0

      loop do
        offset = conndefaults + (i * Libpq::PQconninfoOption.size)
        opt = Libpq::PQconninfoOption.new(offset)
        break if opt[:keyword].nil?
        ret << opt.to_h
        i += 1
      end

      ret
    end

    class << self
      alias_method :connect, :new
      alias_method :open, :new
      alias_method :setdb, :new
      alias_method :setdblogin, :new
    end

    def initialize(*args, &block)
      init_pg_conn_sync(*args, &block)
    end

    def init_pg_conn_sync(*args, &block)
      conninfo = self.class.parse_connect_args(*args)

      @pg_conn = Libpq.PQconnectdb(conninfo)

      if @pg_conn.nil?
        raise_pg_error "PQconnectdb() unable to allocate structure"
      end

      if Libpq.PQstatus(@pg_conn) == PG::CONNECTION_BAD
        raise_pg_error
      end

      # TODO: Set client encoding on the connection

      if block_given?
        begin
          yield self
        ensure
          finish
        end
      end

      self
    end

    def init_pg_conn_async(*args, &block)
      conninfo = self.class.parse_connect_args(*args)

      @pg_conn = Libpq.PQconnectStart(conninfo)

      if @pg_conn.nil?
        raise_pg_error "PQconnectStart() unable to allocate structure"
      end

      if Libpq.PQstatus(@pg_conn) == PG::CONNECTION_BAD
        raise_pg_error
      end

      if block_given?
        begin
          yield self
        ensure
          finish
        end
      end

      self
    end

    # /******     PGconn INSTANCE METHODS: Connection Control     ******/
    def connect_poll
      Libpq.PQconnectPoll(@pg_conn)
    end

    def finish
      Libpq.PQfinish(@pg_conn)
      @pg_conn = nil
    end
    alias_method :close, :finish

    def finished?
      @pg_conn.nil?
    end

    def reset
      Libpq.PQreset(@pg_conn)
    end

    def reset_start
      raise_pg_error "reset has failed" if 0 == Libpq.PQresetStart(@pg_conn)
      nil
    end

    def reset_poll
      Libpq.PQresetPoll(@pg_conn)
    end

    def conndefaults
      self.class.conndefaults
    end

    # /******     PGconn INSTANCE METHODS: Connection Status     ******/
    def db
      Libpq.PQdb(@pg_conn)
    end

    def user
      Libpq.PQuser(@pg_conn)
    end

    def pass
      Libpq.PQpass(@pg_conn)
    end

    def host
      Libpq.PQhost(@pg_conn)
    end

    def port
      Libpq.PQhost(@pg_conn)
    end

    def tty
      Libpq.PQtty(@pg_conn)
    end

    def options
      Libpq.PQoptions(@pg_conn)
    end

    def status
      Libpq.PQstatus(@pg_conn)
    end

    def transaction_status
      Libpq.PQtransactionStatus(@pg_conn)
    end

    def parameter_status(param_name)
      Libpq.PQparameterStatus(@pg_conn, param_name)
    end

    def protocol_version
      Libpq.PQprotocolVersion(@pg_conn)
    end

    def server_version
      Libpq.PQserverVersion(@pg_conn)
    end

    def error_message
      Libpq.PQerrorMessage(@pg_conn)
    end

    def socket
      sd = Libpq.PQsocket(@pg_conn)
      raise_pg_error("Can't get socket descriptor") if sd < 0
      sd
    end

    def backend_pid
      Libpq.PQbackendPID(@pg_conn)
    end

    def connection_needs_password
      1 == Libpq.PQconnectionNeedsPassword(@pg_conn)
    end

    def connection_used_password
      1 == Libpq.PQconnectionUsedPassword(@pg_conn)
    end

    def exec(command, params=nil, result_format=0, &block)
      PG::Error.check_type(command, String)

      if params.nil?
        pg_result = Libpq.PQexec(@pg_conn, command)
        result = Result.checked(pg_result, self)
        if block_given?
          begin
            return yield result
          ensure
            result.clear
          end
        end
        return result
      end

      PG::Error.check_type(params, Array)
      p = BindParameters.new(params)
      pg_result = Libpq.PQexecParams(@pg_conn, command, p.length, p.types, p.values, p.lengths, p.formats, result_format)
      result = Result.checked(pg_result, self)

      if block_given?
        begin
          return yield result
        ensure
          result.clear
        end
      end

      result
    end
    alias_method :query, :exec

    # call-seq:
    #    conn.prepare(stmt_name, sql [, param_types ] ) -> PG::Result
    #
    # Prepares statement _sql_ with name _name_ to be executed later.
    # Returns a PG::Result instance on success.
    # On failure, it raises a PG::Error.
    #
    # +param_types+ is an optional parameter to specify the Oids of the
    # types of the parameters.
    #
    # If the types are not specified, they will be inferred by PostgreSQL.
    # Instead of specifying type oids, it's recommended to simply add
    # explicit casts in the query to ensure that the right type is used.
    #
    # For example: "SELECT $1::int"
    #
    # PostgreSQL bind parameters are represented as $1, $1, $2, etc.,
    # inside the SQL query.
    def prepare(name, command, in_paramtypes=nil)
      PG::Error.check_type(name, String)
      PG::Error.check_type(command, String)

      nparams = 0
      param_types = nil
      unless in_paramtypes.nil?
        PG::Error.check_type(in_paramtypes, Array)

        nparams = in_paramtypes.length
        param_types = FFI::MemoryPointer(:oid, nparams)
        param_types.write_array_of_uint(0, in_paramtypes)
      end

      pg_result = Libpq.PQprepare(@pg_conn, name, command, nparams, param_types)
      Result.checked(pg_result, self)
    end

    # call-seq:
    #    conn.exec_prepared(statement_name [, params, result_format ] ) -> PG::Result
    #    conn.exec_prepared(statement_name [, params, result_format ] ) {|pg_result| block }
    #
    # Execute prepared named statement specified by _statement_name_.
    # Returns a PG::Result instance on success.
    # On failure, it raises a PG::Error.
    #
    # +params+ is an array of the optional bind parameters for the
    # SQL query. Each element of the +params+ array may be either:
    #   a hash of the form:
    #     {:value  => String (value of bind parameter)
    #      :format => Fixnum (0 for text, 1 for binary)
    #     }
    #   or, it may be a String. If it is a string, that is equivalent to the hash:
    #     { :value => <string value>, :format => 0 }
    #
    # PostgreSQL bind parameters are represented as $1, $1, $2, etc.,
    # inside the SQL query. The 0th element of the +params+ array is bound
    # to $1, the 1st element is bound to $2, etc. +nil+ is treated as +NULL+.
    #
    # The optional +result_format+ should be 0 for text results, 1
    # for binary.
    #
    # If the optional code block is given, it will be passed <i>result</i> as an argument,
    # and the PG::Result object will  automatically be cleared when the block terminates.
    # In this instance, <code>conn.exec_prepared</code> returns the value of the block.
    def exec_prepared(name, params=[], result_format=0)
      PG::Error.check_type(name, String)
      PG::Error.check_type(params, Array)
      p = BindParameters.new(params)
      pg_result = Libpq.PQexecPrepared(@pg_conn, name, p.length, p.values, p.lengths, p.formats, result_format)
      result = Result.checked(pg_result, self)

      if block_given?
        begin
          return yield result
        ensure
          result.clear
        end
      end

      result
    end

    # call-seq:
    #    conn.describe_prepared( statement_name ) -> PG::Result
    #
    # Retrieve information about the prepared statement
    # _statement_name_.
    def describe_prepared(name)
      PG::Error.check_type(name, String)
      pg_result = Libpq.PQdescribePrepared(@pg_conn, name)
      Result.checked(pg_result, self)
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

    def escape_bytea(str)
      from_len = str.length
      to_len = FFI::MemoryPointer.new(:int)

      to = Libpq.PQescapeByteaConn(@pg_conn, str, from_len, to_len)

      ret = to.read_bytes(to_len.read_int - 1)
      Libpq.PQfreemem(to)
      ret
    end

    def unescape_bytea(str)
      self.class.unescape_bytea(str)
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
    def set_error_verbosity(in_verbosity)
      Libpq.PQsetErrorVerbosity(@pg_conn, in_verbosity)
    end

    def trace(stream)
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
      Libpq.pg_encoding_to_char(Libpq.PQclientEncoding(@pg_conn))
    end

    def set_client_encoding(str)
      PG::Error.check_type(str, String)
      if -1 == Libpq.PQsetClientEncoding(@pg_conn, str)
        raise_pg_error "Invalid encoding name: #{str}"
      end

      nil
    end

    def transaction
      if block_given?
        result = exec("BEGIN")
        result.check
        begin
          yield
        rescue Exception => e
          result = exec("ROLLBACK")
          result.check
          raise e
        else
          result = exec("COMMIT")
          result.check
        end
      else
        raise ArgumentError, "Must supply block for PG::Connection#transaction"
      end

      nil
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

    def raise_pg_error(msg=nil)
      PG::Error.for_connection(@pg_conn, msg)
    end
  end
end

PGconn = PG::Connection
