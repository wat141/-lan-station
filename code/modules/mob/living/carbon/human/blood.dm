/****************************************************
				BLOOD SYSTEM
****************************************************/
//Blood levels
var/const/BLOOD_VOLUME_SAFE = 501
var/const/BLOOD_VOLUME_OKAY = 336
var/const/BLOOD_VOLUME_BAD = 224
var/const/BLOOD_VOLUME_SURVIVE = 82

/mob/living/carbon/human/var/datum/reagents/vessel	//Container for blood and BLOOD ONLY. Do not transfer other chems here.
/mob/living/carbon/human/var/pale = 0			//Should affect how mob sprite is drawn, but currently doesn't.

//Initializes blood vessels
/mob/living/carbon/human/proc/make_blood()

	if(vessel)
		return

	vessel = new/datum/reagents(600)
	vessel.my_atom = src

	vessel.add_reagent("blood",560)
	spawn(1)
		fixblood()

//Resets blood data
/mob/living/carbon/human/proc/fixblood()
	for(var/datum/reagent/blood/B in vessel.reagent_list)
		if(B.id == "blood")
			B.data = list("donor"=src,"viruses"=null,"blood_DNA"=dna.unique_enzymes,"blood_type"=dna.blood_type,"resistances"=null,"trace_chem"=null,"mind"=null,"ckey"=null,"gender"=null,"real_name"=null,"cloneable"=null,"factions"=null)

// Takes care blood loss and regeneration
/mob/living/carbon/human/proc/handle_blood()

	if(stat != DEAD && bodytemperature >= 170)	//Dead or cryosleep people do not pump the blood.

		var/blood_volume = round(vessel.get_reagent_amount("blood"))

		//Blood regeneration if there is some space
		if(blood_volume < 560 && blood_volume)
			var/datum/reagent/blood/B = locate() in vessel.reagent_list //Grab some blood
			if(B) // Make sure there's some blood at all
				if(B.data["donor"] != src) //If it's not theirs, then we look for theirs
					for(var/datum/reagent/blood/D in vessel.reagent_list)
						if(D.data["donor"] == src)
							B = D
							break

				B.volume += 0.2 // regenerate blood VERY slowly
				if (reagents.has_reagent("nutriment"))	//Getting food speeds it up
					B.volume += 0.8
					reagents.remove_reagent("nutriment", 0.1)
				if (reagents.has_reagent("iron"))	//Hematogen candy anyone?
					B.volume += 1.6
					reagents.remove_reagent("iron", 0.1)

		//Effects of bloodloss
		switch(blood_volume)
			if(BLOOD_VOLUME_SAFE to 10000)
				if(pale)
					pale = 0
					update_body()
			if(BLOOD_VOLUME_OKAY to BLOOD_VOLUME_SAFE)
				if(!pale)
					pale = 1
					update_body()
					var/word = pick("dizzy","woosey","faint")
					src << "\red You feel [word]"
				if(prob(1))
					var/word = pick("dizzy","woosey","faint")
					src << "\red You feel [word]"
					Paralyse(2)
				if(oxyloss < 20)
					oxyloss += 1
			if(BLOOD_VOLUME_BAD to BLOOD_VOLUME_OKAY)
				if(!pale)
					pale = 1
					update_body()
				eye_blurry += 6
				if(oxyloss < 40)
					oxyloss += 2
				oxyloss += 1.5
				if(prob(2.5))
					Paralyse(rand(1,8))
					var/word = pick("dizzy","woosey","faint")
					src << "\red You feel extremely [word]"
			if(BLOOD_VOLUME_SURVIVE to BLOOD_VOLUME_BAD)
				oxyloss += 4
				if(prob(2.5))
					var/word = pick("dizzy","woosey","faint")
					src << "\red You feel extremely [word]"
					Weaken(5)
			if(0 to BLOOD_VOLUME_SURVIVE)
				// There currently is a strange bug here. If the mob is not below -100 health
				// when death() is called, apparently they will be just fine, and this way it'll
				// spam deathgasp. Adjusting toxloss ensures the mob will stay dead.
				death()

		//Bleeding out
		for(var/obj/item/organ/limb/org in organs)
			var/brutedamage = org.brute_dam

			if(brutedamage > 30)
				bloodmax += 0.5
			if(brutedamage > 60)
				bloodmax += 0.5
			if(brutedamage > 80)
				bloodmax += 1

		if(bleedsuppress)
			bloodmax = 0
		drip(bloodmax)

/mob/living/carbon/human/proc/suppress_bloodloss(var/amount)
	if(bleedsuppress)
		return
	else
		bleedsuppress = 1
		spawn(amount)
			bleedsuppress = 0
			if(stat != DEAD)
				src << "<span class='warning'>Your bandage wears off.</span>"

//Makes a blood drop, leaking amt units of blood from the mob
/mob/living/carbon/human/proc/drip(var/amt as num)
	if(!amt) return
	var/blergh = 0

	vessel.remove_reagent("blood",amt)

	if(amt >= rand(1,10))
		blergh = 1

	blood_splatter(src,src,blergh)

/****************************************************
				BLOOD TRANSFERS
****************************************************/

//Gets blood from mob to the container, preserving all data in it.
/mob/living/carbon/proc/take_blood(obj/item/weapon/reagent_containers/container, var/amount)

	var/datum/reagent/B = get_blood(container.reagents)
	if(!B) B = new /datum/reagent/blood
	B.holder = container
	B.volume += amount

	//set reagent data
	B.data["donor"] = src

	/*
	if(T.virus && T.virus.spread_type != SPECIAL)
		B.data["virus"] = new T.virus.type(0)
	*/

	for(var/datum/disease/D in src.viruses)
		if(!B.data["viruses"])
			B.data["viruses"] = list()

		B.data["viruses"] += new D.type(0, D, 1)

	B.data["blood_DNA"] = copytext(src.dna.unique_enzymes,1,0)
	if(src.resistances&&src.resistances.len)
		B.data["resistances"] = src.resistances.Copy()
	var/list/temp_chem = list()
	for(var/datum/reagent/R in src.reagents.reagent_list)
		temp_chem += R.name
		temp_chem[R.name] = R.volume
	B.data["trace_chem"] = list2params(temp_chem)
	if(mind)
		B.data["mind"] = src.mind
	if(ckey)
		B.data["ckey"] = src.ckey
	if(!suiciding)
		B.data["cloneable"] = 1
	B.data["blood_type"] = copytext(src.dna.blood_type,1,0)
	B.data["gender"] = src.gender
	B.data["real_name"] = src.real_name
	return B

//For humans, blood does not appear from blue, it comes from vessels.
/mob/living/carbon/human/take_blood(obj/item/weapon/reagent_containers/container, var/amount)

	if(vessel.get_reagent_amount("blood") < amount)
		return null

	. = ..()
	vessel.remove_reagent("blood",amount) // Removes blood if human

//Transfers blood from container ot vessels
/mob/living/carbon/proc/inject_blood(obj/item/weapon/reagent_containers/container, var/amount)

	var/datum/reagent/blood/injected = get_blood(container.reagents)

	if(!injected)
		return

	var/list/chems = list()
	chems = params2list(injected.data["trace_chem"])
	for(var/C in chems)
		src.reagents.add_reagent(C, (text2num(chems[C]) / 560) * amount)//adds trace chemicals to owner's blood
	reagents.update_total()

	container.reagents.remove_reagent("blood", amount)

//Transfers blood from container ot vessels, respecting blood types compatability.
/mob/living/carbon/human/inject_blood(obj/item/weapon/reagent_containers/container, var/amount)

	var/datum/reagent/blood/injected = get_blood(container.reagents)

	var/datum/reagent/blood/our = get_blood(vessel)

	if (!injected || !our)
		return
	if(blood_incompatible(injected.data["blood_type"],our.data["blood_type"],injected.data["species"],our.data["species"]) )
		reagents.add_reagent("toxin",amount * 0.5)
		reagents.update_total()
	else
		vessel.add_reagent("blood", amount, injected.data)
		vessel.update_total()
	..()

//Gets human's own blood.
/mob/living/carbon/proc/get_blood(datum/reagents/container)
	var/datum/reagent/blood/res = locate() in container.reagent_list //Grab some blood
	if(res) // Make sure there's some blood at all
		if(res.data["donor"] != src) //If it's not theirs, then we look for theirs
			for(var/datum/reagent/blood/D in container.reagent_list)
				if(D.data["donor"] == src)
					return D
	return res

/mob/living/carbon/proc/blood_incompatible(donor,receiver,donor_species,receiver_species)
	if(!donor || !receiver) return 0

	if(donor_species && receiver_species)
		if(donor_species != receiver_species)
			return 1

	var/donor_antigen = copytext(donor,1,lentext(donor))
	var/receiver_antigen = copytext(receiver,1,lentext(receiver))
	var/donor_rh = (findtext(donor,"+")>0)
	var/receiver_rh = (findtext(receiver,"+")>0)

	if(donor_rh && !receiver_rh) return 1
	switch(receiver_antigen)
		if("A")
			if(donor_antigen != "A" && donor_antigen != "O") return 1
		if("B")
			if(donor_antigen != "B" && donor_antigen != "O") return 1
		if("O")
			if(donor_antigen != "O") return 1
		//AB is a universal receiver.
	return 0

/mob/living/carbon/proc/blood_splatter(var/target,var/datum/reagent/blood/source,var/large)

	var/obj/effect/decal/cleanable/blood/B
	var/decal_type = /obj/effect/decal/cleanable/blood/splatter
	var/turf/T = get_turf(target)

	if(istype(source,/mob/living/carbon/human))
		var/mob/living/carbon/human/M = source
		source = M.get_blood(M.vessel)
	else if(istype(source,/mob/living/carbon/monkey))
		var/mob/living/carbon/monkey/donor = source
		if(donor.dna)
			source = new()
			source.data["blood_DNA"] = donor.dna.unique_enzymes
			source.data["blood_type"] = donor.dna.blood_type

	// Are we dripping or splattering?
	if(!large)

		// Only a certain number of drips can be on a given turf.
		var/list/drips = list()
		var/list/drip_icons = list("1","2","3","4","5")

		for(var/obj/effect/decal/cleanable/blood/drip/drop in T)
			drips += drop
			drip_icons.Remove(drop.icon_state)

		// If we have too many drips, remove them and spawn a proper blood splatter.
		if(drips.len >= 5)
			//TODO: copy all virus data from drips to new splatter?
			for(var/obj/effect/decal/cleanable/blood/drip/drop in drips)
				qdel(drop)
		else
			decal_type = /obj/effect/decal/cleanable/blood/drip

	// Find a blood decal or create a new one.
	B = locate(decal_type) in T
	if(!B)
		B = new decal_type(T)

	// If there's no data to copy, call it quits here.
	if(!source)
		return B

	// Update blood information.
	if(source.data["blood_DNA"])
		B.blood_DNA = list()
		if(source.data["blood_type"])
			B.blood_DNA[source.data["blood_DNA"]] = source.data["blood_type"]
		else
			B.blood_DNA[source.data["blood_DNA"]] = "O+"

	return B