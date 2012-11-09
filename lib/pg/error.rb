module PG
  class Error < StandardError
    attr_accessor :connection
    attr_accessor :result

    def initialize(message, connection=nil, result=nil)
      super(message)
      @connection = connection
      @result = result
    end

    # Raise a new PG::Error with either the current message from
    # the given connection, or a user-supplied message string.
    def self.for_connection(conn, msg=Libpq.PQerrorMessage(conn))
      raise PG::Error.new(msg, conn)
    end

    def self.check_type(var, type)
      unless var.is_a?(type)
        raise TypeError, "wrong argument type #{var.class} (expected #{type})"
      end
    end
  end
end

PGError = PG::Error

