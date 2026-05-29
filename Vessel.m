%% Vessel
%   Vessel(name, speed, hourlyRate, mobilizeTime, startLocation, corridor)
%   This is a base class for all vessels. Properties and methods that are shared across vessel types, such as day
%   rates, names, and status (properties) or mobilization and transit (methods).
%   For more detailed information about the properties in this class, please refer to the architechture document
%   provided in the containing directory.
%
%
%   Created:     Oct 18, 2024
%   Modified:    Jan 09, 2025
%   Modified:    Mar 02, 2026 - AL - Added integration port


classdef Vessel
    %% Properties that are shared across all vessel types
    % These can be accessed from outside but cannot be set from outside a class/subclass method.
    % AL Note: These properties are hard coded, but can be redefined in function below (if not redefined, will be these values)
    properties (GetAccess = public, SetAccess = protected)
        % the average vessel speed in transit/towing in km/h
        speed (1,1) double {mustBeNumeric,mustBePositive,mustBeFinite,mustBeReal} = 14;
        % 
        speedLookup(1,2) double {mustBeNumeric,mustBePositive,mustBeFinite,mustBeReal} = [14,9];
        % the hourly rate of the vessel
        hourlyRate (1,1) double {mustBeNumeric,mustBePositive,mustBeFinite,mustBeReal} = 4166.67;
        % the name/identifier of the vessel
        name (1,1) string {mustBeText,mustBeNonzeroLengthText} = "Default Vessel"
        % the type of vessel
        type (1,1) string {mustBeText,mustBeNonzeroLengthText} = "Default Vessel"
        % the number of moorings per turbine
        moorsPerTurb (1,1) double {mustBeNumeric,mustBePositive,mustBeFinite,mustBeReal} = 3;
        % the status of the agent at each simulation step
        status (1,1) string {mustBeText,mustBeNonzeroLengthText} = "null"
        % the accrued cost of the vessel over the simulation
        cost (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
        % "holds" a vessel on a task for the number of hours it is designated to take
        hold (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
        % the number of hours it takes to mobilize this vessel
        mobilizeTime (1,1) double {mustBeNumeric,mustBePositive,mustBeFinite,mustBeReal} = 72;
        % current latitude in decminal degrees of the vessel
        lat (1,1) double {mustBeNumeric,mustBeFinite,mustBeReal} = 40;
        % current longitude in decminal degrees of the vessel
        lon (1,1) double {mustBeNumeric,mustBeFinite,mustBeReal} = -68;
        % the time that the vessel finished all operations
        time (1,1) datetime = NaT
        % number of hours on the leave status
        timeOnLeave (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
        % number of hours on the docked status
        timeDocked (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
        % the port of origin of this vessel, where it goes to dock and take leave
        port (2,1) double {mustBeNumeric,mustBeFinite,mustBeReal} = [40.7523, -124.2091]
        % the port(s) of origin 
        portLookup (2,2) double {mustBeNumeric,mustBeFinite,mustBeReal} = [40.7523, -124.2091; 0, 0]
        % used for weather delays to keep track of what the vessel was doing before the delay
        heldStatus (1,1) string {mustBeText,mustBeNonzeroLengthText} = "null"
        % information for the transit corridor
        corridor struct = struct()
        % the transfer corridors (if multiple ports)
        corridorLookup struct = struct()
    end


    %% Private properties, only available to the class and subclasses
    % these can only be acessed and changed from inside a class/subclass method.
    properties (Access = protected)
        % depth of the current array location
        depth (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0
        % install times based on the current installation location and depth
        installTimes struct = struct()
        % the current index in sim.array where operations are being held
        installIdx (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 999
        % weather based limits for various actions the vessel can take
        limits struct = struct()
    end


    %% Shared and public methods
    methods
        %% Class constructor
        function obj = Vessel(name, type, speed, speedLookup, hourlyRate, mobilizeTime, startLocation, corridor)
            % Save vessel identifiers.
            obj.name = name;
            obj.type = type;

            % Save vessel information.
            obj.mobilizeTime = mobilizeTime;
            obj.hourlyRate = hourlyRate;
            obj.speedLookup = speedLookup;

            % AHTS - save vessel starting location and port location
            if obj.type == 'AHTS'
                obj.lat = startLocation(1,1);
                obj.lon = startLocation(1,2);
                obj.port = [startLocation(1,1), startLocation(1,2)];
                obj.corridor = corridor;

            % Tow Vessel - Save vessel starting location (assume platform port) and port location.
            elseif obj.type == 'Tow Vessel'
                obj.lat = startLocation(1,1);
                obj.lon = startLocation(1,2);
                obj.port = startLocation(1,1:2);
                obj.corridorLookup = corridor;
                if size(startLocation,1) == 1
                    obj.portLookup = startLocation(1:2);
                    obj.corridor = corridor;
                else
                    obj.portLookup = startLocation(:,1:2);
                    obj.corridor = corridor.PlatformCorridor;
                end
            else 
                disp('ERROR: Unrecognized vessel type')
            end

            % Initialize the mobilization oh the vessel.
            obj = obj.mobilize();
        end


        %% step
        % this is the main funciton called in the simulation and represents actions that every vessel will take at every
        % timestep.
        function [obj, delay] = step(obj, sim)
            % Reduce speed if towing
            if obj.status == 'Towing'
                obj.speed = obj.speedLookup(2);
            else
                obj.speed = obj.speedLookup(1);
            end
            
            % Get the number of moorings from the simulation object
            if obj.moorsPerTurb ~= sim.numMoorings
                obj.moorsPerTurb = sim.numMoorings;
            end

            % Check docked or leave status and count
            if obj.status == "Leave"
                obj.timeOnLeave = obj.timeOnLeave + 1;
            elseif obj.status == "Docked"
                obj.timeDocked = obj.timeDocked + 1;
            end

            % Accrue costs
            obj = obj.incrementCost;

            % Weather delay
            % check that there is a forecast in the sim object
            delay = false;
            if obj.status ~= "Finished" && ~isempty(sim.forecast)
                % call the superclass method checkWeather
                [obj, delay] = obj.checkWeather(sim.forecast);
                % if there is a delay
                if ~delay
                    % if we were just in a delay, restore status
                    if obj.heldStatus ~= "null"
                        obj.status = obj.heldStatus;
                        obj.heldStatus = "null";
                    end
                end
            end

            % Randomly add an hour to the hold time
            % prob = 2^5;
            % if obj.hold > 0 && randi([1,prob], 1) == prob
            %     % if hold hits 0 here it will break other things so min out at 1
            %     obj.hold = max([obj.hold + sign(normrnd(0,1)), 1]);
            % end
        end
    end


    %% Shared but private methods
    methods (Access = protected)
        %% mobilize
        % sets the "Mobilizing" status and hold time
        function obj = mobilize(obj)
            obj.hold = obj.mobilizeTime;
            obj.status = "Mobilizing";
        end


        %% transit
        % sets up the necessary behaviors for the "Transit" status
        function [obj, out] = transit(obj, lat, lon, proj)
            % Multi-port - Switch port & corridor
            if obj.type == "Tow Vessel" && obj.portLookup(2,2) ~= 0 %if multiple ports
                if obj.lat == obj.portLookup(1,1) && obj.lon == obj.portLookup(2,2) % if vessel is currently in platform port
                    % tow platform to turbine port
                    obj.corridor = obj.corridorLookup.PlatformCorrdior;
                elseif obj.lat == obj.portLookup(2,1) && obj.lon == obj.portLookup(2,2) % if vessel currently in turbine port
                    % and needs to go to platform port
                    if lat == obj.portLookup(1,1) && lon == obj.portLookup(1,2)
                        obj.corridor = obj.corridorLookup.PlatformCorridor;
                    % and needs to tow a turbine out
                    else
                        obj.corridor = obj.corridorLookup.TurbineCorridor;
                    end
                else % vessel is not in either port 
                    % and needs to go to the turbine port
                    if lat == obj.portLookup(2,1) && lon == obj.portLookup(2,2)
                        obj.corridor = obj.corridorLookup.TurbineCorridor;
                    % and needs to go to platform port
                    elseif lat == obj.portLookup(1,1) && lon == obj.portLookup(1,2)
                        try
                        obj.corridor = obj.corridorLookup.TurbineCorridor;
                        catch me
                            6;
                        end
                    end
                end
            end
            
            % check for a corridor, if none just do transit as before
            % confirm corridor information
            if ~isempty(obj.corridor) && (lat == obj.port(1) && lon == obj.port(2))
                % on the way to the port
                to = [obj.corridor.rallyPoint(1), obj.corridor.rallyPoint(2)];
                fro = [obj.lat, obj.lon];
                t = obj.corridor.time;
            elseif ~isempty(obj.corridor) && (obj.lat == obj.port(1) && obj.lon == obj.port(2))
                % on the way from the port
                to = [lat, lon];
                fro = [obj.corridor.rallyPoint(1), obj.corridor.rallyPoint(2)];
                t = obj.corridor.time;
            else
                % corridor not needed/not given
                to = [lat, lon]; fro = [obj.lat, obj.lon]; t = 0;
            end

            % transit distance
            dist = distance(to(1), to(2), fro(1), fro(2), proj);

            % transit details
            t = t + round(dist/obj.speed);
            out = strcat(obj.name, ' in transit for ', num2str(t), ' hours.');

            % information for the vessel
            obj.hold = t;
            obj.status = "Transit";
            obj.lat = lat;
            obj.lon = lon;
        end


        %% incrementCost
        % accrues hourly costs, scaled based on status
        function obj = incrementCost(obj)
            switch obj.status
                case "Leave"
                    scale = 0.5;
                case "Docked"
                    scale = 0.8;
                case {"Transit", "Towing"}
                    scale = 1.1;
                case "Finished"
                    scale = 0.0;
                otherwise
                    scale = 1;
            end
            obj.cost = obj.cost + obj.hourlyRate * scale;
        end


        %% findLocation
        % find the next grid location to go to
        function obj = findLocation(obj, simArray, proj)
            % Sub classes have slightly different behaviors
            switch class(obj)
                case 'AHTS'
                    possLocs = simArray(simArray(:, 3) < 2, :);
                case 'Towing'
                    possLocs = simArray(simArray(:, 3) == 2, :);
                otherwise
                    possLocs = simArray(simArray(:, 3) < 3, :);
            end

            % pick the closest point to the vessel
            [~, minIdx] = min(distance(possLocs(:,1), possLocs(:, 2), obj.lat, obj.lon, proj));

            % select the index in the original array corresponding to the ID of the selected location
            try
                idx = find(possLocs(minIdx, 4) == simArray(:, 4));
            catch
                idx = 999;
            end

            % save the index
            if ~isempty(idx)
                obj.installIdx = idx;
            end
        end


        %% checkWeather
        % compares the current weather forecast against the current action
        % and if relevant the appropriate installation time
        function [obj, delay] = checkWeather(obj, forecast)
            % preallocate output, only turns true if weather delay
            delay = false;

            % check if our current status matches a limit
            if obj.status ~= "Delayed"
                il = obj.status == [obj.limits(:).Name];
                st = obj.status;
            else
                il = obj.heldStatus == [obj.limits(:).Name];
                st = obj.heldStatus;
            end

            % check if the current status has limits
            if any(il)
                % extract the limits and compare to the current forecast
                hs = obj.limits(il).Hs;
                vhub = obj.limits(il).Vhub;
                if all(st ~= ["Transit", "Towing"])
                    t = obj.installTimes([obj.installTimes(:).Name] == st).Time;
                else
                    t = min([obj.hold length(forecast)]);
                end
                if any(forecast(1:t, 1) > vhub) || any(forecast(1:t, 3) > hs)
                    if obj.status ~= "Delayed"
                        obj.heldStatus = obj.status;
                    end
                    obj.status = "Delayed";
                    delay = true;
                end
            end
        end


        %% finish
        % close up operations
        function [obj, out] = finish(obj, t)
            obj.status = "Finished";
            out = strcat(obj.name, " is finished with all operations.");
            obj.time = t;
            return
        end
    end
end
