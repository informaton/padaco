%% selectedIndex = setMenuSelection(menuHandle, selectionStr)
% selectedIndex is the numerical index of the selection when found and
% empty ([]) when the selection is not found.
%> @brief Small wrapper to set the string displayed/selected in a
%> matlab dropdown menu control.

%> @Copyright Informaton, Hyatt Moore 8/13/2018
function selectedIndex = setMenuSelection(menuHandle, selectionStr)
    selectedIndex = [];
    
    if(ishandle(menuHandle))
        selections = get(menuHandle,'string');
        selectedIndex = find(strcmpi(selections,selectionStr),1);
        if(~isempty(selectedIndex))
            set(menuHandle,'value',selectedIndex);
        end
    end
    
end