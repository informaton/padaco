%   predStrength = getPredictionStrength(signalFile [, exclusionsFile [, start_stop_time]])
function [predStrength, optimal_k, statTool] = getPredictionStrength(signalFilename, settingsFilename, settingsStruct, showGUI)
    % narginchk(1,2)
    predStrength = [];
    if nargin<1 || isempty(signalFilename)
        signalFilename = '~/data/count_1_min_features/features/sum/features.sum.accel.count.vecMag.txt';
    end
        
    if nargin<2
        % settingsFilename = '~/Documents/padaco/.pasettings';
        settingsFilename = './.pasettings'; % can also be in the current path
        %settingsFilename = fullfile('~/Documents/padaco','choi_and_imported_file_count_exclusions.mat');
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
    
    if nargin<4
        showGUI = false;
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
    
    delayedStart = true;
    cSettings = statTool.getClusterSettings(settings);
    tmpClusterObj = PACluster(statTool.featureStruct.features,cSettings,[],[],statTool.featureStruct.studyIDs, statTool.featureStruct.startDaysOfWeek, delayedStart);
                
    minK = statTool.getSetting('predictionStrength_minK'); % 2 
    maxK = statTool.getSetting('predictionStrength_maxK'); % 10
    iterations = statTool.getSetting('predictionStrength_iterations'); % 20
    showProgress = true; % ~isdeployed;
    extraLabel = '';
    if nargin==3
        extraLabel = ' with overriding settings';
    end
    fprintf(1, 'Calculating prediction strength from %s%s.\n', signalFilename, extraLabel);
    showProgress = showGUI; %true; %showGUI;
    % preclusterReductionSelection: 7
    % processedType = baseSettings.processedTypes(settings.processedTypeSelection); % 1 for count
    % baseFeatureSelection: 2
    % signalSelection: 4
    [optimal_k, avg_prediction] = predictionStrength(tmpClusterObj.loadShapes, 'mink', minK, 'maxk', maxK, 'M', iterations, 'showprogress', showProgress,'gui',showGUI);
    predStrength = avg_prediction;
    %featureStruct = statTool.loadAlignedFeatures(signalFilename);
    % featuresPath = '/var/home/hyatt4/data/count_1_min_features';
    % statTool.setFeaturesPathnameAndUpdate(featuresPath);
    
end

