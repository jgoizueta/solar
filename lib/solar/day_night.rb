module Solar
  class <<self
    # Day-night (or twilight) status at a given position and time.
    # Returns +:night+, +:day+ or +:twilight+
    #
    # Options:
    #
    # * +:twilight_zenith+ is the zenith for the sun at dawn
    #   (at the beginning of twilight)
    #   and at dusk (end of twilight). Default value is +:civil+
    # * +:day_zenith+ is the zenith for the san at sunrise and sun set.
    #   Default value is  +:official+ (sun aparently under the horizon,
    #   tangent to it)
    #
    # These parameters can be assigned zenith values in degrees or these
    # symbols: +:official+, +:civil+, +:nautical+ or +:astronomical+.
    #
    # A simple day/night result (returning either +:day+ or +:night+)
    # can be requested by setting the +:simple+ option to true
    # (which usses the official day definition),
    # or by setting a +:zenith+ parameter to define the kind of day-night
    # distinction.
    #
    # By setting the +:detailed+ option to true, the result will be one of:
    # +:night+, +:astronomical_twilight+, +:nautical_twilight+,
    # +:civil_twilight+, +:day+
    #
    def day_or_night(t, longitude, latitude, options = {})
      h, _ = position(t, longitude, latitude)
      options = { zenith: :official } if options[:simple]
      if options[:detailed]
        if h < ALTITUDES[:astronomical]
          :night
        elsif  h < ALTITUDES[:nautical]
          :astronomical_twilight
        elsif h < ALTITUDES[:civil]
          :nautical_twilight
        elsif h < ALTITUDES[:official]
          :civil_twilight
        else
          :day
        end
      else
        # Determined :night / :twilight / :day state;
        # twilight/day definition can be changed with options :zenith or :twilight_zenith, :day_zenith
        if options[:zenith]
          # only :day / :night distinction as defined by :zenith
          twilight_altitude = day_altitude = altitude_from_options(options)
        else
          twilight_altitude = altitude_from_options(
            zenith: options[:twilight_zenith] || :civil
          )
          day_altitude = altitude_from_options(
            zenith: options[:day_zenith] || :official
          )
        end
        if h > day_altitude
          :day
        else
          h <= twilight_altitude ? :night : :twilight
        end
      end
    end
  end
end
