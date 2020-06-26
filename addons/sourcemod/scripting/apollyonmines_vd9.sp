#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define SOUND_PLACE "weapons/slam/mine_mode.wav"
#define SOUND_ARMING "npc/roller/mine/combine_mine_deploy1.wav"
#define SOUND_ARMED "buttons/blip1.wav"

#define MODEL_MINE "models/props_lab/tpplug.mdl" 
#define MODEL_BEAM "materials/sprites/purplelaser1.vmt"

#define LASER_WIDTH 0.6//0.12
#define LASER_COLOR_CMB "255 0 0"
#define LASER_COLOR_REB "0 0 255"

#define TRACE_START 1.0
#define TRACE_LENGTH 80.0

#define COMMAND "mine"
#define ALTCOMMAND "tripmine"

public Plugin:myinfo = {

	name = "apollyonmines",
	author = "apollyon094",
	description = "Apollyon's TDM mines",
	version = "1.0.8",
	url = "apollyon094.blogspot.com"

};

new Handle:sm_pp_tripmines;
new Handle:sm_pp_minedmg;
new Handle:sm_pp_minerad;
new Handle:sm_pp_minefilter;

#define sm_pp_tripmines_desc "Number of mines each player gets per round"

new num_mines[MAXPLAYERS+1];
new mine_counter = 0;
new bool:explosion_sound_enable=true;
new last_mine_used;
new minefilter;

public OnPluginStart() {

	sm_pp_tripmines = CreateConVar("sm_pp_tripmines", "8", sm_pp_tripmines_desc, 0);
	sm_pp_minedmg = CreateConVar("sm_pp_minedmg", "128", "damage (magnitude) of the tripmines", 0);
	sm_pp_minerad = CreateConVar("sm_pp_minerad", "0", "override for explosion damage radius", 0);
	sm_pp_minefilter = CreateConVar("sm_pp_minefilter", "0", "0 = detonate when laser touches anyone, 1 = enemies and owner only, 2 = enemies only", 0);

	HookEvent("round_start", Event_RoundStart);
	HookConVarChange(sm_pp_tripmines, CVarChanged_tripmines);
	HookConVarChange(sm_pp_minefilter, CVarChanged_minefilter);

	RegConsoleCmd(COMMAND, Command_Mine);

	if(strlen(ALTCOMMAND) != 0) {

		RegConsoleCmd(ALTCOMMAND, Command_Mine);

	}

	minefilter = GetConVarInt(sm_pp_minefilter);

}

public OnMapStart() {

	PrecacheSound(SOUND_PLACE, true);
	PrecacheSound(SOUND_ARMING, true);
	PrecacheSound(SOUND_ARMED, true);
	PrecacheModel(MODEL_MINE);
	PrecacheModel(MODEL_BEAM, true);

}

bool:IsValidClient(client) {

	return (client > 0 && client <= MaxClients && IsClientInGame(client));

}

public CVarChanged_tripmines(Handle:cvar, const String:oldval[], const String:newval[]) {

	if(strcmp(oldval, newval) == 0) {

		return;

	}

	ClampMines();

}

public CVarChanged_minefilter(Handle:cvar, const String:oldval[], const String:newval[]) {

	if(strcmp(oldval, newval) == 0) {

		return;

	}

	minefilter = GetConVarInt(sm_pp_minefilter);

}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {

	GiveAllPlayersMines();

	mine_counter = 0;

	explosion_sound_enable=true;

}

public OnClientConnected(client) {

	GivePlayerMines(client);

}

public OnClientDisconnect(client) {

	DeletePlacedMines(client);
	
}

public DeletePlacedMines(client) {

	new ent = -1;

	decl String:name[32];

	while((ent = FindEntityByClassname(ent, "prop_physics_override")) != -1) {

		GetEntPropString(ent, Prop_Data, "m_iName", name, 32);

		if(strncmp(name, "apollyontripmine", 11, true) == 0) {

			if(GetEntPropEnt(ent, Prop_Data, "m_hLastAttacker") == client) {

				AcceptEntityInput(ent, "Kill");	

			}

		}
	}

	while((ent = FindEntityByClassname(ent, "env_beam")) != -1) {

		GetEntPropString(ent, Prop_Data, "m_iName", name, 32);

		if(strncmp(name, "apollyontripmine", 11, true) == 0) {

			if(GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity") == client) {

				AcceptEntityInput(ent, "Kill");

			}

		}

	}

}

public GiveAllPlayersMines() {

	new mines = GetConVarInt(sm_pp_tripmines);

	for(new i = 0; i < MAXPLAYERS+1; i++) {

		num_mines[i] = mines;

	}

}

public GivePlayerMines(client) {

	new mines = GetConVarInt(sm_pp_tripmines);

	num_mines[client] = mines;
}


public ClampMines() {

	new mines = GetConVarInt(sm_pp_tripmines);

	for(new i = 0; i < MAXPLAYERS+1; i++) {

		if(num_mines[i] > mines) {

			num_mines[i] = mines;

		}

	}

}

public Action:Command_Mine(client, args) {

	if(IsClientConnected(client)) {

		if(IsPlayerAlive(client)) {

			if(num_mines[client] > 0) {

				PlaceMine(client);

			} else {

				if(GetConVarInt(sm_pp_tripmines) != 0) {

					PrintCenterText(client, "You have no more mines.");

				} else {

					PrintCenterText(client, "Mines are disabled.");

				}

			}

		}

	}

	return Plugin_Handled;

}

public PlaceMine(client) {

	decl Float:trace_start[3], Float:trace_angle[3], Float:trace_end[3], Float:trace_normal[3];

	GetClientEyePosition(client, trace_start);
	GetClientEyeAngles(client, trace_angle);
	GetAngleVectors(trace_angle, trace_end, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(trace_end, trace_end);

	for(new i = 0; i < 3; i++) {

		trace_start[i] += trace_end[i] * TRACE_START;

	}

	for(new i = 0; i < 3; i++) {

		trace_end[i] = trace_start[i] + trace_end[i] * TRACE_LENGTH;

	}

	TR_TraceRayFilter(trace_start, trace_end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_All, 0);

	if(TR_DidHit(INVALID_HANDLE)) {

		num_mines[client]--;

		if(num_mines[client] != 0) {

			PrintCenterText(client, "You have %d mines left!", num_mines[client]);

		} else {

			PrintCenterText(client, "That was your last mine!");

		}

		TR_GetEndPosition(trace_end, INVALID_HANDLE);
		TR_GetPlaneNormal(INVALID_HANDLE, trace_normal);

		SetupMine(client, trace_end, trace_normal);

	} else {

		PrintCenterText(client, "Invalid mine position.");

	}

}

public bool:TraceFilter_All(entity, contentsMask) {

	return false;

}

public MineLaser_OnTouch(const String:output[], caller, activator, Float:delay) {

	AcceptEntityInput(caller, "TurnOff");
	AcceptEntityInput(caller, "TurnOn");

	if(!IsValidClient(activator)) {

		return;

	}

	if(!IsPlayerAlive(activator)) {

		return;

	}

	new bool:detonate = false;

	if(minefilter == 1 || minefilter == 2) {

		new owner = GetEntPropEnt(caller, Prop_Data, "m_hOwnerEntity");

		if(!IsValidClient(owner)) {

			detonate = true;

		} else {

			new team = GetClientTeam(owner);

			if(GetClientTeam(activator) != team || (owner == activator && minefilter == 1)) {

				detonate = true;

			}

		}

	} else if(minefilter == 0) {

		detonate = true;

	}

	if(detonate) {

		decl String:targetname[64];

		GetEntPropString(caller, Prop_Data, "m_iName", targetname, sizeof(targetname));

		decl String:buffers[2][32];

		ExplodeString(targetname, "_", buffers, 2, 32);

		new ent_mine = StringToInt(buffers[1]);

		AcceptEntityInput(ent_mine, "break");

	}

	return;
}

public SetupMine(client, Float:position[3], Float:normal[3]) {

	decl String:mine_name[64];
	decl String:beam_name[64];
	decl String:str[128];

	Format(mine_name, 64, "apollyontripmine%d", mine_counter);

	new Float:angles[3];

	GetVectorAngles(normal, angles);

	new ent = CreateEntityByName("prop_physics_override");

	Format(beam_name, 64, "apollyontripmine%d_%d", mine_counter, ent);

	DispatchKeyValue(ent, "model", MODEL_MINE);
	DispatchKeyValue(ent, "physdamagescale", "0.0");
	DispatchKeyValue(ent, "health", "1");
	DispatchKeyValue(ent, "targetname", mine_name);
	DispatchKeyValue(ent, "spawnflags", "256");
	DispatchSpawn(ent);

	SetEntityMoveType(ent, MOVETYPE_NONE);
	SetEntProp(ent, Prop_Data, "m_takedamage", 2);
	SetEntPropEnt(ent, Prop_Data, "m_hLastAttacker", client);
	SetEntityRenderColor(ent, 255, 255, 255, 255);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 2);

	Format(str, sizeof(str), "%s,Kill,,0,-1", beam_name);

	DispatchKeyValue(ent, "OnBreak", str);

	HookSingleEntityOutput(ent, "OnBreak", MineBreak, true);
	HookSingleEntityOutput(ent, "OnPlayerUse", MineUsed, false);

	for(new i =0 ; i < 3; i++) {

		position[i] += normal[i] * 0.5;

	}

	TeleportEntity(ent, position, angles, NULL_VECTOR);//angles, NULL_VECTOR);

	TR_TraceRayFilter(position, angles, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All, 0);

	new Float:beamend[3];

	TR_GetEndPosition(beamend, INVALID_HANDLE);

	new ent_laser = CreateLaser(beamend, position, beam_name, GetClientTeam(client));

	if(minefilter == 1 || minefilter == 2) {

		HookSingleEntityOutput(ent_laser, "OnTouchedByEntity", MineLaser_OnTouch);

	} else {

		Format(str, sizeof(str), "%s,Break,,0,-1", mine_name);

		DispatchKeyValue(ent_laser, "OnTouchedByEntity", str);

	}

	SetEntPropEnt(ent_laser, Prop_Data, "m_hOwnerEntity",client); //Set the owner of the mine's beam
	
	new Handle:data;

	CreateDataTimer(1.0, ActivateTimer, data, TIMER_REPEAT);

	ResetPack(data);

	WritePackCell(data, 0);

	WritePackCell(data, ent);

	WritePackCell(data, ent_laser);

	PlayMineSound(ent, SOUND_PLACE);
	
	mine_counter++;
}

public Action:ActivateTimer(Handle:timer, Handle:data) {

	ResetPack(data);

	new counter = ReadPackCell(data);
	new ent = ReadPackCell(data);
	new ent_laser = ReadPackCell(data);

	if(!IsValidEntity(ent)) { // mine was broken (gunshot/grenade) before it was armed

		return Plugin_Stop;

	}

	if(counter < 3) {

		PlayMineSound(ent, SOUND_ARMING);

		counter++;

		ResetPack(data);
		WritePackCell(data, counter);

	} else {

		PlayMineSound(ent, SOUND_ARMED);

		DispatchKeyValue(ent_laser, "TouchType", "4");
		DispatchKeyValue(ent_laser, "renderamt", "220");

		return Plugin_Stop;
	}
	
	return Plugin_Handled;
}

PlayMineSound(entity, const String:sound[]) {

	EmitSoundToAll(sound, entity);
}


public MineBreak (const String:output[], caller, activator, Float:delay) {

	new Float:pos[3];

	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", pos);

	CreateExplosionDelayed(pos, GetEntPropEnt(caller, Prop_Data, "m_hLastAttacker"));

}

public MineUsed(const String:output[], caller, activator, Float:delay) { 

	last_mine_used = caller;
	 
}

public CreateLaser(Float:start[3], Float:end[3], String:name[], team) {

	new ent = CreateEntityByName("env_beam");

	if (ent != -1) {

		decl String:color[16];

		if(team == 2) {

			color = LASER_COLOR_REB;

		} else {

			if(team == 3) {

				color = LASER_COLOR_CMB;
			}
		}

		TeleportEntity(ent, start, NULL_VECTOR, NULL_VECTOR);

		SetEntityModel(ent, MODEL_BEAM); // This is where you would put the texture, ie "sprites/laser.vmt" or whatever.
		SetEntPropVector(ent, Prop_Data, "m_vecEndPos", end);

		DispatchKeyValue(ent, "targetname", name);
		DispatchKeyValue(ent, "rendercolor", color);
		DispatchKeyValue(ent, "renderamt", "80");
		DispatchKeyValue(ent, "decalname", "Bigshot"); 
		DispatchKeyValue(ent, "life", "0"); 
		DispatchKeyValue(ent, "TouchType", "0");
		DispatchSpawn(ent);

		SetEntPropFloat(ent, Prop_Data, "m_fWidth", LASER_WIDTH); 
		SetEntPropFloat(ent, Prop_Data, "m_fEndWidth", LASER_WIDTH);
 
		ActivateEntity(ent);

		AcceptEntityInput(ent, "TurnOn");

	}

	return ent;

}

public CreateExplosionDelayed(Float:vec[3], owner) {

	new Handle:data;

	CreateDataTimer(0.1, CreateExplosionDelayedTimer, data);
	
	WritePackCell(data,owner);
	WritePackFloat(data,vec[0]);
	WritePackFloat(data,vec[1]);
	WritePackFloat(data,vec[2]);

}

public Action:CreateExplosionDelayedTimer(Handle:timer, Handle:data) {

	ResetPack(data);

	new owner = ReadPackCell(data);
	new Float:vec[3];

	vec[0] = ReadPackFloat(data);
	vec[1] = ReadPackFloat(data);
	vec[2] = ReadPackFloat(data);

	CreateExplosion(vec, owner);
	
	return Plugin_Handled;

}

public Action:EnableExplosionSound(Handle:timer) {

	explosion_sound_enable = true;
	return Plugin_Handled;

}

public CreateExplosion(Float:vec[3], owner) {

	new ent = CreateEntityByName("env_explosion");

	DispatchKeyValue(ent, "classname", "env_explosion");

	SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", owner);

	new mag = GetConVarInt(sm_pp_minedmg);
	new rad = GetConVarInt(sm_pp_minerad);

	SetEntProp(ent, Prop_Data, "m_iMagnitude",mag); 

	if(rad != 0) {

		SetEntProp(ent, Prop_Data, "m_iRadiusOverride",rad);

	}

	DispatchSpawn(ent);

	ActivateEntity(ent);

	decl String:exp_sample[64];

	Format(exp_sample, 64, ")ambient/explosions/exp%d.wav", GetRandomInt(3, 5));

	if(explosion_sound_enable) {

		explosion_sound_enable = false;

		EmitAmbientSound(exp_sample, vec, _, SNDLEVEL_GUNFIRE );

		CreateTimer(0.1, EnableExplosionSound);

	} 

	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);

	AcceptEntityInput(ent, "explode");

	AcceptEntityInput(ent, "kill");

}
