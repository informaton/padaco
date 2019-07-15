%==================================================================
%> @brief Recursively initializes the graphic handles found in the
%> provided structure with the properties found at corresponding locations
%> in the propStruct argument.
%> @param handleStruct The struct of line handles to set the
%> properties of.
%> @param propertyStruct Structure of property structs (i.e. property/value pairings) to set the graphic
%> handles found in handleStruct to.
%==================================================================
function setStructWithStruct(handleStruct,propertyStruct)
fnames = fieldnames(handleStruct);
for f=1:numel(fnames)
    fname = fnames{f};
    curHandleField = handleStruct.(fname);
    curPropertyField = propertyStruct.(fname);
    if(isstruct(curHandleField))
        setStructWithStruct(curHandleField,curPropertyField);
    else
        if(ishandle(curHandleField))
            try
                set(curHandleField,curPropertyField);
            catch me
                showME(me);
            end
        end
    end
end
end