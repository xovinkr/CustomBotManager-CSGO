// Создатель мода qw1zzr
// скомпилировано 26.03.2026 в 19:47
// хз нахуя вам эта информация, но тип да
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Custom Bot Manager",
	author = "qw1zzr",
	description = "Bot Manager with Fake Ping, ClanTag and BotName",
	version = "1.0",
	url = "https://github.com/xovinkr/CustomBotManager-CSGO"
};

ArrayList g_hNameQueue;
ArrayList g_hTagQueue;
ConVar g_cvFakePing;
ConVar g_cvSuppress;

int g_iPlayerResource = -1;
int g_iBotPings[MAXPLAYERS + 1];

public void OnPluginStart() 
{
	g_hNameQueue = new ArrayList(MAX_NAME_LENGTH);
	g_hTagQueue = new ArrayList(MAX_NAME_LENGTH);

	RegServerCmd("cbm_botname", Command_AddName);
	RegServerCmd("cbm_bottag", Command_AddTag);
	RegServerCmd("cbm_clear", Command_ClearAll);

	g_cvFakePing = CreateConVar("cbm_fakeping", "1");
	g_cvSuppress = CreateConVar("cbm_suppress", "1");

	HookUserMessage(GetUserMessageId("SayText2"), OnSayText2, true);

	CreateTimer(2.0, Timer_UpdatePingValues, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	delete g_hNameQueue;
	delete g_hTagQueue;
}

public void OnMapStart()
{
	g_iPlayerResource = GetPlayerResourceEntity();
}

public Action Command_AddName(int args)
{
	if (args < 1) return Plugin_Handled;
	char buffer[MAX_NAME_LENGTH];
	GetCmdArgString(buffer, sizeof(buffer));
	StripQuotes(buffer);
	TrimString(buffer);
	if (strlen(buffer) > 0) g_hNameQueue.PushString(buffer);
	return Plugin_Handled;
}

public Action Command_AddTag(int args)
{
	if (args < 1) return Plugin_Handled;
	char buffer[MAX_NAME_LENGTH];
	GetCmdArgString(buffer, sizeof(buffer));
	StripQuotes(buffer);
	TrimString(buffer);
	if (strlen(buffer) > 0) g_hTagQueue.PushString(buffer);
	return Plugin_Handled;
}

public Action Command_ClearAll(int args)
{
	g_hNameQueue.Clear();
	g_hTagQueue.Clear();
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
	{
		g_iBotPings[client] = 20 + GetRandomInt(0, 10);
		SDKHook(client, SDKHook_PostThinkPost, OnBotThinkPost);
		CreateTimer(0.5, Timer_ApplyBotData, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_UpdatePingValues(Handle timer)
{
	if (!g_cvFakePing.BoolValue) return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
		{
			g_iBotPings[i] = 25 + (i % 10) + GetRandomInt(0, 7);
		}
	}
	return Plugin_Continue;
}

public void OnBotThinkPost(int client)
{
	if (IsClientInGame(client) && g_iPlayerResource != -1)
	{
		SetEntProp(g_iPlayerResource, Prop_Send, "m_iPing", g_iBotPings[client], _, client);
	}
}

public Action Timer_ApplyBotData(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0 || !IsClientInGame(client)) return Plugin_Stop;

	if (g_hNameQueue.Length > 0)
	{
		char nextName[MAX_NAME_LENGTH];
		g_hNameQueue.GetString(0, nextName, sizeof(nextName));
		g_hNameQueue.Erase(0);

		SetClientInfo(client, "name", nextName);
		SetEntPropString(client, Prop_Data, "m_szNetname", nextName);
	}

	if (g_hTagQueue.Length > 0)
	{
		char nextTag[MAX_NAME_LENGTH];
		g_hTagQueue.GetString(0, nextTag, sizeof(nextTag));
		g_hTagQueue.Erase(0);

		CS_SetClientClanTag(client, nextTag);
		SetEntPropString(client, Prop_Send, "m_szClan", nextTag);
	}

	Handle event = CreateEvent("player_info");
	if (event != null)
	{
		SetEventInt(event, "userid", GetClientUserId(client));
		SetEventInt(event, "index", client - 1);
		SetEventBool(event, "bot", false);
		FireEvent(event);
	}

	return Plugin_Stop;
}

public Action OnSayText2(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!g_cvSuppress.BoolValue) return Plugin_Continue;
	char message[64];
	PbReadString(bf, "msg_name", message, sizeof(message));
	if (StrContains(message, "Name_Change") != -1 || StrContains(message, "Join_Team") != -1)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}