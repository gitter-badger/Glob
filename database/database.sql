




-- database/database.sql

CREATE OR REPLACE FUNCTION
  drop_all_table(user_name IN VARCHAR,schema_name IN VARCHAR)
  RETURNS VOID
  AS $$
  DECLARE statements CURSOR FOR
    SELECT table_name FROM pg_tables
    WHERE tableowner = user_name AND
          schemaname = schema_name;
    BEGIN
      FOR stmt IN statements LOOP
        EXECUTE 'DROP TABLE ' || quote_ident(stmt.tablename) || ' CASCADE;';
      END LOOP;
    END;
$$ LANGUAGE plpgsql;

SELECT drop_all_table('qinka','public');

CREATE TABLE table_nav
{
  texts TEXT NOT NULL PRIMARY KEY,
  ordering INT ,
  refto TEXT NOT NULL
};

CREATE TABLE table_pages
{
  indexs TEXT NOT NULL PRIMARY KEY,
  tos TEXT NOT NULL,
  times DATE NOT NULL,
  title TEXT NOT NULL
};

CREATE TABLE table_blogs
{
  indexs TEXT NOT NULL PRIMARY KEY,
  tos TEXT NOT NULL,
  times DATE NOT NULL,
  title TEXT NOT NULL
};

CREATE TABLE table_htmls
{
  indexs TEXT NOT NULL PRIMARY KEY,
  html TEXT NOT NULL
};