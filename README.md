# MatLab-Antenna
MATLAB scripts for designing a V2X patch antenna with extended bandwidth and matching optimization.
# MATLAB V2X Patch Antenna (Extended Bandwidth)

MATLAB scripts for designing a V2X patch antenna targeting extended bandwidth. The repository provides a repeatable workflow to explore antenna geometry, evaluate matching performance, and compare design variations efficiently.

## What’s included
- Defining antenna and substrate parameters (patch, ground plane, feed/network elements)
- Running parameter sweeps to study the influence of key dimensions
- Computing and visualizing performance metrics such as S11, impedance matching behavior, resonance characteristics, and bandwidth trends
- Example setups and configurable scripts so you can start from a baseline and adapt the design to your needs

## Design objective
A conventional patch antenna often has limited bandwidth. This repository targets wider operating bandwidth by enabling you to investigate design strategies and parameter choices that affect the antenna resonance and matching over frequency.

The scripts are structured so you can quickly test how changes in geometry and feed positioning (or coupling-related parameters) influence return loss and the usable frequency range.

## How to use
1. Clone this repository.
2. Open the main MATLAB scripts.
3. Update configuration parameters (substrate properties, antenna dimensions, sweep ranges).
4. Run simulations and review generated plots/results.

## Notes
Results may depend on your MATLAB version, installed toolboxes, and the simulation settings used in the scripts.

## Contributions
Feel free to open an issue or submit a pull request with improvements (new feeding/matching methods, additional parameter studies, etc.).
