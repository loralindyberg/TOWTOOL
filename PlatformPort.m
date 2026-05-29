%% PlatformPort
%   PlatformPort(name, lat, lon, hourlyRate, assemblyTime, arraySize)
%   This is a sub class of the Port object. This class defines properties and methods that are specific to a 
%   platform construction port and the operations therein.
%   For more detailed information about the properties in this class, please refer to the architechture document
%   provided in the containing directory.
%
%
%   Created:     Nov 11, 2025
%   Modified:    Jan 08, 2026


classdef PlatformPort < Port
    %% Public properties
    % These can be accessed from outside but cannot be set from outside a class method.
    properties (GetAccess = public, SetAccess = protected)
        % the assembly time per platform in hours
        assemblyTime (1,1) double {mustBeNumeric,mustBePositive,mustBeFinite,mustBeReal} = 318;
        % the total number of platforms that have been produced by the port
        nPlatforms (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
        % the target number of platforms to be produced during the simulation
        arraySize(1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 1;
        % the number of hours that the port is not working due to weather or other delays
        stopTime (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
        % the number of assembled platforms
        assembled (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
    end


    %% Private properties, only available to this class
    % these can only be acessed and changed from inside a class method.
    properties (Access = protected, Hidden = true)
        % defines the maximum number of platforms that can be kept in wet storage
        maxStorage (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 5;
        % this is the number of hours that the platform port has worked since sim start
        workTime (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0
    end

    %% Shared and public methods
    methods
        %% Class constructor
        function obj = PlatformPort(name, lat, lon, hourlyRate, assemblyTime, arraySize)
            obj = obj@Port(name, lat, lon, hourlyRate);
            obj.assemblyTime = assemblyTime;
            obj.arraySize = arraySize;
            
        end


        %% InitStorage
        function obj = InitStorage(obj, N)
            obj.workTime = obj.assemblyTime*N;
            obj.cost = obj.assemblyTime*obj.hourlyRate*N;
            obj.nPlatforms = N;
            obj = obj.addToStorage(N);
            obj.assembled = obj.nPlatforms;
        end


        %% SetMaxStorage
        function obj = SetMaxStorage(obj, nMax)
            obj.maxStorage = nMax;
        end

        %% step
        % this is the main funciton called in the simulation and represents actions that a platform assembly port will
        % take during a simulation.
        % out is a message that can be saved for later
        % sim is the simulation information structure
        function [obj, sim, out] = step(obj, sim)
            %% call the super class step function
            [obj, delay] = step@Port(obj, sim);


            %% This is the end condition. Once this is met, the port stops accruing cost
            if obj.status == "Finished"
                out = '';
                return
            end


            %% Check wet storage, if we are maxed out we stop
            if ~sim.loadPlatform && obj.nPlatforms == obj.maxStorage
                sim.nPlatforms = obj.nPlatforms;
                obj.stopTime = obj.stopTime + 1;
                out = strcat(obj.name, " has ", num2str(obj.nPlatforms), " platfomrs in wet storage! (TPORTBAD)");
                return
            end


            %% Enact weather delay
            if delay
                out = strcat(obj.name, " delayed by weather.");
                % catch for if a tow is looking for a Platform
                if sim.loadPlatform && obj.nPlatforms > 0
                    sim.loadPlatform = false;
                    obj = obj.removeFromStorage(1);
                    obj.nPlatforms = obj.nPlatforms - 1;
                    out = strcat(out, ".. Platform removed from wet storage.");
                end
                return
            else
                % randomly increase/decrease work time by an hour on a 1/2^n chance
                % prob = 2^6;
                % if randi([1,prob], 1) == prob
                %     obj.workTime = max([obj.workTime + sign(normrnd(0,1)), 0]);
                % end
                obj.workTime = obj.workTime + 1;
            end


            %% Logic of building platforms and adding to storage
            % update assembly line
            if obj.assembled == obj.arraySize && obj.nPlatforms == 0
                % port operations are finished
                [obj, out] = obj.finish(sim.time);
                out = strcat(out, ' All Platforms towed.');
                sim.timeToPlatform = 0;
            elseif obj.assembled == obj.arraySize
                % Platform assembly has ended, purely wet storage
                out = 'All platforms assembled.';
                obj.status = "Assembly Finished";
                sim.timeToPlatform = 0;
            elseif rem((obj.workTime - obj.assemblyTime*obj.nPlatforms)/obj.assemblyTime, obj.assemblyTime) >= 1
                % a platform has been assembled
                obj.nPlatforms = obj.nPlatforms + 1;
                obj.assembled = obj.assembled +1;
                obj = obj.addToStorage(1);
                out = 'Platform moved to storage.';
                if obj.assembled == obj.arraySize
                    sim.timeToPlatform = 0;
                else
                    sim.timeToPlatform = (1-rem((obj.workTime - obj.assemblyTime*obj.nPlatforms)/obj.assemblyTime, obj.assemblyTime))*obj.assemblyTime;
                end
            else % assembly is in progress
                out = 'Platform assembly in progress.';
                obj.status = "Assembling";
                sim.timeToPlatform = (1-rem((obj.workTime - obj.assemblyTime*obj.nPlatforms)/obj.assemblyTime, obj.assemblyTime))*obj.assemblyTime;
            end


            %% a towing vessel has requested a platform, update storage
            if sim.loadPlatform && obj.nPlatforms> 0
                sim.loadPlatform = false;
                obj = obj.removeFromStorage(1);
                obj.nPlatforms = obj.nPlatforms - 1;
                out = strcat(out, ".. Platform removed from wet storage.");
            end

            %% fill the sim variable and update internal time
            sim.nPlatforms = obj.nPlatforms;
            sim.timeToPlatform = round(sim.timeToPlatform);
        end
    end
end
