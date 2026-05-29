%% TurbinePort
%   TurbinePort(name, lat, lon, hourlyRate, assemblyTime, maxTurbines)
%   This is a sub class of the Port object. This class defines properties and methods that are specific to a turbine
%   assembly port and the operations therein.
%   For more detailed information about the properties in this class, please refer to the architechture document
%   provided in the containing directory.
%
%
%   Created:     Oct 18, 2024
%   Modified:    Jan 09, 2025


classdef TurbinePort < Port
    %% Public properties
    % These can be accessed from outside but cannot be set from outside a class method.
    properties (GetAccess = public, SetAccess = protected)
        % the assembly time per turbine in hours
        assemblyTime (1,1) double {mustBeNumeric,mustBePositive,mustBeFinite,mustBeReal} = 318;
        % the total number of turbines that have been produced by the port
        nTurbines (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
        % the target number of turbines to be produced during the simulation
        maxTurbines (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 1;
        % the number of hours that the port is not working due to weather or other delays
        stopTime (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0;
    end


    %% Private properties, only available to this class
    % these can only be acessed and changed from inside a class method.
    properties (Access = protected, Hidden = true)
        % defines the maximum number of turbines that can be kept in wet storage
        maxStorage (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 5;
        % this is the number of hours that the turbine port has worked since sim start
        workTime (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0
    end

    %% Shared and public methods
    methods
        %% Class constructor
        function obj = TurbinePort(name, lat, lon, hourlyRate, assemblyTime, maxTurbines)
            obj = obj@Port(name, lat, lon, hourlyRate);
            obj.assemblyTime = assemblyTime;
            obj.maxTurbines = maxTurbines;
        end


        %% InitStorage
        function obj = InitStorage(obj, N)
            obj.workTime = obj.assemblyTime*N;
            obj.cost = obj.assemblyTime*obj.hourlyRate*N;
            obj.nTurbines = N;
            obj = obj.addToStorage(N);
        end


        %% SetMaxStorage
        function obj = SetMaxStorage(obj, nMax)
            obj.maxStorage = nMax;
        end

        %% step
        % this is the main funciton called in the simulation and represents actions that a turbine assembly port will
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
            if ~sim.loadTurbine && obj.storage == obj.maxStorage
                sim.nTurbines = obj.storage;
                obj.stopTime = obj.stopTime + 1;
                out = strcat(obj.name, " has ", num2str(obj.storage), " turbines in wet storage! (TPORTBAD)");
                return
            end


            %% Enact weather delay
            if delay
                out = strcat(obj.name, " delayed by weather.");
                % catch for if a tow is looking for a turbine
                if sim.loadTurbine && obj.storage > 0
                    sim.loadTurbine = false;
                    obj = obj.removeFromStorage(1);
                    out = strcat(out, ".. Turbine removed from wet storage.");
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


            %% Logic of building turbines and adding to storage
            % update assembly line
            if obj.nTurbines == obj.maxTurbines && obj.storage == 0
                % port operations are finished
                [obj, out] = obj.finish(sim.time);
                out = strcat(out, ' All turbines towed.');
                sim.timeToTurbine = 0;
            elseif obj.nTurbines == obj.maxTurbines
                % Turbine assembly has ended, purely wet storage
                out = 'All turbines assembled.';
                obj.status = "Assembly Finished";
                sim.timeToTurbine = 0;
            elseif rem((obj.workTime - obj.assemblyTime*obj.nTurbines)/obj.assemblyTime, obj.assemblyTime) >= 1
                % a turbine has been assembled
                obj.nTurbines = obj.nTurbines + 1;
                obj = obj.addToStorage(1);
                out = 'Turbine moved to storage.';
                if obj.nTurbines == obj.maxTurbines
                    sim.timeToTurbine = 0;
                else
                    sim.timeToTurbine = (1-rem((obj.workTime - obj.assemblyTime*obj.nTurbines)/obj.assemblyTime, obj.assemblyTime))*obj.assemblyTime;
                end
            else % assembly is in progress
                out = 'Turbine assembly in progress.';
                obj.status = "Assembling";
                sim.timeToTurbine = (1-rem((obj.workTime - obj.assemblyTime*obj.nTurbines)/obj.assemblyTime, obj.assemblyTime))*obj.assemblyTime;
            end


            %% a towing vessel has requested a turbine, update storage
            if sim.loadTurbine && obj.storage > 0
                sim.loadTurbine = false;
                obj = obj.removeFromStorage(1);
                out = strcat(out, ".. Turbine removed from wet storage.");
            end


            %% fill the sim variable and update internal time
            sim.nTurbines = obj.storage;
            sim.timeToTurbine = round(sim.timeToTurbine);
        end
    end
end
