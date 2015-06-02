
-- CREATE a database for testing:

CREATE DATABASE university ;

-- Connect to the the newly created database 
\c university 

--Create the students table 

CREATE TABLE STUDENT(
   ID  SERIAL PRIMARY KEY,
   FIRST_NAME	TEXT	NOT NULL,
   LAST_NAME	TEXT	NOT NULL,
   DATE_OF_BIRTH	DATE	NOT NULL
   );

drop schema audit cascade ;

-- Define and load the functions in the script file
\i audit_trigger.postgres.sql 



-- start monitoring 'student' table for events
select audit.audit_table('student') ;


INSERT INTO STUDENT (first_name , last_name , DATE_OF_BIRTH) values ('John' , 'Smith' , '01-01-1969' ) ;
INSERT INTO STUDENT (first_name , last_name , DATE_OF_BIRTH) values ('Mary' , 'Smith' , '01-01-1970' ) ;
INSERT INTO STUDENT (first_name , last_name , DATE_OF_BIRTH) values ('Peter' , 'Smith' , '01-01-1971' ) ;
INSERT INTO STUDENT (first_name , last_name , DATE_OF_BIRTH) values ('Steve' , 'Smith' , '01-01-1972' ) ;



-- we are selecting everything in student to show the content
SELECT * FROM STUDENT ;

update  student set last_name = 'The Smith Family' where id > 2 ;


-- you can see the logs in the logged_actions table
SELECT * FROM audit.logged_actions; 



