function resampleChoiFeatureFile(originalChoiNonwearFilename, desiredEpochLengthMinutes, resampledChoiExportFilename)
    if false
        originalChoiNonwearFilename = '~/data/count_1_min_features/features/nonwear_choi/features.nonwear_choi.accel.count.vecMag.txt';
        resampledChoiExportFilename = '~/data/count_10_min_features/features/nonwear_choi/features.nonwear_choi.accel.count.vecMag.txt';
        desiredEpochLengthMinutes = 10;
        resampleChoiFeatureFile(originalChoiNonwearFilename, desiredEpochLengthMinutes, resampledChoiExportFilename);
    end

    narginchk(3, 3);
    if ~exist(originalChoiNonwearFilename, 'file')
        error('Input Choin nonwear file dos not exist (%s)', originalChoiNonwearFilename);
    end
    [originalEpochLength, featureName] = getEpochLengthInMinutes(originalChoiNonwearFilename);
    if originalEpochLength >= desiredEpochLengthMinutes
        error('Desired epoch length (%d) must be greater than the original epoch length (%d).', desiredEpochLengthMinutes, originalEpochLength) ;
    elseif originalEpochLength==1
        originalStruct = PAStatTool.loadAlignedFeatures(originalChoiNonwearFilename);
        shapes = originalStruct.shapes;
        num_rows = size(shapes,1);
        resampledLength = 24*60/originalEpochLength/desiredEpochLengthMinutes;
        new_shapes = reshape(shapes, [num_rows, desiredEpochLengthMinutes, resampledLength]);
        resampledShapes = reshape(max(new_shapes,[],2),[num_rows, resampledLength]);
        
        resampledStartTimes = originalStruct.startTimes(1:desiredEpochLengthMinutes:end);

        % See PABatchTool.startBatchProcessCallback for deriving start
        % times from elapsed start hour, frame duration, and start and stop
        % date vectors:
        %         startDateVec = [0 0 0 elapsedStartHour 0 0];
        %         stopDateVec = startDateVec + [0 0 0 intervalDurationHours -frameDurationMinutes 0]; %-frameDurMin to prevent looping into the start of the next interval.
        %         frameInterval = [0 0 0 0 frameDurationMinutes 0];
        %         timeAxis = datenum(startDateVec):datenum(frameInterval):datenum(stopDateVec);
        %         timeAxisStr = datestr(timeAxis,'HH:MM:SS');
        if resampledLength ~= numel(resampledStartTimes)
            error('Resampled length (%d) does not equal number of columns (%d)', resampledLength, numel(resampledStartTimes));
        end
        
        featureFilename = resampledChoiExportFilename;
        fid = fopen(featureFilename,'w');
        fprintf(fid,'# Feature:\t%s\n',featureName);            
        fprintf(fid,'# Length:\t%u\n',resampledLength);
        
        fprintf(fid,'# Study_ID\tStart_Datenum\tStart_Day');
        for t=1:resampledLength
            fprintf(fid,'\t%s',resampledStartTimes{t});
        end
        fprintf(fid,'\n');
        fclose(fid);        
        result = int64([originalStruct.studyIDs,originalStruct.startDatenums,originalStruct.startDaysOfWeek,resampledShapes]);
        save(featureFilename, 'result', '-ascii','-tabs','-append');
        fprintf('Resampled results saved to %s\n', featureFilename);
    else
        error('This case is not handled')
    end
end

function [epochLength, featureName] = getEpochLengthInMinutes(featureFilename)
    epochLength = nan;
    if exist(featureFilename,'file')
        fid = fopen(featureFilename, 'r');
        featureLine = fgetl(fid);  % # Feature:	nonwear_choi        
        lengthLine = fgetl(fid);   % # Length:	1440
        fclose(fid);
        featureName = sscanf(featureLine, '# Feature: %s');
        featureLength = sscanf(lengthLine,'# Length: %d');
        epochLength = 24*60/featureLength;
    else
        warning('Feature file ("%s") not found.  Cannot determine epoch length.', featureFilename);
    end

end