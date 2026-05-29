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
%   Modified:    May 28, 2026
%
%


%% Suppressed warnings
% Suppresses the warning about not preallocating arrays before running a loop, we do not know the size of the sim array
% before we begin so it is not able to be preallocated, preallocation is used when possible.
%#ok<*SAGROW>


%% Setup
close all; clc;
clearvars -except wind wave

%% Weather Inputs
% This is weather data from the ERA5 dataset from the CDS API.
% the wind speed from the original data was scaled from 100m to 10m winds using a scaling factor of 0.14.

if ~exist('wave','var')
    load('WeatherData.mat', 'wave', 'wind');
end

% Set the start time of the simulation.
startTime = datetime(1949, 04, 01, 1, 0, 0, 0);

%% Location Inputs

% Array - Load a csv from a shp file with lat, lon, and depth
arr = readmatrix("ExampleArrayLatLon.csv");
arr = arr(1:10,:);
arraySize = size(arr,1); % The number of turbines in the array

%% Setup ports and towing corridors
[MooringMarshalPort, MooringCorridor, TurbineMarshalPort, TurbineCorridor, PlatformMarshalPort,...
    PlatformCorridor, PlatformPortToFarm] = initializeCorridors();


%% Vessel Inputs

% Towing Vessel
towVesselName = 'Tow';
towTransitSpeed = 14;   % [km/h] Transit speed
towTowSpeed = 9;        % [km/h] Tow-out speed
towRate = 1458;         % [$/hr] Hourly rate
towMob = 1;            % [hr] Mobilize time
towTransitWave = 4.75;  % [m] Wave height limit during transit
towTransitWind = 25;    % [m/s] Wind speed limit during transit
towTowWave = 4;       % [m] Wave height limit during tow-out
towTowWind = 15;        % [m/s] Wind speed limit during tow-out - m/s

% AHTS Vessel
AHTSVesselName = 'Dino';
AHTSSpeed = 14;         % [km/h]
AHTSRate = 4167;        % [$/hr] Hourly rate
AHTSMob = 1;           % [hr] Mobilize time
AHTSTransitWave = 4.5;  % [m] Wave height limit during transit
AHTSTransitWind = 20;   % [m/s] Wind speed limit during transit
AHTSPreInstallWave = 4.3; % [m] Wave height limit during pre-install
AHTSPreInstallWind = 20; % [m/s] Wind speed limit during pre-install
AHTSAnchorWave = 4.1;   % [m] Wave height limit during anchor install
AHTSAnchorWind = 20;    % [m/s] Wind speed limit during anchor install
AHTSMooringWave = 4;    % [m] Wave height limit during mooring install
AHTSMooringWind = 15;   % [m/s] Wind speed limit during mooring install


%% Misc Inputs
numLines    = 6;            % number of lines per turbine
turbAssemblyTime = 168/4;     % [hr]
platformAssemblyTime = 336/4; % [hr]
WetStorage_Turbines = 10;    % Max. wet storage capacity at turbine port
WetStorage_Platforms = 10;   % Max. wet storage capacity at platform port
init_Turbines = 0;          % Number of turbines in wet storage at start
init_Platforms = 10;         % Number of platforms in wet storage at start

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

% simStep.array defines all of the simulation-important information about the WEA.
% array is lat, lon, status, id, completion time, depth (m)
% status can be as follows:
% 0 - Nothing installed
% 1 - Mooring Install In Progress
% 2 - Moorings installed
% 3 - Turbine installed


simStep.array = [arr(:, [6,7]),...
    zeros(size((1:arraySize)')),...
    (1:arraySize)',...
    zeros(size((1:arraySize)')), abs(arr(:, 3))];
simStep.mooringsIn = [simStep.array(:, 4), zeros(size(simStep.array,1), 6)];

% instantiating communications throughout the simulation.
simStep.loadTurbine   = false; % Is the tow vessel loading a turbine
simStep.loadPlatform  = false; % Is the tow vessel loading a platform
simStep.loadPlat      = false; % Is the tow vessel unloading a platform
simStep.loadMoorings  = false; % Is the AHTS loading mooring lines
simStep.nMoorings     = 0; % number of moorings provided to ahts by the mooring port
simStep.nTurbines     = init_Turbines; % number of fully assembled turbines in wet storage at turbine port
simStep.nPlatforms    = init_Platforms; % number of platforms (without turbines) in wet storage at platform port
simStep.nPlat         = 0; % number of platforms in wet storage at turbine port (need to be assembled)
simStep.wetStorage_Turbines = WetStorage_Turbines; %Wet storage max capacity
simStep.wetStorage_Platforms = WetStorage_Platforms; %Wet storage max capacity
simStep.numMoorings   = numLines; % provides number of moorings to the sim
simStep.AHTSonSite    = false; % tells the towing vessel if the AHTS is on site for hook up
simStep.towInfo       = [-inf -inf -inf]; % provides towing information to the AHTS
simStep.towWait       = true; % tells the vessel that the AHTS is too far away for a tow out to start
simStep.timeToTurbine = 0; % provide information about turbine assembly so the AHTS can leave for periods of time
simStep.forecast      = []; % provides an empty array for the forecast, overwritten if there is a weather module
simStep.assembled     = 0; %


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
for c = 2:length(TurbineCorridor)
    t = t + distance(TurbineCorridor(c-1,1), TurbineCorridor(c-1,2), ...
        TurbineCorridor(c,1), TurbineCorridor(c,2), simStep.proj)/TurbineCorridor(c,3);
end
turbineCorridorInfo = struct('rallyPoint', TurbineCorridor(end, 1:2), 'time', round(t));

t = 0;
for c = 2:length(PlatformCorridor)
    t = t + distance(PlatformCorridor(c-1,1), PlatformCorridor(c-1,2), ...
        PlatformCorridor(c,1), PlatformCorridor(c,2), simStep.proj)/PlatformCorridor(c,3);
end
platformCorridorInfo = struct('rallyPoint', PlatformCorridor(end, 1:2), 'time', round(t));

t = 0;
for c = 2:length(PlatformPortToFarm)
    t = t + distance(PlatformPortToFarm(c-1,1), PlatformPortToFarm(c-1,2), ...
        PlatformPortToFarm(c,1), PlatformPortToFarm(c,2), simStep.proj)/PlatformPortToFarm(c,3);
end
platformPortToFarmInfo = struct('rallyPoint', PlatformPortToFarm(end, 1:2), 'time', round(t));

if PlatformMarshalPort == TurbineMarshalPort
    PortsSame = 1; %yes
    TowPortLocation = TurbineMarshalPort;
    TowCorridorInfo = platformCorridorInfo;
else
    PortsSame = 0; %no
    TowPortLocation = [PlatformMarshalPort; TurbineMarshalPort];
    TowCorridorInfo = struct('PlatformCorridor',platformCorridorInfo,'TurbineCorridor',turbineCorridorInfo,'PortToFarm',platformPortToFarmInfo);
end

simStep.PortsSame     = PortsSame; % Is turbine port the same as platform port


%% Agents
% Initialize the individual classes for each agent and provide them with necessary information for them to be spun up.
% Each variable provided to an agent is described in the architecture document.
agents = struct( ...
    ... Weather(time, windSpd, windDir, waveHs, waveTp, waveDir)
    'Weather', Weather(wind.t, wind.Spd, wind.Dir, wave.Hstotal, wave.TpTotal, wave.DmTotal), ...
    ... Towing(name, speed, speedLookup, hourlyRate, mobilizeTime, turbineLocation, turbineCorridor, portLocations, Corridors, transitLim, towingLim, simStep)
    'TowVessel', TowingMulti(towVesselName, towTransitSpeed, [towTransitSpeed towTowSpeed], towRate, towMob, TowPortLocation, TowCorridorInfo, [towTransitWave; towTransitWind], [towTowWave; towTowWind]), ...
    ... AHTS(name, speed, speedLookup, hourlyRate, mobilizeTime, startLocation, corridor, transitLim, preinstallLim, anchorLim, mooringLim)
    'AHTS', AHTS(AHTSVesselName, AHTSSpeed, [AHTSSpeed AHTSSpeed], AHTSRate, AHTSMob, MooringMarshalPort(1:2), mooringCorridorInfo, [AHTSTransitWave; AHTSTransitWind], [AHTSPreInstallWave; AHTSPreInstallWind], [AHTSAnchorWave; AHTSAnchorWind], [AHTSMooringWave; AHTSMooringWind]), ...
    ... MooringPort(name, lat, lon, hourlyRate)
    'MooringPort', MooringPort("Mooring Port", MooringMarshalPort(1), MooringMarshalPort(2), MooringMarshalPort(3)), ...
    ... TurbinePort(namelat, lon, hourlyRate, assemblyTime, arraySize)
    'TurbinePort', TurbinePort("Turbine Port", TurbineMarshalPort(1), TurbineMarshalPort(2), TurbineMarshalPort(3), turbAssemblyTime, arraySize));

% Set some data in the ports
agents.MooringPort = agents.MooringPort.addToStorage(numLines*arraySize);
agents.TurbinePort = agents.TurbinePort.SetMaxStorage(WetStorage_Turbines);
agents.TurbinePort = agents.TurbinePort.InitStorage(init_Turbines);

if PortsSame == 0
    % Add platform port as a new agent (separate from Turbine Port)
    agents = setfield(agents, ...
        ...PlatformPort(name, lat, lon, hourlyRate, assemblyTime, arraySize)
        'PlatformPort', PlatformPort("Platform Port", PlatformMarshalPort(1), PlatformMarshalPort(2), PlatformMarshalPort(3), platformAssemblyTime, arraySize));

    agents.PlatformPort = agents.PlatformPort.SetMaxStorage(WetStorage_Platforms);
    agents.PlatformPort = agents.PlatformPort.InitStorage(init_Platforms);
end


%% Run the simulation
fnames = fieldnames(agents);
done = false(size(fnames));
iterMax = 1e6;
iter = 0;
weatherCounts = zeros(size(fnames));

% iter should never approach iterMax, and in fact typically there will be an error in the weather module before 1e6
% steps occur.
% towInfoA = simStep.towInfo;
towInfoA = agents.TowVessel.status;
while ~all(done) && iter <= iterMax
    % Step forward in time.


    simStep.time = startTime + hours(iter);
    simStep.iter = iter + 1;

    if ~strcmp(towInfoA, agents.TowVessel.status)
        % disp(simStep.towInfo)
        % disp(agents.TowVessel.status)
        towInfoA = agents.TowVessel.status;
    end



    % call each agent.
    for arr = 1:length(fnames)
        
        [agents.(fnames{arr}), simStep, out] = agents.(fnames{arr}).step(simStep);
        % disp(out)

        % keep track of weather delays.
        if contains(out, 'delayed')
            weatherCounts(arr) = weatherCounts(arr) + 1;
        end

        % keep track of which agents have finished operations.
        if ~done(arr) && any(agents.(fnames{arr}).status ==  ["Finished", "Weather"])
            done(arr) = true;
        end
    end

    simStep.agents = agents;

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
% save([char(datetime('now','Format','yyyyMMdd''_''HHmm')) '_MORBIT_results.mat'], "simSave")


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


%% Postprocess
% Update results plot
l = length(simSave.time);
timeFromStart = 1:l;
for i = 1:l
    statusi = simSave.arrayStatus{i,1}(:,2);
    mooringsInProgress(i) = sum(statusi==1);
    turbinesComplete(i) = sum(statusi==3);
    mooringsComplete(i) = turbinesComplete(i) + sum(statusi==2);
    mooringStorage(i,1) = simSave.MooringPort(i,1).storage/6;
    turbineStorage(i,1) = simSave.TurbinePort(i,1).storage;
end
daysFromStart = timeFromStart./24;
plot(daysFromStart, mooringsInProgress)
hold on
plot(daysFromStart, mooringsComplete)
plot(daysFromStart, turbinesComplete)
plot(daysFromStart, mooringStorage)
plot(daysFromStart, turbineStorage)
legend('Moorings in Progress', 'Moorings Complete', 'Turbines Installed','Moorings in Storage', 'Turbines in Storage')
hold 'off'

% Update Results Table
% Results = [WeatherDelays(days) WorkingTime(days) Costs(M$)]
% TowDelay = round(weatherCounts(2)/24,1); % [days] Weather delay
% TowWorking = round(days(agents.TowVessel.time - startTime),1); % [days] Working time
% TowCost = agents.TowVessel.cost/1000000; % [M$]
% AHTSDelay = round(weatherCounts(3)/24,1); % [days] Weather delay
% AHTSWorking = round(days(agents.AHTS.time - startTime),1); % [days] Working time
% AHTSCost = agents.AHTS.cost/1000000; % [M$]
% MooringPortDelay = round(weatherCounts(4)/24,1); % [days] Weather delay
% MooringPortWorking = round(days(agents.MooringPort.time - startTime),1); % [days] Working time
% MooringPortCost = agents.MooringPort.cost/1000000; % [M$]
% TurbinePortDelay = round(weatherCounts(3)/24,1); % [days] Weather delay
% TurbinePortWorking = round(days(agents.TurbinePort.time - startTime),1); % [days] Working time
% TurbinePortCost = agents.TurbinePort.cost/1000000; % [M$]
% app.ResultsTable.ColumnName = {'Tow Vessel', 'AHTS', 'Mooring Port', 'TurbinePort'};
% app.ResultsTable.RowName = {'Weather Delay (days)','Working Time (days)', 'Cost (M$)'};
% app.ResultsTable.Data = table([TowDelay;TowWorking;TowCost], [AHTSDelay;AHTSWorking;AHTSCost], [MooringPortDelay;MooringPortWorking;MooringPortCost], [TurbinePortDelay;TurbinePortWorking;TurbinePortCost]);
%