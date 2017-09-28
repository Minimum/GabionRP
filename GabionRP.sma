/*
* Gabion Role-Play Plugin
* 
* A revolutionary new role-play plugin.  Designed by hard core role-players, for role-players.  Innovative, abundant in features, and sleak all at the same time.
* Never settle for second.
* ---
* By: Minimum
* http://gslans.net
* ---
* Section Index:
* 	- Commands Section 	(SECTCMD)
* 	- Events Section 	(SECTEVT)
* 	- Menu Section 		(SECTMENU)
* 	- Item Section		(SECTITEM)
* 
* Now comes the fun part...
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <sqlx>
#include <engine>
#include <fun>
#include <tsx>
#include <tsfun>
#include <svn_version>

#define VERSION	"1.0"
#define BUILD "0001"

new dumbInt = 0;
new dumbStr[4];
new mapName[32];

new Handle:sqlConn;
new Handle:sqlResult;
new sqlCvar[4];

new Float:serverHud = 0.0;
new serverName[32];
new serverRestart = 0;
new serverItemId = 0;

new playerId[33] = 0;
new playerMoney[33] = 0;
new playerDave[33] = 0;
new Float:playerUse[33] = 0.0;
new playerUseToggle[33] = 0;
new playerPay[33] = 60;
//new playerCuffed[33] = 0;
new playerCuff[33] = 0;
new playerSit[33] = 0;
new playerThermal[33] = false;
new playerCloak[33] = false;
new Float:playerTouch[33] = 0.0;
new playerTouchItem[33] = 0;
//new playerPhoneNumber[33][7];

new playerVoodoo[33] = 0;
new Float:playerVoodooLoc[33][3];

new playerShopId[33];
new playerShopName[33][32];
new playerShopMenu[33];
new playerShopLoc[33][3];
new Float:playerShopProfit[33];
new playerShopOwner[33];
new playerCartId[33];
new playerCartAmount[33];
new playerCartName[33][32];
new Float:playerCartPrice[33];

public plugin_init() {
	register_plugin("GabionRP", VERSION, "Minimum");
	
	register_concmd("say","cmdSay");								// Say Hook
	register_concmd("say_team","cmdTeamSay");						// Team Say Hook
	register_concmd("grprest","cmdRestart");						// Reset Map
	register_concmd("adddoor","cmdAddDoor");						// Add Door To SQL
	register_concmd("addweapon","cmdAddWeapon");					// Add Weaponspawn
	register_concmd("grpversion","cmdVersion");						// Current Version
	register_concmd("amx_joblist","cmdJobList");					// Job Listing
	register_concmd("joblist","cmdJobList");						// Job Listing
	register_concmd("phonetest","cmdPhoneTest");					// Phone Test
	register_concmd("spawnitem","cmdSpawnItem");					// Spawn Item
	/*
	* Regs left:
	* Invite To Org
	* Set Job
	* Add Property
	* Set Wallet
	* Set Bank
	* Add Item
	* Remove Item
	* Player Info
	* Server Info
	* Set SQL Var
	* Phone Numbers
	* 
	* Chat left:
	* Web Id/Pw
	* 
	*/
	
	sqlCvar[0] = register_cvar("grp_sqladdress","localhost",FCVAR_PROTECTED);
	sqlCvar[1] = register_cvar("grp_sqluser","root",FCVAR_PROTECTED);
	sqlCvar[2] = register_cvar("grp_sqlpass","pass",FCVAR_PROTECTED);
	sqlCvar[3] = register_cvar("grp_sqlschema","schmonet",FCVAR_PROTECTED);
	register_cvar("grp_servercode","",FCVAR_PROTECTED);
	
	// Forwards
	register_forward(FM_PlayerPreThink,"evtPreThink");				// Player PreTick
	register_forward(FM_ClientPutInServer,"evtJoin");				// Player Connect
	register_forward(FM_ClientDisconnect,"evtLeave");				// Player Disconnect
	//register_forward(FM_ClientKill,"evtKill");
	register_forward(FM_GetGameDescription,"evtGameName");			// Change Gamename
	register_forward(FM_AddToFullPack,"evtPreThinkSpec",1);			// Player PreTick Manipulation
	register_forward(FM_Touch,"evtTouch");							// Player Entity Touch
	
	// Events
	register_event("DeathMsg","evtKill","a");						// Player Death
	
	// Items
	register_srvcmd("itemMoney","itemMoney");						// itemMoney <id> <itemid> <amount>
	register_srvcmd("itemFood","itemFood");							//
	register_srvcmd("itemHealth","itemHealth");						//
	register_srvcmd("itemAlcohol","itemAlcohol");					//
	register_srvcmd("itemPoison","itemPoison");						//
	//register_srvcmd("itemTazer","itemTazer");						//
	
	get_mapname(mapName,31);
	
	server_print("This server is running GabionRP %s (Build %s)^nCompiled on AMXX %s",VERSION,BUILD,AMXX_VERSION_STR);
	
	server_cmd("exec addons/amxmodx/configs/gabionrp.cfg");
	
	set_task(1.0,"sqlInit");
}

public plugin_precache() {
	precache_sound("misc/beep2.wav");
	precache_sound("items/ammopickup1.wav");
	precache_model("models/briefcase.mdl");
	precache_model("models/roleplay/money.mdl");
}

public plugin_end() {
	SQL_FreeHandle(sqlConn);
}

public sqlInit() {
	new info[4][32];
	
	get_pcvar_string(sqlCvar[0],info[0],31);
	get_pcvar_string(sqlCvar[1],info[1],31);
	get_pcvar_string(sqlCvar[2],info[2],31);
	get_pcvar_string(sqlCvar[3],info[3],31);
	get_cvar_string("grp_servercode",serverName,31);
	
	if(strlen(serverName) < 1) {
		new encrypted[34], in[64], hostName[64];
		get_cvar_string("hostname",hostName,63);
		
		formatex(in,63,"%s%s",hostName,mapName);
		md5(in,encrypted);
		formatex(serverName,31,encrypted);
	}
	
	new Handle:sqlInfo = SQL_MakeDbTuple(info[0],info[1],info[2],info[3],0);
	
	sqlConn = SQL_Connect(sqlInfo,dumbInt,dumbStr,3);
	SQL_FreeHandle(sqlInfo);
	
	if(sqlConn == Empty_Handle) {
		server_print("SQL Connection Failure.  Reattempting in 2 seconds...");
		set_task(2.0,"sqlInit");
		return PLUGIN_HANDLED;
	}
	
	server_print("SQL Connection Successful.");
	
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set server = '' where server = '%s'",serverName);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select grp_curitems.id,grp_curitems.itemid,grp_curitems.amount,grp_curitems.x,grp_curitems.y,grp_curitems.z,grp_curitems.sessionid,grp_items.model from grp_curitems,grp_items where mapname = '%s' and ownerid = 0 and grp_items.id = grp_curitems.itemid order by sessionid asc",mapName);
	SQL_Execute(sqlResult);
	new numSpawned,itemId,itemDbId,itemAmount,itemLoc[3],flags[64];
	
	while(SQL_MoreResults(sqlResult)) {
		numSpawned++;
		
		itemId = SQL_ReadResult(sqlResult,0);
		itemDbId = SQL_ReadResult(sqlResult,1);
		itemAmount = SQL_ReadResult(sqlResult,2);
		itemLoc[0] = SQL_ReadResult(sqlResult,3);
		itemLoc[1] = SQL_ReadResult(sqlResult,4);
		itemLoc[2] = SQL_ReadResult(sqlResult,5);
		serverItemId = SQL_ReadResult(sqlResult,6);
			
		SQL_ReadResult(sqlResult,7,flags,63);
		
		evtSpawnItem(itemId,itemDbId,itemAmount,itemLoc,flags);
		
		SQL_NextRow(sqlResult);
	}
	
	server_print("%i items spawned from database.",numSpawned);
	SQL_FreeHandle(sqlResult);
	
	new ent = 0, Float:weapLoc[3], weapStr[4][8];
	
	while ((ent = find_ent_by_class(ent,"ts_groundweapon")))
		remove_entity(ent);
	
	numSpawned = 0;
	sqlResult = SQL_PrepareQuery(sqlConn,"select weapid,duration,ammo,flags,x,y,z from grp_weapons where mapname = '%s'",mapName);
	SQL_Execute(sqlResult);
	
	while(SQL_MoreResults(sqlResult)) {
		SQL_ReadResult(sqlResult,0,weapStr[0],7);
		SQL_ReadResult(sqlResult,1,weapStr[1],7);
		SQL_ReadResult(sqlResult,2,weapStr[2],7);
		SQL_ReadResult(sqlResult,3,weapStr[3],7);
		itemLoc[0] = SQL_ReadResult(sqlResult,4);
		itemLoc[1] = SQL_ReadResult(sqlResult,5);
		itemLoc[2] = SQL_ReadResult(sqlResult,6);
		
		weapLoc[0] = float(itemLoc[0]);
		weapLoc[1] = float(itemLoc[1]);
		weapLoc[2] = float(itemLoc[2]);
		
		ts_weaponspawn(weapStr[0],weapStr[1],weapStr[2],weapStr[3],weapLoc);
		
		SQL_NextRow(sqlResult);
	}
	
	server_print("%i weapons spawned from database.",numSpawned);
	SQL_FreeHandle(sqlResult);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select entid,propid,health from grp_doors where mapname = '%s'",mapName);
	SQL_Execute(sqlResult);
	numSpawned = 0;
	new health = 0;
	
	while(SQL_MoreResults(sqlResult)) {
		ent = SQL_ReadResult(sqlResult,0);
		health = SQL_ReadResult(sqlResult,2);
		if(SQL_ReadResult(sqlResult,1) == 0) 
			engfunc(EngFunc_RemoveEntity, ent);
		
		else {
			numSpawned++;
			if(health == 0)
				set_pev(ent,pev_takedamage,0.0);
			
			else {
				set_pev(ent,pev_max_health,float(health));
				set_pev(ent,pev_health,float(health));
			}
		}
		
		SQL_NextRow(sqlResult);
	}
	
	server_print("%i doors godded from database.",numSpawned);
	SQL_FreeHandle(sqlResult);
	
	return PLUGIN_HANDLED;
}

/*
* Clean String
* Cleans database queries to help prevent SQL Injection.
* Do not use this on completed queries.
* It is preferred that you use this on client input.
* ---
* QueryStr: The Query String to clean.
* 
*/
public cleanString(queryStr[],len) {
	replace_all(queryStr,len,"\^"","^"");
	replace_all(queryStr,len,"\^'","^'");
	replace_all(queryStr,len,"^"","\^"");
	replace_all(queryStr,len,"^'","\'");
	return;
}

/*
* Commands Section (SECTCMD)
*/

public cmdRestart(id) {
	if(!cmd_access(id,ADMIN_MAP,id,1))
		return PLUGIN_HANDLED;
	
	client_print(0,print_chat,"Server restarting in %i second(s).",5-serverRestart);
	serverRestart++;
	
	if(serverRestart > 5)
		server_cmd("changelevel %s",mapName);
	
	set_task(1.0,"cmdRestart",0);
	
	return PLUGIN_HANDLED;
}

public cmdPhoneTest(id) {
	new args[16];
	read_argv(1,args,15);
	
	server_print(evtPhoneNumber(args));
	
	return PLUGIN_HANDLED;
}

public cmdAddDoor(id) {
	if(!(get_user_flags(id) & ADMIN_IMMUNITY)) 
		return PLUGIN_HANDLED;
	
	new args[4][32], args2[4][32], entId, className[32];
	//<name> <propid> <lockstr> <health> <price> <locked> <alarm>
	read_argv(1,args[0],31);
	read_argv(2,args[1],31);
	read_argv(3,args[2],31);
	read_argv(4,args[3],31);
	read_argv(5,args2[0],31);
	read_argv(6,args2[1],31);
	read_argv(7,args2[2],31);
	
	if(strlen(args[0]) < 1) {
		client_print(id,print_console,"Usage: adddoor <name> <propid> <lockstr> <health> <locked> <alarm>");
		return PLUGIN_HANDLED;
	}
	
	get_user_aiming(id,entId,dumbInt,500);
	
	pev(entId,pev_classname,className,31);
	
	if(!equali(className,"func_door") && !equali(className,"func_door_rotating")) {
		client_print(id,print_chat,"That is not a valid door.");
		return PLUGIN_HANDLED;
	}
	
	// Cleaning SQL Strings - No SQL Injections here :D
	cleanString(args[0],31);
	cleanString(args[1],31);
	cleanString(args[2],31);
	cleanString(args[3],31);
	
	cleanString(args2[0],31);
	cleanString(args2[1],31);
	cleanString(args2[2],31);

	sqlResult = SQL_PrepareQuery(sqlConn,"select id from grp_doors where entid=%i and mapname = '%s'",entId,mapName);
	SQL_Execute(sqlResult);
	
	if(SQL_NumResults(sqlResult) > 0) {
		SQL_FreeHandle(sqlResult);
		client_print(id,print_chat,"This door already exists in the database!");
		return PLUGIN_HANDLED;
	}
	
	SQL_FreeHandle(sqlResult);
	
	new values[5];
	values[0] = str_to_num(args[1]); // propid 0
	values[1] = str_to_num(args[2]); // lockstr 1
	values[2] = str_to_num(args[3]); // health 2
	values[3] = str_to_num(args2[1]); // locked 3
	values[4] = str_to_num(args2[2]); // alarm 4
	
	set_pev(entId,pev_takedamage,0.0);
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"insert into grp_doors (name,propid,lockstr,health,locked,alarm,mapname,entid) values ('%s',%i,%i,%i,%i,%i,'%s',%i)",args[0],values[0],values[1],values[2],values[3],values[4],mapName,entId);
	client_print(id,print_chat,"Successfully added Property - %s.",args[0]);
	return PLUGIN_HANDLED;
}

public cmdAddWeapon(id) {
	if(!(get_user_flags(id) & ADMIN_IMMUNITY)) 
		return PLUGIN_HANDLED;
	
	new args[5][32];
	//<weaponid> <duration> <ammo> <flags> <comment>
	read_argv(1,args[0],31);
	read_argv(2,args[1],31);
	read_argv(3,args[2],31);
	read_argv(4,args[3],31);
	read_argv(5,args[4],31);
	
	if(strlen(args[0]) < 1) {
		client_print(id,print_console,"Usage: addweapon <weaponid> <duration> <ammo> <flags> <comment>");
		return PLUGIN_HANDLED;
	}
	
	// Cleaning SQL Strings - No SQL Injections here :D
	cleanString(args[0],31);
	cleanString(args[1],31);
	cleanString(args[2],31);
	cleanString(args[3],31);
	cleanString(args[4],31);
	
	new values[4], origin[3], Float:fOrigin[3];
	
	get_user_origin(id,origin);
	
	fOrigin[0] = float(origin[0]);
	fOrigin[1] = float(origin[1]);
	fOrigin[2] = float(origin[2]);
	
	values[0] = str_to_num(args[0]); // weaponid 0
	values[1] = str_to_num(args[1]); // duration 1
	values[2] = str_to_num(args[2]); // ammo 2
	values[3] = str_to_num(args[3]); // flag 3
	
	ts_weaponspawn(args[0],args[1],args[2],args[3],fOrigin);
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"insert into grp_weapons (weapid,duration,ammo,flags,comment,x,y,z,mapname) values (%i,%i,%i,%i,'%s',%i,%i,%i,'%s')",values[0],values[1],values[2],values[3],args[4],origin[0],origin[1],origin[2],mapName);
	client_print(id,print_chat,"Successfully added Weapon Spawn - %s.",args[4]);
	return PLUGIN_HANDLED;
}

public cmdInvite(id) {
	new args[2][32];
	// <player> <jobid>
	read_argv(1,args[0],31);
	read_argv(2,args[1],31);
}

public cmdJobList(id) {
	sqlResult = SQL_PrepareQuery(sqlConn,"select id,name,salary from grp_jobs where org = (select j.org from grp_jobs j, grp_players p where p.job = j.id and p.id = %i)",playerId[id]);
	SQL_Execute(sqlResult);
	
	if(SQL_NumResults(sqlResult) < 1) {
		SQL_FreeHandle(sqlResult);
		client_print(id,print_console,"Your current org has no jobs!");
		
		return PLUGIN_HANDLED;
	}
	
	new jobId, jobName[32], Float:jobSalary, jobStr[256], jobNum;
	
	client_print(id,print_console,"Id^tSalary^tName");
	
	while(SQL_MoreResults(sqlResult)) {
		jobId = SQL_ReadResult(sqlResult,0);
		SQL_ReadResult(sqlResult,1,jobName,31);
		SQL_ReadResult(sqlResult,2,jobSalary);
		
		if(jobNum == 4) {
			format(jobStr,255,"%s%i^t%.2f^t%s",jobStr,jobId,jobSalary,jobName);
			client_print(id,print_console,jobStr);
			jobNum = 0;
			formatex(jobStr,255,"");
		}
		
		else {
			format(jobStr,255,"%s%i^t%.2f^t%s^n",jobStr,jobId,jobSalary,jobName);
			jobNum++;
		}
		
		SQL_NextRow(sqlResult);
	}
	
	if(jobNum != 0)
		client_print(id,print_console,jobStr);
	
	SQL_FreeHandle(sqlResult);
	return PLUGIN_HANDLED;
}

public cmdSay(id) {
	new arg[256], args[4][64], origin[3];
	read_args(arg,255);
	remove_quotes(arg);
	parse(arg, args[0], 63, args[1], 63, args[2], 63, args[3], 63);
	get_user_origin(id,origin);
	
	if(playerShopMenu[id] == 10 && get_distance(playerShopLoc[id],origin) <= 100 || playerShopMenu[id] == 20 && get_distance(playerShopLoc[id],origin) <= 100) {
		if(!is_user_alive(id))
			return PLUGIN_HANDLED;
		
		playerCartPrice[id] = str_to_float(args[0]);
		
		if(playerMoney[id] == 1)
			playerCartPrice[id] = playerCartPrice[id] / 100;
		
		menuShop(id);
		return PLUGIN_HANDLED;
	}
	else if(playerShopMenu[id] == 2 && get_distance(playerShopLoc[id],origin) <= 100) {
		if(!is_user_alive(id))
			return PLUGIN_HANDLED;
		
		playerCartAmount[id] = (str_to_num(args[0]) > 0) ? str_to_num(args[0]) : 1;
		menuShop(id);
		return PLUGIN_HANDLED;
	}
	else if(equali(args[0],"/moneystyle")) {
		if(playerMoney[id] == 0) {
			client_print(id,print_chat,"Changed money style to Cashier Style.");
			playerMoney[id] = 1;
		}
		
		else {
			client_print(id,print_chat,"Changed money style to Normal Style.");
			playerMoney[id] = 0;
		}
		
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set money = %i where id = %i",playerMoney[id],playerId[id]);
		
		return PLUGIN_HANDLED;
	}
	else if(equali(args[0],"/davehud")) {
		if(playerDave[id] == 0) {
			client_print(id,print_chat,"Changed hud style to Dave Hud.");
			playerDave[id] = 1;
		}
		
		else {
			client_print(id,print_chat,"Changed hud style to Normal Hud.");
			playerDave[id] = 0;
		}
		
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set hud = %i where id = %i",playerDave[id],playerId[id]);
		
		return PLUGIN_HANDLED;
	}
	else if(equali(args[0],"/dropmoney")) {
		if(!is_user_alive(id))
			return PLUGIN_HANDLED;
		
		new Float:dropMoney = str_to_float(args[1]);
		
		if(playerMoney[id] == 1)
			dropMoney = dropMoney / 100;
		
		evtDropMoney(id,dropMoney);
		
		return PLUGIN_HANDLED;
	}
	else if(equali(args[0],"/givemoney")) {
		if(!is_user_alive(id))
			return PLUGIN_HANDLED;
		
		new entId;
		
		get_user_aiming(id,entId,dumbInt,200);
		
		new Float:giveMoney = str_to_float(args[1]);
		
		if(playerMoney[id] == 1)
			giveMoney = giveMoney / 100;
		
		if(is_user_alive(entId))
			evtGiveMoney(id,entId,giveMoney);
		
		return PLUGIN_HANDLED;
	}
	else if(equali(args[0],"/giveaccess")) {
		if(!is_user_alive(id))
			return PLUGIN_HANDLED;
		
		new entId, tarId;
		
		get_user_aiming(id,entId,dumbInt,200);
		
		tarId = cmd_target(id,args[1],8);
		
		if(is_user_connected(tarId))
			evtGiveAccess(id,entId,tarId);
		
		else
			client_print(id,print_chat,"Usage (Looking at door): /giveaccess <name>");
		
		return PLUGIN_HANDLED;
	}
	else if(equali(args[0],"/items")) {
		if(!is_user_alive(id))
			return PLUGIN_HANDLED;
		
		playerShopMenu[id] = 30;
		menuShop(id);
		return PLUGIN_HANDLED;
	}
	else if(equali(args[0],"/sit")) {
		if(!is_user_alive(id))
			return PLUGIN_HANDLED;
		
		if(playerSit[id]) {
			client_cmd(id,"-duck");
			playerSit[id] = false;
		}
		else {
			client_cmd(id,"+duck");
			playerSit[id] = true;
		}
	}
	else if(equali(args[0],"/origin")) {
		new origin[3];
		get_user_origin(id,origin);
		playerVoodooLoc[id][0] = float(origin[0]);
		playerVoodooLoc[id][1] = float(origin[1]);
		playerVoodooLoc[id][2] = float(origin[2]);
		client_print(id,print_chat,"Origin: %i,%i,%i",origin[0],origin[1],origin[2]);
	}
	else if(equali(args[0],"/ent")) {
		new entId;
		get_user_aiming(id,entId,dumbInt,800);
		client_print(id,print_chat,"Ent Id: %i",entId);
	}
	else if(equali(args[0],"/buy")) {
		if(!is_user_alive(id))
			return PLUGIN_HANDLED;
		
		evtBuy(id,1);
	}
	else if(equali(args[0],"ooc")) {
		replace(arg,255,"ooc","");
		trim(arg);
		
		if(strlen(arg) < 1) 
			return PLUGIN_HANDLED;
		
		new userName[32];
		get_user_name(id,userName,31);
		server_print("(OOC) %s : %s",userName,arg);
		for(new x=1;x < 33; x++) {
			if(is_user_connected(x))
				client_print(x,print_chat,"(OOC) %s: %s",userName,arg);
		}
	}
	else if(equali(args[0],"cnn")) {
		replace(arg,255,"cnn","");
		trim(arg);
		
		if(strlen(arg) < 1) 
			return PLUGIN_HANDLED;
		
		new userName[32];
		get_user_name(id,userName,31);
		server_print("(NEWS) %s : %s",userName,arg);
		for(new x=1;x < 33; x++) {
			if(is_user_connected(x)) {
				if((get_user_flags(x) & ADMIN_IMMUNITY))
					client_print(x,print_chat,"(NEWS) %s: %s",userName,arg);
				else
					client_print(x,print_chat,"(NEWS) %s",arg);
				
				client_cmd(x,"speak ^"fvox/alert^"");
			}
		}
	}
	else if(equali(args[0],"advert")) {
		replace(arg,255,"advert","");
		trim(arg);
		
		if(strlen(arg) < 1) 
			return PLUGIN_HANDLED;
		
		new userName[32];
		get_user_name(id,userName,31);
		server_print("(ADVERT) %s : %s",userName,arg);
		for(new x=1;x < 33; x++) {
			if(is_user_connected(x)) {
				if((get_user_flags(x) & ADMIN_IMMUNITY))
					client_print(x,print_chat,"(ADVERT) %s: %s",userName,arg);
				else
					client_print(x,print_chat,"(ADVERT) %s",arg);
			}
		}
	}
	else if(equali(args[0],"shout")) {
		replace(arg,255,"shout","");
		trim(arg);
		
		if(strlen(arg) < 1 || !is_user_alive(id))
			return PLUGIN_HANDLED;
		
		strtoupper(arg);
		
		new origin[3], userName[32];
		get_user_name(id,userName,31);
		get_user_origin(id,origin);
		server_print("%s shouts: %s",userName,arg);
		for(new x=1;x < 33; x++) {
			if(is_user_alive(x)) {
				new tarOrigin[3];
				get_user_origin(x,tarOrigin);
				if(get_distance(origin,tarOrigin) <= 1100)
					client_print(x,print_chat,"%s shouts: %s",userName,arg);
			}
		}
	}
	else if(equali(args[0],"whisper")) {
		replace(arg,255,"whisper","");
		trim(arg);
		
		if(strlen(arg) < 1 || !is_user_alive(id))
			return PLUGIN_HANDLED;
		
		new origin[3], userName[32];
		get_user_name(id,userName,31);
		get_user_origin(id,origin);
		server_print("%s whispers: %s",userName,arg);
		for(new x=1;x < 33; x++) {
			if(is_user_alive(x)) {
				new tarOrigin[3];
				get_user_origin(x,tarOrigin);
				if(get_distance(origin,tarOrigin) <= 150)
					client_print(x,print_chat,"%s whispers: %s",userName,arg);
			}
		}
	}
	else if(equali(args[0],"/me")) {
		replace(arg,255,"/me","");
		trim(arg);
		
		if(strlen(arg) < 1 || !is_user_alive(id))
			return PLUGIN_HANDLED;
		
		new origin[3], userName[32];
		get_user_name(id,userName,31);
		get_user_origin(id,origin);
		server_print("**%s %s",userName,arg);
		for(new x=1;x < 33; x++) {
			if(is_user_alive(x)) {
				new tarOrigin[3];
				get_user_origin(x,tarOrigin);
				if(get_distance(origin,tarOrigin) <= 400)
					client_print(x,print_chat,"**%s %s",userName,arg);
			}
		}
	}
	else if(equali(args[0],"/any")) {
		replace(arg,255,"/any","");
		trim(arg);
		
		if(strlen(arg) < 1)
			return PLUGIN_HANDLED;
		
		new userName[32];
		get_user_name(id,userName,31);
		server_print("(ANY) %s: %s",userName,arg);
		for(new x=1;x < 33; x++) {
			if(is_user_connected(x))
				client_print(x,print_chat,"%s",arg);
		}
	}
	else if(equali(args[0],"/pdata")) {
		// TEST STUFF
		new pData[32];
		sqlResult = SQL_PrepareQuery(sqlConn,"select operId from pdata order by id desc limit 1");
		SQL_Execute(sqlResult);
		new instance = 0;
		
		if(SQL_NumResults(sqlResult) > 0)
			instance = SQL_ReadResult(sqlResult,0)+1;
		
		SQL_FreeHandle(sqlResult);
		for(new x=0;x < 512;x++) {
			//log_amx("SETTING %i",x);
			//if(get_pdata_int(id,x) > 0)
			//	set_pdata_int(id,x,8);
			get_pdata_string(id,x,pData,31,1,0);
			cleanString(pData,32);
			SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"insert into pdata (operId,offset2,str,int5,float2) values (%i,%i,^"%s^",%i,%f)",instance,x,pData,get_pdata_int(id,x),get_pdata_float(id,x));
			
		}
		
	}
	else {
		if(containi(arg,"/") == 0) {
			replace(arg,255,"/","");
			trim(arg);
		
			if(strlen(arg) < 1 || !is_user_alive(id))
				return PLUGIN_HANDLED;
		
			new origin[3], userName[32];
			get_user_name(id,userName,31);
			get_user_origin(id,origin);
			server_print("**%s %s",userName,arg);
			for(new x=1;x < 33; x++) {
				if(is_user_alive(x)) {
					new tarOrigin[3];
					get_user_origin(x,tarOrigin);
					if(get_distance(origin,tarOrigin) <= 400)
						client_print(x,print_chat,"**%s %s",userName,arg);
				}
			}
			return PLUGIN_HANDLED;
		}
		
		if(strlen(arg) < 1 || !is_user_alive(id))
			return PLUGIN_HANDLED;
		
		new origin[3], userName[32];
		get_user_name(id,userName,31);
		get_user_origin(id,origin);
		server_print("%s says: %s",userName,arg);
		for(new x=1;x < 33; x++) {
			if(is_user_alive(x)) {
				new tarOrigin[3];
				get_user_origin(x,tarOrigin);
				if(get_distance(origin,tarOrigin) <= 400)
					client_print(x,print_chat,"%s says: %s",userName,arg);
			}
		}
	}
	return PLUGIN_HANDLED;
}

public cmdTeamSay(id) {
	new arg[256];
	read_argv(1,arg,255);
	if(strlen(arg) < 1) 
		return PLUGIN_HANDLED;
	
	new userName[32];
	get_user_name(id,userName,31);
	server_print("(OOC) %s : %s",userName,arg);
	for(new x=1;x < 33; x++) {
		if(is_user_connected(x))
			client_print(x,print_chat,"(OOC) %s: %s",userName,arg);
	}
	return PLUGIN_HANDLED;
}

public cmdVersion(id) {
	if(id == 0)
		server_print("This server is running GabionRP %s (Build %s)^nCompiled on AMXX %s",VERSION,BUILD,AMXX_VERSION_STR);
	
	else
		client_print(id,print_console,"This server is running GabionRP %s (Build %s)^nCompiled on AMXX %s",VERSION,BUILD,AMXX_VERSION_STR);
		
	return PLUGIN_HANDLED;
}

public cmdSpawnItem(id) {
	new origin[3], args[16], itemId, amount;
	get_user_origin(id,origin,3);
	read_argv(1,args,15);
	itemId = str_to_num(args);
	read_argv(2,args,15);
	amount = str_to_num(args);
	
	evtCreateItem(itemId,amount,origin,"");
	
	return PLUGIN_HANDLED;
}

/*
* Events Section (SECTEVT)
*/

public evtHudDraw() {
	new authId[32], query[512];
	formatex(query,511,"select grp_players.sessionid,grp_players.authid,grp_players.bank,grp_players.wallet,grp_jobs.name,grp_jobs.salary,grp_orgs.name,grp_players.raceid from grp_players,grp_jobs,grp_orgs where grp_players.sessionid > 0 and grp_jobs.id=grp_players.job and grp_orgs.id=grp_jobs.org and grp_players.server = '%s'",serverName);
	
	sqlResult = SQL_PrepareQuery(sqlConn,query);
	SQL_Execute(sqlResult);
	
	new id, Float:bank, Float:wallet, jobName[32], Float:salary, payClock[2], payStr[8], orgName[32], raceName[16], raceid;
	
	new entId[33], totalEnts = 0, className[32];
	
	while(SQL_MoreResults(sqlResult)) {
		id = SQL_ReadResult(sqlResult,0);
		SQL_ReadResult(sqlResult,1,authId,31);
		SQL_ReadResult(sqlResult,2,bank);
		SQL_ReadResult(sqlResult,3,wallet);
		SQL_ReadResult(sqlResult,4,jobName,31);
		SQL_ReadResult(sqlResult,5,salary);
		SQL_ReadResult(sqlResult,6,orgName,31);
		raceid = SQL_ReadResult(sqlResult,7);
		
		if(raceid == 2)
			formatex(raceName,15,"Human");
		
		else if(raceid == 3)
			formatex(raceName,15,"Vampire");
		
		else if(raceid == 4)
			formatex(raceName,15,"Vampire Lord");
		
		else if(raceid == 5)
			formatex(raceName,15,"Jiang Shi");
		
		else if(raceid == 6)
			formatex(raceName,15,"Vampire Elder");
		
		else if(raceid == 7)
			formatex(raceName,15,"The Omega");
		
		payClock[0] = floatround(float(playerPay[id] / 60),floatround_floor);
		payClock[1] = playerPay[id] - (payClock[0]*60);
		
		if(payClock[1] < 10)
			formatex(payStr,7,"0%i:0%i",payClock[0],payClock[1]);
		else
			formatex(payStr,7,"0%i:%i",payClock[0],payClock[1]);
		
		if(is_user_alive(id))
			playerPay[id]--;
		
		if(playerPay[id] < 1) {
			SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank+%.2f where id = %i",salary,playerId[id]);
			playerPay[id] = 90;
		}
		
		if(playerDave[id] == 1) {
			set_hudmessage(150, 175, 255, -1.0, 1.0,0,0.0,8.0,0.0,0.0,2);
			show_hudmessage(id,"Bank: $%.2f You: $%.2f Next Pay: %s",bank,wallet,payStr);
		}	
		
		else {
			set_hudmessage(150, 175, 255, 0.0, 0.0,0,0.0,8.0,0.0,0.0,2);
			if(raceid > 1)
				show_hudmessage(id,"^n GRP Experience^n ----------^n Balance: $%.2f^n Wallet: $%.2f^n Job: %s ($%.2f)^n Org: %s^n Race: %s^n Next Pay: %s",bank,wallet,jobName,salary,orgName,raceName,payStr);
			else
				show_hudmessage(id,"^n GRP Experience^n ----------^n Balance: $%.2f^n Wallet: $%.2f^n Job: %s ($%.2f)^n Org: %s^n Next Pay: %s",bank,wallet,jobName,salary,orgName,payStr);
		}
		
		get_user_aiming(id,entId[id],dumbInt,200);
		
		pev(entId[id],pev_classname,className,31);
		
		if(equali(className,"func_door") || equali(className,"func_door_rotating")) 
			totalEnts++;
		else
			entId[id] = 0;
		
		SQL_NextRow(sqlResult);
	}
	
	SQL_FreeHandle(sqlResult);
	
	if(totalEnts < 1)
		return PLUGIN_HANDLED;
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select grp_doors.entid,grp_doors.name,grp_prop.ownername,grp_prop.price,grp_prop.name,grp_prop.ownerid from grp_doors,grp_prop where grp_doors.propid = grp_prop.id and grp_doors.mapname = '%s'",mapName);
	SQL_Execute(sqlResult);
	
	while(SQL_MoreResults(sqlResult)) {
		id = SQL_ReadResult(sqlResult,0);
		
		for(new x=1;x < 33;x++) {
			if(id == entId[x]) {
				SQL_ReadResult(sqlResult,1,jobName,31); 		// Door (Name)
				SQL_ReadResult(sqlResult,2,className,31);		// Ownername
				SQL_ReadResult(sqlResult,3,salary); 			// Price
				SQL_ReadResult(sqlResult,5,payClock[0]);		// OwnerId
				
				if(strlen(jobName) < 1)
					SQL_ReadResult(sqlResult,4,jobName,31);		// Prop (Name)
				
				// Selling Without Owner
				if(salary > 0.0 && payClock[0] < 1) { 
					set_hudmessage(150, 175, 255,-1.0,0.55,0,0.0,2.0,0.0,0.0,3);
					show_hudmessage(x,"%s^nCITY CONTROL, BUY NOW: $%.2f^nSay /buy to purchase.",jobName,salary);
				}
				
				// Not Selling Without Owner
				if(salary < 1.0 && payClock[0] < 1) { 
					set_hudmessage(150, 175, 255,-1.0,0.55,0,0.0,2.0,0.0,0.0,3);
					show_hudmessage(x,"%s^nUNDER CITY CONTROL",jobName);
				}
				
				// Not Selling With Owner
				if(salary < 1.0 && payClock[0] > 1) { 
					set_hudmessage(150, 175, 255,-1.0,0.55,0,0.0,2.0,0.0,0.0,3);
					if(strlen(className) > 1)
						show_hudmessage(x,"%s^nOWNED BY %s",jobName,className);
					else
						show_hudmessage(x,"%s^nOWNER UNDISCLOSED",jobName);
				}
				
				// Selling With Owner
				if(salary > 0.0 && payClock[0] > 1) { 
					set_hudmessage(150, 175, 255,-1.0,0.55,0,0.0,2.0,0.0,0.0,3);
					if(strlen(className) > 1)
						show_hudmessage(x,"%s^n%s SELLING FOR $%.2f^nSay /buy to purchase.",jobName,className,salary);
					else
						show_hudmessage(x,"%s^nSELLING FOR $%.2f^nSay /buy to purchase.",jobName,salary);
				}
			}
		}
		
		SQL_NextRow(sqlResult);
	}
	
	SQL_FreeHandle(sqlResult);
	
	return PLUGIN_HANDLED;
}

public evtGameName() {
	new gameName[32];
	formatex(gameName,31,"GabionRP %s",VERSION);
	forward_return(FMV_STRING,gameName);
	return FMRES_SUPERCEDE;
}

public evtJoin(id) {
	new authId[32], userName[32];
	
	if(is_user_bot(id)) {
		playerId[id] = 0;
		return PLUGIN_HANDLED;
	}
	
	cmdVersion(id);
	
	get_user_authid(id,authId,31);
	get_user_name(id,userName,31);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select id from grp_players where authid = '%s';",authId);
	SQL_Execute(sqlResult);
	
	if(SQL_NumResults(sqlResult) < 1) {
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"insert into grp_players (authid,bank,job) values ('%s',2500.00,1)",authId);
		server_print("%s (%s) has been registered into the Gabion Role-Play Database.",userName,authId);
		
		set_task(0.1,"evtJoin",id);
		SQL_FreeHandle(sqlResult);
	}
	else {
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set sessionid = %i, server = '%s' where authid = '%s'",id,serverName,authId);
		server_print("%s (%s) has been logged into the Gabion Role-Play Database.",userName,authId);
		playerPay[id] = 60;
		playerId[id] = SQL_ReadResult(sqlResult,0);
		SQL_FreeHandle(sqlResult);
		return PLUGIN_CONTINUE;
	}
	return PLUGIN_CONTINUE;
}

public evtLeave(id) {
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set sessionid = 0, server = '' where id = '%i'",playerId[id]);
}

public evtKill() {
	//new killer = read_data(1);
	new victim = read_data(2);
	
	evtDropMoney(victim,0.0);
	return PLUGIN_CONTINUE;
}

public evtPreThink(id) {
	if((get_gametime() - serverHud) >= 2.0) {
		serverHud = get_gametime();
		evtHudDraw();
	}
	
	new entId;
	
	if(playerTouch[id]+2.0 <= get_gametime() && playerTouchItem[id] > 0) 
		playerTouchItem[id] = 0;
	
	if(is_user_alive(playerVoodoo[id])) {
		new originVoo[3];
		get_user_origin(playerVoodoo[id],originVoo);
		originVoo[2]+= 150;
		set_user_gravity(id,0.0);
		set_user_godmode(id,1);
		set_user_origin(id,originVoo);
		set_user_noclip(id,1);
	}
	else if(playerVoodoo[id] < 1) {
		set_user_godmode(id,0);
		set_user_noclip(id,0);
	}
	
	get_user_aiming(id,entId,dumbInt,100);
	
	new in = pev(id,pev_button);
	if(in&IN_USE) {
		
		if(playerTouchItem[id] > 0)
			evtPickUpItem(id);
		
		if(is_user_alive(entId) && is_user_alive(id) && playerCuff[id] > 0) {
			playerUseToggle[id]++;
			if(playerUseToggle[id] > 59) {
				playerUseToggle[id] = 0;
				client_print(id,print_chat,"lol u raepd dat guy");
			}
		}
		
		if(!is_user_alive(entId) && playerUseToggle[id] > 0 || !is_user_alive(id) && playerUseToggle[id] > 0)
			playerUseToggle[id] = 0;
		
		if(playerUse[id]+1 < get_gametime()) {
			evtUse(id);
			playerUse[id] = get_gametime();
		}
	}
	else if(playerUseToggle[id] > 0)
		playerUseToggle[id] = 0;
	
	return PLUGIN_CONTINUE;
}

public evtPreThinkSpec(esHandle,e,ent,host,hostFlags,player,pSet) {
	if(!player)
		return FMRES_IGNORED;
	
	if(playerCloak[ent]) {
		if(!playerThermal[host]) {
			set_es(esHandle,ES_RenderMode, kRenderTransTexture);
			set_es(esHandle,ES_RenderAmt,16);
		}
		else {
			new Float:glowColor[3] = {255.0,0.0,0.0}
			set_es(esHandle,ES_RenderFx,kRenderFxGlowShell);
			set_es(esHandle,ES_RenderColor,glowColor);
		}
	}
	
	if(playerVoodoo[ent] == host) {
		new origin[3];
		pev(ent,pev_origin,origin);
		set_es(esHandle,ES_Origin,playerVoodooLoc[ent]);
	}
	return FMRES_IGNORED;
}

public evtUse(id) {
	new tarId = 0;
	new className[32];
	get_user_aiming(id,tarId,dumbInt,200);
	
	pev(tarId,pev_classname,className,31);
	
	if(equali(className,"func_door") || equali(className,"func_door_rotating")) {
		if((get_user_flags(id) & ADMIN_IMMUNITY))
			force_use(tarId,tarId);
		
		else if(evtOpenDoor(id,tarId))
			force_use(tarId,tarId);
	}
	
	if(is_user_alive(tarId)) {
		client_print(id,print_chat,"lol u used dat guy");
		
	}
	
	evtBuy(id,0);
	
	return PLUGIN_CONTINUE;
}

public evtTouch(entId,id) {
	new className[32];
	pev(entId,pev_classname,className,31);
	
	if(!is_user_alive(id))
		return PLUGIN_HANDLED;
	
	if(equali(className,"droppedItem") && playerTouch[id]+1.0 <= get_gametime()) {
		new targetName[32], name[32], amount, itemId;
		pev(entId,pev_targetname,targetName,31);
		
		sqlResult = SQL_PrepareQuery(sqlConn,"select grp_items.name,grp_curitems.amount,grp_items.id from grp_items,grp_curitems where grp_curitems.id = %i and grp_items.id = grp_curitems.itemid",str_to_num(targetName));
		SQL_Execute(sqlResult);
		
		SQL_ReadResult(sqlResult,0,name,31);
		amount = SQL_ReadResult(sqlResult,1);
		itemId = SQL_ReadResult(sqlResult,2);
		SQL_FreeHandle(sqlResult);
		
		
		set_hudmessage(150, 175, 255, -1.0, 0.40,0,0.0,2.0,0.0,0.0,1);
		
		if(itemId == 1)
			show_hudmessage(id,"Cash: $%.2f^nPress Use to Pickup",float(amount) / 100.0);
		else 
			show_hudmessage(id,"Item: %s x %i^nPress Use to Pickup",name,amount);
		
		playerTouch[id] = get_gametime();
		playerTouchItem[id] = entId;
	}
	else if(equali(className,"func_door") || equali(className,"func_door_rotating")) {
		if(playerTouch[id]+1.0 > get_gametime())
			return PLUGIN_HANDLED;
		
		playerTouch[id] = get_gametime();
		
		if(!evtOpenDoor(id,entId))
			return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public evtPickUpItem(id) {
	new targetName[32];
	pev(playerTouchItem[id],pev_targetname,targetName,31);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select grp_items.name,grp_items.flags,grp_curitems.flags,grp_curitems.amount,grp_items.id from grp_items,grp_curitems where grp_curitems.id = %i and grp_items.id = grp_curitems.itemid",str_to_num(targetName));
	SQL_Execute(sqlResult);
	
	new name[32], flags[2][256], amount, itemId;
	
	SQL_ReadResult(sqlResult,0,name,31);
	SQL_ReadResult(sqlResult,1,flags[0],127);
	SQL_ReadResult(sqlResult,2,flags[1],127);
	amount = SQL_ReadResult(sqlResult,3);
	itemId = SQL_ReadResult(sqlResult,4);
	
	SQL_FreeHandle(sqlResult);
	
	if(containi(flags[0],"NOPICKUP") != -1 || containi(flags[1],"NOPICKUP") != -1) {
		client_print(id,print_chat,"You cannot pick up that item!");
		playerTouchItem[id] = 0;
		return PLUGIN_HANDLED;
	}
	
	engfunc(EngFunc_RemoveEntity, playerTouchItem[id]);
	playerTouchItem[id] = 0;
	
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"delete from grp_curitems where id = %i",str_to_num(targetName));
	
	evtCreatePItem(id,itemId,amount,flags[1]);
	
	if(containi(flags[0],"AUTOUSE") != -1 || containi(flags[1],"AUTOUSE") != -1) {
		cleanString(flags[1],255);
		
		sqlResult = SQL_PrepareQuery(sqlConn,"select id from grp_curitems where ownerid = %i and itemid = %i and flags = '%s' order by id desc",playerId[id],itemId,flags[1]);
		SQL_Execute(sqlResult);
		
		new currentId = SQL_ReadResult(sqlResult,0);
		
		SQL_FreeHandle(sqlResult);
		
		evtUseItem(id,currentId);
	}
	
	emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	return PLUGIN_HANDLED;
}

/*
* Buy Event:
* Used for when a player requests a purchase query.
* Will search for any nearby Properties (looking at), or Shops.
* If a result is found, it will then branch to the respective method.
* If none is found, the method will terminate.
*/
public evtBuy(id,propBuy) {
	new tarId = 0;
	new className[32];
	
	// Property
	if(propBuy > 0) {
		get_user_aiming(id,tarId,dumbInt,200);
		pev(tarId,pev_classname,className,31);
		if(equali(className,"func_door") || equali(className,"func_door_rotating")) {
			sqlResult = SQL_PrepareQuery(sqlConn,"select grp_prop.name,grp_prop.price,grp_prop.id,grp_prop.ownerid from grp_prop,grp_doors where grp_doors.entid = '%i' and grp_doors.mapname = '%s' and grp_prop.price > 0 and grp_prop.id = grp_doors.propid;",tarId,mapName);
			SQL_Execute(sqlResult);
			if(SQL_NumResults(sqlResult) > 0) {
				new Float:propPrice = 0.0;
				SQL_ReadResult(sqlResult,0,className,32);
				SQL_ReadResult(sqlResult,1,propPrice);
				tarId = SQL_ReadResult(sqlResult,2);
				new ownerId =  SQL_ReadResult(sqlResult,3);
				
				SQL_FreeHandle(sqlResult);
				
				evtBuyProp(id,tarId,className,propPrice,ownerId);
				return PLUGIN_HANDLED;
			}
			SQL_FreeHandle(sqlResult);
		}
	}
	
	// Shops
	new origin[3], limit[2][3];
	get_user_origin(id,origin);
	limit[0][0] = origin[0] - 100;
	limit[0][1] = origin[1] - 100;
	limit[0][2] = origin[2] - 100;
	
	limit[1][0] = origin[0] + 100;
	limit[1][1] = origin[1] + 100;
	limit[1][2] = origin[2] + 100;
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select grp_shops.id,grp_shops.name,grp_shops.type,grp_prop.profit,grp_prop.ownerid,grp_shops.x,grp_shops.y,grp_shops.z from grp_shops,grp_prop where grp_shops.x > %i and grp_shops.x < %i and grp_shops.y > %i and grp_shops.y < %i and grp_shops.z > %i and grp_shops.z < %i and grp_shops.propid = grp_prop.id and grp_shops.mapname = '%s' limit 1",limit[0][0],limit[1][0],limit[0][1],limit[1][1],limit[0][2],limit[1][2],mapName);
	SQL_Execute(sqlResult);
	
	if(SQL_MoreResults(sqlResult) < 1) {
		SQL_FreeHandle(sqlResult);
		return PLUGIN_HANDLED;
	}	
	
	playerShopId[id] = SQL_ReadResult(sqlResult,0);
	SQL_ReadResult(sqlResult,1,playerShopName[id],31);
	
	// 0: Shop, 1: Bank Teller, 2: Bank ATM, 3: Prodigy Storage, 4: Stor-O-Matic, 5: Static Phone
	playerShopMenu[id] = SQL_ReadResult(sqlResult,2) * 10;
	
	if(playerShopMenu[id] < 30 && playerShopMenu[id] > 9) {
		playerCartPrice[id] = 0.0;
		client_print(id,print_chat,"Say the amount to transfer.");
	}
	
	if(playerShopMenu[id] == 30)
		playerShopMenu[id] = 50;
	
	else if(playerShopMenu[id] == 40)
		playerShopMenu[id] = 60;
	
	else if(playerShopMenu[id] == 50)
		playerShopMenu[id] = 70;
	
	SQL_ReadResult(sqlResult,3,playerShopProfit[id]);
	playerShopOwner[id] = SQL_ReadResult(sqlResult,4);
	
	playerShopLoc[id][0] = SQL_ReadResult(sqlResult,5);
	playerShopLoc[id][1] = SQL_ReadResult(sqlResult,6);
	playerShopLoc[id][2] = SQL_ReadResult(sqlResult,7);
	
	SQL_FreeHandle(sqlResult);
	
	menuShop(id);
	
	return PLUGIN_HANDLED;
}

/*
* Buy Property Event:
*/
public evtBuyProp(id,propId,propName[32],Float:propPrice,ownerId) {
	playerCartPrice[id] = propPrice;
	playerCartId[id] = propId;
	formatex(playerCartName[id],31,"%s",propName);
	playerShopMenu[id] = 40;
	playerCartAmount[id] = ownerId;
	
	menuShop(id);
	return PLUGIN_HANDLED;
}

public evtPhoneNumber(const number[]) {
	new formatNumber[16], len = strlen(number);
	
	switch(len) {
		case 4: {
			formatNumber[0] = number[0];
			formatNumber[1] = number[1];
			formatNumber[2] = number[2];
			
			formatNumber[3] = '-';
			
			formatNumber[4] = number[3];
		}
		
		case 5: {
			formatNumber[0] = number[0];
			formatNumber[1] = number[1];
			formatNumber[2] = number[2];
			
			formatNumber[3] = '-';
			
			formatNumber[4] = number[3];
			formatNumber[5] = number[4];
		}
		
		case 6: {
			formatNumber[0] = number[0];
			formatNumber[1] = number[1];
			formatNumber[2] = number[2];
			
			formatNumber[3] = '-';
			
			formatNumber[4] = number[3];
			formatNumber[5] = number[4];
			formatNumber[6] = number[5];
		}
		
		case 7: {
			formatNumber[0] = number[0];
			formatNumber[1] = number[1];
			formatNumber[2] = number[2];
			
			formatNumber[3] = '-';
			
			formatNumber[4] = number[3];
			formatNumber[5] = number[4];
			formatNumber[6] = number[5];
			formatNumber[7] = number[6];
		}
		
		case 8: {
			formatNumber[0] = '(';
			
			formatNumber[1] = number[0];
			formatNumber[2] = number[1];
			formatNumber[3] = number[2];
			
			formatNumber[4] = ')';
			formatNumber[5] = ' ';
			
			formatNumber[6] = number[3];
			formatNumber[7] = number[4];
			formatNumber[8] = number[5];
			
			formatNumber[9] = '-';
			
			formatNumber[10] = number[6];
			formatNumber[11] = number[7];
		}
		
		case 9: {
			formatNumber[0] = '(';
			
			formatNumber[1] = number[0];
			formatNumber[2] = number[1];
			formatNumber[3] = number[2];
			
			formatNumber[4] = ')';
			formatNumber[5] = ' ';
			
			formatNumber[6] = number[3];
			formatNumber[7] = number[4];
			formatNumber[8] = number[5];
			
			formatNumber[9] = '-';
			
			formatNumber[10] = number[6];
			formatNumber[11] = number[7];
			formatNumber[12] = number[8];
		}
		
		case 10: {
			formatNumber[0] = '(';
			
			formatNumber[1] = number[0];
			formatNumber[2] = number[1];
			formatNumber[3] = number[2];
			
			formatNumber[4] = ')';
			formatNumber[5] = ' ';
			
			formatNumber[6] = number[3];
			formatNumber[7] = number[4];
			formatNumber[8] = number[5];
			
			formatNumber[9] = '-';
			
			formatNumber[10] = number[6];
			formatNumber[11] = number[7];
			formatNumber[12] = number[8];
			formatNumber[13] = number[9];
		}
		
		default: {
			formatex(formatNumber,15,"%s",number);
		}
	}
	
	return formatNumber;
}

public evtDropMoney(id,Float:amount) {
	new Float:wallet, walletStr[16], itemAmount;
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select wallet from grp_players where id = %i",playerId[id]);
	SQL_Execute(sqlResult);
	
	SQL_ReadResult(sqlResult,0,wallet);
	
	SQL_FreeHandle(sqlResult);
	
	if(wallet <= 0.01 || amount < 0.0)
		return PLUGIN_HANDLED;
	
	if(amount == 0.0 || amount > wallet )
		amount = wallet;
	
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set wallet=wallet-%.2f where id = %i",amount,playerId[id]);
	
	formatex(walletStr,15,"%.2f",amount);
	replace_all(walletStr,15,".","");
	itemAmount = str_to_num(walletStr);
	
	new origin[3];
	get_user_origin(id,origin);
	client_print(id,print_chat,"You dropped $%.2f.",amount);
	
	evtCreateItem(1,itemAmount,origin,"AUTOUSE");
	
	return PLUGIN_HANDLED;
}

public evtGiveMoney(id,tarId,Float:amount) {
	new Float:wallet;
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select wallet from grp_players where id = %i",playerId[id]);
	SQL_Execute(sqlResult);
	
	SQL_ReadResult(sqlResult,0,wallet);
	
	SQL_FreeHandle(sqlResult);
	
	if(wallet <= 0.01 || amount < 0.0)
		return PLUGIN_HANDLED;
	
	if(amount == 0.0 || amount > wallet )
		amount = wallet;
	
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set wallet=wallet-%.2f where id = %i",amount,playerId[id]);
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set wallet=wallet+%.2f where id = %i",amount,playerId[tarId]);

	new names[2][32];
	get_user_name(id,names[0],31);
	get_user_name(tarId,names[1],31);
	
	client_print(id,print_chat,"You gave %s $%.2f.",names[1],amount);
	client_print(tarId,print_chat,"%s gave you $%.2f.",names[0],amount);
	
	return PLUGIN_HANDLED;
}

public evtGiveAccess(id,entId,tarId) {
	sqlResult = SQL_PrepareQuery(sqlConn,"select p.id from grp_prop p, grp_doors d where p.ownerid = %i and p.id = d.propid",playerId[id]);
	SQL_Execute(sqlResult);
	
	if(SQL_NumResults(sqlResult) < 1) {
		SQL_FreeHandle(sqlResult);
		return PLUGIN_HANDLED;
	}
	
	new propId = SQL_ReadResult(sqlResult,0);
	
	SQL_FreeHandle(sqlResult);
	
	if(propId < 1) 
		return PLUGIN_HANDLED;
	
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_prop set access=access+^"<%i>^" where id = %i",playerId[tarId],propId);
	return PLUGIN_HANDLED;
}

public evtOpenDoor(id,entId) {
	sqlResult = SQL_PrepareQuery(sqlConn,"select count(*) from grp_prop p, grp_doors d where d.entid = %i and d.propid=p.id and p.access like '%<%i>%' or d.entid = %i and d.propid=p.id and p.ownerid = %i or d.locked = 0 and d.entid = %i or p.orgid = (select j.org from grp_jobs j, grp_players p where p.job = j.id and p.id = %i) and d.entid = %i and d.propid=p.id",entId,playerId[id],entId,playerId[id],entId,playerId[id],entId);
	SQL_Execute(sqlResult);
		
	if(SQL_NumResults(sqlResult) < 1) {
		SQL_FreeHandle(sqlResult);
		return true;
	}
		
	new columns = SQL_ReadResult(sqlResult,0);
		
	SQL_FreeHandle(sqlResult);
		
	if(columns < 1)
		return false;
	
	return true;
}

public evtEmitAction(id,showSelf,const message[],any:...) {
	new outMessage[64], name[32];
	vformat(outMessage,63,message,4);
	
	get_user_name(id,name,31);
	format(outMessage,63,"**%s %s",name,outMessage);
	
	new origin[2][3];
	get_user_origin(id,origin[0]);
	
	for(new x=1;x < 33;x++) {
		if(is_user_alive(x)) {
			if(x != id) {
				get_user_origin(x,origin[1]);
				
				if(get_distance(origin[0],origin[1]) <= 400) 
					client_print(x,print_chat,outMessage);
			}
			
			else if(showSelf)
				client_print(x,print_chat,outMessage);
			
		}
	}
}

public evtCreateItem(itemId,amount,origin[3],flags[256]) {
	serverItemId++;
	cleanString(flags,255);
	
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"insert into grp_curitems (itemid,amount,x,y,z,sessionid,mapname,flags) values (%i,%i,%i,%i,%i,%i,'%s','%s')",itemId,amount,origin[0],origin[1],origin[2],serverItemId,mapName,flags);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select grp_curitems.id,grp_items.model from grp_curitems,grp_items where grp_curitems.sessionid = %i and grp_curitems.mapname = '%s' and grp_curitems.itemid = grp_items.id",serverItemId,mapName);
	SQL_Execute(sqlResult);
	
	new id = SQL_ReadResult(sqlResult,0), model[64];
	
	SQL_ReadResult(sqlResult,1,model,63);
	
	SQL_FreeHandle(sqlResult);
	
	if(itemId == 1 && amount >= 50000)
		evtSpawnItem(id,itemId,amount,origin,"models/briefcase.mdl");
	else
		evtSpawnItem(id,itemId,amount,origin,model);
}

public evtCreatePItem(id,itemId,amount,flags[256]) {
	cleanString(flags,255);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select id,amount from grp_curitems where ownerid = %i and itemid = %i and flags = '%s'",playerId[id],itemId,flags);
	SQL_Execute(sqlResult);
	
	if(SQL_NumResults(sqlResult) > 0)
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_curitems set amount=amount+%i where id = %i",amount,SQL_ReadResult(sqlResult,0));
	else
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"insert into grp_curitems (itemid,amount,ownerid,flags) values (%i,%i,%i,'%s')",itemId,amount,playerId[id],flags);
	
	SQL_FreeHandle(sqlResult);
	return PLUGIN_HANDLED;
}

public evtSpawnItem(id,itemId,amount,origin[3],model[64]) {
	new targetName[64];
	formatex(targetName,63,"%i",id);
	
	new Float:minBox[3] = {-2.5,-2.5,-2.5};
	new Float:maxBox[3] = {2.5,2.5,-2.5};
	new Float:angles[3] = {0.0,0.0,0.0};
	
	angles[1] = random_float(0.0,360.0);
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	
	if(!pev_valid(ent)) {
		log_amx("ERROR: Item failed to spawn.");
		return PLUGIN_HANDLED;
	}
	
	set_pev(ent,pev_targetname,targetName);
	set_pev(ent,pev_classname,"droppedItem");
	set_pev(ent,pev_mins,minBox);
	set_pev(ent,pev_maxs,maxBox);
	set_pev(ent,pev_angles,angles);
	set_pev(ent,pev_takedamage,0.0);
	set_pev(ent,pev_dmg,0.0);
	set_pev(ent,pev_dmg_take,0.0);
	set_pev(ent,pev_solid,SOLID_TRIGGER);
	set_pev(ent,pev_movetype,MOVETYPE_TOSS);
	
	if(strlen(model) > 0)
		engfunc(EngFunc_SetModel, ent, model);
	else
		engfunc(EngFunc_SetModel, ent, "models/briefcase.mdl");
	
	new Float:fOrigin[3];
	
	fOrigin[0] = float(origin[0]);
	fOrigin[1] = float(origin[1]);
	fOrigin[2] = float(origin[2]);
	
	set_pev(ent,pev_origin,fOrigin);
	
	return PLUGIN_HANDLED;
}

public evtDropItem(id,itemId,dropAmount) {
	new origin[3];
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select amount,flags,itemid from grp_curitems where id = %i",itemId);
	SQL_Execute(sqlResult);
	
	new amount, flags[256], iId;
	amount = SQL_ReadResult(sqlResult,0);
	SQL_ReadResult(sqlResult,1,flags,255);
	iId = SQL_ReadResult(sqlResult,2);
	get_user_origin(id,origin);
	
	SQL_FreeHandle(sqlResult);
	
	if(amount < dropAmount) 
		dropAmount = amount;
	
	if(amount == dropAmount) 
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"delete from grp_curitems where id = %i",itemId);
	else
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_curitems set amount=amount-%i where id = %i",dropAmount,itemId);
	
	client_print(id,print_chat,"Dropped %i of %s.",dropAmount,playerCartName[id]);
	
	evtCreateItem(iId,dropAmount,origin,flags);
	
	emit_sound(id, CHAN_ITEM, "items/ammopickup1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	return PLUGIN_HANDLED;
}

public evtGiveItem(id,itemId,giveAmount) {
	new entId;
	get_user_aiming(id,entId,dumbInt,200);
	
	if(!is_user_alive(entId))
		return PLUGIN_HANDLED;
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select amount,flags,itemid from grp_curitems where id = %i",itemId);
	SQL_Execute(sqlResult);
	
	new amount, flags[256], iId, origin[3];
	amount = SQL_ReadResult(sqlResult,0);
	SQL_ReadResult(sqlResult,1,flags,255);
	iId = SQL_ReadResult(sqlResult,2);
	get_user_origin(id,origin);
	
	SQL_FreeHandle(sqlResult);
	
	if(amount < giveAmount) 
		giveAmount = amount;
	
	if(amount == giveAmount) 
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"delete from grp_curitems where id = %i",itemId);
	else
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_curitems set amount=amount-%i where id = %i",giveAmount,itemId);
	
	new names[2][32];
	get_user_name(id,names[0],31);
	get_user_name(entId,names[1],31);
	client_print(id,print_chat,"Gave %s: %i of %s.",names[1],giveAmount,playerCartName[id]);
	client_print(entId,print_chat,"%s gave you %i of %s.",names[0],giveAmount,playerCartName[id]);
	
	evtCreatePItem(entId,iId,giveAmount,flags);
	
	return PLUGIN_HANDLED;
}

public evtUseItem(id,currentId) {
	sqlResult = SQL_PrepareQuery(sqlConn,"select i.cmd,i.flags,c.flags,c.amount,i.id from grp_items i, grp_curitems c where c.id = %i and i.id = c.itemid",currentId);
	SQL_Execute(sqlResult);
	
	new cmd[256], flags[2][128], amount, itemId, strIds[4][8];
	SQL_ReadResult(sqlResult,0,cmd,255);
	SQL_ReadResult(sqlResult,1,flags[0],255);
	SQL_ReadResult(sqlResult,2,flags[1],255);
	amount = SQL_ReadResult(sqlResult,3);
	itemId = SQL_ReadResult(sqlResult,4);
	
	formatex(strIds[0],7,"%i",id);
	formatex(strIds[1],7,"%i",amount);
	formatex(strIds[2],7,"%i",itemId);
	formatex(strIds[3],7,"%i",currentId);
	
	replace_all(cmd,255,"<id>",strIds[0]);
	replace_all(cmd,255,"<amount>",strIds[1]);
	replace_all(cmd,255,"<itemid>",strIds[2]);
	replace_all(cmd,255,"<currentid>",strIds[3]);
	
	SQL_FreeHandle(sqlResult);
	
	server_cmd(cmd);
	
	return PLUGIN_HANDLED;
}

public evtDestroyItem(id,itemId,deleteAmount,show) {
	sqlResult = SQL_PrepareQuery(sqlConn,"select amount from grp_curitems where id = %i",itemId);
	SQL_Execute(sqlResult);
	
	new amount = SQL_ReadResult(sqlResult,0);
	
	SQL_FreeHandle(sqlResult);
	
	if(amount < deleteAmount) 
		deleteAmount = amount;
	
	if(amount == deleteAmount) 
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"delete from grp_curitems where id = %i",itemId);
	else
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_curitems set amount=amount-%i where id = %i",deleteAmount,itemId);
	
	if(show)
		client_print(id,print_chat,"Destroyed %i of %s(s).",deleteAmount,playerCartName[id]);
	
	return PLUGIN_HANDLED;
}

public evtDepositItem(id,curId,depositAmount,type,storeId) {
	new flags[256];
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select amount,itemid,flags from grp_curitems where id = %i",curId);
	SQL_Execute(sqlResult);
	
	new amount = SQL_ReadResult(sqlResult,0);
	new itemId = SQL_ReadResult(sqlResult,1);
	SQL_ReadResult(sqlResult,2,flags,255);
	
	SQL_FreeHandle(sqlResult);
	
	if(amount < depositAmount) 
		depositAmount = amount;
	
	if(amount == depositAmount) 
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"delete from grp_curitems where id = %i",curId);
	else
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_curitems set amount=amount-%i where id = %i",depositAmount,curId);
	
	evtCreateSItem(storeId,itemId,depositAmount,flags,type);
	
	client_print(id,print_chat,"Deposited %i x %s into storage.",depositAmount,playerCartName[id]);
	
	return PLUGIN_HANDLED;
}

public evtWithdrawItem(id,curId,withdrawAmount,type) {
	new typeStr[16], flags[256];
	if(type == 0) 
		formatex(typeStr,15,"storage");
	else
		formatex(typeStr,15,"prodigy");
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select amount,itemid,flags from grp_%s where id = %i",typeStr,curId);
	SQL_Execute(sqlResult);
	
	new amount = SQL_ReadResult(sqlResult,0);
	new itemId = SQL_ReadResult(sqlResult,1);
	SQL_ReadResult(sqlResult,2,flags,255);
	
	SQL_FreeHandle(sqlResult);
	
	if(amount < withdrawAmount) 
		withdrawAmount = amount;
	
	if(amount == withdrawAmount) 
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"delete from grp_%s where id = %i",typeStr,curId);
	else
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_%s set amount=amount-%i where id = %i",typeStr,withdrawAmount,curId);
	
	evtCreatePItem(id,itemId,withdrawAmount,flags);
	
	client_print(id,print_chat,"Withdrew %i x %s from storage.",withdrawAmount,playerCartName[id]);
	
	return PLUGIN_HANDLED;
}

public evtCreateSItem(id,itemId,amount,flags[256],type) {
	new typeStr[16];
	if(type == 0) 
		formatex(typeStr,15,"storage");
	else 
		formatex(typeStr,15,"prodigy");
	
	cleanString(flags,255);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select id,amount from grp_%s where storeid = %i and itemid = %i and flags = '%s'",typeStr,id,itemId,flags);
	SQL_Execute(sqlResult);
	
	if(SQL_NumResults(sqlResult) > 0)
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_%s set amount=amount+%i where id = %i",typeStr,amount,SQL_ReadResult(sqlResult,0));
	else
		SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"insert into grp_%s (itemid,amount,storeid,flags) values (%i,%i,%i,'%s')",typeStr,itemId,amount,id,flags);
	
	SQL_FreeHandle(sqlResult);
	return PLUGIN_HANDLED;
}

/*
* Menu Section (SECTMENU) 
*/

public menuShop(id) {
	new shopName[32], buttons;
	new menu;
	
	new origin[3];
	get_user_origin(id,origin);
	
	if(get_distance(origin,playerShopLoc[id]) > 100 && playerShopMenu[id] < 30) {
		client_print(id,print_chat,"You're too far away from the npc!");
		playerShopMenu[id] = 0;
		return PLUGIN_HANDLED;
	}
	
	switch(playerShopMenu[id]) {
		// Main Menu: Shop
		case 0: {
			formatex(shopName,31,"Shop: %s",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			menu_additem(menu,"Purchase Items","shop",ADMIN_ALL);
			
			if(playerShopOwner[id] == playerId[id] && playerShopProfit[id] > 0) {
				buttons++;
				formatex(shopName,31,"Collect Profit ($%.2f)",playerShopProfit[id]);
				menu_additem(menu,"Collect Profit ($%.2f)","shoppro",ADMIN_ALL);
			}
			
			if(playerShopOwner[id] != playerId[id] && playerShopProfit[id] >= 350.0) {
				if(buttons == 0)
					menu_addblank(menu,1);
				
				menu_additem(menu,"Hello, I would like to rob you. :D","shoprob",ADMIN_ALL);
			}
		}
		
		// Shop Menu
		case 1: {
			formatex(shopName,31,"Items: %s",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			sqlResult = SQL_PrepareQuery(sqlConn,"select grp_items.id,grp_items.name,grp_shopitems.price from grp_shopitems,grp_items where grp_shopitems.shopid = %i and grp_shopitems.itemid = grp_items.id limit 64",playerShopId[id]);
			SQL_Execute(sqlResult);
			
			if(SQL_MoreResults(sqlResult) < 1) {
				SQL_FreeHandle(sqlResult);
				playerShopMenu[id] = 0;
				client_print(id,print_chat,"This shop has no items!");
				log_amx("ALERT: Shop ^"%s^" (%i) has no items to sell!",playerShopName[id],playerShopId[id]);
				menu_destroy(menu);
				menuShop(id);
				return PLUGIN_HANDLED;
			}
			
			new itemId, itemName[32], Float:price, itemCmd[64];
			
			while(SQL_MoreResults(sqlResult)) {
				itemId = SQL_ReadResult(sqlResult,0);
				SQL_ReadResult(sqlResult,1,itemName,31);
				SQL_ReadResult(sqlResult,2,price);
				
				formatex(itemCmd,63,"%i ^"%s^" %.2f",itemId,itemName,price);
				format(itemName,31,"%s - $%.2f",itemName,price);
				
				menu_additem(menu,itemName,itemCmd,ADMIN_ALL);
				SQL_NextRow(sqlResult);
			}
			
			SQL_FreeHandle(sqlResult);
		}
		
		// Confirm Item Amount Menu
		case 2: {
			formatex(shopName,31,"Buying: %i x %s^nTotal: $%.2f @ $%.2f/1",playerCartAmount[id],playerCartName[id],float(playerCartAmount[id]) * playerCartPrice[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Purchase W/ Debit","confirmd",ADMIN_ALL);
			menu_additem(menu,"Purchase W/ Cash","confirmc",ADMIN_ALL);
			menu_additem(menu,"Back","back",ADMIN_ALL);
		}
		
		// Main Menu: Bank Teller
		case 10: {
			formatex(shopName,31,"%s Teller ^nFunds: $%.2f",playerShopName[id],playerCartPrice[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Deposit Funds","deposit",ADMIN_ALL);
			menu_additem(menu,"Withdraw Funds","withdraw",ADMIN_ALL);
			//menu_additem(menu,"Hello, I would like to rob you. xD","bankrob",ADMIN_ALL);
		}
		
		// Bank Teller: Deposit
		case 11: {
			formatex(shopName,31,"%s Teller: Deposit",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"$5.00","5.0",ADMIN_ALL);
			menu_additem(menu,"$10.00","10.0",ADMIN_ALL);
			menu_additem(menu,"$20.00","20.0",ADMIN_ALL);
			menu_additem(menu,"$50.00","50.0",ADMIN_ALL);
			menu_additem(menu,"$100.00","100.0",ADMIN_ALL);
			menu_additem(menu,"$200.00","200.0",ADMIN_ALL);
			menu_additem(menu,"$500.00","500.0",ADMIN_ALL);
			menu_additem(menu,"$1000.00","1000.0",ADMIN_ALL);
			
			//menu_setprop(menu,MPROP_PADMENU
		}
		
		// Bank Teller: Withdraw
		case 12: {
			formatex(shopName,31,"%s Teller: Withdraw",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"$5.00","5.0",ADMIN_ALL);
			menu_additem(menu,"$10.00","10.0",ADMIN_ALL);
			menu_additem(menu,"$20.00","20.0",ADMIN_ALL);
			menu_additem(menu,"$50.00","50.0",ADMIN_ALL);
			menu_additem(menu,"$100.00","100.0",ADMIN_ALL);
			menu_additem(menu,"$200.00","200.0",ADMIN_ALL);
			menu_additem(menu,"$500.00","500.0",ADMIN_ALL);
			menu_additem(menu,"$1000.00","1000.0",ADMIN_ALL);
		}
		
		// Main Menu: Bank ATM
		case 20: {
			formatex(shopName,31,"%s ATM ^nFunds: $%.2f",playerShopName[id],playerCartPrice[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Deposit Funds","deposit",ADMIN_ALL);
			menu_additem(menu,"Withdraw Funds","withdraw",ADMIN_ALL);
		}
		
		// Bank ATM: Deposit
		case 21: {
			formatex(shopName,31,"%s ATM: Deposit",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"$5.00","5.0",ADMIN_ALL);
			menu_additem(menu,"$10.00","10.0",ADMIN_ALL);
			menu_additem(menu,"$20.00","20.0",ADMIN_ALL);
			menu_additem(menu,"$50.00","50.0",ADMIN_ALL);
			menu_additem(menu,"$100.00","100.0",ADMIN_ALL);
			menu_additem(menu,"$200.00","200.0",ADMIN_ALL);
			menu_additem(menu,"$500.00","500.0",ADMIN_ALL);
			menu_additem(menu,"$1000.00","1000.0",ADMIN_ALL);
		}
		
		// Bank ATM: Withdraw
		case 22: {
			formatex(shopName,31,"%s ATM: Withdraw",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"$5.00","5.0",ADMIN_ALL);
			menu_additem(menu,"$10.00","10.0",ADMIN_ALL);
			menu_additem(menu,"$20.00","20.0",ADMIN_ALL);
			menu_additem(menu,"$50.00","50.0",ADMIN_ALL);
			menu_additem(menu,"$100.00","100.0",ADMIN_ALL);
			menu_additem(menu,"$200.00","200.0",ADMIN_ALL);
			menu_additem(menu,"$500.00","500.0",ADMIN_ALL);
			menu_additem(menu,"$1000.00","1000.0",ADMIN_ALL);
		}
		
		// Inventory Main Menu
		case 30: {
			menu = menu_create("Your Inventory", "menuShopHand");
			sqlResult = SQL_PrepareQuery(sqlConn,"select grp_curitems.id,grp_curitems.amount,grp_items.name from grp_items,grp_curitems where grp_curitems.ownerid = %i and grp_curitems.itemid = grp_items.id",playerId[id]);
			SQL_Execute(sqlResult);
			
			if(SQL_NumResults(sqlResult) < 1) {
				client_print(id,print_chat,"You have no items!");
				menu_destroy(menu);
				SQL_FreeHandle(sqlResult);
				return PLUGIN_HANDLED;
			}
			
			new itemName[32], itemAmount, itemId;
			
			while(SQL_MoreResults(sqlResult)) {
				itemId = SQL_ReadResult(sqlResult,0);
				itemAmount = SQL_ReadResult(sqlResult,1);
				SQL_ReadResult(sqlResult,2,itemName,31);
				
				formatex(shopName,31,"%i %i ^"%s^"",itemId,itemAmount,itemName);
				format(itemName,31,"%s - %i",itemName,itemAmount);
				
				menu_additem(menu,itemName,shopName,ADMIN_ALL);
				
				SQL_NextRow(sqlResult);
			}
			
			SQL_FreeHandle(sqlResult);
		}
		
		// Inventory Item Selected
		case 31: {
			formatex(shopName,31,"Item: %s x %i",playerCartName[id],playerCartAmount[id]);
			
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Use Item","use",ADMIN_ALL);
			menu_additem(menu,"Use Item With..","usewith",ADMIN_ALL);
			menu_additem(menu,"Examine Item","examine",ADMIN_ALL);
			menu_additem(menu,"Show Item","show",ADMIN_ALL);
			menu_additem(menu,"Give Item","give",ADMIN_ALL);
			menu_additem(menu,"Drop Item","drop",ADMIN_ALL);
			menu_additem(menu,"Destroy Item","destroy",ADMIN_ALL);
		}
		
		// Inventory Drop Amount
		case 32: {
			formatex(shopName,31,"Dropping Item: %s x %i",playerCartName[id],playerCartAmount[id]);
			
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Drop 1","1",ADMIN_ALL);
			if(playerCartAmount[id] >= 5)
				menu_additem(menu,"Drop 5","5",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 1)
				menu_additem(menu,"Drop 10","10",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 25)
				menu_additem(menu,"Drop 25","25",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 50)
				menu_additem(menu,"Drop 50","50",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 100)
				menu_additem(menu,"Drop 100","100",ADMIN_ALL);
			
			menu_additem(menu,"Drop All","all",ADMIN_ALL);
		}
		
		// Inventory Give Amount
		case 33: {
			formatex(shopName,31,"Giving Item: %s x %i",playerCartName[id],playerCartAmount[id]);
			
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Give 1","1",ADMIN_ALL);
			if(playerCartAmount[id] >= 5)
				menu_additem(menu,"Give 5","5",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 1)
				menu_additem(menu,"Give 10","10",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 25)
				menu_additem(menu,"Give 25","25",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 50)
				menu_additem(menu,"Give 50","50",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 100)
				menu_additem(menu,"Give 100","100",ADMIN_ALL);
			
			menu_additem(menu,"Give All","all",ADMIN_ALL);
		}
		
		// Inventory Destroy Amount
		case 34: {
			formatex(shopName,31,"Destroying Item: %s x %i",playerCartName[id],playerCartAmount[id]);
			
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Destroy 1","1",ADMIN_ALL);
			if(playerCartAmount[id] >= 5)
				menu_additem(menu,"Destroy 5","5",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 1)
				menu_additem(menu,"Destroy 10","10",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 25)
				menu_additem(menu,"Destroy 25","25",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 50)
				menu_additem(menu,"Destroy 50","50",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 100)
				menu_additem(menu,"Destroy 100","100",ADMIN_ALL);
			
			menu_additem(menu,"Destroy All","all",ADMIN_ALL);
		}
		
		// Inventory Use With
		case 35: {
			return PLUGIN_HANDLED;
		}
		
		// Property Confirm Buy
		case 40: {
			formatex(shopName,31,"Property: %s",playerCartName[id]);
			menu = menu_create(shopName, "menuShopHand");
			formatex(shopName,31,"Purchase ($%.2f)",playerCartPrice[id]);
			menu_additem(menu,shopName,"buy",ADMIN_ALL);
		}
		
		// Prodigy Main Menu
		case 50: {
			formatex(shopName,31,"%s Storage",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Withdraw Item(s)","1",ADMIN_ALL);
			menu_additem(menu,"Deposit Item(s)","2",ADMIN_ALL);
		}
		
		// Prodigy: List Items (STORAGE)
		case 51: {
			formatex(shopName,31,"%s Storage: Withdraw",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			sqlResult = SQL_PrepareQuery(sqlConn,"select grp_prodigy.id,grp_prodigy.amount,grp_items.name from grp_items,grp_prodigy where grp_prodigy.storeid = %i and grp_prodigy.itemid = grp_items.id",playerId[id]);
			SQL_Execute(sqlResult);
			
			if(SQL_NumResults(sqlResult) < 1) {
				client_print(id,print_chat,"Your storage account is empty!");
				menu_destroy(menu);
				SQL_FreeHandle(sqlResult);
				return PLUGIN_HANDLED;
			}
			
			new itemName[32], itemAmount, itemId;
			
			while(SQL_MoreResults(sqlResult)) {
				itemId = SQL_ReadResult(sqlResult,0);
				itemAmount = SQL_ReadResult(sqlResult,1);
				SQL_ReadResult(sqlResult,2,itemName,31);
				
				formatex(shopName,31,"%i %i ^"%s^"",itemId,itemAmount,itemName);
				format(itemName,31,"%s - %i",itemName,itemAmount);
				
				menu_additem(menu,itemName,shopName,ADMIN_ALL);
				
				SQL_NextRow(sqlResult);
			}
			
			SQL_FreeHandle(sqlResult);
		}
		
		// Prodigy: List Items (INVENTORY)
		case 52: {
			formatex(shopName,31,"%s Storage: Deposit",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			sqlResult = SQL_PrepareQuery(sqlConn,"select grp_curitems.id,grp_curitems.amount,grp_items.name from grp_items,grp_curitems where grp_curitems.ownerid = %i and grp_curitems.itemid = grp_items.id",playerId[id]);
			SQL_Execute(sqlResult);
			
			if(SQL_NumResults(sqlResult) < 1) {
				client_print(id,print_chat,"Your inventory is empty!");
				menu_destroy(menu);
				SQL_FreeHandle(sqlResult);
				return PLUGIN_HANDLED;
			}
			
			new itemName[32], itemAmount, itemId;
			
			while(SQL_MoreResults(sqlResult)) {
				itemId = SQL_ReadResult(sqlResult,0);
				itemAmount = SQL_ReadResult(sqlResult,1);
				SQL_ReadResult(sqlResult,2,itemName,31);
				
				formatex(shopName,31,"%i %i ^"%s^"",itemId,itemAmount,itemName);
				format(itemName,31,"%s - %i",itemName,itemAmount);
				
				menu_additem(menu,itemName,shopName,ADMIN_ALL);
				
				SQL_NextRow(sqlResult);
			}
			
			SQL_FreeHandle(sqlResult);
		}
		
		// Prodigy: Deposit Item Selected
		case 53: {
			formatex(shopName,31,"Deposit %s: x %i",playerCartName[id],playerCartAmount[id]);
			
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Deposit 1","1",ADMIN_ALL);
			if(playerCartAmount[id] >= 5)
				menu_additem(menu,"Deposit 5","5",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 1)
				menu_additem(menu,"Deposit 10","10",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 25)
				menu_additem(menu,"Deposit 25","25",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 50)
				menu_additem(menu,"Deposit 50","50",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 100)
				menu_additem(menu,"Deposit 100","100",ADMIN_ALL);
			
			menu_additem(menu,"Deposit All","all",ADMIN_ALL);
		}
		
		// Prodigy: Withdraw Item Selected
		case 54: {
			formatex(shopName,31,"Withdraw %s: x %i",playerCartName[id],playerCartAmount[id]);
			
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Withdraw 1","1",ADMIN_ALL);
			if(playerCartAmount[id] >= 5)
				menu_additem(menu,"Withdraw 5","5",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 1)
				menu_additem(menu,"Withdraw 10","10",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 25)
				menu_additem(menu,"Withdraw 25","25",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 50)
				menu_additem(menu,"Withdraw 50","50",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 100)
				menu_additem(menu,"Withdraw 100","100",ADMIN_ALL);
			
			menu_additem(menu,"Withdraw All","all",ADMIN_ALL);
		}
		
		// Storage Main Menu
		case 60: {
			formatex(shopName,31,"%s Stor-O-Matic",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Withdraw Item(s)","1",ADMIN_ALL);
			menu_additem(menu,"Deposit Item(s)","2",ADMIN_ALL);
		}
		
		// Storage: List Items (STORAGE)
		case 61: {
			formatex(shopName,31,"%s Stor-O-Matic: Withdraw",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			sqlResult = SQL_PrepareQuery(sqlConn,"select grp_storage.id,grp_storage.amount,grp_items.name from grp_items,grp_storage where grp_storage.storeid = %i and grp_storage.itemid = grp_items.id",playerShopId[id]);
			SQL_Execute(sqlResult);
			
			if(SQL_NumResults(sqlResult) < 1) {
				client_print(id,print_chat,"This Stor-O-Matic is empty!");
				menu_destroy(menu);
				SQL_FreeHandle(sqlResult);
				return PLUGIN_HANDLED;
			}
			
			new itemName[32], itemAmount, itemId;
			
			while(SQL_MoreResults(sqlResult)) {
				itemId = SQL_ReadResult(sqlResult,0);
				itemAmount = SQL_ReadResult(sqlResult,1);
				SQL_ReadResult(sqlResult,2,itemName,31);
				
				formatex(shopName,31,"%i %i ^"%s^"",itemId,itemAmount,itemName);
				format(itemName,31,"%s - %i",itemName,itemAmount);
				
				menu_additem(menu,itemName,shopName,ADMIN_ALL);
				
				SQL_NextRow(sqlResult);
			}
			
			SQL_FreeHandle(sqlResult);
		}
		
		// Storage: List Items (INVENTORY)
		case 62: {
			formatex(shopName,31,"%s Stor-O-Matic: Deposit",playerShopName[id]);
			menu = menu_create(shopName, "menuShopHand");
			
			sqlResult = SQL_PrepareQuery(sqlConn,"select grp_curitems.id,grp_curitems.amount,grp_items.name from grp_items,grp_curitems where grp_curitems.ownerid = %i and grp_curitems.itemid = grp_items.id",playerId[id]);
			SQL_Execute(sqlResult);
			
			if(SQL_NumResults(sqlResult) < 1) {
				client_print(id,print_chat,"Your inventory is empty!");
				menu_destroy(menu);
				SQL_FreeHandle(sqlResult);
				return PLUGIN_HANDLED;
			}
			
			new itemName[32], itemAmount, itemId;
			
			while(SQL_MoreResults(sqlResult)) {
				itemId = SQL_ReadResult(sqlResult,0);
				itemAmount = SQL_ReadResult(sqlResult,1);
				SQL_ReadResult(sqlResult,2,itemName,31);
				
				formatex(shopName,31,"%i %i ^"%s^"",itemId,itemAmount,itemName);
				format(itemName,31,"%s - %i",itemName,itemAmount);
				
				menu_additem(menu,itemName,shopName,ADMIN_ALL);
				
				SQL_NextRow(sqlResult);
			}
			
			SQL_FreeHandle(sqlResult);
		}
		
		// Storage: Deposit Item Selected
		case 63: {
			formatex(shopName,31,"Deposit %s: x %i",playerCartName[id],playerCartAmount[id]);
			
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Deposit 1","1",ADMIN_ALL);
			if(playerCartAmount[id] >= 5)
				menu_additem(menu,"Deposit 5","5",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 1)
				menu_additem(menu,"Deposit 10","10",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 25)
				menu_additem(menu,"Deposit 25","25",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 50)
				menu_additem(menu,"Deposit 50","50",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 100)
				menu_additem(menu,"Deposit 100","100",ADMIN_ALL);
			
			menu_additem(menu,"Deposit All","all",ADMIN_ALL);
		}
		
		// Storage: Withdraw Item Selected
		case 64: {
			formatex(shopName,31,"Withdraw %s: x %i",playerCartName[id],playerCartAmount[id]);
			
			menu = menu_create(shopName, "menuShopHand");
			
			menu_additem(menu,"Withdraw 1","1",ADMIN_ALL);
			if(playerCartAmount[id] >= 5)
				menu_additem(menu,"Withdraw 5","5",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 1)
				menu_additem(menu,"Withdraw 10","10",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 25)
				menu_additem(menu,"Withdraw 25","25",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 50)
				menu_additem(menu,"Withdraw 50","50",ADMIN_ALL);
			
			if(playerCartAmount[id] >= 100)
				menu_additem(menu,"Withdraw 100","100",ADMIN_ALL);
			
			menu_additem(menu,"Withdraw All","all",ADMIN_ALL);
		}
		
		// Static Phone: Main Menu
		case 70: {
			
			formatex(shopName,31,"%s^nDialing: %s",playerShopName[id],evtPhoneNumber(playerCartName[id]));
			
			//menu_additem(menu,
		}
	}
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
	
	return PLUGIN_CONTINUE;
}

public menuShopHand(id, menu, item) {
	if(item == MENU_EXIT || !is_user_alive(id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	new data[64], origin[3], Float:fData;
	get_user_origin(id,origin);
	menu_item_getinfo(menu, item, dumbInt, data,63, dumbStr, 3, dumbInt);
	
	if(get_distance(origin,playerShopLoc[id]) > 100 && playerShopMenu[id] < 30) {
		client_print(id,print_chat,"You're too far away from the npc!");
		playerShopMenu[id] = 0;
		return PLUGIN_HANDLED;
	}
	
	switch(playerShopMenu[id]) {
		// Main Menu: Shop
		case 0: {
			if(equal(data,"shop")) {
				playerShopMenu[id] = 1;
				menuShop(id);
			}
			
			if(equal(data,"shoppro")) {
				SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players,grp_prop set grp_players.wallet=grp_players.wallet+grp_prop.profit,grp_prop.profit=0 where grp_players.id = %i and grp_players.id = grp_prop.propid",playerId[id]);
				
				client_print(id,print_chat,"Funds successfully collected!");
				menuShop(id);
			}

			if(equal(data,"shoprob")) {
				client_print(id,print_chat,"This is a TO DO.  Sorry for putting a stop to your malicious activities. xD");
				menuShop(id);
			}
		}
		
		// Shop Menu
		case 1: {
			new args[3][32];
			parse(data, args[0], 31, args[1], 31, args[2], 31);
			
			server_print(data);
			
			playerCartId[id] = str_to_num(args[0]);
			formatex(playerCartName[id],31,args[1]);
			playerCartPrice[id] = str_to_float(args[2]);
			
			playerShopMenu[id] = 2;
			menuShop(id);
		}
		
		// Confirm Item Amount Menu
		case 2: {
			if(playerCartAmount[id] < 1)
				playerCartAmount[id] = 1;
			
			new Float:total = playerCartAmount[id] * playerCartPrice[id];

			server_print("%i x $%f = %f",playerCartAmount[id],playerCartPrice[id],total);
			
			sqlResult = SQL_PrepareQuery(sqlConn,"select bank,wallet from grp_players where id = %i",playerId[id]);
			SQL_Execute(sqlResult);
			new Float:cash[2];
			SQL_ReadResult(sqlResult,0,cash[0]);
			SQL_ReadResult(sqlResult,1,cash[1]);
			SQL_FreeHandle(sqlResult);

			if(equal(data,"confirmd") && cash[0] >= total) {
				SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players,grp_prop set grp_players.bank=grp_players.bank-%.2f,grp_prop.profit=grp_prop.profit+%.2f where grp_players.id = %i and grp_prop.id = (select propid from grp_shops where id = %i)",total,total,playerId[id],playerShopId[id]);
				evtCreatePItem(id,playerCartId[id],playerCartAmount[id],"");
				playerShopMenu[id] = 0;
				menu_destroy(menu);
				return PLUGIN_HANDLED;
			}
			
			if(equal(data,"confirmc") && cash[1] >= total) {
				SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players,grp_prop set grp_players.bank=grp_players.bank-%.2f,grp_prop.profit=grp_prop.profit+%.2f where grp_players.id = %i and grp_prop.id = (select propid from grp_shops where id = %i)",total,total,playerId[id],playerShopId[id]);
				evtCreatePItem(id,playerCartId[id],playerCartAmount[id],"");
				playerShopMenu[id] = 0;
				menu_destroy(menu);
				return PLUGIN_HANDLED;
			}

			client_print(id,print_chat,"Insufficient funds to purchase.");
			menuShop(id);
		}
		
		// Main Menu: Bank Teller
		case 10: {
			if(equal(data,"deposit")) {
				if(playerCartPrice[id] <= 0.0) {
					playerShopMenu[id] = 11;
					menuShop(id);
				}
				else {
					SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank+%.2f,wallet=wallet-%.2f where id = %i and wallet >= %.2f",playerCartPrice[id],playerCartPrice[id],playerId[id],playerCartPrice[id]);
					client_print(id,print_chat,"Transaction complete.");
					playerShopMenu[id] = 0;
				}
			}
			
			else if(equal(data,"withdraw")) {
				if(playerCartPrice[id] <= 0.0) {
					playerShopMenu[id] = 12;
					menuShop(id);
				}
				else {
					SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank-%.2f,wallet=wallet+%.2f where id = %i and bank >= %.2f",playerCartPrice[id],playerCartPrice[id],playerId[id],playerCartPrice[id]);
					client_print(id,print_chat,"Transaction complete.");
					playerShopMenu[id] = 0;
				}
			}
		}
		
		// Bank Teller: Deposit
		case 11: {
			fData = str_to_float(data);
			SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank+%.2f,wallet=wallet-%.2f where id = %i and wallet >= %.2f",fData,fData,playerId[id],fData);
			client_print(id,print_chat,"Transaction complete.");
		}
		
		// Bank Teller: Withdraw
		case 12: {
			fData = str_to_float(data);
			SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank-%.2f,wallet=wallet+%.2f where id = %i and bank >= %.2f",fData,fData,playerId[id],fData);
			client_print(id,print_chat,"Transaction complete.");
		}
		
		// Main Menu: Bank ATM
		case 20: {
			if(equal(data,"deposit")) {
				if(playerCartPrice[id] <= 0.0) {
					playerShopMenu[id] = 21;
					menuShop(id);
				}
				else {
					SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank+%.2f,wallet=wallet-%.2f where id = %i and wallet >= %.2f",playerCartPrice[id],playerCartPrice[id],playerId[id],playerCartPrice[id]);
					client_print(id,print_chat,"Transaction complete.");
					playerShopMenu[id] = 0;
				}
			}
			
			else if(equal(data,"withdraw")) {
				if(playerCartPrice[id] <= 0.0) {
					playerShopMenu[id] = 22;
					menuShop(id);
				}
				else {
					SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank-%.2f,wallet=wallet+%.2f where id = %i and bank >= %.2f",playerCartPrice[id],playerCartPrice[id],playerId[id],playerCartPrice[id]);
					client_print(id,print_chat,"Transaction complete.");
					playerShopMenu[id] = 0;
				}
			}
		}
		
		// Bank ATM: Deposit
		case 21: {
			fData = str_to_float(data);
			SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank+%.2f,wallet=wallet-%.2f where id = %i and wallet >= %.2f",fData,fData,playerId[id],fData);
			client_print(id,print_chat,"Transaction complete.");
		}
		
		// Bank ATM: Withdraw
		case 22: {
			fData = str_to_float(data);
			SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank-%.2f,wallet=wallet+%.2f where id = %i and bank >= %.2f",fData,fData,playerId[id],fData);
			client_print(id,print_chat,"Transaction complete.");
		}
		
		// Inventory Main Menu
		case 30: {
			new args2[3][32];
			parse(data, args2[0], 31, args2[1], 31, args2[2], 31);
			
			playerCartId[id] = str_to_num(args2[0]);
			playerCartAmount[id] = str_to_num(args2[1]);
			formatex(playerCartName[id],31,"%s",args2[2]);
			
			playerShopMenu[id] = 31;
			menuShop(id);
			
		}
		
		// Inventory Item Selected
		case 31: {
			if(equal(data,"use")) {
				evtUseItem(id,playerCartId[id]);
			}
			
			if(equal(data,"usewith")) {
				playerShopMenu[id] = 35;
			}
			
			if(equal(data,"examine")) {
				sqlResult = SQL_PrepareQuery(sqlConn,"select grp_items.info from grp_curitems,grp_items where grp_curitems.id = %i and grp_curitems.itemid = grp_items.id",playerCartId[id]);
				SQL_Execute(sqlResult);
				new info[64];
				
				SQL_ReadResult(sqlResult,0,info,63);
				
				client_print(id,print_chat,info);
				
				SQL_FreeHandle(sqlResult);
			}
			
			if(equal(data,"give")) {
				playerShopMenu[id] = 33;
				menuShop(id);
			}
			
			if(equal(data,"drop")) {
				playerShopMenu[id] = 32;
				menuShop(id);
			}
			
			if(equal(data,"destroy")) {
				playerShopMenu[id] = 34;
				menuShop(id);
			}
			
			if(equal(data,"show")) {
				new showEntId
				
				get_user_aiming(id,showEntId,dumbInt,200);
				
				if(is_user_alive(showEntId)) {
					sqlResult = SQL_PrepareQuery(sqlConn,"select grp_items.name from grp_curitems,grp_items where grp_curitems.id = %i and grp_curitems.itemid = grp_items.id",playerCartId[id]);
					SQL_Execute(sqlResult);
					new name[32], showName[2][32];
					
					get_user_name(id,showName[0],31);
					get_user_name(showEntId,showName[1],31);
					
					SQL_ReadResult(sqlResult,0,name,31);
					
					client_print(showEntId,print_chat,"%s showed you their %s.",showName[0],name);
					client_print(id,print_chat,"You showed %s your %s.",showName[1],name);
					
					SQL_FreeHandle(sqlResult);
				}
				
			}
		}
		
		// Inventory Drop Amount
		case 32: {
			if(!equal(data,"all")) 
				playerCartAmount[id] = str_to_num(data);
			
			evtDropItem(id,playerCartId[id],playerCartAmount[id]);
		}
		
		// Inventory Give Amount
		case 33: {
			if(!equal(data,"all")) 
				playerCartAmount[id] = str_to_num(data);
			
			evtGiveItem(id,playerCartId[id],playerCartAmount[id]);
		}
		
		// Inventory Destroy Amount
		case 34: {
			if(!equal(data,"all")) 
				playerCartAmount[id] = str_to_num(data);
			
			evtDestroyItem(id,playerCartId[id],playerCartAmount[id],true);
		}
		
		// Inventory Use With
		case 35: {
			
		}
		
		// Property Confirm Buy
		case 40: {
			sqlResult = SQL_PrepareQuery(sqlConn,"select bank from grp_players where id = %i",playerId[id]);
			SQL_Execute(sqlResult);
			
			new Float:bank;
			SQL_ReadResult(sqlResult,0,bank);
			
			SQL_FreeHandle(sqlResult);
			
			if(bank >= playerCartPrice[id]) {
				SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank+%.2f where id = %i",playerCartPrice[id],playerCartAmount[id]);
				SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set bank=bank-%.2f where id = %i",playerCartPrice[id],playerId[id]);
				
				SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_prop set ownerid = %i,price = 0 where id = %i",playerId[id],playerCartId[id]);
				
				client_print(id,print_chat,"Property successfully purchased.");
			}
			else
				client_print(id,print_chat,"Insufficient funds to purchase.");
			
		}
		
		// Prodigy Main Menu
		case 50: {
			if(equal(data,"1")) 
				playerShopMenu[id] = 51;

			
			if(equal(data,"2")) 
				playerShopMenu[id] = 52;
			
			menuShop(id);
		}
		
		// Prodigy Withdraw List
		case 51: {
			new args3[3][32];
			parse(data, args3[0], 31, args3[1], 31, args3[2], 31);
			
			playerCartId[id] = str_to_num(args3[0]);
			playerCartAmount[id] = str_to_num(args3[1]);
			formatex(playerCartName[id],31,"%s",args3[2]);
			
			playerShopMenu[id] = 53;
			menuShop(id);
		}
		
		// Prodigy Deposit List
		case 52: {
			new args4[3][32];
			parse(data, args4[0], 31, args4[1], 31, args4[2], 31);
			
			playerCartId[id] = str_to_num(args4[0]);
			playerCartAmount[id] = str_to_num(args4[1]);
			formatex(playerCartName[id],31,"%s",args4[2]);
			
			playerShopMenu[id] = 54;
			menuShop(id);
		}
		
		// Prodigy Withdraw
		case 53: {
			if(!equal(data,"all")) 
				playerCartAmount[id] = str_to_num(data);
			evtWithdrawItem(id,playerCartId[id],playerCartAmount[id],1);
		}
		
		// Prodigy Deposit
		case 54: {
			if(!equal(data,"all")) 
				playerCartAmount[id] = str_to_num(data);
			evtDepositItem(id,playerCartId[id],playerCartAmount[id],1,playerId[id]);
		}
		
		// Stor-O-Matic Main Menu
		case 60: {
			if(equal(data,"1")) 
				playerShopMenu[id] = 61;

			
			if(equal(data,"2")) 
				playerShopMenu[id] = 62;
			
			menuShop(id);
		}
		
		// Stor-O-Matic Withdraw List
		case 61: {
			new args5[3][32];
			parse(data, args5[0], 31, args5[1], 31, args5[2], 31);
			
			playerCartId[id] = str_to_num(args5[0]);
			playerCartAmount[id] = str_to_num(args5[1]);
			formatex(playerCartName[id],31,"%s",args5[2]);
			
			playerShopMenu[id] = 63;
			menuShop(id);
		}
		
		// Stor-O-Matic Deposit List
		case 62: {
			new args7[3][32];
			parse(data, args7[0], 31, args7[1], 31, args7[2], 31);
			
			playerCartId[id] = str_to_num(args7[0]);
			playerCartAmount[id] = str_to_num(args7[1]);
			formatex(playerCartName[id],31,"%s",args7[2]);
			
			playerShopMenu[id] = 64;
			menuShop(id);
		}
		
		// Stor-O-Matic Withdraw
		case 63: {
			if(!equal(data,"all")) 
				playerCartAmount[id] = str_to_num(data);
			evtWithdrawItem(id,playerCartId[id],playerCartAmount[id],0);
		}
		
		// Stor-O-Matic Withdraw
		case 64: {
			if(!equal(data,"all")) 
				playerCartAmount[id] = str_to_num(data);
			evtDepositItem(id,playerCartId[id],playerCartAmount[id],0,playerShopId[id]);
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

/*
*	Items Section (SECTITEM)
*/

public itemMoney() {
	new args[3][16], id, amount, itemId, Float:cash;
	read_argv(1,args[0],15);
	read_argv(2,args[1],15);
	read_argv(3,args[2],15);
	
	id = str_to_num(args[0]);
	itemId = str_to_num(args[1]);
	amount = str_to_num(args[2]);
	
	cash = float(amount) / 100;
	
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"update grp_players set wallet=wallet+%.2f where id = %i",cash,playerId[id]);
	
	SQL_SimpleQueryFmt(sqlConn,dumbStr,3,dumbInt,"delete from grp_curitems where id = %i",itemId);
	
	client_print(id,print_chat,"You picked up $%.2f.",cash);
	
	return PLUGIN_HANDLED;
}

public itemFood() {
	new args[3][16], id, amount, itemId, health, itemName[32];
	read_argv(1,args[0],15);
	read_argv(2,args[1],15);
	read_argv(3,args[2],15);
	
	id = str_to_num(args[0]);
	itemId = str_to_num(args[1]);
	amount = str_to_num(args[2]);
	
	health = get_user_health(id);
	
	if(health >= 100)
		return PLUGIN_HANDLED;
	
	health = (amount+health > 100) ? 100 : amount+health;
	set_user_health(id,health);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select name from grp_items i, grp_curitems c where c.itemid = i.id and c.id = %i",itemId);
	SQL_Execute(sqlResult);
	
	SQL_ReadResult(sqlResult,0,itemName,31);
	
	SQL_FreeHandle(sqlResult);
	
	evtEmitAction(id,false,"has used a %s.",itemName);
	client_print(id,print_chat,"You have been healed from the %s.",itemName);
	
	evtDestroyItem(id,itemId,1,false);
	
	return PLUGIN_HANDLED;
}

public itemHealth() {
	new args[3][16], id, amount, itemId, health, itemName[32];
	read_argv(1,args[0],15);
	read_argv(2,args[1],15);
	read_argv(3,args[2],15);
	
	id = str_to_num(args[0]);
	itemId = str_to_num(args[1]);
	amount = str_to_num(args[2]);
	
	health = get_user_health(id);
	
	if(health >= 100)
		return PLUGIN_HANDLED;
	
	health = (amount+health > 100) ? 100 : amount+health;
	set_user_health(id,health);
	
	sqlResult = SQL_PrepareQuery(sqlConn,"select name from grp_items i, grp_curitems c where c.itemid = i.id and c.id = %i",itemId);
	SQL_Execute(sqlResult);
	
	SQL_ReadResult(sqlResult,0,itemName,31);
	
	SQL_FreeHandle(sqlResult);
	
	evtEmitAction(id,false,"has healed themself with a %s.",itemName);
	client_print(id,print_chat,"You have healed yourself with a %s.",itemName);
	
	evtDestroyItem(id,itemId,1,false);
	
	return PLUGIN_HANDLED;
}

public itemAlcohol() {
	
}

public itemPoison() {
	
}