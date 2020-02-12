% --------------------------------------------------------------------
%> @brief Sets the color of the <line> handles.  Any handle with 'color'
%> %property.
%> @param lineHandleStruct Struct of line handles to set the color of.
%> @param colorStruct Struct with field organization corresponding to that of
%> input line handles.  The values are the colors to set
%> the matching line handle to.
% --------------------------------------------------------------------
function setHandleColor(lineHandleStruct,colorStruct)
setStructWithStruct(lineHandleStruct,colorStruct);
end