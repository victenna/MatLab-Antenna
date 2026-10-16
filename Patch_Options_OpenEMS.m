close all
clear
clc

%% Физические константы
physical_constants;
unit = 1e-3;

% =====================================================================
%                    ВЫБОР ВАРИАНТА АНТЕННЫ
% =====================================================================
% ANTENNA_OPTION = 1: свои размеры, БЕЗ выреза в патче, БЕЗ щелей в земле
% ANTENNA_OPTION = 2: свои размеры, вырез с края патча, БЕЗ щелей в земле
% ANTENNA_OPTION = 3: свои размеры, вырез с края патча, + 2 щели в земле
ANTENNA_OPTION = 3;   % <-- МЕНЯТЬ ЗДЕСЬ: 1, 2 или 3

switch ANTENNA_OPTION
    case 1
        % --- АНТЕННА 1 (референс, без выреза) ---
        patch.width  = 15.6;   % X (соответствует Lx в MATLAB MoM)
        patch.length = 20.1;    % Y (соответствует Wy в MATLAB MoM)
        feed.x = -3.6;
        feed.y =  0.0;
        USE_SLOT = false;
        USE_GAP  = false;
        dx = 0; dy = 0;

    case 2
        % --- АНТЕННА 2 (вырез в патче, без щелей в земле) ---
        patch.width  = 17.6;
        patch.length = 32;
        feed.x = -6.0;
        feed.y =  0.0;
        USE_SLOT = true;
        USE_GAP  = false;
        dx = 2.4;    % глубина выреза по X
        dy = 18.0;   % длина выреза по Y

    case 3
        % --- АНТЕННА 3 (вырез в патче + 2 щели в земле) ---
        patch.width  = 17.6;
        patch.length = 32.8;
        feed.x = -6.7;
        feed.y =  0.0;
        USE_SLOT = true;
        USE_GAP  = true;
        dx = 2.75;
        dy = 21.7;

    otherwise
        error('ANTENNA_OPTION должен быть 1, 2 или 3');
end

% Смещение выреза так, чтобы он был точно по правому краю патча
s_Offset_X = (patch.width - dx)/2;

%% Подложка / земля
substrate.epsR      = 2.2;
substrate.thickness = 1.57;
substrate.cells     = 8;

f0 = 5.9e9;
fc = 1.5e9;
tanD = 0.0009;
substrate.kappa = 2*pi*f0 * EPS0 * substrate.epsR * tanD;

substrate.width     = patch.width  + 6*substrate.thickness;
substrate.length    = patch.length + 6*substrate.thickness;

%% Щели в земле (используются только при USE_GAP = true)
gnd_slot_gap    = -0.5;   % расстояние от кромки патча до щели, мм
gnd_slot_width  = 3.5;    % ширина щели по Y, мм
gnd_slot_length = 24;     % длина щели по X, мм
gnd_slot_y = patch.length/2 + gnd_slot_gap + gnd_slot_width/2;

fprintf('\n=== ANTENNA_OPTION = %d ===\n', ANTENNA_OPTION);
fprintf('    patch.width  = %.2f мм\n', patch.width);
fprintf('    patch.length = %.2f мм\n', patch.length);
fprintf('    feed.x       = %.3f мм\n', feed.x);
fprintf('    USE_SLOT (вырез в патче) = %d\n', USE_SLOT);
fprintf('    USE_GAP  (щели в земле)  = %d\n', USE_GAP);
if USE_SLOT
    fprintf('    dx = %.2f мм, dy = %.2f мм, offset X = %.3f мм\n', dx, dy, s_Offset_X);
end
if USE_GAP
    fprintf('    gap = %.2f мм, width = %.2f мм, length = %.2f мм, Y-центр = ±%.3f мм\n', ...
        gnd_slot_gap, gnd_slot_width, gnd_slot_length, gnd_slot_y);
end

feed.R = 50;

% =====================================================================
% ПАРАМЕТРЫ КОАКСИАЛЬНОГО ФИДЕРА (одинаковы для всех вариантов антенны)
% =====================================================================
via.radius    = 0.5;         % радиус центрального пина
coax.eps      = 2.1;         % тефлон волнового заполнения
coax.b        = (2*via.radius) * exp(feed.R*sqrt(coax.eps)/60) / 2;
                              % Внешний радиус диэлектрика (под coax.eps!)
coax.shield_t = 0.3;         % толщина металлической стенки экрана
coax.len      = 3.0;         % длина коаксиального отрезка под землёй

% Равномерный шаг по Z внутри коаксиального порта = шагу подложки.
% Нужен для calcTLPort (иначе: "mesh is not equidistant").
dz_sub = substrate.thickness / substrate.cells;   % ≈ 0.196 мм
n_coax = round(coax.len / dz_sub);
z_coax = linspace(-coax.len, 0, n_coax+1);

fprintf('\n--- ПАРАМЕТРЫ КОАКСИАЛЬНОГО ФИДЕРА ---\n');
fprintf('  via.radius     = %.3f мм\n', via.radius);
fprintf('  coax.b (диэл.) = %.3f мм\n', coax.b);
fprintf('  coax.len       = %.3f мм\n', coax.len);
fprintf('  ячеек по Z в порту = %d (шаг %.4f мм)\n', n_coax, coax.len/n_coax);

%% Симуляционный бокс
%SimBox = [120 120 100];
SimBox = [150 150 120];%---------------------------------Important
%SimBox = [200 200 160];

%% FDTD
% NrTs увеличен с 80000: при вырезе в патче (Antenna 2/3) сигнал на
% порту затухает медленнее (слабо связанная резонансная мода от щели),
% и обрыв по лимиту NrTs раньше естественного затухания до EndCriteria
% даёт прямоугольную обрезку временного сигнала -> sinc-рябь в S11.
%FDTD = InitFDTD('NrTs', 20000, 'EndCriteria', 1e-4);
FDTD = InitFDTD('NrTs', 300000, 'EndCriteria', 1e-4);%------------------------------Important
FDTD = SetGaussExcite(FDTD, f0, fc);
FDTD = SetBoundaryCond(FDTD, {'PML_8' 'PML_8' 'PML_8' 'PML_8' 'PML_8' 'PML_8'});

%% CSX — геометрия
CSX = InitCSX();

% Начальные границы расчетной области
mesh.x = [-SimBox(1)/2  SimBox(1)/2];
mesh.y = [-SimBox(2)/2  SimBox(2)/2];

% Сетка по Z: воздух, подложка и равномерные слои коаксиала вниз от земли
mesh.z = [-SimBox(3)/3  SimBox(3)*2/3  ...
           linspace(0, substrate.thickness, substrate.cells+1) ...
           z_coax];

% --- Патч (сплошной металл) ---
CSX = AddMetal(CSX, 'patch');
CSX = AddBox(CSX, 'patch', 10, ...
    [-patch.width/2,  -patch.length/2,  substrate.thickness], ...
    [ patch.width/2,   patch.length/2,  substrate.thickness]);

% --- Вырез в патче (edge-notch slot), опционально ---
% Реализован через приоритет: воздушный "вырез" накладывается поверх
% металла патча (prio > patch prio) и локально "прорезает" его — это
% CSXCAD-эквивалент Boolean Subtract в MATLAB Antenna Toolbox.
if USE_SLOT
    CSX = AddMaterial(CSX, 'patch_slot_air');
    CSX = SetMaterialProperty(CSX, 'patch_slot_air', 'Epsilon', 1);
    CSX = AddBox(CSX, 'patch_slot_air', 20, ...
        [s_Offset_X - dx/2,  -dy/2,  substrate.thickness], ...
        [s_Offset_X + dx/2,   dy/2,  substrate.thickness]);
end

% --- Подложка ---
CSX = AddMaterial(CSX, 'substrate');
CSX = SetMaterialProperty(CSX, 'substrate', ...
    'Epsilon', substrate.epsR, 'Kappa', substrate.kappa);
CSX = AddBox(CSX, 'substrate', 0, ...
    [-substrate.width/2,  -substrate.length/2,  0], ...
    [ substrate.width/2,   substrate.length/2,  substrate.thickness]);

% --- Земляная плоскость ---
CSX = AddMetal(CSX, 'gnd');
CSX = AddBox(CSX, 'gnd', 10, ...
    [-substrate.width/2,  -substrate.length/2,  0], ...
    [ substrate.width/2,   substrate.length/2,  0]);

% --- Щели в земле (для подавления кросс-поляризации), опционально ---
if USE_GAP
    CSX = AddMaterial(CSX, 'gnd_slot_air');
    CSX = SetMaterialProperty(CSX, 'gnd_slot_air', 'Epsilon', 1);
    CSX = AddBox(CSX, 'gnd_slot_air', 20, ...
        [-gnd_slot_length/2,  gnd_slot_y - gnd_slot_width/2,  0], ...
        [ gnd_slot_length/2,  gnd_slot_y + gnd_slot_width/2,  0]);
    CSX = AddBox(CSX, 'gnd_slot_air', 20, ...
        [-gnd_slot_length/2, -gnd_slot_y - gnd_slot_width/2,  0], ...
        [ gnd_slot_length/2, -gnd_slot_y + gnd_slot_width/2,  0]);
end

% --- Отверстие в земле под диэлектрик коаксиала ---
% ВАЖНО: приоритет должен быть СТРОГО МЕЖДУ приоритетом земли (10) и
% приоритетом via_pin/coax_metal (12), а не выше них. Иначе воздух
% antipad "перебивает" металл пина ровно в плоскости z=0 — там, где
% центральный проводник коаксиального порта должен электрически
% соединяться с via, и получается паразитный разрыв в фидере.
CSX = AddMaterial(CSX, 'antipad_air');
CSX = SetMaterialProperty(CSX, 'antipad_air', 'Epsilon', 1);
CSX = AddCylinder(CSX, 'antipad_air', 11, ...
    [feed.x, feed.y, 0], [feed.x, feed.y, 0], coax.b);

% --- Направляющая Via (пин) внутри подложки ---
CSX = AddMetal(CSX, 'via_pin');
CSX = AddCylinder(CSX, 'via_pin', 12, ...
    [feed.x, feed.y, 0], [feed.x, feed.y, substrate.thickness], ...
    via.radius);

% --- Свойства материалов для внутренностей порта ---
CSX = AddMetal(CSX, 'coax_metal');
CSX = AddMaterial(CSX, 'coax_dielectric');
CSX = SetMaterialProperty(CSX, 'coax_dielectric', 'Epsilon', coax.eps);

% --- NF2FF бокс ---
nf2ff_start = [-SimBox(1)/2+15  -SimBox(2)/2+15  -SimBox(3)/3+15];
nf2ff_stop  = [ SimBox(1)/2-15   SimBox(2)/2-15   SimBox(3)*2/3-15];
[CSX, nf2ff] = CreateNF2FFBox(CSX, 'nf2ff', nf2ff_start, nf2ff_stop);

% =====================================================================
% РАСЧЕТ И ИНИЦИАЛИЗАЦИЯ СЕТКИ
% =====================================================================
via_step  = via.radius / 3;
port_step = (coax.b - via.radius) / 5;

mesh_local_coax_x = [ ...
    feed.x + (-via.radius : via_step : via.radius), ...
    feed.x + (via.radius + port_step : port_step : coax.b), ...
    feed.x - (via.radius + port_step : port_step : coax.b), ...
    feed.x - coax.b - coax.shield_t, feed.x + coax.b + coax.shield_t];

mesh_local_coax_y = [ ...
    feed.y + (-via.radius : via_step : via.radius), ...
    feed.y + (via.radius + port_step : port_step : coax.b), ...
    feed.y - (via.radius + port_step : port_step : coax.b), ...
    feed.y - coax.b - coax.shield_t, feed.y + coax.b + coax.shield_t];

mesh.x = [mesh.x, mesh_local_coax_x];
mesh.y = [mesh.y, mesh_local_coax_y];

% Явные линии сетки по краям выреза/щелей
if USE_SLOT
    mesh.x = [mesh.x, s_Offset_X - dx/2, s_Offset_X + dx/2];
    mesh.y = [mesh.y, -dy/2, dy/2];
end
if USE_GAP
    mesh.x = [mesh.x, -gnd_slot_length/2, gnd_slot_length/2];
    mesh.y = [mesh.y, gnd_slot_y - gnd_slot_width/2, gnd_slot_y + gnd_slot_width/2, ...
                      -gnd_slot_y - gnd_slot_width/2, -gnd_slot_y + gnd_slot_width/2];
end

% Автоматическая генерация и сглаживание сетки
mesh = DetectEdges(CSX, mesh, 'ExcludeProperty', {'patch', 'via_pin', 'coax_metal'});
mesh = DetectEdges(CSX, mesh, 'SetProperty', {'patch'}, ...
    '2D_Metal_Edge_Res', c0/(f0+fc)/unit/50);
mesh = SmoothMesh(mesh, c0/(f0+fc)/unit/40, 1.4);%-------------------------------Important
%mesh = SmoothMesh(mesh, c0/(f0+fc)/unit/15, 1.4);

% Гарантируем равномерную сетку по Z внутри коаксиального порта:
% убираем всё, что SmoothMesh мог вставить между -coax.len и 0,
% и возвращаем ровные линии z_coax
mesh.z(mesh.z > -coax.len & mesh.z < 0) = [];
mesh.z = sort(unique([mesh.z, z_coax, substrate.thickness]));

dz_port = diff(mesh.z(mesh.z >= -coax.len & mesh.z <= 0));
fprintf('  Шаг Z в порту: min = %.4f, max = %.4f мм\n', min(dz_port), max(dz_port));

% Финализируем сетку в CSX структуре
CSX = DefineRectGrid(CSX, unit, mesh);

% =====================================================================
% ДОБАВЛЕНИЕ ПОЛНОЦЕННОГО КОАКСИАЛЬНОГО ПОРТА
% =====================================================================
[CSX, port] = AddCoaxialPort(CSX, ...
    12, ...                          % Приоритет отрисовки (prio)
    1, ...                           % Уникальный ID порта (portnr)
    'coax_metal', ...                % Материал для проводников
    'coax_dielectric', ...           % Материал диэлектрика заполнения
    [feed.x, feed.y, -coax.len], ... % Начало оси порта (дно кабеля)
    [feed.x, feed.y, 0], ...         % Конец оси порта (уровень земли)
    'z', ...                         % Направление распространения волны
    via.radius, ...                  % r_i: внутренний радиус жилы
    coax.b, ...                      % r_o: внутренний радиус экрана
    coax.b + coax.shield_t, ...      % r_os: внешний радиус экрана
    'ExciteAmp', 1);                 % Активный порт (возбуждение включено)

fprintf('\n--- РАЗМЕР СЕТКИ ---\n');
fprintf('  Линий: X=%d Y=%d Z=%d\n', numel(mesh.x), numel(mesh.y), numel(mesh.z));

%% Тег для заголовков графиков
if USE_SLOT
    slot_part = sprintf('patch slot a=%.2fmm b=%.2fmm', dx, dy);
else
    slot_part = 'no patch slot';
end
if USE_GAP
    gnd_part = sprintf('gnd gap=%.1fmm w=%.1fmm L=%.1fmm', ...
        gnd_slot_gap, gnd_slot_width, gnd_slot_length);
else
    gnd_part = 'no gnd slots';
end
gap_tag = sprintf(' [Antenna %d | %s | %s]', ANTENNA_OPTION, slot_part, gnd_part);

%% Запись и просмотр геометрии
Sim_Path = fullfile(tempdir, sprintf('tmp_Patch_Ant_Coax_Opt%d', ANTENNA_OPTION));
Sim_CSX  = 'patch_ant_coax_feed.xml';

cd(tempdir);
if exist(Sim_Path, 'dir'), rmdir(Sim_Path, 's'); end
mkdir(Sim_Path);

WriteOpenEMS([Sim_Path '/' Sim_CSX], FDTD, CSX);
% CSXGeomPlot([Sim_Path '/' Sim_CSX]);  % отключено — AppCSXCAD зависает

%% Запуск симуляции
orig_dir = pwd;
cd(Sim_Path);
RunOpenEMS(Sim_Path, Sim_CSX);
cd(orig_dir);

% =====================================================================
% БЛОК ПОСТОБРАБОТКИ
% =====================================================================
dir_listing = dir(Sim_Path);
fprintf('\n--- ФАЙЛЫ В %s ПОСЛЕ РАСЧЕТА ---\n', Sim_Path);
disp({dir_listing(~[dir_listing.isdir]).name}');

freq = linspace(5.2e9, 6.2e9, 101);%----------------------------------------!!!! Frequency Sweep !!!
cd(Sim_Path);
port = calcPort(port, Sim_Path, freq);
cd(orig_dir);

% AddCoaxialPort возвращает один struct (не cell, т.к. порт один),
% поэтому обращаемся напрямую через точку, без {1}
s11    = port.uf.ref ./ port.uf.inc;
s11_dB = 20 * log10(abs(s11));
Zin    = port.uf.tot ./ port.if.tot;

%% Построение графиков
figure('Name', ['S11' gap_tag], 'NumberTitle', 'off');
plot(freq/1e9, s11_dB, 'k-', 'LineWidth', 2); hold on;
yline(-10, 'r--', '-10 dB'); grid on;
title(['S_{11}' gap_tag], 'Interpreter', 'none');
xlabel('Частота (ГГц)'); ylabel('|S_{11}| (дБ)'); xlim([5.2 6.4]);
[s11_min, idx_min] = min(s11_dB);
xline(freq(idx_min)/1e9, 'b:', sprintf('f_0 = %.3f ГГц', freq(idx_min)/1e9));

fprintf('\nРезонанс: %.3f ГГц, S11min = %.1f дБ, Zin = %.1f%+.1fj Ом\n', ...
    freq(idx_min)/1e9, s11_min, real(Zin(idx_min)), imag(Zin(idx_min)));

% =====================================================================
% ДИАГРАММА СМИТА И VSWR
% =====================================================================
S = zeros(1, 1, numel(freq));
S(1, 1, :) = s11;
sobj = sparameters(S, freq, feed.R);

% --- Диаграмма Смита ---
figure('Name', ['Smith Chart' gap_tag], 'NumberTitle', 'off');
smithplot(freq, s11, 'GridType', 'Z', 'LineWidth', 1.5);

% --- VSWR ---
vswr_val = (1 + abs(s11)) ./ (1 - abs(s11));

figure('Name', ['VSWR' gap_tag], 'NumberTitle', 'off');
plot(freq/1e9, vswr_val, 'k-', 'LineWidth', 2); hold on; grid on;
yline(2, 'r--', 'VSWR = 2');
title(['VSWR' gap_tag], 'Interpreter', 'none');
xlabel('Частота (ГГц)'); ylabel('VSWR');
xlim([5.2 6.4]); ylim([1 5]);

[vswr_min, idx_vswr] = min(vswr_val);
xline(freq(idx_vswr)/1e9, 'b:', ...
    sprintf('VSWR_{min} = %.2f @ %.3f ГГц', vswr_min, freq(idx_vswr)/1e9));

fprintf('\nVSWR в точке резонанса S11 (%.3f ГГц) = %.2f\n', ...
    freq(idx_min)/1e9, vswr_val(idx_min));
fprintf('Минимальный VSWR = %.2f на %.3f ГГц\n', ...
    vswr_min, freq(idx_vswr)/1e9);

% --- Сохранение .mat (во временную папку симуляции) ---
try
    save(fullfile(Sim_Path, 'S11_sparams.mat'), 'sobj', 'freq', 's11', 'feed');
catch ME_save
    warning('Не удалось сохранить .mat файл: %s', ME_save.message);
end

% =====================================================================
% ЭКСПОРТ ДАННЫХ В CSV (папка Documents)
% =====================================================================
out_dir = fullfile(getenv('USERPROFILE'), 'Documents');

T = table(freq(:)/1e9, s11_dB(:), vswr_val(:), real(Zin(:)), imag(Zin(:)), ...
    'VariableNames', {'Freq_GHz','S11_dB','VSWR','ReZin_Ohm','ImZin_Ohm'});

csv_file = fullfile(out_dir, sprintf('VSWR_Antenna%d_OpenEMS.csv', ANTENNA_OPTION));
writetable(T, csv_file);

fprintf('CSV сохранён: %s\n', csv_file);
