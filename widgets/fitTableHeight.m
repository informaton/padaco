%> @brief Extends or shrinks a table's position according to the width given 
%> by its extent property.
function fitTableHeight(uitableH)
    if(nargin>0 && ishandle(uitableH) && strcmpi(get(uitableH,'type'),'uitable'))
        units0 = get(uitableH,'units');
        set(uitableH,'units','pixels');  % I ran into some rounding/precision issues
        pos = get(uitableH,'position');
        ext = get(uitableH,'extent');
        pos(4) = ext(4)+1;
        set(uitableH,'position',pos);
        set(uitableH,'units',units0);
    end
end