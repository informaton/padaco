% --------------------------------------------------------------------
%> @brief Adds a magnitude vector as a heatmap to the specified axes.
%> @param overlayVector A magnitude vector to be displayed in the
%> axes as a heat map.
%> @param startStopDatenum An Nx2 matrix start and stop datenums which
%> correspond to the start and stop times of the same row in overlayVector.
%> @param overlayHeight - The proportion (fraction) of vertical space that the
%> overlay will take up in the secondary axes.
%> @param overlayOffset The normalized y offset that is applied to
%> the overlayVector when displayed on the secondary axes.
%> @param maxValue The maximum value to normalize the overlayVector
%> with so that the normalized overlayVector's maximum value is 1.
%> @param axesH The graphic handle to the axes.
%> @param contextmenuH Optional contextmenu handle.  Is assigned to the overlayLineH lines
%> contextmenu callback when included.
% --------------------------------------------------------------------
function [overlayLineH, overlayPatchH] = addOverlayToAxes(axesH, overlayVector, startStopDatenum, overlayHeight, overlayOffset,maxValue,contextmenuH)
if(nargin<7)
    contextmenuH = [];
end

yLim = get(axesH,'ylim');
yLim = yLim*overlayHeight+overlayOffset;
minColor = [0.0 0.0 0.0];

nFaces = numel(overlayVector);
x = nan(4,nFaces);
y = repmat(yLim([1 2 2 1])',1,nFaces);
vertexColor = nan(4,nFaces,3);

% only work with a row vector so we can add correctly next
overlayVector = overlayVector(:);
% each column represent a face color triplet
overlayColorMap = (overlayVector/maxValue)*[1,1,0.65]+ repmat(minColor,nFaces,1);

% patches are drawn clock wise in matlab

for f=1:nFaces
    if(f==nFaces)
        vertexColor(:,f,:) = overlayColorMap([f,f,f,f],:);
        
    else
        vertexColor(:,f,:) = overlayColorMap([f,f,f+1,f+1],:);
        
    end
    x(:,f) = startStopDatenum(f,[1 1 2 2])';
    
end
overlayPatchH = patch(x,y,vertexColor,'parent',axesH,'edgecolor','interp','facecolor','interp');
normalizedOverlayVector = overlayVector/maxValue*(overlayHeight)+overlayOffset;

overlayLineH = [];
if(~isempty(contextmenuH))
    overlayLineH = line('parent',axesH,'linestyle',':','xdata',linspace(startStopDatenum(1),startStopDatenum(end),numel(overlayVector)),'ydata',normalizedOverlayVector,'color',[1 1 0]);
    set(overlayLineH,'uicontextmenu',contextmenuH);
    % set(contextmenuH,'userdata',overlayVector);
end

end