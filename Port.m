%% Port
%   Port(name, lat, lon, hourlyRate)
%   This is a base class for all ports. Properties and methods that are shared across port types, such as day
%   rates, names, and status (properties) or accrue costs (methods).
%   For more detailed information about the properties in this class, please refer to the architechture document
%   provided in the containing directory.
%
%
%   Created:     Oct 18, 2024
%   Modified:    Jan 09, 2025


classdef Port
    %% Properties that are shared across all port types
    % These can be accessed from outside but cannot be set from outside a class/subclass method.
    properties (GetAccess = public, SetAccess = protected)
        % latitude in decimal degrees
        lat (1,1) double {mustBeNumeric,mustBeFinite,mustBeReal}
        % longitude in decimal degrees
        lon (1,1) double {mustBeNumeric,mustBeFinite,mustBeReal}
        % the hourly cost of the port
        hourlyRate (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 2740
        % the name/identifier of this port
        name (1,1) string {mustBeText,mustBeNonzeroLengthText} = "Default Port"
        % the current status of the port, used in the simulation
        status (1,1) string {mustBeText,mustBeNonzeroLengthText} = "null"
        % the total accrued costs of the port
        cost (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0
        % the number of items in storage for this port (moorings, turbine wet storage, etc...)
        storage double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0
        % the time that the port finished operations
        time (1,1) datetime
    end


    %% Shared and public methods
    methods
        %% Class constructor
        function obj = Port(name, lat, lon, hourlyRate)
            % port identifiers
            obj.name = name;

            % port location
            obj.lat = lat;
            obj.lon = lon;

            % port costs
            obj.hourlyRate = hourlyRate;
        end


        %% step
        % this is the main funciton called in the simulation and represents actions that every port will take at every
        % timestep.
        function [obj, delay] = step(obj, sim)
            % update costs
            obj = obj.incrementCost;

            % weather delay
            delay = false;
            if obj.status ~= "Finished" && ~isempty(sim.forecast)
                % call the superclass method checkWeather
                [obj, delay] = obj.checkWeather(sim.forecast);
            end
        end


        %% addToStorage
        % Adds amount to storage
        function obj = addToStorage(obj, amount)
            obj.storage = obj.storage + amount;
        end


        %% removeFromStorage
        % removes amount from storage
        function obj = removeFromStorage(obj, amount)
            obj.storage = obj.storage - amount;
        end
    end


    %% Shared but private methods
    methods (Access = protected)
        %% incrementCost
        % increments costs and scales based on status
        function obj = incrementCost(obj)
            switch obj.status
                case "Delayed"
                    scale = 0.8;
                case "Finished"
                    scale = 0.0;
                otherwise
                    scale = 1;
            end
            obj.cost = obj.cost + obj.hourlyRate * scale;
        end


        %% checkWeather
        % compares the current weather forecast to see if operations should pause
        function [obj, delay] = checkWeather(obj, forecast)
            % preallocate output, only turns true if weather delay
            delay = false;

            % extract the limits and compare to the current forecast
            hs = 2;
            vhub = 25;

            % check for a delay
            if forecast(1, 1) > vhub || forecast(1, 3)/5 > hs
                obj.status = "Delayed";
                delay = true;
            end
        end


        %% finish
        % close up operations
        function [obj, out] = finish(obj, t)
            obj.status = "Finished";
            out = strcat(obj.name, " storage has been emptied.");
            obj.time = t;
            return
        end
    end
end
