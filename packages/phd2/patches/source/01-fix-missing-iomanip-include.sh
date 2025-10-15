#!/bin/bash
# Add missing <iomanip> include to fix compilation error
FILE="contributions/MPI_IS_gaussian_process/tests/gaussian_process/gp_guider_test.cpp"
sed -i '/^#include <iostream>/a #include <iomanip>' "$FILE"
echo "[patch-sh] Added #include <iomanip> to $FILE"
