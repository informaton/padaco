%> @brief Small wrapper to retrieve current string displayed/selected in a
%> matlab dropdown menu control.
%> @Copyright Informaton, Hyatt Moore 6/27/2015
function selectedString = getSelectedMenuString(menuHandle)
    if(ishandle(menuHandle))
        selections = get(menuHandle,'string');
        if(iscell(selections))
            selectedString = selections{get(menuHandle,'value')};
        else
            selectedString = selections;
        end
    else
        selectedString = '';
    end
end