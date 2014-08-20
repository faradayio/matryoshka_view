# MatryoshkaView

Maintains a list of inner (subset/nested) views and their geometic boundaries for a particular table. Helps you spawn new inner views and lookup the right one.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'matryoshka_view'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install matryoshka_view

## Usage

1. create a MatryoshkaView object with the base table name (`MatryoshkaView.new(base: Place)`)
2. maybe try to lookup a view that satisfies a boundary (`MatryoshkaView.new(base: Place).lookup(the_geom_geojson_of_massachusetts)`)
3. maybe create a new view within a boundary (`MatryoshkaView.new(base: Place).spawn(the_geom_geojson_of_boston)`)

## Contributing

1. Fork it ( https://github.com/[my-github-username]/matryoshka_view/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
