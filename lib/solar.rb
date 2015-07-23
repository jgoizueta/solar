require 'active_support'
require 'active_support/time'

# Calculation of solar position, rise & set times for a given position & time.
# Algorithms are taken from Jean Meeus, Astronomical Algorithms
# Some code & ideas taken from John P. Power's astro-algo: http://astro-algo.rubyforge.org/astro-algo/
module Solar
end

require 'solar/support.rb'
require 'solar/passages.rb'
require 'solar/position.rb'
require 'solar/day_night.rb'
require 'solar/radiation.rb'
require 'solar/lambert.rb'
