# Kodiak SoC co-sim: kodiak_soc (../rtl) + the superdupersparc core (the
# ../superdupersparc submodule) + kodiak_tb.cc, a copy of superdupersparc's
# top.cc.  The golden ISS and the not-yet-RTL sun4m devices (ss10sim's C++
# models) are compiled from the submodule.
#
#   make            -> kodiak_tb
#   make clean
UNAME_S = $(shell uname -s)

SDS = ../superdupersparc
RTL = ../rtl

DEV_OBJ = sun4m.o esp.o scsi.o lance.o dbri.o tcx.o cg14.o
OBJ = kodiak_tb.o verilated.o verilated_vcd_c.o loadelf.o interpret.o $(DEV_OBJ) disassemble.o helper.o sparse_mem.o ckpt.o

SV_SRC = $(wildcard $(RTL)/*.sv) $(wildcard $(SDS)/*.sv) $(wildcard $(SDS)/*.vh)

ifeq ($(UNAME_S),Linux)
	CXX = clang++-16 -flto
	MAKE = make
	VERILATOR_ROOT_DIR = /home/dsheffie/local/share/verilator
	VERILATOR = /home/dsheffie/local/bin/verilator
	EXTRA_LD = -lcapstone -lboost_program_options -lboost_serialization
endif

VERILATOR_SRC = $(VERILATOR_ROOT_DIR)/include/verilated.cpp
VERILATOR_VCD = $(VERILATOR_ROOT_DIR)/include/verilated_vcd_c.cpp
VERILATOR_INC = $(VERILATOR_ROOT_DIR)/include
VERILATOR_DPI_INC = $(VERILATOR_ROOT_DIR)/include/vltstd/

OPT = -O3 -g -std=c++14
CXXFLAGS = -std=c++11 -g $(OPT) -I. -I$(SDS) -I$(VERILATOR_INC) -I$(VERILATOR_DPI_INC) -I../arm -I../ultra96v2_driver
LIBS = $(EXTRA_LD) -lpthread

# STORE_CHECK=1: the co-sim store check (l1d.sv wr_log vs the ISS's store stream)
ifeq ($(STORE_CHECK),1)
CXXFLAGS += -DSTORE_CHECK
VFLAGS_EXTRA += +define+ENABLE_STORE_CHECK
endif

$(filter-out verilated.o verilated_vcd_c.o,$(OBJ)): $(SDS)/machine.vh

DEP = $(OBJ:.o=.d)

EXE = kodiak_tb

.PHONY : all clean
.DEFAULT_GOAL := all

all: $(EXE)

$(EXE) : $(OBJ) obj_dir/Vkodiak_soc__ALL.a
	$(CXX) $(CXXFLAGS) $(OBJ) obj_dir/*.o $(LIBS) -o $(EXE)

kodiak_tb.o: kodiak_tb.cc obj_dir/Vkodiak_soc__ALL.a
	$(CXX) -MMD $(CXXFLAGS) -Iobj_dir -c $<

verilated.o: $(VERILATOR_SRC)
	$(CXX) -MMD $(CXXFLAGS) -c $<

verilated_vcd_c.o: $(VERILATOR_VCD)
	$(CXX) -MMD $(CXXFLAGS) -c $<

%.o: $(SDS)/%.cc
	$(CXX) -MMD $(CXXFLAGS) -c $<

obj_dir/Vkodiak_soc__ALL.a : $(SV_SRC)
	$(VERILATOR) -cc $(RTL)/kodiak_soc.sv -y $(RTL) -y $(SDS) +incdir+$(SDS) --top-module kodiak_soc +define+PIPETRACE +define+ENABLE_TLB_MIRROR $(VFLAGS_EXTRA)
	$(MAKE) OPT_FAST="-O3 -flto" -C obj_dir -f Vkodiak_soc.mk

-include $(DEP)

clean:
	rm -rf $(EXE) $(OBJ) $(DEP) obj_dir
