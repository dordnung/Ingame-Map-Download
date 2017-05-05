/*
 * -----------------------------------------------------
 * File        main.h
 * Authors     David <popoklopsi> Ordnung
 * License     GPLv3
 * Web         http://popoklopsi.de
 * -----------------------------------------------------
 *
 * Gamebanana Maplister
 * Copyright (C) 2012-2015 David <popoklopsi> Ordnung
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>
 */

#include <stdlib.h>
#include <cstdlib>
#include <sstream>
#include <iostream>
#include <string>
#include <string.h>
#include <vector>
#include <thread>
#include <mutex>
#include <ctime>
#include <curl/curl.h>
#include <sqlite3.h>
#include "json/json.h"


// Sleeping for different OSs
#ifdef _WIN32
#include <windows.h>
#define Sleeping(seconds) Sleep(seconds*1000);
#else
#include <unistd.h>
#define Sleeping(seconds) sleep(seconds);
#endif

// Using std
using namespace std;


// Thread for Curl Performances
typedef bool(*callback)(char*, string, string, string, int);

// Main Methods
bool OnGotMainPage(char *error, string result, string url, string data, int errorCount);
bool OnGotMapsPage(char *error, string result, string url, string data, int errorCount);
bool OnGotMapDetails(char *error, string result, string url, string data, int errorCount);
bool OnGotCategorieDetails(char *error, string result, string url, string data, int errorCount);

// Print current status
void printStatus();

// Int to game and game to id
int getGameFromChoice(int arg);
string getGameFromId(int id);

// Curl
void getPage(callback function, string page, string data, bool threading, int errorCount);
void getPageThread(callback function, string page, string data, int errorCount);

size_t write_data(void *buffer, size_t size, size_t nmemb, void *userp);


// SQLite 3
void insertCategorie(string id, string name);
void insertMap(string id, string categorie, string date, string mdate, string downloads, string name, string rating, string votes, string views, string download, string size);


// String operations
void replaceString(string &str, const string& oldStr, const string& newStr);
vector<std::string> splitString(const string &str, const string& search, const string& to = "");