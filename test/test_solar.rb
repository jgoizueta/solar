require 'helper'

class TestSolar < Test::Unit::TestCase

  should "calculate transits for the required date" do
    d = Date.new(2012,10,7)
    for lon in -360..360
      for lat in -50..50
        r,trans,s = Solar.passages(d, lon, lat)
        assert_equal d, trans.utc.to_date, "longitude: #{lon} latitude: #{lat}"
      end
    end
  end

end
