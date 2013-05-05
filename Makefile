# -----------------------------------------------------
# File        Makefile
# Authors     David <popoklopsi> Ordnung
# License     GPLv3
# Web         http://popoklopsi.de
# -----------------------------------------------------
# 
# Gamebanana Maplister Makefile
# Copyright (C) 2012-2013 David <popoklopsi> Ordnung
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

CPP = g++
CURL = ../curl/
SQLITE3 = ../sqlite3/
OPENSSL = ../openssl

BINARY = gamebanana.bin


OBJECTS += main.cpp
BIN_DIR = .

INCLUDE += -I./ -I$(CURL) -I$(SQLITE3)

LINK = $(CURL)libcurl.a $(OPENSSL)/libssl.a $(OPENSSL)/libcrypto.a $(SQLITE3)libsqlite3.a -lm -ldl -lrt -m32

CFLAGS += -O3 -funroll-loops -Wall -pipe -std=c++0x -pthread -msse -m32 -fpermissive -D_LINUX -DLINUX -DCURL_STATICLIB -DPOSIX -DCOMPILER_GCC -DNDEBUG -Dstricmp=strcasecmp \
			-D_stricmp=strcasecmp -D_strnicmp=strncasecmp -Dstrnicmp=strncasecmp -D_snprintf=snprintf -D_vsnprintf=vsnprintf \
			-D_alloca=alloca -Dstrcmpi=strcasecmp -Wno-deprecated -Wno-sign-compare -Wno-write-strings -fno-strict-aliasing -msse -mtune=i686 -march=pentium -mmmx


OBJ_BIN := $(OBJECTS:%.cpp=%.o)

MAKEFILE_NAME := $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))

%.o: %.cpp
	$(CPP) $(INCLUDE) $(CFLAGS) -o $@ -c $<

all:
	$(MAKE) -f $(MAKEFILE_NAME) clean
	mkdir -p $(BIN_DIR)
	$(MAKE) -f $(MAKEFILE_NAME) to_prog
	$(MAKE) -f $(MAKEFILE_NAME) clean
	

to_prog: $(OBJ_BIN)
	$(CPP) $(INCLUDE) $(OBJ_BIN) $(LINK) -o $(BIN_DIR)/$(BINARY)

default: all

clean:
	rm -f main.o