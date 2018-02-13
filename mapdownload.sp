/**
 * -----------------------------------------------------
 * File         mapdownload.sp
 * Authors      David Ordnung
 * License      GPLv3
 * Web          http://dordnung.de
 * -----------------------------------------------------
 * 
 * 
 * Copyright (C) 2013-2017 David Ordnung
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
#undef REQUIRE_EXTENSIONS
#include <clientprefs>

// Maybe include the updater if exists
#include <updater>




// Using semicolons ands new api
#pragma semicolon 1
#pragma newdecls required



// Table Version
#define TABLE_VERSION "2"


// URLs
#define UPDATE_URL_PLUGIN "http://dordnung.de/sourcemod/mapdl/update.txt"
#define UPDATE_URL_DB "http://dordnung.de/sourcemod/mapdl/gamebanana.sq3"


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
// Use old syntax here, otherwise enums like this won't work anymore ):
enum DownloadInfo
{
    DL_CLIENT,                                  // Client of current download
    DL_FINISH,                                  // Finished files
    Float:DL_CURRENT,                           // Current Bytes
    Float:DL_TOTAL,                             // Total bytes
    Modus:DL_MODE,                              // Current dl Modes
    String:DL_ID[32],                           // Map ID
    String:DL_NAME[128],                        // Map Name
    String:DL_FILE[128],                        // Download Link
    String:DL_SAVE[PLATFORM_MAX_PATH + 1],      // Path to save to
    Handle:DL_FILES,                            // Array to store files
    Handle:DL_FTPFILES                          // Array to store ftp files
}







// Global download list
int g_Downloads[20][DownloadInfo];


// Global strings
char g_sVersion[] = "2.3.0";
char g_sModes[][] = {"Downloading", "Uploading", "Compressing"};
char g_sGameSearch[64];
char g_sClientConfig[MAXPLAYERS + 1][256];
char g_sPluginPath[PLATFORM_MAX_PATH + 1];
char g_sCommand[32];
char g_sCommandCustom[32];
char g_sCommandDownload[32];
char g_sFTPCommand[32];
char g_sTag[32];
char g_sTagChat[64];
char g_sFlag[32];
char g_sFTPHost[128];
char g_sFTPUser[64];
char g_sFTPPW[128];
char g_sFTPPath[PLATFORM_MAX_PATH + 1];
char g_sGame[12];
char g_sSearch[MAXPLAYERS + 1][NUMBER_ELEMENTS][128];
char g_sLogin[MAXPLAYERS + 1][2][64];
char g_sWhitelistMaps[1024];
char g_sBlacklistMaps[1024];
char g_sWhitelistCategories[1024];
char g_sBlacklistCategories[1024];
char g_sLogPath[PLATFORM_MAX_PATH + 1];


// Global bools
bool g_bShow;
bool g_bMapCycle;
bool g_bNotice;
bool g_bFTP;
bool g_bFTPLogin;
bool g_bFirst;
bool g_bUpdate;
bool g_bUpdateDB;
bool g_bDBLoaded;
bool g_bSearch;
bool g_bDownloadList;
bool g_bUseCustom;
bool g_bClientprefsAvailable;
bool g_bForce32Bit;


// Global ints
int g_iFTPPort;
int g_iTotalDownloads;
int g_iCurrentDownload;
int g_iShowColor[4];
int g_iLast[MAXPLAYERS + 1][2];
int g_iCurrentNotice;
int g_iDatabaseRetries;
int g_iDatabaseTries;


// Global handles
ConVar g_hSearch;
ConVar g_hCommand;
ConVar g_hCommandCustom;
ConVar g_hCommandDownload;
ConVar g_hUpdate;
ConVar g_hUpdateDB;
ConVar g_hTag;
ConVar g_hFlag;
ConVar g_hShow;
ConVar g_hShowColor;
ConVar g_hMapCycle;
ConVar g_hNotice;
ConVar g_hFTP;
ConVar g_hFTPHost;
ConVar g_hFTPUser;
ConVar g_hFTPPW;
ConVar g_hFTPPort;
ConVar g_hFTPPath;
Database g_hDatabase;
Handle g_hHudSync;
ConVar g_hDownloadList;
ConVar g_hFTPLogin;
ConVar g_hFTPCommand;
ConVar g_hDatabaseRetries;
Handle g_hConfigCookie;


// Database querys
// Check if database is valid
char g_sDatabaseCheck[] = "SELECT \
                        `mapdl_categories_v2`.`id`, `mapdl_categories_v2`.`name`, `mapdl_categories_v2`.`game`, \
                        `mapdl_maps_v2`.`id`,  `mapdl_maps_v2`.`categories_id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, \
                        `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_info_v2`.`table_version` \
                        FROM `mapdl_categories_v2`, `mapdl_maps_v2`, `mapdl_info_v2` LIMIT 1";


// Check if database is current version
char g_sDatabaseCheckVersion[] = "SELECT `table_version` FROM `mapdl_info_v2`";


// Get all categories
char g_sAllCategories[] = "SELECT \
                        `mapdl_categories_v2`.`id`, `mapdl_categories_v2`.`name`, COUNT(`mapdl_maps_v2`.`name`) FROM `mapdl_categories_v2`, `mapdl_maps_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_categories_v2`.`id`=`mapdl_maps_v2`.`categories_id` %s%s%s%s GROUP BY `mapdl_categories_v2`.`name`";


// Search for a category by name
char g_sSearchCategories[] = "SELECT \
                        `mapdl_categories_v2`.`id`, `mapdl_categories_v2`.`name`, COUNT(`mapdl_maps_v2`.`name`) FROM `mapdl_categories_v2`, `mapdl_maps_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_categories_v2`.`id`=`mapdl_maps_v2`.`categories_id` AND `mapdl_maps_v2`.`name` \
                        LIKE '%s' ESCAPE '?' %s%s%s%s GROUP BY `mapdl_categories_v2`.`name`";


// Get all maps
char g_sAllMaps[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_maps_v2`.`categories_id`=%i AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s %s";


// Search for a map by name
char g_sSearchMapsByName[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_maps_v2`.`name` LIKE '%s' ESCAPE '?' AND `mapdl_maps_v2`.`categories_id`=%i AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s %s";


// Search for a map by date
char g_sSearchMapsByDate[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY `mapdl_maps_v2`.`date` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC LIMIT 100";


// Search for a map by last modification date
char g_sSearchMapsByMDate[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`date` != `mapdl_maps_v2`.`mdate` AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY `mapdl_maps_v2`.`mdate`DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC  LIMIT 100";


// Search for a map by downloads
char g_sSearchMapsByDownloads[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY `mapdl_maps_v2`.`downloads` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC LIMIT 100";


// Search for a map by views
char g_sSearchMapsByViews[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY `mapdl_maps_v2`.`views` DESC, cast(`mapdl_maps_v2`.`rating` as float) DESC LIMIT 100";


// Search for a map by rating
char g_sSearchMapsByRating[] = "SELECT `mapdl_maps_v2`.`id`, `mapdl_maps_v2`.`date`, `mapdl_maps_v2`.`mdate`, `mapdl_maps_v2`.`downloads`, `mapdl_maps_v2`.`rating`, `mapdl_maps_v2`.`votes`, \
                        `mapdl_maps_v2`.`views`, `mapdl_maps_v2`.`name`, `mapdl_maps_v2`.`download`, `mapdl_maps_v2`.`size`, `mapdl_categories_v2`.`game` FROM `mapdl_maps_v2`, `mapdl_categories_v2` \
                        WHERE `mapdl_categories_v2`.`game` IN %s AND `mapdl_maps_v2`.`categories_id` = `mapdl_categories_v2`.`id` %s%s%s%s GROUP BY `mapdl_maps_v2`.`name` ORDER BY cast(`mapdl_maps_v2`.`rating` as float) DESC, `mapdl_maps_v2`.`votes` DESC LIMIT 100";



// Customs


// Create Customs
char g_sCreateCustom[] = "CREATE TABLE IF NOT EXISTS `mapdl_custom` \
                        (`id` integer PRIMARY KEY, `name` varchar(255) NOT NULL, `url` varchar(255) NOT NULL, UNIQUE (name, url))";


// Create Customs maps
char g_sCreateCustomMaps[] = "CREATE TABLE IF NOT EXISTS `mapdl_custom_maps` \
                        (`custom_id` tinyint NOT NULL, `file` varchar(128) NOT NULL, UNIQUE (custom_id, file))";


// Insert name and urls
char g_InsertCustom[] = "INSERT INTO `mapdl_custom` \
                        (`id`, `name`, `url`) VALUES (NULL, '%s', '%s')";


// Insert Maps
char g_InsertCustomMaps[] = "INSERT INTO `mapdl_custom_maps` (`custom_id`, `file`) \
                        SELECT `mapdl_custom`.`id`, '%s' FROM `mapdl_custom` WHERE `mapdl_custom`.`name` = '%s'";


// Get custom urls
char g_sAllCustom[] = "SELECT `mapdl_custom`.`id`, `mapdl_custom`.`name`, COUNT(`mapdl_custom_maps`.`file`) FROM `mapdl_custom_maps`, `mapdl_custom` \
                        WHERE `mapdl_custom`.`id` = `mapdl_custom_maps`.`custom_id` %s%s GROUP BY `mapdl_custom`.`name`";


// Get custom urls search
char g_sSearchCustom[] = "SELECT `mapdl_custom`.`id`, `mapdl_custom`.`name`, COUNT(`mapdl_custom_maps`.`file`) FROM `mapdl_custom_maps`, `mapdl_custom` \
                        WHERE `mapdl_custom_maps`.`file` LIKE '%s' ESCAPE '?' AND `mapdl_custom`.`id` = `mapdl_custom_maps`.`custom_id` %s%s GROUP BY `mapdl_custom`.`name`";


// Get custom maps
char g_sAllCustomMaps[] = "SELECT `mapdl_custom_maps`.`file`, `mapdl_custom`.`url` FROM `mapdl_custom_maps`, `mapdl_custom` \
                        WHERE `mapdl_custom_maps`.`custom_id`=%i AND `mapdl_custom`.`id` = `mapdl_custom_maps`.`custom_id` %s%s GROUP BY `mapdl_custom_maps`.`file`";


// Get custom maps search
char g_sSearchCustomMaps[] = "SELECT `mapdl_custom_maps`.`file`, `mapdl_custom`.`url` FROM `mapdl_custom_maps`, `mapdl_custom` \
                        WHERE `mapdl_custom_maps`.`file` LIKE '%s' ESCAPE '?' AND `mapdl_custom_maps`.`custom_id`=%i AND `mapdl_custom`.`id` = `mapdl_custom_maps`.`custom_id` %s%s GROUP BY `mapdl_custom_maps`.`file`";




// Global info
public Plugin myinfo =
{
    name = "Ingame Map Download",
    author = "dordnung",
    version = g_sVersion,
    description = "Allows admins to download maps ingame"
};




/*
**************

MAIN METHODS

**************
*/





// Plugin started
public void OnPluginStart()
{
    // Load Translation
    LoadTranslations("core.phrases");
    LoadTranslations("mapdownload.phrases");
    
    
    // First is true!
    g_bFirst = true;
    g_bDBLoaded = false;
    g_bUseCustom = false;
    g_bClientprefsAvailable = false;
    g_bForce32Bit = false;
    g_iCurrentNotice = 0;
    g_iDatabaseTries = 0;
    g_iShowColor = {255, 255, 255, 255};


    // Init. AutoExecConfig
    AutoExecConfig_SetFile("plugin.mapdownload");


    // Public Cvar
    AutoExecConfig_CreateConVar("mapdownload_version", g_sVersion, "Ingame Map Download Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

    // Set Cvars
    g_hCommand = AutoExecConfig_CreateConVar("mapdownload_command", "sm_mapdl", "Command to open Map Download menu. Append prefix 'sm_' for chat use!");
    g_hCommandCustom = AutoExecConfig_CreateConVar("mapdownload_command_custom", "sm_mapdl_custom", "Command to open custom Map Download menu. Append prefix 'sm_' for chat use!");
    g_hCommandDownload = AutoExecConfig_CreateConVar("mapdownload_command_download", "sm_mapdl_url", "Command to download a map directly from an url. Append prefix 'sm_' for chat use!");
    g_hTag = AutoExecConfig_CreateConVar("mapdownload_tag", "Map Download", "Chat prefix of Map Download");
    g_hFlag = AutoExecConfig_CreateConVar("mapdownload_flag", "bg", "Flagstring to access menu (see configs/admin_levels.cfg)");
    g_hShow = AutoExecConfig_CreateConVar("mapdownload_show", "0", "1 = All players see map downloading status, 0 = Only admins");
    g_hShowColor = AutoExecConfig_CreateConVar("mapdownload_show_color", "255,255,255,255", "RGBA Color of the HUD Text if available", FCVAR_PROTECTED);
    g_hDatabaseRetries = AutoExecConfig_CreateConVar("mapdownload_retries", "1", "Numbers of retries to load database");
    g_hSearch = AutoExecConfig_CreateConVar("mapdownload_search", "1", "1 = Search searchmask within a string, 0 = Search excact mask");
    g_hMapCycle = AutoExecConfig_CreateConVar("mapdownload_mapcycle", "1", "1 = Write downloaded map in mapcycle.txt, 0 = Off");
    g_hNotice = AutoExecConfig_CreateConVar("mapdownload_notice", "1", "1 = Notice admins on server that Map Download runs, 0 = Off");
    g_hDownloadList = AutoExecConfig_CreateConVar("mapdownload_downloadlist", "1", "1 = Add custom files of a map into an intern downloadlist, all items whill be loaded when a player will connect the first time, 0 = Off");
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
public void OnConfigsExecuted()
{
    char showColor[32];
    char showColorExploded[4][12];

    // Read all convars
    // Ints
    g_iFTPPort = g_hFTPPort.IntValue;


    // Bools
    g_bNotice = g_hNotice.BoolValue;
    g_bShow = g_hShow.BoolValue;
    g_bMapCycle = g_hMapCycle.BoolValue;
    g_bFTP = g_hFTP.BoolValue;
    g_bFTPLogin = (g_hFTPLogin.BoolValue && g_bFTP);
    g_bUpdate = g_hUpdate.BoolValue;
    g_bUpdateDB = g_hUpdateDB.BoolValue;
    g_bSearch = g_hSearch.BoolValue;
    g_bDownloadList = g_hDownloadList.BoolValue;
    g_iDatabaseRetries = g_hDatabaseRetries.BoolValue;


    // Strings
    g_hShowColor.GetString(showColor, sizeof(showColor));
    g_hCommand.GetString(g_sCommand, sizeof(g_sCommand));
    g_hCommandCustom.GetString(g_sCommandCustom, sizeof(g_sCommandCustom));
    g_hCommandDownload.GetString(g_sCommandDownload, sizeof(g_sCommandDownload));
    g_hFTPCommand.GetString(g_sFTPCommand, sizeof(g_sFTPCommand));
    g_hTag.GetString(g_sTag, sizeof(g_sTag));
    g_hFlag .GetString(g_sFlag, sizeof(g_sFlag));
    g_hFTPHost.GetString(g_sFTPHost, sizeof(g_sFTPHost));
    g_hFTPUser.GetString(g_sFTPUser, sizeof(g_sFTPUser));
    g_hFTPPW.GetString(g_sFTPPW, sizeof(g_sFTPPW));
    g_hFTPPath.GetString(g_sFTPPath, sizeof(g_sFTPPath));


    // Hud Sync
    g_hHudSync = CreateHudSynchronizer();

    // Explode Colors
    int found = ExplodeString(showColor, ",", showColorExploded, sizeof(showColorExploded), sizeof(showColorExploded[]));

    if (found == 4)
    {
        int r = StringToInt(showColorExploded[0]);
        int g = StringToInt(showColorExploded[1]);
        int b = StringToInt(showColorExploded[2]);
        int a = StringToInt(showColorExploded[3]);

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


    // Add Auto Updater if exit and wanted
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
    ConVar cvar = FindConVar("sv_hudhint_sound");
    if (cvar != null)
    {
        cvar.SetInt(0);
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
        RegAdminCmd(g_sCommandDownload, DownloadMapDirect, ReadFlagString(g_sFlag));
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
public void OnAllPluginsLoaded()
{
    // Is system2 extension here?
    if (!LibraryExists("system2"))
    {
        // No -> stop plugin!
        SetFailState("Attention: Extension system2 couldn't be found. Please install it to run Map Download!");
    }

    char binDir[PLATFORM_MAX_PATH];
    char binDir32Bit[PLATFORM_MAX_PATH];

    if (!System2_Check7ZIP(binDir, sizeof(binDir))) {
        if (!System2_Check7ZIP(binDir32Bit, sizeof(binDir32Bit), true)) {
            if (StrEqual(binDir, binDir32Bit)) {
                SetFailState("Attention: 7-ZIP was not found or is not executable at '%s'", binDir);
            } else {
                SetFailState("Attention: 7-ZIP was not found or is not executable at '%s' or '%s'", binDir, binDir32Bit);
            }
        } else {
            g_bForce32Bit = true;
            Log("Attention: 64-Bit version of 7-ZIP was not found or is not executable at '%s', falling back to 32-Bit version!", binDir);
        }
    }
}



// Logging Stuff
void Log(char[] fmt, any ...)
{
    char format[1024];
    char file[PLATFORM_MAX_PATH + 1];
    char currentDate[32];

    VFormat(format, sizeof(format), fmt, 2);
    FormatTime(currentDate, sizeof(currentDate), "%d-%m-%y");
    Format(file, sizeof(file), "%s/mapdownload_(%s).log", g_sLogPath, currentDate);

    LogToFile(file, "[ MAPDL ] %s", format);
}





// Client cookies are cached
public void OnClientCookiesCached(int client)
{
    int config = GetClientConfigCookie(client);

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
void SetTitleWithCookie(int client)
{
    int config = GetClientConfigCookie(client);

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
int GetClientConfigCookie(int client)
{
    // Only with clientprefs
    if (g_bClientprefsAvailable && IsClientValid(client) && AreClientCookiesCached(client))
    {
        char buffer[8];

        GetClientCookie(client, g_hConfigCookie, buffer, sizeof(buffer));

        return StringToInt(buffer);
    }

    return -1;
}




// Prepare folders and connect to database
void PreparePlugin()
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
        PrepareDB(true, "", null, null, METHOD_GET);
    }
    else
    {
        char path[PLATFORM_MAX_PATH + 1];

        // Path to sql file
        BuildPath(Path_SM, path, sizeof(path), "data/sqlite/gamebanana.sq3");

        // Download current database
        System2HTTPRequest downloadRequest = new System2HTTPRequest(PrepareDB, UPDATE_URL_DB);
        downloadRequest.SetOutputFile(path);
        downloadRequest.GET();
        delete downloadRequest;
    }
}





// Prepare folders and connect to database
void ParseDownloadList()
{
    // Parse Downloadlist
    if (g_bDownloadList)
    {
        char dllistFile[PLATFORM_MAX_PATH + 1];
        char readbuffer[64];

        // Path to downloadlist
        BuildPath(Path_SM, dllistFile, sizeof(dllistFile), "data/mapdownload/downloadlist.txt");


        // Open file
        File file = OpenFile(dllistFile, "rb");


        // We could open file
        if (file != null)
        {
            // Loop through file content
            while (!file.EndOfFile() && file.ReadLine(readbuffer, sizeof(readbuffer)))
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
            file.Close();
        }
    }
}



// Create DB Connection
public void PrepareDB(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    if (g_bUpdateDB)
    {
        char detailError[256];

        // Response 200 expected
        if (success && response != null && response.StatusCode != 200)
        {
            success = false;
            Format(detailError, sizeof(detailError), "Expected HTTP status code 200, but got %d", response.StatusCode);
        }
        else
        {
            strcopy(detailError, sizeof(detailError), error);
        }

        if (!success)
        {
            // We couldn't update the db
            if (g_iDatabaseRetries > g_iDatabaseTries)
            {
                // We couldn't update the db
                LogError("Attention: Couldn't update database. Error: '%s'. Trying again...", detailError);
                g_iDatabaseTries++;

                // Retry the download
                request.GET();

                return;
            }
            else
            {
                LogError("Attention: Couldn't update database after %d retries. Error: '%s'. Try to restart your server", g_iDatabaseTries, detailError);
            }
        }
        else
        {
            // Notice update
            Log("Updated gamebanana Database succesfully!");
        }
    }


    char sqlError[256];


    // Connect to database
    KeyValues dbValue = new KeyValues("Databases");
    
    dbValue.SetString("driver", "sqlite");
    dbValue.SetString("host", "localhost");
    dbValue.SetString("database", "gamebanana");
    dbValue.SetString("user", "root");

    // Connect
    g_hDatabase = SQL_ConnectCustom(dbValue, sqlError, sizeof(sqlError), true);


    // Close Keyvalues
    delete dbValue;


    // Check valid connection
    if (g_hDatabase == null)
    {
        // Log error and stop plugin
        LogError("Map Download couldn't connect to the Database! Error: %s", sqlError);
        SetFailState("Map Download couldn't connect to the Database! Error: %s", sqlError);
    }
    else
    {
        // Create Transaction
        Transaction txn = new Transaction();

        txn.AddQuery(g_sDatabaseCheck, 1);
        txn.AddQuery(g_sDatabaseCheckVersion, 2);
        txn.AddQuery(g_sCreateCustom, 3);
        txn.AddQuery(g_sCreateCustomMaps, 4);

        g_hDatabase.Execute(txn, OnDBStartedUp, OnDBStartUpFailed);
    }
}



// Everything is started up
public void OnDBStartedUp(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    for (int i=0; i < numQueries; i++)
    {
        if (queryData[i] == 1)
        {
            // Check valid database
            if (!results[i].FetchRow())
            {
                LogError("Map Download database seems to be empty!");
            }
        }

        if (queryData[i] == 2)
        {
            char version[16];

            // Check valid database version
            if (!results[i].FetchRow())
            {
                LogError("Your Map Download database seems to be outdated!");
            }

            results[i].FetchString(0, version, sizeof(version));

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
public void OnDBStartUpFailed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogError("Map Download couldn't prepare the Database. Error: '%s'", error);

    if (g_iDatabaseRetries > g_iDatabaseTries)
    {
        g_iDatabaseTries++;

        // Retrie
        PrepareDB(true, "", null, null, METHOD_GET);
    }
}



// Parse the white,black and customlist
void ParseLists()
{
    char listPath[PLATFORM_MAX_PATH + 1];

    KeyValues listKeyValue = new KeyValues("MapDownloadLists");

    // Path
    BuildPath(Path_SM, listPath, sizeof(listPath), "configs/mapdownload_lists.cfg");


    // List file exists?
    if (!FileExists(listPath))
    {
        // no...
        return;
    }


    // Load the file to keyvalue
    listKeyValue.ImportFromFile(listPath);
    

    // First key categories
    if (listKeyValue.JumpToKey("categories") && listKeyValue.GotoFirstSubKey(false))
    {
        // Loop through all items
        do
        {
            char section[128];
            char search[128];
            char searchBuffer[256];
            char searchFinal[256];


            // Get Section and key
            listKeyValue.GetSectionName(section, sizeof(section));
            listKeyValue.GetString(NULL_STRING, search, sizeof(search));


            // Any data?
            if (!StrEqual(search, ""))
            {
                // Escape search
                g_hDatabase.Escape(search, searchBuffer, sizeof(searchBuffer));
                EscapeString(searchBuffer, '_', '?', searchFinal, sizeof(searchFinal));


                // whitelist?
                if (StrEqual(section, "whitelist", false))
                {
                    if (strlen(g_sWhitelistCategories) == 0)
                    {
                        Format(searchFinal, sizeof(searchFinal), "AND (`mapdl_categories_v2`.`name` LIKE '%s' ESCAPE '?'", searchFinal);
                    }
                    else
                    {
                        Format(searchFinal, sizeof(searchFinal), " OR `mapdl_categories_v2`.`name` LIKE '%s' ESCAPE '?'", searchFinal);
                    }

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
        while (listKeyValue.GotoNextKey(false));

        if (strlen(g_sWhitelistCategories) > 0)
        {
            StrCat(g_sWhitelistCategories, sizeof(g_sWhitelistCategories), ")");
        }
    }


    // Rewind
    listKeyValue.Rewind();


    // First key maps
    if (listKeyValue.JumpToKey("maps") &&  listKeyValue.GotoFirstSubKey(false))
    {
        // Loop through all items
        do
        {
            char section[128];
            char search[128];
            char searchBuffer[256];
            char searchFinal[256];


            // Get Section and key
            listKeyValue.GetSectionName(section, sizeof(section));
            listKeyValue.GetString(NULL_STRING, search, sizeof(search));


            // Any data?
            if (!StrEqual(search, ""))
            {
                // Escape search
                g_hDatabase.Escape(search, searchBuffer, sizeof(searchBuffer));
                EscapeString(searchBuffer, '_', '?', searchFinal, sizeof(searchFinal));



                // whitelist?
                if (StrEqual(section, "whitelist", false))
                {
                    if (strlen(g_sWhitelistMaps) == 0)
                    {
                        Format(searchFinal, sizeof(searchFinal), "AND (`mapdl_maps_v2`.`name` LIKE '%s' ESCAPE '?'", searchFinal);
                    }
                    else
                    {
                        Format(searchFinal, sizeof(searchFinal), " OR `mapdl_maps_v2`.`name` LIKE '%s' ESCAPE '?'", searchFinal);
                    }

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
        while (listKeyValue.GotoNextKey(false));

        if (strlen(g_sWhitelistMaps) > 0)
        {
            StrCat(g_sWhitelistMaps, sizeof(g_sWhitelistMaps), ")");
        }
    }


    // Rewind
    listKeyValue.Rewind();


    // Goto custom urls
    if (listKeyValue.JumpToKey("customurls") &&  listKeyValue.GotoFirstSubKey(false))
    {
        ArrayList sectionArray = new ArrayList(128);
        Transaction txn = new Transaction();

        // Loop through all items
        do
        {
            char query[1024];
            char section[128];
            char search[128];
            char sectionBuffer[256];


            // Get Section and key
            listKeyValue.GetSectionName(section, sizeof(section));
            listKeyValue.GetString(NULL_STRING, search, sizeof(search));


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
                g_hDatabase.Escape(section, sectionBuffer, sizeof(sectionBuffer));


                // Get result of insert
                Format(query, sizeof(query), g_InsertCustom, sectionBuffer, search);
                txn.AddQuery(query);


                // Push Name in
                sectionArray.PushString(sectionBuffer);
                sectionArray.PushString(search);
            }
        } 
        while (listKeyValue.GotoNextKey(false));

        g_hDatabase.Execute(txn, OnAddedCustomUrls, OnAddedCustomUrlsFailed, sectionArray);
    }

    delete listKeyValue;
}



// All Custom Urls added
public void OnAddedCustomUrls(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    char sectionBuffer[128];
    char search[128];

    ArrayList array = view_as<ArrayList>(data);

    for (int i=0; i < numQueries; i++)
    {
        array.GetString(i, sectionBuffer, sizeof(sectionBuffer));
        array.GetString(i+1, search, sizeof(search));

        // We need a handle to give with
        ArrayList nameArray = new ArrayList(128, 0);

        // Push Name in
        PushArrayString(nameArray, sectionBuffer);


        // Now search for maps
        System2HTTPRequest searchRequest = new System2HTTPRequest(OnGetPage, search);
        searchRequest.Any = nameArray;
        searchRequest.SetUserAgent("Ingame Map Download Searcher");
        searchRequest.GET();
        delete searchRequest;
    }

    delete array;
}



// Custom urls couldn't be add
public void OnAddedCustomUrlsFailed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    delete view_as<ArrayList>(data);

    LogError("Map Download couldn't add custom urls. Error: '%s'", error);
}



public void OnGetPage(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    ArrayList nameArray = view_as<ArrayList>(request.Any);
    if (nameArray != null)
    {
        // Get Name
        char name[128];
        nameArray.GetString(0, name, sizeof(name));

        if (!success)
        {
            LogError("Couldn't parse custom url %s. Error: %s", name, error);
        }
        else if (response.StatusCode != 200)
        {
            LogError("Couldn't parse custom url %s. Expected status code 200, got: %d", name, response.StatusCode);
        }
        else
        {
            // Get output
            char[] output = new char[response.ContentLength + 1];
            response.GetContent(output, response.ContentLength + 1);

            // Explode Output
            char explodes[64][512];
            int found = ExplodeString(output, "href=", explodes, sizeof(explodes), sizeof(explodes[]));

            // Go through results
            char part[512];
            char partBuffer[1024];
            char query[1024];
            for (int i=0; i < found; i++)
            {
                int split = SplitString(explodes[i], "\">", part, sizeof(part));

                if (split > 0)
                {
                    ReplaceString(part, sizeof(part), "\"", "", false);
                    EscapeString(part, '%', '%', partBuffer, sizeof(partBuffer));

                    // Check valid
                    if ((StrEndsWith(partBuffer, ".bsp") || StrEndsWith(partBuffer, ".bz2") || StrEndsWith(partBuffer, ".rar") 
                        || StrEndsWith(partBuffer, ".zip") || StrEndsWith(partBuffer, ".7z")) && !StrEndsWith(partBuffer, ".txt.bz2"))
                    {
                        // Insert Map
                        Format(query, sizeof(query), g_InsertCustomMaps, partBuffer, name);
                        g_hDatabase.Query(SQL_CallBack, query);
                    }
                }
            }

            // Delete array
            delete nameArray;
        }
    }
}




// Callback of SQL
public void SQL_CallBack(Database db, DBResultSet results, const char[] error, any data)
{
}




// Deletes complete path
// Recursive method
void DeletePath(char[] path)
{
    // Name buffer
    char buffer[128];


    // Open dir
    DirectoryListing dir = OpenDirectory(path);


    // Found?
    if (dir != null)
    {
        // What we found?
        FileType type;


        // While found something
        while (dir.GetNext(buffer, sizeof(buffer), type))
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
        delete dir;
    }


    // Now dir should be empty, so delete it
    RemoveDir(path);
}



// Is player valid?
bool IsClientValid(int client)
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
bool IsClientAdmin(int client)
{
    int need = ReadFlagString(g_sFlag);
    int clientFlags = GetUserFlagBits(client);

    return (need <= 0 || (clientFlags & need) || (clientFlags & ADMFLAG_ROOT));
}



// Reset client
public void OnClientConnected(int client)
{
    // Reset client
    strcopy(g_sLogin[client][0], sizeof(g_sLogin[][]), "");
    strcopy(g_sLogin[client][1], sizeof(g_sLogin[][]), "");
    strcopy(g_sClientConfig[client], sizeof(g_sClientConfig[]), "");
}



// Sends the current status
void SendCurrentStatus()
{
    // Not finished 
    char message[256];
    char bar[16];
    char percent[64];

    float current;
    float total;
    float per;


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
            int iTotal = GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]);
            int iCurrent = g_Downloads[g_iCurrentDownload][DL_FINISH];
            per = (float(iCurrent) / iTotal) * 100.0;


            // We always need a lot of percent signs^^
            if (g_hHudSync == null && !StrEqual(g_sGame, "csgo", false) && !StrEqual(g_sGame, "dods", false))
            {
                Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %i / %i", per, iCurrent, iTotal);
            }
            else if (g_hHudSync != null)
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
            if (g_hHudSync == null && !StrEqual(g_sGame, "csgo", false) && !StrEqual(g_sGame, "dods", false))
            {
                Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %.0fkB / %.0fkB - %i / %i", per, current, total, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
            }
            else if (g_hHudSync != null)
            {
                Format(percent, sizeof(percent), "%.2f%%%%%% - %.0fkB / %.0fkB\n%i / %i", per, current, total, g_Downloads[g_iCurrentDownload][DL_FINISH], GetArraySize(g_Downloads[g_iCurrentDownload][DL_FILES]));
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
            if (g_hHudSync == null && !StrEqual(g_sGame, "csgo", false) && !StrEqual(g_sGame, "dods", false))
            {
                Format(percent, sizeof(percent), "%.2f%%%%%%%%%% - %.0fkB / %.0fkB", per, current, total);
            }
            else if (g_hHudSync != null)
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

        for (int i=1; i < 11; i++)
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
    if (g_hHudSync != null)
    {
        SetHudTextParams(-1.0, 0.75, 15.0, g_iShowColor[0], g_iShowColor[1], g_iShowColor[2], g_iShowColor[3], 0, 0.0, 0.0, 0.0);
    }


    // Send to every valid client
    for (int i=1; i < MaxClients; i++)
    {
        // Find targets
        if (IsClientValid(i) && (g_bShow || IsClientAdmin(i)))
        {
            if (g_Downloads[g_iCurrentDownload][DL_MODE] != MODUS_FINISH)
            {
                // Csgo need extra formating
                if (!StrEqual(g_sGame, "csgo", false))
                {
                    Format(message, sizeof(message), "%T: %s\n%s\n%s", g_sModes[g_Downloads[g_iCurrentDownload][DL_MODE]], i, g_Downloads[g_iCurrentDownload][DL_NAME], bar, percent);
                }
                else
                {
                    Format(message, sizeof(message), "%T\n%s\n", g_sModes[g_Downloads[g_iCurrentDownload][DL_MODE]], i, percent);
                }
            }
            else
            {
                // Csgo need extra formating
                if (!StrEqual(g_sGame, "csgo", false))
                {
                    Format(message, sizeof(message), "%T", "FinishHint", i, g_Downloads[g_iCurrentDownload][DL_NAME]);
                }
                else
                {
                    Format(message, sizeof(message), "%T", "FinishHintShort", i);
                }
            }


            // No Hud text supported
            if (g_hHudSync == null) 
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
public Action NoticeTimer(Handle timer, any data)
{
    char commandBuffer[64];
    char commandBufferCustom[64];
    char commandBufferDownload[64];


    // Only for commands with sm_
    if (StrContains(g_sCommand, "sm_", false) > -1)
    {
        // Replace sm_
        Format(commandBuffer, sizeof(commandBuffer), g_sCommand);
        ReplaceString(commandBuffer, sizeof(commandBuffer), "sm_", "");

        Format(commandBufferCustom, sizeof(commandBufferCustom), g_sCommandCustom);
        ReplaceString(commandBufferCustom, sizeof(commandBufferCustom), "sm_", "");

        Format(commandBufferDownload, sizeof(commandBufferDownload), g_sCommandDownload);
        ReplaceString(commandBufferDownload, sizeof(commandBufferDownload), "sm_", "");


        // Client loop
        for (int i=1; i < MaxClients; i++)
        {
            // Valid and admin?
            if (IsClientValid(i) && IsClientAdmin(i))
            {
                // Print
                if (g_iCurrentNotice == 0)
                {
                    CPrintToChat(i, "%s %t", g_sTagChat, "Notice", commandBuffer);
                }

                if (g_iCurrentNotice == 3)
                {
                    CPrintToChat(i, "%s %t", g_sTagChat, "Notice2", commandBufferCustom);
                }

                if (g_iCurrentNotice == 1)
                {
                    CPrintToChat(i, "%s %t", g_sTagChat, "Notice3");
                }

                if (g_iCurrentNotice == 2)
                {
                    CPrintToChat(i, "%s %t", g_sTagChat, "Notice4", commandBufferDownload);
                }
            }
        }


        // Increase
        g_iCurrentNotice++;


        if ((g_bUseCustom && g_iCurrentNotice == 4) || (!g_bUseCustom && g_iCurrentNotice == 3))
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
void GetFileName(const char[] path, char[] buffer, int size)
{
    // Empty?
    if (path[0] == '\0')
    {
        buffer[0] = '\0';

        return;
    }
    

    // Linux
    int pos = FindCharInString(path, '/', true);
    
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
bool StrEndsWith(char[] str, char[] str2)
{
    // Len of strings
    int len = strlen(str);
    int len2 = strlen(str2);
    int start = len - len2;


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
    for (int i=0; i < len2; i++)
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
public Action OnSetLoginData(int client, int args)
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
public Action OpenMenuCustom(int client, int args)
{
    if (g_bUseCustom)
    {
        char argument[64];
        
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
public Action OpenMenu(int client, int args)
{
    char argument[64];
    
    // Get argument
    GetCmdArgString(argument, sizeof(argument));


    // Prepare Menu
    PrepareMenu(client, argument, false);


    // Finish
    return Plugin_Handled;
}



// Download a Map directly
public Action DownloadMapDirect(int client, int args)
{
    if (IsClientValid(client))
    {
        if (args >= 1)
        {
            char fileName[128];
            char id[16];
            char name[16];
            char url[128];

            // Concat all arguments to url
            GetCmdArgString(url, sizeof(url));

            // Check valid
            if ((StrEndsWith(url, ".bsp") || StrEndsWith(url, ".bz2") || StrEndsWith(url, ".rar") || StrEndsWith(url, ".zip") || StrEndsWith(url, ".7z")) && !StrEndsWith(url, ".txt.bz2"))
            {
                // Get the name of the map
                GetFileName(url, fileName, sizeof(fileName));
                SplitString(fileName, ".", name, sizeof(name));

                // We need a random id
                Format(id, sizeof(id), "%i", GetRandomInt(5000, 10000));

                
                // Download the Map
                StartDownloadingMap(client, id, name, url, false);


                // Finish
                return Plugin_Handled;
            }
            else
            {
                // URL isn't a file
                CPrintToChat(client, "%s %t", g_sTagChat, "InvalidUrl", url);
            }
        }
        else
        {
            // No argument given
            ReplyToCommand(client, "Usage: %s <url>", g_sCommandDownload);
        }
    }

    // Client is invalid
    return Plugin_Continue;
}





// Prepare a new menu
void PrepareMenu(int client, char[] argument, bool isCustom)
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
            char argumentEscaped[256];
            char argumentEscapedBuffer[256];


            // Mark menu position
            g_iLast[client][0] = 0;
            g_iLast[client][1] = 0;


            // Is a argument given?
            if (!StrEqual(argument, ""))
            {
                g_hDatabase.Escape(argument, argumentEscapedBuffer, sizeof(argumentEscapedBuffer));
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
void OpenSortChoiceMenu(int client)
{
    char display[64];

    // Create menu
    Menu menu = new Menu(OnSortChoose);

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    
    menu.SetTitle("%T", "ChooseSortType", client);

    Format(display, sizeof(display), "%T", "AllMaps", client);
    menu.AddItem("0", display);

    Format(display, sizeof(display), "%T", "NewestMaps", client);
    menu.AddItem("1", display);

    Format(display, sizeof(display), "%T", "LatestModifiedMaps", client);
    menu.AddItem("2", display);

    Format(display, sizeof(display), "%T", "MostDownloadedMaps", client);
    menu.AddItem("3", display);

    Format(display, sizeof(display), "%T", "MostViewedMaps", client);
    menu.AddItem("4", display);

    if (g_bClientprefsAvailable)
    {
        Format(display, sizeof(display), "%T\n ", "BestRatedMaps", client);
    }
    else
    {
        Format(display, sizeof(display), "%T", "BestRatedMaps", client);
    }

    menu.AddItem("5", display);

    if (g_bClientprefsAvailable)
    {
        Format(display, sizeof(display), "%T", "SortConfig", client);
        menu.AddItem("6", display);
    }

    menu.Display(client, 30);
}





// Client pressed a sort type
public int OnSortChoose(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select && IsClientValid(param1))
    {
        char choose[8];

        // Get Choice
        menu.GetItem(param2, choose, sizeof(choose));

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
        // Delete menu on end
        delete menu;
    }
}




// Open the config menu
void OpenConfigMenu(int client)
{
    char item[32];
    Menu menu = new Menu(OnChooseSortType);


    menu.SetTitle("%T", "ChooseSortTypeMaps", client);
    menu.ExitBackButton = true;

    Format(item, sizeof(item), "%T", "Ascending", client);
    menu.AddItem("1", item);

    Format(item, sizeof(item), "%T", "Descending", client);
    menu.AddItem("2", item);

    menu.Display(client, 30);
}




// Client pressed a sort type
public int OnChooseSortType(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select && IsClientValid(param1))
    {
        char choose[12];
        char display[32];
        Menu newMenu = new Menu(OnChooseSort);
        int clientCookie = GetClientConfigCookie(param1);

        newMenu.ExitBackButton = true;

        // Get Choice
        menu.GetItem(param2, choose, sizeof(choose));

        if (StrEqual(choose, "1"))
        {
            newMenu.SetTitle("%T:", "Ascending", param1);

            Format(display, sizeof(display), "%T", "SortByName", param1);
            newMenu.AddItem("1", display, (clientCookie == 0) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByDate", param1);
            newMenu.AddItem("3", display, (clientCookie == 3) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByMDate", param1);
            newMenu.AddItem("5", display, (clientCookie == 5) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByDownloads", param1);
            newMenu.AddItem("7", display, (clientCookie == 7) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByViews", param1);
            newMenu.AddItem("9", display, (clientCookie == 9) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByRating", param1);
            newMenu.AddItem("11", display, (clientCookie == 11) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        }
        else
        {
            newMenu.SetTitle("%T:", "Descending", param1);

            Format(display, sizeof(display), "%T", "SortByName", param1);
            newMenu.AddItem("0", display, (clientCookie == 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByDate", param1);
            newMenu.AddItem("2", display, (clientCookie == 2) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByMDate", param1);
            newMenu.AddItem("4", display, (clientCookie == 4) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByDownloads", param1);
            newMenu.AddItem("6", display, (clientCookie == 6) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByViews", param1);
            newMenu.AddItem("8", display, (clientCookie == 8) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

            Format(display, sizeof(display), "%T", "SortByRating", param1);
            newMenu.AddItem("10", display, (clientCookie == 10) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        }

        newMenu.Display(param1, 45);
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
        // Delete menu on end
        delete menu;
    }
}




// Client pressed a sort type
public int OnChooseSort(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select && IsClientValid(param1))
    {
        char choose[12];

        // Get Choice
        menu.GetItem(param2, choose, sizeof(choose));

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
        // Delete menu on end
        delete menu;
    }
}




// Open the menu with all Maps
void OpenMenuWithAllMaps(int client)
{
    SendCategories(client);
}




// Send the categories to the client
void SendCategories(int client)
{
    char query[4096];
    

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
    g_hDatabase.Query(OnSendCategories, query, GetClientUserId(client));
}





// Categories to menu
public void OnSendCategories(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client))
    {
        // Valid answer?
        if (results != null)
        {
            // Do we found something?
            if (results.FetchRow())
            {
                // Create menu
                Menu menu = new Menu(OnCategoryChoose);
                char id[16];
                char name[128];
                char item[128 + 32];


                menu.ExitBackButton = true;

                // Title
                if (StrEqual(g_sSearch[client][SEARCH], ""))
                {
                    menu.SetTitle("%T", "ChooseCategory", client);
                }
                else
                {
                    menu.SetTitle("%T", "Found", client, g_sSearch[client][SEARCHREAL]);
                }


                do
                {
                    // Fetch results
                    results.FetchString(0, id, sizeof(id));
                    results.FetchString(1, name, sizeof(name));


                    // Add to menu
                    Format(item, sizeof(item), "%s (%i %T)", name, results.FetchInt(2), "Maps", client);
                    
                    menu.AddItem(id, item);
                } while (results.FetchRow());


                // Now send menu at last positon
                menu.DisplayAt(client, g_iLast[client][0], MENU_TIME_FOREVER);
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
public int OnCategoryChoose(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select && IsClientValid(param1))
    {
        char choose[12];

        // Get Choice
        menu.GetItem(param2, choose, sizeof(choose));


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
        // Delete menu on end
        delete menu;
    }
}




// Send maps to client
void SendMaps(int client, char[] sort)
{
    if (IsClientValid(client))
    {
        char query[4096];

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
                int sortInt = StringToInt(sort);

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
        g_hDatabase.Query(OnSendMaps, query, GetClientUserId(client));
    }
}




// Maps to menu
public void OnSendMaps(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client))
    {
        bool isCustom = StrEqual(g_sSearch[client][CUSTOM], "1", false);

        if (results != null)
        {
            // Do we found something?
            if (results.FetchRow())
            {
                // Create menu
                Menu menu = new Menu(OnMapChoose);

                char game[16];
                char name[128];
                char date[64];
                char mdate[64];
                char downloads[12];
                char rating[12];
                char votes[12];
                char views[12];
                char file[256];
                char id[64];
                char size[32];
                char item[sizeof(name) + sizeof(rating) + sizeof(downloads) + 32];
                char item2[256 + 64 + 128 + 32 + 16 + 64 + 64 + 12 + 12 + 12 + 12 + 32];
                
                // Title
                menu.SetTitle("%T", "ChooseMap", client);
                menu.ExitBackButton = true;


                do
                {
                    // Fetch results
                    if (!isCustom)
                    {
                        results.FetchString(0, id, sizeof(id));
                        results.FetchString(1, date, sizeof(date));
                        results.FetchString(2, mdate, sizeof(mdate));
                        results.FetchString(3, downloads, sizeof(downloads));
                        results.FetchString(4, rating, sizeof(rating));
                        results.FetchString(5, votes, sizeof(votes));
                        results.FetchString(6, views, sizeof(views));
                        results.FetchString(7, name, sizeof(name));
                        results.FetchString(8, file, sizeof(file));
                        results.FetchString(9, size, sizeof(size));
                        results.FetchString(10, game, sizeof(game));
                    }
                    else
                    {
                        results.FetchString(0, name, sizeof(name));
                        results.FetchString(1, id, sizeof(id));
                    }


                    // Replace <| in name
                    ReplaceString(name, sizeof(name), "<|", "", false);


                    // Add to menu
                    if (!isCustom)
                    {
                        int sortTitle = StringToInt(g_sSearch[client][TITLE]);

                        switch(sortTitle)
                        {
                            case 0:
                            {
                                Format(item, sizeof(item), "%s (%s, %s %T)", name, rating, downloads, "DownloadsShort", client);
                            }
                            case 1:
                            {
                                char dateStr[64];
                                FormatTime(dateStr, sizeof(dateStr), "%d.%m.%Y %H:%M", StringToInt(date));

                                Format(item, sizeof(item), "%s (%s)", name, dateStr);
                            }
                            case 2:
                            {
                                char mdateStr[64];
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
                    menu.AddItem(item2, item);
                }
                while (results.FetchRow());


                // Now send menu
                menu.DisplayAt(client, g_iLast[client][1], MENU_TIME_FOREVER);
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
public int OnMapChoose(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select && IsClientValid(param1))
    {
        char choose[128 + 128 + 128 + 32 + 16 + 64 + 64 + 12 + 12 + 12 + 12 + 12];
        char splits[11][128];

        bool isCustom = StrEqual(g_sSearch[param1][CUSTOM], "1", false);


        // Get choice
        menu.GetItem(param2, choose, sizeof(choose));


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
        // Delete menu on end
        delete menu;
    }
}



// Creates the decide Menu
void createDecideMenu(int client, bool isCustom)
{
    char item[64];

    // Create information menu
    Menu menuNew = new Menu(OnDecide);

    // Title and back button
    menuNew.SetTitle("%T: %s\n \n%T\n%T\n%T\n%T\n%T\n%T\n ", "Map", client, g_sSearch[client][MAPNAME]
                                                                ,"Downloads", client, g_sSearch[client][DOWNLOADS], "Rating", client, g_sSearch[client][RATING], g_sSearch[client][VOTES], "Views"
                                                                ,client, g_sSearch[client][VIEWS], "Created", client, g_sSearch[client][DATE], "LatestModified", client, g_sSearch[client][MDATE], "Size"
                                                                , client, g_sSearch[client][MAPSIZE]);

    menuNew.Pagination = 3;

    // Items
    Format(item, sizeof(item), "%T", "Download", client);
    menuNew.AddItem("1", item);


    if (!isCustom)
    {
        Format(item, sizeof(item), "%T\n ", "Motd", client);
        menuNew.AddItem("2", item);
    }


    Format(item, sizeof(item), "%T", "Back", client);
    menuNew.AddItem("3", item);
    

    // Display Menu
    menuNew.Display(client, MENU_TIME_FOREVER);
}




// Player decided to download a map
public int OnDecide(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select && IsClientValid(param1))
    {
        char choose[16];
        char motdUrl[PLATFORM_MAX_PATH + 1];

        int choice;
        bool isCustom = StrEqual(g_sSearch[param1][CUSTOM], "1", false);


        // Get choice
        menu.GetItem(param2, choose, sizeof(choose));

        choice = StringToInt(choose);


        // Choice is 2 -> Open motd
        if (choice == 2 && !isCustom)
        {
            // Motd
            Format(motdUrl, sizeof(motdUrl), "http://%s.gamebanana.com/maps/%s", g_sSearch[param1][GAME], g_sSearch[param1][MAPID]);
            ShowMOTDPanel(param1, g_sSearch[param1][MAPNAME], motdUrl, MOTDPANEL_TYPE_URL);

            // Resend Menu
            createDecideMenu(param1, isCustom);
        }
        else if (choice == 1)
        {
            // Now start downloading
            if (isCustom)
            {
                // We need a random id
                int random = GetRandomInt(5000, 10000);

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
        // Delete menu on end
        delete menu;
    }
}







/*
**************

Download

**************
*/





// Now we can start
void StartDownloadingMap(int client, const char[] id, const char[] map, const char[] link, bool isCustom)
{
    char savePath[PLATFORM_MAX_PATH + 1];


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
        Format(g_Downloads[g_iTotalDownloads][DL_FILE], 128, link);
    }
    else
    {
        SplitString(map, ".", g_Downloads[g_iTotalDownloads][DL_NAME], 128);
        Format(g_Downloads[g_iTotalDownloads][DL_FILE], 128, "%s/%s", link, map);
    }

    strcopy(g_Downloads[g_iTotalDownloads][DL_ID], 32, id);
    strcopy(g_Downloads[g_iTotalDownloads][DL_SAVE], PLATFORM_MAX_PATH+1, savePath);


    // File array
    if (g_Downloads[g_iTotalDownloads][DL_FILES] != null)
    {
        CloseHandle(g_Downloads[g_iTotalDownloads][DL_FILES]);
    }
    
    // Create new Array
    g_Downloads[g_iTotalDownloads][DL_FILES] = CreateArray(PLATFORM_MAX_PATH + 1);


    // FTP File array
    if (g_Downloads[g_iTotalDownloads][DL_FTPFILES] != null)
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
void DownloadMap()
{
    // Update current download item
    g_iCurrentDownload++;

    // Finally start the download
    System2HTTPRequest downloadRequest = new System2HTTPRequest(OnDownloadFinished, g_Downloads[g_iCurrentDownload][DL_FILE]);
    downloadRequest.SetProgressCallback(OnDownloadUpdate);
    downloadRequest.SetOutputFile(g_Downloads[g_iCurrentDownload][DL_SAVE]);
    downloadRequest.GET();
    delete downloadRequest;
}


// Download updated
public void OnDownloadUpdate(System2HTTPRequest request, int dlTotal, int dlNow, int ulTotal, int ulNow)
{
    // Save the download bytes in kilobytes
    g_Downloads[g_iCurrentDownload][DL_CURRENT] = dlNow / 1024.0;
    g_Downloads[g_iCurrentDownload][DL_TOTAL] = dlTotal / 1024.0;

    // Show status
    SendCurrentStatus();
}


// Download finished
public void OnDownloadFinished(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    char detailError[256];

    // Response 200 expected
    if (success && response.StatusCode != 200)
    {
        success = false;
        Format(detailError, sizeof(detailError), "Expected HTTP status code 200, but got %d", response.StatusCode);
    }
    else
    {
        strcopy(detailError, sizeof(detailError), error);
    }

    // Finished with Error?
    if (!success)
    {
        if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
        {
            CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Failed", detailError);
        }

        Log("%L: Downloading Map %s(%s) FAILED: %s", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE], detailError);

        // Stop
        StopDownload();
    }
    else
    {
        char extractPath[PLATFORM_MAX_PATH + 1];
        
        // Create path to extract to, this is the unique path
        Format(extractPath, sizeof(extractPath), "%s/%s", g_sPluginPath, g_Downloads[g_iCurrentDownload][DL_ID]);

        // Only extract it if it's not a .bsp file
        if (!StrEndsWith(g_Downloads[g_iCurrentDownload][DL_SAVE], ".bsp"))
        {
            // Now extract it
            System2_Extract(OnExtracted, g_Downloads[g_iCurrentDownload][DL_SAVE], extractPath,0, g_bForce32Bit);
        }
        else
        {
            char fileName[128];

            // Move .bsp files directly to the extract path
            GetFileName(g_Downloads[g_iCurrentDownload][DL_SAVE], fileName, sizeof(fileName));
            Format(extractPath, sizeof(extractPath), "%s/%s", extractPath, fileName);

            System2_CopyFile(CopyFinished, g_Downloads[g_iCurrentDownload][DL_SAVE], extractPath, true);
        }
    }
}




// Stop download and go to next one
void StopDownload()
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
public void OnExtracted(bool success, const char[] command, System2ExecuteOutput output)
{
    // Error?
    if (!success || (output != null && output.ExitStatus != 0))
    {
        if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
        {
            CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Failed", command);
        }

        Log("%L: Downloading Map %s(%s) FAILED: %s", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE], command);

        // Stop
        StopDownload();
    }
    else
    {
        // Doesn't seems so
        char extractPath[PLATFORM_MAX_PATH + 1];
        

        // Format unique file path
        Format(extractPath, sizeof(extractPath), "%s/%s", g_sPluginPath, g_Downloads[g_iCurrentDownload][DL_ID]);

        // What we found?
        int found = SearchForFolders(extractPath, 0);

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
                char dllistFile[PLATFORM_MAX_PATH + 1];
                char content[64];
                char readbuffer[64];

                File file;
                bool duplicate;

                int arraySize = GetArraySize(g_Downloads[g_iCurrentDownload][DL_FTPFILES]);


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
                if (file != null)
                {
                    // Loop through files
                    for (int i=0; i < arraySize; i++)
                    {
                        // First get content
                        GetArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], i, content, sizeof(content));


                        // No .bsp or .nav files
                        if (!StrEndsWith(content, ".nav") && !StrEndsWith(content, ".bsp") && !StrEndsWith(content, ".txt") && !StrEndsWith(content, ".jpg") && !StrEndsWith(content, ".jpeg"))
                        {
                            // Set File pointer to start
                            file.Seek(0, SEEK_SET);

                            // Resetz duplicate
                            duplicate = false;


                            // Loop through file content and search if file already in downloadlist
                            while (!file.EndOfFile() && file.ReadLine(readbuffer, sizeof(readbuffer)))
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
                                // Add to download table
                                AddFileToDownloadsTable(content);

                                // Add a carriage return as line ending for WindowsOS
                                if (System2_GetOS() == OS_WINDOWS)
                                {
                                    StrCat(content, sizeof(content), "\r");
                                }

                                file.WriteLine(content);
                            }
                        }
                    }


                    // Close File
                    file.Close();
                }
            }



            // Using ftp?
            if (g_bFTP)
            {
                // Now Upload it to the Fast DL Server
                // First Compress all files
                char file[128];
                char archive[128];
                
                
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
                System2_Compress(OnCompressed, file, archive, ARCHIVE_BZIP2, LEVEL_3, 0, g_bForce32Bit);
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






/*
    Searching for folders and files
    We can only copy known folders, because we can't know the path of a single file.
    We only know where to put .bsp and .nav files
*/
int SearchForFolders(char[] path, int found)
{
    char newPath[PLATFORM_MAX_PATH + 1];
    char content[128];


    // Open current dir
    DirectoryListing dir = OpenDirectory(path);
    FileType type;



    if (dir != null)
    {
        // Read extract path
        while (dir.GetNext(content, sizeof(content), type))
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
                    System2_CopyFile(CopyFinished, newPath, content, false);

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
                        System2_CopyFile(CopyFinished, newPath, content, false);
                    }
                }

                // jpg file?
                else if ((StrEndsWith(content, ".jpg") || StrEndsWith(content, ".jpeg")) && type == FileType_File)
                {
                    // Add File to file list, for uploading
                    PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], newPath);


                    // Copy jpg to maps folder
                    Format(content, sizeof(content), "maps/%s", content);

                    PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], content);
                    System2_CopyFile(CopyFinished, newPath, content, false);
                }

                // Map file
                else if (StrEndsWith(content, ".bsp") && type == FileType_File)
                {
                    char buff[128];


                    // Add File to file list, for uploading
                    PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], newPath);


                    // Copy map to maps folder
                    Format(buff, sizeof(buff), "maps/%s", content);

                    PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], buff);
                    System2_CopyFile(CopyFinished, newPath, buff, false);


                    
                    // Maybe auto add it to the mapcycle file
                    // Maplist doesn't exist anymore and mani's votemaplist also not
                    if (g_bMapCycle)
                    {
                        // File
                        char readbuffer[PLATFORM_MAX_PATH];
                        char mapcyclePath[PLATFORM_MAX_PATH];
                        File mapcycle = null;


                        // We don't need the .bsp extension^^
                        ReplaceString(content, sizeof(content), ".bsp", "");


                        // After steam pipe update mapcycle file is in cfg folder
                        if (FileExists("cfg/mapcycle.txt"))
                        {
                            strcopy(mapcyclePath, sizeof(mapcyclePath), "cfg/mapcycle.txt");
                        }

                        // But the old path is also possible
                        else
                        {
                            strcopy(mapcyclePath, sizeof(mapcyclePath), "mapcycle.txt");
                        }


                        // Found valid mapcycle?
                        mapcycle = OpenFile(mapcyclePath, "r+b");
                        if (mapcycle != null)
                        {
                            // Search for duplicate
                            bool duplicate = false;
                            bool added = false;
                            ArrayList maps = new ArrayList(PLATFORM_MAX_PATH);

                            while (!mapcycle.EndOfFile() && mapcycle.ReadLine(readbuffer, sizeof(readbuffer)))
                            {
                                // Replace line ends
                                ReplaceString(readbuffer, sizeof(readbuffer), "\n", "");
                                ReplaceString(readbuffer, sizeof(readbuffer), "\t", "");
                                ReplaceString(readbuffer, sizeof(readbuffer), "\r", "");

                                // No comments
                                if (readbuffer[0] == '/' || readbuffer[0] == ' ')
                                {
                                    maps.PushString(readbuffer);
                                    continue;
                                }


                                if (StrEqual(content, readbuffer, false))
                                {
                                    // Found duplicate!
                                    duplicate = true;
                                    break;
                                }

                                // Keep sorting of the file
                                if (!added && strcmp(content, readbuffer, false) <= 0)
                                {
                                    maps.PushString(content);
                                    added = true;
                                }

                                maps.PushString(readbuffer);
                            }

                            // Close the file
                            mapcycle.Close();

                            // If not in mapcycle, add it
                            if (!duplicate)
                            {
                                // Maybe it should stay at last line
                                if (!added)
                                {
                                    maps.PushString(content);
                                }

                                // Open the mapcycle writeable
                                mapcycle = OpenFile(mapcyclePath, "w+b");
                                if (mapcycle != null)
                                {
                                    for (int i = 0; i < maps.Length; i++)
                                    {
                                        maps.GetString(i, readbuffer, sizeof(readbuffer));

                                        // Add a carriage return as line ending for WindowsOS
                                        if (System2_GetOS() == OS_WINDOWS)
                                        {
                                            StrCat(readbuffer, sizeof(readbuffer), "\r");
                                        }

                                        mapcycle.WriteLine(readbuffer);
                                    }

                                    mapcycle.Close();
                                }
                            }

                            // delete the maps array
                            delete maps;
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


        // Close dir
        delete dir;
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
void CopyToGameDir(const char[] path, const char[] cur)
{
    // Name buffer
    char buffer[128];
    char file[128];

    // Open dir
    DirectoryListing dir = OpenDirectory(path);


    // First create current path in gamedir
    if (!DirExists(cur))
    {
        CreateDirectory(cur, 511);
    }


    // Should never be a null
    if (dir != null)
    {
        // What we found?
        FileType type;

        
        // While found something
        while (dir.GetNext(buffer, sizeof(buffer), type))
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
                    System2_CopyFile(CopyFinished, buffer, file, false);

                    // Update file count
                    PushArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], buffer);
                    PushArrayString(g_Downloads[g_iCurrentDownload][DL_FTPFILES], file);
                }
            }
        }

        // Close Handle
        delete dir;
    }
}





// Copy finished
public void CopyFinished(bool success, char[] from, char[] to, any extractOnFinish)
{
    // We only log any errors
    if (!success)
    {
        LogError("Couldn't copy file %s to %s!", from, to);
    }
    else if (extractOnFinish)
    {
        OnExtracted(true, "", null);
    }
}







/*
**************

Compressing and Uploading

**************
*/




// Compress updated
public void OnCompressed(bool success, const char[] command, System2ExecuteOutput output)
{
    // Error?
    if (!success || output.ExitStatus != 0)
    {
        if (IsClientValid(g_Downloads[g_iCurrentDownload][DL_CLIENT]))
        {
            CPrintToChat(g_Downloads[g_iCurrentDownload][DL_CLIENT], "%s %t", g_sTagChat, "Failed", command);
        }

        Log("%L: Downloading Map %s(%s) FAILED: %s", g_Downloads[g_iCurrentDownload][DL_CLIENT], g_Downloads[g_iCurrentDownload][DL_NAME], g_Downloads[g_iCurrentDownload][DL_FILE], command);

        // Stop
        StopDownload();
    }
    else
    {
        // Compress next file
        char file[PLATFORM_MAX_PATH + 1];
        char archive[PLATFORM_MAX_PATH + 1];
        
        
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
            char url[256];
            Format(url, sizeof(url), "ftp://%s/%s", g_sFTPHost, archive);

            System2FTPRequest uploadRequest = new System2FTPRequest(OnUploadFinished, url);
            uploadRequest.CreateMissingDirs = true;
            uploadRequest.SetPort(g_iFTPPort);
            uploadRequest.SetProgressCallback(OnUploadProgress);
            uploadRequest.SetInputFile(file);

            if (!g_bFTPLogin)
            {
                uploadRequest.SetAuthentication(g_sFTPUser, g_sFTPPW);
            }
            else
            {
                uploadRequest.SetAuthentication(g_sLogin[g_Downloads[g_iCurrentDownload][DL_CLIENT]][0], g_sLogin[g_Downloads[g_iCurrentDownload][DL_CLIENT]][1]);
            }

            uploadRequest.StartRequest();
            delete uploadRequest;
        }
        else
        {
            // Get next File
            GetArrayString(g_Downloads[g_iCurrentDownload][DL_FILES], g_Downloads[g_iCurrentDownload][DL_FINISH], file, sizeof(file));
            

            // Get Archive
            Format(archive, sizeof(archive), "%s.bz2", file);


            // Compress
            // Next step is in OnCompressed when every file is compressed
            System2_Compress(OnCompressed, file, archive, ARCHIVE_BZIP2, LEVEL_3, 0, g_bForce32Bit);
        }
    }
}





// Upload finished
public void OnUploadFinished(bool success, const char[] error, System2FTPRequest request, System2FTPResponse response)
{
    // Finished with Error?
    if (!success)
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
        // Upload next file
        char file[PLATFORM_MAX_PATH + 1];
        char archive[PLATFORM_MAX_PATH + 1];
        
        
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

            char url[256];
            Format(url, sizeof(url), "ftp://%s/%s", g_sFTPHost, archive);

            // Reuse the copied request
            request.SetURL(url);
            request.SetInputFile(file);
            request.StartRequest();
        }
    }
}




// Upload updated
public void OnUploadProgress(System2FTPRequest request, int dlTotal, int dlNow, int ulTotal, int ulNow)
{
    // Save the download bytes in kilobytes
    g_Downloads[g_iCurrentDownload][DL_CURRENT] = ulNow / 1024.0;
    g_Downloads[g_iCurrentDownload][DL_TOTAL] = ulTotal / 1024.0;

    // Show status
    SendCurrentStatus();
}
