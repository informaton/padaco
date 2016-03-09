%> @brief Extends or shrinks a table's position according to the width given 
%> by its extent property.
function fitTableWidth(uitableH)
    if(nargin>0 && ishandle(uitableH) && strcmpi(get(uitableH,'type'),'uitable'))
       pos = get(uitableH,'position');
       ext = get(uitableH,'extent');
       pos(3) = ext(3);

       % We will have a vertical slider in this case on the right hand side of our table 
       % that is not being accounted for.
       if(ext(4)>pos(4))  
           widthOfVerticalSlider = 15;
           pos(3) = pos(3)+ widthOfVerticalSlider;
       end
       
       set(uitableH,'position',pos);
       
    end
end