%> @brief Small wrapper to retrieve current string displayed/selected in a
%> matlab dropdown menu control.
%> @Copyright Informaton, Hyatt Moore 6/27/2015
function [selectedString, selectedIndex] = getSelectedMenuString(menuHandle)
    if(ishandle(menuHandle))
        selections = get(menuHandle,'string');
        selectedIndex = get(menuHandle,'value');
        if(iscell(selections))
            selectedString = selections{selectedIndex};
        else
            selectedString = selections;
        end
    else
        selectedString = '';
        selectedIndex = [];
    end
end