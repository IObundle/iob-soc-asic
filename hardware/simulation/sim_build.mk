HEX+=iob_soc_sut_boot.hex iob_soc_sut_firmware.hex
include ../../software/sw_build.mk

VTOP:=iob_soc_sut_tb

# SOURCES
ifeq ($(SIMULATOR),verilator)

# get header files (needed for iob_soc_sut_tb.cpp)
VHDR+=iob_uart_swreg.h
iob_uart_swreg.h: ../../software/esrc/iob_uart_swreg.h
	cp $< $@

# verilator top module
VTOP:=iob_soc_sut_top

endif

TEST_LIST+=test1
test1:
	make -C ../../ fw-clean SIMULATOR=$(SIMULATOR) && make -C ../../ sim-clean SIMULATOR=$(SIMULATOR) && make run SIMULATOR=$(SIMULATOR) TEST_LOG="| tee -a test.log"
