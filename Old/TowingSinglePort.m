%% Towing
%   Towing(name, speed, speedLookup, hourlyRate, mobilizeTime, startLocation, corridor, transitLim, towingLim)
%   This is a sub class of the vessel object. This class defines properties and methods that are only used for a towing
%   agent and the main functionality of the simulation.
%   For more detailed information about the properties in this class, please refer to the architechture document
%   provided in the containing directory.
%
%
%   Created:     Oct 18, 2024
%   Modified:    Jan 08, 2026 - added integration port


classdef TowingSinglePort < Vessel
    %% Private properties, only available to this class
    % these can only be acessed and changed from inside a class method.
    properties (Access = protected)
        % a logical, towing or not towing
        towing (1,1) logical {mustBeNumericOrLogical} = false
    end


    %% Shared and public methods
    methods
        %% Class constructor
        function obj = TowingSinglePort(name, speed, speedLookup, hourlyRate, mobilizeTime, startLocations, corridors, transitLim, towingLim)
            type = 'Tow Vessel';
            obj = obj@Vessel(name, type, speed, speedLookup, hourlyRate, mobilizeTime, startLocations, corridors);
            obj.limits = struct('Name', {"Transit"; "Towing"}, ...
                'Hs', {transitLim(1); towingLim(1)}, ...
                'Vhub', {transitLim(2); towingLim(2)});
        end

        %% step
        % this is the main funciton called in the simulation and represents actions that a towing vessel will take
        % during a simulation.
        % out is a message that can be saved for later
        % sim is the simulation information structure
        function [obj, sim, out] = step(obj, sim)
            %% Call the super class step function to cover all vessel specific actions
            [obj, delay] = step@Vessel(obj, sim);

            
            %% This is the end condition. Once this is met, the towing vessel stops accruing cost
            if obj.status == "Finished"
                out = '';
                return
            elseif sim.nTurbines == 0 && obj.hold == 0 && all(sim.array(:, 3) == 3)
                [obj, out] = obj.finish(sim.time);
                return
            end


            %% Basic stuff for every step regardless
            % calculate installation times based on depth
            if isempty(fieldnames(obj.installTimes))
                obj.installTimes = struct('Name', {"AssistingAHTS"}, 'Time', {20 + sim.numMoorings*6});
            end


            %% Enact delay
            if delay
                out = strcat(obj.name, " delayed by weather.");
                return
            end


            %% HOLD
            % a work around for avoiding accidentally interrupting an action
            % Currently in the middle of an action and cannot be interrupted for obj.hold hours
            if obj.hold > 0
                obj.hold = obj.hold - 1;
                if sim.PortsSame == 0
                    if obj.towing == 1 && isequal(obj.corridor, obj.corridorLookup.TurbineCorridor) && any(sim.array(:,3)==2) && sim.towInfo(3) == inf && sim.nTurbines > 0 %towing turbine to site
                        sim.towInfo = [obj.installIdx obj.hold inf];
                    elseif obj.towing == 1 && isequal(obj.corridor, obj.corridorLookup.PlatformCorridor) %towing platform to turbine port
                        sim.towInfo = [inf inf obj.hold];
                    else
                        sim.towInfo = [obj.installIdx inf inf];
                    end
                elseif sim.PortsSame == 1
                    if obj.towing == 1 && any(sim.array(:,3)==2) && sim.towInfo(3) == inf && sim.nPlatforms > 0 %towing turbine to site
                        sim.towInfo = [obj.installIdx obj.hold inf];
                    else
                        sim.towInfo = [obj.installIdx inf inf];
                    end
                end
                out = strcat(obj.name, " is currently ", obj.status, ".");
                return
            end


            

            % Decision matrix for the towing vessel
            if sim.nPlatforms > 0 && obj.lat == obj.port(1) && obj.lon == obj.port(2) && any(sim.array(:, 3) == 2)
                obj = obj.findLocation(sim.array, sim.proj);
                sim.towInfo(1) = obj.installIdx;
                % if there are available turbines, and there are available mooring site, and the towing vessel
                % is in the port
                if sim.towWait
                    % if there is not available AHTS
                    obj.status = "Docked";
                    sim.towInfo(2) = obj.transit(sim.array(obj.installIdx, 1), sim.array(obj.installIdx, 2), sim.proj).hold + 6;
                    out = strcat(obj.name, " is waiting for an available AHTS.");
                    obj.speed = obj.speedLookup(2);
                else
                    % tow a turbine out to the array
                    obj = obj.transit(sim.array(obj.installIdx, 1), sim.array(obj.installIdx, 2), sim.proj);
                    obj.hold = obj.hold + 14; % account for attaching and ballasting, etc...
                    obj.status = "Towing";
                    obj.speed = obj.speedLookup(2);
                    obj.towing = true;
                    out = strcat(obj.name, " is towing out a fully assembled Turbine (", num2str(obj.hold), "hrs).");
                    sim.loadPlatform = true;
                    sim.towInfo(2) = obj.hold;
                end
            elseif obj.installIdx ~= 999 && obj.lat == sim.array(obj.installIdx, 1) && ...
                    obj.lon == sim.array(obj.installIdx, 2) && sim.array(obj.installIdx, 3) == 2 && sim.AHTSonSite
                % we have arrived, begin installation process
                obj.status = "AssistingAHTS";
                obj.hold = obj.installTimes(1).Time;
                obj.towing = false;
                sim.towInfo(2) = inf;
                out = strcat(obj.name, " is assisting with connecting mooring lines.");
                obj.speed = obj.speedLookup(2);
            elseif obj.installIdx ~= 999 && obj.lat == sim.array(obj.installIdx, 1) && ...
                    obj.lon == sim.array(obj.installIdx, 2) && sim.array(obj.installIdx, 3) == 2
                % we have arrived, but the AHTS is not here yet
                obj.status = "OnSite";
                sim.towInfo(2) = 0;
                out = strcat(obj.name, " is waiting on site with a fully assembled turbine.");
                obj.speed = obj.speedLookup(2);
            elseif obj.installIdx ~= 999 && obj.lat == sim.array(obj.installIdx, 1) && ...
                    obj.lon == sim.array(obj.installIdx, 2) && sim.array(obj.installIdx, 3) == 3
                % installation is finished and the tow is returning to port
                obj = obj.transit(obj.port(1), obj.port(2), sim.proj);
                out = strcat(obj.name, " is returning to port.");
                obj.speed = obj.speedLookup(1);
            elseif sim.nTurbines > 0 && ~any(sim.array(:, 3) == 2)
                obj = obj.findLocation(sim.array, sim.proj);
                sim.towInfo(1) = obj.installIdx;
                obj.status = "Docked";
                obj.speed = obj.speedLookup(1);
                % wet storage has turbines but sites aren't ready
                out = strcat(obj.name, ": No sites for available turbine(s).");
            else
                % tow vessel is waiting
                obj.status = "Docked";
                out = strcat(obj.name, " is currently waiting for an available turbine.");
                obj.speed = obj.speedLookup(1);
            end  
        end
    end
end
