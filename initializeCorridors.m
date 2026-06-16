function[MooringMarshalPort, MooringCorridor, TurbineMarshalPort, TurbineCorridor,...
    PlatformMarshalPort, PlatformCorridor, PlatformPortToFarm] = initializeCorridors()

% Ports - lat, lon
humboldt  = [40.807565, -124.162268];
sanfran   = [37.794402, -122.391938];
longbeach = [33.739737, -118.205367];

% Vessel Cooridors - define the corridor coordinates and max transit speed.
% lat, lon, speed in km/h

% Mooring Integration Port - Humboldt
% TowingCorridor = MooringCorridor;
% TurbineMarshalPort = [humboldt, 2740];
MooringMarshalPort = [humboldt, 0];
MooringCorridor = [
    MooringMarshalPort(1:2), 0;
    40.805218, -124.183262, 3.1;
    40.795938, -124.190302, 3.1;
    40.787897, -124.191152, 3.1;
    40.770065, -124.207903, 3.1;
    40.751493, -124.221983, 3.1;
    40.767169, -124.241829, 3.1;
    40.773442, -124.250287, 5.0;
    ];

% Turbine Integration Port - San Francisco
 TurbineMarshalPort = [sanfran, 2740];
 TurbineCorridor = [
     TurbineMarshalPort(1:2), 0;
     37.799021, -122.386430, 3.1;
     37.831327, -122.406041, 3.1;
     37.832565, -122.434380, 3.1;
     37.817666, -122.478388, 5.0;
     37.800736, -122.525967, 5.0;
     37.779031, -122.618314, 5.0;
     37.893440, -122.792528, 14;
     37.939753, -123.076536, 14;
     38.258986, -123.152197, 14;
     38.842176, -123.856663, 14;
     39.741013, -123.986767, 14;
     40.666081, -124.491586, 14;
     ];



% Platform Construction Port - Long Beach
PlatformMarshalPort = [longbeach, 2740];
PlatformCorridor = [
    PlatformMarshalPort(1:2), 0;
    33.733226, -118.209396, 3.1;
    33.686061, -118.201603, 3.1;
    33.501702, -118.267943, 3.1;
    34.066744, -119.295705, 5.0;
    34.269694, -119.774961, 5.0;
    34.295901, -120.818056, 14;
    35.078138, -120.969683, 14;
    36.396862, -122.181873, 14;
    37.779031, -122.618314, 14];
    %37.893440, -122.792528, 14;
    %37.939753, -123.076536, 14;
    %38.258986, -123.152197, 14;
    %38.842176, -123.856663, 14;
    %39.741013, -123.986767, 14;
    %40.666081, -124.491586, 14;
    %];

%PlatformMarshalPort = TurbineMarshalPort;
%PlatformCorridor = TurbineCorridor;

PlatformPortToFarm = [
    PlatformMarshalPort(1:2), 0;
    33.733226, -118.209396, 3.1;
    33.686061, -118.201603, 3.1;
    33.501702, -118.267943, 3.1;
    34.066744, -119.295705, 5.0;
    34.269694, -119.774961, 5.0;
    34.295901, -120.818056, 14;
    35.078138, -120.969683, 14;
    36.396862, -122.181873, 14;
    37.779031, -122.618314, 14;
    37.893440, -122.792528, 14;
    37.939753, -123.076536, 14;
    38.258986, -123.152197, 14;
    38.842176, -123.856663, 14;
    39.741013, -123.986767, 14;
    40.666081, -124.491586, 14;
    ];