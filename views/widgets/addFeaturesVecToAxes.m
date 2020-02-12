% --------------------------------------------------------------------
%> @brief Plots a feature vector on the specified axes.
%> @param featureVector A vector of features to be displayed.
%> @param startStopDatenum A vector of start and stop date nums that
%> correspond to the start and stop times of the study that the
%> feature in featureVector at the same index corresponds to.
%> @param overlayHeight - The proportion (fraction) of vertical space that the
%> overlay will take up in the secondary axes.
%> @param overlayOffset The normalized y offset ([0, 1]) that is applied to
%> the featureVector when displayed on the secondary axes.
%> @param axesH The graphic handle to the axes.
%> @param useSmoothing Boolean flag to set if feature vector should
%> be applied (true) or not (false) before display.
%> @retval featureHandles Line handles created from the method.
% --------------------------------------------------------------------
function featureHandles = addFeaturesVecToAxes(axesH, featureVector, startStopDatenum, overlayHeight, overlayOffset, useSmoothing)
if(overlayOffset>0)
    featureHandles = nan(3,1);
else
    featureHandles = nan(2,1);
end


n = 10;
b = repmat(1/n,1,n);


if(useSmoothing)
    % Sometimes 'single' data is loaded, particularly with raw
    % accelerations.  We need to convert to double in such
    % cases for filtfilt to work.
    if(~isa(featureVector,'double'))
        featureVector = double(featureVector);
    end
    smoothY = filtfilt(b,1,featureVector);
else
    smoothY = featureVector;
end
smoothY = smoothY-min(smoothY);
normalizedY = smoothY/max(smoothY)*overlayHeight+overlayOffset;%drop it right down in place, center vertically

featureHandles(1) = line('parent',axesH,'ydata',normalizedY,'xdata',startStopDatenum(:,1),'color','b','hittest','off','userdata',featureVector);
%draw some boundaries around our features - put in rails
railsBottom = [overlayOffset,overlayOffset]+0.001;
railsTop = railsBottom+overlayHeight - 0.001;
x = [startStopDatenum(1), startStopDatenum(end)];
featureHandles(2) = line('parent',axesH,'ydata',railsBottom,'xdata',x,'color',[0.2 0.2 0.2],'linewidth',0.2,'hittest','off');
if(overlayOffset>0)
    featureHandles(3) = line('parent',axesH,'ydata',railsTop,'xdata',x,'color',[0.2 0.2 0.2],'linewidth',0.2,'hittest','off');
end
end