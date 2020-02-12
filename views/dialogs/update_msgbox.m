function update_msgbox(msgboxH, newMsg)
    textH = findobj(msgboxH,'type','text');
    set(textH,'string',newMsg);
end