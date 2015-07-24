# Solar

Solar position & radiation calculations.

This gem provides functions to compute solar position, rise & set times for a given position & time,
as weel as solar radiation and radiation on a sloped surface.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'solar'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install solar

## Examples

### Compute solar passages at a date and Earth's position.

The position is specified as longitude and latitude in degrees:

```ruby
longitude =  1.5 # 1 degree 30 minutes East
latitude  = 42.0 # 42 degrees North
```

The date as a `Date` object:
```ruby
date = Date.new(2014, 3, 22)
```

The `passages` method returns the time of sun rise, transit and set.
Transit refers to the moment the sun crosses the local meridian, i.e.
to local solar noon.

```ruby
rise, transit, set = Solar.passages(date, longitude, latitude)
puts rise    # => Sat, 22 Mar 2014 05:54:29 +0000
puts transit # => Sat, 22 Mar 2014 12:00:54 +0000  
puts set     # => Sat, 22 Mar 2014 18:07:51 +0000
```

### Solar position in horizontal coordinates

We can also compute the local relative position of the sun
for a given instant and place.

Now, instead of a `Date` we need to specify a `Time`; e.g.
we can specify the given date at 1 pm like so:

```ruby
time = date.to_time + 13*3600.0
```

The `position` method returns the sun's elevation and azimuth in degrees
at the given time and place:

```ruby
elevation, azimuth = Solar.position(time, longitude, latitude)
puts elevation # => 48.710153789164785
puts azimuth   # => 179.6564173373824
```

Azimuth is measured on the horizontal plane clockwise from North.
Elevation is the measured from the horizontal plane to the Sun.

It's complementary angle is the solar zenith, the angular distance from
the local zenith to the sun:

```ruby
zenith = 90.0 - elevation
puts zenith # => 41.289846210835215
```

### Day and Night

We can query for the day/night situation for a given time and place:

```ruby
situation = Solar.day_or_night(time, longitude, latitude)
puts situation.inspect # => :day
```

This method returns `:day`, `:night` or `:twilight`.
Twilight refers to the period when the sun has set (appears under the hozizon)
but the sky is not completely dark.

```ruby
situation = Solar.day_or_night(Time.utc(2014,3,22,18,10), longitude, latitude)
puts situation.inspect # => :twilight
```

Actually there are different
[definitions of twilight](https://en.wikipedia.org/wiki/Twilight#Definitions)
and you can differentiate between them with the `:detailed` option:

```ruby
situation = Solar.day_or_night(
  Time.utc(2014,3,22,18,10), longitude, latitude, detailed: true
)
puts situation.inspect # => :civil_twilight
situation = Solar.day_or_night(
  Time.utc(2014,3,22,18,40), longitude, latitude, detailed: true
)
puts situation.inspect # => :nautical_twilight
situation = Solar.day_or_night(
  Time.utc(2014,3,22,19,30), longitude, latitude, detailed: true
)
puts situation.inspect # => :astronomical_twilight
situation = Solar.day_or_night(
  Time.utc(2014,3,22,20), longitude, latitude, detailed: true
)
puts situation.inspect # => :night
```

### Solar Radiation

The `radiation` method can compute the radiation (W per square meter)
on at a given time and location on a horizonta plane:

```ruby
global_radiation_h = Solar.radiation(time, longitude, latitude)
puts global_radiation_h # => 1021.7400285752376
```

In this case whe're assuming a *clearness index* of 1.0, i.e.
clear skies.

It can also compute the radiation on an inclined surface, defined by
its slope (angle in degrees from 0--horizontal to 90--vertical)
and aspect (horizontal clockwise angle from North):

```ruby
r = Solar.radiation(time, longitude, latitude, slope: 10, aspect: 0)
puts r # 852.5943696877531
```

But this method was not created to give estimates of the radiation, but
to adjust measures of the global radiation on the horizontal to what
a sloping surface would get. For this, we need to provide the
measured radiation on a horizontal plane as `:global_radiation`:

```ruby
r = Solar.radiation(
  time, longitude, latitude,
  slope: 10, aspect: 0,
  global_radiation: 432
)
puts r # => 410.89951605660417
```

### Pending...

Please refer to the code documentation for more information.

* TODO: explain how to use ActiveSupport date & time methods, time zones, etc.
* TODO: explain the use of zenith/elevations to work with civil/nautical/astronomcial etc.
* TODO: more information about the uses of `radiation`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. Run `bundle exec solar` to use the gem in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/solar. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## Copyright

Copyright (c) 2012-2015 Javier Goizueta. See LICENSE.txt for
further details.
