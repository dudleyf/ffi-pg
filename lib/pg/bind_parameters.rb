module PG
  class BindParameters
    attr_reader :nparams, :params, :types, :values, :lengths, :formats

    def initialize(params)
      @nparams  = params.length
      @types    = FFI::MemoryPointer.new(:uint, @nparams) # An array of oids
      @values   = FFI::MemoryPointer.new(:pointer, @nparams)
      @lengths  = FFI::MemoryPointer.new(:int, @nparams)
      @formats  = FFI::MemoryPointer.new(:int, @nparams)

      @params = []
      Array(params).each_with_index do |p, i|
        put_param i, BindParameter.new(p)
      end
    end

    def put_param(i, param)
      @params << param
      @types.put_uint(i, param.type)
      @values.put_pointer(i, param.value_ptr)
      @lengths.put_int(i, param.length)
      @formats.put_int(i, param.format)
    end

    alias_method :length, :nparams
  end

  class BindParameter
    attr_reader :type, :value, :format, :value_ptr

    def initialize(str_or_opts)
      @type   = 0
      @format = 0

      if str_or_opts.kind_of?(Hash)
        self.type   = str_or_opts[:type]
        self.value  = str_or_opts[:value]
        self.format = str_or_opts[:format]
      else
        self.value = str_or_opts
      end
    end

    def type=(t)
      @type = t.nil? ? 0 : t.to_i
    end

    def value=(v)
      if v.nil?
        @value = @value_ptr = nil
      else
        @value = v.to_s
        @value_ptr = FFI::MemoryPointer.from_string(@value)
      end

      @value
    end

    def format=(f)
      @format = f.nil? ? 0 : f.to_i
    end

    def length
      @value.nil? ? 0 : @value.length
    end
  end
end
