-- COMP3311 20T3 Assignment 2

-- Q1: students who've studied many courses

create view Q1(unswid,name)
as
select p.unswid, p.name
from people p
where p.id in
(select c.student 
from course_enrolments c
group by c.student
having count(course) > 65
)
;

-- Q2: numbers of students, staff and both


-- Q2 helper views
create or replace view Q2_f1 as(
select count(s.id)
from students s, staff 
where s.id = staff.id
)
;
create or replace view Q2_f2 as(
select count(s.id) 
from students s
)
;
create or replace view Q2_f3 as(
select count(staff.id) as count
from staff
)
;

-- Q2
create or replace view Q2(nstudents,nstaff,nboth)
as
select  Q2_f2.count - Q2_f1.count as nstudents, Q2_f3.count- Q2_f1.count as nstaff, Q2_f1.count as nboth
from Q2_f2, Q2_f3,Q2_f1
;

-- Q3: prolific Course Convenor(s)

create or replace view Q3_f1 as
with LICcode as (select id from staff_roles as c where c.name = 'Course Convenor')
select a.staff,count(*)
from course_staff as a
join courses as b on (a.course = b.id)
where a.role = (select id from LICcode)
group by a.staff
;


create or replace view Q3(name,ncourses)
as
with Most as(
select *
from Q3_f1
where Q3_f1.count = (select max(count) from Q3_f1)
)
select p.name, Most.count
from people p, Most
where p.id = Most.staff
;

-- Q4: Comp Sci students in 05s2 and 17s1

create or replace view Q4a(id,name)
as
select unswid , name
from people p
where p.id in (
with b as (select id from programs as p where p.code = '3978'),
c as (select id from terms as t where year = '2005' and session = 'S2')
select student
from program_enrolments as a
where a.program = (select id from b)
and a.term = (select id from c)
)
;

create or replace view Q4b(id,name)
as
select unswid , name
from people p
where p.id in (
with b as (select id from programs as p where p.code = '3778'),
c as (select id from terms as t where year = '2017' and session = 'S1')
select student
from program_enrolments as a
where a.program = (select id from b)
and a.term = (select id from c)
)
;


-- Q5: most "committee"d faculty

create or replace view Q5(name)
as
with a as (
select facultyOf(o.id)
from orgunits o
where o.utype = 9
),
b as (
select a.facultyOf, count(*)
from a
where a is not null
group by facultyOf
)
select o.name
from b, orgunits o
where b.count = (select max(count) from b)
and b.facultyOf = o.id
;

-- Q6: nameOf function

create or replace function
   Q6(id_input integer) returns text
as $$
    select p.name 
    from people p
    where p.id = id_input or p.unswid = id_input;
$$ language sql;

-- Q7: offerings of a subject

create or replace function
   Q7(s text) 
    returns table (subject text, term text, convenor text)
as $$

with a as (
select id, code
from subjects
where code = s
),
c as (select id from staff_roles as c where c.name = 'Course Convenor'),
d as (
select c1.staff , c2.term
from course_staff c1 join courses c2  on (c2.id = c1.course)
where c1.role = (select id from c)
and c2.subject = (select id from a)
)
select a.code::text , termname(d.term), p.name
from d, people p, a
where p.id = d.staff
 
$$ language sql;

-- Q8: transcript

--find 
create or replace function
   Q8_f1(_course integer) returns text
as $$
declare
    _subject integer;
    _code text;
begin
    
    select subject into _subject
    from courses
    where id = _course;
    
    select code into _code 
    from subjects
    where id = _subject;
    
    return _code;


end;
$$ language plpgsql;

create or replace function
   Q8(zid integer) returns setof TranscriptRecord
as $$
declare
    _result TranscriptRecord;
    _id integer;
    _weightedSumOfMarks float := 0;
    _total_uoc integer := 0;    
    _total_uoc_attempted float := 0;
    
    
    _course integer;
    _subject integer;
    _term integer;
    _program integer;
    _uoc integer;
    _mark integer;
begin
    select id into _id from people where unswid = zid;
    if (not found) then
        raise exception 'Invalid student %', zid;
    end if;

    for _course in (
    select course 
    from course_enrolments c
    where student = _id
    order by (select term from courses co where c.course = co.id),
    (Q8_f1(course)) asc
    ) loop
        select grade ,mark into _result.grade, _result.mark
        from course_enrolments 
        where student = _id
        and course = _course;
        
        select subject , term into _subject, _term
        from courses
        where id = _course;
        _result.term := termname(_term);
        
        select code , substring(name from 1 for 20) , uoc into _result.code, _result.name , _uoc
        from subjects
        where id = _subject;
        
        if (_result.grade in ('SY', 'PT', 'PC', 'PS', 'CR', 'DN', 'HD', 'A', 'B', 'C', 'XE', 'T', 'PE', 'PC', 'RS')) then
            _result.uoc := _uoc;
            _total_uoc := _total_uoc + _result.uoc;
        else
            _result.uoc := null;
        end if;
        
        if (_result.mark is not null) then
            _total_uoc_attempted := _total_uoc_attempted + _uoc;
            _weightedSumOfMarks := _weightedSumOfMarks + _uoc * _result.mark;
        end if;
        
        select program into _program
        from program_enrolments
        where student = _id
        and term = _term;
        
        select code into _result.prog
        from programs
        where id = _program;
        
        return next _result;
    end loop;
    
    if ( _total_uoc_attempted = 0) then
        _result.code := null;
        _result.term := null;
        _result.prog := null;
        _result.name := 'No WAM available';
        _result.mark := null;
        _result.grade := null;
        _result.uoc := null;
        return next _result;
    else
        _result.code := null;
        _result.term := null;
        _result.prog := null;
        _result.name := 'Overall WAM/UOC';
        _result.mark := _weightedSumOfMarks / _total_uoc_attempted;
        _result.grade := null;
        _result.uoc := _total_uoc;  
        return next _result;
    end if;
end;
$$ language plpgsql;

-- Q9: members of academic object group

create or replace function
   Q9(gid integer) returns setof AcObjRecord
as $$
declare
    _result AcObjRecord;
    _gtype acadobjectgrouptype;
    _gdefby acadobjectgroupdeftype;
    
    
    _definition textstring;
    _program integer;
    _stream integer;
    _subject integer;
    _negated boolean;
    _children integer;
begin
    select gtype,gdefby,definition,negated into _gtype, _gdefby,_definition,_negated
    from acad_object_groups
    where id = gid;
    if (not found) then
        raise exception 'No such group %', gid;
    end if;
    
    if (_gdefby='query') then
        return;
    elsif (_negated=true) 
    then
        return;
    elsif (_definition ~ '.*(FREE|GEN|F=).*')
    then    
        return;
    end if;

    if (_gtype = 'program') then
        _result.objtype := 'program';
        if (_gdefby = 'enumerated') then
        
            for _program in (select program from program_group_members where ao_group = gid) loop
                select code into _result.objcode
                from programs
                where id = _program;
                return next _result;
            end loop;
        
            for _children in (select id from acad_object_groups where parent = gid) loop
                for _result in (select * from q9(_children)) loop
                    return next _result;
                end loop;
            end loop;
        
        
        end if;
        
        if (_gdefby = 'pattern') then
            _definition := regexp_replace(_definition, '\,|\;' , '|' , 'g');
            _definition := regexp_replace(_definition, '\{|\}' , '' , 'g');
            _definition := regexp_replace(_definition, '#' , '.' , 'g');
            
            for _result.objcode in (select * from regexp_split_to_table(_definition, '\|')) loop
                if (_result.objcode !~ '\.|\[') then
                    return next _result;
                else 
                    for _result.objcode in (select code from programs where code ~ _result.objcode) loop
                        return next _result;
                    end loop;
                end if;
            
            end loop;
            
        end if;
        
    end if;


    if (_gtype = 'stream') then
        _result.objtype := 'stream';
        if (_gdefby = 'enumerated') then
        
            for _stream in (select stream from stream_group_members where ao_group = gid) loop
                select code into _result.objcode
                from streams
                where id = _stream;
                return next _result;
            end loop;
        
            for _children in (select id from acad_object_groups where parent = gid) loop
                for _result in (select * from q9(_children)) loop
                    return next _result;
                end loop;
            end loop;
        
        
        end if;
        
        
        if (_gdefby = 'pattern') then
            _definition := regexp_replace(_definition, '\,|\;' , '|' , 'g');
            _definition := regexp_replace(_definition, '\{|\}' , '' , 'g');
            _definition := regexp_replace(_definition, '#' , '.' , 'g');
            
            for _result.objcode in (select * from regexp_split_to_table(_definition, '\|')) loop
                if (_result.objcode !~ '\.|\[') then
                    return next _result;
                else 
                    for _result.objcode in (select code from streams where code ~ _result.objcode) loop
                        return next _result;
                    end loop;
                end if;
            
            end loop;
            
        end if;
        
        
    end if;
    
    
    
    if (_gtype = 'subject') then
        _result.objtype := 'subject';
        if (_gdefby = 'enumerated') then
        
            for _subject in (select subject from subject_group_members where ao_group = gid) loop
                select code into _result.objcode
                from subjects
                where id = _subject;
                return next _result;
            end loop;
        
            for _children in (select id from acad_object_groups where parent = gid) loop
                for _result in (select * from q9(_children)) loop
                    return next _result;
                end loop;
            end loop;
        end if;
        
        if (_gdefby = 'pattern') then
            _definition := regexp_replace(_definition, '\,|\;' , '|' , 'g');
            _definition := regexp_replace(_definition, '\{|\}' , '' , 'g');
            _definition := regexp_replace(_definition, '#' , '.' , 'g');
            
            for _result.objcode in (select * from regexp_split_to_table(_definition, '\|')) loop
                if (_result.objcode !~ '\.|\[') then
                    return next _result;
                else 
                    for _result.objcode in (select code from subjects where code ~ _result.objcode) loop
                        return next _result;
                    end loop;
                end if;
            
            end loop;
            
        end if;
        
        
    end if;



end;
$$ language plpgsql;

-- Q10: follow-on courses

create or replace function
   Q10_f1(_code text) returns setof text
as $$
declare
    _result text;
    _id integer;
    _rule_id integer;
    
    _subject integer;
begin

    for _id in (select id from acad_object_groups where definition ~ _code) loop
        
        for _rule_id in (select id from rules where ao_group = _id) loop
        
            for _subject in (select subject from subject_prereqs where rule = _rule_id) loop
                select code into _result
                from subjects
                where id = _subject;
                
                return next _result;
            
            end loop;
            
        end loop;   
        
    end loop;


end;
$$ language plpgsql;



create or replace function
   Q10(_code text) returns setof text
as $$
declare
    _result text;
begin
    
    for _result in (select distinct q10_f1 from q10_f1(_code)) loop
        return next _result;
    end loop;
    
end;
$$ language plpgsql;
