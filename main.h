/*
 * -----------------------------------------------------
 * File        main.h
 * Authors     David <popoklopsi> Ordnung
 * License     GPLv3
 * Web         http://popoklopsi.de
 * -----------------------------------------------------
 * 
 * Gamebanana Maplister
 * Copyright (C) 2012-2013 David <popoklopsi> Ordnung
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

// c++ libs
// So much stuff ^^
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

// Curl
#include <curl/curl.h>

// Sqlite
#include <sqlite3.h>





// Sleeping
#ifdef _WIN32
	#define Sleeping(seconds) Sleep(seconds*1000);
#else
	#include <unistd.h>
	#define Sleeping(seconds) sleep(seconds);
#endif




// Using std
using namespace std;


// Thread for Curl Performances
typedef void (*callback)(char*, string, string, string, string);






// Main Methods
void OnGotMainPage(char *error, string result, string url, string data, string data2);
void OnGotMapsPage(char *error, string result, string url, string data, string data2);
void OnGotMapDownload(char *error, string result, string url, string data, string data2);
void OnGotCategorieDetails(char *error, string result, string url, string data, string data2);

// Print current status
void printStatus();

// Int to game
void getGame(int gameInt);



// Curl
void getPage(callback function, string page, string data, string data2);
void getPageMultiThread(callback function, string page, string data, string data2);
void getPageThread(callback function, string page, string data, string data2);

size_t write_data(void *buffer, size_t size, size_t nmemb, void *userp);




// SQLite 3
void insertCategorie(string name);
void insertMap(string categorie, string name, string link, string download, string size);



// String operations
void replaceString(string &str, const string& oldStr, const string& newStr);
vector<std::string> splitString(const string &str, const string& search, const string& to = "");