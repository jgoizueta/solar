require 'active_support'
require 'active_support/time'

# Calculation of solar position, rise & set times for a given position & time.
# Algorithms are taken from Jean Meeus, Astronomical Algorithms
# Some code & ideas taken from John P. Power's astro-algo: http://astro-algo.rubyforge.org/astro-algo/
module Solar

  ALTITUDES = {
    :official => -50/60.0,
    :civil => -6.0,
    :nautical =>  -12.0,
    :astronomical => -18.0
  }

  class <<self

    # Day-night (or twilight) status at a given position and time
    # returns :night, :day or :twilight
    # options:
    # * :twilight_zenith zenith for the sun at dawn (beginning of twilight)
    #   and at dusk (end of twilight). Default: :civil
    # * :day_zenith zenith for the san at sunrise and sun set.
    #   Default: :official (sun aparently under the horizon, tangent to it)
    # These parameters can be assigned zenith values in degrees of the symbols:
    # :official, :civil, :nautical or :astronomical.
    def day_or_night(t, longitude, latitude, options={})
      if options[:zenith]
        twilight_altitude = day_altitude = altitude_from_options(options)
      else
        twilight_altitude = altitude_from_options(:zenith => options[:twilight_zenith] || :civil)
        day_altitude = altitude_from_options(:zenith => options[:day_zenith] || :official)
      end
      al,az = position(t, longitude, latitude)
      (al > day_altitude) ? :day : (al <= twilight_altitude) ? :night : :twilight
    end

    # Sun horizontal coordinates (relative position) in degrees:
    # * elevation (altitude over horizon) in degrees; positive upwards
    # * azimuth in degrees measured clockwise (towards East) from North direction
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
      theta = 280.46061837 + 360.98564736629*(jd-2451545) + (0.000387933 - t/38710000)*t*t

      # Reduce magnitude to minimize errors
      theta %= 360

      # Local hour angle
      h = theta + longitude - alpha_deg
      h %= 360

      latitude_rad = to_rad(latitude)
      h_rad = to_rad(h)

      # Local horizontal coordinates : Meeus pg 89
      altitude_rad = Math.asin(Math.sin(latitude_rad)*Math.sin(delta_rad) + Math.cos(latitude_rad)*Math.cos(delta_rad)*Math.cos(h_rad))
      azimuth_rad = Math.atan2((Math.sin(h_rad)),((Math.cos(h_rad) * Math.sin(latitude_rad)) - Math.tan(delta_rad) * Math.cos(latitude_rad)))

      [to_deg(altitude_rad), (180+to_deg(azimuth_rad))%360 ]

    end

    # Sun rise time for a given date (UTC) and position.
    # The :zenith or :altitude of the sun can be passed as an argument,
    # which can be numeric (in degrees) or symbolic:
    # :official, :civil, :nautical or :astronomical.
    # nil is returned if the sun doesn't rise at the date and position.
    def rise(date, longitude, latitude, options={})
      rising, transit, setting = passages(date, longitude, latitude, options)
      if rising==setting || (setting-rising)==1
        nil # rising==setting => no rise; setting-rising == 1 => no set
      else
        rising
      end
    end

    # Sun set time for a given date (UTC) and position.
    # The :zenith or :altitude of the sun can be passed as an argument,
    # which can be numeric (in degrees) or symbolic:
    # :official, :civil, :nautical or :astronomical.
    # nil is returned if the sun doesn't set at the date and position.
    def set(date, longitude, latitude, options={})
      rising, transit, setting = passages(date, longitude, latitude, options)
      if rising==setting || (setting-rising)==1
        nil # rising==setting => no rise; setting-rising == 1 => no set
      else
        setting
      end
    end

    # Rise and set times as given by rise() and set()
    def rise_and_set(date, longitude, latitude, options={})
      rising, transit, setting = passages(date, longitude, latitude, options)
      if rising==setting || (setting-rising)==1
        nil # rising==setting => no rise; setting-rising == 1 => no set
      else
        [rising, setting]
      end
    end

    # Solar passages [rising, transit, setting] for a given date (UTC) and position.
    # The :zenith or :altitude of the sun can be passed as an argument,
    # which can be numeric (in degrees) or symbolic:
    # :official, :civil, :nautical or :astronomical.
    # In circumpolar case:
    # If Sun never rises, returns 00:00:00 on Date for all passages.
    # If Sun never sets, returns 00:00:00 (rising), 12:00:00 (transit), 24:00:00 (setting)
    # on Date for all passages.
    def passages(date, longitude, latitude, options={})

      ho = altitude_from_options(options)
      t = to_jc(jd_r(date.to_datetime))
      theta0 = (100.46061837 + (36000.770053608 + (0.000387933 - t/38710000)*t)*t) % 360
      # Calculate apparent right ascention and declination for 0 hr Dynamical time for three days (degrees)
      ra = []
      decl = []
      -1.upto(1) do |i|
        declination, right_ascention = equatorial_position_rad((date+i).to_datetime)
        ra << to_deg(right_ascention)
        decl << to_deg(declination)
      end
      # tweak right ascention around 180 degrees (autumnal equinox)
      if ra[0] > ra[1]
        ra[0] -= 360
      end
      if ra[2] < ra[1]
        ra[2] += 360
      end

      ho_rad, latitude_rad = [ho, latitude].map{|x| to_rad(x)}
      decl_rad = decl.map{|x| to_rad(x)}

      # approximate Hour Angle (degrees)
      ha = Math.sin(ho_rad) / (Math.cos(latitude_rad) * Math.cos(decl_rad[1])) - Math.tan(latitude_rad) * Math.tan(decl_rad[1])
      # handle circumpolar. see note 2 at end of chapter
      if ha.abs <= 1
        ha = to_deg(Math.acos(ha))
      elsif ha > 1  # circumpolar - sun never rises
        # format sunrise, sunset & solar noon as DateTime
        sunrise = date.to_datetime
        transit = date.to_datetime
        sunset = date.to_datetime
        return [sunrise, transit, sunset]
      else  # cirumpolar - sun never sets
        # format sunrise, sunset & solar noon as DateTime
        sunrise = date.to_datetime
        transit = date.to_datetime + 0.5
        sunset = date.to_datetime + 1
        return [sunrise, transit, sunset]
      end
      # approximate m (fraction of 1 day)
      # store days added or subtracted to add in later
      m = []
      days = [0]*3
      for i in 0..2
        case i
        when 0
          m[i] = (ra[1] - longitude - theta0) / 360 # transit
          day_offset = +1
        when 1
          m[i] = m[0] - ha / 360 # rising
          day_offset = -1
        when 2
          m[i] = m[0] + ha / 360 # setting
          day_offset = -1
        end

        until m[i] >= 0 do
          m[i] += 1
          days[i] += day_offset
        end
        until m[i] <= 1 do
          m[i] -= 1
          days[i] -= day_offset
        end
      end
      theta = [] # apparent sidereal time (degrees)
      ra2 = []   # apparent right ascension (degrees)
      decl2 = [] # apparent declination (degrees)
      h = []   # local hour angle (degrees)
      alt = []   # altitude (degrees)
      delta_m = [1]*3
      while ( delta_m[0] >= 0.01 || delta_m[1] >= 0.01 || delta_m[2] >= 0.01 ) do
        0.upto(2) do |i|
          theta[i] = theta0 + 360.985647 * m[i]
          n = m[i] + delta_t(date.to_datetime).to_r / 86400
          a = ra[1] - ra[0]
          b = ra[2] - ra[1]
          c = b - a
          ra2[i] = ra[1] + n / 2 * ( a + b + n * c )

          n = m[i] + delta_t(date.to_datetime).to_r / 86400
          a = decl[1] - decl[0]
          b = decl[2] - decl[1]
          c = b - a
          decl2[i] = decl[1] + n / 2 * ( a + b + n * c )

          h[i] = theta[i] + longitude - ra2[i]

          alt[i] = to_deg Math.asin(Math.sin(latitude_rad) * Math.sin(to_rad(decl2[i])) +
            Math.cos(latitude_rad) * Math.cos(to_rad(decl2[i])) * Math.cos(to_rad(h[i])))
        end
        # adjust m
        delta_m[0] = -h[0] / 360
        1.upto(2) do |i|
          delta_m[i] = (alt[i] - ho) / (360 * Math.cos(to_rad(decl2[i])) * Math.cos(latitude_rad) * Math.sin(to_rad(h[i])))
        end
        0.upto(2) do |i|
          m[i] += delta_m[i]
        end
      end
      # format sunrise, sunset & solar noon as DateTime
      sunrise = date.to_datetime + m[1] + days[1]
      transit = date.to_datetime + m[0] + days[0]
      sunset = date.to_datetime + m[2] + days[2]
      [sunrise, transit, sunset]
    end


    private

    # Julian Day as Rational
    def jd_r(t)
      if false
        # This computes JD with precision of seconds and yields smaller denominators
        t = t.utc
        t.to_date.ajd + Rational(t.hour,24) + Rational(t.min,1440) + Rational(t.sec,86400)
      else
        # This preserves the internal precision of t (which we probably don't need)
        # and produces larger denominators in general
        t.to_datetime.utc.ajd
      end
    end

    # Julian Day as Float
    def jd_f(t)
      # t.to_date.ajd.to_f + t.hour/24.0 + t.min/1440.0 + t.sec/86400.0
      t.to_datetime.utc.ajd.to_f
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
      (jd - 2451545)/36525
    end

    def polynomial(coefficients, x)
      coefficients.inject(0.0){|p, a| p*x + a}
    end

    # Conversion of Float to Rational preserving the exact value of the number
    def to_r(x)
      x = x.to_f
      return Rational(x.to_i,1) if x.modulo(1)==0
      if !x.finite?
        return Rational(0,0) if x.nan?
        return x<0 ? Rational(-1,0) : Rational(1,0)
      end

      f,e = Math.frexp(x)

      if e < Float::MIN_EXP
         bits = e+Float::MANT_DIG-Float::MIN_EXP
      else
         bits = [Float::MANT_DIG,e].max
         #return Rational(x.to_i,1) if bits<e
      end
        p = Math.ldexp(f,bits)
        e = bits - e
        if e<Float::MAX_EXP
          q = Math.ldexp(1,e)
        else
          q = Float::RADIX**e
        end
      return Rational(p.to_i,q.to_i)
    end

    # time to dynamical time
    def to_td(t)
      t = t.utc
      t + to_r(delta_t(t))/86400
    end

    # dynamical_time to utc
    def to_utc(td)
      raise "Invalid dynamical time (should be utc)" unless td.utc?
      td - to_r(delta_t(td))/86400

    end

    # Compute difference between dynamical time and UTC in seconds.
    # See http://sunearth.gsfc.nasa.gov/eclipse/SEcat5/deltatpoly.html.
    # Good from -1999 to +3000.
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
      l = 280.46645 + (36000.76983 + 0.0003032*t)*t

      # Mean anomaly of the Sun
      m_deg = 357.52910 + (35999.05030 - (0.0001559 + 0.00000048*t)*t)*t
      m_rad = to_rad(m_deg)

      # Eccentricity of the Earth's orbit
      e = 0.016708617 - (0.000042037 + 0.0000001236*t)*t

      # Sun's Equation of the center
      c = (1.914600 - (0.004817 + 0.000014*t)*t)*Math.sin(m_rad) + (0.019993 - 0.000101*t)*Math.sin(2*m_rad) + 0.000290*Math.sin(3*m_rad)

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
      epsilon_deg = 23.4392966666667 - (0.012777777777777778 + (0.00059/60 - 0.00059/60*t)*t)*t + 0.00256*Math.cos(omega_rad)
      epsilon_rad = to_rad(epsilon_deg)

      # Sun's declination
      delta_rad = Math.asin(Math.sin(epsilon_rad)*Math.sin(lambda_rad))

      # Sun's right ascension
      alpha_rad = Math.atan2(((Math.cos(epsilon_rad) * Math.sin(lambda_rad))),(Math.cos(lambda_rad)))

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
