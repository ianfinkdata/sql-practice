

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
