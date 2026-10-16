# =============================================================================
# CST Python-макрос (v2024): ТРИ ВАРИАНТА АНТЕННЫ (Antenna 1 / 2 / 3)
# Геометрия и размеры — как в Antenna_1_2_3_RFTool_Coax.m (MATLAB RF PCB Toolbox)
# Запитка — физический коаксиальный зонд + Waveguide Port (как в
# build_slotted_patch_w.py), общая для всех трёх вариантов.
#
#   ANTENNA_OPTION = 1: свои размеры, БЕЗ выреза в патче, БЕЗ щелей в земле
#   ANTENNA_OPTION = 2: свои размеры, вырез с края патча, БЕЗ щелей в земле
#   ANTENNA_OPTION = 3: свои размеры, вырез с края патча, + 2 щели в земле
#
# Запуск: внешний python.bat из состава CST, либо ipython-консоль CST
# (во втором случае см. блок 0 — переключение способа создания проекта).
# =============================================================================
import cst.interface

# ---------------------------------------------------------------------------
# ЧТО СТРОИТЬ
# ---------------------------------------------------------------------------
# Один вариант:      OPTIONS_TO_BUILD = [3]   #------------------
# Все три сразу:     OPTIONS_TO_BUILD = [1, 2, 3]   (каждый — в отдельном проекте)
OPTIONS_TO_BUILD = [3]                 #--------------------------------------------------------------------------!!!

SAVE_DIR = r"C:\Users\Victor\Documents"

# ---------------------------------------------------------------------------
# 1. ОБЩИЕ ПАРАМЕТРЫ (одинаковы для всех трёх вариантов)
# ---------------------------------------------------------------------------
h_sub     = 1.57      # мм, толщина подложки RT5880 (как h в MATLAB-скрипте)
eps_r     = 2.2       # диэлектрическая проницаемость подложки
tan_d     = 0.0009    # тангенс потерь RT5880
t_metal   = 0.035     # мм, толщина металла патча
pin_d     = 1.0       # мм, диаметр via/pin
via_r     = pin_d / 2.0

f_min     = 5.4       # ГГц  (сетка MATLAB: linspace(5.5, 6.8, 11))
f_max     = 6.4       # ГГц  (в старом build_slotted_patch_w.py было 5.4...6.4)
f_rad     = 5.9       # ГГц, частота монитора дальнего поля

# --- Щели в земле (используются только при ANTENNA_OPTION = 3) --------------
gnd_slot_gap    = -0.5    # мм, расстояние от кромки патча до щели (знак как в MATLAB)
gnd_slot_width  = 3.5     # мм, ширина щели (по Y)
gnd_slot_length = 24.0    # мм, длина щели (по X)

# ---------------------------------------------------------------------------
# 1a. ПАРАМЕТРЫ КОАКСИАЛЬНОГО ЗОНДА
# ---------------------------------------------------------------------------
# Внешний радиус диэлектрика считается из того же условия Z0 = 50 Ом,
# что и antipad_d в MATLAB, но с eps коаксиала (Teflon), а не подложки:
#     Z0 = 60/sqrt(eps) * ln(b/a)  =>  b = a * exp(Z0*sqrt(eps)/60)
import math
coax_eps    = 2.1                                            # Teflon
Z0_coax     = 50.0
coax_b      = via_r * math.exp(Z0_coax * math.sqrt(coax_eps) / 60.0)  # ~1.673 мм
coax_shield = 0.3                                            # мм, толщина экрана
coax_len    = 3.0                                            # мм, длина коаксиала ниже земли
port_margin = coax_b + coax_shield + 0.2                     # запас грани порта за экран

# ВАЖНО (по итогам сверки с openEMS AddCoaxialPort):
# ReferencePlaneDistance = "0" — плоскость отсчёта S-параметров остаётся ТАМ,
# где физически стоит порт (z = -coax_len). Прежнее значение "-coax_len"
# де-эмбеддировало опорную плоскость лишний раз и было признано ошибочным.
# Если нужно перенести отсчёт к плоскости земли — ставьте "{coax_len}".
#ref_plane_distance = "3.0"
ref_plane_distance = f"{-coax_len}"     # = "-3.0"
# ---------------------------------------------------------------------------
# 2. ТАБЛИЦА ВАРИАНТОВ (1:1 со switch ANTENNA_OPTION в MATLAB)
# ---------------------------------------------------------------------------
ANTENNA_TABLE = {
    1: dict(Lx=15.6, Wy=20.1, feed_x=-3.6, feed_y=0.0,
            USE_SLOT=False, USE_GAP=False, dx=0.00, dy=0.00),
    2: dict(Lx=17.60, Wy=32.00, feed_x=-6.00, feed_y=0.0,
            USE_SLOT=True,  USE_GAP=False, dx=2.40, dy=18.00),
    3: dict(Lx=17.6, Wy=33, feed_x=-6.70, feed_y=0.0,
            USE_SLOT=True,  USE_GAP=True,  dx=2.75, dy=21.70),
}


def resolve_geometry(option):
    """Разворачивает вариант в полный набор производных размеров."""
    if option not in ANTENNA_TABLE:
        raise ValueError("ANTENNA_OPTION должен быть 1, 2 или 3")

    g = dict(ANTENNA_TABLE[option])
    g["option"] = option

    # Земля / подложка: Gnd_SizeX = Lx + 6h, Gnd_SizeY = Wy + 6h (как в MATLAB)
    g["gnd_x"] = g["Lx"] + 6 * h_sub
    g["gnd_y"] = g["Wy"] + 6 * h_sub

    # Y-координата центра щелей в земле (симметрично сверху и снизу патча)
    g["gnd_slot_y"] = g["Wy"] / 2.0 + gnd_slot_gap + gnd_slot_width / 2.0

    return g


def print_geometry(g):
    print("\n" + "=" * 62)
    print(f"=== ANTENNA_OPTION = {g['option']} ===")
    print(f"    Lx = {g['Lx']:.2f} мм, Wy = {g['Wy']:.2f} мм, "
          f"Feed X = {g['feed_x']:.3f} мм")
    print(f"    Земля/подложка: {g['gnd_x']:.2f} x {g['gnd_y']:.2f} мм "
          f"(Lx+6h, Wy+6h)")
    print(f"    USE_SLOT (вырез в патче) = {int(g['USE_SLOT'])}")
    print(f"    USE_GAP  (щели в земле)  = {int(g['USE_GAP'])}")
    if g["USE_SLOT"]:
        print(f"      dx = {g['dx']:.2f} мм, dy = {g['dy']:.2f} мм "
              f"(у правой кромки патча)")
    if g["USE_GAP"]:
        print(f"      gap = {gnd_slot_gap:.2f} мм, w = {gnd_slot_width:.2f} мм, "
              f"L = {gnd_slot_length:.2f} мм")
        print(f"      Y-центр щелей = +/-{g['gnd_slot_y']:.3f} мм")
    print(f"    Коакс: pin_d = {pin_d:.2f} мм, коакс. диэлектрик b = "
          f"{coax_b:.3f} мм, len = {coax_len:.2f} мм")
    print("=" * 62)


# ---------------------------------------------------------------------------
# 3. ПОСТРОЕНИЕ ОДНОГО ВАРИАНТА
# ---------------------------------------------------------------------------
def build_antenna(project, g):
    modeler = project.model3d
    opt = g["option"]
    Lx, Wy = g["Lx"], g["Wy"]
    gnd_x, gnd_y = g["gnd_x"], g["gnd_y"]
    feed_x, feed_y = g["feed_x"], g["feed_y"]

    # --- 3.1 Единицы и частота --------------------------------------------
    modeler.add_to_history("set units",
        '''
        With Units
            .Geometry "mm"
            .Frequency "GHz"
            .Time "ns"
        End With
        ''')

    modeler.add_to_history("set frequency range",
        f'''
        Solver.FrequencyRange "{f_min}", "{f_max}"
        ''')

    # --- 3.2 Материалы -----------------------------------------------------
    modeler.add_to_history("define material RT5880",
        f'''
        With Material
            .Reset
            .Name "RT5880"
            .Folder ""
            .Type "Normal"
            .Epsilon "{eps_r}"
            .Mu "1.0"
            .TanD "{tan_d}"
            .TanDFreq "10"
            .Colour "0.6", "0.8", "0.4"
            .Transparency "0"
            .Create
        End With
        ''')

    modeler.add_to_history("define material Teflon",
        f'''
        With Material
            .Reset
            .Name "Teflon"
            .Folder ""
            .Type "Normal"
            .Epsilon "{coax_eps}"
            .Mu "1.0"
            .TanD "0.0002"
            .TanDFreq "10"
            .Colour "0.9", "0.9", "0.7"
            .Transparency "0.3"
            .Create
        End With
        ''')

    # --- 3.3 Подложка ------------------------------------------------------
    modeler.add_to_history("define substrate",
        f'''
        With Brick
            .Reset
            .Name "Substrate"
            .Component "component1"
            .Material "RT5880"
            .Xrange "{-gnd_x/2}", "{gnd_x/2}"
            .Yrange "{-gnd_y/2}", "{gnd_y/2}"
            .Zrange "0", "{h_sub}"
            .Create
        End With
        ''')

    # --- 3.4 Земля ---------------------------------------------------------
    modeler.add_to_history("define ground",
        f'''
        With Brick
            .Reset
            .Name "Ground"
            .Component "component2"
            .Material "PEC"
            .Xrange "{-gnd_x/2}", "{gnd_x/2}"
            .Yrange "{-gnd_y/2}", "{gnd_y/2}"
            .Zrange "0", "0"
            .Create
        End With
        ''')

    # --- 3.5 Щели в земле (только Antenna 3) -------------------------------
    if g["USE_GAP"]:
        ys = g["gnd_slot_y"]
        for tag, yc in (("Top", ys), ("Bot", -ys)):
            modeler.add_to_history(f"cut ground slot {tag}",
                f'''
                With Brick
                    .Reset
                    .Name "GndSlot{tag}"
                    .Component "component2"
                    .Material "Vacuum"
                    .Xrange "{-gnd_slot_length/2}", "{gnd_slot_length/2}"
                    .Yrange "{yc - gnd_slot_width/2}", "{yc + gnd_slot_width/2}"
                    .Zrange "-0.01", "0.01"
                    .Create
                End With
                Solid.Subtract "component2:Ground", "component2:GndSlot{tag}"
                ''')

    # --- 3.6 Отверстие (antipad) под коаксиал ------------------------------
    modeler.add_to_history("cut hole in ground",
        f'''
        With Cylinder
            .Reset
            .Name "GroundHole"
            .Component "component2"
            .Material "Vacuum"
            .OuterRadius "{coax_b}"
            .InnerRadius "0"
            .Axis "z"
            .Zrange "-0.01", "0.01"
            .Xcenter "{feed_x}"
            .Ycenter "{feed_y}"
            .Segments "0"
            .Create
        End With
        Solid.Subtract "component2:Ground", "component2:GroundHole"
        ''')

    # --- 3.7 Патч ----------------------------------------------------------
    modeler.add_to_history("define patch",
        f'''
        With Brick
            .Reset
            .Name "Patch"
            .Component "component3"
            .Material "PEC"
            .Xrange "{-Lx/2}", "{Lx/2}"
            .Yrange "{-Wy/2}", "{Wy/2}"
            '.Zrange "{h_sub}", "{h_sub + t_metal}"
            .Zrange "{h_sub}", "{h_sub}"
            .Create
        End With
        ''')

    # --- 3.8 Вырез с края патча (Antenna 2 и 3) ----------------------------
    if g["USE_SLOT"]:
        dx, dy = g["dx"], g["dy"]
        modeler.add_to_history("define patch slot",
            f'''
            With Brick
                .Reset
                .Name "Slot"
                .Component "component3"
                .Material "Vacuum"
                .Xrange "{Lx/2 - dx}", "{Lx/2}"
                .Yrange "{-dy/2}", "{dy/2}"
                '.Zrange "{h_sub}", "{h_sub + t_metal}"
                '.Zrange "{h_sub}", "{h_sub}"
                .Zrange "{h_sub - 0.01}", "{h_sub + 0.01}"
                .Create
            End With
            Solid.Subtract "component3:Patch", "component3:Slot"
            ''')

    # --- 3.9 Коаксиальный зонд --------------------------------------------
    modeler.add_to_history("define coax dielectric",
        f'''
        With Cylinder
            .Reset
            .Name "CoaxDielectric"
            .Component "component4"
            .Material "Teflon"
            .OuterRadius "{coax_b}"
            .InnerRadius "{via_r}"
            .Axis "z"
            .Zrange "{-coax_len}", "0"
            .Xcenter "{feed_x}"
            .Ycenter "{feed_y}"
            .Segments "0"
            .Create
        End With
        ''')

    modeler.add_to_history("define coax outer",
        f'''
        With Cylinder
            .Reset
            .Name "CoaxOuter"
            .Component "component4"
            .Material "PEC"
            .OuterRadius "{coax_b + coax_shield}"
            .InnerRadius "{coax_b}"
            .Axis "z"
            .Zrange "{-coax_len}", "0"
            .Xcenter "{feed_x}"
            .Ycenter "{feed_y}"
            .Segments "0"
            .Create
        End With
        ''')

    # Pin от низа коаксиала (Z = -coax_len) до нижней грани патча (Z = h_sub);
    # электрический контакт с металлом патча — по касанию граней.
    modeler.add_to_history("define pin",
        f'''
        With Cylinder
            .Reset
            .Name "Pin"
            .Component "component4"
            .Material "PEC"
            .OuterRadius "{via_r}"
            .InnerRadius "0"
            .Axis "z"
            .Zrange "{-coax_len}", "{h_sub}"
            .Xcenter "{feed_x}"
            .Ycenter "{feed_y}"
            .Segments "0"
            .Create
        End With
        ''')

    # --- 3.10 Waveguide Port ----------------------------------------------
    modeler.add_to_history("define waveguide port by coordinates",
        f'''
        With Port
            .Reset
            .PortNumber "1"
            .Label ""
            .Folder ""
            .NumberOfModes "1"
            .AdjustPolarization "False"
            .PolarizationAngle "0.0"
            .ReferencePlaneDistance "{ref_plane_distance}"
            .TextSize "50"
            .TextMaxLimit "1"
            .Coordinates "Free"
            .Orientation "zmin"
            .PortOnBound "False"
            .ClipPickedPortToBound "False"
            .Xrange "{feed_x - port_margin}", "{feed_x + port_margin}"
            .Yrange "{feed_y - port_margin}", "{feed_y + port_margin}"
            .Zrange "{-coax_len}", "{-coax_len}"
            .XrangeAdd "0.0", "0.0"
            .YrangeAdd "0.0", "0.0"
            .ZrangeAdd "0.0", "0.0"
            .SingleEnded "False"
            .WaveguideMonitor "False"
            .Create
        End With
        ''')

    # --- 3.11 Границы ------------------------------------------------------
    modeler.add_to_history("define boundaries",
        '''
        With Boundary
            .Xmin "expanded open"
            .Xmax "expanded open"
            .Ymin "expanded open"
            .Ymax "expanded open"
            .Zmin "expanded open"
            .Zmax "expanded open"
        End With
        ''')

    # --- 3.12 Монитор дальнего поля ---------------------------------------
    # Имя без символов ~[]:,|*/\$"^ — иначе CST отвергает его как невалидное.
    modeler.add_to_history("define farfield monitor",
        f'''
        With Monitor
            .Reset
            .Name "farfield_{str(f_rad).replace(".", "p")}GHz"
            .Domain "Frequency"
            .FieldType "Farfield"
            .Frequency "{f_rad}"
            .ExportFarfieldSource "False"
            .Create
        End With
        ''')

    # --- 3.13 Сохранение ---------------------------------------------------
    save_path = rf"{SAVE_DIR}\SST_Antenna{opt}_Coax_WGport.cst"
    project.save(path=save_path, allow_overwrite=True)
    print(f"[Antenna {opt}] проект сохранён: {save_path}")
    return save_path


# ---------------------------------------------------------------------------
# 4. ГЛАВНЫЙ ЦИКЛ
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    de = cst.interface.DesignEnvironment.new()

    saved = []
    for opt in OPTIONS_TO_BUILD:
        geo = resolve_geometry(opt)
        print_geometry(geo)
        prj = de.new_mws()
        saved.append(build_antenna(prj, geo))

    print("\nПостроено проектов: %d" % len(saved))
    print("Дальнейшие шаги (для каждого проекта):")
    print("1. Переключите солвер на Frequency Domain вручную")
    print("   (Home -> Simulation -> Solver) — ChangeSolverType скриптом")
    print("   в CST 2024 не срабатывает.")
    print("2. Запустите расчёт (Start Simulation)")
    print("3. Сравните S11 / Smith chart с MATLAB (тот же ANTENNA_OPTION)")
    print("4. При необходимости экспортируйте S11 через File -> Export -> ASCII")

# --- Экспорт S11 (раскомментировать ТОЛЬКО после успешного расчёта) --------
# modeler.add_to_history("export S11",
#     '''
#     SelectTreeItem "1D Results\\S-Parameters\\S1,1"
#     With ASCIIExport
#         .Reset
#         .FileName "S11_export.txt"
#         .Mode "ASCII"
#         .Execute
#     End With
#     ''')
