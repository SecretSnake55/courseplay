function courseplay.prerequisitesPresent(specializations)
	return true;
end

function courseplay:load(xmlFile)
	-- current number of waypoint
	self.recordnumber = 1
	self.lastrecordnumber = nil
	-- TODO what is this?
	self.tmr = 1
	-- waypoints are stored in here
	self.Waypoints = {}
	-- loaded/saved courses saved in here
	self.courses = {}
	-- TODO still needed?
	self.play = false
	-- TODO still needed?
	self.back = false 	
	-- total number of course players
	self.working_course_player_num = nil
	
	-- info text on tractor
	self.info_text = nil
	
	-- global info text - also displayed when not in vehicle
	self.global_info_text = nil
	
	-- course modes: 1 circle route - 2 returning route
	self.course_mode = 1
	
	-- ai mode: 1 abfahrer
	self.ai_mode = 1
	
	self.wait = true
	
	-- our arrow is displaying dirction to waypoints
	self.ArrowPath = Utils.getFilename("../aacourseplay/img/arrow.png", self.baseDirectory);
	self.ArrowOverlay = Overlay:new("Arrow", self.ArrowPath, 0.4, 0.08, 0.250, 0.250);
	self.ArrowOverlay:render()
	
	-- kegel der route	
	local baseDirectory = getAppBasePath()
	local i3dNode = Utils.loadSharedI3DFile("data/maps/models/objects/beerKeg/beerKeg.i3d", baseDirectory)
	local itemNode = getChildAt(i3dNode, 0)
	link(getRootNode(), itemNode)
	setRigidBodyType(itemNode, "NoRigidBody")
	setTranslation(itemNode, 0, 0, 0)
	setVisibility(itemNode, false)
	delete(i3dNode)
	self.sign = itemNode
	-- visual waypoints saved in this
	self.signs = {}
	
	-- course name for saving
	self.current_course_name = nil
	
	-- individual speed limit
	self.max_speed = nil
	
	-- traffic collision	
	self.onTrafficCollisionTrigger = courseplay.onTrafficCollisionTrigger;
	self.aiTrafficCollisionTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrafficCollisionTrigger#index"));
	
	self.numCollidingVehicles = 0;
	self.numToolsCollidingVehicles = {};
	
	
	-- tipTrigger
	self.findTipTriggerCallback = courseplay.findTipTriggerCallback;
	
	
	-- tippers
	self.tippers = {}
	self.tipper_attached = false	
	self.currentTrailerToFill = nil
	self.lastTrailerToFillDistance = nil
	self.unloaded = false	
	self.unloading_tipper = nil
	
	-- for user input like saving
	self.user_input_active = false
	self.user_input_message = nil
	self.user_input = nil
	self.save_name = false
	
	
	self.course_selection_active = false
	self.select_course = false
	self.selected_course_number = 0
	
	-- name search
	local aNameSearch = {"vehicle.name." .. g_languageShort, "vehicle.name.de", "vehicle.name.en", "vehicle.name", "vehicle#type"};
	
	for nIndex,sXMLPath in pairs(aNameSearch) do 
		self.name = getXMLString(xmlFile, sXMLPath);
		if self.name ~= nil then 
		break; 
		end;
	end;
	
	print("initialized courseplay for " .. self.name)
	
	-- loading saved courses from xml
	courseplay:load_courses(self)
end	

-- displays help text, user_input 	
function courseplay:draw()
	if not self.drive then
		if not self.record then		
			-- switch course mode
			if self.course_mode == 1 then
				g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayRound"), InputBinding.CourseMode);			      
			else
				g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayReturn"), InputBinding.CourseMode);			      
			end
			
			if InputBinding.hasEvent(InputBinding.CourseMode) then 
				if self.course_mode == 1 then
					self.course_mode = 0
				else
					self.course_mode = 1
				end
			end
			
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStart"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then 
				courseplay:start_record(self)
			end
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("PointRecordStop"), InputBinding.PointRecord);
			if InputBinding.hasEvent(InputBinding.PointRecord) then 
				courseplay:stop_record(self)
			end
	
			g_currentMission:addHelpButtonText(g_i18n:getText("CourseWaitpoint"), InputBinding.CourseWait);
			if InputBinding.hasEvent(InputBinding.CourseWait) then 
				courseplay:set_waitpoint(self)
			end
		end	
	end  
	
	if self.play then
		if not self.drive then 
			g_currentMission:addHelpButtonText(g_i18n:getText("CourseReset"), InputBinding.CourseReset);
			if InputBinding.hasEvent(InputBinding.CourseReset) then 
				courseplay:reset_course(self)
			end	
			
			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStart"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then 
				courseplay:start(self)
			end	
		else
			if self.wait then
				g_currentMission:addHelpButtonText(g_i18n:getText("CourseWaitpoinStart"), InputBinding.CourseWait);
			
				if InputBinding.hasEvent(InputBinding.CourseWait) then 
					self.wait = false
				end			
			end
			g_currentMission:addHelpButtonText(g_i18n:getText("CoursePlayStop"), InputBinding.CoursePlay);
			if InputBinding.hasEvent(InputBinding.CoursePlay) then 
				courseplay:stop(self)
			end
		end				
	end
	
	if self.dcheck and table.getn(self.Waypoints) > 1 then
		courseplay:dcheck(self);	  
	end
	
	
	if self.user_input_message then
		courseplay:user_input(self);
	end
	
	
	if self.course_selection_active then
		courseplay:display_course_selection(self);
	end
end	


-- is been called everey frame
function courseplay:update()
	-- show visual waypoints only when in vehicle
	if self.isEntered then
		courseplay:sign_visibility(self, true)
	else
		courseplay:sign_visibility(self, false)
	end
	
	-- we are in record mode
	if self.record then 
		courseplay:record(self);
	end	
	
	-- we are in drive mode
	if self.drive then
		courseplay:drive(self);
	end	
	
	courseplay:infotext(self);
end		

function courseplay:delete()
	if self.aiTrafficCollisionTrigger ~= nil then
		removeTrigger(self.aiTrafficCollisionTrigger);
	end	
end;	
