
function figH = settingsDlg(varargin)
% Pretty version
h = 640;
w = 580;

position = [0 0 w h];
figH = figure('visible','off','name','Settings','position',position,...
    'menubar','none','toolbar','none','numbertitle','off',...
    'CreateFcn',{@movegui,'centern'},varargin{:});
tabGroupH = uitabgroup('parent',figH,'units','normalized',...
    'position',[0.0125 0.15 0.975 0.825],'tag','tabgroup');
% tabs = {'Name 1','Tab 2','Tab 3'};
% for t = 1:numel(tabs)    
%     u = uitab(tabGroupH,'title',tabs{t},'tag',sprintf('tag_%d',t));
% end

p = uipanel('parent',figH,'units','normalized',...
    'bordertype','beveledin','borderwidth',2,...
    'position',[0.025 0.025 0.95 0.12]);
btnProps.style = 'pushbutton';
btnProps.fontSize = 12;
%btnProps.callback = @btnPressCb;
btnProps.units = 'normalized';
btnProps.string = 'Cancel';
btnProps.position = [0.1 0.25 0.2 0.5];
posOffset = [0.3 0 0 0];
btnProps.parent = p;
btnProps.tag = 'push_cancel';
uicontrol(btnProps);

btnProps.tag = 'push_defaults';
btnProps.position = btnProps.position + posOffset;
btnProps.string = 'Set Defaults';
% btnProps.style = 'togglebutton';
uicontrol(btnProps);

btnProps.position = btnProps.position + posOffset;
btnProps.string = 'Confirm';
btnProps.tag = 'push_apply';
uicontrol(btnProps);

movegui(figH, 'center');

% set(figH,'visible','on');
% figH = figure('name','Settings');
% tbG=uitabgroup(figH,'units','normalized','position',[0.0125 0.15 0.975 0.825]);
% tbG=matlab.ui.container.TabGroup('parent',figH,'units','normalized','position',[0.0125 0.15 0.975 0.825]);
% tabs = {'Name 1','Tab 2','Tab 3'};
% for t = 1:numel(tabs)    
%     u = uitab(tbG,'title',tabs{t});
% end
% p = matlab.ui.container.Panel('parent',figH);
% uibutton(figH,'push','text','Cancel');
% tbG.set('Units','normalized')

% tabGroupH = uitabgroup('visible','off');

%set(tabGroupH,'units','normalized','position',[0.0125 0.15 0.975 0.825]);

%b = matlab.ui.control.Button('parent',figH,'text','Confirm')

%uibutton(figH,'push','text','Cancel');
%uibutton(figH,'push','text','Set Defaults');

% set(figH,'visible','on');

% Ugly version(s) ... that support ui buttons...
%figH = uifigure('visible','off','name','Settings');

% figH = uifigure('name','Settings');
% tabGroupH = uitabgroup(figH)
% tabGroupH.set('Units','normalized')
% 
% tabGroupH = uitabgroup(figH);
% 
% uibutton(u,'push','text','Confirm');
end

