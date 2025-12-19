#!/bin/bash

# Verification script for Cyclic Peptide Screening Pipeline installation

echo "========================================="
echo "Installation Verification"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass=0
check_fail=0

# Function to check command
check_env() {
    env_name=$1
    test_cmd=$2

    echo -n "Checking $env_name... "

    if conda activate $env_name 2>/dev/null && eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        conda deactivate 2>/dev/null
        ((check_pass++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        conda deactivate 2>/dev/null
        ((check_fail++))
    fi
}

# Function to check module
check_module() {
    module_name=$1

    echo -n "Checking module $module_name... "

    if module load $module_name 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        module unload $module_name 2>/dev/null
        ((check_pass++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((check_fail++))
    fi
}

echo "1. Checking Conda Environments"
echo "--------------------------------"

check_env "fpocket_env" "fpocket --help"
check_env "boltz_env" "boltzgen --version"
check_env "SE3nv" "python --version"
check_env "rosetta_env" "rosetta_scripts --help"

echo ""
echo "2. Checking System Modules"
echo "--------------------------------"

check_module "pymol"
check_module "parallel"

echo ""
echo "3. Checking Scripts"
echo "--------------------------------"

echo -n "Checking master_pipeline.sh... "
if [ -x "./master_pipeline.sh" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((check_pass++))
else
    echo -e "${RED}✗ FAIL (not executable)${NC}"
    ((check_fail++))
fi

echo -n "Checking run_postprocessing.sh... "
if [ -x "./run_postprocessing.sh" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((check_pass++))
else
    echo -e "${RED}✗ FAIL (not executable)${NC}"
    ((check_fail++))
fi

echo -n "Checking hbond_analysis_nofail.xml... "
if [ -f "./hbond_analysis_nofail.xml" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((check_pass++))
else
    echo -e "${RED}✗ FAIL (missing)${NC}"
    ((check_fail++))
fi

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo -e "Passed: ${GREEN}$check_pass${NC}"
echo -e "Failed: ${RED}$check_fail${NC}"
echo ""

if [ $check_fail -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Installation complete.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Configure SLURM settings in master_pipeline.sh"
    echo "  2. Read EXAMPLE.md for usage examples"
    echo "  3. Run: ./master_pipeline.sh input.cif '14..20' 1"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. See INSTALL.md for troubleshooting.${NC}"
    echo ""
    echo "Common issues:"
    echo "  - Conda environments: conda env create -f environments/<env>.yml"
    echo "  - System modules: Contact your cluster administrator"
    echo "  - Scripts not executable: chmod +x *.sh"
    exit 1
fi
