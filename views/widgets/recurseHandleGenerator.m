%==================================================================
%> @brief Recursively fills in the template structure dummyStruct
%> with matlab lines and returns as a new struct.  If dummyStruct
%> has numeric values in its deepest nodes, then these values are
%> assigned as the y-values of the corresponding line handle, and the
%> x-value is a vector from 1 to the number of elements in y.
%> @param dummyStruct Structure with arbitrarily deep number fields.
%> @param handleType String name of the type of handle to be created:
%> - @c line
%> - @c text
%> @param handleProperties Struct of line handle properties to initialize line handles with.
%> @param destStruct Optional struct; see note.
%> @retval destStruct The filled in struct, with the same field
%> layout as dummyStruct but with line handles filled in at the
%> deepest nodes.
%> @note If destStruct is included, then lineproperties must also be included, even if only as an empty place holder.
%> For example as <br>
%> destStruct = recurseHandleGenerator(dummyStruct,handleType,[],destStruct)
%> @param destStruct The initial struct to grow to (optional and can be different than the output node).
%> For example<br> desStruct = recurseLineGenerator(dummyStruct,'line',proplines,diffStruct)
%> <br>Or<br> recurseHandleGenerator(dummyStruct,'line',[],diffStruct)
%==================================================================
function destStruct = recurseHandleGenerator(dummyStruct,handleType,handleProperties,destStruct)
if(nargin < 4 || isempty(destStruct))
    destStruct = struct();
    if(nargin<3)
        handleProperties = [];
    end
    
end

fnames = fieldnames(dummyStruct);
for f=1:numel(fnames)
    fname = fnames{f};
    
    curHandleProperties = handleProperties;
    if(isfield(handleProperties,'tag'))
        curHandleProperties.tag = [handleProperties.tag,'.',fname];
    end
    
    
    if(isstruct(dummyStruct.(fname)))
        destStruct.(fname) = [];
        
        %recurse down
        destStruct.(fname) = recurseHandleGenerator(dummyStruct.(fname),handleType,curHandleProperties,destStruct.(fname));
    else
        
        if(strcmpi(handleType,'line') || strcmpi(handleType,'text'))
            if(nargin>1 && ~isempty(curHandleProperties)) %aka  if(hasProperties)
                destStruct.(fname) = feval(handleType,curHandleProperties);
            else
                destStruct.(fname) = feval(handleType);
            end
        else
            destStruct.(fname) = [];
            fprintf('Warning!  Handle type %s unknown!',handleType);
        end
        
    end
end
end