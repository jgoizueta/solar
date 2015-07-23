module Solar
  class <<self
    # Sun rise time for a given date (UTC) and position.
    #
    # The +:zenith+ or +:altitude+ of the sun can be passed as an argument,
    # which can be numeric (in degrees) or symbolic:
    # +:official+, +:civil+, +:nautical+ or +:astronomical+.
    #
    # +nil+ is returned if the sun doesn't rise at the date and position.
    #
    def rise(date, longitude, latitude, options = {})
      rising, _, setting = passages(date, longitude, latitude, options)
      if rising == setting || (setting - rising) == 1
        nil # rising==setting => no rise; setting-rising == 1 => no set
      else
        rising
      end
    end

    # Sun set time for a given date (UTC) and position.
    #
    # The +:zenith+ or +:altitude+ of the sun can be passed as an argument,
    # which can be numeric (in degrees) or symbolic:
    # +:official+, +:civil+, +:nautical+ or +:astronomical+.
    #
    # +nil+ is returned if the sun doesn't set at the date and position.
    #
    def set(date, longitude, latitude, options = {})
      rising, _, setting = passages(date, longitude, latitude, options)
      if rising==setting || (setting-rising)==1
        nil # rising==setting => no rise; setting-rising == 1 => no set
      else
        setting
      end
    end

    # Rise and set times as given by rise() and set()
    def rise_and_set(date, longitude, latitude, options = {})
      rising, _, setting = passages(date, longitude, latitude, options)
      if rising==setting || (setting-rising)==1
        nil # rising==setting => no rise; setting-rising == 1 => no set
      else
        [rising, setting]
      end
    end

    # Solar passages [rising, transit, setting] for a given date (UTC) and position.
    #
    # The +:zenith+ or +:altitude+ of the sun can be passed as an argument,
    # which can be numeric (in degrees) or symbolic:
    # +:official+, +:civil+, +:nautical+ or +:astronomical+.
    #
    # In circumpolar case:
    # * If Sun never rises, returns 00:00:00 on Date for all passages.
    # * If Sun never sets, returns 00:00:00 (rising), 12:00:00 (transit),
    #   24:00:00 (setting) on Date for all passages.
    #
    def passages(date, longitude, latitude, options = {})
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
      decl_rad = decl.map { |x| to_rad(x) }

      # approximate Hour Angle (degrees)
      ha = Math.sin(ho_rad) /
           Math.cos(latitude_rad) * Math.cos(decl_rad[1]) -
           Math.tan(latitude_rad) * Math.tan(decl_rad[1])
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
      (0..2).each do |i|
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

        until m[i] >= 0
          m[i] += 1
          days[i] += day_offset
        end
        until m[i] <= 1
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
      while delta_m[0] >= 0.01 || delta_m[1] >= 0.01 || delta_m[2] >= 0.01
        0.upto(2) do |i|
          theta[i] = theta0 + 360.985647 * m[i]
          n = m[i] + delta_t(date.to_datetime).to_r / 86_400
          a = ra[1] - ra[0]
          b = ra[2] - ra[1]
          c = b - a
          ra2[i] = ra[1] + n / 2 * (a + b + n * c)

          n = m[i] + delta_t(date.to_datetime).to_r / 86_400
          a = decl[1] - decl[0]
          b = decl[2] - decl[1]
          c = b - a
          decl2[i] = decl[1] + n / 2 * (a + b + n * c)

          h[i] = theta[i] + longitude - ra2[i]

          alt[i] = to_deg Math.asin(
            Math.sin(latitude_rad) * Math.sin(to_rad(decl2[i])) +
            Math.cos(latitude_rad) * Math.cos(to_rad(decl2[i])) *
            Math.cos(to_rad(h[i]))
          )
        end
        # adjust m
        delta_m[0] = -h[0] / 360
        1.upto(2) do |i|
          delta_m[i] = (alt[i] - ho) /
          360 * Math.cos(to_rad(decl2[i])) * Math.cos(latitude_rad) * Math.sin(to_rad(h[i]))
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
  end
end
