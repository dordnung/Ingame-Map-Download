/*
 * -----------------------------------------------------
 * File        main.cpp
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

// Header
#include "main.h"


// Time
char timeBuffer[128];


// The game to list maps for
string game;

// Some data we need to know
volatile int allMaps;
volatile int current;
volatile time_t startTime;

// Mutex
mutex threadMutex;

// Database
sqlite3* db;



// Where all began :)
int main(int argc, const char* argv[])
{
	// Choice
	int choice;
	int gameCount = 1;
	bool useArg = false;

	// Argument?
	if (argc == 2)
	{
		choice = atoi(argv[1]);

		if (choice > 0 && choice < 6)
		{
			useArg = true;
		}
		else if (choice == 6)
		{
			gameCount = 5;
			useArg = true;
		}
	}

	// Standard Value
	game = "";
	allMaps = 0;
	current = 0;

	cout << endl << endl;

	if (!useArg)
	{
		do
		{
			cout << "Please choose a game" << endl;
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
			if (choice == 0)
			{
				return 1;
			}

			else if (choice == 6)
			{
				gameCount = 5;

				break;
			}

			else if (choice > 0 && choice < 6)
			{
				break;
			}


			cout << endl << endl;
		} 
		while (true);
	}



	// Open Database
	if (sqlite3_open("gamebanana.sq3", &db) != SQLITE_OK)
	{
		// Couldn't open!
		cout << "Couldn't open sqlite3 database: " << sqlite3_errmsg(db) << endl;

		if (!useArg)
		{
			cout << "Press any Key to exit...";
			cin.get();
		}

		return 1;
	}




	// Settings
	sqlite3_exec(db, "PRAGMA journal_mode=OFF", 0, 0, 0);
	sqlite3_exec(db, "PRAGMA locking_mode=EXCLUSIVE", 0, 0, 0);
	sqlite3_exec(db, "PRAGMA synchronous=OFF", 0, 0, 0);

	// Create Tables
	sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS `mapdl_categories` (`id` integer PRIMARY KEY, `name` varchar(255) NOT NULL, `game` varchar(24) NOT NULL, UNIQUE (name, game))", 0, 0, 0);
	sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS `mapdl_maps` (`categories_id` tinyint NOT NULL, `mapname` varchar(255) NOT NULL, `mapID` int NOT NULL, `file` varchar(128) NOT NULL, `size` varchar(24) NOT NULL, PRIMARY KEY(file))", 0, 0, 0);
	sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS `mapdl_info` (`table_version` varchar(12) NOT NULL, UNIQUE (table_version))", 0, 0, 0);
	sqlite3_exec(db, "DELETE * FROM `mapdl_info`", 0, 0, 0);

	if (!useArg)
	{
		// Delete screen
		#ifdef _WIN32
			system("cls");
		#endif
	}


	// Message
	cout << "Starting to search... Please wait... " << endl << endl;


	// Set time start
	startTime = time(0);
	strftime(timeBuffer, sizeof(timeBuffer), "%Y%m%d", localtime((const time_t*)&startTime));

	// Update time info
	string query = "INSERT INTO `mapdl_info` (`table_version`) VALUES ('" + (string)timeBuffer + "')";
	
	sqlite3_exec(db, query.c_str(), 0, 0, 0);



	// First get all maps and categories
	for (int i=1; i <= gameCount; i++)
	{
		// Get the Game
		if (gameCount == 1)
		{
			getGame(choice);
		}
		else
		{
			getGame(i);
		}

		getPage(OnGotCategorieDetails, "http://" + game + ".gamebanana.com/maps", "", "");
	}



	// Now start searching
	for (int i=1; i <= gameCount; i++)
	{
		// Get the Game
		if (gameCount == 1)
		{
			getGame(choice);
		}
		else
		{
			getGame(i);
		}

		// Start :)
		cout << "Start searching maps for game " << game << endl << endl;


		// Start all :)
		getPage(OnGotMainPage, "http://" + game + ".gamebanana.com/maps", "", "");


		// New line
		cout << endl;
	}
	


	// Sleep so all is finished
	Sleeping(5);




	// Show correct finish :)
	current = allMaps - 1;
	printStatus();


	if (!useArg)
	{
		// Close and End
		cout << "Press any Key to exit...";
		cin.get();
	}


	// Close SQLite
	sqlite3_close(db);


	return 1;
}









//// MAIN OPERATIONS ///




// We got the categories pages
void OnGotMainPage(char *error, string result, string url, string data, string data2)
{
	// Valid answer?
	if ((strcmp(error, "") == 0) && result != "")
	{
		// Pages
		int pages = 1;


		// No go through each page
		// Splitter for pages
		vector<std::string> founds = splitString(result, "class=\"CurrentPage\">");


		// Must be 3
		if (founds.size() == 3)
		{
			string found = founds[1];

			// Split for highest page
			vector<std::string> pageCount = splitString(found, "SubmissionsList\">", "</a>");

			int size = pageCount.size();

			if (size > 2)
			{
				// Replace garbage
				replaceString(pageCount[size - 1], "\n", "");
				replaceString(pageCount[size - 1], "\t", "");

				// Not get the page count
				pages = atoi(pageCount[size - 1].c_str());
			}
			else
			{
				cout << "ERROR: Couldn't get last page count. Program seems to be outdated..." << endl;

				return;
			}
		}
		else
		{
			cout << "ERROR: Couldn't get first page count. Program seems to be outdated..." << endl;

			return;
		}



		// Now read all pages
		OnGotMapsPage("", result, url, data, data2);


		for (int i=2; i <= pages; i++)
		{
			// Save int
			stringstream ss;
			ss << i;

			getPage(OnGotMapsPage, url + "?vl[page]=" + ss.str() + "&mid=SubmissionsList", data, data2);
		}
	}
	else
	{
		getPage(OnGotMainPage, url, data, data2);
	}
}






// Open a new Page
void OnGotMapsPage(char *error, string result, string url, string data, string data2)
{
	// Valid answer?
	if ((strcmp(error, "") == 0) && result != "")
	{
		// Splitter for pages
		vector<std::string> founds = splitString(result, "<div class=\"Category\">", "</h4>");

		// Must be 3
		if (founds.size() > 1)
		{
			for (unsigned int i=1; i < founds.size(); i++)
			{
				string found = founds[i];


				// Split for categorie
				vector<std::string> catsplit = splitString(found, "<acronym title=\"", "</div>");

				if (catsplit.size() == 2)
				{
					vector<std::string> catsplit2 = splitString(catsplit[1], "\">", "</a>");

					// Must be 3
					if (catsplit2.size() == 3)
					{
						// Replace garbage
						replaceString(catsplit2[2], "\n", "");
						replaceString(catsplit2[2], "\t", "");
						replaceString(catsplit2[2], "<br>", "");

						data2 = catsplit2[2];
					}
					else
					{
						cout << "ERROR: Couldn't get categorie name. Program seems to be outdated..." << endl;

						return;
					}
				}
				else
				{
					cout << "ERROR: Couldn't get categorie split. Program seems to be outdated..." << endl;

					return;
				}


				// Split again
				vector<std::string> strongSplit = splitString(found, "<h4>", "</a>");


				// Must be 2
				if (strongSplit.size() == 2)
				{
					vector<std::string> strongerSplit = splitString(strongSplit[1], "href=\"");

					// Must be 2
					if (strongerSplit.size() == 2)
					{
						string foundStrong = strongerSplit[1];

						// Replace garbage
						replaceString(foundStrong, "\n", "");
						replaceString(foundStrong, "\t", "");
						replaceString(foundStrong, "<br>", "");


						// Get Final link
						vector<std::string> linkName = splitString(foundStrong, "\">");

						// Also must be 2
						if (linkName.size() == 2)
						{
							replaceString(linkName[0], "maps/", "maps/download/");

							getPageMultiThread(OnGotMapDownload, linkName[0], linkName[1], data2);
						}
						else
						{
							cout << "ERROR: Couldn't get map link and name. Program seems to be outdated..." << endl;

							return;
						}
					}
					else
					{
						cout << "ERROR: Couldn't get map link and name split. Program seems to be outdated..." << endl;

						return;
					}
				}
				else
				{
					cout << "ERROR: Couldn't get map name and link head. Program seems to be outdated..." << endl;

					return;
				}
			}
		}
		else
		{
			cout << "ERROR: Couldn't get categorie head. Programm seems to be outdated..." << endl;

			return;
		}
	}
	else
	{
		getPage(OnGotMapsPage, url, data, data2);
	}
}






// Retrieve Map Download
void OnGotMapDownload(char *error, string result, string url, string data, string data2)
{
	// Valid answer?
	if ((strcmp(error, "") == 0) && result != "")
	{
		// File size
		string fileSize = "0";

		// Splitter for download name
		vector<std::string> founds = splitString(result, "<dt>File</dt>", "</dd>");
		vector<std::string> sizes = splitString(result, "<dt>Filesize</dt>", "</dd>");


		// Check file size
		if (sizes.size() == 2)
		{
			replaceString(sizes[1], "\n", "");
			replaceString(sizes[1], "\t", "");
			replaceString(sizes[1], "<br>", "");
			replaceString(sizes[1], "<dd>", "");

			fileSize = sizes[1];
		}
		else
		{
			cout << "ERROR: Couldn't get map size. Program seems to be outdated..." << endl;

			return;
		}

		// Must be 2
		if (founds.size() == 2)
		{
			string mapFile = founds[1];

			// Replace garbage
			replaceString(mapFile, "\n", "");
			replaceString(mapFile, "\t", "");
			replaceString(mapFile, "<br>", "");
			replaceString(mapFile, "<dd>", "");

			printStatus();


			// Get View Link
			replaceString(url, "http://" + game + ".gamebanana.com/maps/download/", "");


			// Sqlite operation in thread
			thread t1(insertMap, data2, data, url, mapFile, fileSize);
			t1.detach();
		}
		else
		{
			cout << "ERROR: Couldn't get map download link. Program seems to be outdated..." << endl;

			return;
		}
	}
	else
	{
		getPageMultiThread(OnGotMapDownload, url, data, data2);
	}
}






// Get Information about categories and maps
void OnGotCategorieDetails(char *error, string result, string url, string data, string data2)
{
	// Valid answer?
	if ((strcmp(error, "") == 0) && result != "")
	{
		// Splitter for categories
		vector<std::string> founds = splitString(result, "<img src=\"\">", "</a>");

		// All maps
		vector<std::string> mapCount = splitString(result, "</abbr>", "Maps");


		// Found Categories?
		if (founds.size() > 1)
		{
			// Get Map Count
			if (mapCount.size() > 1)
			{
				// Loop for each map
				for (unsigned int i=1; i < mapCount.size(); i++)
				{
					// Replace garbage
					replaceString(mapCount[i], " ", "");
					replaceString(mapCount[i], "\n", "");
					replaceString(mapCount[i], "\t", "");
					replaceString(mapCount[i], ",", "");

					allMaps = allMaps + atoi(mapCount[i].c_str());
				}
			}
			else
			{
				cout << "ERROR: Couldn't get pre maps count. Program seems to be outdated..." << endl;

				return;
			}



			// Loop for result
			for (unsigned int i=1; i < founds.size(); i++)
			{
				// Replace garbage
				replaceString(founds[i], "<a href=\"", "");
				replaceString(founds[i], "\n", "");
				replaceString(founds[i], "\t", "");

				// Get Link and name
				vector<std::string> linkName = splitString(founds[i], "\">");


				if (linkName.size() == 2)
				{
					// Insert new Typ
					insertCategorie(linkName[1]);
				}
				else
				{
					cout << "ERROR: Couldn't get pre categorie name. Program seems to be outdated..." << endl;

					return;
				}
			}
		}
		else
		{
			cout << "ERROR: Couldn't get pre categorie head. Program seems to be outdated..." << endl;

			return;
		}
	}
	else
	{
		getPage(OnGotCategorieDetails, url, data, data2);
	}
}






// Print current status
void printStatus()
{
	current++;

	if (threadMutex.try_lock())
	{
		char cPercent[12];
		char cTime[12];

		float fPercent = ((float)current / (float)allMaps) * 100.0f;
		int percent = (int) fPercent;

		if (percent > 99)
		{
			percent = 100;
		}

		string code((percent / 10) + 1, '|');

		#ifdef _WIN32
			sprintf_s(cPercent, "%.2f", fPercent);
			sprintf_s(cTime, "%.1f", (( ((float)current)) / ((float)(time(0) - startTime)) ));
		#else
			sprintf(cPercent, "%.2f", fPercent);
			sprintf(cTime, "%.1f", (( ((float)current)) / ((float)(time(0) - startTime)) ));
		#endif


		cout << code << " - " << (string)cPercent << "% (" << current << " / " << allMaps << ") - time: " << (time(0) - startTime) << "s, left: " << (int)((allMaps-current) / (( ((float)current)) / ((float)(time(0) - startTime)) )) << "s (" << cTime << " Maps/s)" << endl;


		threadMutex.unlock();
	}
}





void getGame(int gameInt)
{
	// What we have?
	switch (gameInt)
	{
		case 1:
		{
			game = "tf2";

			break;
		}
		case 2:
		{
			game = "dods";

			break;
		}
		case 3:
		{
			game = "hl2dm";

			break;
		}
		case 4:
		{
			game = "css";

			break;
		}
		case 5:
		{
			game = "csgo";

			break;
		}
	}
}









//// CURL OPERATIONS ///



// Get Page joinable
void getPage(callback function, string page, string data, string data2)
{
	thread t1(getPageThread, function, page, data, data2);
	t1.join();
}


// Get Page detached
void getPageMultiThread(callback function, string page, string data, string data2)
{
	thread t1(getPageThread, function, page, data, data2);

	t1.detach();
}



// Thread for curl
void getPageThread(callback function, string page, string data, string data2)
{
	// Error
	char ebuf[CURL_ERROR_SIZE];

	// Response
	std::ostringstream stream;

	// Init Curl
	CURL *curl = curl_easy_init();
		

	if (curl != NULL)
	{
		// Configurate Curl
		curl_easy_setopt(curl, CURLOPT_URL, page.c_str());
		curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
		curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, ebuf);
		curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10);
		curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
		curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 5);
		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
		curl_easy_setopt(curl, CURLOPT_WRITEDATA, &stream);

		// Perform Curl
		CURLcode res = curl_easy_perform(curl);

		// Everything good :)
		if (res == CURLE_OK)
		{
			function("", stream.str(), page, data, data2);
		}
		else
		{
			// Error ):
			function(ebuf, stream.str(), page, data, data2);
		}

		// Clean Curl
		curl_easy_cleanup(curl);

		// Stop
		return;
	}

	// Other error
	function("", "", page, data, data2);
}




// Curl receive data -> write to buffer
size_t write_data(void *buffer, size_t size, size_t nmemb, void *userp)
{
	std::ostringstream *data = (std::ostringstream*)userp;
	size_t count = size * nmemb;

	data->write((char*)buffer, count);

	return count;
}










//// SQLITE3 OPERATIONS ///



// Insert a new Categorie
void insertCategorie(string name)
{
	string query = "INSERT INTO `mapdl_categories` (`id`, `name`, `game`) VALUES (NULL, '" + name + "', '" + game + "')";

	sqlite3_exec(db, query.c_str(), 0, 0, 0);
}


// Insert a new Map
void insertMap(string categorie, string name, string link, string download, string size)
{
	string query = "INSERT INTO `mapdl_maps` (`categories_id`, `mapname`, `mapID`, `file`, `size`) SELECT mapdl_categories.id, '" + name + "', " + link + ", '" + download + "', '" + size + "' FROM `mapdl_categories` WHERE mapdl_categories.name = '" + categorie + "' AND mapdl_categories.game = '" + game + "'";

	sqlite3_exec(db, query.c_str(), 0, 0, 0);
}











//// STRING OPERATIONS ///


// Replace a string with a new str
void replaceString(string &str, const string& oldStr, const string& newStr)
{
	// pos
	size_t pos = 0;


	// Next item?
	while((pos = str.find(oldStr, pos)) != std::string::npos)
	{
		// Replace
		str.replace(pos, oldStr.length(), newStr);
		pos += newStr.length();
	}
}




// Split a string with start and end
vector<std::string> splitString(const string &str, const string& search, const string& to)
{
	// Vector with splits
	std::vector<std::string> splits;

	// current pos
	size_t pos = 0;

	// Also add first item
	bool first = true;


	// Next item?
	while((pos = str.find(search, pos)) != std::string::npos)
	{
		if (first)
		{
			// Save also first item
			string found = str.substr(0, pos);

			replaceString(found, search, "");

			splits.push_back(found);
		}


		// Substring it
		if (to != "")
		{
			string found = str.substr(pos, (str.find(to, pos) - pos));

			// Replace start and end
			replaceString(found, search, "");
			replaceString(found, to, "");

			splits.push_back(found);
		}
		else
		{
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