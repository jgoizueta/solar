module Solar
  class <<self
    # Sun horizontal coordinates (relative position) in degrees:
    #
    # * +elevation+ (altitude over horizon) in degrees; positive upwards
    # * +azimuth+ in degrees measured clockwise (towards East) from North direction
    #
    def position(t, longitude, latitude)

      delta_rad, alpha_rad = equatorial_position_rad(t)
      alpha_deg = to_deg(alpha_rad)
      # alpha_h += 360 if alpha_h < 0

      # t as Julian centuries of 36525 ephemeris days form the epoch J2000.0
      if false
        # Float
        jd = jd_f(t)
      else
        # Rational
        jd = jd_r(t)
      end
      t = to_jc(jd)

      # Sidereal time at Greenwich
      theta = 280.46061837 +
              360.98564736629*(jd - 2_451_545) +
              (0.000387933 - t/38_710_000)*t*t

      # Reduce magnitude to minimize errors
      theta %= 360

      # Local hour angle
      h = theta + longitude - alpha_deg
      h %= 360

      latitude_rad = to_rad(latitude)
      h_rad = to_rad(h)

      # Local horizontal coordinates : Meeus pg 89
      altitude_rad = Math.asin(Math.sin(latitude_rad)*Math.sin(delta_rad) +
                     Math.cos(latitude_rad)*Math.cos(delta_rad)*Math.cos(h_rad))
      azimuth_rad = Math.atan2(
        Math.sin(h_rad),
        Math.cos(h_rad) * Math.sin(latitude_rad) -
        Math.tan(delta_rad) * Math.cos(latitude_rad)
      )

      [to_deg(altitude_rad), (180 + to_deg(azimuth_rad)) % 360]
    end
  end
end
