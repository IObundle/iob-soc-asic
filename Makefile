CORE := iob_soc_caravel
BOARD ?= AES-KU040-DB-G

# Disable Linter while rules are not finished
DISABLE_LINT:=1

#ifeq ($(TESTER),1)
#TOP_MODULE_NAME :=iob_soc_tester
#endif
ifneq ($(USE_EXTMEM),1)
$(warning WARNING: USE_EXTMEM must be set to support iob-soc-opencryptolinux and ethernet with DMA. Auto-adding USE_EXTMEM=1...)
USE_EXTMEM:=1
endif

LIB_DIR:=submodules/IOBSOC/submodules/LIB
include $(LIB_DIR)/setup.mk

CARAVEL_LIB := setup_scripts
PYTHON_EXEC:=/usr/bin/env python3 -B

INIT_MEM ?= 1
RUN_LINUX ?= 0

ifeq ($(INIT_MEM),1)
SETUP_ARGS += INIT_MEM
endif

ifeq ($(USE_EXTMEM),1)
SETUP_ARGS += USE_EXTMEM
endif

ifeq ($(TESTER_ONLY),1)
SETUP_ARGS += TESTER_ONLY
endif

ifeq ($(RUN_LINUX),1)
SETUP_ARGS += RUN_LINUX
endif

ifeq ($(NO_ILA),1)
SETUP_ARGS += NO_ILA
endif

setup:
	make build-setup SETUP_ARGS="$(SETUP_ARGS)"

setup_caravel: build_dir_name
	$(PYTHON_EXEC) $(CARAVEL_LIB)/caravel_setup.py $(BUILD_DIR)

pc-emul-run: build_dir_name
	make clean setup && make -C $(BUILD_DIR)/ pc-emul-run

sim-run: build_dir_name
	make clean setup && make -C $(BUILD_DIR)/ sim-run

fpga-run: build_dir_name
ifeq ($(USE_EXTMEM),1)
	echo "WARNING: INIT_MEM must be set to zero run on the FPGA with USE_EXTMEM=1. Auto-setting INIT_MEM=0..."
	nix-shell --run "make clean setup INIT_MEM=0"
else
	nix-shell --run "make clean setup"
endif
	nix-shell --run "make -C $(BUILD_DIR)/ fpga-fw-build"
	make -C $(BUILD_DIR)/ fpga-run

test-all: build_dir_name
	make clean setup && make -C $(BUILD_DIR)/ pc-emul-test
	#make sim-run SIMULATOR=icarus
	make sim-run SIMULATOR=verilator
	make fpga-run BOARD=CYCLONEV-GT-DK
	make fpga-run BOARD=AES-KU040-DB-G
	make clean setup && make -C $(BUILD_DIR)/ doc-test

.PHONY: pc-emul-run sim-run fpga-run

build-sut-netlist: build_dir_name
	make clean && make setup 
	# Rename constraint files
	#FPGA_DIR=`ls -d $(BUILD_DIR)/hardware/fpga/quartus/CYCLONEV-GT-DK` &&\
	#mv $$FPGA_DIR/iob_soc_sut_fpga_wrapper_dev.sdc $$FPGA_DIR/iob_soc_sut_dev.sdc
	#FPGA_DIR=`ls -d $(BUILD_DIR)/hardware/fpga/vivado/AES-KU040-DB-G` &&\
	#mv $$FPGA_DIR/iob_soc_sut_fpga_wrapper_dev.sdc $$FPGA_DIR/iob_soc_sut_dev.sdc
	# Build netlist 
	make -C $(BUILD_DIR)/ fpga-build BOARD=$(BOARD) IS_FPGA=0

tester-sut-netlist: build-sut-netlist
	#Build tester without sut sources, but with netlist instead
	TESTER_VER=`cat submodules/TESTER/iob_soc_tester_setup.py | grep version= | cut -d"'" -f2` &&\
	rm -fr ../iob_soc_tester_V* && make setup TESTER_ONLY=1 BUILD_DIR="../iob_soc_tester_$$TESTER_VER" &&\
	cp ../iob_soc_caravel_V*/hardware/fpga/iob_soc_sut_fpga_wrapper_netlist.v ../iob_soc_tester_$$TESTER_VER/hardware/fpga/iob_soc_sut.v &&\
	cp ../iob_soc_caravel_V*/hardware/fpga/iob_soc_sut_firmware.* ../iob_soc_tester_$$TESTER_VER/hardware/fpga/ &&\
	if [ -f ../iob_soc_caravel_V*/hardware/fpga/iob_soc_sut_stub.v ]; then cp ../iob_soc_caravel_V*/hardware/fpga/iob_soc_sut_stub.v ../iob_soc_tester_$$TESTER_VER/hardware/src/; fi &&\
	echo -e "\nIP+=iob_soc_sut.v" >> ../iob_soc_tester_$$TESTER_VER/hardware/fpga/fpga_build.mk &&\
	cp software/firmware/iob_soc_tester_firmware.c ../iob_soc_tester_$$TESTER_VER/software/firmware
	# Copy and modify iob_soc_sut_params.vh (needed for stub) and modify *_stub.v to insert the SUT parameters 
	TESTER_VER=`cat submodules/TESTER/iob_soc_tester_setup.py | grep version= | cut -d"'" -f2` &&\
	if [ -f ../iob_soc_caravel_V*/hardware/fpga/iob_soc_sut_stub.v ]; then\
		cp ../iob_soc_caravel_V0.70/hardware/src/iob_soc_sut_params.vh ../iob_soc_tester_$$TESTER_VER/hardware/src/;\
		sed -i -E 's/=[^,]*(,?)$$/=0\1/g' ../iob_soc_tester_$$TESTER_VER/hardware/src/iob_soc_sut_params.vh;\
		sed -i 's/_sut(/_sut#(\n`include "iob_soc_sut_params.vh"\n)(/g' ../iob_soc_tester_$$TESTER_VER/hardware/src/iob_soc_sut_stub.v;\
	fi
	# Run Tester on fpga
	TESTER_VER=`cat submodules/TESTER/iob_soc_tester_setup.py | grep version= | cut -d"'" -f2` &&\
	make -C ../iob_soc_tester_V*/ fpga-run BOARD=$(BOARD) | tee ../iob_soc_tester_$$TESTER_VER/test.log && grep "Verification successful!" ../iob_soc_tester_$$TESTER_VER/test.log > /dev/null

.PHONY: build-sut-netlist test-sut-netlist

# Target to create vcd file based on ila_data.bin generated by the ILA Tester peripheral
ila-vcd: build_dir_name
	# Create VCD file from simulation ila data
	if [ -f $(BUILD_DIR)/hardware/simulation/ila_data.bin ]; then \
		./$(BUILD_DIR)/./scripts/ilaDataToVCD.py ILA0 $(BUILD_DIR)/hardware/simulation/ila_data.bin ila_sim.vcd; fi
	# Create VCD file from fpga ila data
	if [ -f $(BUILD_DIR)/hardware/fpga/ila_data.bin ]; then \
		./$(BUILD_DIR)/./scripts/ilaDataToVCD.py ILA0 $(BUILD_DIR)/hardware/fpga/ila_data.bin ila_fpga.vcd; fi
	#gtkwave ./ila_sim.vcd
.PHONY: ila-vcd
