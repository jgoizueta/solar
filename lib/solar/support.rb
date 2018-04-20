module Solar

  ALTITUDES = {
    official:     -50/60.0,
    civil:            -6.0,
    nautical:        -12.0,
    astronomical:    -18.0
  }

  class <<self
    private

    # Julian Day as Rational
    def jd_r(t)
      if false
        # This computes JD with precision of seconds and yields smaller denominators
        t = t.utc
        t.to_date.ajd + Rational(t.hour,24) + Rational(t.min,1440) + Rational(t.sec,86_400)
      else
        # This preserves the internal precision of t (which we probably don't need)
        # and produces larger denominators in general
        t.to_datetime.new_offset.ajd
      end
    end

    # Julian Day as Float
    def jd_f(t)
      # t.to_date.ajd.to_f + t.hour/24.0 + t.min/1440.0 + t.sec/86400.0
      t.to_datetime.new_offset.ajd.to_f
    end

    def to_rad(deg)
      deg*Math::PI/180.0
    end

    def to_deg(rad)
      rad*180.0/Math::PI
    end

    def to_h(deg)
      deg/15.0
    end

    # Julian day to Julian Centuries since J2000.0
    def to_jc(jd)
      (jd - 2_451_545)/36_525
    end

    def polynomial(coefficients, x)
      coefficients.inject(0.0) { |p, a| p*x + a }
    end

    # Conversion of Float to Rational preserving the exact value of the number
    def to_r(x)
      x = x.to_f
      return Rational(x.to_i,1) if x.modulo(1) == 0
      if !x.finite?
        return Rational(0,0) if x.nan?
        return x < 0 ? Rational(-1,0) : Rational(1,0)
      end

      f,e = Math.frexp(x)

      if e < Float::MIN_EXP
        bits = e + Float::MANT_DIG - Float::MIN_EXP
      else
        bits = [Float::MANT_DIG, e].max
        # return Rational(x.to_i, 1) if bits < e
      end
      p = Math.ldexp(f,bits)
      e = bits - e
      if e<Float::MAX_EXP
        q = Math.ldexp(1, e)
      else
        q = Float::RADIX**e
      end
      Rational(p.to_i, q.to_i)
    end

    # time to dynamical time
    def to_td(t)
      t = t.utc
      t + to_r(delta_t(t))/86_400
    end

    # dynamical_time to utc
    def to_utc(td)
      raise 'Invalid dynamical time (should be utc)' unless td.utc?
      td - to_r(delta_t(td))/86_400
    end

    # Compute difference between dynamical time and UTC in seconds.
    #
    # See http://sunearth.gsfc.nasa.gov/eclipse/SEcat5/deltatpoly.html.
    #
    # Good from -1999 to +3000.
    #
    def delta_t(date)
      year = date.year.to_f
      y = year + (date.month.to_f - 0.5) / 12.0

      case
      when year < -500.0
        u = (year - 1820.0) / 100.0
        -20.0 + 32.0*u*u
      when year < 500.0
        u = y / 100.0
        polynomial [0.0090316521, 0.022174192, -0.1798452, -5.952053, 33.78311, -1014.41, 10583.6], u
      when year < 1600.0
        u = (y - 1000.0) / 100.0
        polynomial [0.0083572073, -0.005050998, -0.8503463, 0.319781, 71.23472, -556.01, 1574.2], u
      when year < 1700.0
        t = y - 1600.0
        polynomial [1.0/7129.0, -0.01532, -0.9808, 120.0], t
      when year < 1800.0
        t = y - 1700.0
        polynomial [-1.0/1174000.0, 0.00013336, -0.0059285, 0.1603, 8.83], t
      when year < 1860.0
        t = y - 1800.0
        polynomial [0.000000000875, -0.0000001699, 0.0000121272, -0.00037436, 0.0041116, 0.0068612, -0.332447, 13.72], t
      when year < 1900.0
        t = y - 1860.0
        polynomial [1.0/233174.0, -0.0004473624, 0.01680668, -0.251754, 0.5737, 7.62], t
      when year < 1920.0
        t = y - 1900.0
        polynomial [-0.000197, 0.0061966, -0.0598939, 1.494119, -2.79], t
      when year < 1941.0
        t = y - 1920.0
        polynomial [0.0020936, -0.076100, 0.84493, 21.20], t
      when year < 1961.0
        t = y - 1950.0
        polynomial [1.0/2547.0, -1.0/233.0, 0.407, 29.07], t
      when year < 1986.0
        t = y - 1975.0
        polynomial [-1.0/718.0, -1.0/260.0, 1.067, 45.45], t
      when year < 2005.0
        t = y - 2000.0
        polynomial [0.00002373599, 0.000651814, 0.0017275, -0.060374, 0.3345, 63.86], t
      when year < 2050.0
        t = y - 2000.0
        polynomial [0.005589, 0.32217, 62.92], t
      when year < 2150.0
        -20.0 + 32.0*((y - 1820.0)/100.0)**2 - 0.5628*(2150.0 - y)
      else
        u = (year - 1820.0) / 100.0
        -20.0 + 32*u*u
      end
    end

    # Solar equatorial coordinates / Low accuracy : Meeus pg 151
    # returns [declination in radians, right ascension in radians]
    def equatorial_position_rad(t)
      # t as Julian centuries of 36525 ephemeris days form the epoch J2000.0
      if false
        # Float
        jd = jd_f(to_td(t))
      else
        # Rational
        jd = jd_r(to_td(t))
      end
      t = to_jc(jd)

      # Geometric mean longitude of the Sun, referred to the mean equinox of the date
      l = 280.46645 + (36_000.76983 + 0.0003032*t)*t

      # Mean anomaly of the Sun
      m_deg = 357.52910 + (35_999.05030 - (0.0001559 + 0.00000048*t)*t)*t
      m_rad = to_rad(m_deg)

      # Eccentricity of the Earth's orbit
      e = 0.016708617 - (0.000042037 + 0.0000001236*t)*t

      # Sun's Equation of the center
      c = (1.914600 - (0.004817 + 0.000014*t)*t)*Math.sin(m_rad) +
          (0.019993 - 0.000101*t)*Math.sin(2*m_rad) +
          0.000290*Math.sin(3*m_rad)

      # Sun's true longitude
      o = l + c

      # Reduce magnitude to minimize errors
      o %= 360

      # Sun's apparent Longitude
      omega_deg = 125.04 - 1934.136*t
      omega_rad = to_rad(omega_deg)
      lambda_deg = o - 0.00569 - 0.00478 * Math.sin(omega_rad)

      # Reduce magnitude to minimize errors
      lambda_deg %= 360

      lambda_rad = to_rad(lambda_deg)

      # Obliquity of the ecliptic
      epsilon_deg = 23.4392966666667 -
                    (0.012777777777777778 + (0.00059/60 - 0.00059/60*t)*t)*t +
                    0.00256*Math.cos(omega_rad)
      epsilon_rad = to_rad(epsilon_deg)

      # Sun's declination
      delta_rad = Math.asin(Math.sin(epsilon_rad)*Math.sin(lambda_rad))

      # Sun's right ascension
      alpha_rad = Math.atan2(
        Math.cos(epsilon_rad) * Math.sin(lambda_rad),
        Math.cos(lambda_rad)
      )

      [delta_rad, alpha_rad]
    end

    def altitude_from_options(options)
      if options.has_key?(:zenith)
        zenith = options[:zenith]
        if Symbol===zenith
          altitude = ALTITUDES[zenith]
        else
          altitude = 90.0 - zenith
        end
      else
        altitude = options[:altitude] || :official
        altitude = ALTITUDES[altitude] if Symbol===altitude
      end
      altitude
    end
  end

end
