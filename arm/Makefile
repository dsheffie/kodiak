# kodiak_arm: the ARM side of Kodiak on the Ultra96-v2 (build on the board).
# The device models are superdupersparc's sun4m C++ (the submodule); the window
# protocol is win_service.h, shared with kodiak_tb.
SDS = ../superdupersparc
DRV = ../ultra96v2_driver
CXX ?= g++
OPT = -O2
CXXFLAGS = -std=c++17 -g $(OPT) -I. -I$(SDS) -I$(DRV) -MMD
LIBS = -lboost_program_options -lcapstone -pthread
ifdef WIN_STATS
CXXFLAGS += -DENABLE_WIN_STATS   # per-device window counters (kodiak_arm.cc)
endif
SDS_OBJ = sun4m.o esp.o scsi.o lance.o tcx.o cg14.o sparse_mem.o helper.o loadelf.o
OBJ = kodiak_arm.o driver.o $(SDS_OBJ)

kodiak_arm: $(OBJ)
	$(CXX) $(CXXFLAGS) $(OBJ) $(LIBS) -o $@

%.o: %.cc
	$(CXX) $(CXXFLAGS) -c $<
%.o: $(SDS)/%.cc
	$(CXX) $(CXXFLAGS) -c $<
%.o: $(DRV)/%.cc
	$(CXX) $(CXXFLAGS) -c $<

-include $(OBJ:.o=.d)

clean:
	rm -f kodiak_arm *.o *.d
