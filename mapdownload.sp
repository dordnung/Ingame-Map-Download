/**
 * -----------------------------------------------------
 * File			mapdownload.sp
 * Authors		David <popoklopsi> Ordnung
 * License		GPLv3
 * Web			http://popoklopsi.de
 * -----------------------------------------------------
 * 
 * 
 * Copyright (C) 2013-2014 David <popoklopsi> Ordnung
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

// Cookie for config
#undef REQUIRE_PLUGIN
#include <clientprefs>

// Maybe include the updater if exists
#include <updater>




// Using Semicolons
#pragma semicolon 1




// Table Version
#define TABLE_VERSION "2"


// URLs
#define UPDATE_URL_PLUGIN "http://popoklopsi.de/mapdl/update.txt"
#define UPDATE_URL_DB "http://popoklopsi.de/mapdl/v2/gamebanana.sq3"
#define URL_MOTD "http://popoklopsi.de/mapdl/motd.php"


// Client menu store defines
#define SEARCH 0
#define SEARCHREAL 1
#define CAT_ID 2
#define MAPNAME 3
#define MAPFILE 4
#define MAPID 5
#define MAPSIZE 6
#define DATE 7
#define MDATE 8
#define DOWNLOADS 9
#define RATING 10
#define VOTES 11
#define VIEWS 12
#define GAME 13
#define CUSTOM 14
#define TITLE 15
#define CURRENT_MENU 16
#define NUMBER_ELEMENTS 17






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
	DL_CLIENT,                                  // Client of current download
	DL_FINISH,                                  // Finished files
	Float:DL_CURRENT,                           // Current Bytes
	Float:DL_TOTAL,                             // Total bytes
	Modus:DL_MODE,                              // Current dl Modes
	String:DL_ID[32],                           // Map ID
	String:DL_NAME[128],                        // Map Name
	String:DL_FILE[PLATFORM_MAX_PATH + 1],      // Download Link
	String:DL_SAVE[PLATFORM_MAX_PATH + 1],      // Path to save to
	Handle:DL_FILES,                            // Array to store files
	Handle:DL_FTPFILES                          // Array to store ftp files
}







// Global download list
new g_Downloads[20][DownloadInfo];


// Global strings
new String:g_sVersion[] = "2.2.0";
new String:g_sModes[][] = {"Downloading", "Uploading", "Compressing"};
new String:g_sGameSearch[64];
new String:g_sClientConfig[MAXPLAYERS + 1][256];
new String:g_sPluginPath[PLATFORM_MAX_PATH + 1];
new String:g_sCommand[32];
new String:g_sCommandCustom[32];
new String:g_sFTPCommand[32];
new String:g_sTag[32];
new String:g_sTagChat[64];
new String:g_sFlag[32];
new String:g_sFTPHost[128];
new String:g_sFTPUser[64];
new String:g_sFTPPW[128];
new String:g_sFTPPath[PLATFORM_MAX_PATH + 1];
new String:g_sGame[12];
new String:g_sSearch[MAXPLAYERS + 1][NUMBER_ELEMENTS][64];
new String:g_sLogin[MAXPLAYERS + 1][2][64];
new String:g_sWhitelistMaps[1024];
new String:g_sBlacklistMaps[1024];
new String:g_sWhitelistCategories[1024];
new String:g_sBlacklistCategories[1024];
new String:g_sLogPath[PLATFORM_MAX_PATH + 1];


// Global bools
new bool:g_bShow;
new bool:g_bMapCycle;
new bool:g_bNotice;
new bool:g_bFTP;
new bool:g_bFTPLogin;
new bool:g_bFirst;
new bool:g_bUpdate;
new bool:g_bUpdateDB;
new bool:g_bDBLoaded;
new bool:g_bSearch;
new bool:g_bDownloadList;
new bool:g_bUseCustom;
new bool:g_bClientprefsAvailable;


// Global ints
new g_iFTPPort;
new g_iTotalDownloads;
new g_iCurrentDownload;
new g_iShowColor[4];
new g_iLast[MAXPLAYERS + 1][2];
new g_iCurrentNotice;
new g_iDatabaseRetries;
new g_iDatabaseTries;


// Global handles
new Handle:g_hSearch;
new Handle:g_hCommand;
new Handle:g_hCommandCustom;
new Handle:g_hUpdate;
new Handle:g_hUpdateDB;
new Handle:g_hTag;
new Handle:g_hFlag;
new Handle:g_hShow;
new Handle:g_hShowColor;
new Handle:g_hMapCycle;
new Handle:g_hNotice;
new Handle:g_hFTP;
new Handle:g_hFTPHost;
new Handle:g_hFTPUser;
new Handle:g_hFTPPW;
new Handle:g_hFTPPort;
new Handle:g_hFTPPath;
new Handle:g_hDatabase;
new Handle:g_hHudSync;
new Handle:g_hDownloadList;
new Handle:g_hFTPLogin;
new Handle:g_hFTPCommand;
new Handle:g_hDatabaseRetries;
new Handle:g_hConfigCookie;




// Database querys
// Check if database is valid
new String:g_sDatabaseCheck[] = "SELECT \
                        `mapdl_categories_v2`.`id`, `mapdl_categories_v2`.`name`, `mapdl_categories_v2`.`game`, \
                        `mapdl_maps_v2`.`id`,  `mapdl_maps_v2`.`categories_id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, \
                        `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_info_v2`.`table_version` \
                        FROM `mapdl_categories_v2`, `mapdl_maps_v2`, `mapdl_info_v2` LIMIT 1";


// Check if database is current version
new String:g_sDatabaseCheckVersion[] = "SELECT `table_version` FROM `mapdl_info_v2`";


// Get all categories
new String:g_sAllCategories[] = "SELECT \
                        `mapdl_categories_v2`.`id`, `mapdl_categories_v2`.`name`, COUNT(`mapdl_maps_v2`.`name`) FROM `mapdl_categories_v2`, `mapdl_maps_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_categories_v2`.`id`=`mapdl_maps_v2`.`categories_id` %s%s%s%s GROUP BY `mapdl_categories_v2`.`name`";


// Search for a category by name
new String:g_sSearchCategories[] = "SELECT \
                        `mapdl_categories_v2`.`id`, `mapdl_categories_v2`.`name`, COUNT(`mapdl_maps_v2`.`name`) FROM `mapdl_categories_v2`, `mapdl_maps_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_categories_v2`.`id`=`mapdl_maps_v2`.`categories_id` AND `mapdl_maps_v2`.`name` \
                        LIKE '%s' ESCAPE '?' %s%s%s%s GROUP BY `mapdl_categories_v2`.`name`";


// Get all maps
new String:g_sAllMaps[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_maps_v2`.`categories_id`=%i AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s %s";


// Search for a map by name
new String:g_sSearchMapsByName[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_maps_v2`.`name` LIKE '%s' ESCAPE '?' AND `mapdl_maps_v2`.`categories_id`=%i AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s %s";


// Search for a map by date
new String:g_sSearchMapsByDate[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY `mapdl_maps_v2`.`date` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC LIMIT 100";


// Search for a map by last modification date
new String:g_sSearchMapsByMDate[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`date` != `mapdl_maps_v2`.`mdate` AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY `mapdl_maps_v2`.`mdate`DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC  LIMIT 100";


// Search for a map by downloads
new String:g_sSearchMapsByDownloads[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY `mapdl_maps_v2`.`downloads` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC LIMIT 100";


// Search for a map by views
new String:g_sSearchMapsByViews[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY `mapdl_maps_v2`.`views` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC LIMIT 100";


// Search for a map by rating
new String:g_sSearchMapsByRating[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY cast(`mapdl_maps_v2`.`rating` as float) DESC, `mapdl_maps_v2`.`votes` DESC LIMIT 100";



// Customs


// Create Customs
new String:g_sCreateCustom[] = "CREATE TABLE IF NOT EXISTS `mapdl_custom` \
                        (`id` integer PRIMARY KEY, `name` varchar(255) NOT NULL, `url` varchar(255) NOT NULL, UNIQUE (name, url))";


// Create Customs maps
new String:g_sCreateCustomMaps[] = "CREATE TABLE IF NOT EXISTS `mapdl_custom_maps` \
                        (`custom_id` tinyint NOT NULL, `file` varchar(128) NOT NULL, UNIQUE (custom_id, file))";


// Insert name and urls
new String:g_InsertCustom[] = "INSERT INTO `mapdl_custom` \
                        (`id`, `name`, `url`) VALUES (NULL, '%s', '%s')";


// Insert Maps
new String:g_InsertCustomMaps[] = "INSERT INTO `mapdl_custom_maps` (`custom_id`, `file`) \
                        SELECT `mapdl_custom`.`id`, '%s' FROM `mapdl_custom` WHERE `mapdl_custom`.`name` = '%s'";


// Get custom urls
new String:g_sAllCustom[] = "SELECT `mapdl_custom`.`id`, `mapdl_custom`.`name`, COUNT(`mapdl_custom_maps`.`file`) FROM `mapdl_custom_maps`, `mapdl_custom` \
                        WHERE `mapdl_custom`.`id` = `mapdl_custom_maps`.`custom_id` %s%s GROUP BY `mapdl_custom`.`name`";


// Get custom urls search
new String:g_sSearchCustom[] = "SELECT `mapdl_custom`.`id`, `mapdl_custom`.`name`, COUNT(`mapdl_custom_maps`.`file`) FROM `mapdl_custom_maps`, `mapdl_custom` \
                        WHERE `mapdl_custom_maps`.`file` LIKE '%s' ESCAPE '?' AND `mapdl_custom`.`id` = `mapdl_custom_maps`.`custom_id` %s%s GROUP BY `mapdl_custom`.`name`";


// Get custom maps
new String:g_sAllCustomMaps[] = "SELECT `mapdl_custom_maps`.`file`, `mapdl_custom`.`url` FROM `mapdl_custom_maps`, `mapdl_custom` \
                        WHERE `mapdl_custom_maps`.`custom_id`=%i AND `mapdl_custom`.`id` = `mapdl_custom_maps`.`custom_id` %s%s GROUP BY `mapdl_custom_maps`.`file`";


// Get custom maps search
new String:g_sSearchCustomMaps[] = "SELECT `mapdl_custom_maps`.`file`, `mapdl_custom`.`url` FROM `mapdl_custom_maps`, `mapdl_custom` \
                        WHERE `mapdl_custom_maps`.`file` LIKE '%s' ESCAPE '?' AND `mapdl_custom_maps`.`custom_id`=%i AND `mapdl_custom`.`id` = `mapdl_custom_maps`.`custom_id` %s%s GROUP BY `mapdl_custom_maps`.`file`";




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
	LoadTranslations("core.phrases");
	LoadTranslations("mapdownload.phrases");
	
	
	// First is true!
	g_bFirst = true;
	g_bDBLoaded = false;
	g_bUseCustom = false;
	g_bClientprefsAvailable = false;
	g_iCurrentNotice = 0;
	g_iDatabaseTries = 0;
	g_iShowColor = {255, 255, 255, 255};


	// Init. AutoExecConfig
	AutoExecConfig_SetFile("plugin.mapdownload");


	// Public Cvar
	AutoExecConfig_CreateConVar("mapdownload_version", g_sVersion, "Ingame Map Download Version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

	// Set Cvars
	g_hCommand = AutoExecConfig_CreateConVar("mapdownload_command", "sm_mapdl", "Command to open Map Download menu. Append prefix 'sm_' for chat use!");
	g_hCommandCustom = AutoExecConfig_CreateConVar("mapdownload_command_custom", "sm_mapdl_custom", "Command to open custom Map Download menu. Append prefix 'sm_' for chat use!");
	g_hTag = AutoExecConfig_CreateConVar("mapdownload_tag", "Map Download", "Chat prefix of Map Download");
	g_hFlag = AutoExecConfig_CreateConVar("mapdownload_flag", "bg", "Flagstring to access menu (see configs/admin_levels.cfg)");
	g_hShow = AutoExecConfig_CreateConVar("mapdownload_show", "0", "1 = All players see map downloading status, 0 = Only admins");
	g_hShowColor = AutoExecConfig_CreateConVar("mapdownload_show_color", "255,255,255,255", "RGBA Color of the HUD Text if available", FCVAR_PROTECTED);
	g_hDatabaseRetries = AutoExecConfig_CreateConVar("mapdownload_retries", "1", "Numbers of retries to load database");
	g_hSearch = AutoExecConfig_CreateConVar("mapdownload_search", "1", "1 = Search searchmask within a string, 0 = Search excact mask");
	g_hMapCycle = AutoExecConfig_CreateConVar("mapdownload_mapcycle", "1", "1 = Write downloaded map in mapcycle.txt, 0 = Off");
	g_hNotice = AutoExecConfig_CreateConVar("mapdownload_notice", "1", "1 = Notice admins on server that Map Download runs, 0 = Off");
	g_hDownloadList = AutoExecConfig_CreateConVar("mapdownload_downloadlist", "1", "1 = Add custom files of map to intern downloadlist, 0 = Off");
	g_hUpdate = AutoExecConfig_CreateConVar("mapdownload_update_plugin", "1", "1 = Auto update plugin with God Tony's autoupdater, 0 = Off");
	g_hUpdateDB = AutoExecConfig_CreateConVar("mapdownload_update_database", "1", "1 = Auto download gamebanana database on plugin start, 0 = Off");
	g_hFTP = AutoExecConfig_CreateConVar("mapdownload_ftp", "0", "1 = Use Fast Download upload, 0 = Off");
	g_hFTPLogin = AutoExecConfig_CreateConVar("mapdownload_ftp_login", "0", "1 = Player have to insert username and password of ftp server in his console (Security), 0 = Off");
	g_hFTPCommand = AutoExecConfig_CreateConVar("mapdownload_ftp_command", "mapdl_login", "Command to set username and passwort if 'mapdownload_ftp_ingame = 1'");
	g_hFTPHost = AutoExecConfig_CreateConVar("mapdownload_ftp_host", "192.168.0.1", "Host of your FastDL server", FCVAR_PROTECTED);
	g_hFTPPort = AutoExecConfig_CreateConVar("mapdownload_ftp_port", "21", "Port of your FastDL server", FCVAR_PROTECTED);
	g_hFTPUser = AutoExecConfig_CreateConVar("mapdownload_ftp_user", "username", "Username to login", FCVAR_PROTECTED);
	g_hFTPPW = AutoExecConfig_CreateConVar("mapdownload_ftp_pass", "password", "Password for username to login", FCVAR_PROTECTED);
	g_hFTPPath = AutoExecConfig_CreateConVar("mapdownload_ftp_path", "path/on/fastdl", "Path to your FastDL gamedir folder, including folders maps, sound, and so on", FCVAR_PROTECTED);



	// Exec Config
	AutoExecConfig(true, "plugin.mapdownload");

	// clean Config
	AutoExecConfig_CleanFile();
}





// Config is executed
public OnConfigsExecuted()
{
	decl String:showColor[32];
	decl String:showColorExploded[4][12];

	// Read all convars
	// Ints
	g_iFTPPort = GetConVarInt(g_hFTPPort);


	// Bools
	g_bNotice = GetConVarBool(g_hNotice);
	g_bShow = GetConVarBool(g_hShow);
	g_bMapCycle = GetConVarBool(g_hMapCycle);
	g_bFTP = GetConVarBool(g_hFTP);
	g_bFTPLogin = (GetConVarBool(g_hFTPLogin) && g_bFTP);
	g_bUpdate = GetConVarBool(g_hUpdate);
	g_bUpdateDB = GetConVarBool(g_hUpdateDB);
	g_bSearch = GetConVarBool(g_hSearch);
	g_bDownloadList = GetConVarBool(g_hDownloadList);
	g_iDatabaseRetries = GetConVarBool(g_hDatabaseRetries);


	// Strings
	GetConVarString(g_hShowColor, showColor, sizeof(showColor));
	GetConVarString(g_hCommand, g_sCommand, sizeof(g_sCommand));
	GetConVarString(g_hCommandCustom, g_sCommandCustom, sizeof(g_sCommandCustom));
	GetConVarString(g_hFTPCommand, g_sFTPCommand, sizeof(g_sFTPCommand));
	GetConVarString(g_hTag, g_sTag, sizeof(g_sTag));
	GetConVarString(g_hFlag, g_sFlag, sizeof(g_sFlag));
	GetConVarString(g_hFTPHost, g_sFTPHost, sizeof(g_sFTPHost));
	GetConVarString(g_hFTPUser, g_sFTPUser, sizeof(g_sFTPUser));
	GetConVarString(g_hFTPPW, g_sFTPPW, sizeof(g_sFTPPW));
	GetConVarString(g_hFTPPath, g_sFTPPath, sizeof(g_sFTPPath));


	// Hud Sync
	g_hHudSync = CreateHudSynchronizer();

	// Explode Colors
	new found = ExplodeString(showColor, ",", showColorExploded, sizeof(showColorExploded), sizeof(showColorExploded[]));

	if (found == 4)
	{
		new r = StringToInt(showColorExploded[0]);
		new g = StringToInt(showColorExploded[1]);
		new b = StringToInt(showColorExploded[2]);
		new a = StringToInt(showColorExploded[3]);

		if (r < 0 || r > 255)
		{
			LogError("Red Color have to be between 0 and 255 in '%s'!", showColor);
		}
		else
		{
			g_iShowColor[0] = r;
		}

		if (g < 0 || g > 255)
		{
			LogError("Green Color have to be between 0 and 255 in '%s'!", showColor);
		}
		else
		{
			g_iShowColor[1] = g;
		}

		if (b < 0 || b > 255)
		{
			LogError("Blue Color have to be between 0 and 255 in '%s'!", showColor);
		}
		else
		{
			g_iShowColor[2] = b;
		}

		if (a < 0 || a > 255)
		{
			LogError("Alpha have to be between 0 and 255 in '%s'!", showColor);
		}
		else
		{
			g_iShowColor[3] = a;
		}
	}
	else
	{
		LogError("RGBA Colors '%s' have an invalid format!", showColor);
	}


	// Add Auto Updater if exit and want
	if (LibraryExists("updater") && g_bUpdate)
	{
		Updater_AddPlugin(UPDATE_URL_PLUGIN);
	}

	// Check for clientprefs
	if (LibraryExists("clientprefs"))
	{
		g_bClientprefsAvailable = true;
		g_hConfigCookie = RegClientCookie("mapdl_config", "MapDownload Config Cookie", CookieAccess_Private);
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
		RegAdminCmd(g_sCommandCustom, OpenMenuCustom, ReadFlagString(g_sFlag));
		RegConsoleCmd(g_sFTPCommand, OnSetLoginData);

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


	// No Lightgreen?
	if (!CColorAllowed(Color_Lightgreen))
	{
		CReplaceColor(Color_Lightgreen, Color_Olive);
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



// Logging Stuff
Log(String:fmt[], any:...)
{
	decl String:format[1024];
	decl String:file[PLATFORM_MAX_PATH + 1];
	decl String:currentDate[32];


	VFormat(format, sizeof(format), fmt, 2);
	FormatTime(currentDate, sizeof(currentDate), "%d-%m-%y");
	Format(file, sizeof(file), "%s/mapdownload_(%s).log", g_sLogPath, currentDate);

	LogToFile(file, "[ MAPDL ] %s", format);
}





// Client cookies are cached
public OnClientCookiesCached(client)
{
	new config = GetClientConfigCookie(client);

	switch(config)
	{
		case 0:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY LOWER(`mapdl_maps_v2`.`name`) ASC");
		}
		case 1:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY LOWER(`mapdl_maps_v2`.`name`) DESC");
		}
		case 2:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY `mapdl_maps_v2`.`date` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC");
		}
		case 3:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY `mapdl_maps_v2`.`date` ASC, cast(`mapdl_maps_v2`.`rating` as float) ASC");
		}
		case 4:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "AND `mapdl_maps_v2`.`date` != `mapdl_maps_v2`.`mdate` ORDER BY `mapdl_maps_v2`.`mdate` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC");
		}
		case 5:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "AND `mapdl_maps_v2`.`date` != `mapdl_maps_v2`.`mdate` ORDER BY `mapdl_maps_v2`.`mdate` ASC, cast(`mapdl_maps_v2`.`rating` as float) ASC");
		}
		case 6:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY `mapdl_maps_v2`.`downloads` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC");
		}
		case 7:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY `mapdl_maps_v2`.`downloads` ASC, cast(`mapdl_maps_v2`.`rating` as float) ASC");
		}
		case 8:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY `mapdl_maps_v2`.`views` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC");
		}
		case 9:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY `mapdl_maps_v2`.`views` ASC, cast(`mapdl_maps_v2`.`rating` as float) ASC");
		}
		case 10:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY cast(`mapdl_maps_v2`.`rating` as float) DESC, `mapdl_maps_v2`.`votes` DESC");
		}
		case 11:
		{
			strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "ORDER BY cast(`mapdl_maps_v2`.`rating` as float) ASC, `mapdl_maps_v2`.`votes` ASC");
		}
	}
}





// Set Title at search
SetTitleWithCookie(client)
{
	new config = GetClientConfigCookie(client);

	switch(config)
	{
		case 0:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "0");
		}
		case 1:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "0");
		}
		case 2:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "1");
		}
		case 3:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "1");
		}
		case 4:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "2");
		}
		case 5:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "2");
		}
		case 6:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "3");
		}
		case 7:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "3");
		}
		case 8:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "4");
		}
		case 9:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "4");
		}
		case 10:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "5");
		}
		case 11:
		{
			strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "5");
		}
	}
}





// Gets the Client cookie
GetClientConfigCookie(client)
{
	// Only with clientprefs
	if (g_bClientprefsAvailable && IsClientValid(client) && AreClientCookiesCached(client))
	{
		decl String:buffer[8];

		GetClientCookie(client, g_hConfigCookie, buffer, sizeof(buffer));

		return StringToInt(buffer);
	}

	return -1;
}




// Prepare folders and connect to database
PreparePlugin()
{
	// Build plugin paths
	BuildPath(Path_SM, g_sPluginPath, sizeof(g_sPluginPath), "data/mapdownload");
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "data/mapdownload/logs");


	// Check if paths exist
	// If not, create them!
	if (!DirExists(g_sPluginPath))
	{
		CreateDirectory(g_sPluginPath, 511);
	}

	if (!DirExists(g_sLogPath))
	{
		CreateDirectory(g_sLogPath, 511);
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

	// Format Search
	Format(g_sGameSearch, sizeof(g_sGameSearch), "('%s')", g_sGame);


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
ParseDownloadList()
{
	// Parse Downloadlist
	if (g_bDownloadList)
	{
		decl String:dllistFile[PLATFORM_MAX_PATH + 1];
		decl String:readbuffer[64];

		new Handle:file;


		// Path to downloadlist
		BuildPath(Path_SM, dllistFile, sizeof(dllistFile), "data/mapdownload/downloadlist.txt");


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
			// Create Transaction
			new Handle:txn = SQL_CreateTransaction();

			SQL_AddQuery(txn, g_sDatabaseCheck, 1);
			SQL_AddQuery(txn, g_sDatabaseCheckVersion, 2);
			SQL_AddQuery(txn, g_sCreateCustom, 3);
			SQL_AddQuery(txn, g_sCreateCustomMaps, 4);

			SQL_ExecuteTransaction(g_hDatabase, txn, OnDBStartedUp, OnDBStartUpFailed);
		}
	}
}



// Everything is started up
public OnDBStartedUp(Handle:db, any:data, numQueries, Handle:results[], any:queryData[])
{
	for (new i=0; i < numQueries; i++)
	{
		if (queryData[i] == 1)
		{
			// Check valid database
			if (!SQL_FetchRow(results[i]))
			{
				LogError("Map Download database seems to be empty!");
			}
		}

		if (queryData[i] == 2)
		{
			decl String:version[16];

			// Check valid database version
			if (!SQL_FetchRow(results[i]))
			{
				LogError("Your Map Download database seems to be outdated!");
			}

			SQL_FetchString(results[i], 0, version, sizeof(version));

			if (!StrEqual(version, TABLE_VERSION, false))
			{
				LogError("Your Map Download database seems to be outdated: Found '%s', expected '%s'!", version, TABLE_VERSION);
			}
		}
	}

	// Now we can load white,black and customlist
	ParseLists();

	// Database loaded
	g_bDBLoaded = true;
}



// start up failed
public OnDBStartUpFailed(Handle:db, any:data, numQueries, const String:error[], failIndex, any:queryData[])
{
	LogError("Map Download couldn't prepare the Database. Error: '%s'", error);

	if (g_iDatabaseRetries > g_iDatabaseTries)
	{
		g_iDatabaseTries++;

		// Retrie
		PrepareDB(true, "", 0.0, 0.0, 0.0, 0.0);
	}
}



// Parse the white,black and customlist
ParseLists()
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
					Format(searchFinal, sizeof(searchFinal), "AND `mapdl_categories_v2`.`name` LIKE '%s' ESCAPE '?' ", searchFinal);
					StrCat(g_sWhitelistCategories, sizeof(g_sWhitelistCategories), searchFinal);
				}

				// blacklist
				else if (StrEqual(section, "blacklist", false))
				{
					Format(searchFinal, sizeof(searchFinal), "AND `mapdl_categories_v2`.`name` NOT LIKE '%s' ESCAPE '?' ", searchFinal);
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
					Format(searchFinal, sizeof(searchFinal), "AND `mapdl_maps_v2`.`name` LIKE '%s' ESCAPE '?' ", searchFinal);
					StrCat(g_sWhitelistMaps, sizeof(g_sWhitelistMaps), searchFinal);
				}

				// blacklist
				else if (StrEqual(section, "blacklist", false))
				{
					Format(searchFinal, sizeof(searchFinal), "AND `mapdl_maps_v2`.`name` NOT LIKE '%s' ESCAPE '?' ", searchFinal);
					StrCat(g_sBlacklistMaps, sizeof(g_sBlacklistMaps), searchFinal);
				}
			}
		} 
		while (KvGotoNextKey(listHandle, false));
	}


	// Rewind
	KvRewind(listHandle);


	// Goto custom urls
	if (KvJumpToKey(listHandle, "customurls") &&  KvGotoFirstSubKey(listHandle, false))
	{
		new Handle:sectionArray = CreateArray(128);
		new Handle:txn = SQL_CreateTransaction();

		// Loop through all items
		do
		{
			decl String:query[1024];
			decl String:section[128];
			decl String:search[128];
			decl String:sectionBuffer[256];


			// Get Section and key
			KvGetSectionName(listHandle, section, sizeof(section));
			KvGetString(listHandle, NULL_STRING, search, sizeof(search));


			// Any data?
			if (!StrEqual(search, "") && !StrEqual(section, "") )
			{
				// Yes we use it :)
				g_bUseCustom = true;


				// Remove last / if exists
				if (StrEndsWith(search, "/"))
				{
					search[strlen(search) - 1] = 0;
				}

				// Escape strings
				SQL_EscapeString(g_hDatabase, section, sectionBuffer, sizeof(sectionBuffer));


				// Get result of insert
				Format(query, sizeof(query), g_InsertCustom, sectionBuffer, search);
				SQL_AddQuery(txn, query);


				// Push Name in
				PushArrayString(sectionArray, sectionBuffer);
				PushArrayString(sectionArray, search);
			}
		} 
		while (KvGotoNextKey(listHandle, false));

		SQL_ExecuteTransaction(g_hDatabase, txn, OnAddedCustomUrls, OnAddedCustomUrlsFailed, sectionArray);
	}

	CloseHandle(listHandle);
}



// All Custom Urls added
public OnAddedCustomUrls(Handle:db, any:data, numQueries, Handle:results[], any:queryData[])
{
	decl String:sectionBuffer[128];
	decl String:search[128];

	for (new i=0; i < numQueries; i++)
	{
		GetArrayString(data, i, sectionBuffer, sizeof(sectionBuffer));
		GetArrayString(data, i+1, search, sizeof(search));

		// We need a handle to give with
		new Handle:nameArray = CreateArray(128, 0);

		// Push Name in
		PushArrayString(nameArray, sectionBuffer);
		PushArrayString(nameArray, "");


		// Now search for maps
		System2_GetPage(OnGetPage, search, "", "Ingame Map Download Searcher", nameArray);
	}

	CloseHandle(data);
}



// Custom urls couldn't be add
public OnAddedCustomUrlsFailed(Handle:db, any:data, numQueries, const String:error[], failIndex, any:queryData[])
{
	CloseHandle(data);

	LogError("Map Download couldn't add custom urls. Error: '%s'", error);
}



public OnGetPage(const String:output[], const size, CMDReturn:status, any:namer)
{
	decl String:name[128];
	decl String:part[512];
	decl String:partBuffer[1024];
	decl String:explodes[64][512];
	decl String:query[1024];
	decl String:outputFinal[size + 128 + 1];

	new found;
	new split;


	if (namer != INVALID_HANDLE)
	{
		// Get Pre String
		GetArrayString(namer, 1, name, sizeof(name));
		Format(outputFinal, (size + 128 + 1), "%s%s", name, output);

		// Empty it
		SetArrayString(namer, 1, "");


		// Get Name
		GetArrayString(namer, 0, name, sizeof(name));


		// Explode Output
		found = ExplodeString(outputFinal, "href=", explodes, sizeof(explodes), sizeof(explodes[]));


		// Go through results
		for (new i=0; i < found; i++)
		{
			split = SplitString(explodes[i], "\">", part, sizeof(part));

			if (split > 0)
			{
				ReplaceString(part, sizeof(part), "\"", "", false);
				EscapeString(part, '%', '%', partBuffer, sizeof(partBuffer));

				// Check valid
				if ((StrEndsWith(partBuffer, ".bz2") || StrEndsWith(partBuffer, ".rar") || StrEndsWith(partBuffer, ".zip") || StrEndsWith(partBuffer, ".7z")) && !StrEndsWith(partBuffer, ".txt.bz2"))
				{
					// Insert Map
					Format(query, sizeof(query), g_InsertCustomMaps, partBuffer, name);

					SQL_TQuery(g_hDatabase, SQL_CallBack, query);
				}
			}
		}


		// Finish?
		if (status != CMD_PROGRESS)
		{
			// Close Array
			CloseHandle(namer);
			namer = INVALID_HANDLE;

			if (status == CMD_ERROR)
			{
				LogError("Couldn't parse Key %s. Error: %s", name, output);
			}

		}
		else if (StrContains(explodes[found-1], "\">", false) == -1)
		{
			// Add Last Item
			Format(explodes[found-1], sizeof(explodes[]), "href=%s", explodes[found-1]);
			SetArrayString(namer, 1, explodes[found-1]);
		}
	}
}




// Callback of SQL
public SQL_CallBack(Handle:owner, Handle:hndl, const String:error[], any:data)
{
}




// Deletes complete path
// Recursive method
DeletePath(String:path[])
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
bool:IsClientValid(client)
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
bool:IsClientAdmin(client)
{
	new need = ReadFlagString(g_sFlag);
	new clientFlags = GetUserFlagBits(client);

	return (need <= 0 || (clientFlags & need) || (clientFlags & ADMFLAG_ROOT));
}



// Reset client
public OnClientConnected(client)
{
	// Reset client
	strcopy(g_sLogin[client][0], sizeof(g_sLogin[][]), "");
	strcopy(g_sLogin[client][1], sizeof(g_sLogin[][]), "");
	strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "");
}



// Sends the current status
SendCurrentStatus()
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
			if (g_hHudSync == INVALID_HANDLE && !StrEqual(g_sGame, "csgo", false) && !StrEqual(g_sGame, "dods", false))
			{
				Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %i / %i", per, iCurrent, iTotal);
			}
			else if (g_hHudSync != INVALID_HANDLE)
			{
				Format(percent, sizeof(percent), "%.2f%%%%%% - %i / %i", per, iCurrent, iTotal);
			}
			else if (StrEqual(g_sGame, "dods", false))
			{
				Format(percent, sizeof(percent), "%.2f - %i / %i", per, iCurrent, iTotal);
			}
			else
			{
				Format(percent, sizeof(percent), "%.0f%%%%%% - %i/%i", per, iCurrent, iTotal);
			}
		}

		else if (g_Downloads[g_iCurrentDownload][DL_MODE] == MODUS_UPLOAD)
		{
			// We always need a lot of percent signs^^
			if (g_hHudSync == INVALID_HANDLE && !StrEqual(g_sGame, "csgo", false) && !StrEqual(g_sGame, "dods", false))
			{
				Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %.0fkB / %.0fkB - %i / %i", per, current, total, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
			}
			else if (g_hHudSync != INVALID_HANDLE)
			{
				Format(percent, sizeof(percent), "%.2f%%%%%% - %.0fkB / %.0fkB - %i / %i", per, current, total, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
			}
			else if (StrEqual(g_sGame, "dods", false))
			{
				Format(percent, sizeof(percent), "%.2f - %.0fkB / %.0fkB - %i / %i", per, current, total, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
			}
			else
			{
				Format(percent, sizeof(percent), "%.0f%%%%%% - %i/%i", per, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
			}
		}

		else
		{
			// We always need a lot of percent signs^^
			if (g_hHudSync == INVALID_HANDLE && !StrEqual(g_sGame, "csgo", false) && !StrEqual(g_sGame, "dods", false))
			{
				Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %.0fkB / %.0fkB", per, current, total);
			}
			else if (g_hHudSync != INVALID_HANDLE)
			{
				Format(percent, sizeof(percent), "%.2f%%%%%% - %.0fkB / %.0fkB", per, current, total);
			}
			else if (StrEqual(g_sGame, "dods", false))
			{
				Format(percent, sizeof(percent), "%.2f - %.0fkB / %.0fkB", per, current, total);
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
		SetHudTextParams(-1.0, 0.75, 7.0, g_iShowColor[0], g_iShowColor[1], g_iShowColor[2], g_iShowColor[3], 0, 0.0, 0.0, 0.0);
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
				if (!StrEqual(g_sGame, "csgo", false))
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
	decl String:commandBufferCustom[64];


	// Only for commands with sm_
	if (StrContains(g_sCommand, "sm_", false) > -1)
	{
		// Replace sm_
		Format(commandBuffer, sizeof(commandBuffer), g_sCommand);
		ReplaceString(commandBuffer, sizeof(commandBuffer), "sm_", "");

		Format(commandBufferCustom, sizeof(commandBufferCustom), g_sCommandCustom);
		ReplaceString(commandBufferCustom, sizeof(commandBufferCustom), "sm_", "");


		// Client loop
		for (new i=1; i < MaxClients; i++)
		{
			// Valid and admin?
			if (IsClientValid(i) && IsClientAdmin(i))
			{
				// Print
				if (g_iCurrentNotice == 0)
				{
					CPrintToChat(i, "%s %t", g_sTagChat, "Notice", commandBuffer);
				}

				if (g_iCurrentNotice == 2)
				{
					CPrintToChat(i, "%s %t", g_sTagChat, "Notice2", commandBufferCustom);
				}

				if (g_iCurrentNotice == 1)
				{
					CPrintToChat(i, "%s %t", g_sTagChat, "Notice3");
				}
			}
		}


		// Increase
		g_iCurrentNotice++;


		if ((g_bUseCustom && g_iCurrentNotice == 3) || (!g_bUseCustom && g_iCurrentNotice == 2))
		{
			// Reset
			g_iCurrentNotice = 0;
		}


		// Continue
		return Plugin_Continue;
	}


	// If not, stop timer
	return Plugin_Handled;
}



// Gets the filename of a path or the last dir
GetFileName(const String:path[], String:buffer[], size)
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



// Checks if a strings end with specific string
bool:StrEndsWith(String:str[], String:str2[])
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



// Save Login data
public Action:OnSetLoginData(client, args)
{
	if (IsClientValid(client))
	{
		if (args == 2)
		{
			// Get username and password
			GetCmdArg(1, g_sLogin[client][0], sizeof(g_sLogin[][]));
			GetCmdArg(2, g_sLogin[client][1], sizeof(g_sLogin[][]));

			ReplyToCommand(client, "Succesfully set Login Data");
		}
		else
		{
			ReplyToCommand(client, "Usage: %s <username> <password>", g_sFTPCommand);
		}
	}


	return Plugin_Handled;
}







/*
**************

MENU

**************
*/



// Open Custom menu
public Action:OpenMenuCustom(client, args)
{
	if (g_bUseCustom)
	{
		decl String:argument[64];
		
		// Get argument
		GetCmdArgString(argument, sizeof(argument));


		// Open Menu
		PrepareMenu(client, argument, true);


		// Finish
		return Plugin_Handled;
	}

	// We don't use it
	return Plugin_Continue;
}




// Open  menu
public Action:OpenMenu(client, args)
{
	decl String:argument[64];
	
	// Get argument
	GetCmdArgString(argument, sizeof(argument));


	// Prepare Menu
	PrepareMenu(client, argument, false);


	// Finish
	return Plugin_Handled;
}





// Prepare a new menu
PrepareMenu(client, String:argument[], bool:isCustom)
{
	if (g_bDBLoaded)
	{
		if (IsClientValid(client))
		{
			// Max. 20 downloads
			if (g_iTotalDownloads == 20)
			{
				CPrintToChat(client, "%s %t", g_sTagChat, "Wait");

				return;
			}

			if (g_bFTPLogin && (StrEqual(g_sLogin[client][0], "") || StrEqual(g_sLogin[client][1], "")))
			{
				// Remember
				CPrintToChat(client, "%s %t", g_sTagChat, "Login", g_sFTPCommand);
			}

			// Check config of client
			OnClientCookiesCached(client);

			// Reset Data
			strcopy(g_sSearch[client][CUSTOM], sizeof(g_sSearch[][]), isCustom ? "1" : "0");
			strcopy(g_sSearch[client][SEARCH], sizeof(g_sSearch[][]), "");
			strcopy(g_sSearch[client][SEARCHREAL], sizeof(g_sSearch[][]), "");
			strcopy(g_sSearch[client][CAT_ID], sizeof(g_sSearch[][]), "");
			strcopy(g_sSearch[client][CURRENT_MENU], sizeof(g_sSearch[][]), "0");


			// Do we want to search something?
			decl String:argumentEscaped[256];
			decl String:argumentEscapedBuffer[256];


			// Mark menu position
			g_iLast[client][0] = 0;
			g_iLast[client][1] = 0;


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

				// Send category list
				OpenMenuWithAllMaps(client);
			}
			else if (isCustom)
			{
				OpenMenuWithAllMaps(client);
			}
			else
			{
				OpenSortChoiceMenu(client);
			}
		}
	}
	else
	{
		// Db is not loaded, yet
		CPrintToChat(client, "%s %t", g_sTagChat, "DBWait");
	}
}




// Open the choice menu
OpenSortChoiceMenu(client)
{
	decl String:display[64];

	// Create menu
	new Handle:menu = CreateMenu(OnSortChoose);

	SetMenuExitButton(menu, true);
	SetMenuExitBackButton(menu, false);
	SetMenuTitle(menu, "%T", "ChooseSortType", client);

	Format(display, sizeof(display), "%T", "AllMaps", client);
	AddMenuItem(menu, "0", display);

	Format(display, sizeof(display), "%T", "NewestMaps", client);
	AddMenuItem(menu, "1", display);

	Format(display, sizeof(display), "%T", "LatestModifiedMaps", client);
	AddMenuItem(menu, "2", display);

	Format(display, sizeof(display), "%T", "MostDownloadedMaps", client);
	AddMenuItem(menu, "3", display);

	Format(display, sizeof(display), "%T", "MostViewedMaps", client);
	AddMenuItem(menu, "4", display);

	if (g_bClientprefsAvailable)
	{
		Format(display, sizeof(display), "%T\n ", "BestRatedMaps", client);
	}
	else
	{
		Format(display, sizeof(display), "%T", "BestRatedMaps", client);
	}

	AddMenuItem(menu, "5", display);

	if (g_bClientprefsAvailable)
	{
		Format(display, sizeof(display), "%T", "SortConfig", client);
		AddMenuItem(menu, "6", display);
	}

	DisplayMenu(menu, client, 30);
}





// Client pressed a sort type
public OnSortChoose(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientValid(param1))
	{
		decl String:choose[8];

		// Get Choice
		GetMenuItem(menu, param2, choose, sizeof(choose));

		strcopy(g_sSearch[param1][CURRENT_MENU], sizeof(g_sSearch[][]), choose);

		// Check what the client want to see
		if (StrEqual(choose, "0"))
		{
			OpenMenuWithAllMaps(param1);
		}
		else if (StrEqual(choose, "6"))
		{
			// Send Maps with sort
			OpenConfigMenu(param1);
		}
		else
		{
			// Send Maps with sort
			SendMaps(param1, choose);
		}
	}
	else if (action == MenuAction_End)
	{
		// Close handle on End
		CloseHandle(menu);
	}
}




// Open the config menu
OpenConfigMenu(client)
{
	decl String:item[32];
	new Handle:menu = CreateMenu(OnChooseSortType);


	SetMenuTitle(menu, "%T", "ChooseSortType", client);
	SetMenuExitBackButton(menu, true);

	Format(item, sizeof(item), "%T", "Ascending", client);
	AddMenuItem(Handle:menu, "1", item);

	Format(item, sizeof(item), "%T", "Descending", client);
	AddMenuItem(Handle:menu, "2", item);

	DisplayMenu(menu, client, 30);
}




// Client pressed a sort type
public OnChooseSortType(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientValid(param1))
	{
		decl String:choose[12];
		decl String:display[32];
		new Handle:newMenu = CreateMenu(OnChooseSort);
		new clientCookie = GetClientConfigCookie(param1);

		SetMenuExitBackButton(newMenu, true);

		// Get Choice
		GetMenuItem(menu, param2, choose, sizeof(choose));

		if (StrEqual(choose, "1"))
		{
			SetMenuTitle(newMenu, "%T:", "Ascending", param1);

			Format(display, sizeof(display), "%T", "SortByName", param1);
			AddMenuItem(newMenu, "1", display, (clientCookie == 0) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByDate", param1);
			AddMenuItem(newMenu, "3", display, (clientCookie == 3) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByMDate", param1);
			AddMenuItem(newMenu, "5", display, (clientCookie == 5) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByDownloads", param1);
			AddMenuItem(newMenu, "7", display, (clientCookie == 7) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByViews", param1);
			AddMenuItem(newMenu, "9", display, (clientCookie == 9) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByRating", param1);
			AddMenuItem(newMenu, "11", display, (clientCookie == 11) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
		else
		{
			SetMenuTitle(newMenu, "%T:", "Descending", param1);

			Format(display, sizeof(display), "%T", "SortByName", param1);
			AddMenuItem(newMenu, "0", display, (clientCookie == 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByDate", param1);
			AddMenuItem(newMenu, "2", display, (clientCookie == 2) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByMDate", param1);
			AddMenuItem(newMenu, "4", display, (clientCookie == 4) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByDownloads", param1);
			AddMenuItem(newMenu, "6", display, (clientCookie == 6) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByViews", param1);
			AddMenuItem(newMenu, "8", display, (clientCookie == 8) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

			Format(display, sizeof(display), "%T", "SortByRating", param1);
			AddMenuItem(newMenu, "10", display, (clientCookie == 10) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}

		DisplayMenu(newMenu, param1, 45);
	}
	else if (action == MenuAction_Cancel)
	{
		// Pressed back
		if (param2 == MenuCancel_ExitBack && IsClientValid(param1))
		{
			// Send new main menu
			PrepareMenu(param1, "", false);
		}
	}
	else if (action == MenuAction_End)
	{
		// Close handle on End
		CloseHandle(menu);
	}
}




// Client pressed a sort type
public OnChooseSort(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientValid(param1))
	{
		decl String:choose[12];

		// Get Choice
		GetMenuItem(menu, param2, choose, sizeof(choose));

		SetClientCookie(param1, g_hConfigCookie, choose);

		OnClientCookiesCached(param1);

		PrepareMenu(param1, "", false);
	}
	else if (action == MenuAction_Cancel)
	{
		// Pressed back
		if (param2 == MenuCancel_ExitBack && IsClientValid(param1))
		{
			// Send config menu
			OpenConfigMenu(param1);
		}
	}
	else if (action == MenuAction_End)
	{
		// Close handle on End
		CloseHandle(menu);
	}
}




// Open the menu with all Maps
OpenMenuWithAllMaps(client)
{
	SendCategories(client);
}




// Send the categories to the client
SendCategories(client)
{
	decl String:query[4096];
	

	// Reset map menu pos
	g_iLast[client][1] = 0;


	// No searching?
	if (StrEqual(g_sSearch[client][SEARCH], ""))
	{
		// Send all categories
		if (StrEqual(g_sSearch[client][CUSTOM], "0", false))
		{
			Format(query, sizeof(query), g_sAllCategories, g_sGameSearch, g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
		}
		else
		{
			Format(query, sizeof(query), g_sAllCustom, g_sWhitelistMaps, g_sBlacklistMaps);
		}
	}
	else
	{
		// Search for a map
		if (StrEqual(g_sSearch[client][CUSTOM], "0", false))
		{
			Format(query, sizeof(query), g_sSearchCategories, g_sGameSearch, g_sSearch[client][SEARCH], g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
		}
		else
		{
			Format(query, sizeof(query), g_sSearchCustom, g_sSearch[client][SEARCH], g_sWhitelistMaps, g_sBlacklistMaps);
		}
	}


	// Execute
	SQL_TQuery(g_hDatabase, OnSendCategories, query, GetClientUserId(client));
}





// Categories to menu
public OnSendCategories(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	new client = GetClientOfUserId(userid);

	if (IsClientValid(client))
	{
		// Valid answer?
		if (hndl != INVALID_HANDLE)
		{
			// Do we found something?
			if (SQL_FetchRow(hndl))
			{
				// Create menu
				new Handle:menu = CreateMenu(OnCategoryChoose);
				decl String:id[16];
				decl String:name[128];
				decl String:item[128 + 32];


				SetMenuExitBackButton(menu, true);

				// Title
				if (StrEqual(g_sSearch[client][SEARCH], ""))
				{
					SetMenuTitle(menu, "%T", "ChooseCategory", client);
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
			LogError("Couldn't execute category query. Error: %s", error);
		}
	} 
}




// Client pressed category
public OnCategoryChoose(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientValid(param1))
	{
		decl String:choose[12];

		// Get Choice
		GetMenuItem(menu, param2, choose, sizeof(choose));


		// Save to client and send maps menu
		g_iLast[param1][0] = GetMenuSelectionPosition();
		Format(g_sSearch[param1][CAT_ID], sizeof(g_sSearch[][]), choose);


		// Send Maps of category
		SendMaps(param1, "0");
	}
	else if (action == MenuAction_Cancel)
	{
		// Pressed back
		if (param2 == MenuCancel_ExitBack && IsClientValid(param1))
		{
			// Send new main menu
			PrepareMenu(param1, g_sSearch[param1][SEARCHREAL], StrEqual(g_sSearch[param1][CUSTOM], "1"));
		}
	}
	else if (action == MenuAction_End)
	{
		// Close handle on End
		CloseHandle(menu);
	}
}




// Send maps to client
SendMaps(client, String:sort[])
{
	if (IsClientValid(client))
	{
		decl String:query[4096];

		// Reset Data
		strcopy(g_sSearch[client][MAPNAME], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][MAPFILE], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][MAPID], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][MAPSIZE], sizeof(g_sSearch[][]), "");

		strcopy(g_sSearch[client][DATE], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][MDATE], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][DOWNLOADS], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][RATING], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][VOTES], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][VIEWS], sizeof(g_sSearch[][]), "");

		strcopy(g_sSearch[client][GAME], sizeof(g_sSearch[][]), "");
		strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "0");

		
		// No searching?
		if (StrEqual(g_sSearch[client][SEARCH], ""))
		{
			if (StrEqual(g_sSearch[client][CUSTOM], "0", false))
			{
				// check what type of maps we want
				new sortInt = StringToInt(sort);

				switch(sortInt)
				{
					case 0:
					{
						SetTitleWithCookie(client);

						Format(query, sizeof(query), g_sAllMaps, StringToInt(g_sSearch[client][CAT_ID]), g_sWhitelistMaps, g_sBlacklistMaps, g_sClientConfig[client]);
					}
					case 1:
					{
						strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "1");
						Format(query, sizeof(query), g_sSearchMapsByDate, g_sGameSearch, g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
					}
					case 2:
					{
						strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "2");
						Format(query, sizeof(query), g_sSearchMapsByMDate, g_sGameSearch, g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
					}
					case 3:
					{
						strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "3");
						Format(query, sizeof(query), g_sSearchMapsByDownloads, g_sGameSearch, g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
					}
					case 4:
					{
						strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "4");
						Format(query, sizeof(query), g_sSearchMapsByViews, g_sGameSearch, g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
					}
					case 5:
					{
						strcopy(g_sSearch[client][TITLE], sizeof(g_sSearch[][]), "5");
						Format(query, sizeof(query), g_sSearchMapsByRating, g_sGameSearch, g_sWhitelistCategories, g_sBlacklistCategories, g_sWhitelistMaps, g_sBlacklistMaps);
					}
				}
			}
			else
			{
				Format(query, sizeof(query), g_sAllCustomMaps, StringToInt(g_sSearch[client][CAT_ID]), g_sWhitelistMaps, g_sBlacklistMaps);
			}
		}
		else
		{
			// Search
			if (StrEqual(g_sSearch[client][CUSTOM], "0"))
			{
				SetTitleWithCookie(client);

				Format(query, sizeof(query), g_sSearchMapsByName, g_sSearch[client][SEARCH], StringToInt(g_sSearch[client][CAT_ID]), g_sWhitelistMaps, g_sBlacklistMaps, g_sClientConfig[client]);
			}
			else
			{
				Format(query, sizeof(query), g_sSearchCustomMaps, g_sSearch[client][SEARCH], StringToInt(g_sSearch[client][CAT_ID]), g_sWhitelistMaps, g_sBlacklistMaps);
			}
		}

		// Execute
		SQL_TQuery(g_hDatabase, OnSendMaps, query, GetClientUserId(client));
	}
}




// Maps to menu
public OnSendMaps(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	new client = GetClientOfUserId(userid);

	if (IsClientValid(client))
	{
		new bool:isCustom = StrEqual(g_sSearch[client][CUSTOM], "1", false);

		if (hndl != INVALID_HANDLE)
		{
			// Do we found something?
			if (SQL_FetchRow(hndl))
			{
				// Create menu
				new Handle:menu = CreateMenu(OnMapChoose);

				decl String:game[16];
				decl String:name[128];
				decl String:date[64];
				decl String:mdate[64];
				decl String:downloads[12];
				decl String:rating[12];
				decl String:votes[12];
				decl String:views[12];
				decl String:file[256];
				decl String:id[64];
				decl String:size[32];
				decl String:item[sizeof(name) + sizeof(rating) + sizeof(downloads) + 32];
				decl String:item2[256 + 64 + 128 + 32 + 16 + 64 + 64 + 12 + 12 + 12 + 12 + 32];
				
				// Title
				SetMenuTitle(menu, "%T", "ChooseMap", client);
				SetMenuExitBackButton(menu, true);


				do
				{
					// Fetch results
					if (!isCustom)
					{
						SQL_FetchString(hndl, 0, id, sizeof(id));
						SQL_FetchString(hndl, 1, date, sizeof(date));
						SQL_FetchString(hndl, 2, mdate, sizeof(mdate));
						SQL_FetchString(hndl, 3, downloads, sizeof(downloads));
						SQL_FetchString(hndl, 4, rating, sizeof(rating));
						SQL_FetchString(hndl, 5, votes, sizeof(votes));
						SQL_FetchString(hndl, 6, views, sizeof(views));
						SQL_FetchString(hndl, 7, name, sizeof(name));
						SQL_FetchString(hndl, 8, file, sizeof(file));
						SQL_FetchString(hndl, 9, size, sizeof(size));
						SQL_FetchString(hndl, 10, game, sizeof(game));
					}
					else
					{
						SQL_FetchString(hndl, 0, name, sizeof(name));
						SQL_FetchString(hndl, 1, id, sizeof(id));
					}


					// Replace <| in name
					ReplaceString(name, sizeof(name), "<|", "", false);


					// Add to menu
					if (!isCustom)
					{
						new sortTitle = StringToInt(g_sSearch[client][TITLE]);

						switch(sortTitle)
						{
							case 0:
							{
								Format(item, sizeof(item), "%s (%s, %s %T)", name, rating, downloads, "DownloadsShort", client);
							}
							case 1:
							{
								decl String:dateStr[64];
								FormatTime(dateStr, sizeof(dateStr), "%d.%m.%Y %H:%M", StringToInt(date));

								Format(item, sizeof(item), "%s (%s)", name, dateStr);
							}
							case 2:
							{
								decl String:mdateStr[64];
								FormatTime(mdateStr, sizeof(mdateStr), "%d.%m.%Y %H:%M", StringToInt(mdate));

								Format(item, sizeof(item), "%s (%s)", name, mdateStr);
							}
							case 3:
							{
								Format(item, sizeof(item), "%s (%s %T)", name, downloads, "DownloadsTitle", client);
							}
							case 4:
							{
								Format(item, sizeof(item), "%s (%s %T)", name, views, "ViewsTitle", client);
							}
							case 5:
							{
								Format(item, sizeof(item), "%s (%s %T)", name, rating, "RatingTitle", client);
							}
						}
					}
					else
					{
						Format(item, sizeof(item), name);
					}
					

					// This is tricky, add all needed data to the callback parameter
					// Non of these data has currently a '<|' in it
					if (!isCustom)
					{
						Format(item2, sizeof(item2), "%s<|%s<|%s<|%s<|%s<|%s<|%s<|%s<|%s<|%s<|%s", file, id, name, size, game, date, mdate, downloads, rating, votes, views);
					}
					else
					{
						Format(item2, sizeof(item2), "%s<|%s", name, id);
					}


					// Add item
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
		decl String:choose[128 + 128 + 128 + 32 + 16 + 64 + 64 + 12 + 12 + 12 + 12 + 12];
		decl String:splits[11][128];

		new bool:isCustom = StrEqual(g_sSearch[param1][CUSTOM], "1", false);


		// Get choice
		GetMenuItem(menu, param2, choose, sizeof(choose));


		// Explode choice again
		ExplodeString(choose, "<|", splits, sizeof(splits), sizeof(splits[]));


		// Save Data
		g_iLast[param1][1] = GetMenuSelectionPosition();

		// Now save download information
		if (!isCustom)
		{
			Format(g_sSearch[param1][MAPFILE], sizeof(g_sSearch[][]), splits[0]);
			Format(g_sSearch[param1][MAPID], sizeof(g_sSearch[][]), splits[1]);
			Format(g_sSearch[param1][MAPNAME], sizeof(g_sSearch[][]), splits[2]);
			Format(g_sSearch[param1][MAPSIZE], sizeof(g_sSearch[][]), splits[3]);
			Format(g_sSearch[param1][GAME], sizeof(g_sSearch[][]), splits[4]);
			Format(g_sSearch[param1][DATE], sizeof(g_sSearch[][]), splits[5]);
			Format(g_sSearch[param1][MDATE], sizeof(g_sSearch[][]), splits[6]);
			Format(g_sSearch[param1][DOWNLOADS], sizeof(g_sSearch[][]), splits[7]);
			Format(g_sSearch[param1][RATING], sizeof(g_sSearch[][]), splits[8]);
			Format(g_sSearch[param1][VOTES], sizeof(g_sSearch[][]), splits[9]);
			Format(g_sSearch[param1][VIEWS], sizeof(g_sSearch[][]), splits[10]);

			FormatTime(g_sSearch[param1][DATE], sizeof(g_sSearch[][]), "%d.%m.%Y %H:%M", StringToInt(g_sSearch[param1][DATE]));
			FormatTime(g_sSearch[param1][MDATE], sizeof(g_sSearch[][]), "%d.%m.%Y %H:%M", StringToInt(g_sSearch[param1][MDATE]));
		}
		else
		{
			Format(g_sSearch[param1][MAPNAME], sizeof(g_sSearch[][]), splits[0]);
			Format(g_sSearch[param1][MAPFILE], sizeof(g_sSearch[][]), splits[1]);
		}

		// Create the last menu
		createDecideMenu(param1, isCustom);
	}
	else if (action == MenuAction_Cancel)
	{
		// Pressed back
		if (param2 == MenuCancel_ExitBack && IsClientValid(param1))
		{
			if (StrEqual(g_sSearch[param1][CURRENT_MENU], "0"))
			{
				// Send category Panel
				SendCategories(param1);
			}
			else
			{
				PrepareMenu(param1, "", false);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		// Close handle on End
		CloseHandle(menu);
	}
}



// Creates the decide Menu
createDecideMenu(client, bool:isCustom)
{
	decl String:item[64];

	// Create information menu
	new Handle:menuNew = CreateMenu(OnDecide);

	// Title and back button
	SetMenuTitle(menuNew, "%T: %s\n \n%T\n%T\n%T\n%T\n%T\n%T\n ", "Map", client, g_sSearch[client][MAPNAME]
                                                                ,"Downloads", client, g_sSearch[client][DOWNLOADS], "Rating", client, g_sSearch[client][RATING], g_sSearch[client][VOTES], "Views"
                                                                ,client, g_sSearch[client][VIEWS], "Created", client, g_sSearch[client][DATE], "LatestModified", client, g_sSearch[client][MDATE], "Size"
                                                                , client, g_sSearch[client][MAPSIZE]);

	SetMenuPagination(menuNew, 3);

	// Items
	Format(item, sizeof(item), "%T", "Download", client);
	AddMenuItem(menuNew, "1", item);


	if (!isCustom)
	{
		Format(item, sizeof(item), "%T\n ", "Motd", client);
		AddMenuItem(menuNew, "2", item);
	}


	Format(item, sizeof(item), "%T", "Back", client);
	AddMenuItem(menuNew, "3", item);
	

	// Display Menu
	DisplayMenu(menuNew, client, MENU_TIME_FOREVER);
}




// Player decided to download a map
public OnDecide(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select && IsClientValid(param1))
	{
		decl String:choose[16];
		decl String:motdUrl[PLATFORM_MAX_PATH + 1];

		new choice;
		new bool:isCustom = StrEqual(g_sSearch[param1][CUSTOM], "1", false);


		// Get choice
		GetMenuItem(menu, param2, choose, sizeof(choose));

		choice = StringToInt(choose);


		// Choice is 2 -> Open motd
		if (choice == 2 && !isCustom)
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
			createDecideMenu(param1, isCustom);
		}
		else if (choice == 1)
		{
			// Now start downloading
			if (isCustom)
			{
				// We need a random id
				new random = GetRandomInt(5000, 10000);

				Format(g_sSearch[param1][MAPID], sizeof(g_sSearch[][]), "%i", random);
			}

			// Start
			StartDownloadingMap(param1, g_sSearch[param1][MAPID], g_sSearch[param1][MAPNAME], g_sSearch[param1][MAPFILE], isCustom);
		}
		else if (choice == 3)
		{
			// Send Maps Panel
			SendMaps(param1, g_sSearch[param1][CURRENT_MENU]);
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
StartDownloadingMap(client, const String:id[], const String:map[], const String:link[], bool:isCustom)
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


	// Log
	Log("%L: Downloading Map %s(%s)", client, map, link);

	// Format the download destination
	if (!isCustom)
	{
		GetFileName(link, savePath, sizeof(savePath));
	}
	else
	{
		GetFileName(map, savePath, sizeof(savePath));
	}


	Format(savePath, sizeof(savePath), "%s/%s", g_sPluginPath, savePath);



	// Init download
	g_Downloads[g_iTotalDownloads][DL_CLIENT] = client;
	g_Downloads[g_iTotalDownloads][DL_FINISH] = 0;
	g_Downloads[g_iTotalDownloads][DL_CURRENT] = 0.0;
	g_Downloads[g_iTotalDownloads][DL_TOTAL] = 0.0;


	// Strings
	if (!isCustom)
	{
		strcopy(g_Downloads[g_iTotalDownloads][DL_NAME], 128, map);
		Format(g_Downloads[g_iTotalDownloads][DL_FILE], 256, link);
	}
	else
	{
		SplitString(map, ".", g_Downloads[g_iTotalDownloads][DL_NAME], 128);
		Format(g_Downloads[g_iTotalDownloads][DL_FILE], 256, "%s/%s", link, map);
	}

	strcopy(g_Downloads[g_iTotalDownloads][DL_ID], 32, id);
	strcopy(g_Downloads[g_iTotalDownloads][DL_SAVE], PLATFORM_MAX_PATH+1, savePath);

	
	

	// File array
	if (g_Downloads[g_iTotalDownloads][DL_FILES] != INVALID_HANDLE)
	{
		CloseHandle(g_Downloads[g_iTotalDownloads][DL_FILES]);
	}
	
	// Create new Array
	g_Downloads[g_iTotalDownloads][DL_FILES] = CreateArray(PLATFORM_MAX_PATH + 1);



	// FTP File array
	if (g_Downloads[g_iTotalDownloads][DL_FTPFILES] != INVALID_HANDLE)
	{
		CloseHandle(g_Downloads[g_iTotalDownloads][DL_FTPFILES]);
	}
	
	// Create new Array
	g_Downloads[g_iTotalDownloads][DL_FTPFILES] = CreateArray(PLATFORM_MAX_PATH+  1);



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
DownloadMap()
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

		Log("%L: Downloading Map %s(%s) FAILED: %s", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE], error);

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
StopDownload()
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

			Log("%L: Downloading Map %s(%s) FAILED: %s", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE], output);

			// Stop
			StopDownload();
		}
		else
		{
			// Doesn't seems so
			decl String:extractPath[PLATFORM_MAX_PATH + 1];
			

			// Format unique file path
			Format(extractPath, sizeof(extractPath), "%s/%s", g_sPluginPath, g_Downloads[g_iCurrentDownload][DL_ID]);

			// What we found?
			new found = SearchForFolders(extractPath, 0);

			// Now search for extracted files and folders
			if (found > 0)
			{
				// We need to find at least a .bsp or .nav file!
				// Only nav?
				if (found == 2 && IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
				{
					CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "OnlyNav");
				}


				// Do we need to add files to downloadlist?
				if (g_bDownloadList)
				{
					// Yes...
					decl String:dllistFile[PLATFORM_MAX_PATH + 1];
					decl String:content[64];
					decl String:readbuffer[64];

					new Handle:file;
					new bool:duplicate;

					new arraySize = GetArraySize(g_Downloads[g_iCurrentDownload][DL_FTPFILES]);


					// Path to downloadlist
					BuildPath(Path_SM, dllistFile, sizeof(dllistFile), "data/mapdownload/downloadlist.txt");


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

					Log("%L: Downloading Map %s(%s) SUCCEEDED", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE]);

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

				Log("%L: Downloading Map %s(%s) FAILED: Found no .bsp file", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE]);

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
SearchForFolders(String:path[], found)
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


					// Copy nav to maps folder
					Format(content, sizeof(content), "maps/%s", content);

					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], content);
					System2_CopyFile(CopyFinished, newPath, content);

					// We found a nav
					found = found + 2;
				}

				// txt file?
				else if (StrEndsWith(content, ".txt") && type == FileType_File)
				{
					if (StrContains(content, "read", false) == -1 && StrContains(content, "change", false) == -1 && StrContains(content, "about", false) == -1 && StrContains(content, "contact", false) == -1 && StrContains(content, "credits", false) == -1 && StrContains(content, "install", false) == -1)
					{
						// Add File to file list, for uploading
						PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], newPath);


						// Copy txt to maps folder
						Format(content, sizeof(content), "maps/%s", content);

						PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], content);
						System2_CopyFile(CopyFinished, newPath, content);
					}
				}

				// Map file
				else if (StrEndsWith(content, ".bsp") && type == FileType_File)
				{
					decl String:buff[128];


					// Add File to file list, for uploading
					PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], newPath);


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
					found = found + 1;
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
CopyToGameDir(const String:path[], const String:cur[])
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

		// Close Handle
		CloseHandle(dir);
	}
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

			Log("%L: Downloading Map %s(%s) FAILED: %s", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE], output);

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
				if (!g_bFTPLogin)
				{
					System2_UploadFTPFile(OnUploadProgress, file, archive, g_sFTPHost, g_sFTPUser, g_sFTPPW, g_iFTPPort);
				}
				else
				{
					System2_UploadFTPFile(OnUploadProgress, file, archive, g_sFTPHost, g_sLogin[g_Downloads[g_iCurrentDownload][DL_CLIENT]][0], g_sLogin[g_Downloads[g_iCurrentDownload][DL_CLIENT]][1], g_iFTPPort);
				}
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


		Log("%L: Downloading Map %s(%s) FAILED: %s", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE], error);

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

				Log("%L: Downloading Map %s(%s) SUCCEEDED", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE]);

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
				if (!g_bFTPLogin)
				{
					System2_UploadFTPFile(OnUploadProgress, file, archive, g_sFTPHost, g_sFTPUser, g_sFTPPW, g_iFTPPort);
				}
				else
				{
					System2_UploadFTPFile(OnUploadProgress, file, archive, g_sFTPHost, g_sLogin[g_Downloads[g_iCurrentDownload][DL_CLIENT]][0], g_sLogin[g_Downloads[g_iCurrentDownload][DL_CLIENT]][1], g_iFTPPort);
				}
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