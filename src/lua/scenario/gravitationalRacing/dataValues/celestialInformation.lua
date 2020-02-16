local data = {
  --Mass precision: 4 sig. fig.
  --Radius precision: nearest km
  --AxisTilt precision: 3 sig. fig.
  --RotationPeriod precision (in days): 3 sig. fig.
  sun = {
    mass           = 1.989*10^30,
    radius         = 696342,
    axisTilt       = 7.25,
    rotationPeriod = 24.5
  },
  mercury = {
    mass           = 3.301*10^23,
    radius         = 2439,
    axisTilt       = 0.0340,
    rotationPeriod = 58.7
  },
  venus = {
    mass           = 4.867*10^24,
    radius         = 6051,
    axisTilt       = 177,
    rotationPeriod = 243
  },
  earth = {
    mass           = 5.972*10^24,
    radius         = 6371,
    axisTilt       = 23.4,
    rotationPeriod = 1.00
  },
  mars = {
    mass           = 6.417*10^23,
    radius         = 3389,
    axisTilt       = 25.2,
    rotationPeriod = 1.02
  },
  jupiter = {
    mass           = 1.898*10^27,
    radius         = 69911,
    axisTilt       = 3.13,
    rotationPeriod = 0.41
  },
  saturn = {
    mass           = 5.680*10^26,
    radius         = 58232,
    axisTilt       = 26.7,
    rotationPeriod = 0.46
  },
  uranus = {
    mass           = 8.680*10^25,
    radius         = 25362,
    axisTilt       = 97.8,
    rotationPeriod = 0.72
  },
  neptune = {
    mass           = 1.020*10^26,
    radius         = 24622,
    axisTilt       = 28.3,
    rotationPeriod = 0.67
  }
}

--Have to be setup outside of table create since they require data from the sun (inside the table)
data.neutronStar = {
  mass           = data.sun.mass,
  radius         = data.sun.radius/2,
  axisTilt       = 0,
  rotationPeriod = data.sun.rotationPeriod/3
}
data.blackhole = {
  mass           = data.sun.mass,
  radius         = data.sun.radius/3,
  axisTilt       = 0,
  rotationPeriod = 0
}

data.CDCrucis = {
  mass           = data.sun.mass*42.6,
  radius         = data.sun.radius*5,
  axisTilt       = 0, --Unknown
  rotationPeriod = 25  --Unknown - random value
}
data.HD49798 = {
  mass           = data.sun.mass*1.5,
  radius         = data.sun.radius*1.45,
  axisTilt       = 0, --Unknown
  rotationPeriod = 20  --unkown - random value
}
data.etaUrsaeMajoris = {
  mass           = data.sun.mass*6.1,
  radius         = data.sun.radius*3.4,
  axisTilt       = 0, --Unknown
  rotationPeriod = 1.15
}
data.alphaVolantis = {
  mass           = data.sun.mass*1.87,
  radius         = data.sun.radius*1.9,
  axisTilt       = 0, --Unknown
  rotationPeriod = 3.14 --unkown
}
data.procyonA = {
  mass           = data.sun.mass*1.499,
  radius         = data.sun.radius*2.048,
  axisTilt       = 0, --Unknown
  rotationPeriod = 23
}
data.ABDoradusA = {
  mass           = data.sun.mass*0.75,
  radius         = data.sun.radius*0.96,
  axisTilt       = 0, --Unknown
  rotationPeriod = 0.5148
}
data.CHXR73 = {
  mass           = data.sun.mass*0.32,
  radius         = data.sun.radius*0.83,
  axisTilt       = 0, --Unknown
  rotationPeriod = 9.11
}

---------------------------------------------------------------------------------------------------------------------------------------------

local function getData(celestial, attribute)
  --[[
  Returns the data for a specific attribute of a specific celestial
  If celestial is nil, returns all data for all celestials
  If attribute is nil, returns all data for that celestial

  ]]--
  if not celestial and attribute then
    error("celestialInformation.getData() - Cannot get attribute of a nil celestial!")
  end

  --Handle all data request
  if not celestial and not attribute then
    return data
  end

  --All/one attribute(s) requires valid celestial
  if not data[celestial] then
    error("celestialInformation.getData() - Cannot get data of an unknown celestial")
  end

  --Handle all attributes request
  if not attribute then
    return data[celestial]
  end

  --Handle specific attribute request
  if not data[celestial][attribute] then
    error("celestialInformation.getData() - Cannot get an unknown attribute of this celestial")
  else
    return data[celestial][attribute]
  end
end

return {getData = getData}
