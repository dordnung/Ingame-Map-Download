/*
 * -----------------------------------------------------
 * File        main.cpp
 * Authors     David Ordnung
 * License     GPLv3
 * Web         http://dordnung.de
 * -----------------------------------------------------
 *
 * Gamebanana Maplister
 * Copyright (C) 2012-2017 David Ordnung
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

#include "main.h"

// The game to list maps for
int currentGame = -1;

// Use threading?
bool threaded = false;
vector<thread*> runningThreads;

// Current statistics
volatile int allMaps = 0;
volatile int current = 0;
time_t startTime;

// Mutex
mutex threadMutex;

// Database
sqlite3 *db;


// Where all began :)
int main(int argc, const char *argv[]) {
	int choice = -1;
	int gameCount = 1;

	// Search for a game without asking?
	if (argc >= 2) {
		choice = atoi(argv[1]);

		if (choice > 0 && choice < 6) {
			cout << "INFO: Found game choice argument, searching maps only for " << getGameFromChoice(choice) << endl;
		} else if (choice == 6) {
			gameCount = 5;
			cout << "INFO: Found game choice argument, searching maps for all games" << endl;
		} else {
			choice = -1;
			cout << "WARNING: " << choice << " is an invalid game choice argument" << endl;
		}
	}

	// Use threading or not without asking?
	if (argc >= 3) {
		if (atoi(argv[2]) > 0) {
			threaded = true;
			cout << "INFO: Found thread argument. Using threads" << endl;
		} else {
			threaded = false;
			cout << "INFO: Found thread argument. Don't using threads" << endl;
		}
	}

	cout << endl << endl;

	// Ask for game to search maps for
	if (choice == -1) {
		do {
			cout << "Please choose a game to search maps for" << endl;
			cout << "-------------------------------------" << endl;
			cout << "1. Team Fortress 2" << endl;
			cout << "2. Day of Defeat: Source" << endl;
			cout << "3. Half-Life 2: Deathmatch" << endl;
			cout << "4. Counter-Strike: Source" << endl;
			cout << "5. Counter-Strike: Global Offensive" << endl;
			cout << "-------------------------------------" << endl;
			cout << "6. All Games" << endl;
			cout << "-------------------------------------" << endl;
			cout << "0. Exit" << endl << endl;

			cout << "Insert your choice: ";

			cin >> choice;

			// What we have?
			if (choice == 0) {
				return 1;
			} else if (choice == 6) {
				gameCount = 5;
				break;
			} else if (choice > 0 && choice < 6) {
				break;
			}

			cout << endl << endl;
		} while (true);
	}

	cout << endl << endl;

	// Ask for threading
	if (argc < 3) {
		int useThreading = -1;

		do {
			cout << "Should it search with threading?" << endl;
			cout << "-------------------------------------" << endl;
			cout << "1. Yes" << endl;
			cout << "2. No" << endl;
			cout << "-------------------------------------" << endl;
			cout << "0. Exit" << endl << endl;

			cout << "Insert your choice: ";

			cin >> useThreading;

			// What we have?
			if (useThreading == 0) {
				return 1;
			} else if (useThreading == 1) {
				threaded = true;
				break;
			} else if (useThreading == 2) {
				threaded = false;
				break;
			}

			cout << endl << endl;
		} while (true);
	}

	// Open the database
	if (sqlite3_open("gamebanana.sq3", &db) != SQLITE_OK) {
		// Couldn't open!
		cerr << "ERROR: Couldn't open sqlite3 database: " << sqlite3_errmsg(db) << endl;
		return 1;
	}

	// Database settings
	sqlite3_exec(db, "PRAGMA journal_mode=OFF", 0, 0, 0);
	sqlite3_exec(db, "PRAGMA locking_mode=EXCLUSIVE", 0, 0, 0);
	sqlite3_exec(db, "PRAGMA synchronous=OFF", 0, 0, 0);

	// Create tables
	sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS `mapdl_categories_v2` (`id` int, `name` varchar(255) NOT NULL, `game` varchar(24) NOT NULL, UNIQUE(`id`))", 0, 0, 0);
	sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS `mapdl_maps_v2` (`id` int NOT NULL, `categories_id` int NOT NULL, `date` int NOT NULL, `mdate` int NOT NULL, `downloads` int NOT NULL, `name` varchar(255) NOT NULL, `rating` varchar(6) NOT NULL, `votes` int NOT NULL, `views` int NOT NULL, `download` varchar(128) NOT NULL, `size` varchar(24) NOT NULL, UNIQUE(`id`))", 0, 0, 0);
	sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS `mapdl_info_v2` (`table_date` varchar(12) NOT NULL, `table_version` TINYINT NOT NULL, UNIQUE(`table_version`))", 0, 0, 0);
	sqlite3_exec(db, "DELETE FROM `mapdl_info_v2`", 0, 0, 0);

	// Update database time info
	char timeBuffer[128];
	startTime = time(0);

#ifdef _WIN32
	struct tm time_info;
	localtime_s(&time_info, (const time_t*)&startTime);

	strftime(timeBuffer, sizeof(timeBuffer), "%Y%m%d", &time_info);
#else
	strftime(timeBuffer, sizeof(timeBuffer), "%Y%m%d", localtime((const time_t*)&startTime));
#endif
	string query = "INSERT INTO `mapdl_info_v2` (`table_date`, `table_version`) VALUES ('" + (string)timeBuffer + "', 2)";
	sqlite3_exec(db, query.c_str(), 0, 0, 0);

	// First get all maps and categories
	for (int i = 1; i <= gameCount; i++) {
		if (gameCount == 1) {
			currentGame = getGameFromChoice(choice);
		} else {
			currentGame = getGameFromChoice(i);
		}

		getPage(OnGotCategorieDetails, "http://gamebanana.com/maps/games/" + to_string(currentGame), "", false, 0);
	}

	// Now start searching
	for (int i = 1; i <= gameCount; i++) {
		// Get the current game to search maps for
		if (gameCount == 1) {
			currentGame = getGameFromChoice(choice);
		} else {
			currentGame = getGameFromChoice(i);
		}

		cout << "INFO: Start searching maps for game " << getGameFromId(currentGame) << "; Game " << to_string(i) << "/" << to_string(gameCount) << endl << endl;

		// Start on the main maps page
		getPage(OnGotMainPage, "http://gamebanana.com/maps/games/" + to_string(currentGame), "", false, 0);
		cout << endl;
	}

	// Sleep until all is finished
	Sleeping(5);

	// Sleep until all threads are finished
	while (runningThreads.size() > 0) {
		Sleeping(1);
	}
	
	// Show correct finish :)
	current = allMaps - 1;
	printStatus();
	cout << "INFO: Finished!" << endl;

	// Close database
	sqlite3_close(db);

	return 1;
}


//// MAIN OPERATIONS ///

// We got the main maps page of a game
bool OnGotMainPage(char *error, string result, string url, string data, int errorCount) {
	// Valid answer?
	if ((strcmp(error, "") == 0) && result != "") {
		// Pages
		int pages = 1;

		// Now go through each page
		// Splitter for pages
		vector<std::string> founds = splitString(result, "class=\"CurrentPage\">");

		// Must be 3
		if (founds.size() == 3) {
			string found = founds[1];

			// Split for highest page
			vector<std::string> pageCount = splitString(found, "SubmissionsList\">", "</a>");

			int size = pageCount.size();
			if (size > 2) {
				// Replace garbage
				replaceString(pageCount[size - 1], "\n", "");
				replaceString(pageCount[size - 1], "\t", "");

				// Now get the page count
				pages = atoi(pageCount[size - 1].c_str());
			} else {
				cerr << "ERROR: Couldn't get last page count. Program seems to be outdated..." << endl;
				exit(1);
			}
		} else {
			cerr << "ERROR: Couldn't get first page count. Program seems to be outdated..." << endl;
			exit(1);
		}

		cout << "INFO: Found " << pages << " pages of maps" << endl;

		// Now read all pages
		OnGotMapsPage("", result, url, data, 0);

		for (int i = 2; i <= pages; i++) {
			getPage(OnGotMapsPage, url + "?vl[page]=" + to_string(i) + "&mid=SubmissionsList", data, false, 0);
		}
	} else {
		cerr << "ERROR: Error on loading game main page: " << error << endl;
		return false;
	}
	return true;
}


// Open a new Page
bool OnGotMapsPage(char *error, string result, string url, string data, int errorCount) {
	// Valid answer?
	if ((strcmp(error, "") == 0) && result != "") {
		// Splitter for Maps
		vector<std::string> founds = splitString(result, "td class=\"Preview\"", "<div");

		// Must be at least 2
		if (founds.size() > 1) {
			cout << "INFO: Found " << founds.size() << " maps on page" << endl;

			for (unsigned int i = 1; i < founds.size(); i++) {
				string found = founds[i];

				// Split for mapID
				vector<std::string> idSplit = splitString(found, "maps/", "\">");

				if (idSplit.size() == 2) {
					// Replace garbage
					replaceString(idSplit[1], "\n", "");
					replaceString(idSplit[1], "\t", "");
					replaceString(idSplit[1], "<br>", "");

					data = idSplit[1];
				} else {
					cerr << "ERROR: Couldn't get mapID split. Program seems to be outdated..." << endl;
					exit(1);
				}

				getPage(OnGotMapDetails, "http://api.gamebanana.com/Core/Item/Data?itemtype=Map&itemid=" + data + "&fields=catid,date,mdate,downloads,name,rating,votes,views,Downloadable().sFileUrl(),Downloadable().nGetFilesize()", data, true, 0);
			}
		} else {
			cerr << "ERROR: Couldn't get maps head. Programm seems to be outdated..." << endl;
			exit(1);
		}
	} else {
		cerr << "ERROR: Error on loading maps page: " << error << endl;

		if (errorCount > 20) {
			cerr << "ERROR: Found more then 20 errors on url " << url << ". Skipping..." << endl;
			return true;
		}
		return false;
	}
	return true;
}


// Retrieve Map Details
bool OnGotMapDetails(char *error, string result, string url, string data, int errorCount) {
	// Valid answer?
	if ((strcmp(error, "") == 0) && result != "") {
		// Read information of the map
		Json::Value root;
		Json::Reader reader;

		if (!reader.parse(result, root) && root.size() == 1) {
			cerr << "ERROR: Couldn't read map information. Program seems to be outdated..." << endl;
			exit(1);
		}

		// Check all information
		if (root.size() == 10) {
			// We have to temp. save the values, so we can check for valid data
			char fileSizeString[32];
			string categorie = "";
			string date = "";
			string mdate = "";
			string downloads = "0";
			string name = "";
			string rating = "0.00";
			string votes = "0";
			string views = "0";
			string download = "";
			float fileSize = 0.0;

			// Check if root has valid data
			if (root[0].isInt()) {
				categorie = to_string(root[0].asInt());
			}

			if (root[1].isInt()) {
				date = to_string(root[1].asInt());
			}

			if (root[2].isInt()) {
				mdate = to_string(root[2].asInt());
			}

			if (root[3].isInt()) {
				downloads = to_string(root[3].asInt());
			}

			if (root[4].isString()) {
				name = root[4].asString();
			}

			if (root[5].isString()) {
				rating = root[5].asString();
			}

			if (root[6].isInt()) {
				votes = to_string(root[6].asInt());
			}

			if (root[7].isInt()) {
				views = to_string(root[7].asInt());
			}

			if (root[8].isString()) {
				download = root[8].asString();
			}

			if (root[9].isInt()) {
				fileSize = (float)root[9].asInt();
			}


			// Give FileSize a nice layout
#ifdef _WIN32
			sprintf_s(fileSizeString, "%.2f B", fileSize);
#else
			sprintf(fileSizeString, "%.2f B", fileSize);
#endif
			if (fileSize > 1024.0) {
				fileSize /= 1024.0;
#ifdef _WIN32
				sprintf_s(fileSizeString, "%.2f KB", fileSize);
#else
				sprintf(fileSizeString, "%.2f KB", fileSize);
#endif
				if (fileSize > 1024.0) {
					fileSize /= 1024.0;
#ifdef _WIN32
					sprintf_s(fileSizeString, "%.2f MB", fileSize);
#else
					sprintf(fileSizeString, "%.2f MB", fileSize);
#endif
				}
			}

			// Update and print the current status
			printStatus();

			// Insert the map
			insertMap(data, categorie, date, mdate, downloads, name, rating, votes, views, download, fileSizeString);
		} else {
			cerr << "ERROR: Couldn't get map information. Program seems to be outdated..." << endl;
			exit(1);
		}
	} else {
		cerr << "ERROR: Error on loading map details: " << error << endl;

		if (errorCount > 20) {
			cerr << "ERROR: Found more then 20 errors on url " << url << ". Skipping..." << endl;
			return true;
		}
		return false;
	}
	return true;
}


// Get Information about categories and maps
bool OnGotCategorieDetails(char *error, string result, string url, string data, int errorCount) {
	// Valid answer?
	if ((strcmp(error, "") == 0) && result != "") {
		// Splitter for categories
		vector<std::string> founds = splitString(result, "<h3>Categories</h3>", "</tbody>");

		// Found Categories?
		if (founds.size() == 2) {
			// Replace garbage
			replaceString(founds[1], "\n", "");
			replaceString(founds[1], "\t", "");
			replaceString(founds[1], "\r", "");

			// Should be even, but first part is also there
			vector<std::string> categorieParts = splitString(founds[1], "<td", "</td>");

			if (categorieParts.size() % 3 == 1) {
				// All maps
				vector<std::string> mapCount = splitString(founds[1], "<td>", "</td>");

				// Link name
				vector<std::string> linkName = splitString(founds[1], "<td class=\"Name\"><a href=\"", "</a>");

				if (linkName.size() <= 1) {
					cerr << "ERROR: Couldn't get pre categorie link. Program seems to be outdated..." << endl;
					exit(1);
				}

				// Get Map Count
				if (mapCount.size() > 1) {
					cout << "INFO: Found " << mapCount.size() << " categories in " << getGameFromId(currentGame) << endl;

					// Loop for each map
					for (unsigned int i = 1; i < mapCount.size(); i++) {
						// Replace garbage
						replaceString(mapCount[i], "<td>", "");
						replaceString(mapCount[i], "</td>", "");
						replaceString(mapCount[i], " ", "");
						replaceString(mapCount[i], ",", "");

						allMaps = allMaps + atoi(mapCount[i].c_str());
					}

					cout << "INFO: Found " << allMaps << " maps in " << getGameFromId(currentGame) << endl;
				} else {
					cout << "ERROR: Couldn't get pre maps count. Program seems to be outdated..." << endl;
					exit(1);
				}

				// Loop for result
				for (unsigned int i = 1; i < linkName.size(); i++) {
					vector<std::string> realLinkName = splitString(linkName[i], "cats/");

					if (realLinkName.size() == 2) {
						vector<std::string> realCatId = splitString(realLinkName[1], "\">");

						if (realCatId.size() == 2) {
							// Insert new Typ
							insertCategorie(realCatId[0], realCatId[1]);
							cout << "INFO: Found category " << realCatId[1] << " with ID " << realCatId[0] << endl;
						} else {
							cerr << "ERROR: Couldn't get real catid. Program seems to be outdated..." << endl;
							exit(1);
						}
					} else {
						cerr << "ERROR: Couldn't get real link name. Program seems to be outdated..." << endl;
						exit(1);
					}
				}
			} else {
				cerr << "ERROR: Number of categories should be even. Program seems to be outdated..." << endl;
				exit(1);
			}
		} else {
			cerr << "ERROR: Couldn't get categorie head. Program seems to be outdated..." << endl;
			exit(1);
		}
	} else {
		cerr << "ERROR: Error on loading game category details: " << error << endl;
		return false;
	}
	return true;
}

// Print current status
void printStatus() {
	char cPercent[12];
	char cTime[12];

	threadMutex.lock();

	current++;

	float fPercent = ((float)current / (float)allMaps) * 100.0f;
	int percent = (int)fPercent;
	if (percent > 99) {
		percent = 100;
	}

	string code((percent / 10) + 1, '|');

#ifdef _WIN32
	sprintf_s(cPercent, "%.2f", fPercent);
	sprintf_s(cTime, "%.1f", ((((float)current)) / ((float)(time(0) - startTime))));
#else
	sprintf(cPercent, "%.2f", fPercent);
	sprintf(cTime, "%.1f", ((((float)current)) / ((float)(time(0) - startTime))));
#endif
	cout << code << " - " << (string)cPercent << "% (" << current << " / " << allMaps << ") - time: " << (time(0) - startTime) << "s, left: " << (int)((allMaps - current) / ((((float)current)) / ((float)(time(0) - startTime)))) << "s (" << cTime << " Maps/s)" << endl;

	threadMutex.unlock();
}

int getGameFromChoice(int arg) {
	// What we have?
	switch (arg) {
		case 1:
		{
			return 297;
		}
		case 2:
		{
			return 10;
		}
		case 3:
		{
			return 5;
		}
		case 4:
		{
			return 2;
		}
		default:
		{
			return 4660;
		}
	}
}

string getGameFromId(int id) {
	// What we have?
	switch (id) {
		case 297:
		{
			return "tf2";
		}
		case 10:
		{
			return "dods";
		}
		case 5:
		{
			return "hl2dm";
		}
		case 2:
		{
			return "css";
		}
		default:
		{
			return "csgo";
		}
	}
}


//// CURL OPERATIONS ///

// Get Page joinable
void getPage(callback function, string page, string data, bool threading, int errorCount) {
	if (threading && threaded) {
		thread pageThread(getPageThread, function, page, data, errorCount);

		threadMutex.lock();
		runningThreads.push_back(&pageThread);
		threadMutex.unlock();
		pageThread.detach();
	} else {
		getPageThread(function, page, data, errorCount);
	}
}

// Thread for curl
void getPageThread(callback function, string page, string data, int errorCount) {
	bool validResponse = false;
	while (!validResponse) {
		// Error buffer
		char ebuf[CURL_ERROR_SIZE];

		// Response
		std::ostringstream stream;

		// Init Curl
		CURL *curl = curl_easy_init();
		if (curl != NULL) {
			// Configurate Curl
			curl_easy_setopt(curl, CURLOPT_URL, page.c_str());
			curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
			curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, ebuf);
			curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60);
			curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
			curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 60);
			curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
			curl_easy_setopt(curl, CURLOPT_WRITEDATA, &stream);

			// Perform Curl
			CURLcode res = curl_easy_perform(curl);

			// Everything good :)
			if (res == CURLE_OK) {
				validResponse = function("", stream.str(), page, data, errorCount);
			} else {
				// Error ):
				validResponse = function(ebuf, stream.str(), page, data, errorCount);
			}

			// Clean Curl
			curl_easy_cleanup(curl);
			
			errorCount++;
			continue;
		}

		// Other error
		validResponse = function("", "", page, data, errorCount);
		errorCount++;
	}

	// Remove thread from running threads
	threadMutex.lock();
	for (std::vector<thread*>::iterator it = runningThreads.begin(); it != runningThreads.end(); ++it) {
		if ((*it)->get_id() == this_thread::get_id()) {
			runningThreads.erase(it);
			break;
		}
	}
	threadMutex.unlock();
}

// Curl receive data -> write to buffer
size_t write_data(void *buffer, size_t size, size_t nmemb, void *userp) {
	std::ostringstream *data = (std::ostringstream*)userp;
	size_t count = size * nmemb;

	data->write((char*)buffer, count);

	return count;
}


//// SQLITE3 OPERATIONS ///

// Insert a new Categorie
void insertCategorie(string id, string name) {
	string query = "INSERT OR IGNORE INTO `mapdl_categories_v2` (`id`, `name`, `game`) VALUES ('" + id + "', '" + name + "', '" + getGameFromId(currentGame) + "')";
	sqlite3_exec(db, query.c_str(), 0, 0, 0);

	query = "UPDATE `mapdl_categories_v2` SET `name` = '" + name + "', `game` = '" + getGameFromId(currentGame) + "' WHERE `id` = " + id;
	sqlite3_exec(db, query.c_str(), 0, 0, 0);
}


// Insert a new Map
void insertMap(string id, string categorie, string date, string mdate, string downloads, string name, string rating, string votes, string views, string download, string size) {
	string query = "INSERT OR IGNORE INTO `mapdl_maps_v2` (`id`, `categories_id`, `date`, `mdate`, `downloads`, `name`, `rating`, `votes`, `views`, `download`, `size`) VALUES (" + id + ", " + categorie + ", " + date + ", " + mdate + ", " + downloads + ", '" + name + "', '" + rating + "', " + votes + ", " + views + ", '" + download + "', '" + size + "')";
	sqlite3_exec(db, query.c_str(), 0, 0, 0);

	query = "UPDATE `mapdl_maps_v2` SET `categories_id` = " + categorie + ", `date` = " + date + ", `mdate` = " + mdate + ", `downloads` = " + downloads + ", `name` = '" + name + "', `rating` = '" + rating + "', `votes` = " + votes + ", `views` = " + views + ", `download` = '" + download + "', `size` = '" + size + "' WHERE `id` = " + id;
	sqlite3_exec(db, query.c_str(), 0, 0, 0);
}


//// STRING OPERATIONS ///

// Replace a string with a new str
void replaceString(string &str, const string& oldStr, const string& newStr) {
	// pos
	size_t pos = 0;

	// Next item?
	while ((pos = str.find(oldStr, pos)) != std::string::npos) {
		// Replace
		str.replace(pos, oldStr.length(), newStr);
		pos += newStr.length();
	}
}

// Split a string with start and end
vector<std::string> splitString(const string &str, const string& search, const string& to) {
	// Vector with splits
	std::vector<std::string> splits;

	// current pos
	size_t pos = 0;

	// Also add first item
	bool first = true;

	// Next item?
	while ((pos = str.find(search, pos)) != std::string::npos) {
		if (first) {
			// Save also first item
			string found = str.substr(0, pos);

			replaceString(found, search, "");

			splits.push_back(found);
		}


		// Substring it
		if (to != "") {
			string found = str.substr(pos, (str.find(to, pos) - pos));

			// Replace start and end
			replaceString(found, search, "");
			replaceString(found, to, "");

			splits.push_back(found);
		} else {
			string found = str.substr(pos, string::npos);

			// Replace start and end
			replaceString(found, search, "");

			splits.push_back(found);
		}

		// new len
		pos += search.length();

		// not first anymore
		first = false;
	}

	// Return found items
	return splits;
}