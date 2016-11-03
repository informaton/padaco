function helpViewer(url,name)
    if(nargin<2 || isempty(name))
        name = 'Padaco help';
    end
    com.mathworks.mlservices.MLHelpServices.cshDisplayFile(url);
    com.mathworks.mlservices.MLHelpServices.cshSetSize(900,600);
    com.mathworks.mlservices.MLHelpServices.cshSetLocation(300,50);
    %     com.mathworks.mlservices.MLHelpServices.cshDisplayTopic('string one','string two');
    %     browser = com.mathworks.mde.help.HelpBrowser.getInstance();
    %     browser.setName(name);
    % viewer = com.mathworks.mlservices.MLCSHelpViewer)
    % browser = com.mathworks.mlservices.MLHelpBrowser)
    
    1;
end