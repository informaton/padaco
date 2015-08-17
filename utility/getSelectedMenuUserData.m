%> @brief Small wrapper to retrieve current user data property from the
%current, selected item of a matlab dropdown menu control handle.
function selectedData = getSelectedMenuUserData(menuHandle)
    if(ishandle(menuHandle))
        selections = get(menuHandle,'userdata');
        if(iscell(selections))
            selectedData = selections{get(menuHandle,'value')};
        else
            selectedData = selections;
        end
    else
        selectedData = [];
    end
end