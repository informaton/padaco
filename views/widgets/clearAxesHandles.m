% --------------------------------------------------------------------
%> @brief Clears axes handles of any children and sets default properties.
%> @param axesHorStruct either a struct with fields that are axes handles,
%> or an array of axes handles.
% --------------------------------------------------------------------
function clearAxesHandles(axesHorStruct)
if(isstruct(axesHorStruct))
    axesH = struct2array(axesHorStruct);  %place in utility folder
else
    axesH = axesHorStruct;
end
for a=1:numel(axesH)
    
    h=axesH(a);
    if(ishandle(h))
        cla(h);
        title(h,'');
        ylabel(h,'');
        xlabel(h,'');
        set(h,'xtick',[],'ytick',[]);
    end
end
end