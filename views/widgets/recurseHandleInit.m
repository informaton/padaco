%==================================================================
%> @brief Recursively initializes the graphic handles found in the
%> provided structure with the handle properties provided.
%> @param handleStruct The struct of line handles to set the
%> properties of.
%> @param properties Structure of property/value pairings to set the graphic
%> handles found in handleStruct to.
%==================================================================
function recurseHandleInit(handleStruct,properties)
fnames = fieldnames(handleStruct);
for f=1:numel(fnames)
    fname = fnames{f};
    curField = handleStruct.(fname);
    if(isstruct(curField))
        recurseHandleInit(curField,properties);
    else
        if(ishandle(curField))
            set(curField,properties);
        end
    end
end
end