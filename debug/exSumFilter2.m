% plot a semi-nice looking summing filter
close all;
short = ones(300,1);
long = ones(900,1);
xVec=1:numel(vec);
xshort = 1:numel(short);
xlong = 1:numel(long);

figure;
int = 1:5:numel(xshort);stem(xshort(int),short(int));xlim([-50,350]);ylim([-0.5,1.5])
title('h_{short}')
xlabel('n')
ylabel('h_{short}[n]')
set(gcf,'color',[1 1 1],'inverthardcopy','off')

figure;
subplot(2,1,1);
int = 1:5:numel(xshort);stem(xshort(int),short(int));xlim([-50,numel(xlong)+50]);ylim([-0.5,1.5])
title('h_{short}')
xlabel('n')
ylabel('h_{short}[n]')

subplot(2,1,2);
int = 1:5:numel(xlong);stem(xlong(int),long(int));xlim([-50,numel(xlong)+50]);ylim([-0.5,1.5])
title('h_{long}')
xlabel('n')
ylabel('h_{long}[n]')


set(gcf,'color',[1 1 1],'inverthardcopy','off')

xlimit = [1, numel(vec)];

xticks = linspace(1,numel(vec),25);
d=num2str((0:24)');
figure;
subplot(3,1,1)
plot(vec);
set(gca,'xtick',xticks,'xticklabel',d)

xlim(xlimit);
ylabel('x[n]','fontsize',12);
xlabel('n');
title('Vector magnitude counts','fontsize',14);

subplot(3,1,2);
plot(filter(short,1,vec));
xlim(xlimit);
ylabel('x[n]\otimesh[n]_{short}','fontsize',12);
xlabel('n');
title('Results with short summing filter','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)

subplot(3,1,3);
plot(filter(long,1,vec));
xlim(xlimit);
ylabel('x[n]\otimesh[n]_{long}','fontsize',12);
title('Results with long summing filter','fontsize',14);
set(gca,'xtick',xticks,'xticklabel',d)
xlabel('n');

set(gcf,'color',[1 1 1],'inverthardcopy','off')

