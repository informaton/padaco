% Test PAClassifyGravities

% Get some data 
% vecMagData = ....

CG = PAClassifyGravities(vecMagData);
CG.setSetting('sampleRate',40);
%[usageVec, wearState, startStopDateNums] = CG.classifyUsageState(gravityVec, datetimeNums, rules)
[usageVec, wearState, startStopDateNums] = CG.classifyUsageState();