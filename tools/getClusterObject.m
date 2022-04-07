%   clusterObj = getClusterObj(signalFile, settingsFilename, settingStruct)
function clusterObj = getClusterObject(signalFilename, settingsFilename, settingsStruct)
    narginchk(1,3)

    % if nargin<1 || isempty(signalFilename)
    %    signalFilename = '~/data/count_1_min_features/features/sum/features.sum.accel.count.vecMag.txt';
    % end
        
    if nargin<2
        if isunix
            settingsFilename = '~/Documents/padaco/.pasettings';
        elseif ispc
            error('Unhandled case for pc');
        end
        % settingsFilename = './.pasettings'; % can also be in the current path        
    end
    
    if isempty(settingsFilename)
        settings = PAStatTool.getDefaults();
    elseif ~exist(settingsFilename,'file')
        error('Settings file provided does not exist (%s).  Default settings can be used by using an empty value for the settings filename ('''') or removing it as an argument', signalFilename);
    else
        settings = getSettingsFromFile(settingsFilename);
        fprintf('This requires more work still to ensure StatToolSettings are used\n');
    end
    
    if nargin>=3
        settings = mergeStruct(settings, settingsStruct);
    end
    
    if isempty(settings) || (isstruct(settings) && isempty(fieldnames(settings)))
        error('Settings are empty');
    end

    figH = [];    
    statTool = PAStatTool(figH, settings);
    
    % featuresStruct = statTool.loadAlignedFeatures(signalFilename);
    
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
    fprintf(1, 'Calculating prediction strength from %s%s.\n', signalFilename, extraLabel);

    clusterObj = PACluster(statTool.featureStruct.features,cSettings,[],[],statTool.featureStruct.studyIDs, statTool.featureStruct.startDaysOfWeek, delayedStart);
                
    
end

