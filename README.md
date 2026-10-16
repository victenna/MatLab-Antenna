# Patch Antenna Options — MATLAB / openEMS / CST

Three scripts model **the same three variants** of a coax-probe-fed microstrip patch antenna for the **5.9 GHz V2X band**, each in a different electromagnetic solver:

| File | Solver | Method |
|---|---|---|
| `Patch_Options_MatLab.m` | MATLAB Antenna Toolbox + RF PCB Toolbox | MoM (Method of Moments) |
| `Patch_Options_OpenEMS.m` | openEMS (via MATLAB interface) | FDTD |
| `Patch_Options_CST.py` | CST Studio Suite 2024 (Python API) | model build for the Frequency Domain solver |

Geometry, substrate and feed parameters are consistent across all three files, so the results (S11, VSWR, input impedance, Smith chart) can be compared directly between solvers.

> Code comments and console output are in Russian.

---

## Antenna variants

The variant is selected by a single variable at the top of each file:

- MATLAB / openEMS: `ANTENNA_OPTION = 1 | 2 | 3`
- CST: `OPTIONS_TO_BUILD = [3]` (or `[1, 2, 3]` — each variant in a separate project)

| Variant | Patch Lx × Wy, mm | Feed point X, mm | Edge notch in patch (dx × dy, mm) | Ground-plane slots |
|---|---|---|---|---|
| **1** — reference | 15.6 × 20.1 | −3.6 | none | none |
| **2** | 17.6 × 32.0 | −6.0 | 2.40 × 18.0 | none |
| **3** | 17.6 × 32.8 | −6.7 | 2.75 × 21.7 | 2 slots |

**Common parameters:**

- Substrate Rogers RT5880: εr = 2.2, tan δ = 0.0009, h = 1.57 mm
- Ground plane and substrate: (Lx + 6h) × (Wy + 6h)
- Feed point on the symmetry axis (Y = 0)
- Patch notch — a rectangle of depth `dx` at the right edge (along X) and length `dy` (along Y), centered in Y
- Ground-plane slots (variant 3 only): length 24 mm (along X), width 3.5 mm (along Y), offset from the patch edge −0.5 mm; placed symmetrically above and below the patch, Y-center = ±(Wy/2 − 0.5 + 1.75) mm
- Center conductor (pin): diameter 1.0 mm

Coordinate system: patch centered at the origin, ground plane at z = 0, patch at z = h.

---

## 1. `Patch_Options_MatLab.m` — MATLAB (MoM)

### Requirements
- MATLAB R2024b or later
- Antenna Toolbox, RF PCB Toolbox (`pcbStack`, `CoaxialFeed`), RF Toolbox (`sparameters`, `rfparam`, `smithplot`)

### How it works
1. **Geometry.** Patch, notch and ground plane are built from `antenna.Rectangle` shapes with Boolean operations (`patch - slot`, `gnd - slot_top - slot_bot`).
2. **Coaxial feed.** Defined with `CoaxialFeed` using a pad and an antipad in the ground plane. The antipad diameter follows from the Z0 = 50 Ω condition: `D = d · exp(Z0·√εr / 60)`.
3. **Assembly.** `pcbStack` with three layers `{patch, substrate, ground}`, `FeedFormat = 'FeedDefinitions'`, copper conductor.
4. **Mesh.** `mesh` with `MaxEdgeLength = 2 mm`, `MinEdgeLength = 0.5 mm`; a top view is displayed.
5. **S-parameters, adaptive:**
   - coarse pass on `linspace(5.2, 6.4 GHz, 11)`;
   - detection of intervals where VSWR crosses 2;
   - `M = 4` extra points are computed inside each such interval, so band edges are found accurately without a dense uniform sweep.
6. **Smoothing.** Spline interpolation of S11 onto 400 points for smooth plots. The bandwidth is read from this interpolated curve, which is built on the actually computed points.
7. **Plots:** VSWR with the VSWR ≤ 2 band highlighted and a parameter table, input impedance R/X, Smith chart with a 5.9 GHz marker.
8. **Radiation pattern (5.9 GHz):** 3D pattern, E-plane (φ = 0°) and H-plane (φ = 90°) cuts in dB, E-plane gain table at 0°, 30°, 60°, 70°, 80°, 85° from broadside. These sections are wrapped in `try/catch`: if a function is not supported for this feed configuration, the script prints a message and continues.

### What to change
- `ANTENNA_OPTION` — antenna variant
- `freqs` — coarse-pass frequency grid (number of points directly affects run time)
- `M` — number of refinement points inside each VSWR = 2 crossing interval
- `a1`, `a2` — maximum and minimum mesh edge length
- `f_rad` — frequency for the radiation pattern

### Output
- `Documents\VSWR_Antenna<N>_MatLab.csv` — frequency (GHz) and VSWR (first line is the script name)
- MATLAB figures (mesh, VSWR, impedance, Smith chart, patterns)

---

## 2. `Patch_Options_OpenEMS.m` — openEMS (FDTD)

### Requirements
- [openEMS](https://www.openems.de/) and CSXCAD with the MATLAB interface (their `matlab` folders must be on the MATLAB `path`)
- RF Toolbox (for `sparameters`, `smithplot`)

### How it works
1. **CSX geometry.** Patch and ground are zero-thickness metals (`AddMetal`). The patch notch and ground slots are implemented through **priorities**: an "air" box with priority 20 overrides metal with priority 10 — the equivalent of a Boolean subtraction.
2. **Substrate loss.** tan δ is converted to conductivity: `κ = 2π·f0·ε0·εr·tan δ`.
3. **Coaxial port.** A 3 mm coaxial section below the ground plane (`AddCoaxialPort`) with Teflon filling (εr = 2.1); outer dielectric radius from the Z0 = 50 Ω condition. A via pin connects the center conductor to the patch.
   - The antipad in the ground plane has priority 11 — strictly between ground (10) and pin/port (12), so the air does not break the pin at z = 0.
4. **Mesh.** Local refinement around the pin and coax, explicit lines on notch and slot edges, then `DetectEdges` + `SmoothMesh` (λ/40 at fmax). Inside the port the Z step is forced to be **uniform** (required by the port calculation).
5. **Excitation and boundaries.** Gaussian pulse f0 = 5.9 GHz, fc = 1.5 GHz; PML_8 on all faces; simulation box 150 × 150 × 120 mm; `NrTs = 300000`, `EndCriteria = 1e-4`. The large `NrTs` is needed for variants 2 and 3: the signal decays slowly, and early truncation produces spurious ripple in S11.
6. **Simulation** runs in `tempdir\tmp_Patch_Ant_Coax_Opt<N>`.
7. **Post-processing** on `linspace(5.2, 6.2 GHz, 101)`: S11 (dB) with the resonance marked, Smith chart, VSWR, input impedance.

> An NF2FF box is created, but the far field is not computed in this script — it can be added with `CalcNF2FF`.

### What to change
- `ANTENNA_OPTION` — antenna variant
- `SimBox` — simulation domain size
- `NrTs`, `EndCriteria` — simulation length
- `SmoothMesh(..., c0/(f0+fc)/unit/40, ...)` — mesh density (λ/40)
- `freq` — post-processing frequency grid

### Output
- `Documents\VSWR_Antenna<N>_OpenEMS.csv` — columns `Freq_GHz, S11_dB, VSWR, ReZin_Ohm, ImZin_Ohm`
- `S11_sparams.mat` in the simulation folder
- Console: resonant frequency, S11min, Zin, minimum VSWR

---

## 3. `Patch_Options_CST.py` — CST Studio Suite (Python)

### Requirements
- CST Studio Suite 2024 with the Python API (`cst.interface`)
- Run with `python.bat` from the CST installation or from the CST ipython console

### How it works
The script **builds the model** but does not run the simulation. For each variant in `OPTIONS_TO_BUILD`:

1. Opens the CST Design Environment and creates a new MWS project.
2. Through `add_to_history` (VBA commands) it defines:
   - units (mm, GHz, ns) and the 5.4–6.4 GHz range;
   - materials RT5880 and Teflon;
   - substrate, ground plane (PEC, zero thickness), ground slots (variant 3) and antipad — via `Solid.Subtract`;
   - patch (PEC, zero thickness) and edge notch (variants 2 and 3);
   - coax: Teflon dielectric, 0.3 mm PEC shield, pin from the bottom of the coax up to the patch;
   - **Waveguide Port** at the bottom end of the coax (z = −3 mm);
   - `expanded open` boundaries on all faces;
   - far-field monitor at 5.9 GHz.
3. Saves the project: `SAVE_DIR\SST_Antenna<N>_Coax_WGport.cst`.

### After running the script (manually in CST)
1. Switch the solver to **Frequency Domain** (Home → Simulation → Solver) — changing the solver from a script does not work in CST 2024.
2. Start the simulation (Start Simulation).
3. Compare S11 / Smith chart with MATLAB and openEMS for the same variant.
4. If needed, export S11: File → Export → ASCII.

### What to change
- `OPTIONS_TO_BUILD` — which variants to build
- `SAVE_DIR` — folder for saved projects
- `ANTENNA_TABLE` — variant dimensions
- `ref_plane_distance` — S-parameter reference plane position relative to the port
- `f_min`, `f_max`, `f_rad` — frequency range and far-field monitor frequency

---

## Feed model differences

The models are consistent but not identical — keep this in mind when comparing results:

| | MATLAB | openEMS | CST |
|---|---|---|---|
| Feed | `CoaxialFeed` (pad/antipad in ground) | 3 mm coaxial port below ground | physical 3 mm coax + Waveguide Port |
| εr used for 50 Ω sizing | 2.2 (substrate) | 2.1 (Teflon) | 2.1 (Teflon) |
| Metal | copper | PEC, zero thickness | PEC, zero thickness |
| Frequency range | 5.2–6.4 GHz | 5.2–6.2 GHz | 5.4–6.4 GHz |

---

## Quick start

```
1. Select the variant:   ANTENNA_OPTION = 3      (MATLAB, openEMS)
                         OPTIONS_TO_BUILD = [3]  (CST)
2. MATLAB:   run Patch_Options_MatLab.m
3. openEMS:  run Patch_Options_OpenEMS.m
4. CST:      python.bat Patch_Options_CST.py  → Frequency Domain → Start Simulation
5. Compare the CSV files VSWR_Antenna3_*.csv in the Documents folder
```

## Author
Vittorio Rabinovich — Toronto, Canada
