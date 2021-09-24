#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

Database gH_SQL = null;
Database gH_SQL_new = null;

public void OnPluginStart()
{
    FREAK_CONNECT();

    RegConsoleCmd("sm_convert_zones", Command_Convert);
    RegConsoleCmd("sm_convert_playertimes", Command_convert_playertimes);
    RegConsoleCmd("sm_convert_bonus", Command_convert_bonus);
    RegConsoleCmd("sm_convert_maptier", Command_convert_maptier);
}

public Action Command_Convert(int client, int args)
{
    SQLdump();

    return Plugin_Handled;
}

public Action Command_convert_playertimes(int client, int args)
{
    SQLDump_Playertimes();

    return Plugin_Handled;
}

public Action Command_convert_bonus(int client, int args)
{
    SQLDump_Bonus();

    return Plugin_Handled;
}

public Action Command_convert_maptier(int client, int args)
{
    SQLDump_Maptier();

    return Plugin_Handled;
}

void SQLdump()
{
    char sQuery[512];
    FormatEx(sQuery, 512, "SELECT `mapname`, `zonegroup`, `hookname`,"...
                            "`zonetype`, `zonetypeid`,"...
                            "`pointa_x`, `pointa_y`, `pointa_z`,"...
                            "`pointb_x`, `pointb_y`, `pointb_z`"...
                            "FROM `ck_zones`;");
    gH_SQL.Query(SQL_SQLdump_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_SQLdump_Callback(Database db, DBResultSet results, const char[] error, any d)
{
    if(results == null)
    {
        SetFailState("sqldump error. %s", error);
        return;
    }

    int iCount = 0;

    while(results.FetchRow())
    {
        char sMapname[160];
        results.FetchString(0, sMapname, 160);

        int track = results.FetchInt(1);

        char sHookname[128];
        results.FetchString(2, sHookname, 128);

        if(StrEqual(sHookname, "None"))
        {
            strcopy(sHookname, 128, "NONE");
        }

        // Start(1), End(2), Stage(3), Checkpoint(4), Speed(5),
        // TeleToStart(6), Validator(7), Chekcer(8), Stop(0), AntiJump(9),
        // AntiDuck(10), MaxSpeed(11) //4以上的都不要了
        /* enum
        {
            Zone_Start,
            Zone_End,
            Zone_Stage,
            Zone_Checkpoint,
            Zone_Stop,
            Zone_Teleport,
            Zone_Mark,
            ZONETYPES_SIZE
        }; */

        int type = results.FetchInt(3) - 1;// zone_start starts from 0.

        if(type > 3)
        {
            continue;
        }

        int data = results.FetchInt(4);

        if(type == 2)
        {
            data += 2;// ck stage starts from 0, shavit stage starts from 2.
        }

        else if(type == 3)
        {
            data += 1;// ck checkpoint starts from 0, shavit checkpoint starts from 1.
        }

        float corner_1[3];
        corner_1[0] = results.FetchFloat(5);
        corner_1[1] = results.FetchFloat(6);
        corner_1[2] = results.FetchFloat(7);

        float corner_2[3];
        corner_2[0] = results.FetchFloat(8);
        corner_2[1] = results.FetchFloat(9);
        corner_2[2] = results.FetchFloat(10);

        char sQuery[512];
        FormatEx(sQuery, 512,
			"INSERT INTO mapzones (map, type, corner1_x, corner1_y, corner1_z, corner2_x, corner2_y, corner2_z, destination_x, destination_y, destination_z, track, flags, data, hookname) VALUES ('%s', %d, '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', '%.03f', %d, %d, %d, '%s');",
			sMapname, type, corner_1[0], corner_1[1], corner_1[2], corner_2[0], corner_2[1], corner_2[2], 0, 0, 0, track, 0, data, sHookname);
        
        gH_SQL_new.Query(SQL_SQLinsert_Callback, sQuery, iCount++, DBPrio_High);
    }
}

public void SQL_SQLinsert_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
    {
        SetFailState("sqlinsert error. %s", error);
        return;
    }

    PrintToServer("%d insert already", data);
}

void SQLDump_Playertimes()
{
    char sQuery[512];
    FormatEx(sQuery, 512, "SELECT `steamid`, `mapname`, `name`, `runtimepro` FROM `ck_playertimes`;");
    gH_SQL.Query(SQL_SQLdump_Playertimes_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_SQLdump_Playertimes_Callback(Database db, DBResultSet results, const char[] error, any d)
{
    if(results == null)
    {
        SetFailState("sqldump Playertimes error. %s", error);
        return;
    }

    int iCount = 0;

    while(results.FetchRow())
    {
        char sSteamid[32];
        results.FetchString(0, sSteamid, sizeof(sSteamid));
        //STEAM_X:Y:Z.
        //For 32-bit systems
        //W=Z*2+Y
        //STEAM_1:1:61512149
        //---> 61512149*2 = 123024298
        //steam3 = 123024298 + 1
        //123024299
        char sSteamidTemp[3][32];
        ExplodeString(sSteamid, ":", sSteamidTemp, 3, 32);

        int y = StringToInt(sSteamidTemp[1]);
        int z = StringToInt(sSteamidTemp[2]);
        int iSteamid = z*2 + y;

        char sMapname[160];
        results.FetchString(1, sMapname, 160);

        char sName[MAX_NAME_LENGTH];
        results.FetchString(2, sName, MAX_NAME_LENGTH);

        float fTime = results.FetchFloat(3);

        DataPack dp = new DataPack();
        dp.WriteCell(iSteamid);
        dp.WriteCell(iCount++);
        dp.WriteString(sMapname);
        dp.WriteFloat(fTime);

        char sQuery[512];
        FormatEx(sQuery, 512,
            "REPLACE INTO `users` (auth, name) VALUES (%d, '%s');",
        iSteamid, sName);
        
        gH_SQL_new.Query(SQL_SQLinsert_playertimes_Callback, sQuery, dp, DBPrio_High);
    }
}

public void SQL_SQLinsert_playertimes_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
    if(results == null)
    {
        PrintToServer("sqlinsert playertimes_Callback error. %s", error);
    }

    dp.Reset();

    int iSteamid = dp.ReadCell();
    int iCount = dp.ReadCell();

    char sMapname[160];
    dp.ReadString(sMapname, 160);

    float time = dp.ReadFloat();

    delete dp;

    PrintToServer("%d convert success.", iCount);

    char sQuery[512];
    FormatEx(sQuery, 512,
        "INSERT INTO playertimes (auth, map, time, jumps, date, style, strafes, sync) VALUES (%d, '%s', %f, 0, 0, 0, 0, 100);",
        iSteamid, sMapname, time);
    
    gH_SQL_new.Query(SQL_SQLinsert_playertimes_Callback2, sQuery, iCount);
}

public void SQL_SQLinsert_playertimes_Callback2(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
    {
        PrintToServer("sqlinsert playertimes_Callback2 error. %s", error);
    }

    PrintToServer("%d insert success.", data);
}

void SQLDump_Bonus()
{
    char sQuery[512];
    FormatEx(sQuery, 512, "SELECT `steamid`, `mapname`, `name`, `runtime`, `zonegroup` FROM `ck_bonus`;");
    gH_SQL.Query(SQL_SQLdump_Bonus_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_SQLdump_Bonus_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
    {
        PrintToServer("sqlinsert Bonus_Callback error. %s", error);
    }

    int iCount = 0;

    while(results.FetchRow())
    {
        char sSteamid[32];
        results.FetchString(0, sSteamid, sizeof(sSteamid));
        //STEAM_X:Y:Z.
        //For 32-bit systems
        //W=Z*2+Y
        //STEAM_1:1:61512149
        //---> 61512149*2 = 123024298
        //steam3 = 123024298 + 1
        //123024299
        char sSteamidTemp[3][32];
        ExplodeString(sSteamid, ":", sSteamidTemp, 3, 32);

        int y = StringToInt(sSteamidTemp[1]);
        int z = StringToInt(sSteamidTemp[2]);
        int iSteamid = z*2 + y;

        char sMapname[160];
        results.FetchString(1, sMapname, 160);

        char sName[MAX_NAME_LENGTH];
        results.FetchString(2, sName, MAX_NAME_LENGTH);

        float fTime = results.FetchFloat(3);
        int track = results.FetchInt(4);

        DataPack dp = new DataPack();
        dp.WriteCell(iSteamid);
        dp.WriteCell(iCount++);
        dp.WriteString(sMapname);
        dp.WriteFloat(fTime);
        dp.WriteCell(track);

        char sQuery[512];
        FormatEx(sQuery, 512,
            "REPLACE INTO `users` (auth, name) VALUES (%d, '%s');",
        iSteamid, sName);
        
        gH_SQL_new.Query(SQL_SQLinsert_bonus_Callback, sQuery, dp, DBPrio_High);
    }
}

public void SQL_SQLinsert_bonus_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
    if(results == null)
    {
        PrintToServer("sqlinsert bonus_Callback error. %s", error);
    }

    dp.Reset();

    int iSteamid = dp.ReadCell();
    int iCount = dp.ReadCell();

    char sMapname[160];
    dp.ReadString(sMapname, 160);

    float time = dp.ReadFloat();
    int track = dp.ReadCell();

    delete dp;

    PrintToServer("%d convert success.", iCount);

    char sQuery[512];
    FormatEx(sQuery, 512,
        "INSERT INTO playertimes (auth, map, time, jumps, date, style, strafes, sync, track) VALUES (%d, '%s', %f, 0, 0, 0, 0, 100, %d);",
        iSteamid, sMapname, time, track);
    
    gH_SQL_new.Query(SQL_SQLinsert_bonus_Callback2, sQuery, iCount);
}

public void SQL_SQLinsert_bonus_Callback2(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
    {
        PrintToServer("sqlinsert bonus_Callback2 error. %s", error);
    }

    PrintToServer("%d insert success.", data);
}

void SQLDump_Maptier()
{
    char sQuery[512];
    FormatEx(sQuery, 512, "SELECT `mapname`, `tier`, `maxvelocity` FROM `ck_maptier`;");
    gH_SQL.Query(SQL_SQLdump_Tier_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_SQLdump_Tier_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
    {
        PrintToServer("SQL_SQLdump_Tier_Callback error. %s", error);
    }

    int iCount = 0;

    while(results.FetchRow())
    {
        char sMapname[160];
        results.FetchString(0, sMapname, 160);

        int tier = results.FetchInt(1);
        float maxvel = results.FetchFloat(2);

        char sQuery[512];
        FormatEx(sQuery, 512,
            "INSERT INTO maptiers (map, tier, maxvelocity) VALUES ('%s', %d, %f);",
            sMapname, tier, maxvel);
        
        gH_SQL_new.Query(SQL_SQLinsert_tier_Callback, sQuery, iCount++, DBPrio_High);
    }
}

public void SQL_SQLinsert_tier_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
    {
        PrintToServer("SQL_SQLinsert_tier_Callback error. %s", error);
    }

    PrintToServer("%d insert success", data);
}

void FREAK_CONNECT()
{
    char sError[255];
    gH_SQL = SQL_Connect("surftimer", true, sError, 255);

    char sError2[255];
    gH_SQL_new = SQL_Connect("shavit", true, sError, 255);

    if(gH_SQL == null)
    {
        SetFailState("connect to surftimer failed. %s", sError);
        return;
    }

    if(gH_SQL_new == null)
    {
        SetFailState("connect to shavit failed. %s", sError2);
        return;
    }
}