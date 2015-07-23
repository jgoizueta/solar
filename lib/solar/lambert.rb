module Solar
  class <<self

    # slope, sun_azimuth: degrees (0: horizontal; 90: vertical)
    # aspect: degrees from North towards East
    # sun_elevation: degrees (0 on horizon, 90 on zenith)
    def illumination_factor(sun_azimuth, sun_elevation, slope, aspect)
      s = sun_vector(sun_azimuth, sun_elevation)
      nh = vertical_vector
      n  = normal_from_slope_aspect(slope, aspect)
      # Problem: when sun near horizon...
      f = dot(s, n) / dot(s, nh)
      f < 0 ? 0.0 : f
    end

    def illumination_factor_at(t, longitude, latitude, slope, aspect)
      sun_elevation, sun_azimuth = Solar.position(t, longitude, latitude)
      return 0.0 if sun_elevation < 0 # should return 1.0, really
      illumination_factor(sun_azimuth, sun_elevation, slope, aspect)
    end

    def mean_illumination_factor_on(date, latitude, slope, aspect, options = {})
      t1, t2, t3 = Solar.passages(date, 0, latitude, altitude: 24.0)
      if options[:noon]
        return factor_at(t2, 0.0, latitude, slope, aspect)
      end
      if n = options[:n]
        dt = (t3 - t1).to_f*24*3600/n
      else
        dt = (options[:dt] || 60*30.0).to_f
      end
      f = 0.0
      n = 0
      # max_f = 0.0
      (t1..t3).step(dt).each do |t|
        f += illumination_factor_at(Time.at(t), 0.0, latitude, slope, aspect)
        n += 1
      end
      f / n
    end

    private

    def dot(u, v)
      u[0]*v[0] + u[1]*v[1] + u[2]*v[2]
    end

    # Vertical unitary vector (normal to the horizontal plane)
    def vertical_vector
      [0, 0, 1]
    end

    # normal unitary vector in X (horizontal plane to N),
    # Y (horizontal plane to E), Z (vertical upward) system
    def normal_from_slope_aspect(slope, aspect)
      a = to_rad(aspect)
      b = to_rad(slope)
      [Math.sin(b)*Math.sin(a), Math.sin(b)*Math.cos(a), Math.cos(b)]
    end

    # sun vector in X Y Z system
    def sun_vector(sun_azimuth, sun_elevation)
      a = to_rad(sun_azimuth)
      b = to_rad(sun_elevation)
      [Math.cos(b)*Math.sin(a), Math.cos(b)*Math.cos(a), Math.sin(b)]
    end
  end
end
