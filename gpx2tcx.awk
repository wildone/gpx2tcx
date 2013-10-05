# gpx2tcx.awk by Paul Colby (http://colby.id.au), no rights reserved ;)
# $Id: gpx2tcx.awk 301 2012-02-26 06:23:24Z paul $

BEGIN {
  # Skip to the HR data in the HRM file.
  DISTANCE=0 # Distance is *required* by the TCX format.
  FS="="
  while ((!FOUND_HRDATA) && (getline <HRMFILE > 0)) {
    if ($1 == "Version") {
      HRM_VERSION=$2
    } else if ((HRM_VERSION <= 105) && ($1 == "Mode")) {
      FLAG=int(substr($2,1,1)) # First integer flag (0, 1 or 3).
      HAVE_ALTITUDE=(FLAG == 1) ? 1 : 0
      HAVE_CADENCE=(FLAG == 0) ? 1 : 0
      IMPERIAL_UNITS=int(substr($2,3,1)); # Third bit flag (0 or 1).
    } else if ((HRM_VERSION >= 106) && ($1 == "SMode")) {
      HAVE_ALTITUDE=int(substr($2,3,1)) # Third bit flag (0 or 1).
      HAVE_CADENCE=int(substr($2,2,1))  # Second bit flag (0 or 1).
      HAVE_SPEED=int(substr($2,1,1))    # First bit flag (0 or 1).
      IMPERIAL_UNITS=int(substr($2,8,1)); # Eighth bit flag (0 or 1).
    } else if ($1 == "Length") {
      DURATION=$2
	} else if ($1 == "Interval") {
	  HRM_INTERVAL=int($2)
	} else if ($1 == "[Trip]") {
	  getline DISTANCE     <HRMFILE # We'll use this one :)
        if (IMPERIAL_UNITS > 0) DISTANCE=(DISTANCE*160.9344); # 1/10 miles to meters.
	    else                    DISTANCE=(DISTANCE*100);      # 1/10 km to meters.
	  getline ASCENT       <HRMFILE # Not used.
	  getline TOTAL_TIME   <HRMFILE # Not used.
	  getline AVG_ALTITUDE <HRMFILE # Not used.
	  getline MAX_ALTITUDE <HRMFILE # Not used.
	  getline AVG_SPEED    <HRMFILE # Not used.
	  getline MAX_SPEED    <HRMFILE # We'll use this one :)
      if (IMPERIAL_UNITS > 0) MAX_SPEED=(MAX_SPEED*160.9344/60.0/60.0); # 1/10 mph to m/s.
	  else                    MAX_SPEED=(MAX_SPEED*100.0   /60.0/60.0); # 1/10 km/h to m/s.
	  getline ODOMETER     <HRMFILE # Not used.
    } else if (($1 == "[HRData]") || ($1 == "[HRData]\r")) {
      FOUND_HRDATA="$1"
    }
  }
  FS="[<>= \"]+"

  printf "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n\
<TrainingCenterDatabase xmlns=\"http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2\"\
 xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\
 xsi:schemaLocation=\"http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2\
 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd\">\n"

  printf "\n  <Activities>\n"
  if (!SPORT) SPORT=(HAVE_CADENCE) ? "Biking" : "Running";
  printf "    <Activity Sport=\"%s\">\n", SPORT
}

{
  if ($2 == "trkpt") {
    IN_TRKPT=1
    for (i=0;i<NF-1;i++) {
      if ($i == "lat") LATITUDE=$(i+1)
      if ($i == "lon") LONGITUDE=$(i+1)
    }
  } else if ($2 == "time") {
    if (IN_TRKPT) {
      printf "          <Trackpoint>\n"
      printf "            <Time>%s</Time>\n", $3
      printf "            <Position>\n"
      printf "              <LatitudeDegrees>%s</LatitudeDegrees>\n", LATITUDE
      printf "              <LongitudeDegrees>%s</LongitudeDegrees>\n", LONGITUDE
      printf "            </Position>\n"
      if ((HAVE_ALTITUDE == 0) && (ALTITUDE > 0)) {
          printf "            <AltitudeMeters>%f</AltitudeMeters>\n", ALTITUDE
          ALTITUDE=0
      }
      if (FOUND_HRDATA) {
        getline HRMDATA <HRMFILE ; split(HRMDATA, HRMFIELDS, "[\t\r]")
        if (HAVE_ALTITUDE > 0) {
          ALTITUDE=(HRM_VERSION <= 105) ? ALTITUDE=HRMFIELDS[3] : ALTITUDE=HRMFIELDS[2+HAVE_SPEED+HAVE_CADENCE];
          if (HRM_VERSION <= 102) ALTITUDE=(ALTITUDE*10);
          if (IMPERIAL_UNITS > 0) ALTITUDE=(ALTITUDE/0.3048); # feet to meters.
          printf "            <AltitudeMeters>%f</AltitudeMeters>\n", ALTITUDE
        }
        if (HAVE_SPEED) {
          if (IMPERIAL_UNITS > 0) SPEED=(HRMFIELDS[2]*160.9344/60.0/60.0); # 1/10 mph to m/s.
	      else                    SPEED=(HRMFIELDS[2]*100.0   /60.0/60.0); # 1/10 km/h to m/s.
	      DISTANCE=DISTANCE + (SPEED * HRM_INTERVAL)
          printf "            <DistanceMeters>%f</DistanceMeters>\n", DISTANCE
	    }
	    if (HRMFIELDS[1]) {
          printf "            <HeartRateBpm xsi:type=\"HeartRateInBeatsPerMinute_t\">\n"
          printf "              <Value>%s</Value>\n", HRMFIELDS[1]
          printf "            </HeartRateBpm>\n"
        }
        if (HAVE_CADENCE)
          printf "            <Cadence>%s</Cadence>\n", HRMFIELDS[2+HAVE_SPEED]
      }
    } else {
      printf "      <Id>%s</Id>\n      <Lap StartTime=\"%s\">\n", $3, $3
      split(DURATION, DURATION_ARRAY, ":");
      DURATION_NUMBER=DURATION_ARRAY[1]*60*60 + DURATION_ARRAY[2]*60 + DURATION_ARRAY[3];
      printf "        <TotalTimeSeconds>%s</TotalTimeSeconds>\n", DURATION_NUMBER
      printf "        <DistanceMeters>%f</DistanceMeters>\n", DISTANCE
      if (MAX_SPEED) printf "        <MaximumSpeed>%f</MaximumSpeed>\n", MAX_SPEED
      printf "        <Calories>0</Calories>\n"
      printf "        <Intensity>Active</Intensity>\n        <TriggerMethod>Manual</TriggerMethod>\n"
      printf "        <Track>\n"
      DISTANCE=0
    }
  } else if ($2 == "/trkpt") {
    printf "          </Trackpoint>\n"
    IN_TRKPT=0
  } else if ($2 == "/trk") {
    printf "        </Track>\n      </Lap>\n"
  }
}

END {
  printf "    </Activity>\n  </Activities>\n"

  #split("$Revision: 301 $", REVISION, " ")
  #split("$Date: 2012-02-26 17:23:24 +1100 (Sun, 26 Feb 2012) $", DATE, " ")
  # printf "\n  <Author xsi:type=\"Application_t\"> \n\
  #   <Name>Paul Colby's GPX/HRM to TCX Converter</Name> \n\
  #   <Build> \n\
  #     <Version> \n\
  #       <VersionMajor>1</VersionMajor> \n\
  #       <VersionMinor>1</VersionMinor> \n\
  #       <BuildMajor>1</BuildMajor> \n\
  #       <BuildMinor>%d</BuildMinor> \n\
  #     </Version> \n\
  #     <Type>Internal</Type> \n\
  #     <Time>%sT%s%s</Time> \n\
  #     <Builder>PaulColby</Builder> \n\
  #   </Build> \n\
  #   <LangID>EN</LangID> \n\
  #   <PartNumber>636-F6C62-79</PartNumber> \n\
  # </Author>\n", REVISION[2], DATE[2], DATE[3], DATE[4]

  printf "\n</TrainingCenterDatabase>\n"
}
