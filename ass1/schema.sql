-- COMP3311 20T3 Assignment 1
-- Calendar schema
-- Written by jiahao zhang

-- Types

create type AccessibilityType as enum ('read-write','read-only','none');
create type InviteStatus as enum ('invited','accepted','declined');
create type VisibilityType as enum ('public', 'private');
create type DayOfWeek as enum ('monday', 'tuesday','wednesday','thursday','friday');

-- add more types/domains if you want

-- Tables

create table Users (
	id          serial primary key,
	name        text not null,
	passwd      text not null,
	email       text not null unique,
	is_admin    boolean not null
);

create table Groups (
	id          serial primary key,
	name        text not null,
	owner		integer not null,
	foreign key (owner) references Users(id)
);

create table Member (
	user_id		integer,
	group_id 	integer,
	primary key (user_id, group_id),
	foreign key (user_id) references Users(id),
	foreign key (group_id) references Groups(id)
);

create table Calendars (
	id          serial primary key,
	name        text not null,
	colour 		text not null,
	default_access	AccessibilityType not null,
	owner		integer not null,
	foreign key (owner) references Users(id)
);

create table Accessibility (
	user_id		integer,
	calendar_id integer,
	access		AccessibilityType not null,
	primary key (user_id, calendar_id),
	foreign key (user_id) references Users(id),
	foreign key (calendar_id) references Calendars(id)
);

create table Subscribed (
	user_id		integer,
	calendar_id integer,
	colour 		text,
	primary key (user_id, calendar_id),
	foreign key (user_id) references Users(id),
	foreign key (calendar_id) references Calendars(id)
);

create table Events (
	id          serial primary key,
	part_of     integer not null,
	createdby	integer not null,
	title		text not null,
	visibility	VisibilityType not null,
	location	text,
	start_time	time,
	end_time	time,
	foreign key (createdby) references Users(id),
	foreign key (part_of) references Calendars(id)
);

create table Invited (
	user_id		integer,
	event_id	integer,
	status		InviteStatus not null,
	primary key (user_id, event_id),
	foreign key (user_id) references Users(id),
	foreign key (event_id) references Events(id)
);

create table Alarms (
	event_id	integer,
	alarm		interval,
	primary key (event_id, alarm),
	foreign key (event_id) references Events(id)
);

create table One_Day_Events (
	event_id 	integer primary key,
	date		date not null,
	foreign key (event_id) references Events(id)
);

create table Spanning_Events (
	event_id		integer primary key,
	start_date		date not null,
	end_date		date not null,
	foreign key (event_id) references Events(id)
);

create table Recurring_Events (
	event_id		integer primary key,
	start_date		date not null,
	end_date		date,
	ntimes			integer,
	foreign key (event_id) references Events(id)
);

create table Weekly_Events (
	Recurring_Event_id		integer primary key,
	dayofWeek		DayOfWeek not null,
	frequency		integer not null,
	foreign key (Recurring_Event_id) references Recurring_Events(event_id)
);

create table MonthlyByDayEvents (
	Recurring_Event_id		integer primary key,
	dayOfWeek		DayOfWeek not null,
	weekinMonth	integer  not null check (weekinMonth between 1 and 5),
	foreign key (Recurring_Event_id) references Recurring_Events(event_id)
);

create table MonthlyByDateEvents (
	Recurring_Event_id		integer primary key,
	dateinMonth	integer  not null check (dateinMonth between 1 and 31),
	foreign key (Recurring_Event_id) references Recurring_Events(event_id)
);

create table Annual_Events (
	Recurring_Event_id		integer primary key,
	date			date not null,
	foreign key (Recurring_Event_id) references Recurring_Events(event_id)
);
