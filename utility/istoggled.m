% Wrapper to get state of uitogglebutton, toggletool or uitool,
% 'matlab.ui.container.toolbar.ToggleTool',  or check boxes for that
% matter.  Anything with a 'state' or 'value' property.  'on' is true
function isIt = istoggled(uitoggleH)
    if(isfield(uitoggleH,'state') || isprop(uitoggleH,'state'))
        isIt = strcmpi(get(uitoggleH,'state'),'on');
    else
        isIt = get(uitoggleH,'value');
    end
end