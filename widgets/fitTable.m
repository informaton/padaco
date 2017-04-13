% often a uitable's position does not match up correctly with its extent.
function fitTable(uitableH)
    if(nargin>0 && ishandle(uitableH) && strcmpi(get(uitableH,'type'),'uitable'))
       pos = get(uitableH,'position');
       ext = get(uitableH,'extent');
       pos(3:4) = ext(3:4);
       set(uitableH,'position',pos);
    end
end