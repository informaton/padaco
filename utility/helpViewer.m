function helpViewer(url,name)
    if(nargin<2 || isempty(name))
        name = '';
    end
    com.mathworks.mlservices.MLHelpServices.cshDisplayFile(url);
    %     com.mathworks.mlservices.MLHelpServices.cshDisplayFile(url,name);
    com.mathworks.mlservices.MLHelpServices.cshSetSize(900,600);
    com.mathworks.mlservices.MLHelpServices.cshSetLocation(300,50);
end