%> @brief Extends or shrinks a table's position according to the width given 
%> by its extent property.
function fitTableHeight(uitableH)
    if(nargin>0 && ishandle(uitableH) && strcmpi(get(uitableH,'type'),'uitable'))
       pos = get(uitableH,'position');
       ext = get(uitableH,'extent');
       pos(4) = ext(4);
       set(uitableH,'position',pos);
    end
end