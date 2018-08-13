function parameter = getMenuParameter(menu_h, parameterStr)
    parameters = get(menu_h,parameterStr);
    selectionIndex = get(menu_h,'value');
    if(isempty(selectionIndex))
        parameter = [];
    else
        if(isnumeric(parameters))
            parameter = parameters(selectionIndex);
        else
            if(~iscell(parameters))
                % adjust for corner cases
                if(ischar(parameters))
                    parameters = string(parameters);
                else
                    parameters = {parameters};
                end
            end
            parameter = parameters{selectionIndex};
        end
    end
end