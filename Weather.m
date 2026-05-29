%% Weather
%   Weather(time, windSpd, windDir, waveHs, waveTp, waveDir)
%   The weather class is an agent that is designed to provide a forcast of N days. It is supplied with time series data
%   for time, wind characteristics, and wave characteristics.
%
%
%   Created:     Oct 28, 2024
%   Modified:    Jan 09, 2025


classdef Weather
    %% Properties that are shared across all port types
    properties (GetAccess = public, SetAccess = private)
        % the identifier for the weather object
        name (1,1) string {mustBeText,mustBeNonzeroLengthText} = "Weather"
        % the current forecast
        forecast (:, 5) double {mustBeNumeric,mustBeFinite,mustBeReal} = zeros(1,5)
        % a placeholder as status is needed for the simulation
        status (1,1) string {mustBeText,mustBeNonzeroLengthText} = "Weather"
    end


    %% Properties that are hidden
    % these can only be accessed and changed from inside a class method.
    properties (Hidden = true)
        % the time array as datetimes for the weather data
        time (:,1) datetime
        % the wind speed array in m/s for the weather data
        windSpd (:,1) double {mustBeNumeric,mustBeNonempty,mustBeNonmissing,mustBeFinite,mustBeReal} = 0
        % the wind direction in degrees array for the weather data
        windDir (:,1) double {mustBeNumeric,mustBeNonempty,mustBeNonmissing,mustBeFinite,mustBeReal} = 0
        % the wave height array in m for the weather data
        waveHs (:,1) double {mustBeNumeric,mustBeNonempty,mustBeNonmissing,mustBeFinite,mustBeReal} = 0
        % the wave period array in s for the weather data
        waveTp (:,1) double {mustBeNumeric,mustBeNonempty,mustBeNonmissing,mustBeFinite,mustBeReal} = 0
        % the wave direction array in degrees for the weather data
        waveDir (:,1) double {mustBeNumeric,mustBeNonempty,mustBeNonmissing,mustBeFinite,mustBeReal} = 0
        % the number of hours in the forecast, maximumm of 240
        nForecasts (1,1) double {mustBeNumeric,mustBeNonempty,mustBeNonmissing,mustBePositive,mustBeFinite,mustBeReal} = 239
    end


    %% Shared and public methods
    methods
        %% Class constructor
        function obj = Weather(time, windSpd, windDir, waveHs, waveTp, waveDir, nDays)
            % time
            obj.time = time;

            % wind conditions
            obj.windSpd = windSpd;
            obj.windDir = windDir;

            % wave conditions
            obj.waveHs  = waveHs;
            obj.waveTp  = waveTp;
            obj.waveDir = waveDir;

            % set forcast length
            if nargin == 7
                % forecast cannot be longer than 10 days
                if nDays > 10; warning('Forecast cannot be longer than 10 days.'); end
                obj.nForecasts = min([obj.nForecasts, (nDays*10)-1]);
            end
        end


        %% step
        % this is the main funciton called in the simulation.
        % out is a message that can be saved for later
        % sim is the simulation information structure
        function [obj, sim, out] = step(obj, sim)
            % based on the current sim time, generate the forecast
            tStep = sim.time;
            % idx   = find(obj.time > tStep, 1, "first");% & obj.time < tStep + hours(239);
            idx = sim.iter;
            % disp(idx-sim.iter)
            try
            sim.forecast = [obj.windSpd(idx:(idx+obj.nForecasts)), ...
                obj.windDir(idx:(idx+obj.nForecasts)), ...
                obj.waveHs(idx:(idx+obj.nForecasts)), ...
                obj.waveTp(idx:(idx+obj.nForecasts)), ...
                obj.waveDir(idx:(idx+obj.nForecasts))];
            catch ME
                6;
            end
            obj.forecast = sim.forecast;
            out = '';
        end
    end
end
