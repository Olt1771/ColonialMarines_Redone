/*
	Click code cleanup
	~Sayu
*/

// 1 decisecond click delay (above and beyond mob/next_move)
/mob/var/next_click	= 0

/*
	Before anything else, defer these calls to a per-mobtype handler.  This allows us to
	remove istype() spaghetti code, but requires the addition of other handler procs to simplify it.

	Alternately, you could hardcode every mob's variation in a flat ClickOn() proc; however,
	that's a lot of code duplication and is hard to maintain.

	Note that this proc can be overridden, and is in the case of screen objects.
*/
/atom/Click(location,control,params)
	usr.ms_last_pos = src
	usr.ClickOn(src, params)
/atom/DblClick(location,control,params)
	usr.ms_last_pos = src
	usr.DblClickOn(src,params)

/*
	Standard mob ClickOn()
	Handles exceptions: Buildmode, middle click, modified clicks, mech actions

	After that, mostly just check your state, check whether you're holding an item,
	check whether you're adjacent to the target, then pass off the click to whoever
	is recieving it.
	The most common are:
	* mob/UnarmedAttack(atom,adjacent) - used here only when adjacent, with no item in hand; in the case of humans, checks gloves
	* atom/attackby(item,user) - used only when adjacent
	* item/afterattack(atom,user,adjacent,params) - used both ranged and adjacent
	* mob/RangedAttack(atom,params) - used only ranged, only used for tk and laser eyes but could be changed
*/
/mob/proc/ClickOn( atom/A, params )
	if(world.time <= next_click)
		return
	next_click = world.time + 1
	if(client.buildmode)
		build_click(src, client.buildmode, params, A)
		return

	var/obj/item/W = get_active_hand()

	var/list/modifiers = params2list(params)
	if(modifiers["shift"] && modifiers["ctrl"])
		CtrlShiftClickOn(A)
		return
	if(modifiers["middle"])
		MiddleClickOn(A)
		return
	if(modifiers["shift"])
		ShiftClickOn(A)
		return
	if(modifiers["alt"]) // alt and alt-gr (rightalt)
		AltClickOn(A)
		return
	if(modifiers["ctrl"])
		if(W == A)
			W.ctrl_self(src)
			if(hand)
				update_inv_l_hand(0)
			else
				update_inv_r_hand(0)
		else
			CtrlClickOn(A)
		return

	if(stat || paralysis || stunned || weakened)
		return

	face_atom(A)

	if(next_move > world.time) // in the year 2000...
		return

	if(istype(loc,/obj/mecha))
		var/obj/mecha/M = loc
		return M.click_action(A,src)

	if(restrained())
		changeNext_move(CLICK_CD_HANDCUFFED)   //Doing shit in cuffs shall be vey slow
		RestrainedClickOn(A)
		return

	if(in_throw_mode)
		throw_item(A)
		return



	if(W == A)
		W.attack_self(src)
		if(hand)
			update_inv_l_hand(0)
		else
			update_inv_r_hand(0)
		return

	// operate three levels deep here (item in backpack in src; item in box in backpack in src, not any deeper)
	if(!isturf(A) && A == loc || (A in contents) || (A.loc in contents) || (A.loc && (A.loc.loc in contents)))
		// No adjacency needed
		if(W)
			var/resolved = A.attackby(W,src)
			if(!resolved && A && W)
				W.afterattack(A,src,1,params) // 1 indicates adjacency
		else
			if(ismob(A))
				changeNext_move(CLICK_CD_MELEE)
			UnarmedAttack(A)
		return

	if(!isturf(loc)) // This is going to stop you from telekinesing from inside a closet, but I don't shed many tears for that
		return

	// Allows you to click on a box's contents, if that box is on the ground, but no deeper than that
	if(isturf(A) || isturf(A.loc) || (A.loc && isturf(A.loc.loc)))
		if(A.Adjacent(src)) // see adjacent.dm
			if(W)
				// Return 1 in attackby() to prevent afterattack() effects (when safely moving items for example)
				var/resolved = A.attackby(W,src,params)
				if(!resolved && A && W)
					W.afterattack(A,src,1,params) // 1: clicking something Adjacent
			else
				if(ismob(A))
					changeNext_move(CLICK_CD_MELEE)
				UnarmedAttack(A, 1)
			return
		else // non-adjacent click
			if(W)
				W.afterattack(A,src,0,params) // 0: not Adjacent
			else
				RangedAttack(A, params)

/mob/proc/changeNext_move(num)
	next_move = world.time + num

// Default behavior: ignore double clicks (the second click that makes the doubleclick call already calls for a normal click)
/mob/proc/DblClickOn(atom/A, params)
	return


/*
	Translates into attack_hand, etc.

	Note: proximity_flag here is used to distinguish between normal usage (flag=1),
	and usage when clicking on things telekinetically (flag=0).  This proc will
	not be called at ranged except with telekinesis.

	proximity_flag is not currently passed to attack_hand, and is instead used
	in human click code to allow glove touches only at melee range.
*/
/mob/proc/UnarmedAttack(atom/A, proximity_flag)
	if(ismob(A))
		changeNext_move(CLICK_CD_MELEE)
	return

/*
	Ranged unarmed attack:

	This currently is just a default for all mobs, involving
	laser eyes and telekinesis.  You could easily add exceptions
	for things like ranged glove touches, spitting alien acid/neurotoxin,
	animals lunging, etc.
*/
/mob/proc/RangedAttack(atom/A, params)
/*
	Restrained ClickOn

	Used when you are handcuffed and click things.
	Not currently used by anything but could easily be.
*/
/mob/proc/RestrainedClickOn(atom/A)
	return

/*
	Middle click
	Only used for swapping hands
*/
/mob/proc/MiddleClickOn(atom/A)
	return

/mob/living/carbon/MiddleClickOn(atom/A)
	if(!src.stat && src.mind && src.mind.changeling && src.mind.changeling.chosen_sting && (istype(A, /mob/living/carbon)) && (A != src))
		next_click = world.time + 5
		mind.changeling.chosen_sting.try_to_sting(src, A)
	else
		swap_hand()

/mob/living/simple_animal/drone/MiddleClickOn(atom/A)
	swap_hand()

// In case of use break glass
/*
/atom/proc/MiddleClick(mob/M as mob)
	return
*/

/*
	Shift click
	For most mobs, examine.
	This is overridden in ai.dm
*/
/mob/proc/ShiftClickOn(atom/A)
	if(isturf(A) || isobj(A)) // Used as hotkey for pumping shotgun and makes that we can still examine mobs.
		var/obj/item/weapon/gun/projectile/shotgun/O = src.get_active_hand()
		if(istype(O))
			O.attack_pump(src)
			return
	A.ShiftClick(src)
	return
/atom/proc/ShiftClick(mob/user)
	if(user.client && user.client.eye == user || user.client.eye == user.loc)
		user.examinate(src)
	return

/*
	Ctrl click
	For most objects, pull
*/
/mob/proc/CtrlClickOn(atom/A)
	A.CtrlClick(src)
	return
/atom/proc/CtrlClick(mob/user)
	return

/atom/movable/CtrlClick(mob/user)
	if(Adjacent(user))
		user.start_pulling(src)

/*
	Alt click
	Unused except for AI
*/
/mob/proc/AltClickOn(atom/A)
	A.AltClick(src)
	return

/mob/living/carbon/AltClickOn(atom/A)
	if(!src.stat && src.mind && src.mind.changeling && src.mind.changeling.chosen_sting && (istype(A, /mob/living/carbon)) && (A != src))
		next_click = world.time + 5
		mind.changeling.chosen_sting.try_to_sting(src, A)
	else
		..()

/atom/proc/AltClick(mob/user)
	var/turf/T = get_turf(src)
	if(T && user.TurfAdjacent(T))
		if(user.listed_turf == T)
			user.listed_turf = null
		else
			user.listed_turf = T
			user.client.statpanel = T.name
	return

/mob/proc/TurfAdjacent(turf/T)
	return T.Adjacent(src)

/*
	Control+Shift click
	Unused except for AI
*/
/mob/proc/CtrlShiftClickOn(atom/A)
	A.CtrlShiftClick(src)
	return

/atom/proc/CtrlShiftClick(mob/user)
	return

/*
	Misc helpers

	Laser Eyes: as the name implies, handles this since nothing else does currently
	face_atom: turns the mob towards what you clicked on
*/
/mob/proc/LaserEyes(atom/A)
	return

/mob/living/LaserEyes(atom/A)
	changeNext_move(CLICK_CD_RANGE)
	var/turf/T = get_turf(src)
	var/turf/U = get_turf(A)

	var/obj/item/projectile/beam/LE = new /obj/item/projectile/beam( loc )
	LE.icon = 'icons/effects/genetics.dmi'
	LE.icon_state = "eyelasers"
	playsound(usr.loc, 'sound/weapons/taser2.ogg', 75, 1)

	LE.firer = src
	LE.def_zone = get_organ_target()
	LE.original = A
	LE.current = T
	LE.yo = U.y - T.y
	LE.xo = U.x - T.x
	LE.fire()

/mob/living/carbon/human/LaserEyes()
	if(nutrition>0)
		..()
		nutrition = max(nutrition - rand(1,5),0)
	else
		src << "<span class='danger'>You're out of energy!  You need food!</span>"

// Simple helper to face what you clicked on, in case it should be needed in more than one place
/mob/proc/face_atom(atom/A)
	if( buckled || stat != CONSCIOUS || !A || !x || !y || !A.x || !A.y ) return
	var/dx = A.x - x
	var/dy = A.y - y
	if(!dx && !dy) // Wall items are graphically shifted but on the floor
		if(A.pixel_y > 16)		dir = NORTH
		else if(A.pixel_y < -16)dir = SOUTH
		else if(A.pixel_x > 16)	dir = EAST
		else if(A.pixel_x < -16)dir = WEST
		return

	if(abs(dx) < abs(dy))
		if(dy > 0)	dir = NORTH
		else		dir = SOUTH
	else
		if(dx > 0)	dir = EAST
		else		dir = WEST

/obj/screen/click_catcher
	icon = 'icons/mob/screen_full.dmi'
	icon_state = "passage0"
	layer = 0
	mouse_opacity = 2
	screen_loc = "CENTER-7,CENTER-7"

/obj/screen/click_catcher/Click(location, control, params)
	var/list/modifiers = params2list(params)
	if(modifiers["middle"] && istype(usr, /mob/living/carbon))
		var/mob/living/carbon/C = usr
		C.swap_hand()
	else
		var/turf/T = screen_loc2turf(modifiers["screen-loc"], get_turf(usr))
		usr.ms_last_pos = T
		T.Click(location, control, params)
	return 1

//Hold to shoot code below, for full-auto weapons.
//Not sure if this is finished or WIP.
/mob
	var/mouse_hold = 0
	var/fire_in_process = 0

/atom/MouseDown(location,control,params)
	var/list/modifiers = params2list(params)
	if(modifiers["left"]) // Without this check - middle button will be used too, and we don't want that.
		var/obj/item/weapon/gun/W = usr.get_active_hand()
		//We need mouse hold to work at exact scenario and if not passed, then click() will be used instead.
		//Not sure if all this necessary, but works as needed.
		if((usr.a_intent != "harm") && istype(W) && isturf(usr.loc) && !(W == src) && !usr.client.buildmode && !usr.restrained() && !usr.in_throw_mode && (W.fire_delay > 0) && (W.burst_size < 2) && !istype(src, /obj/screen))
			if((isobj(src) || ismob(src)) && !isturf(src.loc))
				return
			if(!usr.mouse_hold)
				usr.mouse_hold = 1

				var/target = src

				if(!W.smart_weapon)
					if(isliving(src))
						var/mob/living/L = src
						if((L.health > 0) && !L.lying) // We don't need auto aim if target alive and not lying, so player will be forced
							target = get_turf(src) // to release LMB and click again, to correct his aim. (When shooting at moving target).
				usr.ms_last_pos = target
				usr.ClickOnHold(target, params)

/mob
	var/ms_last_pos = null

/atom/MouseDrag(atom/A)
	if(isliving(usr))
		var/mob/living/L = usr
		if(ismob(A) || isturf(A) || isobj(A))
			L.ms_last_pos = A

/atom/MouseUp(location,control,params)
	usr.mouse_hold = 0

/mob/proc/ClickOnHold( atom/A, params )
	if(fire_in_process)
		return

	while(mouse_hold)
		var/obj/item/weapon/gun/W = get_active_hand()
		spawn()
			if(!istype(W))
				mouse_hold = 0
				return

			if(!src || !A)
				mouse_hold = 0
				return

			fire_in_process = 1
			if(!istype(W))
				mouse_hold = 0
				return

			if((isobj(A) || ismob(A)) && !isturf(A.loc))
				mouse_hold = 0
				return

			if(!isturf(loc) || restrained() || in_throw_mode || (a_intent == "harm") || (W.burst_size > 1)) // Who knows, what can happen when we hold button.
				mouse_hold = 0
				return

			if(stat || paralysis || stunned || weakened) // Not sure if i want very long lines of ORs.
				mouse_hold = 0
				return

			if(!W.chambered) // Probably can go in previous ORs chain.
				mouse_hold = 0
				return

			if(ms_last_pos)
				face_atom(ms_last_pos)
				if(isliving(ms_last_pos))
					var/mob/living/L = ms_last_pos
					if((L.health > 0) && !L.lying)
						W.afterattack(get_turf(ms_last_pos),src,0,params)
					else
						W.afterattack(ms_last_pos,src,0,params)
				if(isobj(ms_last_pos))
					W.afterattack(istype(ms_last_pos, /obj/item/clothing/mask/facehugger) ? ms_last_pos : get_turf(ms_last_pos),src,0,params)
				else
					W.afterattack(ms_last_pos,src,0,params)
			else
				face_atom(A)
				W.afterattack(A,src,0,params)

		sleep(W.fire_delay ? W.fire_delay : 10)
		fire_in_process = 0

