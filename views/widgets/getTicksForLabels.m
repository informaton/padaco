%> @brief Returns evenly spaced tick marks for an input cell of
%> labels.  This is a utility method for placing nicely spaced labels
%> along an x or y axes.
%> @param cellOfLabels For example {'X','Y','Z','VecMag'}
%> @retval ticks Vector of evenly spaced values between 1/(number
%> of labels)/2 and 1
function ticks = getTicksForLabels(cellOfLabels)
if(~iscell(cellOfLabels))
    numTicks = 1;
else
    numTicks = numel(cellOfLabels);
end
ticks = 1/numTicks/2:1/numTicks:1;
end
