function featureStruct = getFeatureStruct(varargin)
    statTool = getStatTool(varargin{:});
    % featuresStruct = statTool.loadAlignedFeatures(signalFilename);
    
    didCalc = statTool.calcFeaturesFromFile(signalFilename);
    if ~didCalc
        error('Unable to calculate features');
    else
        featureStruct = statTool.featureStruct;
    end
    
    
end

