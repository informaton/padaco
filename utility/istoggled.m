% Wrapper to get state of uitogglebutton or uitool
function isIt = istoggled(uitoggleH)
    isIt = strcmpi(get(uitoggleH,'state'),'on');
end