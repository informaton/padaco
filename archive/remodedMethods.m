% Removed from PAView.m  

% % --------------------------------------------------------------------
% %> @brief Initialize the line handles that will be used in the view.
% %> Also turns on the vertical positioning line seen in the
% %> secondary axes.
% %> @param Instance of PAView.
% %> @param Structure of line properties corresponding to the
% %> fields of the linehandle instance variable.
% %> If empty ([]) then default PAData.getDummyDisplayStruct is used.
% % --------------------------------------------------------------------
% function initLineHandles(obj,lineProps)
% 
% if(nargin<2 || isempty(lineProps))
%     lineProps = PAData.getDummyDisplayStruct();
% end
% 
% obj.recurseHandleSetter(obj.linehandle, lineProps);
% obj.recurseHandleSetter(obj.referencelinehandle, lineProps);
% 
% 
% end
% 
% % --------------------------------------------------------------------
% %> @brief Initialize the label handles that will be used in the view.
% %> Also turns on the vertical positioning line seen in the
% %> secondary axes.
% %> @param Instance of PAView.
% %> @param Structure of label properties corresponding to the
% %> fields of the labelhandle instance variable.
% % --------------------------------------------------------------------
% function initLabelHandles(obj,labelProps)
% obj.recurseHandleSetter(obj.labelhandle, labelProps);
% end



% % --------------------------------------------------------------------
% %> @brief Restores the view to ready state (mouse becomes the default pointer).
% %> @param obj Instance of PAView
% % --------------------------------------------------------------------
% function popout_axes(~, ~, axes_h)
% % hObject    handle to context_menu_pop_out (see GCBO)
% % eventdata  reserved - to be defined in a future version of MATLAB
% % handles    structure with handles and user data (see GUIDATA)
% fig = figure;
% copyobj(axes_h,fig); %or get parent of hObject's parent
% end