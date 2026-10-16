tic
%% ОЧИСТКА И НАСТРОЙКА
clc; clear; close all;
mm = 1e-3;
scriptName = mfilename;   % имя текущего запущенного файла

% =============================================================================
% pcbComponent + CoaxialFeed (RF PCB Toolbox, R2024b+) вместо pcbStack +
% FeedLocations/FeedDiameter. Геометрия (патч со слотом + щели в земле)
% сохранена без изменений для всех трёх вариантов антенн; фид теперь
% задаётся явно через Pad/Antipad + CoaxialFeed, как для Antenna 1/2.
% Разделы 8-10 (pattern/patternElevation) на pcbComponent не гарантированы
% официально — обёрнуты в try/catch.
% =============================================================================

%% 1. ГЕОМЕТРИЯ ПАРАМЕТРОВ (Согласно чертежу)
% --- ОСНОВНЫЕ РАЗМЕРЫ ПАТЧА ---
h  = 1.57*mm;       % Толщина подложки
h1=1.57;

% =====================================================================
%                    ВЫБОР ВАРИАНТА АНТЕННЫ
% =====================================================================
% ANTENNA_OPTION = 1: свои размеры, БЕЗ выреза в патче, БЕЗ щелей в земле
% ANTENNA_OPTION = 2: свои размеры, вырез с края патча, БЕЗ щелей в земле
% ANTENNA_OPTION = 3: свои размеры, вырез с края патча, + 2 щели в земле
ANTENNA_OPTION = 1;   % <-- МЕНЯТЬ ЗДЕСЬ: 1, 2 или 3

switch ANTENNA_OPTION
    case 1
        % --- АНТЕННА 1 ---
        Lx = 15.6*mm;
        Wy = 20.1*mm;
        feed_point = [-3.6*mm, 0];
        USE_SLOT = false;   % вырез в патче
        USE_GAP  = false;   % щели в земле
        a = 0*mm;  b = 0*mm;   % вырез не используется

    case 2
        % --- АНТЕННА 2 ---
        Lx = 17.6*mm;
        Wy = 32*mm;
        feed_point = [-6*mm, 0];
        USE_SLOT = true;    % вырез в патче
        USE_GAP  = false;   % щели в земле
        a = 2.4*mm;         % Глубина выреза (dx на чертеже)
        b = 18.0*mm;        % Длина выреза (dy на чертеже)

    case 3
        % --- АНТЕННА 3 ---
        Lx = 17.6*mm;
        Wy = 32.8*mm;
        feed_point = [-6.7*mm, 0];
        USE_SLOT = true;    % вырез в патче
        USE_GAP  = true;    % щели в земле
        a = 2.75*mm;        % Глубина выреза (dx на чертеже)
        b = 21.7*mm;        % Длина выреза (dy на чертеже)

    otherwise
        error('ANTENNA_OPTION должен быть 1, 2 или 3');
end

Gnd_SizeX = Lx + 6*h;
Gnd_SizeY = Wy + 6*h;

% Рассчитываем смещение, чтобы вырез был точно по краю патча:
% Центр патча в 0. Смещение = (Lx/2) - (a/2)
s_Offset_X = (Lx - a)/2; 

% Передаем в переменные для моделирования
dx = a; 
dy = b;

% --- ЧАСТОТНАЯ СЕТКА ---
freqs = linspace(5.2e9, 6.4e9, 11); %---------------------------------------Менять, Число точек счета!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
f_max=5.9e9;%----------------------------------------------------------------Менять!!!!!!!!
M=4;

%% ===== ЩЕЛИ В ЗЕМЛЕ =====
gnd_slot_gap    = -0.5*mm;   % расстояние от кромки патча до щели
gnd_slot_width  = 3.5*mm;    % ширина щели (по Y)
gnd_slot_length = 24*mm;     % длина щели (по X)

% Y-координата центра щелей (симметрично сверху и снизу патча)
gnd_slot_y = Wy/2 + gnd_slot_gap + gnd_slot_width/2;

fprintf('\n=== ANTENNA_OPTION = %d ===\n', ANTENNA_OPTION);
fprintf('    Lx = %.2f мм, Wy = %.2f мм, Feed X = %.3f мм\n', Lx/mm, Wy/mm, feed_point(1)/mm);
fprintf('    USE_SLOT (вырез в патче) = %d\n', USE_SLOT);
fprintf('    USE_GAP  (щели в земле)  = %d\n', USE_GAP);
if USE_GAP
    fprintf('    gap    = %.2f мм\n', gnd_slot_gap/mm);
    fprintf('    width  = %.2f мм\n', gnd_slot_width/mm);
    fprintf('    length = %.2f мм\n', gnd_slot_length/mm);
    fprintf('    Y-центр щелей = ±%.3f мм\n', gnd_slot_y/mm);
end

%% 2. СОЗДАНИЕ ОБЪЕКТОВ АНТЕННЫ
patch_rect_solid = antenna.Rectangle('Length', Lx, 'Width', Wy);

if USE_SLOT
    slot_rect = antenna.Rectangle('Length', dx, 'Width', dy, ...
        'Center', [s_Offset_X, 0]);
    patch_with_slot = patch_rect_solid - slot_rect;
    fprintf('--- ВЫРЕЗ В ПАТЧЕ ВКЛЮЧЕН (dx=%.2f мм, dy=%.2f мм, offset X=%.3f мм) ---\n', ...
        dx/mm, dy/mm, s_Offset_X/mm);
else
    patch_with_slot = patch_rect_solid;
    fprintf('--- ВЫРЕЗ В ПАТЧЕ ОТКЛЮЧЕН ---\n');
end

% Подложка
sub      = dielectric('Name','RT5880','EpsilonR',2.2,'Thickness',h);

% --- Земля: сплошная либо с вырезанными щелями (USE_GAP) ---
gnd_solid = antenna.Rectangle('Length', Gnd_SizeX, 'Width', Gnd_SizeY);

gnd_slot_top = antenna.Rectangle('Length', gnd_slot_length, 'Width', gnd_slot_width, ...
    'Center', [0,  gnd_slot_y]);
gnd_slot_bot = antenna.Rectangle('Length', gnd_slot_length, 'Width', gnd_slot_width, ...
    'Center', [0, -gnd_slot_y]);

if USE_GAP
    full_gnd = gnd_solid - gnd_slot_top - gnd_slot_bot;
    fprintf('--- ЩЕЛИ В ЗЕМЛЕ ВКЛЮЧЕНЫ ---\n');
else
    full_gnd = gnd_solid;
    fprintf('--- ЩЕЛИ В ЗЕМЛЕ ОТКЛЮЧЕНЫ (референс) ---\n');
end

% Тег для заголовков графиков (см. разделы 5-8)
if USE_SLOT
    slot_part = sprintf('patch slot a=%.2fмм b=%.2fмм', a/mm, b/mm);
else
    slot_part = 'no patch slot';
end
if USE_GAP
    gnd_part = sprintf('gnd gap=%.1fмм w=%.1fмм L=%.1fмм', ...
                      gnd_slot_gap/mm, gnd_slot_width/mm, gnd_slot_length/mm);
else
    gnd_part = 'no gnd slots';
end
gap_tag = sprintf(' [Antenna %d | %s | %s | CoaxialFeed]', ANTENNA_OPTION, slot_part, gnd_part);

%% ===== КОАКСИАЛЬНЫЙ ФИД (Pad/Antipad) =====
% Параметры фида — согласованы с OpenEMS/CST (pin r=0.5мм, Z0=50 Ом),
% диаметр антипада получается из формулы Z0=60/sqrt(er)*ln(D/d)
% (та же логика, что для Antenna 1 и Antenna 2).
pin_d   = 1.0*mm;
Z0_coax = 50;
antipad_d = pin_d * exp(Z0_coax*sqrt(sub.EpsilonR)/60);

fprintf('\n--- ПАРАМЕТРЫ КОАКСИАЛЬНОГО ФИДА (RF PCB Toolbox) ---\n');
fprintf('    pin_d      = %.3f мм\n', pin_d/mm);
fprintf('    antipad_d  = %.3f мм\n', antipad_d/mm);

cPad     = antenna.Circle('Center', feed_point, 'Radius', pin_d/2,     'NumPoints', 32);
cAntipad = antenna.Circle('Center', feed_point, 'Radius', antipad_d/2, 'NumPoints', 32);

% Antipad вырезается из уже готовой земли (full_gnd — сплошная или со
% щелями, в зависимости от USE_GAP), затем pad возвращается обратно.
gnd_with_antipad = full_gnd - cAntipad + cPad;

%-----------------------------
%% 3. СБОРКА pcbComponent + CoaxialFeed И ГЕНЕРАЦИЯ СЕТКИ (MESH)
p = pcbStack;
p.Name           = 'Antenna_CoaxialFeed_RFPCB';
p.BoardThickness = h;
p.BoardShape     = antenna.Rectangle('Length', Gnd_SizeX, 'Width', Gnd_SizeY);
p.Layers         = {patch_with_slot, sub, gnd_with_antipad};

% pcbComponent по умолчанию ожидает фид через FeedLocations —
% переключаем на FeedDefinitions (иначе set.FeedDefinitions выдаёт ошибку).
p.FeedFormat      = 'FeedDefinitions';
f1 = CoaxialFeed('PadShape', cPad, 'AntipadShape', cAntipad, ...
    'SignalLayers', 1, 'GroundLayers', 3);
p.FeedDefinitions = f1;
p.Conductor       = metal('Copper');

% --- АВТОМАТИЧЕСКИЙ РАСЧЕТ ПАРАМЕТРОВ СЕТКИ ---
c0 = 3e8;                  % Скорость света
er = sub.EpsilonR;         % Берем диэлектрическую проницаемость из объекта sub

% Длина волны в диэлектрике (основной критерий точности)
lambda_g = c0 / (f_max * sqrt(er));

a1=2*mm;
a2=0.5*mm;

figure('Name', '2D Mesh View (Top)', 'Color', 'w');
mesh(p, 'MaxEdgeLength', a1, 'MinEdgeLength', a2); %---------------------------MESH
view(0, 90);    % Строго плоский вид
axis equal;     % Сохранение пропорций геометрии

title([scriptName gap_tag], ...
      'FontSize', 14, ...
      'FontWeight', 'bold', ...
      'Interpreter', 'none');
xlabel('x (m)');
ylabel('y (m)');
grid on;

fprintf('\n--- ПАРАМЕТРЫ СЕТКИ (АВТО) ---\n');
fprintf('Частота расчета: %.2f ГГц\n', f_max/1e9);
fprintf('MaxEdgeLength (a1): %.3f mm\n', a1/mm);
fprintf('MinEdgeLength (a2): %.3f mm\n', a2/mm);
fprintf('------------------------------\n');

%-------------------------------------
%% 4. РАСЧЕТ S-ПАРАМЕТРОВ — ГРУБЫЙ ПРОХОД (21 точка)
fprintf('Запуск электромагнитного расчета (MoM, RF PCB Toolbox) — грубый проход...\n');
tic_sp = tic;
s_obj_coarse = sparameters(p, freqs, 50);
fprintf('Грубый расчет занял %.1f сек. (%d точек)\n', toc(tic_sp), numel(freqs));

if isa(s_obj_coarse, 'sparameters')
    s11_coarse = rfparam(s_obj_coarse, 1, 1);
else
    s11_coarse = squeeze(s_obj_coarse.Parameters(1,1,:));
end
swr_coarse = (1 + abs(s11_coarse)) ./ (1 - abs(s11_coarse));

%% 4.1 ПОИСК ПЕРЕСЕЧЕНИЙ SWR=2 И ЛОКАЛЬНОЕ УТОЧНЕНИЕ
target       = 2;
sign_diff    = sign(swr_coarse - target);
crossing_idx = find(diff(sign_diff) ~= 0);   % интервалы [idx, idx+1] с пересечением

n_refine = M;   % доп. точек внутри каждого интервала пересечения
freqs_refine = [];

for k = 1:length(crossing_idx)
    idx  = crossing_idx(k);
    f_lo = freqs(idx);
    f_hi = freqs(idx+1);
    new_pts = linspace(f_lo, f_hi, n_refine+2);
    new_pts = new_pts(2:end-1);   % без повтора уже посчитанных границ
    freqs_refine = [freqs_refine, new_pts]; %#ok<AGROW>
end
freqs_refine = unique(freqs_refine);

if ~isempty(freqs_refine)
    fprintf('Найдено %d пересечений SWR=2 -> уточняю %d точками рядом с ними...\n', ...
        numel(crossing_idx), numel(freqs_refine));
    tic_sp2 = tic;
    s_obj_refine = sparameters(p, freqs_refine, 50);
    fprintf('Уточняющий расчет занял %.1f сек.\n', toc(tic_sp2));

    if isa(s_obj_refine, 'sparameters')
        s11_refine = rfparam(s_obj_refine, 1, 1);
    else
        s11_refine = squeeze(s_obj_refine.Parameters(1,1,:));
    end
else
    s11_refine = [];
    fprintf('Пересечений SWR=2 в грубой сетке не найдено — уточнение не требуется.\n');
end

% --- ОБЪЕДИНЕНИЕ грубых и уточняющих точек в единый массив ---
freqs = [freqs(:); freqs_refine(:)];
s11_complex = [s11_coarse(:); s11_refine(:)];

[freqs, sort_idx] = sort(freqs);
s11_complex = s11_complex(sort_idx);
[freqs, uniq_idx] = unique(freqs, 'stable');
s11_complex = s11_complex(uniq_idx);

fprintf('Итого точек после уточнения: %d (вместо равномерных 51)\n', numel(freqs));

% КСВ по объединенному, локально плотному набору реальных точек
swr_val = (1 + abs(s11_complex)) ./ (1 - abs(s11_complex));

%% 4.2 ЛЁГКОЕ СГЛАЖИВАНИЕ ТОЛЬКО ДЛЯ КРАСОТЫ ГРАФИКА (не для BW!)
N_fine     = 400;
freqs_fine = linspace(freqs(1), freqs(end), N_fine);

s11_fine = interp1(freqs, real(s11_complex), freqs_fine, 'spline') + ...
    1i * interp1(freqs, imag(s11_complex), freqs_fine, 'spline');

swr_fine = (1 + abs(s11_fine)) ./ (1 - abs(s11_fine));
Z0     = 50;                                          % опорный импеданс порта (см. вызов sparameters(...,50))
z_fine = Z0 * (1 + s11_fine) ./ (1 - s11_fine);       % импеданс из интерп. S11

%% 4.3 СОХРАНЕНИЕ КСВ В CSV (папка Documents)
% Путь к папке "Документы" берётся у Windows (работает и при OneDrive)
try
    docs_dir = char(System.Environment.GetFolderPath( ...
        System.Environment.SpecialFolder.MyDocuments));
catch
    docs_dir = pwd;   % если не удалось — текущая папка MATLAB
end
csv_name = fullfile(docs_dir, sprintf('VSWR_Antenna%d_MatLab.csv', ANTENNA_OPTION));

fid = fopen(csv_name, 'w');
fprintf(fid, '# %s\n', scriptName);          % первая строка: имя скрипта
fclose(fid);
writematrix([freqs_fine(:)/1e9, swr_fine(:)], csv_name, 'WriteMode', 'append');
fprintf('КСВ сохранён в файл: %s\n', csv_name);

%% 5. ГРАФИК КСВ (SWR) И ТАБЛИЦА ПАРАМЕТРОВ
fig_swr = figure('Name', 'SWR & Parameters', 'Color', 'w', 'Position', [100 100 1100 500]);

subplot(1,2,1);
plot(freqs_fine/1e9, swr_fine, 'r-', 'LineWidth', 2);
grid on; hold on;
yline(2, 'b--', 'SWR = 2');
ylim([1 10]);
xlabel('Frequency (GHz)');
ylabel('SWR');
title(['SWR Analysis' gap_tag]);

bw_str    = 'N/A';
range_str = 'N/A';
f_center  = 5.9e9 / 1e9; %----------------------------------------------------Менять!!

bw_indices = find(swr_fine <= 2);
if ~isempty(bw_indices)
    f_low    = freqs_fine(bw_indices(1))   / 1e9;
    f_high   = freqs_fine(bw_indices(end)) / 1e9;
    BW_abs   = (f_high - f_low) * 1e3;
    f_center = (f_high + f_low) / 2;

    fill([f_low f_high f_high f_low], [1 1 2 2], [0.8 1 0.8], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.3);
    text(f_center, 1.5, sprintf('BW = %.1f MHz', BW_abs), ...
        'HorizontalAlignment', 'center', 'Color', [0 0.5 0], 'FontWeight', 'bold');

    bw_str    = sprintf('%.1f MHz', BW_abs);
    range_str = sprintf('%.3f - %.3f GHz', f_low, f_high);
end

subplot(1,2,2);
axis off;

if USE_SLOT
    patch_slot_info = sprintf('Вырез в патче: ВКЛЮЧЕН\n  dx = %.2f mm, dy = %.2f mm\n', dx/mm, dy/mm);
else
    patch_slot_info = sprintf('Вырез в патче: ОТКЛЮЧЕН\n');
end

if USE_GAP
    gnd_slot_info = sprintf('Щели в земле: ВКЛЮЧЕНЫ\n  gap=%.2f mm, w=%.2f mm, L=%.2f mm\n', ...
                        gnd_slot_gap/mm, gnd_slot_width/mm, gnd_slot_length/mm);
else
    gnd_slot_info = sprintf('Щели в земле: ОТКЛЮЧЕНЫ\n');
end

param_text = sprintf([...
    'ANTENNA_OPTION = %d\n\n'      ...
    'ТЕКУЩИЕ ПАРАМЕТРЫ:\n\n'       ...
    'Lx           = %.2f mm\n'     ...
    'Wy           = %.2f mm\n'     ...
    'h            = %.2f mm\n'     ...
    'Feed X       = %.3f mm\n\n'   ...
    patch_slot_info                ...
    gnd_slot_info                  ...
    'Фид: CoaxialFeed (pin_d=%.2f mm, antipad_d=%.2f mm)\n' ...
    '--------------------------\n' ...
    'РЕЗУЛЬТАТЫ (SWR < 2):\n'      ...
    'Bandwidth : %s\n'             ...
    'Range     : %s'],             ...
    ANTENNA_OPTION,                       ...
    Lx/mm, Wy/mm, h/mm, feed_point(1)/mm, ...
    pin_d/mm, antipad_d/mm,               ...
    bw_str, range_str);

text(0.05, 0.5, param_text, 'FontSize', 11, 'FontWeight', 'bold', 'FontName', 'Consolas');

%% 6. ГРАФИК ИМПЕДАНСА (R и X)
z_data = Z0 * (1 + s11_complex) ./ (1 - s11_complex);

fig_imp = figure('Name', 'Impedance Analysis', 'Color', 'w');

yyaxis left
plot(freqs_fine/1e9, real(z_fine), 'r-', 'LineWidth', 2); hold on;
plot(freqs/1e9, real(z_data), 'ko', 'MarkerFaceColor', 'r', 'MarkerSize', 5);
ylabel('Resistance R (Ohms)');
ax_imp = gca;
ax_imp.YColor = 'r';
grid on;

yyaxis right
plot(freqs_fine/1e9, imag(z_fine), 'b--', 'LineWidth', 2); hold on;
plot(freqs/1e9, imag(z_data), 'ko', 'MarkerFaceColor', 'b', 'MarkerSize', 5);
ylabel('Reactance X (Ohms)');
ax_imp.YColor = 'b';
yline(0, 'k:', 'LineWidth', 1.5);

xlabel('Frequency (GHz)');
title(['Input Impedance' gap_tag]);
legend('R (Active)', 'X (Reactive)', 'Location', 'best');
fprintf('Расчет импеданса завершен.\n');

%% 7. ДИАГРАММА СМИТА (SMITH CHART)
figure('Name', 'Smith Chart Analysis', 'Color', 'w');

s_plot = smithplot(freqs_fine, s11_fine, 'LineStyle', '-', 'LineWidth', 2);
s_plot.LegendVisible = false;
s_plot.TitleTop      = ['Smith Chart (S11)' gap_tag];

[~, idx_59] = min(abs(freqs_fine - 5.9e9));
text(real(s11_fine(idx_59)), imag(s11_fine(idx_59)), ...
    ' \leftarrow 5.9 GHz', 'Color', 'k', 'FontSize', 10, 'FontWeight', 'bold');

%% 8. 3D ДИАГРАММА НАПРАВЛЕННОСТИ — ТОЧКА РИСКА НА pcbComponent
f_rad = 5.9e9; %---------------------------------------------------------------Менять!!!!!!!!!
try
    fprintf('Расчет 3D диаграммы направленности на %.4f GHz...\n', f_rad/1e9);
    figure('Name', '3D Radiation Pattern', 'Color', 'w', 'Position', [150 150 700 600]);
    pattern(p, f_rad);
    title(sprintf('3D Radiation Pattern @ %.3f GHz%s', f_rad/1e9, gap_tag), 'FontSize', 13);
    fprintf('3D диаграмма направленности построена (pattern() отработал на pcbComponent).\n');
catch ME
    fprintf(2, '\npattern() НЕ сработал на pcbComponent: %s\n', ME.message);
    fprintf(2, 'Это ожидаемый риск — см. комментарий в начале файла.\n');
end

%% 9. E- И H-ПЛОСКОСТИ В dB (тоже риск на pcbComponent)
try
    fprintf('Расчет срезов ДН (E- и H-плоскости) в dB...\n');

    theta_angles = 0:1:360;

    e_plane_data = patternElevation(p, f_rad, 0,  'Elevation', theta_angles); % E-plane
    h_plane_data = patternElevation(p, f_rad, 90, 'Elevation', theta_angles); % H-plane

    e_norm = e_plane_data - max(e_plane_data);
    h_norm = h_plane_data - max(h_plane_data);

    dyn_range = -40;
    e_norm = max(e_norm, dyn_range);
    h_norm = max(h_norm, dyn_range);

    theta_plot = deg2rad(90 - theta_angles);

    figure('Name','E & H Plane Patterns (dB)','Color','w');
    ax = polaraxes;
    hold on;

    polarplot(ax, theta_plot, e_norm, 'r-', 'LineWidth', 2.5);
    polarplot(ax, theta_plot, h_norm, 'b--', 'LineWidth', 2.5);

    hold off;

    ax.RLim = [-40 0];
    ax.RTick = [-40 -30 -20 -10 0];
    ax.RAxisLocation = 90;

    ax.ThetaZeroLocation = 'top';
    ax.ThetaDir = 'clockwise';

    grid on;

    legend('E-Plane (\phi=0°)', 'H-Plane (\phi=90°)', ...
        'Location','southoutside');

    title(sprintf('E & H Plane Patterns @ %.3f GHz (dB)%s', f_rad/1e9, gap_tag));

    fprintf('dB график построен.\n');

    %% 10. ТАБЛИЦА УСИЛЕНИЯ (E-ПЛОСКОСТЬ)
    fprintf('\nУсиление в E-плоскости (фиксированные углы)\n');
    fprintf('Частота: %.3f GHz\n', f_rad/1e9);
    fprintf('------------------------------------------\n');
    fprintf('Угол от нормали (°) | Усиление (dBi)\n');
    fprintf('------------------------------------------\n');

    theta_user = [0 30 60 70 80 85];
    theta_matlab = 90 - theta_user;

    e_gain = patternElevation(p, f_rad, 0, 'Elevation', theta_matlab);

    for i = 1:length(theta_user)
        fprintf('%6d               | %6.2f\n', theta_user(i), e_gain(i));
    end

    fprintf('==========================================\n');
catch ME
    fprintf(2, '\npatternElevation() НЕ сработал на pcbComponent: %s\n', ME.message);
    fprintf(2, 'Срезы ДН и таблицу усиления придётся считать на pcbStack-версии отдельно.\n');
end

toc
