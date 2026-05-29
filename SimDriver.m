     %% MORBIT Simulation Driver
%   The UMaine mooring team Mooring focused ORBIT redesign. This system is based on the open source tool developed by
%   NREL, ORBIT (https://github.com/WISDEM/ORBIT). It has been restructured to be a controller based stepped simulation,
%   where each agent in the simulation is communicating laterally with all other simulation agents, as opposed to the
%   approach of the NREL model where agents work independantly and in parallel and then the actions are ordered
%   appropriately after the fact (i.e. an AHTS cannot make a decision based on the actions of a towing vessel or port).
%
%   This is the main simulation driver script. Generally speaking, classes should not need to be modified individually
%   unless dealing with a bug or updating a feature.
%
%
%   Created:     Oct 18, 2024
%   Modified:    Jan 09, 2025
%
%


%% Suppressed warnings
% Suppresses the warning about not preallocating arrays before running a loop, we do not know the size of the sim array
% before we begin so it is not able to be preallocated, preallocation is used when possible.
%#ok<*SAGROW>


%% Setup
clear; close all; clc;

%% Weather Inputs
% This is weather data from the ERA5 dataset from the CDS API.
% the wind speed from the original data was scaled from 100m to 10m winds using a scaling factor of 0.14.
load('WeatherData.mat', 'wave', 'wind');

% Set the start time of the simulation.
startTime = datetime(1949, 04, 01, 1, 0, 0, 0);

%% Location Inputs

% Array - Load a csv from a shp file with lat, lon, and depth
arr = readmatrix("ExampleArrayLatLon.csv");
numTurbines = length(arr); % The number of turbines in the array

% Ports - lat, lon
humboldt  = [40.807565, -124.162268];
sanfran   = [37.794402, -122.391938];
longbeach = [33.739737, -118.205367];

% Vessel Cooridors - define the corridor coordinates and max transit speed.
% lat, lon, speed in km/h
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

% humboldt
% TowingCorridor = MooringCorridor;
% TurbineMarshalPort = [humboldt, 2740];

% San Francisco
% TurbineMarshalPort = [sanfran, 2740];
% TowingCorridor = [
%     TurbineMarshalPort(1:2), 0;
%     37.799021, -122.386430, 3.1;
%     37.831327, -122.406041, 3.1;
%     37.832565, -122.434380, 3.1;
%     37.817666, -122.478388, 5.0;
%     37.800736, -122.525967, 5.0;
%     37.779031, -122.618314, 5.0;
%     37.893440, -122.792528, 14;
%     37.939753, -123.076536, 14;
%     38.258986, -123.152197, 14;
%     38.842176, -123.856663, 14;
%     39.741013, -123.986767, 14;
%     40.666081, -124.491586, 14;
%     ];

% Long Beach
TurbineMarshalPort = [longbeach, 2740];
TowingCorridor = [
    TurbineMarshalPort(1:2), 0;
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


%% Vessel Inputs

% Towing Vessel
towVesselName = 'Tow';
towTransitSpeed = 14;   % [km/h] Transit speed
towTowSpeed = 9;        % [km/h] Tow-out speed
towRate = 1458;         % [$/hr] Hourly rate
towMob = 10;            % [hr] Mobilize time
towTransitWave = 4.75;  % [m] Wave height limit during transit
towTransitWind = 25;    % [m/s] Wind speed limit during transit
towTowWave = 4;       % [m] Wave height limit during tow-out
towTowWind = 15;        % [m/s] Wind speed limit during tow-out - m/s

% AHTS Vessel
AHTSVesselName = 'Dino';
AHTSSpeed = 14;         % [km/h] 
AHTSRate = 4167;        % [$/hr] Hourly rate
AHTSMob = 10;           % [hr] Mobilize time
AHTSTransitWave = 4.5;  % [m] Wave height limit during transit
AHTSTransitWind = 20;   % [m/s] Wind speed limit during transit
AHTSPreInstallWave = 4.3; % [m] Wave height limit during pre-install
AHTSPreInstallWind = 20; % [m/s] Wind speed limit during pre-install
AHTSAnchorWave = 4.1;   % [m] Wave height limit during anchor install
AHTSAnchorWind = 20;    % [m/s] Wind speed limit during anchor install
AHTSMooringWave = 4;    % [m] Wave height limit during mooring install
AHTSMooringWind = 15;   % [m/s] Wind speed limit during mooring install


%% Misc Inputs

numLines    = 6;        % number of lines per turbine
turbAssemblyTime = 336; % [hr]
WetStorage = 5;         % Max. wet storage capacity (# turbines)
numTurb = 5;              % Number of turbines in wet storage at start


%% Weather
% Sample the weather data between certain dates for processing speed.
% providing the entire weather data set, if it is long, can slow down the simulation a lot.
% The "+ years(3)" may need to be modified depending on your WEA and the number of turbines.
% This number is currently based on a 50 turbine array in California.
% If there is a an index error in the weather agent, this number should be increased.
idx = wave.t > startTime & wave.t < startTime + years(10);
wnames = fieldnames(wave);
for w = 1:length(wnames)
    wave.(wnames{w}) = wave.(wnames{w})(idx);
end
wnames = fieldnames(wind);
for w = 1:length(wnames)
    wind.(wnames{w}) = wind.(wnames{w})(idx);
end




%% Create the simulation structure
% initialize the simulation step. This structure is passed between agents at each step of the simulation and is the way
% that agents communicate with one another, as well as where information about each time step is extracted.
simStep = struct();
simStep.time = 0;
simStep.proj = wgs84Ellipsoid("km");

% simStep.arry defines all of the simulation-important information about the WEA.
    % array is lat, lon, status, id, completion time, depth (m)
        % status can be as follows:
            % 0 - Nothing installed
            % 1 - Mooring Install In Progress
            % 2 - Moorings installed
            % 3 - Turbine installed
simStep.array = [arr(:, [6,7]),...
    zeros(size((1:numTurbines)')),...
    (1:numTurbines)',...
    zeros(size((1:numTurbines)')), abs(arr(:, 3))];
simStep.mooringsIn = [simStep.array(:, 4), zeros(length(simStep.array), 6)];

% instantiating communications throughout the simulation.
simStep.loadTurbine   = false; % Is the tow vessel loading a turbine
simStep.loadMoorings  = false; % Is the AHTS loading mooring lines
simStep.nMoorings     = 0; % number of moorings provided to ahts by the mooring port
simStep.nTurbines     = 0; % number of turbines in wet storage
simStep.numMoorings   = numLines; % provides number of moorings to the sim object
simStep.AHTSonSite    = false; % tells the towing vessel if the AHTS is on site for hook up
simStep.towInfo       = [inf inf]; % provides towing information to the AHTS
simStep.towWait       = true; % tells the vessel that the AHTS is too far away for a tow out to start
simStep.timeToTurbine = 0; % provide information about turbine assembly so the AHTS can leave for periods of time
simStep.forecast      = []; % provides an empty array for the forecast, overwritten if there is a weather module


%% Vessel Corridor Info
% To reduce the number of calculations within the simulation, the corridor travel time is calculated ahead and provided
% to vessels in the following structure.
t = 0;
for c = 2:length(MooringCorridor)
    t = t + distance(MooringCorridor(c-1,1), MooringCorridor(c-1,2), ...
        MooringCorridor(c,1), MooringCorridor(c,2), simStep.proj)/MooringCorridor(c,3);
end
mooringCorridorInfo = struct('rallyPoint', MooringCorridor(end, 1:2), 'time', round(t));

t = 0;
for c = 2:length(TowingCorridor)
    t = t + distance(TowingCorridor(c-1,1), TowingCorridor(c-1,2), ...
        TowingCorridor(c,1), TowingCorridor(c,2), simStep.proj)/TowingCorridor(c,3);
end
towingCorridorInfo = struct('rallyPoint', TowingCorridor(end, 1:2), 'time', round(t));


%% Agents
% Initialize the individual classes for each agent and provide them with necessary information for them to be spun up.
% Each variable provided to an agent is described in the architecture document.
agents = struct( ...
    ... Weather(time, windSpd, windDir, waveHs, waveTp, waveDir) 
    'Weather', Weather(wind.t, wind.Spd, wind.Dir, wave.Hstotal, wave.TpTotal, wave.DmTotal),...
    ... Towing(name, speed, speedLookup, hourlyRate, mobilizeTime, startLocation, corridor, transitLim, towingLim)
    'TowVessel', Towing(towVesselName, towTransitSpeed, [towTransitSpeed towTowSpeed], towRate, towMob, TurbineMarshalPort(1:2), towingCorridorInfo, [towTransitWave; towTransitWind], [towTowWave; towTowWind]), ...
    ... AHTS(name, speed, speedLookup, hourlyRate, mobilizeTime, startLocation, corridor, transitLim, preinstallLim, anchorLim, mooringLim)
    'AHTS', AHTS(AHTSVesselName, AHTSSpeed, [AHTSSpeed AHTSSpeed], AHTSRate, AHTSMob, MooringMarshalPort(1:2), mooringCorridorInfo, [AHTSTransitWave; AHTSTransitWind], [AHTSPreInstallWave; AHTSPreInstallWind], [AHTSAnchorWave; AHTSAnchorWind], [AHTSMooringWave; AHTSMooringWind]), ...
    ... MooringPort(name, lat, lon, hourlyRate)
    'MooringPort', MooringPort("Mooring Port", MooringMarshalPort(1), MooringMarshalPort(2), MooringMarshalPort(3)), ...
    ... TurbinePort(name, lat, lon, hourlyRate, assemblyTime, maxTurbines)
    'TurbinePort', TurbinePort("Turbine Port", TurbineMarshalPort(1), TurbineMarshalPort(2), TurbineMarshalPort(3), turbAssemblyTime, numTurbines));

% Set some data in the ports
agents.MooringPort = agents.MooringPort.addToStorage(numLines*numTurbines);
agents.TurbinePort = agents.TurbinePort.SetMaxStorage(WetStorage);
agents.TurbinePort = agents.TurbinePort.InitStorage(numTurb);


%% Run the simulation
fnames = fieldnames(agents);
done = false(size(fnames));
iterMax = 1e6;
iter = 0;
weatherCounts = zeros(size(fnames));

% iter should never approach iterMax, and in fact typically there will be an error in the weather module before 1e6
% steps occur.
while ~all(done) && iter <= iterMax
    % Step forward in time.
    simStep.time = startTime + hours(iter);

    % call each agent.
    for arr = 1:length(fnames)
        [agents.(fnames{arr}), simStep, out] = agents.(fnames{arr}).step(simStep);
        disp(out)

        % keep track of weather delays.
        if contains(out, 'delayed')
            weatherCounts(arr) = weatherCounts(arr) + 1;
        end

        % keep track of which agents have finished operations.
        if ~done(arr) && any(agents.(fnames{arr}).status ==  ["Finished", "Weather"])
            done(arr) = true;
        end
    end

    % Bookkeeping
    iter = iter + 1;
    if iter == 1
        simSave(iter) = struct('time', simStep.time, 'proj', simStep.proj, 'arrayConfig', simStep.array(:, [1 2 4]), 'arrayStatus', simStep.array(:,[4 3 5]), 'MooringStatus', simStep.mooringsIn(:,2:end), 'transitCorridor', MooringCorridor);
    else
        simSave(iter).time = simStep.time;
        simSave(iter).arrayStatus = simStep.array(:, [4 3 5]); % Array ID, status, completion time
        simSave(iter).MooringStatus = simStep.mooringsIn(:,2:end);
    end
    for f = 1:length(fnames)
        if agents.(fnames{f}).name == "Weather"
            continue;
        end
        simSave(iter).(fnames{f}) = agents.(fnames{f});
    end
end

% Convert to a table (for some reason this is more matlab memory efficient) and save
simSave = struct2table(simSave);
save([char(datetime('now','Format','yyyyMMdd''_''HHmm')) '_MORBIT_results.mat'], "simSave")


%% Quick outputs
c = 0; time = startTime;
% weather
fprintf('Weather Delays:\n');
for arr = 1:length(fnames)
    if contains(fnames{arr}, 'Weather')
        continue;
    end
    fprintf('\tThe %s was delayed for %0.1f days.\n', agents.(fnames{arr}).name, weatherCounts(arr)/24)
end

% Costs
fprintf('\nCosts: \n');
for arr = 1:length(fnames)
    if contains(fnames{arr}, 'Weather')
        continue;
    end
    fprintf('\t%s:  $%0.4fM\n', agents.(fnames{arr}).name, agents.(fnames{arr}).cost/1000000);
    c = c + agents.(fnames{arr}).cost;
end
fprintf('Total cost: $%0.4fM\n', c/1000000);

% Time
fprintf('\nTime: \n');
for arr = 1:length(fnames)
    if contains(fnames{arr}, 'Weather')
        continue;
    end
    fprintf('\tThe %s worked for %0.1f days.\n', agents.(fnames{arr}).name, days(agents.(fnames{arr}).time - startTime));
    time = max([agents.(fnames{arr}).time, time]);
end
fprintf('The %s spent %0.1f days on leave, %0.1f days docked.\n', agents.AHTS.name, agents.AHTS.timeOnLeave/24, agents.AHTS.timeDocked/24);
fprintf('The %s spent %0.1f days on leave, %0.1f days docked.\n', agents.TowVessel.name, agents.TowVessel.timeOnLeave/24, agents.TowVessel.timeDocked/24);
fprintf('Total time: %0.4f days\n', days(time - startTime))


%% Clean up
