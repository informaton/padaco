%   clusterObj = getClusterObj(signalFile, settingsFilename, settingStruct)
function clusterObj = getClusterObject(signalFilename, settingsFilename, varargin)
    [statTool, settings] = getStatTool(signalFilename, settingsFilename, varargin{:});
    didCalc = statTool.calcFeaturesFromFile(signalFilename);
    if ~didCalc
        error('Unable to calculate features');
    end
    
    delayedStart = false;
    cSettings = statTool.getClusterSettings(settings);
    
    extraLabel = '';
    if nargin==3
        extraLabel = ' with overriding settings';
    end
    
    % fprintf(1, 'Calculating prediction strength from %s%s.\n', signalFilename, extraLabel);
    fprintf(1, 'Clustering from from %s%s.\n', signalFilename, extraLabel);
    clusterObj = PACluster(statTool.featureStruct.features,cSettings,[],[],statTool.featureStruct.studyIDs, statTool.featureStruct.startDaysOfWeek, delayedStart);    
end
