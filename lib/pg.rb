module PG
  class Error < StandardError; end
end


module PG
  class Connection
  	# The order the options are passed to the ::connect method.
  	CONNECT_ARGUMENT_ORDER = %w[host port options tty dbname user password]


  	### Quote the given +value+ for use in a connection-parameter string.
  	### @param [String] value  the option value to be quoted.
  	### @return [String]
  	def self.quote_connstr( value )
  		return "'" + value.to_s.gsub( /[\\']/ ) {|m| '\\' + m } + "'"
  	end


  	### Parse the connection +args+ into a connection-parameter string
  	### @param [Array<String>] args  the connection parameters
  	### @return [String]  a connection parameters string
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

    def initialize(*args)
      conninfo = self.class.parse_connect_args(*args)

      @conn = Libpq.PQconnectdb(conninfo)

      if @conn.nil?
        raise PG::Error, "PQconnectdb() unable to allocate structure"
      end

      if Libpq.PQstatus(@conn) == :ok
        
      end
    end

    def exec(command, params={}, result_format=0, &block)
      result_ptr = Libpq.PQexec(@conn, command)
      result = Result.new(result_ptr)
    end
    alias_method :query, :exec
  end
end


module PG
  class Result
    def initialize(result)
      @result = result
    end

    def values
      num_rows = Libpq.PQntuples(@result)
      num_fields = Libpq.PQnfields(@result)
      tuples = []

      0.upto(num_rows-1) do |row_idx|
        row = []
        0.upto(num_fields-1) do |field_idx|
          if Libpq.PQgetisnull(@result, row_idx, field_idx) == 0
            row[field_idx] = nil
          else
            val = Libpq.PQgetvalue(@result, row_idx, field_idx)
            row[field_idx] = val
          end
        end
        tuples << row
      end
      tuples
    end
  end
end



# Backwards-compatible aliases
PGconn = PG::Connection
PGresult = PG::Result