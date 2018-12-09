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

#define MAX_THREADS 40

// The game to list maps for
int currentGame = -1;

// Use threading?
bool threaded = false;
volatile int runningThreads;
vector<string> foundCategories;

// Current statistics
volatile int allMaps = 0;
volatile int current = 0;
time_t startTime;

// Mutex
mutex threadMutex;
mutex categoriesMutex;

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
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS `mapdl_maps_v2` (`id` int NOT NULL, `categories_id` int NOT NULL, `date` int NOT NULL, `mdate` int NOT NULL, `downloads` int NOT NULL, `name` varchar(255) NOT NULL, `rating` varchar(6) NOT NULL, `votes` int NOT NULL, `views` int NOT NULL, `download` varchar(128), `size` varchar(24), UNIQUE(`id`))", 0, 0, 0);
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

    // First get all maps
    for (int i = 1; i <= gameCount; i++) {
        if (gameCount == 1) {
            currentGame = getGameFromChoice(choice);
        } else {
            currentGame = getGameFromChoice(i);
        }

        getPage(OnGotMapsCount, "http://gamebanana.com/maps/games/" + to_string(currentGame), "", false, 0);
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
    while (runningThreads) {
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


// Get information about number of maps
bool OnGotMapsCount(char *error, string result, string url, string data, int errorCount, string additional) {
    // Valid answer?
    if ((strcmp(error, "") == 0) && result != "") {
        // Splitter for maps cpount
        vector<string> founds = splitString(result, "\"OfText\">", "<span");

        // Found?
        if (founds.size() == 2) {
            // Replace garbage
            replaceString(founds[1], "of", "");
            replaceString(founds[1], "</span>", "");
            replaceString(founds[1], ",", "");
            replaceString(founds[1], "\n", "");
            replaceString(founds[1], "\t", "");
            replaceString(founds[1], "\r", "");

            allMaps = allMaps + atoi(founds[1].c_str());

            cout << "INFO: Found " << founds[1] << " maps for " << getGameFromId(currentGame) << endl;
        } else {
            cerr << "ERROR: Couldn't get map count. Program seems to be outdated..." << endl;
            exit(1);
        }
    } else {
        cerr << "ERROR: Error on loading game map page: " << error << endl;
        exit(1);
    }
    return true;
}

// We got the main maps page of a game
bool OnGotMainPage(char *error, string result, string url, string data, int errorCount, string additional) {
    // Valid answer?
    if ((strcmp(error, "") == 0) && result != "") {
        // Pages
        int pages = 1;

        // Now go through each page
        // Splitter for pages
        vector<string> founds = splitString(result, "class=\"CurrentPage\">");

        // Must be 2
        if (founds.size() == 2) {
            string found = founds[1];

            // Split for highest page
            vector<string> pageCount = splitString(found, "SubmissionsList\">", "</a>");

            int size = pageCount.size();
            if (size > 3) {
                // Replace garbage
                replaceString(pageCount[size - 2], "\n", "");
                replaceString(pageCount[size - 2], "\t", "");

                // Now get the page count
                pages = atoi(pageCount[size - 2].c_str());
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
        OnGotMapsPage("", result, url, data, 0, additional);

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
bool OnGotMapsPage(char *error, string result, string url, string data, int errorCount, string additional) {
    // Valid answer?
    if ((strcmp(error, "") == 0) && result != "") {
        // Splitter for Maps
        vector<string> founds = splitString(result, "recordCell class=\"Preview\"", "recordCell class=\"Ownership\"");

        // Must be at least 2
        if (founds.size() > 1) {
            cout << "INFO: Found " << founds.size() - 1 << " maps on page" << endl;

            for (unsigned int i = 1; i < founds.size(); i++) {
                string found = founds[i];

                // Split for mapID
                vector<string> idSplit = splitString(found, "class=\"Name\"", ">");

                if (idSplit.size() == 2) {
                    idSplit = splitString(idSplit[1], "maps/", "\"");

                    if (idSplit.size() == 2) {
                        // Replace garbage
                        replaceString(idSplit[1], "\n", "");
                        replaceString(idSplit[1], "\t", "");
                        replaceString(idSplit[1], "<br>", "");

                        data = idSplit[1];
                    } else {
                        cerr << "ERROR: Couldn't get mapID split. Skipping..." << endl;
                        return true;
                    }
                } else {
                    cerr << "ERROR: Couldn't get mapID split. Skipping..." << endl;
                    return true;
                }

                // Split for catId
                vector<string> catIdSplit = splitString(found, "DirectCategory\">", "</a>");
                string catId;

                if (catIdSplit.size() == 2) {
                    catIdSplit = splitString(catIdSplit[1], "cats/", "\">");

                    if (catIdSplit.size() == 2) {
                        // Replace garbage
                        replaceString(catIdSplit[1], "\n", "");
                        replaceString(catIdSplit[1], "\t", "");
                        replaceString(catIdSplit[1], "<br>", "");

                        catId = catIdSplit[1];
                    } else {
                        cerr << "ERROR: Couldn't get catID split. Skipping..." << endl;
                        return true;
                    }
                } else {
                    cerr << "ERROR: Couldn't get catID split. Skipping..." << endl;
                    return true;
                }

                getPage(OnGotMapDetails, "http://api.gamebanana.com/Core/Item/Data?itemtype=Map&itemid=" + data + "&fields=Category().name,date,mdate,downloads,name,rating,votes,views,Files().aFiles()", data, true, 0, catId);
            }
        } else {
            cerr << "ERROR: Couldn't get maps head. Skipping..." << endl;
            return true;
        }
    } else {
        cerr << "ERROR: Error on loading maps page: " << error << endl;

        if (errorCount > 20) {
            cerr << "ERROR: Found more then 20 errors on url " << url << ". Skipping..." << endl;
            return true;
        }
        return false;
    }

    // Prevent too much threads
    while (true) {
        threadMutex.lock();
        if (runningThreads <= MAX_THREADS) {
            threadMutex.unlock();
            break;
        }

        threadMutex.unlock();
        Sleeping(1);
    }

    return true;
}


// Retrieve Map Details
bool OnGotMapDetails(char *error, string result, string url, string data, int errorCount, string categorie) {
    // Valid answer?
    if ((strcmp(error, "") == 0) && result != "") {
        // Read information of the map
        Json::Value root;
        Json::Reader reader;

        if (!reader.parse(result, root) && root.size() == 1) {
            cerr << "ERROR: Couldn't read map information. Skipping..." << endl;
            return true;
        }

        // Check all information
        if (root.size() == 9) {
            // We have to temp. save the values, so we can check for valid data
            string downloadUrl;
            string fileSize;
            string categorieName = "";
            string date = "";
            string mdate = "";
            string downloads = "0";
            string name = "";
            string rating = "0.00";
            string votes = "0";
            string views = "0";

            // Check if root has valid data
            if (root[0].isString()) {
                categorieName = root[0].asString();
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

            if (root[8].isObject() && root[8].getMemberNames().size() > 0) {
                string fileId = root[8].getMemberNames()[0];
                downloadUrl = root[8][fileId].get("_sDownloadUrl", "").asString();
                fileSize = formatFileSize(root[8][fileId].get("_nFilesize", "").asFloat());
            }

            if (downloadUrl.empty() || fileSize.empty()) {
                cerr << "ERROR: File name stuff can't be empty. Skipping..." << endl;
                return true;
            }

            if (categorie.empty() || categorieName.empty()) {
                cerr << "ERROR: Category stuff can't be empty. Skipping..." << endl;
                return true;
            }

            // Add category
            insertCategorie(categorie, categorieName);

            // Add the map with download details
            insertMap(data, categorie, date, mdate, downloads, name, rating, votes, views, downloadUrl, fileSize);
            // Update and print the current status
            printStatus();

            // Add the map without download details
            //insertMap(data, categorie, date, mdate, downloads, name, rating, votes, views);

            // Finally get download details -- not needed as long API gives file
            //getPage(OnGotMapDownloadDetails, "https://gamebanana.com/maps/download/" + data, data, false, 0);
        } else {
            cerr << "ERROR: Couldn't get map information. Skipping..." << endl;
            return true;
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


// Retrieve Map Download Details
bool OnGotMapDownloadDetails(char *error, string result, string url, string data, int errorCount, string additional) {
    // Valid answer?
    if ((strcmp(error, "") == 0) && result != "") {
        // Splitter for FileInfo
        vector<string> founds = splitString(result, "class=\"FileInfo\"", "<div");

        // Must be at least 2
        if (founds.size() > 1) {
            string found = founds[1];
            string fileName;
            string fileSizeString;

            // Split for file name
            vector<string> fileNameSplit = splitString(found, "<span>", "</span>");

            if (fileNameSplit.size() == 4) {
                // Replace garbage
                replaceString(fileNameSplit[1], " ", "");
                replaceString(fileNameSplit[1], "\n", "");
                replaceString(fileNameSplit[1], "\t", "");
                replaceString(fileNameSplit[1], "<br>", "");

                fileName = fileNameSplit[1];
            } else {
                deleteMap(data);

                cerr << "ERROR: Couldn't get map download file name. Skipping..." << endl;
                return true;
            }

            // Split for file size element
            vector<string> fileSizeElementSplit = splitString(found, "<small>", "</small>");

            if (fileSizeElementSplit.size() == 2) {
                // Split for file size
                vector<string> fileSizeSplit = splitString(fileSizeElementSplit[1], "title=\"", "bytes\">");

                if (fileSizeSplit.size() == 2) {
                    // Replace garbage
                    replaceString(fileSizeSplit[1], " ", "");
                    replaceString(fileSizeSplit[1], "\n", "");
                    replaceString(fileSizeSplit[1], "\t", "");
                    replaceString(fileSizeSplit[1], "<br>", "");

                    fileSizeString = formatFileSize(stof(fileSizeSplit[1]));
                } else {
                    deleteMap(data);

                    cerr << "ERROR: Couldn't get map download file size. Skipping..." << endl;
                    return true;
                }
            } else {
                deleteMap(data);

                cerr << "ERROR: Couldn't get map download file size element. Skipping..." << endl;
                return true;
            }

            // Update and print the current status
            printStatus();

            // Insert the map
            updateMapDownloadDetails(data, "https://files.gamebanana.com/maps/" + fileName, fileSizeString);
        } else {
            deleteMap(data);

            cerr << "ERROR: Couldn't get map download file. Skipping..." << endl;
            return true;
        }
    } else {
        cerr << "ERROR: Error on loading map download details page: " << error << endl;

        if (errorCount > 20) {
            deleteMap(data);

            cerr << "ERROR: Found more then 20 errors on url " << url << ". Skipping..." << endl;
            return true;
        }
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
void getPage(callback function, string page, string data, bool threading, int errorCount, string additional) {
    if (threading && threaded) {
        threadMutex.lock();
        runningThreads++;
        threadMutex.unlock();

        thread pageThread(getPageThread, function, page, data, errorCount, additional, true);
        pageThread.detach();
    } else {
        getPageThread(function, page, data, errorCount, additional, false);
    }
}

// Thread for curl
void getPageThread(callback function, string page, string data, int errorCount, string additional, bool isThreaded) {
    bool validResponse = false;
    while (!validResponse) {
        // Error buffer
        char ebuf[CURL_ERROR_SIZE];

        // Response
        ostringstream stream;

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
                validResponse = function("", stream.str(), page, data, errorCount, additional);
            } else {
                // Error ):
                validResponse = function(ebuf, stream.str(), page, data, errorCount, additional);
            }

            // Clean Curl
            curl_easy_cleanup(curl);

            errorCount++;
            continue;
        }

        // Other error
        validResponse = function("", "", page, data, errorCount, additional);
        errorCount++;
    }

    // Remove thread from running threads
    if (isThreaded) {
        threadMutex.lock();
        runningThreads--;
        threadMutex.unlock();
    }
}

// Curl receive data -> write to buffer
size_t write_data(void *buffer, size_t size, size_t nmemb, void *userp) {
    ostringstream *data = (ostringstream*)userp;
    size_t count = size * nmemb;

    data->write((char*)buffer, count);

    return count;
}


//// SQLITE3 OPERATIONS ///

// Insert a new Categorie
void insertCategorie(string id, string name) {
    categoriesMutex.lock();
    if (find(foundCategories.begin(), foundCategories.end(), id) != foundCategories.end()) {
        categoriesMutex.unlock();
        return;
    }
    cout << "INFO: Found new categorie " << name << " for " << getGameFromId(currentGame) << endl;

    foundCategories.push_back(id);
    categoriesMutex.unlock();

    char *errorMessage;

    char *query = sqlite3_mprintf("INSERT OR IGNORE INTO `mapdl_categories_v2` (`id`, `name`, `game`) VALUES (%s, '%q', '%q')", id.c_str(), name.c_str(), (getGameFromId(currentGame)).c_str());
    if (sqlite3_exec(db, query, 0, 0, &errorMessage) != SQLITE_OK) {
        cerr << "ERROR: Couldn't insert category (" << query << ":" << errorMessage << "). Program seems to be outdated..." << endl;
        sqlite3_free(errorMessage);
        sqlite3_free(query);

        exit(1);
    }
    sqlite3_free(query);

    query = sqlite3_mprintf("UPDATE `mapdl_categories_v2` SET `name` = '%q', `game` = '%q' WHERE `id` = %s", name.c_str(), (getGameFromId(currentGame)).c_str(), id.c_str());
    if (sqlite3_exec(db, query, 0, 0, &errorMessage) != SQLITE_OK) {
        cerr << "ERROR: Couldn't update category (" << query << ":" << errorMessage << "). Program seems to be outdated..." << endl;
        sqlite3_free(errorMessage);
        sqlite3_free(query);

        exit(1);
    }
    sqlite3_free(query);
}


// Insert a new Map
void insertMap(string id, string categorie, string date, string mdate, string downloads, string name, string rating, string votes, string views, string download, string size) {
    char *errorMessage;

    char *query = sqlite3_mprintf("INSERT OR IGNORE INTO `mapdl_maps_v2` (`id`, `categories_id`, `date`, `mdate`, `downloads`, `name`, `rating`, `votes`, `views`, `download`, `size`) VALUES (%s, %s, %s, %s, %s, '%q', '%s', %s, %s, '%q', '%s')", id.c_str(), categorie.c_str(), date.c_str(), mdate.c_str(), downloads.c_str(), name.c_str(), rating.c_str(), votes.c_str(), views.c_str(), download.c_str(), size.c_str());
    if (sqlite3_exec(db, query, 0, 0, &errorMessage) != SQLITE_OK) {
        cerr << "ERROR: Couldn't insert map (" << query << ":" << errorMessage << "). Program seems to be outdated..." << endl;
        sqlite3_free(errorMessage);
        sqlite3_free(query);

        exit(1);
    }
    sqlite3_free(query);

    query = sqlite3_mprintf("UPDATE `mapdl_maps_v2` SET `categories_id` = %s, `date` = %s, `mdate` = %s, `downloads` = %s, `name` = '%q', `rating` = '%s', `votes` = %s, `views` = %s, `download` = '%q', `size` = '%s' WHERE `id` = %s", categorie.c_str(), date.c_str(), mdate.c_str(), downloads.c_str(), name.c_str(), rating.c_str(), votes.c_str(), views.c_str(), download.c_str(), size.c_str(), id.c_str());
    if (sqlite3_exec(db, query, 0, 0, &errorMessage) != SQLITE_OK) {
        cerr << "ERROR: Couldn't update map (" << query << ":" << errorMessage << "). Program seems to be outdated..." << endl;
        sqlite3_free(errorMessage);
        sqlite3_free(query);

        exit(1);
    }
    sqlite3_free(query);
}


// Update a new Map
void updateMapDownloadDetails(string id, string download, string size) {
    char *errorMessage;

    char *query = sqlite3_mprintf("UPDATE `mapdl_maps_v2` SET `download` = '%q', `size` = '%s' WHERE `id` = %s", download.c_str(), size.c_str(), id.c_str());
    if (sqlite3_exec(db, query, NULL, NULL, &errorMessage) != SQLITE_OK) {
        cerr << "ERROR: Couldn't update map download details (" << query << ":" << errorMessage << "). Program seems to be outdated..." << endl;
        sqlite3_free(errorMessage);
        sqlite3_free(query);

        exit(1);
    }
    sqlite3_free(query);
}

// Update a new Map
void deleteMap(string id) {
    char *errorMessage;

    char *query = sqlite3_mprintf("DELETE FROM `mapdl_maps_v2` WHERE `id` = %s", id.c_str());
    if (sqlite3_exec(db, query, NULL, NULL, &errorMessage) != SQLITE_OK) {
        cerr << "ERROR: Couldn't delete map (" << query << ":" << errorMessage << "). Program seems to be outdated..." << endl;
        sqlite3_free(errorMessage);
        sqlite3_free(query);

        exit(1);
    }
    sqlite3_free(query);
}


//// STRING OPERATIONS ///

// Replace a string with a new str
string formatFileSize(float bytes) {
    char fileSizeString[32];

    // Give FileSize a nice layout
#ifdef _WIN32
    sprintf_s(fileSizeString, "%.2f B", bytes);
#else
    sprintf(fileSizeString, "%.2f B", bytes);
#endif
    if (bytes > 1024.0) {
        bytes /= 1024.0;
#ifdef _WIN32
        sprintf_s(fileSizeString, "%.2f KB", bytes);
#else
        sprintf(fileSizeString, "%.2f KB", bytes);
#endif
        if (bytes > 1024.0) {
            bytes /= 1024.0;
#ifdef _WIN32
            sprintf_s(fileSizeString, "%.2f MB", bytes);
#else
            sprintf(fileSizeString, "%.2f MB", bytes);
#endif
        }
    }

    return fileSizeString;
}

// Replace a string with a new str
void replaceString(string &str, const string& oldStr, const string& newStr) {
    // pos
    size_t pos = 0;

    // Next item?
    while ((pos = str.find(oldStr, pos)) != string::npos) {
        // Replace
        str.replace(pos, oldStr.length(), newStr);
        pos += newStr.length();
    }
}

// Split a string with start and end
vector<string> splitString(const string &str, const string& search, const string& to) {
    // Vector with splits
    vector<string> splits;

    // current pos
    size_t pos = 0;

    // Also add first item
    bool first = true;

    // Next item?
    while ((pos = str.find(search, pos)) != string::npos) {
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