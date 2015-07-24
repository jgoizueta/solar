require 'helper'

class TestSolar < Minitest::Test
  def test_solar_transits
    d = Date.new(2012,10,7)
    for lon in -360..360
      for lat in -5..5
        lat *= 10
        r,trans,s = Solar.passages(d, lon, lat)
        assert_equal d, trans.utc.to_date, "longitude: #{lon} latitude: #{lat}"
      end
    end
  end

  def test_day_or_night
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

  def test_radiation
    # from [Duffie-1991] Example 1.10.1
    dt = 600.0 # integrate in 10-minute steps
    r = 0.0
    (0...24*3600.0).step(dt) do |h|
      t = Date.new(1991, 4, 15).to_time + h
      r += dt*Solar.radiation(t, 0.0, 43.0, clearness_index: 1.0)*1E-6
    end
    assert_in_delta 33.8, r, 33.8*1E-3
  end
end
