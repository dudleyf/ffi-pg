require 'ffi'

# This module is a direct interface to the libpq API. Comments have been
# mostly copied verbatim from the libpq-fe.h header file.
module Libpq
  extend FFI::Library

  ffi_lib "libpq"

  typedef :uint, :oid

  # 
  # Option flags for PQcopyResult
  # 
  PG_COPYRES_ATTRS       = 0x01
  PG_COPYRES_TUPLES      = 0x02 # Implies PG_COPYRES_ATTRS
  PG_COPYRES_EVENTS      = 0x04
  PG_COPYRES_NOTICEHOOKS = 0x08

  # Application-visible enum types

  enum :conn_status_type, [
    :ok,
    :bad,
    # Non-blocking mode only below here
    :started,             # Waiting for connection to be made.
    :made,                # Connection OK; waiting to send.
    :awaiting_response,   # Waiting for a response from the postmaster.
    :auth_ok,             # Received authentication; waiting for backend startup. 
    :setenv,              # Negotiating environment
    :ssl_startup,         # Negotiating SSL.
    :needed               # Internal state: connect() needed
  ]

  enum :postgres_polling_status_type, [
    :failed, 0,
    :reading,        # These two indicate that one may
    :writing,        # use select before polling again.
    :ok,
    :active          # unused; keep for awhile for backwards compatibility
  ]

  enum :exec_status_type, [
    :empty_query, 0,          # empty query string was executed
    :command_ok,              # a query command that doesn't return
                              # anything was executed properly by the
                              # backend
    :tuples_ok,               # a query command that returns tuples was
                              # executed properly by the backend, PGresult
                              # contains the result tuples
    :copy_out,                # Copy Out data transfer in progress
    :copy_in,                 # Copy In data transfer in progress
    :bad_response,            # an unexpected response was recv'd from the backend
    :nonfatal_error,          # notice or warning message
    :fatal_error,             # query failed
    :copy_both,               # Copy In/Out data transfer in progress
    :single_tuple             # single tuple from larger resultset
  ]

  enum :pg_transaction_status_type, [
    :idle,                  # connection idle
    :active,                # command in progress
    :intrans,               # idle, within transaction block
    :inerror,               # idle, within failed transaction
    :unknown                # cannot determine status
  ]

  enum :pg_verbosity, [
    :terse,             # single-line error messages
    :default,           # recommended style
    :verbose            # all the facts, ma'am
  ]

  enum :pg_ping, [
    :ok,              # server is accepting connections
    :reject,          # server is alive but rejecting connections
    :no_response,     # could not establish connection
    :no_attempt       # connection not attempted (bad params)
  ]

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
  	layout :relname, :string,	    # notification condition name
  	       :be_pid,  :int,			  # process ID of notifying server process
  	       :extra,   :string,			# notification parameter
  	       # Fields below here are private to libpq; apps should not use 'em
  	       :next,   :pg_notify 		# list link
  end

  # Function types for notice-handling callbacks
  callback :pq_notice_receiver, [:pointer, :pg_result], :void
  callback :pq_notice_processor, [:pointer, :string], :void

  # Print options for PQprint()
  typedef :char, :pqbool

  class PQPrintOpt < FFI::Struct
    layout :header,       :pqbool,    # print output field headings and row count
           :align,        :pqbool,    # fill align the fields
           :standard,     :pqbool,    # old brain dead format
           :html3,        :pqbool,    # output html tables
           :expanded,     :pqbool,    # expand tables
           :pager,        :pqbool,    # use pager for output if needed
           :field_sep,    :string,    # field separator
           :table_opt,    :string,    # insert to HTML <table ...>
           :caption,      :string,    # HTML <caption>
           :field_names,  :pointer    # null terminated array of replacement field names
  end

  # ----------------
  # Structure for the conninfo parameter definitions returned by PQconndefaults
  # or PQconninfoParse.
  #
  # All fields except "val" point at static strings which must not be altered.
  # "val" is either NULL or a malloc'd current-value string.  PQconninfoFree()
  # will release both the val strings and the PQconninfoOption array itself.
  # ----------------
  class PQconninfoOption < FFI::Struct
    layout :keyword,  :string,
           :envvar,   :string,
           :compiled, :string,
           :val,      :string,
           :label,    :string,
           :dispchar, :string,
           :dispsize, :int
  end

  typedef :pointer, :pq_conninfo_option


  # ----------------
  # PQArgBlock -- structure for PQfn() arguments
  # ----------------
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

  #----------------
  #PGresAttDesc -- Data about a single attribute (column) of a query result
  #----------------
  class PGresAttDesc < FFI::Struct
    layout :name,       :string,      # column name
           :tableid,    :oid,         # source table, if known
           :columnid,   :int,         # source column, if known
           :format,     :int,         # format code for value (text/binary)
           :typid,      :oid,         # type id
           :typlen,     :int,         # type size
           :atttypemod, :int          # type-specific modifier info
  end

  # make a new client connection to the backend
  # Asynchronous (non-blocking)
  attach_function :PQconnectStart, [:string], :pg_conn
  attach_function :PQconnectStartParams, [:pointer, :pointer, :int], :pg_conn
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
  attach_function :PQconndefaults, [], :pq_conninfo_option
  
  # parse connection options in same way as PQconnectdb
  attach_function :PQconninfoParse, [:string, :pointer], :pq_conninfo_option

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

  # /* Accessor functions for PGconn objects */
  attach_function :PQdb,      [:pg_conn], :string
  attach_function :PQuser,    [:pg_conn], :string
  attach_function :PQpass,    [:pg_conn], :string
  attach_function :PQhost,    [:pg_conn], :string
  attach_function :PQport,    [:pg_conn], :string
  attach_function :PQtty,     [:pg_conn], :string
  attach_function :PQoptions, [:pg_conn], :string
  attach_function :PQstatus,  [:pg_conn], :conn_status_type

  # extern PGTransactionStatusType PQtransactionStatus(const PGconn *conn);
  # extern const char *PQparameterStatus(const PGconn *conn,
  #           const char *paramName);
  # extern int  PQprotocolVersion(const PGconn *conn);
  # extern int  PQserverVersion(const PGconn *conn);
  # extern char *PQerrorMessage(const PGconn *conn);
  # extern int  PQsocket(const PGconn *conn);
  # extern int  PQbackendPID(const PGconn *conn);
  # extern int  PQconnectionNeedsPassword(const PGconn *conn);
  # extern int  PQconnectionUsedPassword(const PGconn *conn);
  # extern int  PQclientEncoding(const PGconn *conn);
  # extern int  PQsetClientEncoding(PGconn *conn, const char *encoding);
  # 
  # /* Get the OpenSSL structure associated with a connection. Returns NULL for
  #  * unencrypted connections or if any other TLS library is in use. */
  # extern void *PQgetssl(PGconn *conn);
  # 
  # /* Tell libpq whether it needs to initialize OpenSSL */
  # extern void PQinitSSL(int do_init);
  # 
  # /* More detailed way to tell libpq whether it needs to initialize OpenSSL */
  # extern void PQinitOpenSSL(int do_ssl, int do_crypto);
  # 
  # /* Set verbosity for PQerrorMessage and PQresultErrorMessage */
  # extern PGVerbosity PQsetErrorVerbosity(PGconn *conn, PGVerbosity verbosity);
  # 
  # /* Enable/disable tracing */
  # extern void PQtrace(PGconn *conn, FILE *debug_port);
  # extern void PQuntrace(PGconn *conn);
  # 
  # /* Override default notice handling routines */
  # extern PQnoticeReceiver PQsetNoticeReceiver(PGconn *conn,
  #           PQnoticeReceiver proc,
  #           void *arg);
  # extern PQnoticeProcessor PQsetNoticeProcessor(PGconn *conn,
  #            PQnoticeProcessor proc,
  #            void *arg);
  # 
  # /*
  #  *     Used to set callback that prevents concurrent access to
  #  *     non-thread safe functions that libpq needs.
  #  *     The default implementation uses a libpq internal mutex.
  #  *     Only required for multithreaded apps that use kerberos
  #  *     both within their app and for postgresql connections.
  #  */
  # typedef void (*pgthreadlock_t) (int acquire);
  # 
  # extern pgthreadlock_t PQregisterThreadLock(pgthreadlock_t newhandler);
  # 
  # /* === in fe-exec.c === */
  # 
  # /* Simple synchronous query */
  # extern PGresult *PQexec(PGconn *conn, const char *query);
  attach_function :PQexec, [:pg_conn, :string], :pg_result

  # extern PGresult *PQexecParams(PGconn *conn,
  #        const char *command,
  #        int nParams,
  #        const Oid *paramTypes,
  #        const char *const * paramValues,
  #        const int *paramLengths,
  #        const int *paramFormats,
  #        int resultFormat);
  # extern PGresult *PQprepare(PGconn *conn, const char *stmtName,
  #       const char *query, int nParams,
  #       const Oid *paramTypes);
  # extern PGresult *PQexecPrepared(PGconn *conn,
  #          const char *stmtName,
  #          int nParams,
  #          const char *const * paramValues,
  #          const int *paramLengths,
  #          const int *paramFormats,
  #          int resultFormat);
  # 
  # /* Interface for multiple-result or asynchronous queries */
  # extern int  PQsendQuery(PGconn *conn, const char *query);
  # extern int PQsendQueryParams(PGconn *conn,
  #           const char *command,
  #           int nParams,
  #           const Oid *paramTypes,
  #           const char *const * paramValues,
  #           const int *paramLengths,
  #           const int *paramFormats,
  #           int resultFormat);
  # extern int PQsendPrepare(PGconn *conn, const char *stmtName,
  #         const char *query, int nParams,
  #         const Oid *paramTypes);
  # extern int PQsendQueryPrepared(PGconn *conn,
  #           const char *stmtName,
  #           int nParams,
  #           const char *const * paramValues,
  #           const int *paramLengths,
  #           const int *paramFormats,
  #           int resultFormat);
  # extern int  PQsetSingleRowMode(PGconn *conn);
  # extern PGresult *PQgetResult(PGconn *conn);
  # 
  # /* Routines for managing an asynchronous query */
  # extern int  PQisBusy(PGconn *conn);
  # extern int  PQconsumeInput(PGconn *conn);
  # 
  # /* LISTEN/NOTIFY support */
  # extern PGnotify *PQnotifies(PGconn *conn);
  # 
  # /* Routines for copy in/out */
  # extern int  PQputCopyData(PGconn *conn, const char *buffer, int nbytes);
  # extern int  PQputCopyEnd(PGconn *conn, const char *errormsg);
  # extern int  PQgetCopyData(PGconn *conn, char **buffer, int async);
  # 
  # /* Deprecated routines for copy in/out */
  # extern int  PQgetline(PGconn *conn, char *string, int length);
  # extern int  PQputline(PGconn *conn, const char *string);
  # extern int  PQgetlineAsync(PGconn *conn, char *buffer, int bufsize);
  # extern int  PQputnbytes(PGconn *conn, const char *buffer, int nbytes);
  # extern int  PQendcopy(PGconn *conn);
  # 
  # /* Set blocking/nonblocking connection to the backend */
  # extern int  PQsetnonblocking(PGconn *conn, int arg);
  # extern int  PQisnonblocking(const PGconn *conn);
  # extern int  PQisthreadsafe(void);
  # extern PGPing PQping(const char *conninfo);
  # extern PGPing PQpingParams(const char *const * keywords,
  #        const char *const * values, int expand_dbname);
  # 
  # /* Force the write buffer to be written (or at least try) */
  # extern int  PQflush(PGconn *conn);
  # 
  # /*
  #  * "Fast path" interface --- not really recommended for application
  #  * use
  #  */
  # extern PGresult *PQfn(PGconn *conn,
  #    int fnid,
  #    int *result_buf,
  #    int *result_len,
  #    int result_is_int,
  #    const PQArgBlock *args,
  #    int nargs);
  #
  attach_function :PQfn, [
    :pg_conn,
    :int,
    :pointer,
    :pointer,
    :int,
    :pq_arg_block,
    :int
  ], :pg_result

  attach_function :PQresultStatus, [:pg_result], :exec_status_type
  attach_function :PQresStatus, [:exec_status_type], :string
  attach_function :PQresultErrorMessage, [:pg_result], :string
  attach_function :PQresultErrorField, [:pg_result, :int], :string
  attach_function :PQntuples, [:pg_result], :int
  attach_function :PQnfields, [:pg_result], :int
  attach_function :PQbinaryTuples, [:pg_result], :int
  attach_function :PQfname, [:pg_result, :int], :string
  attach_function :PQfnumber, [:pg_result, :string], :int
  attach_function :PQftable, [:pg_result, :int], :oid
  attach_function :PQftablecol, [:pg_result, :int], :int
  attach_function :PQfformat, [:pg_result, :int], :int
  attach_function :PQftype, [:pg_result, :int], :oid
  attach_function :PQfsize, [:pg_result, :int], :int
  attach_function :PQfmod, [:pg_result, :int], :int
  attach_function :PQcmdStatus, [:pg_result], :string
  attach_function :PQoidStatus, [:pg_result], :string
  attach_function :PQoidValue, [:pg_result], :oid
  attach_function :PQcmdTuples, [:pg_result], :string
  attach_function :PQgetvalue, [:pg_result, :int, :int], :string
  attach_function :PQgetlength, [:pg_result, :int, :int], :int
  attach_function :PQgetisnull, [:pg_result, :int, :int], :int
  attach_function :PQnparams, [:pg_result], :int
  attach_function :PQparamtype, [:pg_result, :int], :oid

  # /* Describe prepared statements and portals */
  # extern PGresult *PQdescribePrepared(PGconn *conn, const char *stmt);
  # extern PGresult *PQdescribePortal(PGconn *conn, const char *portal);
  # extern int  PQsendDescribePrepared(PGconn *conn, const char *stmt);
  # extern int  PQsendDescribePortal(PGconn *conn, const char *portal);
  # 
  # /* Delete a PGresult */
  # extern void PQclear(PGresult *res);
  # 
  # /* For freeing other alloc'd results, such as PGnotify structs */
  # extern void PQfreemem(void *ptr);
  # 
  # /* Exists for backward compatibility.  bjm 2003-03-24 */
  # #define PQfreeNotify(ptr) PQfreemem(ptr)
  # 
  # /* Error when no password was given. */
  # /* Note: depending on this is deprecated; use PQconnectionNeedsPassword(). */
  # #define PQnoPasswordSupplied  "fe_sendauth: no password supplied\n"
  # 
  # /* Create and manipulate PGresults */
  # extern PGresult *PQmakeEmptyPGresult(PGconn *conn, ExecStatusType status);
  # extern PGresult *PQcopyResult(const PGresult *src, int flags);
  # extern int  PQsetResultAttrs(PGresult *res, int numAttributes, PGresAttDesc *attDescs);
  # extern void *PQresultAlloc(PGresult *res, size_t nBytes);
  # extern int  PQsetvalue(PGresult *res, int tup_num, int field_num, char *value, int len);
  # 
  # /* Quoting strings before inclusion in queries. */
  # extern size_t PQescapeStringConn(PGconn *conn,
  #            char *to, const char *from, size_t length,
  #            int *error);
  # extern char *PQescapeLiteral(PGconn *conn, const char *str, size_t len);
  # extern char *PQescapeIdentifier(PGconn *conn, const char *str, size_t len);
  # extern unsigned char *PQescapeByteaConn(PGconn *conn,
  #           const unsigned char *from, size_t from_length,
  #           size_t *to_length);
  # extern unsigned char *PQunescapeBytea(const unsigned char *strtext,
  #         size_t *retbuflen);
  # 
  # /* These forms are deprecated! */
  # extern size_t PQescapeString(char *to, const char *from, size_t length);
  # extern unsigned char *PQescapeBytea(const unsigned char *from, size_t from_length,
  #         size_t *to_length);
  # 
  # 
  # 
  # /* === in fe-print.c === */
  # 
  # extern void PQprint(FILE *fout,        /* output stream */
  #     const PGresult *res,
  #     const PQprintOpt *ps);  /* option structure */
  # 
  # /*
  #  * really old printing routines
  #  */
  # extern void PQdisplayTuples(const PGresult *res,
  #         FILE *fp,    /* where to send the output */
  #         int fillAlign,  /* pad the fields with spaces */
  #         const char *fieldSep,  /* field separator */
  #         int printHeader,  /* display headers? */
  #         int quiet);
  # 
  # extern void PQprintTuples(const PGresult *res,
  #         FILE *fout,    /* output stream */
  #         int printAttName, /* print attribute names */
  #         int terseOutput,  /* delimiter bars */
  #         int width);    /* width of column, if 0, use variable width */
  # 
  # 
  # /* === in fe-lobj.c === */
  # 
  # /* Large-object access routines */
  # extern int  lo_open(PGconn *conn, Oid lobjId, int mode);
  # extern int  lo_close(PGconn *conn, int fd);
  # extern int  lo_read(PGconn *conn, int fd, char *buf, size_t len);
  # extern int  lo_write(PGconn *conn, int fd, const char *buf, size_t len);
  # extern int  lo_lseek(PGconn *conn, int fd, int offset, int whence);
  # extern pg_int64 lo_lseek64(PGconn *conn, int fd, pg_int64 offset, int whence);
  # extern Oid  lo_creat(PGconn *conn, int mode);
  # extern Oid  lo_create(PGconn *conn, Oid lobjId);
  # extern int  lo_tell(PGconn *conn, int fd);
  # extern pg_int64 lo_tell64(PGconn *conn, int fd);
  # extern int  lo_truncate(PGconn *conn, int fd, size_t len);
  # extern int  lo_truncate64(PGconn *conn, int fd, pg_int64 len);
  # extern int  lo_unlink(PGconn *conn, Oid lobjId);
  # extern Oid  lo_import(PGconn *conn, const char *filename);
  # extern Oid  lo_import_with_oid(PGconn *conn, const char *filename, Oid lobjId);
  # extern int  lo_export(PGconn *conn, Oid lobjId, const char *filename);
  # 
  # /* === in fe-misc.c === */
  # 
  # /* Get the version of the libpq library in use */
  # extern int  PQlibVersion(void);
  # 
  # /* Determine length of multibyte encoded char at *s */
  # extern int  PQmblen(const char *s, int encoding);
  # 
  # /* Determine display length of multibyte encoded char at *s */
  # extern int  PQdsplen(const char *s, int encoding);
  # 
  # /* Get encoding id from environment variable PGCLIENTENCODING */
  # extern int  PQenv2encoding(void);
  # 
  # /* === in fe-auth.c === */
  # 
  # extern char *PQencryptPassword(const char *passwd, const char *user);
  # 
  # /* === in encnames.c === */
  # 
  # extern int  pg_char_to_encoding(const char *name);
  # extern const char *pg_encoding_to_char(int encoding);
  # extern int  pg_valid_server_encoding_id(int encoding);
  # 
  # #ifdef __cplusplus
  # }
  # #endif
  # 
  # #endif   /* LIBPQ_FE_H */
  # 
end