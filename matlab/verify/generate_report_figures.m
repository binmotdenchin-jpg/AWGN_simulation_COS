%% generate_report_figures.m — Save tat ca figures thanh PNG
%
% Chay SAU khi da chay demo_for_teacher.m (cac figure van dang mo).
% Hoac chay doc lap: se goi demo_for_teacher truoc roi save.
%
% Output: thu muc outputs/ voi cac file PNG chat luong cao (300 DPI).
%
% Author: [Ten ban]
% Date:   2026-05-21

%% Kiem tra co figure mo san khong
figs = findall(0, 'Type', 'figure');
if isempty(figs)
    fprintf('Khong co figure nao dang mo. Chay demo_for_teacher truoc...\n\n');
    demo_for_teacher;
    figs = findall(0, 'Type', 'figure');
end

%% Tao thu muc output
out_dir = fullfile('..', 'docs', 'figures');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

%% Save tung figure
fprintf('\n━━━ Saving figures to %s/ ━━━\n', out_dir);

for i = 1:length(figs)
    fig = figs(i);
    name = get(fig, 'Name');
    if isempty(name)
        name = sprintf('figure_%d', i);
    end
    
    % Tao filename an toan
    fname = lower(regexprep(name, '[^a-zA-Z0-9]', '_'));
    fname = regexprep(fname, '_+', '_');         % remove double underscores
    fname = regexprep(fname, '^_|_$', '');       % remove leading/trailing _
    
    filepath = fullfile(out_dir, [fname '.png']);
    
    % Save 300 DPI
    exportgraphics(fig, filepath, 'Resolution', 300);
    fprintf('  ✓ %s\n', filepath);
end

fprintf('\n✓ Da save %d figures vao %s/\n', length(figs), out_dir);
fprintf('  Dung cac file nay cho bao cao PDF va slides.\n\n');
