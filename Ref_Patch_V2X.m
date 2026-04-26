tic
%% CLEANUP AND SETUP
clc; clear; close all;
mm = 1e-3;
scriptName = mfilename;   % Name of the currently running file

%% 1. PARAMETER GEOMETRY (According to the drawing)
% --- MAIN PATCH DIMENSIONS ---
Lx = 15.7*mm;         % Patch width (along X)
Wy = 20.1*mm;         % Patch length (along Y)
h  = 1.57*mm;         % Substrate thickness
Gnd_Size = 50*mm;     % Ground plane size

% --- FEED POINT ---
feed_point = [-3.6*mm, 0]; % Offset -6 mm from center (as in the drawing)

freqs = linspace(5.5e9, 6.5e9, 51); %---------------------------------------Change: number of frequency points!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
f_max = 5.9e9; %-------------------------------------------------------------Change!!!!!!!!

%% 2. ANTENNA OBJECT CREATION
patch_rect_solid = antenna.Rectangle('Length', Lx, 'Width', Wy);

% Final patch (after slot subtraction)
patch_with_slot = patch_rect_solid;

% Substrate and ground plane
sub      = dielectric('Name','RT5880','EpsilonR',2.2,'Thickness',h);
full_gnd = antenna.Rectangle('Length', Gnd_Size, 'Width', Gnd_Size);

%-----------------------------
%% 3. PCB STACK ASSEMBLY AND MESH GENERATION
p = pcbStack;
p.Name           = 'Ref_Antenna';
p.BoardThickness = h;
p.BoardShape     = antenna.Rectangle('Length', Gnd_Size, 'Width', Gnd_Size);
p.Layers         = {patch_with_slot, sub, full_gnd};
p.FeedLocations  = [feed_point, 1, 3];
p.FeedDiameter   = 0.5*mm; % Physical port size for accurate Z-parameters

% --- AUTOMATIC MESH PARAMETER CALCULATION ---
% f_max = max(freqs);       % Upper frequency bound from block 4
c0 = 3e8;                   % Speed of light
er = sub.EpsilonR;          % Permittivity taken from the sub object

% Wavelength in dielectric (primary accuracy criterion)
lambda_g = c0 / (f_max * sqrt(er));

%-------------------------------------------------------------------------------Important!!!
% mesh(p, 'MaxEdgeLength', a1, 'MinEdgeLength', a2);

mesh(p, 'MaxEdgeLength', lambda_g/10, ...
        'MinEdgeLength', lambda_g/30, ...
        'GrowthRate', 0.99);   % Ground plane mesh coarsens quickly

% Console output for verification
fprintf('\n--- MESH PARAMETERS (AUTO) ---\n');
fprintf('Calculation frequency: %.2f GHz\n', f_max/1e9);
% fprintf('MaxEdgeLength (a1): %.3f mm\n', a1/mm);
% fprintf('MinEdgeLength (a2): %.3f mm\n', a2/mm);
fprintf('------------------------------\n');

% --- 2D VISUALIZATION (Top view) ---
figure('Name', '2D Mesh View (Top)', 'Color', 'w');
mesh(p);
view(0, 90);    % Strictly flat top view
axis equal;     % Preserve geometry proportions
% Robust title
title(scriptName, ...
      'FontSize', 14, ...
      'FontWeight', 'bold', ...
      'Interpreter', 'none');
xlabel('x (m)');
ylabel('y (m)');
grid on;

%-------------------------------------
%% 4. S-PARAMETER CALCULATION
fprintf('Launching electromagnetic simulation (MoM)...\n');
s_obj = sparameters(p, freqs, 50);

% Extract S11
if isa(s_obj, 'sparameters')
    s11_complex = rfparam(s_obj, 1, 1);
else
    s11_complex = squeeze(s_obj.Parameters(1,1,:));
end

% VSWR
swr_val = (1 + abs(s11_complex)) ./ (1 - abs(s11_complex));

%% 5. VSWR PLOT AND PARAMETER TABLE
fig_swr = figure('Name', 'SWR & Parameters', 'Color', 'w', 'Position', [100 100 1100 500]);

% --- Left panel: VSWR plot ---
subplot(1,2,1);
plot(freqs/1e9, swr_val, 'r-', 'LineWidth', 2);
grid on; hold on;
yline(2, 'b--', 'SWR = 2');
ylim([1 10]);
xlabel('Frequency (GHz)');
ylabel('SWR');
title('SWR Analysis (Single Vertical Slot)');

% Initialize strings in case bandwidth is not found
bw_str    = 'N/A';
range_str = 'N/A';
f_center  = 5.9e9 / 1e9; %----------------------------------------------------Change!!

bw_indices = find(swr_val <= 2);
if ~isempty(bw_indices)
    f_low    = freqs(bw_indices(1))   / 1e9;
    f_high   = freqs(bw_indices(end)) / 1e9;
    BW_abs   = (f_high - f_low) * 1e3;
    f_center = (f_high + f_low) / 2;

    fill([f_low f_high f_high f_low], [1 1 2 2], [0.8 1 0.8], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.3);
    text(f_center, 1.5, sprintf('BW = %.1f MHz', BW_abs), ...
        'HorizontalAlignment', 'center', 'Color', [0 0.5 0], 'FontWeight', 'bold');

    bw_str    = sprintf('%.1f MHz', BW_abs);
    range_str = sprintf('%.3f - %.3f GHz', f_low, f_high);
end

% --- Right panel: Parameter table ---
subplot(1,2,2);
axis off;

param_text = sprintf([...
    'CURRENT PARAMETERS:\n\n'      ...
    'Lx           = %.2f mm\n'     ...
    'Wy           = %.2f mm\n'     ...
    'h            = %.2f mm\n'     ...
    'Feed X       = %.3f mm\n\n'   ...
    '--------------------------\n' ...
    'RESULTS (SWR < 2):\n'         ...
    'Bandwidth : %s\n'             ...
    'Range     : %s'],             ...
    Lx/mm, Wy/mm, h/mm, feed_point(1)/mm, ...
    bw_str, range_str);

text(0.05, 0.5, param_text, 'FontSize', 11, 'FontWeight', 'bold', 'FontName', 'Consolas');

%% 6. IMPEDANCE PLOT (R and X)
% FIXED: correct Z extraction from sparameters object
s_mat  = s_obj.Parameters;            % Size [1 x 1 x N]
z_mat  = s2z(s_mat, s_obj.Impedance); % S-to-Z conversion
z_data = squeeze(z_mat);              % Vector [N x 1]

fig_imp = figure('Name', 'Impedance Analysis', 'Color', 'w');

yyaxis left
plot(freqs/1e9, real(z_data), 'r-', 'LineWidth', 2);
ylabel('Resistance R (Ohms)');
ax_imp = gca;
ax_imp.YColor = 'r';
grid on; hold on;

yyaxis right
plot(freqs/1e9, imag(z_data), 'b--', 'LineWidth', 2);
ylabel('Reactance X (Ohms)');
ax_imp.YColor = 'b';
yline(0, 'k:', 'LineWidth', 1.5);

xlabel('Frequency (GHz)');
title('Input Impedance (Single Slot)');
legend('R (Active)', 'X (Reactive)', 'Location', 'best');
fprintf('Impedance calculation complete.\n');

%% 7. SMITH CHART
% FIXED: removed grid on after smithplot (caused an error)
figure('Name', 'Smith Chart Analysis', 'Color', 'w');

s_plot = smithplot(freqs, s11_complex, 'LineStyle', '-', 'LineWidth', 2);
s_plot.LegendVisible = false;
s_plot.TitleTop      = 'Smith Chart (S11)';

% Marker at 5.9 GHz
[~, idx_59] = min(abs(freqs - 5.9e9));
text(real(s11_complex(idx_59)), imag(s11_complex(idx_59)), ...
    ' \leftarrow 5.9 GHz', 'Color', 'k', 'FontSize', 10, 'FontWeight', 'bold');

%% 8. 3D RADIATION PATTERN
% Fixed frequency
f_rad = 5.9e9; %---------------------------------------------------------------Change!!!!!!!!!
fprintf('Calculating 3D radiation pattern at %.4f GHz...\n', f_rad/1e9);

figure('Name', '3D Radiation Pattern', 'Color', 'w', 'Position', [150 150 700 600]);
pattern(p, f_rad);
title(sprintf('3D Radiation Pattern @ %.3f GHz', f_rad/1e9), 'FontSize', 13);
fprintf('3D radiation pattern complete.\n');

%% 9 (NEW). E- AND H-PLANE CUTS IN dB

fprintf('Calculating radiation pattern cuts (E- and H-planes) in dB...\n');

theta_angles = 0:1:360;

% --- PLANE CUTS ---
e_plane_data = patternElevation(p, f_rad, 0,  'Elevation', theta_angles); % E-plane
h_plane_data = patternElevation(p, f_rad, 90, 'Elevation', theta_angles); % H-plane

% --- NORMALIZATION (maximum = 0 dB) ---
e_norm = e_plane_data - max(e_plane_data);
h_norm = h_plane_data - max(h_plane_data);

% --- DYNAMIC RANGE CLIPPING ---
dyn_range = -40;
e_norm = max(e_norm, dyn_range);
h_norm = max(h_norm, dyn_range);

% --- ANGLES FOR PLOT ---
theta_plot = deg2rad(90 - theta_angles);

% --- NEW FIGURE ---
figure('Name','E & H Plane Patterns (dB)','Color','w');
ax = polaraxes;
hold on;

polarplot(ax, theta_plot, e_norm, 'r-', 'LineWidth', 2.5);
polarplot(ax, theta_plot, h_norm, 'b--', 'LineWidth', 2.5);

hold off;

% --- AXES IN dB ---
ax.RLim = [-40 0];
ax.RTick = [-40 -30 -20 -10 0];
ax.RAxisLocation = 90;

ax.ThetaZeroLocation = 'top';
ax.ThetaDir = 'clockwise';

grid on;

legend('E-Plane (\phi=0°)', 'H-Plane (\phi=90°)', ...
    'Location','southoutside');

title(sprintf('E & H Plane Patterns @ %.3f GHz (dB)', f_rad/1e9));

fprintf('New dB pattern plot complete.\n');

%% 10. GAIN TABLE (E-PLANE)

fprintf('\nGain in E-plane (fixed angles)\n');
fprintf('Frequency: %.3f GHz\n', f_rad/1e9);
fprintf('------------------------------------------\n');
fprintf('Angle from boresight (°) | Gain (dBi)\n');
fprintf('------------------------------------------\n');

% Angles of interest (θ from Z-axis / boresight)
theta_user = [0 30 60 70 80 85];

% COORDINATE CONVERSION (KEY STEP!)
theta_matlab = 90 - theta_user;

% Calculate gain
e_gain = patternElevation(p, f_rad, 0, 'Elevation', theta_matlab);

% Print results
for i = 1:length(theta_user)
    fprintf('%6d                   | %6.2f\n', theta_user(i), e_gain(i));
end

fprintf('==========================================\n');

toc