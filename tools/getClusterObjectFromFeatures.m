function clusterObj = getClusterObjectFromFeatures(features, studyIDs, startDaysOfWeek, settingsFilename, varargin)
    [statTool, settings] = getStatTool([], settingsFilename, varargin{:});
        
    delayedStart = false;
    cSettings = statTool.getClusterSettings(settings);
    
    extraLabel = '';
    if nargin==3
        extraLabel = ' with overriding settings';
    end
        
    fprintf(1, 'Clustering from passed features%s.\n', extraLabel);
    clusterObj = PACluster(features,cSettings,[],[],studyIDs, startDaysOfWeek, delayedStart);    
end
