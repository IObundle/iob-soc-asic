#Function to obtain parameter named $(1) in verilog header file located in $(2)
#Usage: $(call GET_MACRO,<param_name>,<vh_path>)
GET_MACRO = $(shell grep $(1) $(2) | rev | cut -d" " -f1 | rev)

#Function to obtain parameter named $(1) from iob_soc_sut_conf.vh
GET_SUT_CONF_MACRO = $(call GET_MACRO,IOB_SOC_SUT_$(1),../src/iob_soc_sut_conf.vh)

iob_soc_sut_boot.hex: ../../software/embedded/iob_soc_sut_boot.bin
	../../scripts/makehex.py $< $(call GET_SUT_CONF_MACRO,BOOTROM_ADDR_W) > $@

iob_soc_sut_firmware.hex: iob_soc_sut_firmware.bin
	../../scripts/makehex.py $< $(call GET_SUT_CONF_MACRO,SRAM_ADDR_W) > $@
	../../scripts/hex_split.py iob_soc_sut_firmware .

iob_soc_sut_firmware.bin: ../../software/embedded/iob_soc_sut_firmware.bin
	cp $< $@

../../software/embedded/%.bin:
	make -C ../../ fw-build
