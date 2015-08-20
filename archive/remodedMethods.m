% Removed from PAData.m on 8/19/2015

% --------------------------------------------------------------------
%> @brief Calculates usage states from @b classifyUsageState method
%> and returns it as a matrix of elapsed time aligned vectors.
%> @param obj Instance of PAData
%> @param elapsedStartHour Elapsed hour (starting from 00:00 for new
%> day) to begin aligning feature vectors.
%> @param intervalDurationHours number of hours between
%> consecutively aligned feature vectors.
%> @note For example if elapsedStartHour is 1 and intervalDurationHours is 24, then alignedFeatureVecs will
%> start at 01:00 of each day (and last for 24 hours a piece).
%> @retval alignedUsageStates NxM matrix where each row is the mode usage state
%> occuring in the alignment region according to elapsed start time and
%> interval duration in hours.  Consecutive rows are vector values in order of the section they are calculated from (i.e. the columns).
%> @retval alignedStartDateVecs Nx6 matrix of datevec values whose
%> rows correspond to the start datevec of the corresponding row of alignedFeatureVecs.
% --------------------------------------------------------------------
% function [alignedUsageStates, alignedStartDateVecs] = getAlignedUsageStates(obj,elapsedStartHour, intervalDurationHours)
%     [usageVec, ~,~] = classifyUsageState(obj);
%     currentNumFrames = obj.getFrameCount();
%     if(currentNumFrames~=obj.numFrames)
%         
%         [frameDurMinutes, frameDurHours ] = obj.getFrameDuration();
%         frameDurSeconds = frameDurMinutes*60+frameDurHours*60*60;
%         obj.numFrames = currentNumFrames;
%         frameableSamples = obj.numFrames*frameDurSeconds*obj.getSampleRate();
%         obj.frames =  reshape(usageVec(1:frameableSamples),[],obj.numFrames);  %each frame consists of a column of data.  Consecutive columns represent consecutive frames.
%         
%         obj.features = [];
%         dateNumIndices = 1:size(obj.frames,1):frameableSamples;
%         
%         %take the first part
%         obj.startDatenums = obj.dateTimeNum(dateNumIndices(1:end));
%     end
%     
%     
%     % get frame duration
%     frameDurationVec = [0 0 0 obj.frameDurHour obj.frameDurMin 0];
%     
%     % find the first Start Time
%     startDateVecs = datevec(obj.startDatenums);
%     elapsedStartHours = startDateVecs*[0; 0; 0; 1; 1/60; 1/3600];
%     startIndex = find(elapsedStartHours==elapsedStartHour,1,'first');
%     
%     startDateVec = startDateVecs(startIndex,:);
%     stopDateVecs = startDateVecs+repmat(frameDurationVec,size(startDateVecs,1),1);
%     lastStopDateVec = stopDateVecs(end,:);
%     
%     % A convoluted processes - need to convert datevecs back to
%     % datenum to handle switching across months.
%     remainingDurationHours = datevec(datenum(lastStopDateVec)-datenum(startDateVec))*[0; 0; 24; 1; 1/60; 1/3600];
%     
%     numIntervals = floor(remainingDurationHours/intervalDurationHours);
%     
%     intervalStartDateVecs = repmat(startDateVec,numIntervals,1)+(0:numIntervals-1)'*[0, 0, 0, intervalDurationHours, 0, 0];
%     alignedStartDateVecs = intervalStartDateVecs;
%     durationDateVec = [0 0 0 numIntervals*intervalDurationHours 0 0];
%     stopIndex = find(datenum(stopDateVecs)==datenum(startDateVec+durationDateVec),1,'first');
%     
%     
%     
%     % reshape the result and return as alignedFeatureVec
%     
%     clippedFeatureVecs = usageVec(startIndex:stopIndex);
%     alignedUsageStates = reshape(clippedFeatureVecs,[],numIntervals)';
%     
% end


% Removed from PAView.m  

% % --------------------------------------------------------------------
% %> @brief Initialize the line handles that will be used in the view.
% %> Also turns on the vertical positioning line seen in the
% %> secondary axes.
% %> @param Instance of PAView.
% %> @param Structure of line properties corresponding to the
% %> fields of the linehandle instance variable.
% %> If empty ([]) then default PAData.getDummyDisplayStruct is used.
% % --------------------------------------------------------------------
% function initLineHandles(obj,lineProps)
% 
% if(nargin<2 || isempty(lineProps))
%     lineProps = PAData.getDummyDisplayStruct();
% end
% 
% obj.recurseHandleSetter(obj.linehandle, lineProps);
% obj.recurseHandleSetter(obj.referencelinehandle, lineProps);
% 
% 
% end
% 
% % --------------------------------------------------------------------
% %> @brief Initialize the label handles that will be used in the view.
% %> Also turns on the vertical positioning line seen in the
% %> secondary axes.
% %> @param Instance of PAView.
% %> @param Structure of label properties corresponding to the
% %> fields of the labelhandle instance variable.
% % --------------------------------------------------------------------
% function initLabelHandles(obj,labelProps)
% obj.recurseHandleSetter(obj.labelhandle, labelProps);
% end



% % --------------------------------------------------------------------
% %> @brief Restores the view to ready state (mouse becomes the default pointer).
% %> @param obj Instance of PAView
% % --------------------------------------------------------------------
% function popout_axes(~, ~, axes_h)
% % hObject    handle to context_menu_pop_out (see GCBO)
% % eventdata  reserved - to be defined in a future version of MATLAB
% % handles    structure with handles and user data (see GUIDATA)
% fig = figure;
% copyobj(axes_h,fig); %or get parent of hObject's parent
% end