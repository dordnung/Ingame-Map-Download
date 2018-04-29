# -----------------------------------------------------
# File        Makefile
# Authors     David Ordnung
# License     GPLv3
# Web         http://dordnung.de
# -----------------------------------------------------
# 
# Gamebanana Maplister Makefile
# Copyright (C) 2013-2017 David Ordnung
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

INCLUDE += -I./ -I$(JSON) -I$(SQLITE3)

LDLIBS = $(shell curl-config --libs) -lm -ldl -lpthread -lrt -m32

CFLAGS += -O3 -funroll-loops -Wall -pipe -pthread -msse -DNDEBUG -m32
CPPFLAGS += -O3 -funroll-loops -Wall -pipe -std=c++0x -pthread -msse -fpermissive -DNDEBUG -Wno-deprecated -Wno-write-strings $(shell curl-config --cflags) -m32

OBJ_BIN_C := $(OBJECTS_C:%.c=%.o)
OBJ_BIN_CPP := $(OBJECTS_CPP:%.cpp=%.o)

.PHONY: default all clean

default: all
all: sqlite3 to_prog

%.o: %.c
	$(C) $(INCLUDE) $(CFLAGS) -o $@ -c $<
	
%.o: %.cpp
	$(CPP) $(INCLUDE) $(CPPFLAGS) -o $@ -c $<
	
sqlite3: $(OBJ_BIN_C)

to_prog: $(OBJ_BIN_CPP)
	$(CPP) $(INCLUDE) $(OBJ_BIN_C) $(OBJ_BIN_CPP) $(LDLIBS) -o $(BINARY)

clean:
	rm -f main.o
	rm -f json/*.o
	rm -f sqlite3/*.o
	rm -f $(BINARY)