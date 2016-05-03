# -----------------------------------------------------
# File        Makefile
# Authors     David <popoklopsi> Ordnung
# License     GPLv3
# Web         http://popoklopsi.de
# -----------------------------------------------------
# 
# Gamebanana Maplister Makefile
# Copyright (C) 2012-2014 David <popoklopsi> Ordnung
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>

C = gcc
CPP = g++
JSON = ./json
SQLITE3 = ./sqlite3

BINARY = gamebanana.bin

OBJECTS_C += $(SQLITE3)/sqlite3.c
OBJECTS_CPP += $(JSON)/json_value.cpp $(JSON)/json_reader.cpp $(JSON)/json_writer.cpp main.cpp
BIN_DIR = .

INCLUDE += -I./ -I$(JSON) -I$(SQLITE3)

LINK = -Wl,-Bstatic -lcurl -lssl -lcrypto -lz -Wl,-Bdynamic -lm -ldl -lpthread -lrt -m32

CFLAGS += -O3 -funroll-loops -Wall -pipe -pthread -msse -m32 -D_LINUX -DLINUX -DPOSIX -DCOMPILER_GCC -DNDEBUG
CPPFLAGS += -O3 -funroll-loops -Wall -pipe -std=c++0x -pthread -msse -m32 -fpermissive -D_LINUX -DLINUX -DCURL_STATICLIB -DPOSIX -DCOMPILER_GCC -DNDEBUG -Dstricmp=strcasecmp \
			-D_stricmp=strcasecmp -D_strnicmp=strncasecmp -Dstrnicmp=strncasecmp -D_snprintf=snprintf -D_vsnprintf=vsnprintf \
			-D_alloca=alloca -Dstrcmpi=strcasecmp -Wno-unused-but-set-variable -Wno-unused-variable -Wno-deprecated -Wno-sign-compare -Wno-write-strings -fno-strict-aliasing -msse -mtune=i686 -march=pentium -mmmx


OBJ_BIN_C := $(OBJECTS_C:%.c=%.o)
OBJ_BIN_CPP := $(OBJECTS_CPP:%.cpp=%.o)

MAKEFILE_NAME := $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))

%.o: %.c
	$(C) $(INCLUDE) $(CFLAGS) -o $@ -c $<
	
%.o: %.cpp
	$(CPP) $(INCLUDE) $(CPPFLAGS) -o $@ -c $<

all:
	$(MAKE) -f $(MAKEFILE_NAME) clean
	mkdir -p $(BIN_DIR)
	$(MAKE) -f $(MAKEFILE_NAME) sqlite3
	$(MAKE) -f $(MAKEFILE_NAME) to_prog
	$(MAKE) -f $(MAKEFILE_NAME) clean
	
sqlite3: $(OBJ_BIN_C)

to_prog: $(OBJ_BIN_CPP)
	$(CPP) $(INCLUDE) $(OBJ_BIN_C) $(OBJ_BIN_CPP) $(LINK) -o $(BIN_DIR)/$(BINARY)

default: all

clean:
	rm -f main.o
	rm -f json/*.o
	rm -f sqlite3/*.o