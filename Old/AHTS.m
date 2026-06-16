%% AHTS
%   AHTS(name, speed, hourlyRate, mobilizeTime, startLocation, corridor, transitLim, preinstallLim, anchorLim, mooringLim)
%   This is a sub class of the vessel object. This class defines properties and methods that are only used for AHTS
%   agents and the main functionality of the simulation.
%   For more detailed information about the properties in this class, please refer to the architechture document
%   provided in the containing directory.
%
%
%   Created:     Oct 18, 2024
%   Modified:    Jan 09, 2025


classdef AHTS < Vessel
    %% Public properties
    % These can be accessed from outside but cannot be set from outside a class method.
    % defaults are based on the dino.
    properties (GetAccess = public, SetAccess = protected)
        % the maximum number of moorings that can be reasonably loaded onto the AHTS
        storageLimit (1,1) double {mustBeNumeric,mustBePositive,mustBeFinite,mustBeReal} = 18
    end


    %% Private properties, only available to this class
    % these can only be acessed and changed from inside a class method.
    properties (Access = protected)
        % the number of moorings currently installed at the current location
        moorsIn (1,1) double  {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0
        % the slope of the line for interpolating the storage limits
        slope (1,1) double {mustBeNumeric,mustBeFinite,mustBeReal} = 999
        % the intercept of the line for interpolating the storage limits
        intercept (1,1) double {mustBeNumeric,mustBeFinite,mustBeReal} = 999
        % the current storage of the AHTS
        storage (1,1) double {mustBeNumeric,mustBeNonnegative,mustBeFinite,mustBeReal} = 0
    end


    %% Shared and public methods
    methods
        %% Class constructor
        function obj = AHTS(name, speed, speedLookup, hourlyRate, mobilizeTime, startLocation, corridor, transitLim, preinstallLim, anchorLim, mooringLim)%, cable)
            type = 'AHTS';
            obj = obj@Vessel(name, type, speed, speedLookup, hourlyRate, mobilizeTime, startLocation, corridor)
            obj.limits = struct('Name', {"Transit"; "PreInstall"; "InstallingAnchor"; "InstallingMooring"}, ...
                'Hs', {transitLim(1); preinstallLim(1); anchorLim(1); mooringLim(1)}, ...
                'Vhub', {transitLim(2); preinstallLim(2); anchorLim(2); mooringLim(2)});

            % Initialize the AHTS install times for pre-lay analysis
            obj.installTimes = struct('Name',{"PreInstall"; "InstallingAnchor"; "InstallingMooring"; "ConnectingMoorings"}, ...
                    'Time', {0; 0; 0; 20 + obj.moorsPerTurb});
        end


        %% step
        % this is the main funciton called in the simulation and represents actions that an AHTS will take during a
        % simulation.
        % out is a message that can be saved for later
        % sim is the simulation information structure
        function [obj, sim, out] = step(obj, sim)
            %% Call the super class step function to cover all vessel specific actions
            [obj, delay] = step@Vessel(obj, sim);


            %% This is the end condition. Once this is met, the AHTS stops accruing cost
            if obj.status == "Finished"
                out = '';
                return
            elseif all(obj.storage == 0) && all(sim.nMoorings == 0) && obj.hold == 0 && all(sim.array(:, 3) == 3)
                [obj, out] = obj.finish(sim.time);
                return
            end


            %% Basic stuff for every step regardless
            % calculate installation times based on depth
            if (obj.installIdx ~= 999 && obj.depth ~= sim.array(obj.installIdx, 6))
                obj.depth = sim.array(obj.installIdx, 6);
                obj.installTimes = struct('Name',{"PreInstall"; "InstallingAnchor"; "InstallingMooring"; "ConnectingMoorings"}, ...
                    'Time', {1; round(4 + 0.005 * obj.depth); round(0.005 * obj.depth); 20 + obj.moorsPerTurb});
            end

            if obj.slope == 999
                p = polyfit([min(sim.array(:,6)),max(sim.array(:,6))], [18, 16], 1);
                obj.slope = p(1);
                obj.intercept = p(2);
            end


            %% Enact delay
            if delay
                % disp(obj.heldStatus)
                out = strcat(obj.name, " delayed by weather.");
                return
            end


            %% HOLD
            % a work around for avoiding accidentally interrupting an action
            % Currently in the middle of an action and cannot be interrupted for obj.hold hours
            if obj.hold > 0
                obj.hold = obj.hold - 1;
                out = strcat(obj.name, " is currently ", obj.status);
                if obj.hold == 0
                    switch obj.status
                        case "ConnectingMoorings"
                            sim.array(sim.towInfo(1), 3) = 3;
                            sim.array(sim.towInfo(1), 5) = convertTo(sim.time, 'datenum');
                            sim.AHTSonSite = false;
                        case "InstallingMooring"
                            if obj.moorsIn == 0
                                sim.array(obj.installIdx, 3) = 2;
                            end
                        case "Transit"
                            if obj.lat ~= obj.port(1) &&  obj.lon ~= obj.port(2)
                                % 5 hours away and not in port so flip the tow switch
                                sim.towWait = false;
                            end
                        case {"Leave", "Docked"}
                            if sim.towInfo(1) ~= 999
                                obj = obj.transit(sim.array(sim.towInfo(1), 1), sim.array(sim.towInfo(1), 2), sim.proj);
                            end
                    end
                elseif isfinite(sim.towInfo(2)) && obj.hold >= sim.towInfo(2) && sim.towWait
                    % intercept the vessel while it steams back to the array and reset its hold time so it
                    % goes to hookup a turbine instead...?
                    h = obj.hold;
                    obj = obj.transit(sim.array(sim.towInfo(1), 1), sim.array(sim.towInfo(1), 2), sim.proj);
                    obj.hold = h;
                    sim.towWait = false;
                    out = strcat(obj.name, " changing course to assist with turbine hookup.");
                end
                return
            end

            %% Connect mooring lines
            % Help attach moorings. This comes before other logic because it is of utmost importance
            % the AHTS must always be available to come to connect a turbine.
            if isfinite(sim.towInfo(2))
                % if a turbine is being towed out
                if obj.lat == sim.array(sim.towInfo(1), 1) && obj.lon == sim.array(sim.towInfo(1), 2)
                    % if we are on site
                    if sim.towInfo(2) == 0
                        % if the turbine is on site
                        out = strcat(obj.name, " connecting mooring lines.");
                        obj.status = "ConnectingMoorings";
                        obj.hold = obj.installTimes([obj.installTimes(:).Name] == obj.status).Time;
                        sim.AHTSonSite = true;
                        return
                    elseif all(sim.towInfo(2) > [obj.installTimes(:).Time])
                        6;
                    else
                        % AHTS arrived before the towing vessel
                        out = strcat(obj.name, " is waiting on site.");
                        obj.status = "Waiting";
                        sim.AHTSonSite = true;
                        return
                    end
                elseif distance(obj.lat, obj.lon, sim.array(sim.towInfo(1), 1), sim.array(sim.towInfo(1), 2), sim.proj) > obj.speed*sim.towInfo(2) || ...
                        any(sim.towInfo(2) <= [obj.installTimes(:).Time])
                    % if a turbine is being towed out and we cannot perform the next install phase in time
                    obj = obj.transit(sim.array(sim.towInfo(1), 1), sim.array(sim.towInfo(1), 2), sim.proj);
                    out = strcat(obj.name, " moving to assist with turbine hookup.");
                    return
                end
            end

            %% Next in line of importance, transit
            % Transit between locations
            if obj.status ~= "Transit"
                if obj.lat == obj.port(1) && obj.lon == obj.port(2) && all(obj.storage > 0)
                    % transit from the port to the array
                    % find the closest array point that needs moorings/anchors or return to previous point
                    if obj.installIdx == 999 || sim.array(obj.installIdx, 3) >= 2
                        obj = obj.findLocation(sim.array, sim.proj);
                    end
                    obj = obj.transit(sim.array(obj.installIdx, 1), sim.array(obj.installIdx, 2), sim.proj);
                    out = strcat(obj.name, "is beginning transit to the array (", num2str(obj.hold), "hrs).");
                    return
                elseif all(obj.storage > 0) && sim.array(obj.installIdx, 3) >= 2
                    % The designated array point is installed and storage is not empty, transit to another array point
                    % find the closest array point that needs moorings/anchors
                    obj = obj.findLocation(sim.array, sim.proj);
                    obj = obj.transit(sim.array(obj.installIdx, 1), sim.array(obj.installIdx, 2), sim.proj);
                    out = strcat(obj.name, " is moving to a new installation site.");
                    return
                elseif all(obj.storage > 0) &&...
                        (obj.lat ~= sim.array(obj.installIdx, 1) || obj.lon ~= sim.array(obj.installIdx, 2)) && ...
                        sim.array(obj.installIdx, 3) < 2
                    % return to previous installation site after assisting with turbine hookup
                    obj = obj.transit(sim.array(obj.installIdx, 1), sim.array(obj.installIdx, 2), sim.proj);
                    out = strcat(obj.name, " is returning to the installation site post turbine connection.");
                elseif all(obj.storage == 0) &&  obj.lat ~= obj.port(1) && obj.lon ~= obj.port(2) && any(sim.array(:, 3) < 2)
                    % Transit back to port because storage is empty and more sites need to be finished
                    obj = obj.transit(obj.port(1), obj.port(2), sim.proj);
                    out = strcat(obj.name, " is returning to port to restock.");
                    sim.towWait = true;
                    return
                end
            end

            %% Next level priority: Load storage
            % load mooring lines onto ahts
            if any(obj.status == ["Transit", "Mobilizing"]) && obj.lat == obj.port(1) && obj.lon == obj.port(2) && ...
                    all(obj.storage == 0) && any(sim.nMoorings > 0)
                % modify storage based on depth
                loc = obj.findLocation(sim.array, sim.proj).installIdx;
                if loc ~= 999
                    obj.storageLimit = round(obj.intercept + obj.slope * sim.array(loc, 6));
                    % check the simulation object for how many moorings are available
                    % request max, or the stored number of moorings if nMoorings < max
                    requestedMoorings = min([sim.nMoorings, obj.storageLimit]);
                    t = 5;
                    out = strcat("Loading AHTS for ", num2str(t), " hours.");
                    obj.hold = t;
                    obj.status = "LoadingMoorings";
                    sim.loadMoorings = [true, requestedMoorings];
                    obj.storage = requestedMoorings;
                    return
                end
            end

            %% Next level priority: Do a site install
            % installation process
            if obj.installIdx ~= 999 && obj.lat == sim.array(obj.installIdx, 1) && obj.lon == sim.array(obj.installIdx, 2) && ...
                    all(obj.storage > 0) && sim.array(obj.installIdx, 3) < 2
                if ~any([obj.installTimes(:).Time] > sim.towInfo(2)) % make sure we aren't up against a tow window
                    % Make sure it's "In progress" while we're installing
                    sim.array(obj.installIdx, 3) = 1;
                    if any(obj.status == ["Transit", "InstallingMooring"])
                        obj.status = "PreInstall";
                        out = strcat(obj.name, " is beginning pre-install.");
                    elseif obj.status == "PreInstall"
                        obj.status = "InstallingAnchor";
                        out = strcat(obj.name, " is beginning anchor installation.");
                    elseif obj.status == "InstallingAnchor"
                        obj.status = "InstallingMooring";
                        obj.storage = obj.storage - 1;
                        obj.moorsIn = obj.moorsIn + 1;
                        out = strcat(obj.name, " is beginning mooring installation.");
                        sim.mooringsIn(obj.installIdx, obj.moorsIn+1) = convertTo(sim.time, 'datenum') + obj.installTimes([obj.installTimes(:).Name] == obj.status).Time;
                    end
                    obj.hold = obj.installTimes([obj.installTimes(:).Name] == obj.status).Time;
                else
                    out = strcat(obj.name, " is waiting... Tow in progress.");
                end

                % check if this site is finished
                if obj.moorsIn == obj.moorsPerTurb
                    obj.moorsIn = 0;
                    out = strcat(out, " Site nearly finished!");
                end
                return
            end


            %% THE AHTS HAS DONE NOTHING AT ALL
            if exist('out', 'var') ~= 1
                if all(sim.array(:, 3) >= 2) && sim.nTurbines < 1
                    if sim.timeToTurbine > obj.transit(obj.port(1), obj.port(2), sim.proj).hold*2 + 72 || sim.towInfo(2) > obj.transit(obj.port(1), obj.port(2), sim.proj).hold*2 + 72
                        % All mooring installation points are installed and turbines are currently at a long
                        % lead time. Go on leave to allow wet storage to fill.
                        out = strcat("ALL MOORINGS INSTALLED.    ", obj.name, " is currently awaiting orders. Going on ", num2str(sim.timeToTurbine), "hr leave.");
                        obj = obj.transit(obj.port(1), obj.port(2), sim.proj);
                        if sim.timeToTurbine == 0 && isfinite(sim.towInfo(2))
                            obj.hold = sim.towInfo(2) - obj.hold; % subtract return time from the leave calculation
                        else
                            obj.hold = max([sim.timeToTurbine - obj.hold, 0]); % subtract return time from the leave calculation
                        end
                        obj.status = "Leave";
                        sim.towWait = true;
                    elseif sim.timeToTurbine > obj.transit(obj.port(1), obj.port(2), sim.proj).hold*2.1
                        % All mooring installation points are installed and a turbine is near completion. Dock.
                        out = strcat("ALL MOORINGS INSTALLED.    ", obj.name, " is docking for ", num2str(sim.timeToTurbine), "hrs.");
                        obj = obj.transit(obj.port(1), obj.port(2), sim.proj);
                        obj.hold = sim.timeToTurbine - obj.hold; % subtract return time from the docked calculation
                        obj.status = "Docked";
                        sim.towWait = true;
                    else
                        % All mooring installation points are installed and a turbine is so close we can't dock
                        out = strcat("ALL MOORINGS INSTALLED.    Turbine ready in ", num2str(sim.timeToTurbine), "hrs. ", obj.name, " waiting.");
                        obj.hold = sim.timeToTurbine - obj.hold; % subtract return time from the docked calculation
                        obj.status = "Waiting";
                    end
                elseif isfinite(sim.towInfo(2)) && sim.towInfo(2) <= obj.transit(obj.port(1), obj.port(2), sim.proj).hold*2.1
                    % We are too far from port to return before the turbine arrives, so wait until it is on site
                    out = strcat("Turbine nearly on site, ", obj.name, " is waiting.");
                    obj.status = "Waiting";
                elseif isfinite(sim.towInfo(2)) && sim.towInfo(2) > obj.transit(obj.port(1), obj.port(2), sim.proj).hold*2.1
                    % No more installations until another turbine is on site, dock and wait
                    out = strcat("Towed turbine is far away, ", obj.name, " is docking.");
                    obj = obj.transit(obj.port(1), obj.port(2), sim.proj);
                    obj.hold = sim.towInfo(2) - obj.hold; % subtract return time from the docked calculation
                    obj.status = "Docked";
                elseif ~isfinite(sim.towInfo(2))
                    % The tow has not begun a return trip with a new turbine, dock
                    out = strcat("No turbines being towed, ", obj.name, " is docking.");
                    obj = obj.transit(obj.port(1), obj.port(2), sim.proj);
                elseif any(sim.array(:, 3) < 2) && any(sim.timeToTurbine < [obj.installTimes(:).Time])
                    % We can't start an install right now because a turbine is coming out
                    out = strcat("Turbine nearly done, ", obj.name, " is waiting. (AHTSBAD).");
                    obj.status = "Waiting";
                else
                    out = strcat(obj.name, " is currently awaiting orders (AHTSBAD).");
                    obj.status = "Waiting";
                end
            end
        end
    end
end
