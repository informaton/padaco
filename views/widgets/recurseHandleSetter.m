%==================================================================
%> @brief Recursively sets struct of graphic handles with a matching struct
%> of handle properties.
%> @param handleStruct The struct of matlab graphic handles.  This
%> is searched recursively until a handle is found (i.e. ishandle())
%> @param propertyStruct Structure of property/value pairings to set the graphic
%> handles found in handleStruct to.
%==================================================================
function recurseHandleSetter(handleStruct, propertyStruct)
fnames = fieldnames(handleStruct);
% Add some checking to make sure we match properties correctly.
% Experience showed that 'raw' accelTypes do not contain all
% fields that exist for display which leads to exception throws.
matchingFields = isfield(propertyStruct,fnames);
fnames = fnames(matchingFields);
for f=1:numel(fnames)
    fname = fnames{f};
    curField = handleStruct.(fname);
    curPropertyStruct = propertyStruct.(fname);
    try
        if(isstruct(curField))
            recurseHandleSetter(curField,curPropertyStruct);
        else
            if(ishandle(curField))
                set(curField,curPropertyStruct);
            end
        end
    catch me
        showME(me);
    end
end
end
