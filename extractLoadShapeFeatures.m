%> @brief Determines load shape features.  
%> @param loadShapes MxN matrix of M load shapes of N elements.
%> @param featureName String name of the feature to extract.  Can be
%> - FFT magnitude
%> - Peak values
%> - Peak duration (hours above some threshold)
%> - width of Peaks
%> - Wavelets
%> - Others
%> @retval loadShapeFeatures
function loadShapeFeatures = extractLoadShapeFeatures(loadShapes,featureName,parameter)

switch(lower(featureName))
    case 'sumsqr'
        loadShapeFeatures = extractSumSqr(loadShapes);
    case 'fft'
        loadShapeFeatures = extractSumSqr(loadShapes);
    case 'peakcount'
        loadShapeFeatures = extractPeakCount(loadShapes);
    case 'peakduration'
        loadShapeFeatures = extractPeakCount(loadShapes)*15/60;
    case 'greaterthancount'
        loadShapeFeatures = extractGreaterThanCount(loadShapes,parameter);
    case 'wavelet'
        loadShapeFeatures = extractWavelet(loadShapes);
    case 'sum'
        loadShapeFeatures = extractSum(loadShapes);
    case 'std'
        loadShapeFeatures = extractStd(loadShapes);
    otherwise
        fprintf('The feature provided (%s) was not recognized.\n',featureName);
end
end

function feature = extractGreaterThanCount(loadShapes,threshold)
    feature = sum(loadShapes>=threshold,2);
end

function feature = extractSum(loadShapes)
    feature = sum(loadShapes,2);    
end

function feature = extractSumSqr(loadShapes)
    feature = sum(loadShapes.^2,2);    
end

function feature = extractPeakCount(loadShapes)
    p = 50;
    y = prctile(loadShapes,p,2);
    feature = sum(loadShapes>=repmat(y,1,size(loadShapes,2)),2);
   % y = 10;
   % feature = sum(loadShapes>=y,2);
end
    
    
