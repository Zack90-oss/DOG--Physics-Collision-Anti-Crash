
DOG=DOG or {}

DOG.Name="Dog"

function DOG:Say(sentence)
	if(DOG.ACrash.Con_ChatEnabled:GetBool())then
		local msg = DOG.Name..": "..sentence
		PrintMessage(HUD_PRINTTALK, msg)
	end
end

DOG.ACrash = DOG.ACrash or {}
DOG.ACrash.CPS = 0
DOG.ACrash.CPSAll = 0
DOG.ACrash.CPTAll = 0

DOG.ACrash.NextWipe = 0
DOG.ACrash.NextStart = nil
DOG.ACrash.NextStart = CurTime() + 1
DOG.ACrash.NextMsg = 0
DOG.ACrash.NextMsgEffective = 0

DOG.ACrash.UnFreezeList = DOG.ACrash.UnFreezeList or {}

DOG.ACrash.Values=DOG.ACrash.Values or {}

--\\Old CPS method; unused
DOG.ACrash.Values["UnScrew"] = 680
DOG.ACrash.Values["Phys"] = 1100 + 100
DOG.ACrash.Values["Effective"] = 1250 + 100
DOG.ACrash.Values["CleanUp"] = 1300 + 100
DOG.ACrash.Values["Restart"] = 1400 + 100
DOG.ACrash.Values["EntPhys"] = 100

DOG.ACrash.CPSToCPTDivider = 1
--//

--\\New CPT method
DOG.ACrash.CPTValues = DOG.ACrash.CPTValues or {}

DOG.ACrash.CPTValues["UnScrew"] = 30
DOG.ACrash.CPTValues["Phys"] = 150
DOG.ACrash.CPTValues["Effective"] = 400
DOG.ACrash.CPTValues["CleanUp"] = 600
DOG.ACrash.CPTValues["Restart"] = 2000

DOG.ACrash.CPTValues["EntPhys"] = 20
--//

DOG.ACrash.Con_Enabled = CreateConVar("acdog_enabled", 1, bit.bor(FCVAR_ARCHIVE), "Enable/Disable Anti Crash system")
DOG.ACrash.Con_ExpEnabled = CreateConVar("acdog_experemental", 0, bit.bor(FCVAR_ARCHIVE), "Enable/Disable Experemental CPT accumulation(May start to freeze everything)")

DOG.ACrash.Con_FixValMul = CreateConVar("acdog_fixvaluesmul", 1, bit.bor(FCVAR_ARCHIVE), "Constant Mul, Do not screw up this one or you may suffer constant restarts", 0.5)

DOG.ACrash.Con_ChatEnabled = CreateConVar("acdog_chat", 1, bit.bor(FCVAR_ARCHIVE), "Enable/Disable Dog saying things in chat")

DOG.ACrash.Con_ViolatorChatEnabled = CreateConVar("acdog_violator_chat", 1, bit.bor(FCVAR_ARCHIVE), "Enable/Disable Dog saying whose props (may) violate the physics engine")

DOG.ACrash.ConVars = DOG.ACrash.ConVars or {}
for val, cpt in pairs(DOG.ACrash.CPTValues)do
	DOG.ACrash.ConVars[val] = CreateConVar("acdog_fixvalues_"..val, cpt, bit.bor(FCVAR_ARCHIVE), "Sets the minimum CPT required to trigger action "..val)
end

DOG.ACrash.Disabled = false

function DOG.ACrash:GetCPSConstantCompareMul()
	return ((DOG.ACrash.Con_ExpEnabled:GetBool() and 3.0) or 0) + DOG.ACrash.Con_FixValMul:GetFloat()
end

function DOG.ACrash:GetPhysMeshCount(phys)
	local mes = phys:GetMesh()
	if(mes)then
		return #phys:GetMesh()
	else
		return 1
	end
end

DOG.ACrash.CountFunc = function(ent,colldata)	
	
	if(!DOG or !DOG.ACrash.Con_Enabled:GetBool())then return nil end
	
	if (    not IsValid(ent)   )    then return nil end;
	if (    ent:IsPlayer()     )    then return nil end;
	if (    ent:IsNPC()        )    then return nil end;
	-- if (    ent:IsVehicle()    )    then return nil end;

	if(DOG.ACrash.NextStart)then return nil end
	
	if(DOG.ACrash.NextWipe and DOG.ACrash.NextWipe+1<CurTime())then
		DOG.ACrash.CPS=0
		DOG.ACrash.CPSAll=0
		DOG.ACrash.NextWipe=CurTime()
	end
	
	-- local addCPS = 1
	
	-- DOG.ACrash.CPS = DOG.ACrash.CPS + addCPS
	-- DOG.ACrash.CPSAll = DOG.ACrash.CPSAll + addCPS
	
	-- if(ent.DOGCPSNextWipe and (ent.DOGCPSNextWipe or 0)<=CurTime())then
		-- ent.DOGCPS = 0
		-- ent.DOGCPSNextWipe = CurTime() + 1
	-- end
	-- ent.DOGCPS = (ent.DOGCPS or 0) + addCPS
	
	local addCPT = 1
	
	if(DOG.ACrash.Con_ExpEnabled:GetBool() and IsValid(colldata.PhysObject))then
		addCPT = addCPT + 0.02 * math.max(DOG.ACrash:GetPhysMeshCount(colldata.PhysObject), 60)
	end
	
	local CPTMul = DOG.ACrash:GetCPSConstantCompareMul()
	
	if(DOG.ACrash.LastCPTWipe!=CurTime())then
		DOG.ACrash.LastCPTWipe = CurTime()
		DOG.ACrash.CPT = 0
		DOG.ACrash.CPTAll = 0
	end
	
	DOG.ACrash.CPT = DOG.ACrash.CPT + addCPT
	DOG.ACrash.CPTAll = DOG.ACrash.CPTAll + addCPT
	
	-- if(DOG.ACrash.CPS>DOG.ACrash.Values["UnScrew"])then
	if(DOG.ACrash.CPT > ((DOG.ACrash.ConVars["UnScrew"]:GetFloat() * CPTMul) / DOG.ACrash.CPSToCPTDivider))then
		local phy = ent:GetPhysicsObject();
		
		local freezeme = false
		
		if(DOG.ACrash.CPT > ((DOG.ACrash.ConVars["EntPhys"]:GetFloat() * CPTMul) / DOG.ACrash.CPSToCPTDivider) and !ent.DOGNextUnFreeze)then
			freezeme = true
		end
		
		if(ent:GetClass() == "prop_ragdoll")then
			for i = 0, ent:GetPhysicsObjectCount() - 1 do
				local phy = ent:GetPhysicsObjectNum( i )
				if ( IsValid( phy ) ) then
					ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
					
					if(freezeme)then
						ent.DOGWasFreezed = ent.DOGWasFreezed or phy:IsMotionEnabled()
						phy:EnableMotion( false )
					end
				else
					SafeRemoveEntityDelayed(ent,0)
					break
				end
			end
			
			if(freezeme)then
				ent.DOGNextUnFreeze = CurTime() + 20
				DOG.ACrash.UnFreezeList[#DOG.ACrash.UnFreezeList + 1] = ent
			end
		else
			if ( IsValid( phy ) ) then
				ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				-- if(ent.DOGCPS > DOG.ACrash.Values["EntPhys"] and !ent.DOGNextUnFreeze)then
				if(freezeme)then
					ent.DOGWasFreezed = phy:IsMotionEnabled()
					ent.DOGNextUnFreeze = CurTime() + 10
					phy:EnableMotion( false )
					DOG.ACrash.UnFreezeList[#DOG.ACrash.UnFreezeList+1] = ent
				end
			else
				SafeRemoveEntityDelayed(ent,0)
			end
		end
		if(DOG.ACrash.NextMsg < CurTime())then
			DOG.ACrash.NextMsg = CurTime() + 10
			DOG:Say("Something trying to screw up the server, unscrewing")
		end

	end
	
	if(DOG.ACrash.CPT > ((DOG.ACrash.ConVars["Phys"]:GetFloat() * CPTMul) / DOG.ACrash.CPSToCPTDivider))then
		RunConsoleCommand("phys_timescale", 0)
		DOG.ACrash.NextEnablePhysics = CurTime() + 50
		cookie.Set("dog_physdisabled",1)
		
		DOG:Say("Not enough. Disabling physics")
		DOG.ACrash.CPS=0
		DOG.ACrash.CPT=0
	end
	
	if(DOG.ACrash.CPTAll > ((DOG.ACrash.ConVars["Effective"]:GetFloat() * CPTMul) / DOG.ACrash.CPSToCPTDivider))then
		SafeRemoveEntityDelayed(ent,0)
		
		if(DOG.ACrash.NextMsgEffective<CurTime())then
			DOG.ACrash.NextMsgEffective = CurTime() + 10
			DOG:Say("Trying effective means")
		end	
	end
	
	if(DOG.ACrash.CPTAll > ((DOG.ACrash.ConVars["CleanUp"]:GetFloat() * CPTMul) / DOG.ACrash.CPSToCPTDivider) and DOG.LastCleanUpTime!=CurTime())then
		-- DOG:Say("Cleaning up")
		DOG:Say("Cleaning up")
		DOG.LastCleanUpTime = CurTime()
		timer.Simple(0,function()
			game.CleanUpMap()
		end)
	end
	
	if(DOG.ACrash.CPTAll > ((DOG.ACrash.ConVars["Restart"]:GetFloat() * CPTMul) / DOG.ACrash.CPSToCPTDivider))then
		DOG:Say("Restarting")
		--DOG.ACrash.CPSAll=0
		RunConsoleCommand("changelevel",game.GetMap())
	end		
end

hook.Add("OnEntityCreated","DOG",function(ent)
	if(SERVER)then
		if(ent.PhysicsCollide)then
			ent.OldPhysicsCollide=ent.OldPhysicsCollide or ent.PhysicsCollide
			function ent:PhysicsCollide(cd,col)
				ent:OldPhysicsCollide(cd,col)
				DOG.ACrash.CountFunc(self,cd)
			end
		else
			ent:AddCallback( "PhysicsCollide",DOG.ACrash.CountFunc)
		end
	end
end)

if(cookie.GetNumber("dog_physdisabled",0) == 1)then
	RunConsoleCommand("phys_timescale", 1)
end

hook.Add("PostCleanupMap","DOG_AC",function()
	DOG.ACrash.NextStart = CurTime() + 1
end)

hook.Add("Think","DOG_AC",function()
	if(((DOG.ACrash.NextEnablePhysics and DOG.ACrash.NextEnablePhysics<CurTime()) or !DOG.ACrash.NextEnablePhysics) and cookie.GetNumber("dog_physdisabled",0)==1)then
		RunConsoleCommand("phys_timescale", 1)
		DOG.ACrash.NextEnablePhysics = nil
		cookie.Set("dog_physdisabled",0)
	end
	
	if(DOG.ACrash.NextStart and DOG.ACrash.NextStart<=CurTime())then
		DOG.ACrash.NextStart=nil
	end
	
	if(!DOG.ACrash.NextPropUnFreeze or DOG.ACrash.NextPropUnFreeze<=CurTime())then
		DOG.ACrash.NextPropUnFreeze = CurTime() + 5
		for id,ent in pairs(DOG.ACrash.UnFreezeList)do
			if(IsValid(ent) and ent.DOGNextUnFreeze)then
				if(ent.DOGNextUnFreeze<=CurTime())then
					if(ent:GetClass() == "prop_ragdoll")then
						for i = 0, ent:GetPhysicsObjectCount() - 1 do
							local phy = ent:GetPhysicsObjectNum( i )
							if ( IsValid( phy ) ) then
								phy:EnableMotion( ent.DOGWasFreezed or true )
								ent.DOGWasFreezed = nil
							end
						end
					else
						if ( IsValid( phy ) ) then
							phy:EnableMotion( ent.DOGWasFreezed or true )
							ent.DOGWasFreezed = nil
						end
					end
				end
			else
				DOG.ACrash.UnFreezeList[id] = nil
			end
		end
	end
end)