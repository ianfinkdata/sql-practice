/*
A crime has taken place and the detective needs your help. 
The detective gave you the crime scene report, but you somehow lost it. 
You vaguely remember that the crime was 
a ​murder​ that occurred sometime on ​Jan.15, 2018​ 
and that it took place in ​SQL City​. 
Start by retrieving the corresponding crime scene report 
from the police department’s database.
*/

/* ## Tables

crime_scene_report as csr
drivers_license as dl
facebook_event_checkin as fb
interview as inv
get_fit_now_member as gfn_member
get_fit_now_check_in as gfn_check_in
solution as sol
income as inc
person as per

*/

with csr as (
select * from crime_scene_report 
where type = 'murder'
and city like 'SQL%'
and date = 20180115
)

select * from csr
;
/* ----------
date: 20180115	type: murder	description:	
Security footage shows that there were 2 witnesses. 
The first witness lives at the last house on "Northwestern Dr". 
The second witness, named Annabel, lives somewhere on "Franklin Ave".	
city: SQL City


-----------*/


with csr as (
select * from crime_scene_report 
where type = 'murder'
and city like 'SQL%'
and date = 20180115
),


/*
date: 20180115	
type: murder	
description:

Security footage shows that there were 2 witnesses. 

The first witness lives at the last house on "Northwestern Dr".

The second witness, named Annabel, lives somewhere on "Franklin Ave".

city: SQL City


select * from person 
where lower(address_street_name) 
like 'northwestern%' 
order by address_number desc
;

*/

witness1 as (
select *
from person 
where ssn = 111564949 
),

witness2 as (
select *
from person 
where ssn = 318771143 
)


select *, 1 as witness from witness1
union all
select *, 2 as witness from witness2
order by witness --  address_street_name, address_number
;

/*
id	    name	            license_id	        address_number	address_street_name	        ssn	        witness

14887	Morty Schapiro	118009	                    4919	        Northwestern Dr	    111564949	        1
16371	Annabel Miller	490173	                    103	            Franklin Ave	    318771143	        2

*/


select p.name, i.* 
from interview as i 
join person as p on i.person_id = p.id
where i.person_id in (14887, 16371)

/*
name	person_id	transcript
Morty Schapiro	14887	I heard a gunshot and then saw a man run out. He had a "Get Fit Now Gym" bag. The membership number on the bag started with "48Z". Only gold members have those bags. The man got into a car with a plate that included "H42W".
Annabel Miller	16371	I saw the murder happen, and I recognized the killer from my gym when I was working out last week on January the 9th.
*/

select gfm.id, gfm.person_id, gfm.name, gfm.membership_start_date 
from get_fit_now_member as gfm
where gfm.membership_status = 'gold'
and (gfm.id like '48Z%' or gfm.d = 90081)
order by gfm.membership_start_date
;

/*
id	person_id	name	membership_start_date
48Z55	67318	Jeremy Bowers	20160101
90081	16371	Annabel Miller	20160208
48Z7A	28819	Joe Germuska	20160305
*/

select * from get_fit_now_check_in 
where membership_id in ('48Z55','48Z7A','90081');

/*
membership_id	check_in_date	check_in_time	check_out_time
48Z55	20180109	1530	1700
90081	20180109	1600	1700
48Z7A	20180109	1600	1730
*/

select * from facebook_event_checkin 
where 
-- date = 20180109
-- and 
person_id in (67318,16371,28819);

/*
person_id	event_id	event_name	date
16371	4719	The Funky Grooves Tour	20180115
67318	4719	The Funky Grooves Tour	20180115
67318	1143	SQL Symphony Concert	20171206
*/


select * from interview where person_id in (67318, 28819);

/*
person_id	transcript
67318	
I was hired by a woman with a lot of money. 
I don't know her name but I know she's around 5'5" (65") or 5'7" (67"). 
She has red hair and she drives a Tesla Model S. 
I know that she attended the SQL Symphony Concert 3 times in December 2017. 
*/

select * from drivers_license 
where height between 65 and 67
and gender = 'female'
and hair_color = 'red'
and car_make = 'Tesla'
;

-- left off 
/*
id	age	height	eye_color	hair_color	gender	plate_number	car_make	car_model
202298	68	66	green	red	female	500123	Tesla	Model S
291182	65	66	blue	red	female	08CM64	Tesla	Model S
918773	48	65	black	red	female	917UU3	Tesla	Model S
*/
