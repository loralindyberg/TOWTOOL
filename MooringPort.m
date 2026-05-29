%% MooringPort
%   MooringPort(name, lat, lon, hourlyRate)
%   This is a sub class of the Port object. This class defines properties and methods that are specific to a mooring
%   storage port and the operations therein.
%   For more detailed information about the properties in this class, please refer to the architechture document
%   provided in the containing directory.
%
%
%   Created:     Oct 18, 2024
%   Modified:    Jan 09, 2025


classdef MooringPort < Port
    %% Shared and public methods
    methods
        %% Class constructor
        function obj = MooringPort(name, lat, lon, hourlyRate)
            obj = obj@Port(name, lat, lon, hourlyRate);
            obj.status = "Mobilized";
        end


        %% step
        % this is the main funciton called in the simulation and represents actions that a mooring storage port will
        % take during a simulation.
        % out is a message that can be saved for later
        % sim is the simulation information structure
        function [obj, sim, out] = step(obj, sim)
            %% call the super class step function
            obj = step@Port(obj, sim);


            %% This is the end condition. Once this is met, the port stops accruing cost
            if obj.status == "Finished"
                out = '';
                return
            end


            %% The mooring port is simple. It hold moorings and accrues cost
            if any(obj.storage > 0)
                obj.status = "Moorings Ready";
            end


            %% moorings have been requested
            if sim.loadMoorings(1)
                % set this false so moorings aren't request infinitely
                sim.loadMoorings(1) = false;

                % compare request to storage
                if any(sim.loadMoorings(2) < obj.storage)
                    % if the request is less than the available storage
                    stor = sim.loadMoorings(2);
                else % this is the last of the moorings in storage
                    stor = obj.storage;
                    [obj, out] = obj.finish(sim.time);
                end

                % remove the moorings from internal storage
                obj = obj.removeFromStorage(stor);
            end

            % add the removed moorings to the simulation object to be picked up by the 
            % AHTS in the next simulation step.
            sim.nMoorings = obj.storage;


            %% Close up
            if obj.storage == 0
                [obj, out] = obj.finish(sim.time);
            end

            %% Provide an output message if nothing has happened
            if exist('out', 'var') ~= 1
                out = strcat(obj.name, " has ", num2str(obj.storage), " moorings in storage.");
            end
        end
    end
end
