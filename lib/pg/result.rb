module PG
  class Result
    include Enumerable
    include Constants

    def self.checked(pg_result, connection)
      result = new(pg_result, connection)
      result.check
      result
    end

    def initialize(pg_result, connection)
      @pg_result = pg_result
      @connection = connection
      #TODO: encoding
    end

    def check
      if @pg_result.null?
        #TODO: encoding
        error = @connection.error_message
      else
        if success?
          return nil
        else
          error = result_error_message
        end
      end

      raise PG::Error.new error, @connection, self
    end

    def success?
      case result_status
        when PGRES_TUPLES_OK,
             PGRES_COPY_OUT,
             PGRES_COPY_IN,
             PGRES_COPY_BOTH,
             PGRES_SINGLE_TUPLE,
             PGRES_EMPTY_QUERY,
             PGRES_COMMAND_OK
          return true
        when PGRES_BAD_RESPONSE,
             PGRES_FATAL_ERROR,
             PGRES_NONFATAL_ERROR
          return false
      end
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

    def error_message
      ret = Libpq.PQresultErrorMessage(@pg_result)
      # TODO: encoding
      ret
    end
    alias_method :result_error_message, :error_message

    def error_field(field_code)
      ret = Libpq.PQresultErrorField(@pg_result, field_code)
      # TODO: encoding
      ret
    end
    alias_method :result_error_field, :error_field

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

      # TODO: encoding
      value_at(tuple_num, field_num)
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
          # TODO: encoding
          tuple[field_name] = value_at(tuple_num, field_num)
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
      # TODO: not exactly the right error here, need to copy
      # whatever NUM2INT does.
      PG::Error.check_type(column_index, Fixnum)
      ntuples = Libpq.PQntuples(@pg_result)
      nfields = Libpq.PQnfields(@pg_result)

      if column_index >= nfields
        raise IndexError, "no column #{column_index} in result"
      end

      # TODO: encoding
      (0...ntuples).map do |r|
        value_at(r, column_index)
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
        value_at(r, field_num)
      end
    end

    private

    def value_at(tuple_num, field_num)
      if !null?(tuple_num, field_num)
        value_ptr = Libpq.PQgetvalue(@pg_result, tuple_num, field_num)
        value_len = getlength(tuple_num, field_num)

        value = value_ptr.get_bytes(0, value_len)
      end
    end

    def null?(tuple_num, field_num)
      1 == Libpq.PQgetisnull(@pg_result, tuple_num, field_num)
    end
  end
end

PGresult = PG::Result

