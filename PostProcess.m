load('20260330_1254_MORBIT_results.mat')


% Display total cost and time in Results Summary
%for arr = 1:length(fnames)
%    if contains(fnames{arr}, 'Weather')
%        continue;
%    end
%    c = c + agents.(fnames{arr}).cost;
%end
%text1 = sprintf('Total cost: $%0.4fM\n', c/1000000);
%text2 = sprintf('Total time: %0.4f days\n', days(simStep.time - startTime));
%disp(text1;text2)
                
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
            plot(app.ResultsPlot, daysFromStart, mooringsInProgress)
            hold (app.ResultsPlot, 'on') 
            plot(app.ResultsPlot, daysFromStart, mooringsComplete)
            plot(app.ResultsPlot, daysFromStart, turbinesComplete)
            plot(app.ResultsPlot, daysFromStart, mooringStorage)
            plot(app.ResultsPlot, daysFromStart, turbineStorage)
            legend(app.ResultsPlot, 'Moorings in Progress', 'Moorings Complete', 'Turbines Installed','Moorings in Storage', 'Turbines in Storage')
            hold (app.ResultsPlot, 'off') 
            
            % Update Results Table
            % Results = [WeatherDelays(days) WorkingTime(days) Costs(M$)]
            TowDelay = round(weatherCounts(2)/24,1); % [days] Weather delay
            TowWorking = round(days(agents.TowVessel.time - startTime),1); % [days] Working time
            TowCost = agents.TowVessel.cost/1000000; % [M$]
            AHTSDelay = round(weatherCounts(3)/24,1); % [days] Weather delay
            AHTSWorking = round(days(agents.AHTS.time - startTime),1); % [days] Working time
            AHTSCost = agents.AHTS.cost/1000000; % [M$]
            MooringPortDelay = round(weatherCounts(4)/24,1); % [days] Weather delay
            MooringPortWorking = round(days(agents.MooringPort.time - startTime),1); % [days] Working time
            MooringPortCost = agents.MooringPort.cost/1000000; % [M$]
            TurbinePortDelay = round(weatherCounts(3)/24,1); % [days] Weather delay
            TurbinePortWorking = round(days(agents.TurbinePort.time - startTime),1); % [days] Working time
            TurbinePortCost = agents.TurbinePort.cost/1000000; % [M$]
            app.ResultsTable.ColumnName = {'Tow Vessel', 'AHTS', 'Mooring Port', 'TurbinePort'};
            app.ResultsTable.RowName = {'Weather Delay (days)','Working Time (days)', 'Cost (M$)'};
            app.ResultsTable.Data = table([TowDelay;TowWorking;TowCost], [AHTSDelay;AHTSWorking;AHTSCost], [MooringPortDelay;MooringPortWorking;MooringPortCost], [TurbinePortDelay;TurbinePortWorking;TurbinePortCost]);
          