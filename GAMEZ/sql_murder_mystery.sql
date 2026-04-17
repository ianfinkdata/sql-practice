

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

select *, 'csr' as table_alias from crime_scene_report as csr;
select *, 'dl' as table_alias from drivers_license as dl;
select *, 'fb' as table_alias from facebook_event_checkin as fb;
select *, 'inv' as table_alias from interview as inv;
select *, 'gfn_member' as table_alias from get_fit_now_member as gfn_member;
select *, 'gfn_check_in' as table_alias from get_fit_now_check_in as gfn_check_in;
select *, 'sol' as table_alias from solution as sol;
select *, 'inc' as table_alias from income as inc;
select *, 'per' as table_alias from person as per;