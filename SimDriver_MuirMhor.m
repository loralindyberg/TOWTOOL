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

ToggleWeatherData = "CSV"; %"MAT"; %"CSV";
if ~exist('wave','var')
    if ToggleWeatherData == "CSV"
        try 
            weatherData = readtable('WeatherData.csv');
        catch
            error("ERROR - weather data not loaded. Check file type")
        end
        wave.t = weatherData.t;
        wave.HsTotal = weatherData.SignificantWaveHeight_m_;
        wave.TpTotal = weatherData.PeakWavePeriod_s_;
        wave.DmTotal = weatherData.WaveDirection_deg_;
        wind.t = weatherData.t;
        wind.Spd = weatherData.WindSpeed_m_s_;
        wind.Dir = weatherData.WindDirection_deg_;
    elseif ToggleWeatherData == "MAT"
        try    
            load('WeatherData.mat', 'wave', 'wind');
        catch
            error("ERROR - weather data not loaded. Check file type")
        end
    end
end

% Set the start time of the simulation.
startTime = datetime(1949, 04, 01, 1, 0, 0, 0);

%% Location Inputs

% Array - Load a csv from a shp file with lat, lon, and depth
arr = readmatrix("TowToolArray - Muir Mhor.csv");
arraySize = size(arr,1); % The number of turbines in the array

% if water depth is <100 - increase to 100
arr(:,3) = abs(arr(:,3));
for j = 1:arraySize
    if arr(j,3) < 100
        arr(j,3) = 100;
    end
end

%% Setup ports and towing corridors
humboldt  = [40.807565, -124.162268, 2700]; %lat, lon, rate
sanfran   = [37.794402, -122.391938, 2700];
longbeach = [33.739737, -118.205367, 2700];
searsport = [44.451783, -68.902169, 2700];
lanouvelle = [43.01667, 3.05, 2700];
nigg = [57.70056, -4.03846, 2700];
montrose = [56.7, -2.4667, 2700];
aberdeen = [57.14141, -2.0698, 2700];
talbot= [51.5947, -3.7841, 2700];

fileType = 'Direct'; %'CSV'
if strcmp(fileType,'CSV')
    MooringCorridor = readmatrix('MooringCorridor - Muir Mohr.csv');
    MooringMarshalPort = [MooringCorridor(1,1),MooringCorridor(1,2), 2700];
elseif strcmp(fileType,'Direct')
    MooringMarshalPort = aberdeen;
    MooringCorridor = [
        MooringMarshalPort(1:2)];
end

if strcmp(fileType,'CSV')
    TurbineCorridor = readmatrix('TurbineCorridor - Muir Mohr.csv');
    TurbineIntegrationPort = [TurbineCorridor(1,1),TurbineCorridor(1,2), 2700];
elseif strcmp(fileType,'Direct')
    TurbineIntegrationPort = nigg;
    TurbineCorridor = [
        TurbineIntegrationPort(1:2)];
end

if strcmp(fileType,'CSV')
    PlatformCorridor = readmatrix('TurbineCorridor - Muir Mohr.csv');
    PlatformConstructionPort = [PlatformCorridor(1,1),PlatformCorridor(1,2), 2700];
elseif strcmp(fileType,'Direct')
    PlatformConstructionPort = nigg;
    PlatformCorridor = [PlatformConstructionPort(1,1), PlatformConstructionPort(1,2)];
end

if strcmp(fileType,'CSV')
    TransitCorridor = readmatrix('TurbineCorridor - Muir Mohr.csv');
elseif strcmp(fileType,'Direct')
    TransitCorridor = [PlatformConstructionPort(1,1), PlatformConstructionPort(1,2)];
end

%[MooringMarshalPort, MooringCorridor, TurbineIntegrationPort, TurbineCorridor, PlatformConstructionPort,...
%    PlatformCorridor, TransitCorridor] = initializeCorridors();


%% Vessel Inputs

% Towing Vessel
tow1VesselName = 'Tow1';
tow1TransitSpeed = 14;   % [km/h] Transit speed
tow1TowSpeed = 9;        % [km/h] Tow-out speed
tow1Rate = 1458;         % [$/hr] Hourly rate
tow1Mob = 1;            % [hr] Mobilize time
tow1TransitWave = 4.75;  % [m] Wave height limit during transit
tow1TransitWind = 25;    % [m/s] Wind speed limit during transit
tow1TowWave = 4;       % [m] Wave height limit during tow-out
tow1TowWind = 15;        % [m/s] Wind speed limit during tow-out - m/s
tow1Lim = 0;             % limit to only tow platforms (not turbines), 1=yes, 0=no  

% Towing Vessel
noTowVessels = 1;
tow2VesselName = 'Tow2';
tow2TransitSpeed = 14;   % [km/h] Transit speed
tow2TowSpeed = 9;        % [km/h] Tow-out speed
tow2Rate = 1458;         % [$/hr] Hourly rate
tow2Mob = 1;             % [hr] Mobilize time
tow2TransitWave = 4.75;  % [m] Wave height limit during transit
tow2TransitWind = 25;    % [m/s] Wind speed limit during transit
tow2TowWave = 4;         % [m] Wave height limit during tow-out
tow2TowWind = 15;        % [m/s] Wind speed limit during tow-out - m/s
tow2Lim = 1;             % limit to only tow platforms (not turbines), 1=yes, 0=no  

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
AHTSStorageLimit = 3;       % [no. mooring spreads] AHTS storage capacity


%% Misc Inputs
numLines    = 6;            % number of lines per turbine
turbAssemblyTime = 168;     % [hr]
platformAssemblyTime = 336; % [hr]
WetStorage_Turbines = 10;    % Max. wet storage capacity at turbine port
WetStorage_Platforms = 10;   % Max. wet storage capacity at platform port
init_Turbines = 5;           % Number of turbines in wet storage at start
init_Platforms = 1;          % Number of platforms in wet storage at start

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
simStep.loadTurbine   = false(noTowVessels,1); % Is the tow vessel loading a turbine
simStep.loadPlatform  = false(noTowVessels,1); % Is the tow vessel loading a platform
simStep.loadPlat      = false(noTowVessels,1); % Is the tow vessel unloading a platform
simStep.loadMoorings  = false; % Is the AHTS loading mooring lines
simStep.nMoorings     = 0; % number of moorings provided to ahts by the mooring port
simStep.nTurbines     = init_Turbines; % number of fully assembled turbines in wet storage at turbine port
simStep.nPlatforms    = init_Platforms; % number of platforms (without turbines) in wet storage at platform port
simStep.nPlat         = 0; % number of platforms in wet storage at turbine port (need to be assembled)
simStep.wetStorage_Turbines = WetStorage_Turbines; %Wet storage max capacity
simStep.wetStorage_Platforms = WetStorage_Platforms; %Wet storage max capacity
simStep.numMoorings   = numLines; % provides number of moorings to the sim
simStep.AHTSonSite    = false; % tells the towing vessel if the AHTS is on site for hook up
simStep.towInfo       = -inf(noTowVessels,3); % provides towing information to the AHTS
    %COLUMN 1: ID of turbine (999 if no turbine)
    %COLUMN 2: Time until arrival at array (if towing between turbine port & array)
    %COLUMN 3: Time until arrival at turbine port (if towing between ports)
    %ROW DETERMINED BY TOWING VESSEL NO
    disp(simStep.towInfo)
simStep.towWait       = true; % tells the vessel that the AHTS is too far away for a tow out to start
simStep.timeToTurbine = 0; % provide information about turbine assembly so the AHTS can leave for periods of time
simStep.forecast      = []; % provides an empty array for the forecast, overwritten if there is a weather module
simStep.assembled     = 0; %
simStep.AHTSHelpIdx   = 998; % No of tow vessel AHTS is assisting (998 if none)


if tow2Lim == 1 || tow1Lim == 1
    simStep.towLim = 1; % if one of the towing vessels is limited
else 
    simStep.towLim = 0;
end

%% Vessel Corridor Info
% To reduce the number of calculations within the simulation, the corridor distance is calculated ahead and provided
% to vessels in the following structure.
dist = 0;
if length(MooringCorridor(:,1))>=2
    for c = 2:length(MooringCorridor(:,1))
        dist = dist + distance(MooringCorridor(c-1,1), MooringCorridor(c-1,2), ...
            MooringCorridor(c,1), MooringCorridor(c,2), simStep.proj);
    end
    MooringCorridorInfo = struct('rallyPoint', MooringCorridor(end, 1:2), 'dist', round(dist));
else
    MooringCorridorInfo = struct([]);
end

dist = 0;
if length(TurbineCorridor(:,1))>=2
    for c = 2:length(TurbineCorridor(:,1))
        dist = dist + distance(TurbineCorridor(c-1,1), TurbineCorridor(c-1,2), ...
            TurbineCorridor(c,1), TurbineCorridor(c,2), simStep.proj);
    end
    TurbineCorridorInfo = struct('rallyPoint', TurbineCorridor(end, 1:2), 'dist', round(dist));
else
    TurbineCorridorInfo = struct([]);
end

dist = 0;
if length(PlatformCorridor(:,1))>=2
    for c = 2:length(PlatformCorridor(:,1))
        dist = dist + distance(PlatformCorridor(c-1,1), PlatformCorridor(c-1,2), ...
            PlatformCorridor(c,1), PlatformCorridor(c,2), simStep.proj);
    end
    PlatformCorridorInfo = struct('rallyPoint', PlatformCorridor(end, 1:2), 'dist', round(dist));
else
    PlatformCorridorInfo = struct([]);
end

dist = 0;
if length(TransitCorridor(:,1)) >=2
    for c = 2:length(TransitCorridor(:,1))
        dist = dist + distance(TransitCorridor(c-1,1), TransitCorridor(c-1,2), ...
            TransitCorridor(c,1), TransitCorridor(c,2), simStep.proj);
    end
    TransitCorridorInfo = struct('rallyPoint', TransitCorridor(end, 1:2), 'dist', round(dist));
else
    TransitCorridorInfo = struct([]);  
end

if PlatformConstructionPort == TurbineIntegrationPort
    PortsSame = 1; %yes
    TowPortLocation = [PlatformConstructionPort];
    TowCorridorInfo = PlatformCorridorInfo;
else
    PortsSame = 0; %no
    TowPortLocation = [PlatformConstructionPort; TurbineIntegrationPort];
    TowCorridorInfo = struct('PlatformCorridor',PlatformCorridorInfo,'TurbineCorridor',TurbineCorridorInfo,'TransitCorridor',TransitCorridorInfo);
end

simStep.PortsSame     = PortsSame; % Is turbine port the same as platform port

%% Input error handlng
if tow1Lim == 1 && tow2Lim == 1
    disp("Warning - both tow vessels are limited and will not tow fully assembled platforms")
elseif tow1Lim == 1 && PortsSame == 1
    disp("Warning - Tow vessel #1 is limited and will not be used")
elseif tow2Lim == 1 && PortsSame == 1
    disp('Warning - Tow vessle #2 is limited and will not be used')
elseif init_Turbines + init_Platforms > arraySize  
    disp('Warning - More turbines than needed in wet storage')
elseif PortsSame == 1 && nPlatforms > 0
    disp('Warning - initial platforms in wet storage at platform port will be ignored')
    nPlatforms = 0;
end


%% Agents
% Initialize the individual classes for each agent and provide them with necessary information for them to be spun up.
% Each variable provided to an agent is described in the architecture document.
agents = struct( ...
    ... Weather(time, windSpd, windDir, waveHs, waveTp, waveDir)
    'Weather', Weather(wind.t, wind.Spd, wind.Dir, wave.HsTotal, wave.TpTotal, wave.DmTotal), ...
    ... Towing(name, speed, speedLookup, hourlyRate, mobilizeTime, turbineLocation, turbineCorridor, portLocations, Corridors, transitLim, towingLim, number)
    'TowVessel1', Towing(tow1VesselName, tow1TransitSpeed, [tow1TransitSpeed tow1TowSpeed], tow1Rate, tow1Mob, TowPortLocation, TowCorridorInfo, [tow1TransitWave; tow1TransitWind], [tow1TowWave; tow1TowWind],tow1Lim,1));
    
if noTowVessels == 2
    agents = setfield(agents, ...
        ... Towing(name, speed, speedLookup, hourlyRate, mobilizeTime, turbineLocation, turbineCorridor, portLocations, Corridors, transitLim, towingLim, number)
        'TowVessel2', Towing(tow2VesselName, tow2TransitSpeed, [tow2TransitSpeed tow2TowSpeed], tow2Rate, tow2Mob, TowPortLocation, TowCorridorInfo, [tow2TransitWave; tow2TransitWind], [tow2TowWave; tow2TowWind],tow2Lim,2));
end

agents = setfield(agents,...
    ... AHTS(name, speed, speedLookup, hourlyRate, mobilizeTime, startLocation, corridor, transitLim, preinstallLim, anchorLim, mooringLim, capacity)
    'AHTS', AHTS(AHTSVesselName, AHTSSpeed, [AHTSSpeed AHTSSpeed], AHTSRate, AHTSMob, MooringMarshalPort(1:2), MooringCorridorInfo, [AHTSTransitWave; AHTSTransitWind], [AHTSPreInstallWave; AHTSPreInstallWind], [AHTSAnchorWave; AHTSAnchorWind], [AHTSMooringWave; AHTSMooringWind], AHTSStorageLimit));
agents = setfield(agents,...
    ... MooringPort(name, lat, lon, hourlyRate)
    'MooringPort', MooringPort("Mooring Port", MooringMarshalPort(1), MooringMarshalPort(2), MooringMarshalPort(3)));
if PortsSame == 0
    % Add Platform port agent
    agents = setfield(agents, ...
        ...PlatformPort(name, lat, lon, hourlyRate, assemblyTime, arraySize)
        'PlatformPort', PlatformPort("Platform Port", PlatformConstructionPort(1), PlatformConstructionPort(2), PlatformConstructionPort(3), platformAssemblyTime, arraySize));
    agents.PlatformPort = agents.PlatformPort.SetMaxStorage(WetStorage_Platforms);
    agents.PlatformPort = agents.PlatformPort.InitStorage(init_Platforms);
end
agents = setfield(agents,...    
    ... TurbinePort(namelat, lon, hourlyRate, assemblyTime, arraySize)
    'TurbinePort', TurbinePort("Turbine Port", TurbineIntegrationPort(1), TurbineIntegrationPort(2), TurbineIntegrationPort(3), turbAssemblyTime, arraySize));
    

% Set some data in the ports
agents.MooringPort = agents.MooringPort.addToStorage(numLines*arraySize);
agents.TurbinePort = agents.TurbinePort.SetMaxStorage(WetStorage_Turbines);
agents.TurbinePort = agents.TurbinePort.InitStorage(init_Turbines);



%% Run the simulation
fnames = fieldnames(agents);
done = false(size(fnames));
iterMax = 1e6;
iter = 0;
weatherCounts = zeros(size(fnames));

% iter should never approach iterMax, and in fact typically there will be an error in the weather module before 1e6
% steps occur.
% towInfoA = simStep.towInfo;
% towInfoA = agents.TowVessel.status;
while ~all(done) && iter <= iterMax
    % Step forward in time.
    simStep.time = startTime + hours(iter);
    simStep.iter = iter + 1;

    % if ~strcmp(towInfoA, agents.TowVessel.status)
        % disp(simStep.towInfo)
        % disp(agents.TowVessel.status)
        % towInfoA = agents.TowVessel.status;
    % end



    % call each agent.
    for a = 1:length(fnames)

        [agents.(fnames{a}), simStep, out] = agents.(fnames{a}).step(simStep);
        %disp(out)

        % keep track of weather delays.
        if contains(out, 'delayed')
            weatherCounts(a) = weatherCounts(a) + 1;
        end

        % keep track of which agents have finished operations.
        if ~done(a) && any(agents.(fnames{a}).status ==  ["Finished", "Weather"])
            done(a) = true;
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
    
    %catch error
    if simStep.agents.TowVessel1.status ==  "Towing"
        tow1stat = 1;
    elseif isfinite(simStep.towInfo(1,2))
        tow1stat = 1;
    elseif isfinite(simStep.towInfo(1,3))
        tow1stat = 1;
    else
        tow1stat = 0;
    end
    %if simStep.agents.TowVessel2.status == "Towing"
    %    tow2stat = 1;
    %elseif isfinite(simStep.towInfo(2,2))
    %    tow2stat = 1;
    %elseif isfinite(simStep.towInfo(2,3))
    %    tow2stat = 1;
    %else 
    %    tow2stat = 0;
    %end
    if simStep.agents.AHTS.status == "ConnectingMoorings"
        AHTSstat = 1;
    else
        AHTSstat = 0;
    end
    installed = sum(simStep.array(:,3) == 3,'all');
    turb = simStep.nTurbines + simStep.nPlatforms + simStep.nPlat + tow1stat + installed + AHTSstat; %+ tow2stat;
    disp(turb)
    disp("Wet Storage - turbines:"+ simStep.nTurbines +", plats:"+simStep.nPlat+", Platforms:"+simStep.nPlatforms)
    disp("Installed - "+installed)
    if tow1stat == 1
        disp('Tow 1 is towing')
    end
    %if tow2stat == 1
    %    disp('Tow 2 is towing')
    %end
    if AHTSstat == 1
        disp('AHTS is installing')
    end
    if turb<10
        %error('Execution Stopped: we lost a turbine!')
    end
end

% Convert to a table (for some reason this is more matlab memory efficient) and save
simSave = struct2table(simSave);
save('TOWTOOL_results_new.mat', "simSave")


%% Quick outputs
c = 0; time = startTime;
% weather
fprintf('Weather Delays:\n');
for a = 1:length(fnames)
    if contains(fnames{a}, 'Weather')
        continue;
    end
    fprintf('\tThe %s was delayed for %0.1f days.\n', agents.(fnames{a}).name, weatherCounts(a)/24)
end

% Costs
fprintf('\nCosts: \n');
for a = 1:length(fnames)
    if contains(fnames{a}, 'Weather')
        continue;
    end
    fprintf('\t%s:  $%0.4fM\n', agents.(fnames{a}).name, agents.(fnames{a}).cost/1000000);
    c = c + agents.(fnames{a}).cost;
end
fprintf('Total cost: $%0.4fM\n', c/1000000);

% Time
fprintf('\nTime: \n');
for a = 1:length(fnames)
    if contains(fnames{a}, 'Weather')
        continue;
    end
    fprintf('\tThe %s worked for %0.1f days.\n', agents.(fnames{a}).name, days(agents.(fnames{a}).time - startTime));
    time = max([agents.(fnames{a}).time, time]);
end
fprintf('The %s spent %0.1f days on leave, %0.1f days docked.\n', agents.AHTS.name, agents.AHTS.timeOnLeave/24, agents.AHTS.timeDocked/24);
% fprintf('The %s spent %0.1f days on leave, %0.1f days docked.\n', agents.TowVessel.name, agents.TowVessel.timeOnLeave/24, agents.TowVessel.timeDocked/24);
fprintf('Total time: %0.4f days\n', days(time - startTime))


%% Postprocess
% Update results plot
disp('Simulation Complete. Updating Results Plot')
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
disp('Results Plot Updated')

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