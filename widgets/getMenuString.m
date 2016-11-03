%> @brief Returns the string contents of the current selection of the
%> passed menu handle.
function string = getMenuString(menuH)
    string = getMenuParameter(menuH,'string');
end