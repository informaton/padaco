%> @brief Utility method to set the property value for one or more handles and their descendents
%> as applicable.  If a handle does not have the property, nothing is done
%> for it, but its descendants are still examined for the property and set
%> where applicable.
function sethandles(handles, property, value)
    if(all(ishandle(handles)))
        for n=1:numel(handles)
            set(findobj(handles(n),'-property',property),property,value);
        end
    end
end