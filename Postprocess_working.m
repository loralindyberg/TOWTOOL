%l = length(simSave.time);
l=20000;
timeFromStart = 1:l;
for i = 1:l
    statusi = simSave(i).arrayStatus(:,2);
    mooringsInProgress(i) = sum(statusi==1);
    turbinesComplete(i) = sum(statusi==3);
    mooringsComplete(i) = turbinesComplete(i) + sum(statusi==2);
    mooringStorage(i,1) = simSave(i).MooringPort.storage/6;
    turbineStorage(i,1) = simSave(i).TurbinePort.storage;
    platformStorage(i,1) = simSave(i).PlatformPort.storage;
    towStatus(i) = simSave(i).TowVessel.status;
end
daysFromStart = timeFromStart./24;
plot(daysFromStart, mooringsInProgress)
hold 'on' 
plot(daysFromStart, mooringsComplete)
plot(daysFromStart, turbinesComplete)
plot(daysFromStart, mooringStorage)
plot(daysFromStart, turbineStorage)
plot(daysFromStart, platformStorage)
legend('Moorings in Progress', 'Moorings Complete', 'Turbines Installed','Moorings in Storage', 'Turbines in Storage', 'Platforms in Storage')
hold 'off'

