%> @brief Returns the user data corresponding to the current selection.
%> This require the user data to be a cell whose elements correspond to 
%> menu option indices.
function string = getMenuUserData(menuH)
    string = getMenuParameter(menuH,'userdata');
end