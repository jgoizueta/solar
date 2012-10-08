require 'helper'

class TestSolar < Test::Unit::TestCase

  should "calculate transits for the required date" do
    d = Date.new(2012,10,7)
    for lon in -360..360
      for lat in -5..5
        lat *= 10
        r,trans,s = Solar.passages(d, lon, lat)
        assert_equal d, trans.utc.to_date, "longitude: #{lon} latitude: #{lat}"
      end
    end
  end

  should "determine if it's day or night" do
    assert_equal :day, Solar.day_or_night(Time.utc(2012,10,7,9,0,0), 0, 42)
    assert_equal :day, Solar.day_or_night(Time.utc(2012,10,7,9,0,0), 0, 42, :detailed=>true)
    assert_equal :day, Solar.day_or_night(Time.utc(2012,10,7,9,0,0), 0, 42, :simple=>true)
    assert_equal :night, Solar.day_or_night(Time.utc(2012,10,7,21,0,0), 0, 42)
    assert_equal :night, Solar.day_or_night(Time.utc(2012,10,7,21,0,0), 0, 42, :detailed=>true)
    assert_equal :night, Solar.day_or_night(Time.utc(2012,10,7,21,0,0), 0, 42, :simple=>true)
    assert_equal :night, Solar.day_or_night(Time.utc(2012,12,7,9,0,0), 0, 89)
    assert_equal :twilight, Solar.day_or_night(Time.utc(2012,10,7,9,0,0), 0, 89)
    assert_equal :day, Solar.day_or_night(Time.utc(2012,12,7,9,0,0), 0, -89)
    assert_equal :day, Solar.day_or_night(Time.utc(2012,10,7,9,0,0), 0, -89)
  end

end
