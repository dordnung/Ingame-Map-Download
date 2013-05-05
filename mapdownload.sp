/**
 * -----------------------------------------------------
 * File			mapdownload.sp
 * Authors		David <popoklopsi> Ordnung
 * License		GPLv3
 * Web			http://popoklopsi.de
 * -----------------------------------------------------
 * 
 * 
 * Copyright (C) 2013 David <popoklopsi> Ordnung
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



// Sourcemod
#include <sourcemod>

// Colors
#include <colors>

// System2
#include <system2>

// Auto append config
#include <autoexecconfig>

// Downloads Table
#include <sdktools>

// Escaping
#include <stringescape>

// Maybe include the updater if exists
#undef REQUIRE_PLUGIN
#include <updater>




// Using Semicolons
#pragma semicolon 1






// URLs
#define UPDATE_URL_PLUGIN "http://popoklopsi.de/mapdl/update.txt"
#define UPDATE_URL_DB "http://popoklopsi.de/mapdl/gamebanana.sq3"
#define URL_MOTD "http://popoklopsi.de/mapdl/motd.php"


// Client menu store defines
#define SEARCH 0
#define SEARCHREAL 1
#define CAT_ID 2
#define MAPNAME 3
#define MAPFILE 4
#define MAPID 5
#define MAPSIZE 6
#define GAME 7







// List of dl modes
enum Modus
{
	MODUS_DOWNLOAD,
	MODUS_UPLOAD,
	MODUS_COMPRESS,
	MODUS_FINISH
}




// List of download information
enum DownloadInfo
{
	DL_CLIENT,									// Client of current download
	DL_FINISH,									// Finished files
	Float:DL_CURRENT,							// Current Bytes
	Float:DL_TOTAL,								// Total bytes
	Modus:DL_MODE,								// Current dl Modes
	String:DL_ID[32],							// Map ID
	String:DL_NAME[128],						// Map Name
	String:DL_FILE[128],						// Download Link
	String:DL_SAVE[PLATFORM_MAX_PATH + 1],		// Path to save to
	Handle:DL_FILES,							// Array to store files
	Handle:DL_FTPFILES							// Array to store ftp files
}







// Global download list
new g_Downloads[20][DownloadInfo];


// Global strings
new String:g_sVersion[] = "2.0.0";
new String:g_sModes[][] = {"Downloading", "Uploading", "Compressing"};
new String:g_sGameSearch[64];
new String:g_sPluginPath[PLATFORM_MAX_PATH + 1];
new String:g_sCommand[32];
new String:g_sTag[32];
new String:g_sTagChat[64];
new String:g_sFlag[32];
new String:g_sFTPHost[128];
new String:g_sFTPUser[64];
new String:g_sFTPPW[128];
new String:g_sFTPPath[PLATFORM_MAX_PATH + 1];
new String:g_sGame[12];
new String:g_sSearch[MAXPLAYERS + 1][8][64];
new String:g_sWhitelistMaps[1024];
new String:g_sBlacklistMaps[1024];
new String:g_sWhitelistCategories[1024];
new String:g_sBlacklistCategories[1024];


// Global bools
new bool:g_bShow;
new bool:g_bMapCycle;
new bool:g_bNotice;
new bool:g_bFTP;
new bool:g_bFirst;
new bool:g_bUpdate;
new bool:g_bUpdateDB;
new bool:g_bDBLoaded;
new bool:g_bSearch;
new bool:g_bDownloadList;


// Global ints
new g_iFTPPort;
new g_iTotalDownloads;
new g_iCurrentDownload;
new g_iGameChoice;
new g_iLast[MAXPLAYERS + 1][2];


// Global handles
new Handle:g_hSearch;
new Handle:g_hCommand;
new Handle:g_hUpdate;
new Handle:g_hUpdateDB;
new Handle:g_hTag;
new Handle:g_hFlag;
new Handle:g_hShow;
new Handle:g_hMapCycle;
new Handle:g_hNotice;
new Handle:g_hFTP;
new Handle:g_hFTPHost;
new Handle:g_hFTPUser;
new Handle:g_hFTPPW;
new Handle:g_hFTPPort;
new Handle:g_hFTPPath;
new Handle:g_hDatabase;
new Handle:g_hGameChoice;
new Handle:g_hHudSync;
new Handle:g_hDownloadList;




// Database querys
// Check if database is valid
new String:g_sDatabaseCheck[] = "SELECT \
						`mapdl_categories`.`id`, `mapdl_categories`.`name`, `mapdl_categories`.`game`, \
						\
						`mapdl_maps`.`categories_id`, `mapdl_maps`.`mapname`, `mapdl_maps`.`mapID`, `mapdl_maps`.`file`, `mapdl_maps`.`size`, `mapdl_info`.`table_version` \
						\
						FROM `mapdl_categories`, `mapdl_maps`, `mapdl_info` LIMIT 1";


// Get all categories
new String:g_sAllCategories[] = "SELECT \
						`mapdl_categories`.`id`, `mapdl_categories`.`name`, COUNT(`mapdl_maps`.`mapname`) FROM `mapdl_categories`, `mapdl_maps` \
						WHERE `game` IN %s AND `mapdl_categories`.`id`=`mapdl_maps`.`categories_id` %s%s%s%s GROUP BY `mapdl_categories`.`name`";


// Search for a categorie
new String:g_sSearchCategories[] = "SELECT \
						`mapdl_categories`.`id`, `mapdl_categories`.`name`, COUNT(`mapdl_maps`.`mapname`) FROM `mapdl_categories`, `mapdl_maps` \
						WHERE `game` IN %s AND `mapdl_categories`.`id`=`mapdl_maps`.`categories_id` AND `mapdl_maps`.`mapname` LIKE '%s' ESCAPE '?' %s%s%s%s GROUP BY `mapdl_categories`.`name`";

						
// Get all maps
new String:g_sAllMaps[] = "SELECT `mapdl_maps`.`mapname`, `mapdl_maps`.`mapID`, `mapdl_maps`.`file`, `mapdl_maps`.`size`, `mapdl_categories`.`game` FROM `mapdl_maps`, `mapdl_categories` \
						WHERE `mapdl_maps`.`categories_id`=%i AND `mapdl_maps`.`categories_id` = `mapdl_categories`.`id` %s%s GROUP BY `mapdl_maps`.`mapname`";


// Search for a map
new String:g_sSearchMaps[] = "SELECT `mapdl_maps`.`mapname`, `mapdl_maps`.`mapID`, `mapdl_maps`.`file`, `mapdl_maps`.`size`, `mapdl_categories`.`game` FROM `mapdl_maps`, `mapdl_categories` \
						WHERE `mapdl_maps`.`mapname` LIKE '%s' ESCAPE '?' AND `mapdl_maps`.`categories_id`=%i AND `mapdl_maps`.`categories_id` = `mapdl_categories`.`id` %s%s GROUP BY `mapdl_maps`.`mapname`";







// Global info
public Plugin:myinfo =
{
	name = "Ingame Map Download",
	author = "Popoklopsi",
	version = g_sVersion,
	description = "Allows admins to download Maps ingame"
};



























/*
**************

MAIN METHODS

**************
*/





// Plugin started
public OnPluginStart()
{
	// Load Translation
	LoadTranslations("mapdownload.phrases");
	
	
	// First is true!
	g_bFirst = true;
	g_bDBLoaded = false;


	// Init. AutoExecConfig
	AutoExecConfig_SetFile("plugin.mapdownload");


	// Public Cvar
	AutoExecConfig_CreateConVar("mapdownload_version", g_sVersion, "Ingame Map Download Version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

	// Set Cvars
	g_hCommand = AutoExecConfig_CreateConVar("mapdownload_command", "sm_download", "Command to open Map Download menu. Append prefix 'sm_' for chat use!");
	g_hTag = AutoExecConfig_CreateConVar("mapdownload_tag", "Map Download", "Chat prefix of Map Download");
	g_hFlag = AutoExecConfig_CreateConVar("mapdownload_flag", "bg", "Flagstring to access menu (see configs/admin_levels.cfg)");
	g_hShow = AutoExecConfig_CreateConVar("mapdownload_show", "0", "1 = All players see map downloading status, 0 = Only admins");
	g_hSearch = AutoExecConfig_CreateConVar("mapdownload_search", "1", "1 = Search searchmask within a string, 0 = Search excact mask");
	g_hMapCycle = AutoExecConfig_CreateConVar("mapdownload_mapcycle", "1", "1 = Write downloaded map in mapcycle.txt, 0 = Off");
	g_hNotice = AutoExecConfig_CreateConVar("mapdownload_notice", "1", "1 = Notice admins on server that Map Download runs, 0 = Off");
	g_hDownloadList = AutoExecConfig_CreateConVar("mapdownload_downloadlist", "1", "1 = Add custom files of map to intern downloadlist, 0 = Off");
	g_hGameChoice = AutoExecConfig_CreateConVar("mapdownload_game", "1", "(Only CS:S). Gamemode: 1=Normal, 2=GunGame, 3=Zombie, 4=1+2, 5=1+3, 6=2+3, 7=1+2+3");
	g_hUpdate = AutoExecConfig_CreateConVar("mapdownload_update_plugin", "1", "1 = Auto update plugin with God Tony's autoupdater, 0 = Off");
	g_hUpdateDB = AutoExecConfig_CreateConVar("mapdownload_update_database", "1", "1 = Auto update gamebanana database on plugin start, 0 = Off");
	g_hFTP = AutoExecConfig_CreateConVar("mapdownload_ftp", "0", "1 = Use Fast Download upload, 0 = Off");
	g_hFTPHost = AutoExecConfig_CreateConVar("mapdownload_ftp_host", "192.168.0.1", "Host of your FastDL server");
	g_hFTPPort = AutoExecConfig_CreateConVar("mapdownload_ftp_port", "21", "Port of your FastDL server");
	g_hFTPUser = AutoExecConfig_CreateConVar("mapdownload_ftp_user", "username", "Username to login");
	g_hFTPPW = AutoExecConfig_CreateConVar("mapdownload_ftp_pass", "password", "Password for username to login");
	g_hFTPPath = AutoExecConfig_CreateConVar("mapdownload_ftp_path", "path/on/fastdl", "Path to your FastDL gamedir folder, including folders maps, sound, and so on");



	// Exec Config
	AutoExecConfig(true, "plugin.mapdownload");

	// clean Config
	AutoExecConfig_CleanFile();
}





// Config is executed
public OnConfigsExecuted()
{
	// Read all convars
	// Ints
	g_iFTPPort = GetConVarInt(g_hFTPPort);
	g_iGameChoice = GetConVarInt(g_hGameChoice);

	// Valid?
	if (g_iGameChoice < 0 || g_iGameChoice > 7)
	{
		g_iGameChoice = 1;
	}


	// Bools
	g_bNotice = GetConVarBool(g_hNotice);
	g_bShow = GetConVarBool(g_hShow);
	g_bMapCycle = GetConVarBool(g_hMapCycle);
	g_bFTP = GetConVarBool(g_hFTP);
	g_bUpdate = GetConVarBool(g_hUpdate);
	g_bUpdateDB = GetConVarBool(g_hUpdateDB);
	g_bSearch = GetConVarBool(g_hSearch);
	g_bDownloadList = GetConVarBool(g_hDownloadList);


	// Strings
	GetConVarString(g_hCommand, g_sCommand, sizeof(g_sCommand));
	GetConVarString(g_hTag, g_sTag, sizeof(g_sTag));
	GetConVarString(g_hFlag, g_sFlag, sizeof(g_sFlag));
	GetConVarString(g_hFTPHost, g_sFTPHost, sizeof(g_sFTPHost));
	GetConVarString(g_hFTPUser, g_sFTPUser, sizeof(g_sFTPUser));
	GetConVarString(g_hFTPPW, g_sFTPPW, sizeof(g_sFTPPW));
	GetConVarString(g_hFTPPath, g_sFTPPath, sizeof(g_sFTPPath));



	// Hud Sync
	g_hHudSync = CreateHudSynchronizer();



	// Add Auto Updater if exit and want
	if (LibraryExists("updater") && g_bUpdate)
	{
		Updater_AddPlugin(UPDATE_URL_PLUGIN);
	}
	


	// Disable Hud Hint sound
	if (FindConVar("sv_hudhint_sound") != INVALID_HANDLE)
	{
		SetConVarInt(FindConVar("sv_hudhint_sound"), 0);
	}

	// First start?
	if (g_bFirst)
	{
		// Reset
		g_iCurrentDownload = -1;
		g_iTotalDownloads = 0;
	
		// Now register command to open menu
		RegAdminCmd(g_sCommand, OpenMenu, ReadFlagString(g_sFlag));


		// Prepare folders and connect to database
		PreparePlugin();


		// Start notice timer, every 6 minutes
		if (g_bNotice) 
		{
			CreateTimer(360.0, NoticeTimer, _, TIMER_REPEAT);
		}
		
		// Started
		g_bFirst = false;
	}



	// Change color for csgo
	if (StrEqual(g_sGame, "csgo", false))
	{
		CReplaceColor(Color_Green, Color_Lightred);
		CReplaceColor(Color_Lightgreen, Color_Lime);
	}


	// Load the downloadlist
	ParseDownloadList();
}





// All plugins are loaded now
public OnAllPluginsLoaded()
{
	// Is system2 extension here?
	if (!LibraryExists("system2"))
	{
		// No -> stop plugin!
		SetFailState("Attention: Extension system2 couldn't be found. Please install it to run Map Download!");
	}
}





// Prepare folders and connect to database
public PreparePlugin()
{
	// Build plugin paths
	BuildPath(Path_SM, g_sPluginPath, sizeof(g_sPluginPath), "mapdownload");


	// Check if paths exist
	// If not, create them!
	if (!DirExists(g_sPluginPath))
	{
		CreateDirectory(g_sPluginPath, 511);
	}

	// Temp dir
	Format(g_sPluginPath, sizeof(g_sPluginPath), "%s/temp", g_sPluginPath);

	
	// First delete old temp path
	DeletePath(g_sPluginPath);
	
	// Create new one
	CreateDirectory(g_sPluginPath, 511);






	// Format tags
	Format(g_sTagChat, sizeof(g_sTagChat), "{lightgreen}[{green} %s {lightgreen}]", g_sTag);
	Format(g_sTag, sizeof(g_sTag), "[ %s ]", g_sTag);





	// Get the game
	GetGameFolderName(g_sGame, sizeof(g_sGame));


	// We need the gamename of gamebanana
	if (StrEqual(g_sGame, "tf", false))
	{
		Format(g_sGame, sizeof(g_sGame), "tf2");
	}

	else if (StrEqual(g_sGame, "cstrike", false))
	{
		Format(g_sGame, sizeof(g_sGame), "css");
	}

	else if (StrEqual(g_sGame, "hl2mp", false))
	{
		Format(g_sGame, sizeof(g_sGame), "hl2dm");
	}

	else if (StrEqual(g_sGame, "dod", false))
	{
		Format(g_sGame, sizeof(g_sGame), "dods");
	}

	else if (!StrEqual(g_sGame, "csgo", false))
	{
		// Log error and stop plugin
		LogError("%s isn't supported for Map Download!", g_sGame);
		SetFailState("%s isn't supported for Map Download!", g_sGame);
	}




	// Special mods on CSS
	if (StrEqual(g_sGame, "css", false))
	{
		// Add Comma
		new bool:foundOne = false;


		//Start
		Format(g_sGameSearch, sizeof(g_sGameSearch), "(");



		// Main
		if (g_iGameChoice == 1 || g_iGameChoice == 4 || g_iGameChoice == 5 || g_iGameChoice == 7)
		{
			// Use Main
			Format(g_sGameSearch, sizeof(g_sGameSearch), "%s'css'", g_sGameSearch);

			foundOne = true;
		}



		// GunGame
		if (g_iGameChoice == 2 || g_iGameChoice == 4 || g_iGameChoice == 6 || g_iGameChoice == 7)
		{
			// Use GunGame
			if (foundOne)
			{
				Format(g_sGameSearch, sizeof(g_sGameSearch), "%s, ", g_sGameSearch);
			}

			// cssgg
			Format(g_sGameSearch, sizeof(g_sGameSearch), "%s'cssgg'", g_sGameSearch);

			foundOne = true;
		}



		// Zombie
		if (g_iGameChoice == 3 || g_iGameChoice == 5 || g_iGameChoice == 6 || g_iGameChoice == 7)
		{
			// Use zombie
			if (foundOne)
			{
				Format(g_sGameSearch, sizeof(g_sGameSearch), "%s, ", g_sGameSearch);
			}

			// csszm
			Format(g_sGameSearch, sizeof(g_sGameSearch), "%s'csszm'", g_sGameSearch);
		}


		// End
		Format(g_sGameSearch, sizeof(g_sGameSearch), "%s)", g_sGameSearch);
	}
	else
	{
		// Not CS:S
		Format(g_sGameSearch, sizeof(g_sGameSearch), "('%s')", g_sGame);
	}




	// If no DB update -> Load Database
	if (!g_bUpdateDB)
	{
		// Save methods :)
		PrepareDB(true, "", 0.0, 0.0, 0.0, 0.0);
	}
	else
	{
		decl String:path[PLATFORM_MAX_PATH + 1];

		// Path to sql file
		BuildPath(Path_SM, path, sizeof(path), "data/sqlite/gamebanana.sq3");


		// Download current database
		System2_DownloadFile(PrepareDB, UPDATE_URL_DB, path);
	}
}





// Prepare folders and connect to database
public ParseDownloadList()
{
	// Parse Downloadlist
	if (g_bDownloadList)
	{
		decl String:dllistFile[PLATFORM_MAX_PATH + 1];
		decl String:readbuffer[64];

		new Handle:file;


		// Path to downloadlist
		BuildPath(Path_SM, dllistFile, sizeof(dllistFile), "mapdownload/downloadlist.txt");



		// Open file
		file = OpenFile(dllistFile, "rb");


		// We could open file
		if (file != INVALID_HANDLE)
		{
			// Loop through file content
			while (!IsEndOfFile(file) && ReadFileLine(file, readbuffer, sizeof(readbuffer)))
			{
				// Replace line ends
				ReplaceString(readbuffer, sizeof(readbuffer), "\n", "");
				ReplaceString(readbuffer, sizeof(readbuffer), "\t", "");
				ReplaceString(readbuffer, sizeof(readbuffer), "\r", "");


				// No comments or spaces at start
				if (readbuffer[0] == '/' || readbuffer[0] == ' ')
				{
					continue;
				}


				// Add to download table
				AddFileToDownloadsTable(readbuffer);
			}


			// Close File
			CloseHandle(file);
		}
	}
}



// Create DB Connection
public PrepareDB(bool:finished, const String:error[], Float:dltotal, Float:dlnow, Float:ultotal, Float:ulnow)
{
	if (finished)
	{
		if (!StrEqual(error, ""))
		{
			// We couldn't update the db
			LogError("Attention: Couldn't update database. Error: %s", error);
		}
		else
		{
			// Notice update
			LogMessage("Updated gamebanana Database succesfully!");
		}


		decl String:sqlError[256];



		// Connect to database
		new Handle:dbHandle = CreateKeyValues("Databases");
		
		KvSetString(dbHandle, "driver", "sqlite");
		KvSetString(dbHandle, "host", "localhost");
		KvSetString(dbHandle, "database", "gamebanana");
		KvSetString(dbHandle, "user", "root");

		// Connect
		g_hDatabase = SQL_ConnectCustom(dbHandle, sqlError, sizeof(sqlError), true);


		// Close Keyvalues
		CloseHandle(dbHandle);




		// Check valid connection
		if (g_hDatabase == INVALID_HANDLE)
		{
			// Log error and stop plugin
			LogError("Map Download couldn't connect to the Database! Error: %s", sqlError);
			SetFailState("Map Download couldn't connect to the Database! Error: %s", sqlError);
		}
		else
		{
			// Lock database
			SQL_LockDatabase(g_hDatabase);

			
			// Get result
			new Handle:result = SQL_Query(g_hDatabase, g_sDatabaseCheck);

			// Check valid database
			if (result == INVALID_HANDLE)
			{
				// Something is old
				SQL_GetError(g_hDatabase, sqlError, sizeof(sqlError));
				
				LogError("Map Download plugin or database is outdated. Please update! Error: %s", sqlError);
			}
			else
			{
				if (!SQL_FetchRow(result))
				{
					LogError("Map Download database seems to be empty!");
				}

				// Close result
				CloseHandle(result);
			}



			// Unlock
			SQL_UnlockDatabase(g_hDatabase);


			// Now we can load white and blacklist
			ParseLists();


			// Database loaded
			g_bDBLoaded = true;
		}
	}
}





// Parse the white and black list
public ParseLists()
{
	decl String:listPath[PLATFORM_MAX_PATH + 1];

	new Handle:listHandle = CreateKeyValues("MapDownloadLists");


	// Path
	BuildPath(Path_SM, listPath, sizeof(listPath), "configs/mapdownload_lists.cfg");



	// List file exists?
	if (!FileExists(listPath))
	{
		// no...
		return;
	}


	// Load the file to keyvalue
	FileToKeyValues(listHandle, listPath);
	

	// First key categories
	if (KvJumpToKey(listHandle, "categories") &&  KvGotoFirstSubKey(listHandle, false))
	{
		// Loop through all items
		do
		{
			decl String:section[128];
			decl String:search[128];
			decl String:searchBuffer[256];
			decl String:searchFinal[256];


			// Get Section and key
			KvGetSectionName(listHandle, section, sizeof(section));
			KvGetString(listHandle, NULL_STRING, search, sizeof(search));


			// Any data?
			if (!StrEqual(search, ""))
			{
				// Escape search
				SQL_EscapeString(g_hDatabase, search, searchBuffer, sizeof(searchBuffer));
				EscapeString(searchBuffer, '_', '?', searchFinal, sizeof(searchFinal));



				// whitelist?
				if (StrEqual(section, "whitelist", false))
				{
					Format(searchFinal, sizeof(searchFinal), "AND `mapdl_categories`.`name` LIKE '%s' ESCAPE '?' ", searchFinal);
					StrCat(g_sWhitelistCategories, sizeof(g_sWhitelistCategories), searchFinal);
				}

				// blacklist
				else if (StrEqual(section, "blacklist", false))
				{
					Format(searchFinal, sizeof(searchFinal), "AND `mapdl_categories`.`name` NOT LIKE '%s' ESCAPE '?' ", searchFinal);
					StrCat(g_sBlacklistCategories, sizeof(g_sBlacklistCategories), searchFinal);
				}
			}
		} 
		while (KvGotoNextKey(listHandle, false));
	}


	// Rewind
	KvRewind(listHandle);


	// First key maps
	if (KvJumpToKey(listHandle, "maps") &&  KvGotoFirstSubKey(listHandle, false))
	{
		// Loop through all items
		do
		{
			decl String:section[128];
			decl String:search[128];
			decl String:searchBuffer[256];
			decl String:searchFinal[256];


			// Get Section and key
			KvGetSectionName(listHandle, section, sizeof(section));
			KvGetString(listHandle, NULL_STRING, search, sizeof(search));


			// Any data?
			if (!StrEqual(search, ""))
			{
				// Escape search
				SQL_EscapeString(g_hDatabase, search, searchBuffer, sizeof(searchBuffer));
				EscapeString(searchBuffer, '_', '?', searchFinal, sizeof(searchFinal));



				// whitelist?
				if (StrEqual(section, "whitelist", false))
				{
					Format(searchFinal, sizeof(searchFinal), "AND `mapdl_maps`.`mapname` LIKE '%s' ESCAPE '?' ", searchFinal);
					StrCat(g_sWhitelistMaps, sizeof(g_sWhitelistMaps), searchFinal);
				}

				// blacklist
				else if (StrEqual(section, "blacklist", false))
				{
					Format(searchFinal, sizeof(searchFinal), "AND `mapdl_maps`.`mapname` NOT LIKE '%s' ESCAPE '?' ", searchFinal);
					StrCat(g_sBlacklistMaps, sizeof(g_sBlacklistMaps), searchFinal);
				}
			}
		} 
		while (KvGotoNextKey(listHandle, false));
	}
}





// Deletes complete path
// Recursive method
public DeletePath(String:path[])
{
	// Name buffer
	decl String:buffer[128];


	// Open dir
	new Handle:dir = OpenDirectory(path);


	// Found?
	if (dir != INVALID_HANDLE)
	{
		// What we found?
		new FileType:type;


		// While found something
		while (ReadDirEntry(dir, buffer, sizeof(buffer), type))
		{
			// Maybe it founds relative paths
			if (!StrEqual(buffer, ".", false) && !StrEqual(buffer, "..", false))
			{
				// Append found item
				Format(buffer, sizeof(buffer), "%s/%s", path, buffer);


				if (type == FileType_Directory)
				{
					// If folder -> rescursive
					DeletePath(buffer);
				}
				else
				{
					// If file -> delete file
					DeleteFile(buffer);
				}
			}
		}

		// Close Dir handle
		CloseHandle(dir);
	}


	// Now dir should be empty, so delete it
	RemoveDir(path);
}





// Is player valid?
public bool:IsClientValid(client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client))
		{
			if (!IsFakeClient(client) && !IsClientSourceTV(client) && !IsClientReplay(client))
			{
				// He is valid
				return true;
			}
		}
	}


	// He isn't
	return false;
} 





// Is player admin?
public bool:IsClientAdmin(client)
{
	new need = ReadFlagString(g_sFlag);

	return (need <= 0 || (GetUserFlagBits(client) & need));
} 





// Sends the current status
public SendCurrentStatus()
{
	// Not finished	
	decl String:message[256];
	decl String:queue[64];
	decl String:bar[16];
	decl String:percent[64];

	new Float:current;
	new Float:total;
	new Float:per;


	// First check if finished
	if (g_Downloads[g_iCurrentDownload][DL_MODE] != MODUS_FINISH)
	{
		// Not finished	
		current = g_Downloads[g_iCurrentDownload][DL_CURRENT];
		total = g_Downloads[g_iCurrentDownload][DL_TOTAL];
		per = ((current / total) * 100.0);

		
		// modus?
		if (g_Downloads[g_iCurrentDownload][DL_MODE] == MODUS_COMPRESS)
		{
			new iTotal = GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]);
			new iCurrent = g_Downloads[g_iCurrentDownload][DL_FINISH];
			per = (float(iCurrent / iTotal) * 100.0);


			// We always need a lot of percent signs^^
			if (StrEqual(g_sGame, "css", false))
			{
				Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %i / %i", per, iCurrent, iTotal);
			}
			else if (g_hHudSync != INVALID_HANDLE)
			{
				Format(percent, sizeof(percent), "%.2f%%%%%% - %i / %i", per, iCurrent, iTotal);
			}
			else
			{
				Format(percent, sizeof(percent), "%.0f%%%%%% - %i/%i", per, iCurrent, iTotal);
			}
		}

		else if (g_Downloads[g_iCurrentDownload][DL_MODE] == MODUS_UPLOAD)
		{
			// We always need a lot of percent signs^^
			if (StrEqual(g_sGame, "css", false))
			{
				Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %.0fkB / %.0fkB - %i / %i", per, current, total, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
			}
			else if (g_hHudSync != INVALID_HANDLE)
			{
				Format(percent, sizeof(percent), "%.2f%%%%%% - %.0fkB / %.0fkB - %i / %i", per, current, total, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
			}
			else
			{
				Format(percent, sizeof(percent), "%.0f%%%%%% - %i/%i", per, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
			}
		}

		else
		{
			// We always need a lot of percent signs^^
			if (StrEqual(g_sGame, "css", false))
			{
				Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %.0fkB / %.0fkB", per, current, total);
			}
			else if (g_hHudSync != INVALID_HANDLE)
			{
				Format(percent, sizeof(percent), "%.2f%%%%%% - %.0fkB / %.0fkB", per, current, total);
			}
			else
			{
				Format(percent, sizeof(percent), "%.0f%%%%%% - %.0f/%.0f kB", per, current, total);
			}
		}

		

		// Create Bar
		Format(bar, sizeof(bar), "[");

		for (new i=1; i < 11; i++)
		{
			// Check how far we are
			if ((per / 10) >= i)
			{
				// Add bar
				Format(bar, sizeof(bar), "%s|", bar);
			}
			else
			{
				// Add space
				Format(bar, sizeof(bar), "%s ", bar);
			}
		}

		// End of bar
		Format(bar, sizeof(bar), "%s]", bar);
	}


	// Prepare Hud text
	if (g_hHudSync != INVALID_HANDLE)
	{
		SetHudTextParams(-1.0, 0.75, 7.0, 0, 200, 0, 255, 0, 0.0, 0.0, 0.0);
	}


	// Send to every valid client
	for (new i=1; i < MaxClients; i++)
	{
		// Find targets
		if (IsClientValid(i) && (g_bShow || IsClientAdmin(i)))
		{
			if (g_Downloads[g_iCurrentDownload][DL_MODE] != MODUS_FINISH)
			{
				// Format the message
				Format(queue, sizeof(queue), "%T", "Queue", i, g_iTotalDownloads - g_iCurrentDownload - 1);

				// Csgo need extra formating
				if (StrEqual(g_sGame, "css", false) || g_hHudSync != INVALID_HANDLE)
				{
					Format(message, sizeof(message), "%T: %s\n%s\n%s\n%s", g_sModes[g_Downloads[g_iCurrentDownload][DL_MODE]], i, g_Downloads[g_iCurrentDownload][DL_NAME], bar, percent, queue);
				}
				else
				{
					Format(message, sizeof(message), "%T\n%s\n%s", g_sModes[g_Downloads[g_iCurrentDownload][DL_MODE]], i, percent, queue);
				}
			}
			else
			{
				Format(message, sizeof(message), "%T", "FinishHint", i, g_Downloads[g_iCurrentDownload][DL_NAME]);
			}


			// No Hud text supported
			if (g_hHudSync == INVALID_HANDLE) 
			{
				PrintHintText(i, message);
			}
			else
			{
				// Hud Synchronizer
				ClearSyncHud(i, g_hHudSync);
				ShowSyncHudText(i, g_hHudSync, message);
			}
		}
	}
}





// The notice timer
public Action:NoticeTimer(Handle:timer, any:data)
{
	decl String:commandBuffer[64];
	

	// Only for commands with sm_
	if (StrContains(g_sCommand, "sm_", false) > -1)
	{
		// Replace sm_
		Format(commandBuffer, sizeof(commandBuffer), g_sCommand);
		ReplaceString(commandBuffer, sizeof(commandBuffer), "sm_", "");


		// Client loop
		for (new i=1; i < MaxClients; i++)
		{
			// Valid and admin?
			if (IsClientValid(i) && IsClientAdmin(i))
			{
				// Print
				CPrintToChat(i, "%s %t", g_sTagChat, "Notice", commandBuffer, commandBuffer);
				CPrintToChat(i, "%s %t", g_sTagChat, "NoticeDetail");
			}
		}


		// Continue
		return Plugin_Continue;
	}


	// If not, stop timer
	return Plugin_Handled;
}





// Gets the filename of a path or the last dir
public GetFileName(const String:path[], String:buffer[], size)
{
	// Empty?
	if (path[0] == '\0')
	{
		buffer[0] = '\0';

		return;
	}
	

	// Linux
	new pos = FindCharInString(path, '/', true);
	
	// Windows
	if (pos == -1) 
	{
		pos = FindCharInString(path, '\\', true);
	}
	
	// Correct start
	pos++;
	

	// Copy File Name
	strcopy(buffer, size, path[pos]);
}






// Renames a map correctly
public FixMapName(String:map[], size)
{
	// Len of string
	new len = strlen(map);

	// For every char in string
	for (new i=0; i < len; i++)
	{
		// Upper to lower
		if (IsCharUpper(map[i]))
		{
			map[i] = CharToLower(map[i]);
		}
	}

	// No replace spaces
	ReplaceString(map, size, " ", "");
}






// Checks if a strings end with specific string
public bool:StrEndsWith(String:str[], String:str2[])
{
	// Len of strings
	new len = strlen(str);
	new len2 = strlen(str2);
	new start = len - len2;


	// len2 can't be greather than len
	if (start < 0)
	{
		return false;
	}

	// If len is equal, check string equal
	if (start == 0)
	{
		return StrEqual(str, str2, false);
	}


	// For every char in string
	for (new i=0; i < len2; i++)
	{
		// Check if one char isn't equal
		if (str[start+i] != str2[i])
		{
			return false;
		}
	}


	// if we come until here, it's true
	return true;
}


























/*
**************

MENU

**************
*/



// Menu should open now
public Action:OpenMenu(client, args)
{
	if (g_bDBLoaded)
	{
		if (IsClientValid(client))
		{
			// Max. 20 downloads
			if (g_iTotalDownloads == 20)
			{
				CPrintToChat(client, "%s %t", g_sTagChat, "Wait");

				return Plugin_Handled;
			}


			// Reset Data
			strcopy(g_sSearch[client][SEARCH], sizeof(g_sSearch[][]), "");
			strcopy(g_sSearch[client][SEARCHREAL], sizeof(g_sSearch[][]), "");
			Format(g_sSearch[client][CAT_ID], sizeof(g_sSearch[][]), "");


			// Do we want to search something?
			decl String:argument[64];
			decl String:argumentEscaped[256];
			decl String:argumentEscapedBuffer[256];

			GetCmdArgString(argument, sizeof(argument));


			// Is a argument given?
			if (!StrEqual(argument, ""))
			{
				SQL_EscapeString(g_hDatabase, argument, argumentEscapedBuffer, sizeof(argumentEscapedBuffer));
				EscapeString(argumentEscapedBuffer, '_', '?', argumentEscaped, sizeof(argumentEscaped));


				// Auto append?
				if (g_bSearch)
				{
					Format(argumentEscaped, sizeof(argumentEscaped), "%%%s%%", argumentEscaped);
				}


				// Set Search string
				strcopy(g_sSearch[client][SEARCH], sizeof(g_sSearch[][]), argumentEscaped);
				strcopy(g_sSearch[client][SEARCHREAL], sizeof(g_sSearch[][]), argument);
			}



			// Mark menu position
			g_iLast[client][0] = 0;

			
			// Send Categorie list
			SendCategories(client);
		}
	}
	else
	{
		// Db is not loaded, yet
		CPrintToChat(client, "%s %t", g_sTagChat, "DBWait");
	}


	// Finish
	return Plugin_Handled;
}











// Send the categories to the client
public SendCategories(client)
{
	decl String:query[4096];
	

	// Reset map menu pos
	g_iLast[client][1] = 0;


	// No searching?
	if (StrEqual(g_sSearch[client][SEARCH], ""))
	{
		// Send all categories
		Format(query, sizeof(query), g_sAllCategories, g_sGameSearch, g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
	}
	else
	{
		// Search for a map
		Format(query, sizeof(query), g_sSearchCategories, g_sGameSearch, g_sSearch[client][SEARCH], g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
	}


	// Execute
	SQL_TQuery(g_hDatabase, OnSendCategories, query, client);
}





// Categories to menu
public OnSendCategories(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (IsClientValid(client))
	{
		// Valid answer?
		if (hndl != INVALID_HANDLE)
		{
			// Do we found something?
			if (SQL_FetchRow(hndl))
			{
				// Create menu
				new Handle:menu = CreateMenu(OnCategorieChoose);
				decl String:id[16];
				decl String:name[128];
				decl String:item[128 + 32];


				// Title
				if (StrEqual(g_sSearch[client][SEARCH], ""))
				{
					SetMenuTitle(menu, "%T", "ChooseTyp", client);
				}
				else
				{
					SetMenuTitle(menu, "%T", "Found", client, g_sSearch[client][SEARCHREAL]);
				}



				do
				{
					// Fetch results
					SQL_FetchString(hndl, 0, id, sizeof(id));
					SQL_FetchString(hndl, 1, name, sizeof(name));


					// Add to menu
					Format(item, sizeof(item), "%s (%i %T)", name, SQL_FetchInt(hndl, 2), "Maps", client);
					
					AddMenuItem(menu, id, item);
				} 
				while (SQL_FetchRow(hndl));


				// Now send menu at last positon
				DisplayMenuAtItem(menu, client, g_iLast[client][0], MENU_TIME_FOREVER);
			}
			else
			{
				// Found nothing!
				CPrintToChat(client, "%s %t", g_sTagChat, "Empty", g_sSearch[client][SEARCHREAL]);
			}
		}
		else
		{
			// Log error
			LogError("Couldn't execute categorie query. Error: %s", error);
		}
	} 
}





// Client pressed categorie
public OnCategorieChoose(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientValid(param1))
	{
		decl String:choose[10];


		// Get Choice
		GetMenuItem(menu, param2, choose, sizeof(choose));


		// Save to client and send maps menu
		g_iLast[param1][0] = GetMenuSelectionPosition();
		Format(g_sSearch[param1][CAT_ID], sizeof(g_sSearch[][]), choose);


		// Send Maps of categorie
		SendMaps(param1);
	}
	else if (action == MenuAction_End)
	{
		// Close handle on End
		CloseHandle(menu);
	}
}










// Send maps to client
public SendMaps(client)
{
	if (IsClientValid(client))
	{
		decl String:query[2048 + 512];

		// Reset Data
		Format(g_sSearch[client][MAPNAME], sizeof(g_sSearch[][]), "");
		Format(g_sSearch[client][MAPFILE], sizeof(g_sSearch[][]), "");
		Format(g_sSearch[client][MAPID], sizeof(g_sSearch[][]), "");
		Format(g_sSearch[client][MAPSIZE], sizeof(g_sSearch[][]), "");
		Format(g_sSearch[client][GAME], sizeof(g_sSearch[][]), "");

		
		// No searching?
		if (StrEqual(g_sSearch[client][SEARCH], ""))
		{
			Format(query, sizeof(query), g_sAllMaps, StringToInt(g_sSearch[client][CAT_ID]), g_sWhitelistMaps, g_sBlacklistMaps);
		}
		else
		{
			// Search
			Format(query, sizeof(query), g_sSearchMaps, g_sSearch[client][SEARCH], StringToInt(g_sSearch[client][CAT_ID]), g_sWhitelistMaps, g_sBlacklistMaps);
		}


		// Execute
		SQL_TQuery(g_hDatabase, OnSendMaps, query, client);
	}
}





// Maps to menu
public OnSendMaps(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (IsClientValid(client))
	{
		if (hndl != INVALID_HANDLE)
		{
			// Do we found something?
			if (SQL_FetchRow(hndl))
			{
				// Create menu
				new Handle:menu = CreateMenu(OnMapChoose);

				decl String:id[16];
				decl String:game[16];
				decl String:name[128];
				decl String:file[128];
				decl String:size[32];
				decl String:item[128 + 16];
				decl String:item2[128 + 128 + 32 + 16 + 16];

				
				// Title
				SetMenuTitle(menu, "%T", "ChooseMap", client);
				SetMenuExitBackButton(menu, true);


				do
				{
					// Fetch results
					SQL_FetchString(hndl, 0, name, sizeof(name));
					SQL_FetchString(hndl, 1, id, sizeof(id));
					SQL_FetchString(hndl, 2, file, sizeof(file));
					SQL_FetchString(hndl, 3, size, sizeof(size));
					SQL_FetchString(hndl, 4, game, sizeof(game));


					// Replace < in name
					ReplaceString(name, sizeof(name), "<", "", false);


					// Add to menu
					Format(item, sizeof(item), "%s (%s)", name, size);
					
					// This is tricky, add all needed data to the callback parameter
					// Non of these data has currently a '<' in it
					Format(item2, sizeof(item2), "%s<%s<%s<%s<%s", file, id, name, size, game);

					AddMenuItem(menu, item2, item);
				}
				while (SQL_FetchRow(hndl));


				// Now send menu
				DisplayMenuAtItem(menu, client, g_iLast[client][1], MENU_TIME_FOREVER);
			}
			else
			{
				// Found nothing!
				CPrintToChat(client, "%s %t", g_sTagChat, "Empty", g_sSearch[client][SEARCHREAL]);
			}
		}
		else
		{
			// Something went wrong
			LogError("Couldn't execute maps query. Error: %s", error);
		}
	} 
}





// Client pressed a map
public OnMapChoose(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientValid(param1))
	{
		decl String:choose[128 + 128 + 32 + 16 + 16];
		decl String:splits[5][128];
		decl String:item[64];


		// Get choice
		GetMenuItem(menu, param2, choose, sizeof(choose));


		// Explode choice again
		ExplodeString(choose, "<", splits, sizeof(splits), sizeof(splits[]));


		// Save Data
		g_iLast[param1][1] = GetMenuSelectionPosition();

		// Now save download information
		Format(g_sSearch[param1][MAPFILE], sizeof(g_sSearch[][]), splits[0]);
		Format(g_sSearch[param1][MAPID], sizeof(g_sSearch[][]), splits[1]);
		Format(g_sSearch[param1][MAPNAME], sizeof(g_sSearch[][]), splits[2]);
		Format(g_sSearch[param1][MAPSIZE], sizeof(g_sSearch[][]), splits[3]);
		Format(g_sSearch[param1][GAME], sizeof(g_sSearch[][]), splits[4]);


		// Create confirm menu
		new Handle:menuNew = CreateMenu(OnDecide);

		// Title and back button
		SetMenuTitle(menuNew, "%T", "Download", param1, splits[2], splits[3]);
		SetMenuExitBackButton(menuNew, true);

		// Items
		Format(item, sizeof(item), "%T", "Yes", param1);
		AddMenuItem(menuNew, "1", item);

		Format(item, sizeof(item), "%T", "Motd", param1);
		AddMenuItem(menuNew, "2", item);


		
		// Display Menu
		DisplayMenu(menuNew, param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Cancel)
	{
		// Pressed back
		if (param2 == MenuCancel_ExitBack && IsClientValid(param1))
		{
			// Send Categorie Panel
			SendCategories(param1);
		}
	}
	else if (action == MenuAction_End)
	{
		// Close handle on End
		CloseHandle(menu);
	}
}





// Player decided to download a map
public OnDecide(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientValid(param1))
	{
		decl String:choose[16];
		decl String:motdUrl[PLATFORM_MAX_PATH + 1];
		decl String:item[64];

		new choice;



		// Get choice
		GetMenuItem(menu, param2, choose, sizeof(choose));

		choice = StringToInt(choose);



		// Choice is 2 -> Open motd
		if (choice == 2)
		{
			// Motd
			if (!StrEqual(g_sGame, "csgo", false))
			{
				Format(motdUrl, sizeof(motdUrl), "http://%s.gamebanana.com/maps/%s", g_sSearch[param1][GAME], g_sSearch[param1][MAPID]);
				ShowMOTDPanel(param1, g_sSearch[param1][MAPNAME], motdUrl, MOTDPANEL_TYPE_URL);
			}
			else
			{
				Format(motdUrl, sizeof(motdUrl), "%s?url=http://%s.gamebanana.com/maps/%s", URL_MOTD, g_sSearch[param1][GAME], g_sSearch[param1][MAPID]);
				ShowMOTDPanel(param1, g_sSearch[param1][MAPNAME], motdUrl, MOTDPANEL_TYPE_URL);
			}



			// Resend Menu
			new Handle:menuNew = CreateMenu(OnDecide);

			// Title and back button
			SetMenuTitle(menuNew, "%T", "Download", param1, g_sSearch[param1][MAPNAME], g_sSearch[param1][MAPSIZE]);
			SetMenuExitBackButton(menuNew, true);

			// Items
			Format(item, sizeof(item), "%T", "Yes", param1);
			AddMenuItem(menuNew, "1", item);

			Format(item, sizeof(item), "%T", "Motd", param1);
			AddMenuItem(menuNew, "2", item);

			
			// Display Menu
			DisplayMenu(menuNew, param1, MENU_TIME_FOREVER);
		}
		else if (choice == 1)
		{
			// Now start downloading
			StartDownloadingMap(param1, g_sSearch[param1][MAPID], g_sSearch[param1][MAPNAME], g_sSearch[param1][MAPFILE]);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		// Pressed back
		if (param2 == MenuCancel_ExitBack && IsClientValid(param1))
		{
			// Send Maps Panel
			SendMaps(param1);
		}
	}
	else if (action == MenuAction_End)
	{
		// Close handle on End
		CloseHandle(menu);
	}
}




























/*
**************

Download

**************
*/





// Now we can start
public StartDownloadingMap(client, const String:id[], const String:map[], const String:link[])
{
	decl String:savePath[PLATFORM_MAX_PATH + 1];


	// Maps on Gamebanana have an unique ID, we use this for the save path
	Format(savePath, sizeof(savePath), "%s/%s", g_sPluginPath, id);


	// Dir exists already?
	if (DirExists(savePath))
	{
		// Delete it!
		DeletePath(savePath);
	}


	// Create new
	CreateDirectory(savePath, 511);


	// Format the download destination
	GetFileName(link, savePath, sizeof(savePath));
	Format(savePath, sizeof(savePath), "%s/%s", g_sPluginPath, savePath);




	// Init download
	g_Downloads[g_iTotalDownloads][DL_CLIENT] = client;
	g_Downloads[g_iTotalDownloads][DL_FINISH] = 0;
	g_Downloads[g_iTotalDownloads][DL_CURRENT] = 0.0;
	g_Downloads[g_iTotalDownloads][DL_TOTAL] = 0.0;

	// Strings
	strcopy(g_Downloads[g_iTotalDownloads][DL_ID], 32, id);
	strcopy(g_Downloads[g_iTotalDownloads][DL_NAME], 128, map);
	Format(g_Downloads[g_iTotalDownloads][DL_FILE], 128, "http://files.gamebanana.com/maps/%s", link);
	strcopy(g_Downloads[g_iTotalDownloads][DL_SAVE], PLATFORM_MAX_PATH+1, savePath);
	
	

	// File array
	if (g_Downloads[g_iTotalDownloads][DL_FILES] != INVALID_HANDLE)
	{
		CloseHandle(g_Downloads[g_iTotalDownloads][DL_FILES]);
	}
	
	// Create new Array
	g_Downloads[g_iTotalDownloads][DL_FILES] = CreateArray(PLATFORM_MAX_PATH+1);



	// FTP File array
	if (g_Downloads[g_iTotalDownloads][DL_FTPFILES] != INVALID_HANDLE)
	{
		CloseHandle(g_Downloads[g_iTotalDownloads][DL_FTPFILES]);
	}
	
	// Create new Array
	g_Downloads[g_iTotalDownloads][DL_FTPFILES] = CreateArray(PLATFORM_MAX_PATH+1);





	// Mode
	g_Downloads[g_iTotalDownloads][DL_MODE] = MODUS_DOWNLOAD;


	
	
	// Increase total downloads
	g_iTotalDownloads++;


	// If not download in queue, start it right now
	if (g_iTotalDownloads == 1)
	{
		DownloadMap();
	}
}





// Start download
public DownloadMap()
{
	// Update current download item
	g_iCurrentDownload++;


	// Finally start download
	System2_DownloadFile(OnDownloadUpdate, g_Downloads[g_iCurrentDownload][DL_FILE], g_Downloads[g_iCurrentDownload][DL_SAVE]);
}





// Download updated
public OnDownloadUpdate(bool:finished, const String:error[], Float:dltotal, Float:dlnow, Float:ultotal, Float:ulnow)
{
	// Finished with Error?
	if (finished && !StrEqual(error, ""))
	{
		if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
		{
			CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Failed", error);
		}

		// Stop
		StopDownload();
	}
	else
	{
		// finished?
		if (finished)
		{
			decl String:extractPath[PLATFORM_MAX_PATH + 1];
			
			// Create path to extract to, this is the unique path
			Format(extractPath, sizeof(extractPath), "%s/%s", g_sPluginPath, g_Downloads[g_iCurrentDownload][DL_ID]);

			
			// Now extract it
			System2_ExtractArchive(OnExtracted, g_Downloads[g_iCurrentDownload][DL_SAVE], extractPath);
		}
		else
		{
			// Save the download bytes in kilobytes
			g_Downloads[g_iCurrentDownload][DL_CURRENT] = dlnow / 1024.0;
			g_Downloads[g_iCurrentDownload][DL_TOTAL] = dltotal / 1024.0;

			// Show status
			SendCurrentStatus();
		}
	}
}





// Stop download and go to next one
public StopDownload()
{
	// Is another download in queue?
	if (g_iCurrentDownload + 1 < g_iTotalDownloads)
	{
		// Start Download
		DownloadMap();
	}
	else
	{
		// If not -> reset data
		g_iTotalDownloads = 0;
		g_iCurrentDownload = -1;
	}
}
































/*
**************

Extract

**************
*/




// Extract Status
public OnExtracted(const String:output[], const size, CMDReturn:status)
{
	// Extract finished?
	if (status != CMD_PROGRESS)
	{
		// Error?
		if (status == CMD_ERROR)
		{
			if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
			{
				CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Failed", output);
			}

			// Stop
			StopDownload();
		}
		else
		{
			// Doesn't seems so
			decl String:extractPath[PLATFORM_MAX_PATH + 1];
			

			// Format unique file path
			Format(extractPath, sizeof(extractPath), "%s/%s", g_sPluginPath, g_Downloads[g_iCurrentDownload][DL_ID]);


			// Now search for extracted files and folders
			if (SearchForFolders(extractPath, false))
			{
				// We need to find at least a .bsp file!

				// Do we need to add files to downloadlist?
				if (g_bDownloadList)
				{
					// Yes ^^
					decl String:dllistFile[PLATFORM_MAX_PATH + 1];
					decl String:content[64];
					decl String:readbuffer[64];

					new Handle:file;
					new bool:duplicate;

					new arraySize = GetArraySize(g_Downloads[g_iCurrentDownload][DL_FTPFILES]);


					// Path to downloadlist
					BuildPath(Path_SM, dllistFile, sizeof(dllistFile), "mapdownload/downloadlist.txt");



					// Do we need to create the file first?
					if (!FileExists(dllistFile))
					{
						file = OpenFile(dllistFile, "w+b");
					}
					else
					{
						// Open read and append
						file = OpenFile(dllistFile, "r+b");
					}


					// We could open file
					if (file != INVALID_HANDLE)
					{
						// Loop through files
						for (new i=0; i < arraySize; i++)
						{
							// First get content
							GetArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], i, content, sizeof(content));


							// No .bsp or .nav files
							if (!StrEndsWith(content, ".nav") && !StrEndsWith(content, ".bsp") && !StrEndsWith(content, ".txt"))
							{
								// Set File pointer to start
								FileSeek(file, 0, SEEK_SET);

								// Resetz duplicate
								duplicate = false;


								// Loop through file content and search if file already in downloadlist
								while (!IsEndOfFile(file) && ReadFileLine(file, readbuffer, sizeof(readbuffer)))
								{
									// Replace line ends
									ReplaceString(readbuffer, sizeof(readbuffer), "\n", "");
									ReplaceString(readbuffer, sizeof(readbuffer), "\t", "");
									ReplaceString(readbuffer, sizeof(readbuffer), "\r", "");


									// No comments or spaces at start
									if (readbuffer[0] == '/' || readbuffer[0] == ' ')
									{
										continue;
									}


									if (StrEqual(content, readbuffer, false))
									{
										// Found duplicate!
										duplicate = true;

										// Stop
										break;
									}
								}


								// If not in file already, add it
								if (!duplicate)
								{
									WriteFileLine(file, content);

									// Add to download table
									AddFileToDownloadsTable(content);
								}
							}
						}


						// Close File
						CloseHandle(file);
					}
				}



				// Using ftp?
				if (g_bFTP)
				{
					// Now Upload it to the Fast DL Server
					// First Compress all files
					decl String:file[128];
					decl String:archive[128];
					
					
					// Set new mode
					g_Downloads[g_iCurrentDownload][DL_MODE] = MODUS_COMPRESS;


					// Show status
					SendCurrentStatus();
					
					
					// Get first File
					GetArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], 0, file, sizeof(file));
					
					// Get Archive
					Format(archive, sizeof(archive), "%s.bz2", file);
					
					// Compress
					// Next step is in OnCompressed when every file is compressed
					System2_CompressFile(OnCompressed, file, archive, ARCHIVE_BZIP2, LEVEL_3);
				}
				else
				{
					// Mark as finished
					g_Downloads[g_iCurrentDownload][DL_MODE] = MODUS_FINISH;


					// No uploading.
					// We are finished :)
					if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
					{
						CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Finish", g_Downloads[g_iCurrentDownload][DL_NAME]);
					}

					SendCurrentStatus();


					// Stop here
					StopDownload();
				}
			}
			else
			{
				// We found no .bsp file...
				if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
				{
					CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Invalid");
				}

				StopDownload();
			}
		}
	}
}







/*
	Searching for folders and files
	We can only copy known folders, because we can't know the path of a single file.
	We only know where to put .bsp and .nav files
*/
public bool:SearchForFolders(String:path[], bool:found)
{
	decl String:newPath[PLATFORM_MAX_PATH + 1];
	decl String:content[128];


	// Open current dir
	new Handle:dir = OpenDirectory(path);
	new FileType:type;



	if (dir != INVALID_HANDLE)
	{
		// Read extract path
		while (ReadDirEntry(dir, content, sizeof(content), type))
		{
			// No relative paths
			if (!StrEqual(content, ".") && !StrEqual(content, ".."))
			{
				// Append found item to path
				Format(newPath, sizeof(newPath), "%s/%s", path, content);
				

				// Check possible folders
				if ((StrEqual(content, "sound") || StrEqual(content, "scripts") || StrEqual(content, "models") || StrEqual(content, "materials") || StrEqual(content, "resource")) && type == FileType_Directory) 
				{
					// Copy thos folder to game dir
					CopyToGameDir(newPath, content);
				}


				// Nav file?
				else if (StrEndsWith(content, ".nav") && type == FileType_File)
				{
					// Add File to file list, for uploading
					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], newPath);


					// Fix Map name
					FixMapName(content, sizeof(content));


					// Copy nav to maps folder
					Format(content, sizeof(content), "maps/%s", content);

					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], content);
					System2_CopyFile(CopyFinished, newPath, content);
				}

				// txt file?
				else if (StrEndsWith(content, ".txt") && type == FileType_File)
				{
					// Add File to file list, for uploading
					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], newPath);


					// Fix Map name
					FixMapName(content, sizeof(content));


					// Copy txt to maps folder
					Format(content, sizeof(content), "maps/%s", content);

					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], content);
					System2_CopyFile(CopyFinished, newPath, content);
				}

				// Map file
				else if (StrEndsWith(content, ".bsp") && type == FileType_File)
				{
					decl String:buff[128];


					// Add File to file list, for uploading
					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], newPath);


					// Fix Map name
					FixMapName(content, sizeof(content));


					// Copy map to maps folder
					Format(buff, sizeof(buff), "maps/%s", content);

					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], buff);
					System2_CopyFile(CopyFinished, newPath, buff);



					
					// Maybe auto add it to the mapcycle file
					// Maplist doesn't exist anymore and mani's votemaplist also not
					if (g_bMapCycle)
					{
						// File
						decl String:readbuffer[128];
						new Handle:mapcycle = INVALID_HANDLE;


						// We don't need the .bsp extension^^
						ReplaceString(content, sizeof(content), ".bsp", "");


						// After steam pipe update mapcycle file is in cfg folder
						if (FileExists("cfg/mapcycle.txt"))
						{
							// Write to mapcycle
							mapcycle = OpenFile("cfg/mapcycle.txt", "r+b");
						}

						// But the old path is also possible
						else
						{
							// Write to mapcycle
							mapcycle = OpenFile("mapcycle.txt", "r+b");
						}


						// Found valid mapcycle?
						if (mapcycle != INVALID_HANDLE)
						{
							// Search for duplicate
							new bool:duplicate = false;


							while (!IsEndOfFile(mapcycle) && ReadFileLine(mapcycle, readbuffer, sizeof(readbuffer)))
							{
								// Replace line ends
								ReplaceString(readbuffer, sizeof(readbuffer), "\n", "");
								ReplaceString(readbuffer, sizeof(readbuffer), "\t", "");
								ReplaceString(readbuffer, sizeof(readbuffer), "\r", "");


								// No comments
								if (readbuffer[0] == '/' || readbuffer[0] == ' ')
								{
									continue;
								}


								if (StrEqual(content, readbuffer, false))
								{
									// Found duplicate!
									duplicate = true;

									// Stop
									break;
								}
							}


							// If not in mapcycle, add it
							if (!duplicate)
							{
								WriteFileLine(mapcycle, content);
							}

							// Close
							CloseHandle(mapcycle);
						}
					}

					



					// Notice new map, so admin know it's base name
					if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
					{
						CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "FoundMap", content);
					}

					// Yes, we found a a .bsp file :) 
					found = true;
				}

				else if (type == FileType_Directory) 
				{
					// Go on searching, keep found in memory
					found = SearchForFolders(newPath, found);
				}
			}
		}


		// Close handle
		CloseHandle(dir);
	}


	// Found .bsp?
	return found;
}










/*
**************

Copying

**************
*/




// This allow us to copy a known folder to the gamedir
public CopyToGameDir(const String:path[], const String:cur[])
{
	// Name buffer
	decl String:buffer[128];
	decl String:file[128];

	// Open dir
	new Handle:dir = OpenDirectory(path);




	// First create current path in gamedir
	if (!DirExists(cur))
	{
		CreateDirectory(cur, 511);
	}



	// Should never be a INVALID_HANDLE
	if (dir != INVALID_HANDLE)
	{
		// What we found?
		new FileType:type;

		
		// While found something
		while (ReadDirEntry(dir, buffer, sizeof(buffer), type))
		{
			// No relative paths
			if (!StrEqual(buffer, ".", false) && !StrEqual(buffer, "..", false))
			{
				// Append found item
				Format(file, sizeof(file), "%s/%s", cur, buffer);
				Format(buffer, sizeof(buffer), "%s/%s", path, buffer);


				if (type == FileType_Directory)
				{
					// If folder -> rescursive
					CopyToGameDir(buffer, file);
				}
				else
				{
					// If file -> copy file to current dir
					System2_CopyFile(CopyFinished, buffer, file);

					// Update file count
					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], buffer);
					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], file);
				}
			}
		}
	}


	// Close Handle
	CloseHandle(dir);
}





// Copy finished
public CopyFinished(bool:success, String:from[], String:to[])
{
	// We only log any errors
	if (!success)
	{
		LogError("Couldn't copy file %s to %s!", from, to);
	}
}


























/*
**************

Compressing and Uploading

**************
*/








// Compress updated
public OnCompressed(const String:output[], const size, CMDReturn:status)
{
	// Compressing finished?
	if (status != CMD_PROGRESS)
	{
		// Error?
		if (status == CMD_ERROR)
		{
			if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
			{
				CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Failed", output);
			}

			// Stop
			StopDownload();
		}
		else
		{
			// Compress next file
			decl String:file[PLATFORM_MAX_PATH + 1];
			decl String:archive[PLATFORM_MAX_PATH + 1];
			
			
			// Update compressed files
			g_Downloads[g_iCurrentDownload][DL_FINISH]++;


			// Show status
			SendCurrentStatus();


			// All files compressed?
			if (g_Downloads[g_iCurrentDownload][DL_FINISH] == GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]))
			{
				// Clean counter, we need it another time ;)
				g_Downloads[g_iCurrentDownload][DL_FINISH] = 0;
	
	
				// Get first File
				GetArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], 0, file, sizeof(file));
				GetArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], 0, archive, sizeof(archive));


				// Get Archive and remote path
				Format(file, sizeof(file), "%s.bz2", file);
				Format(archive, sizeof(archive), "%s/%s.bz2", g_sFTPPath, archive);


				// Set new mode
				g_Downloads[g_iCurrentDownload][DL_MODE] = MODUS_UPLOAD;

				

				// Upload this file
				// Next step is in OnUploadProgress when every file is uploaded
				System2_UploadFTPFile(OnUploadProgress, file, archive, g_sFTPHost, g_sFTPUser, g_sFTPPW, g_iFTPPort);
			}
			else
			{
				// Get next File
				GetArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], g_Downloads[g_iCurrentDownload][DL_FINISH], file, sizeof(file));
				

				// Get Archive
				Format(archive, sizeof(archive), "%s.bz2", file);


				// Compress
				// Next step is in OnCompressed when every file is compressed
				System2_CompressFile(OnCompressed, file, archive, ARCHIVE_BZIP2, LEVEL_3);
			}
		}
	}
}







// Download updated
public OnUploadProgress(bool:finished, const String:error[], Float:dltotal, Float:dlnow, Float:ultotal, Float:ulnow)
{
	// Finished with Error?
	if (finished && !StrEqual(error, ""))
	{
		if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
		{
			CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Failed", error);
		}

		// Stop
		StopDownload();
	}
	else
	{
		// finished?
		if (finished)
		{
			// Upload next file
			decl String:file[PLATFORM_MAX_PATH + 1];
			decl String:archive[PLATFORM_MAX_PATH + 1];
			
			
			// Update uploaded files
			g_Downloads[g_iCurrentDownload][DL_FINISH]++;


			// All files uploaded?
			if (g_Downloads[g_iCurrentDownload][DL_FINISH] == GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]))
			{
				// Mark as finished
				g_Downloads[g_iCurrentDownload][DL_MODE] = MODUS_FINISH;


				// Update status
				SendCurrentStatus();

	
				// We are finished :)
				if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
				{
					CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Finish", g_Downloads[g_iCurrentDownload][DL_NAME]);
				}

				// Stop here
				StopDownload();
			}
			else
			{
				// Get next File
				GetArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], g_Downloads[g_iCurrentDownload][DL_FINISH], file, sizeof(file));
				GetArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], g_Downloads[g_iCurrentDownload][DL_FINISH], archive, sizeof(archive));


				// Show status
				SendCurrentStatus();


				// Get Archive and remote path
				Format(file, sizeof(file), "%s.bz2", file);
				Format(archive, sizeof(archive), "%s/%s.bz2", g_sFTPPath, archive);


				// Upload this file
				System2_UploadFTPFile(OnUploadProgress, file, archive, g_sFTPHost, g_sFTPUser, g_sFTPPW, g_iFTPPort);
			}
		}
		else
		{
			// Save the download bytes in kilobytes
			g_Downloads[g_iCurrentDownload][DL_CURRENT] = ulnow / 1024.0;
			g_Downloads[g_iCurrentDownload][DL_TOTAL] = ultotal / 1024.0;

			// Show status
			SendCurrentStatus();
		}
	}
}