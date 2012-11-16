# ffi-pg

A pg gem compatible wrapper for libpq using Ruby's FFI. In its current state, this
library implements most of the libpq API. Missing bits:

* Encoding support
* Large objects
* Copy
* trace/untrace

## Deprecated Before Its Time
### In which another gem is abandoned

The initial motivation for this project was to support the pg gem on JRuby, but
https://github.com/headius/jruby-pg.git implements the PostgreSQL protocol in pure
Java, giving us an implementation that doesn't depend on the native libpq library.
A self-contained gem with no native code dependencies sounds like a much better idea
to me, so unless someone has a good reason for sticking with a native code wrapper,
I don't think it makes much sense to keep working on this one.


## Installation

Add this line to your application's Gemfile:

    gem 'ffi-pg'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ffi-pg

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
