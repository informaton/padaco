% Test PAClassifyGravities

% Get some data 
data = vecMagData;
% data = xData;
CG = PAClassifyGravities(data);
sampleRate = 40;
CG.setSetting('sampleRate', sampleRate);
%[usageVec, wearState, startStopDateNums] = CG.classifyUsageState(gravityVec, datetimeNums, rules)
[usageVec, wearState, startStopDateNums] = CG.classifyUsageState();

tags = CG.getActivityTags();
% any(usageVec==tags.SENSOR_BURST);

sum(usageVec==tags.SENSOR_BURST)/sampleRate/60

x = (0:numel(usageVec)-1)/sampleRate;
plot(x,vecMagData,'k', x, usageVec, 'b:')

% y1 = [zeros(1,50), ones(1, 50), zeros(1, 50)];
% x1 = 1:numel(y1);
% b = ones(1,20);
% y = filter(b, 1, y1);
% plot(x1, y, x1, y1)



