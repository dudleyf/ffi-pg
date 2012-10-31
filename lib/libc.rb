module Libc
  extend FFI::Library

  ffi_lib FFI::Library::LIBC

  typedef :pointer, :stream # FILE*

  attach_function :dup, [:int], :int
  attach_function :fdopen, [:int, :string], :stream
  attach_function :fclose, [:stream], :void
end
