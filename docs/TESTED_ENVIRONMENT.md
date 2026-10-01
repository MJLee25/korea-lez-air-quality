# Environment notes

Original full-estimation environment: `OnlineResource2/monthly_results/sessionInfo.txt`.
Current tested public environment: Windows, R 4.6.0, dplyr 1.2.1, ggplot2 4.0.3,
sf 1.1-3, spdep 1.4-2. The fresh baseline model used splm 1.6-5.

The dependency installer obtains currently available packages and is not a
bit-for-bit lockfile. For exact historical bootstrap comparisons, reproduce the
original session versions (especially did 2.3.0), and compare aggregate outputs
before replacing published reference results. No original fitted model objects
or bootstrap influence-function arrays containing observations are distributed.
