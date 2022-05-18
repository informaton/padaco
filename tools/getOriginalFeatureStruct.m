function [originalFeatureStruct, statTool] = getOriginalFeatureStruct(signalFilename, settingsFilename, varargin)
    [statTool, ~] = getStatTool(signalFilename, settingsFilename, varargin{:});

    originalFeatureStruct = statTool.loadAlignedFeatures(signalFilename);    
    if(isfield(originalFeatureStruct,'studyIDs'))
        [originalFeatureStruct.uniqueIDs,iaFirst] = unique(originalFeatureStruct.studyIDs,'first');
        [~,iaLast,~] = unique(originalFeatureStruct.studyIDs,'last');
        originalFeatureStruct.indFirstLast = [iaFirst, iaLast];  % can be more than one week
        originalFeatureStruct.numDays = iaLast - iaFirst+1;  % can be more than one week
        
        originalFeatureStruct.indFirstLast1Week = [iaFirst, min(iaLast, iaFirst+statTool.MAX_DAYS_PER_STUDY-1)];  % cannot be more than one week, but can be less ...
        
        ind2keepExactly1Week = false(size(originalFeatureStruct.shapes,1),1);
        ind2keep = false(size(originalFeatureStruct.shapes,1),1);
        oneWeekDayInd = originalFeatureStruct.indFirstLast1Week;
        for d=1:size(oneWeekDayInd,1)
            ind2keep(oneWeekDayInd(d,1):oneWeekDayInd(d,2))= true;  % could be less than a week, but not more
            if(originalFeatureStruct.numDays(d)>=7)
                % exactly 1 week
                ind2keepExactly1Week(oneWeekDayInd(d,1):oneWeekDayInd(d,2)) = true;
            end
        end
        originalFeatureStruct.ind2keep1Week = ind2keep;  % logical index for subject days that are part of 1 week or less.
        originalFeatureStruct.ind2keepExactly1Week = ind2keepExactly1Week; % logical index for subject days that are part of 1 week exactly (each day is covered).
    end
end