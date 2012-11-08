require 'ffi'

# This module is a direct interface to the libpq API. Comments have been
# mostly copied verbatim from the libpq-fe.h header file.
module Libpq
  extend FFI::Library

  ffi_lib "libpq"

  typedef :uint, :oid

  typedef :pointer, :int_array
  typedef :pointer, :string_array
  typedef :pointer, :oid_array
  typedef :pointer, :byte_array # unsigned char*

  typedef :int, :conn_status_type
  typedef :int, :postgres_polling_status_type
  typedef :int, :exec_status_type
  typedef :int, :pg_transaction_status_type
  typedef :int, :pg_verbosity
  typedef :int, :pg_ping

  # Option flags for PQcopyResult
  PG_COPYRES_ATTRS       = 0x01
  PG_COPYRES_TUPLES      = 0x02 # Implies PG_COPYRES_ATTRS
  PG_COPYRES_EVENTS      = 0x04
  PG_COPYRES_NOTICEHOOKS = 0x08

  # We use constants instead of FFI::Enums here, since the
  # pg gem exposes the values to client code.
  module Constants
    InvalidOid = INVALID_OID = 0

    # Identifiers of error message fields.
    # These were hiding in postgres_ext.h instead of
    # libpq-fe.h.
    PG_DIAG_SEVERITY = 'S'
    PG_DIAG_SQLSTATE = 'C'
    PG_DIAG_MESSAGE_PRIMARY = 'M'
    PG_DIAG_MESSAGE_DETAIL = 'D'
    PG_DIAG_MESSAGE_HINT = 'H'
    PG_DIAG_STATEMENT_POSITION = 'P'
    PG_DIAG_INTERNAL_POSITION = 'p'
    PG_DIAG_INTERNAL_QUERY = 'q'
    PG_DIAG_CONTEXT =  'W'
    PG_DIAG_SOURCE_FILE =  'F'
    PG_DIAG_SOURCE_LINE =  'L'
    PG_DIAG_SOURCE_FUNCTION = 'R'

    # enum ConnStatusType
    CONNECTION_OK = 0
    CONNECTION_BAD = 1
    # Non-blocking mode only below here
    CONNECTION_STARTED = 2            # Waiting for connection to be made.
    CONNECTION_MADE = 3               # Connection OK; waiting to send.
    CONNECTION_AWAITING_RESPONSE = 4  # Waiting for a response from the postmaster.
    CONNECTION_AUTH_OK = 5            # Received authentication; waiting for backend startup.
    CONNECTION_SETENV = 6             # Negotiating environment
    CONNECTION_SSL_STARTUP = 7        # Negotiating SSL.
    CONNECTION_NEEDED = 8             # Internal state: connect() needed

    # enum PostgresPollingStatusType
    PGRES_POLLING_FAILED = 0
    PGRES_POLLING_READING = 1         # These two indicate that one may
    PGRES_POLLING_WRITING = 2         # use select before polling again.
    PGRES_POLLING_OK = 3
    PGRES_POLLING_ACTIVE = 4          # unused; keep for awhile for backwards compatibility

    # enum ExecStatusType
    PGRES_EMPTY_QUERY = 0             # empty query string was executed
    PGRES_COMMAND_OK = 1              # a query command that doesn't return
                                      # anything was executed properly by the
                                      # backend
    PGRES_TUPLES_OK = 2               # a query command that returns tuples was
                                      # executed properly by the backend, PGresult
                                      # contains the result tuples
    PGRES_COPY_OUT = 3                # Copy Out data transfer in progress
    PGRES_COPY_IN = 4                 # Copy In data transfer in progress
    PGRES_BAD_RESPONSE = 5            # an unexpected response was recv'd from the backend
    PGRES_NONFATAL_ERROR = 6          # notice or warning message
    PGRES_FATAL_ERROR = 7             # query failed
    PGRES_COPY_BOTH = 8               # Copy In/Out data transfer in progress
    PGRES_SINGLE_TUPLE = 9            # single tuple from larger resultset

    # enum PGTransactionStatusType
    PQTRANS_IDLE = 0                  # connection idle
    PQTRANS_ACTIVE = 1                # command in progress
    PQTRANS_INTRANS = 2               # idle, within transaction block
    PQTRANS_INERROR = 3               # idle, within failed transaction
    PQTRANS_UNKNOWN = 4               # cannot determine status

    # enum PGVerbosity
    PQERRORS_TERSE = 0                # single-line error messages
    PQERRORS_DEFAULT = 1              # recommended style
    PQERRORS_VERBOSE = 2              # all the facts, ma'am

    # enum PGPing
    PQPING_OK = 0                     # server is accepting connections
    PQPING_REJECT = 1                 # server is alive but rejecting connections
    PQPING_NO_RESPONSE = 2            # could not establish connection
    PQPING_NO_ATTEMPT = 3             # connection not attempted (bad params)
  end
  include Constants

  # FILE*
  typedef :pointer, :stream

  # PGconn encapsulates a connection to the backend.
  # The contents of this struct are not supposed to be known to applications.
  typedef :pointer, :pg_conn

  # PGresult encapsulates the result of a query (or more precisely, of a single
  # SQL command --- a query string given to PQsendQuery can contain multiple
  # commands and thus return multiple PGresult objects).
  # The contents of this struct are not supposed to be known to applications.
  typedef :pointer, :pg_result

  # PGcancel encapsulates the information needed to cancel a running
  # query on an existing connection.
  # The contents of this struct are not supposed to be known to applications.
  typedef :pointer, :pg_cancel

  # PGnotify represents the occurrence of a NOTIFY message.
  # Ideally this would be an opaque typedef, but it's so simple that it's
  # unlikely to change.
  # NOTE: in Postgres 6.4 and later, the be_pid is the notifying backend's,
  # whereas in earlier versions it was always your own backend's PID.
  typedef :pointer, :pg_notify

  class PGNotify < FFI::Struct
    layout :relname, :string,      # notification condition name
           :be_pid,  :int,        # process ID of notifying server process
           :extra,   :string,      # notification parameter
           # Fields below here are private to libpq; apps should not use 'em
           :next,   :pg_notify     # list link
  end

  # Function types for notice-handling callbacks
  callback :pq_notice_receiver, [:pointer, :pg_result], :void
  callback :pq_notice_processor, [:pointer, :string], :void

  # Print options for PQprint()
  typedef :char, :pqbool

  class PQPrintOpt < FFI::Struct
    layout :header,       :pqbool,      # print output field headings and row count
           :align,        :pqbool,      # fill align the fields
           :standard,     :pqbool,      # old brain dead format
           :html3,        :pqbool,      # output html tables
           :expanded,     :pqbool,      # expand tables
           :pager,        :pqbool,      # use pager for output if needed
           :field_sep,    :string,      # field separator
           :table_opt,    :string,      # insert to HTML <table ...>
           :caption,      :string,      # HTML <caption>
           :field_names,  :string_array # null terminated array of replacement field names
  end

  typedef :pointer, :pq_print_opt

  # Structure for the conninfo parameter definitions returned by PQconndefaults
  # or PQconninfoParse.
  #
  # All fields except "val" point at static strings which must not be altered.
  # "val" is either NULL or a malloc'd current-value string.  PQconninfoFree()
  # will release both the val strings and the PQconninfoOption array itself.
  class PQconninfoOption < FFI::Struct
    layout :keyword,  :string,
           :envvar,   :string,
           :compiled, :string,
           :val,      :string,
           :label,    :string,
           :dispchar, :string,
           :dispsize, :int

    def to_h
      {
        :keyword => self[:keyword],
        :envvar => self[:envvar],
        :compiled => self[:compiled],
        :val => self[:val],
        :label => self[:label],
        :dispchar => self[:dispchar],
        :dispsize => self[:dispsize]
      }
    end
  end
  typedef :pointer, :pq_conninfo_option
  typedef :pointer, :pq_conninfo_option_array

  # PQArgBlock -- structure for PQfn() arguments
  class PQArgBlockU < FFI::Union
    layout :ptr,     :pointer,
           :integer, :int
  end

  class PQArgBlock < FFI::Struct
    layout :len,   :int,
           :isint, :int,
           :u,     PQArgBlockU
  end

  typedef :pointer, :pq_arg_block

  #PGresAttDesc -- Data about a single attribute (column) of a query result
  class PGresAttDesc < FFI::Struct
    layout :name,       :string,      # column name
           :tableid,    :oid,         # source table, if known
           :columnid,   :int,         # source column, if known
           :format,     :int,         # format code for value (text/binary)
           :typid,      :oid,         # type id
           :typlen,     :int,         # type size
           :atttypemod, :int          # type-specific modifier info
  end

  typedef :pointer, :pgres_att_desc_array

  # make a new client connection to the backend
  # Asynchronous (non-blocking)
  attach_function :PQconnectStart, [:string], :pg_conn
  attach_function :PQconnectStartParams, [
    :string_array,
    :string_array,
    :int
  ], :pg_conn
  attach_function :PQconnectPoll, [:pg_conn], :postgres_polling_status_type

  # Synchronous (blocking)
  attach_function :PQconnectdb, [:string], :pg_conn
  attach_function :PQconnectdbParams, [:pointer, :pointer, :int], :pg_conn
  attach_function :PQsetdbLogin, [
    :string, # pghost
    :string, # pgport
    :string, # pgoptions
    :string, # pgtty
    :string, # dbName
    :string, # login
    :string  # pwd
  ], :pg_conn

  def self.PQsetdb(host, port, pgopt, pgtty, dbname)
    PQsetdbLogin(host, port, pgopt, pgtty, dbname, nil, nil)
  end

  # close the current connection and free the PGconn data structure
  attach_function :PQfinish, [:pg_conn], :void

  # get info about connection options known to PQconnectdb
  attach_function :PQconndefaults, [], :pq_conninfo_option_array

  # parse connection options in same way as PQconnectdb
  attach_function :PQconninfoParse, [:string, :string_array], :pq_conninfo_option

  # free the data structure returned by PQconndefaults() or PQconninfoParse()
  attach_function :PQconninfoFree, [:pq_conninfo_option], :void

  # close the current connection and restablish a new one with the same
  # parameters
  #
  # Asynchronous (non-blocking)
  attach_function :PQresetStart, [:pg_conn], :int
  attach_function :PQresetPoll, [:pg_conn], :postgres_polling_status_type

  # Synchronous (blocking)
  attach_function :PQreset, [:pg_conn], :void

  # request a cancel structure
  attach_function :PQgetCancel, [:pg_conn], :pg_cancel

  # free a cancel structure
  attach_function :PQfreeCancel, [:pg_cancel], :void

  # issue a cancel request
  attach_function :PQcancel, [:pg_cancel, :string, :int], :int

  # backwards compatible version of PQcancel; not thread-safe
  attach_function :PQrequestCancel, [:pg_conn], :int

  # Accessor functions for PGconn objects
  attach_function :PQdb, [:pg_conn], :string
  attach_function :PQuser, [:pg_conn], :string
  attach_function :PQpass, [:pg_conn], :string
  attach_function :PQhost, [:pg_conn], :string
  attach_function :PQport, [:pg_conn], :string
  attach_function :PQtty, [:pg_conn], :string
  attach_function :PQoptions, [:pg_conn], :string
  attach_function :PQstatus, [:pg_conn], :conn_status_type
  attach_function :PQtransactionStatus, [:pg_conn], :pg_transaction_status_type
  attach_function :PQparameterStatus, [:pg_conn, :string], :string
  attach_function :PQprotocolVersion, [:pg_conn], :int
  attach_function :PQserverVersion, [:pg_conn], :int
  attach_function :PQerrorMessage, [:pg_conn], :string
  attach_function :PQsocket, [:pg_conn], :int
  attach_function :PQbackendPID, [:pg_conn], :int
  attach_function :PQconnectionNeedsPassword, [:pg_conn], :int
  attach_function :PQconnectionUsedPassword, [:pg_conn], :int
  attach_function :PQclientEncoding, [:pg_conn], :int
  attach_function :PQsetClientEncoding, [:pg_conn, :string], :int

  # Get the OpenSSL structure associated with a connection. Returns NULL for
  # unencrypted connections or if any other TLS library is in use.
  attach_function :PQgetssl, [:pg_conn], :pointer

  # Tell libpq whether it needs to initialize OpenSSL
  attach_function :PQinitSSL, [:int], :void

  # More detailed way to tell libpq whether it needs to initialize OpenSSL */
  attach_function :PQinitOpenSSL, [:int, :int], :void

  # Set verbosity for PQerrorMessage and PQresultErrorMessage
  attach_function :PQsetErrorVerbosity, [:pg_conn, :pg_verbosity], :pg_verbosity

  # Enable/disable tracing
  attach_function :PQtrace, [:pg_conn, :stream], :void
  attach_function :PQuntrace, [:pg_conn], :void

  # Override default notice handling routines
  attach_function :PQsetNoticeReceiver, [
    :pg_conn,
    :pq_notice_receiver,
    :pointer
  ], :pq_notice_receiver

  attach_function :PQsetNoticeProcessor, [
    :pg_conn,
    :pq_notice_processor,
    :pointer
  ], :pq_notice_receiver

  # /*
  #  *     Used to set callback that prevents concurrent access to
  #  *     non-thread safe functions that libpq needs.
  #  *     The default implementation uses a libpq internal mutex.
  #  *     Only required for multithreaded apps that use kerberos
  #  *     both within their app and for postgresql connections.
  #  */
  # typedef void (*pgthreadlock_t) (int acquire);
  #
  # attach_function pgthreadlock_t PQregisterThreadLock(pgthreadlock_t newhandler);

  # Simple synchronous query
  attach_function :PQexec, [:pg_conn, :string], :pg_result

  attach_function :PQexecParams, [
    :pg_conn,
    :string,     # command
    :int,        # nParams
    :pointer,    # paramTypes (oid array)
    :pointer,    # paramValues (string array)
    :pointer,    # paramLengths (int array)
    :pointer,    # paramFormats (int array)
    :int         # resultFormat
  ], :pg_result

  attach_function :PQprepare, [
    :pg_conn,
    :string,    # stmtName
    :string,    # query
    :int,       # nParams,
    :oid_array  # paramTypes
  ], :pg_result

  attach_function :PQexecPrepared, [
    :pg_conn,
    :string,        # stmtName
    :int,           # nParams
    :string_array,  # paramValues
    :int_array,     # paramLengths
    :int_array,     # paramFormats
    :int            # resultFormat
  ], :pg_result

  # Interface for multiple-result or asynchronous queries
  attach_function :PQsendQuery, [:pg_conn, :string], :int

  attach_function :PQsendQueryParams, [
    :pg_conn,
    :string,        # command
    :int,           # nParams
    :oid_array,     # paramTypes
    :string_array,  # paramValues
    :int_array,     # paramLengths
    :int_array,     # paramFormats
    :int            # resultFormat
  ], :int

  attach_function :PQsendPrepare, [
    :pg_conn,
    :string,    # stmtName
    :string,    # query
    :int,       # nParams
    :oid_array  # paramTypes
  ], :int

  attach_function :PQsendQueryPrepared, [
    :pg_conn,
    :string,        # stmtName
    :int,           # nParams
    :string_array,  # paramValues
    :int_array,     # paramLengths
    :int_array,     # paramFormats
    :int            # resultFormat
  ], :int

  attach_function :PQsetSingleRowMode, [:pg_conn], :int
  attach_function :PQgetResult, [:pg_conn], :pg_result

  # Routines for managing an asynchronous query
  attach_function :PQisBusy, [:pg_conn], :int
  attach_function :PQconsumeInput, [:pg_conn], :int

  # LISTEN/NOTIFY support
  attach_function :PQnotifies, [:pg_conn], :pg_notify

  # Routines for copy in/out
  attach_function :PQputCopyData, [:pg_conn, :string, :int], :int
  attach_function :PQputCopyEnd,  [:pg_conn, :string], :int
  attach_function :PQgetCopyData, [:pg_conn, :pointer, :int], :int

  # Deprecated routines for copy in/out
  # extern int  PQgetline(PGconn *conn, char *string, int length)
  # extern int  PQputline(PGconn *conn, const char *string);
  # extern int  PQgetlineAsync(PGconn *conn, char *buffer, int bufsize);
  # extern int  PQputnbytes(PGconn *conn, const char *buffer, int nbytes);
  # extern int  PQendcopy(PGconn *conn);

  # Set blocking/nonblocking connection to the backend
  attach_function :PQsetnonblocking, [:pg_conn, :int], :int
  attach_function :PQisnonblocking, [:pg_conn], :int
  attach_function :PQisthreadsafe, [], :int
  attach_function :PQping, [:string], :pg_ping
  attach_function :PQpingParams, [:string_array, :string_array, :int], :pg_ping

  # Force the write buffer to be written (or at least try)
  attach_function :PQflush, [:pg_conn], :int

  # "Fast path" interface --- not really recommended for application use
  attach_function :PQfn, [:pg_conn, :int, :pointer, :pointer, :int, :pq_arg_block, :int], :pg_result

  # Accessor functions for PGresult objects
  attach_function :PQresultStatus,        [:pg_result], :exec_status_type
  attach_function :PQresStatus,           [:exec_status_type], :string
  attach_function :PQresultErrorMessage,  [:pg_result], :string
  attach_function :PQresultErrorField,    [:pg_result, :int], :string
  attach_function :PQntuples,             [:pg_result], :int
  attach_function :PQnfields,             [:pg_result], :int
  attach_function :PQbinaryTuples,        [:pg_result], :int
  attach_function :PQfname,               [:pg_result, :int], :string
  attach_function :PQfnumber,             [:pg_result, :string], :int
  attach_function :PQftable,              [:pg_result, :int], :oid
  attach_function :PQftablecol,           [:pg_result, :int], :int
  attach_function :PQfformat,             [:pg_result, :int], :int
  attach_function :PQftype,               [:pg_result, :int], :oid
  attach_function :PQfsize,               [:pg_result, :int], :int
  attach_function :PQfmod,                [:pg_result, :int], :int
  attach_function :PQcmdStatus,           [:pg_result], :string
  attach_function :PQoidStatus,           [:pg_result], :string
  attach_function :PQoidValue,            [:pg_result], :oid
  attach_function :PQcmdTuples,           [:pg_result], :string
  attach_function :PQgetvalue,            [:pg_result, :int, :int], :string
  attach_function :PQgetlength,           [:pg_result, :int, :int], :int
  attach_function :PQgetisnull,           [:pg_result, :int, :int], :int
  attach_function :PQnparams,             [:pg_result], :int
  attach_function :PQparamtype,           [:pg_result, :int], :oid

  # Describe prepared statements and portals
  attach_function :PQdescribePrepared,      [:pg_conn, :string], :pg_result
  attach_function :PQdescribePortal,        [:pg_conn, :string], :pg_result
  attach_function :PQsendDescribePrepared,  [:pg_conn, :string], :int
  attach_function :PQsendDescribePortal,    [:pg_conn, :string], :int

  # /* Delete a PGresult */
  attach_function :PQclear, [:pg_result], :void

  # /* For freeing other alloc'd results, such as PGnotify structs */
  attach_function :PQfreemem, [:pointer], :void

  # /* Exists for backward compatibility.  bjm 2003-03-24 */
  def self.PQfreeNotify(ptr)
    self.PQfreemem(ptr)
  end

  # /* Error when no password was given. */
  # /* Note: depending on this is deprecated; use PQconnectionNeedsPassword(). */
  PQnoPasswordSupplied = "fe_sendauth: no password supplied\n"

  # /* Create and manipulate PGresults */
  attach_function :PQmakeEmptyPGresult, [:pg_conn, :exec_status_type], :pg_result
  attach_function :PQcopyResult,      [:pg_result, :int ], :pg_result
  attach_function :PQsetResultAttrs,  [:pg_result, :int, :pgres_att_desc_array], :int
  attach_function :PQresultAlloc,     [:pg_result, :uint], :pointer
  attach_function :PQsetvalue,        [:pg_result, :int, :int, :string, :int], :int

  # Quoting strings before inclusion in queries.
  attach_function :PQescapeStringConn,  [:pg_conn, :buffer_out, :string, :uint, :pointer], :uint
  attach_function :PQescapeLiteral,     [:pg_conn, :string, :uint ], :string
  attach_function :PQescapeIdentifier,  [:pg_conn, :string, :uint], :string
  attach_function :PQescapeByteaConn,   [:pg_conn, :byte_array, :uint, :pointer], :pointer
  attach_function :PQunescapeBytea,     [:byte_array, :pointer], :byte_array

  # These forms are deprecated!
  attach_function :PQescapeString,  [:buffer_out, :string, :uint], :uint
  attach_function :PQescapeBytea,   [:pointer, :uint, :pointer], :pointer

  attach_function :PQprint, [:stream, :pg_result, :pq_print_opt], :void

  # really old printing routines
  attach_function :PQdisplayTuples, [:pg_result, :stream, :int, :string, :int, :int], :void
  attach_function :PQprintTuples,   [:pg_result, :stream, :int, :int, :int], :void

  # Large-object access routines
  attach_function :lo_open,             [:pg_conn, :oid, :int], :int
  attach_function :lo_close,            [:pg_conn, :int], :int
  attach_function :lo_read,             [:pg_conn, :int, :string, :uint], :int
  attach_function :lo_write,            [:pg_conn, :int, :string, :uint], :int
  attach_function :lo_lseek,            [:pg_conn, :int, :int, :int], :int
#  attach_function :lo_lseek64,          [:pg_conn, :int, :int64, :int], :int64
  attach_function :lo_creat,            [:pg_conn, :int], :oid
  attach_function :lo_create,           [:pg_conn, :oid], :oid
  attach_function :lo_tell,             [:pg_conn, :int], :int
#  attach_function :lo_tell64,           [:pg_conn, :int], :int64
  attach_function :lo_truncate,         [:pg_conn, :int, :uint], :int
#  attach_function :lo_truncate64,       [:pg_conn, :int, :int64], :int
  attach_function :lo_unlink,           [:pg_conn, :oid], :int
  attach_function :lo_import,           [:pg_conn, :string ], :oid
  attach_function :lo_import_with_oid,  [:pg_conn, :string, :oid], :oid
  attach_function :lo_export,           [:pg_conn, :oid, :string], :int

  # Get the version of the libpq library in use
  attach_function :PQlibVersion, [], :int

  # Determine length of multibyte encoded char at *s
  attach_function :PQmblen, [:string, :int], :int

  # Determine display length of multibyte encoded char at *s
  attach_function :PQdsplen, [:string, :int], :int  #

  # Get encoding id from environment variable PGCLIENTENCODING
  attach_function :PQenv2encoding, [], :int

  attach_function :PQencryptPassword, [:string, :string], :string

  attach_function :pg_char_to_encoding, [:string], :int
  attach_function :pg_encoding_to_char, [:int], :string
  attach_function :pg_valid_server_encoding_id, [:int], :int
end
