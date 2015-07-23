module Solar
  DEBUG_RADIATION = ENV['DEBUG_SOLAR_RADIATION']
  class <<self
    # Radiation in W/m^2 at time t at a position given by longitude, latitud on
    # terrain of given slope and aspect, given the global radiation on a horizontal plane
    # and optionally the diffuse radiation on a horizontal plane.
    # Computes mean radiation in a short period of length givien by :t_step (10 minute by default) centered at t.
    # Basically the method used is the oned presented in:
    #
    # * Solar Engineering of Thermal Processes
    #   1991 Duffie, Beckman
    #
    # Options:
    #
    # * +:slope+ slope angle in degrees (0-horizontal to 90-vertical)
    # * +:aspect+ clockwise from North in degrees
    # * +:t_step+ time step in hours; if radiation  values are given they
    #   are considered as the mean values for the time step.
    # * +:global_radiation+ Global radation measured on a horizontal plane
    #   in W/m^2 (mean value over the time step)
    # * +:diffuse_radiation+ Diffuse radation measured on a horizontal plane
    #   in W/m^2 (mean value over the time step)
    # * +:albedo+ of the terrain, used to compute reflected radiation.
    #
    # This can be used with a measured :global_radiation and optional
    # :diffuse_radiation, both measured on horizontal to compute the
    # estimated global radiation on a sloped plane.
    #
    # It can be also used by giving the :clearness_index to compute
    # estimated radiation.
    #
    def radiation(t, longitude, latitude, options = {})
      # TODO: parameterize on the .... algorithms
      #       consider method of [Neteler-2008] Appendix A pg. 377-381

      slope = options[:slope] ||  0.0
      aspect = options[:aspect] || 0.0

      # time step in hours
      t_step = options[:t_step] || 1/6.0
      # global measured radiation in W/m^2 (mean over time step) (horizontal)
      g = options[:global_radiation]
      # optional: diffuse radiation (horizontal)
      g_d = options[:diffuse_radiation]
      k_t = options[:clearness_index]

      # ground reflectance (albedo) as %
      rg = options[:albedo] || 0.2

      # t is assumed at half the time step

      t_utc = t.utc
      n = t_utc.yday # day of the year (a number between 1 and 365)
      lambda = to_rad(longitude)
      phi = to_rad(latitude)

      d = solar_declination(n)

      # utc time in hours
      tu = t_utc.hour + t_utc.min/60.0 + t_utc.sec/3600.0
      b = to_rad(360.0*(n-1)/365.0)
      # equation of time
      e = 3.82*(0.000075+0.001868*Math.cos(b) - 0.032077*Math.sin(b) - 0.014615*Math.cos(2*b) - 0.04089*Math.sin(2*b))
      # solar time in hours
      ts = tu + longitude/15.0 + e

      # hour angle (omega) in radians
      w = to_rad((ts - 12.0)*15.0)
      cos_w = Math.cos(w)
      sin_w = Math.sin(w)

      # extraterrestrial_normal_radiation in W/m^2
      g_on = ext_radiation(t)

      cos_phi = Math.cos(phi)
      sin_phi = Math.sin(phi)
      cos_d = Math.cos(d)
      sin_d = Math.sin(d)

      # zenith angle in radians
      # eq. 1.6.5 (pg 15) [1991-Duffie]
      cos_phi_z = cos_phi*cos_d*cos_w + sin_phi*sin_d

      # extraterrestrial horizontal radiation in W/m^2
      g_o = g_on*cos_phi_z

      # hour_angle at beginning of time step
      w1 = to_rad((ts - t_step/2 - 12.0)*15.0)
      # hour_angle at end of time step
      w2 = to_rad((ts + t_step/2 - 12.0)*15.0)

      # extraterrestrial horizontal radiation in W/m^2  averaged over the time step
      # [1991-Duffie pg 37] eq. 1.10.1, 1.10.3
      # TODO: for long time steps we should average as:
      #  g_o_a = 12/Math::PI * g_on * ( cos_phi*cos_d*(Math.sin(w2)-Math.sin(w1)) + (w2-w1)*sin_phi*sin_d )
      g_o_a = g_o
      g_o_a = 0 if g_o_a < 0

      # clearness index
      k_t ||= g/g_o_a

      # either k_t or g must be defined by the user
      g ||= (g_o_a == 0 ? 0.0 : k_t*g_o_a)

      # diffuse fraction
      if k_t.infinite?
        df = 1.0 # actual df may be around 0.5; for the purpose of computing g_d it is 1
      else
        solar_elevation = 90 - to_deg(Math.acos(cos_phi_z))
        df = diffuse_fraction(k_t, solar_elevation)
      end

      # diffuse radiation W/m^2
      g_d ||= df*g

      # beam radiation
      g_b = g - g_d

      # slope
      beta = to_rad(slope)
      # azimuth
      gamma = to_rad(aspect-180)

      cos_beta = Math.cos(beta)
      sin_beta = Math.sin(beta)
      cos_gamma = Math.cos(gamma)
      sin_gamma = Math.sin(gamma)

      # angle of incidence
      # eq (1.6.2) pg 14 [1991-Duffie]
      # eq (3) "Analytical integrated functions for daily solar radiation on slopes" - Allen, Trezza, Tasumi
      cos_phi = sin_d*sin_phi*cos_beta \
                - sin_d*cos_phi*sin_beta*cos_gamma \
                + cos_d*cos_phi*cos_beta*cos_w \
                + cos_d*sin_phi*sin_beta*cos_gamma*cos_w \
                + cos_d*sin_beta*sin_gamma*sin_w

      # ratio of beam radiation on tilted surface to beam radiation on horizontal
      # [1991-Duffie pg 23-24] eq. 1.8.1
      # rb = illumination_factor_at(t, longitude, latitude, slope, aspect)
      rb = cos_phi / cos_phi_z
      rb = 0.0 if rb < 0.0

      # anisotropy index
      if k_t.infinite? || g_o_a == 0
        ai = 0.0
      else
        ai = g_b / g_o_a
      end

      # horizontal brightening factor
      if g != 0
        f = Math.sqrt(g_b / g)
      else
        f = 1.0
      end

      if DEBUG_RADIATION
        sun_elevation, sun_azimuth = Solar.position(t_utc, longitude, latitude)
        rb2 = illumination_factor_at(t_utc, longitude, latitude, slope, aspect)
        puts ""
        puts "  @#{t_utc} #{sun_elevation}  [#{90-sun_elevation}] az: #{sun_azimuth} <#{Math.acos(cos_phi_z)*180/Math::PI}>"
        puts "  kt:#{k_t} df:#{df}   g: #{g} gon: #{g_on}"
        puts "  rb: #{rb} (#{rb2}) g_b:#{g_b} g_o_a:#{g_o_a} g_d:#{g_d}"
        puts "  -> #{(g_b + g_d*ai)*rb}+#{g_d*(1-ai)*((1 + cos_beta)/2)*(1 + f*Math.sin(beta/2)**3)}+#{g*rg*(1 - cos_beta)/2}"
      end

      # global radiation on slope according to HDKR model
      # eq. 2.16.7 (pg.92) [1991-Duffie]
      # three terms:
      # * direct and circumsolar: (g_b + g_d*ai)*rb
      # * diffuse: g_d*(1-ai)*((1 + cos_beta)/2)*(1 + f*Math.sin(beta/2)**3)
      # * reflected: g*rg*(1 - cos_beta)/2
      (g_b + g_d*ai)*rb + g_d*(1-ai)*((1 + cos_beta)/2)*(1 + f*Math.sin(beta/2)**3) + g*rg*(1 - cos_beta)/2
    end

    private

    G_SC = 1367.0 # solar constant W/m^2

    # Extraterrestrial normal radiation
    # Solar Engineering of Thermal Processes [1991, Duffie, Beckman]
    #  pg.5-6, 8-9; pg 37.
    def ext_radiation(t)
      n = t.utc.yday
      G_SC*(1.0 + 0.033*Math.cos(to_rad(360.0*n/365.0)))

      # Alternative based on [Neteler-2008 pg378] (A.65)
      # j = 2*Math::PI*n/365.25
      # G_SC*(1.0 + 0.03344*Math.cos(j - 0.048869))
    end

    # Diffuse fraction as a function of the clearness index
    # Erbs model:
    #
    # * Estimation of the diffuse radiation fraction for hourly, daily and monthly-average global radiation
    #   1982 Erbs, Klein, Duffie
    #   SOLAR ENERGY - 1982 Vol.28 Issue 4
    #
    # Other sources of information for this model:
    #
    # * Different methods for separating diffuse and direct components of solar radiation and their application in crop growth models
    #   1992 Bindi, Miglietta, Zipoli
    #   CLIMATE RESEARCH - July 1992
    #   http://www.int-res.com/articles/cr/2/c002p047.pdf (pg 53 Method ER)
    # * DIVISION OF GLOBAL RADIATION INTO DIRECT RADIATION AND DIFFUSE RADIATION
    #   2010 Fabienne Lanini
    # * Solar radiation model
    #   2001 Wong, Chow
    #   APPLIED ENERGY - August 2001 [pg. 210]
    # * COMPARISON OF MODELS FOR THE DERIVATION OF DIFFUSE FRACTION OF GLOBAL IRRADIANCE DATA FOR VIENNA, AUSTRIA
    #   2011 Dervishi, Mahdavi - pg 766
    #
    #  TODO: use model that uses solar elevation (Skartveit Olseth):
    #
    #  * AN HOURLY DIFFUSE FRACTION MODEL WITH CORRECTION FOR VARIABILITY AND SURFACE ALBEDO
    #    1998 Skartveit, Olseth, Tuft
    #    SOLAR ENERY - September 1998
    #    http://www.sciencedirect.com/science/article/pii/S0038092X9800067X
    #
    #  Precedent model:
    #
    #  * A model for the diffuse fraction of hourly global radiation
    #    1986 Skartveit, Olseth
    #    SOLAR ENERGY - JANUARY 1987
    #    http://www.researchgate.net/publication/222958126
    #
    #  Additional information:
    #
    #  * Solar radiation model
    #    2001 Wong, Chow
    #    APPLIED ENERGY - August 2001 [pg. 212]
    #
    #  * Solar Engineering of Thermal Processes
    #    1991 Duffie, Beckman [pg.77]
    #
    def diffuse_fraction(k_t, solar_elevation)
      if k_t <= 0.22
        df  = 1.0 - 0.09*k_t
      elsif k_t <= 0.80
        df = 0.9511 - 0.1604*k_t + 4.388*k_t**2 - 16.638*k_t**3 + 12.336*k_t**4
      else
        df = 0.165
      end
    end

    def solar_declination(day)
      # solar declination [Duffie-1991 pg 13]
      ang = to_rad(360*(284.0 + day)/365.0)
      to_rad(23.45)*Math.sin(ang)

      # Alternative based on [Neteler-2008 pg337] (A.59)
      # j = 2*Math::PI*day/365.25
      # Math.asin(0.3978*Math.sin(j - 1.4 + 0.0355*Math.sin(j - 0.0489)))
    end

  end
end
