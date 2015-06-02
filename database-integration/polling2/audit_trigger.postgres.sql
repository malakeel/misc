
CREATE EXTENSION IF NOT EXISTS hstore;

CREATE SCHEMA audit;

CREATE TABLE audit.logged_actions (
    event_id bigserial primary key,
    schema text not null,
    table_name text not null,
    relid oid not null,
    action_tstamp_tx TIMESTAMP WITH TIME ZONE NOT NULL,
    action_tstamp_stm TIMESTAMP WITH TIME ZONE NOT NULL,
    action_tstamp_clk TIMESTAMP WITH TIME ZONE NOT NULL,
    tx_id bigint,
    app_name text,
    action TEXT NOT NULL , 
    row_data hstore,
    processed boolean not null default FALSE 
 
);


CREATE OR REPLACE FUNCTION audit.if_modified_func() RETURNS TRIGGER AS $body$
DECLARE
    audit_row audit.logged_actions;
    BEGIN
    IF TG_WHEN <> 'AFTER' THEN
        RAISE EXCEPTION 'audit.if_modified_func() may only run as an AFTER trigger';
    END IF;

    audit_row = ROW(
        nextval('audit.logged_actions_event_id_seq'), 	-- event_id
        TG_TABLE_SCHEMA::text,                        	-- schema_name
        TG_TABLE_NAME::text,                          	-- table_name
        TG_RELID,                                     	-- relation OID for much quicker searches
        current_timestamp,                            	-- action_tstamp_tx
        statement_timestamp(),                        	-- action_tstamp_stm
        clock_timestamp(),                            	-- action_tstamp_clk
        txid_current(),                               	-- transaction ID
        current_setting('application_name'),          	-- client application
        TG_OP,                         			-- action
	NULL ,
        FALSE                                   	-- was the record processed  ?  
        );
 
    IF ( TG_LEVEL = 'ROW') THEN 
	    IF (TG_OP = 'UPDATE' ) THEN
		audit_row.row_data = hstore(NEW.*);
		IF  (hstore(NEW.*)  = hstore(OLD.*) ) THEN
		    -- All changed fields are ignored. Skip this update.
		    RETURN NULL;
		END IF;
	    ELSIF (TG_OP = 'DELETE' ) THEN
		audit_row.row_data = hstore(OLD.*)  ;
	    ELSIF (TG_OP = 'INSERT' ) THEN
		audit_row.row_data = hstore(NEW.*)  ;
	    ELSE
		RAISE EXCEPTION '[audit.if_modified_func] - Trigger func added as trigger for unhandled case: %, %',TG_OP, TG_LEVEL;
		RETURN NULL;
	    END IF;
    END IF;

    
    INSERT INTO audit.logged_actions VALUES (audit_row.*);
    RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public;

CREATE OR REPLACE FUNCTION audit.audit_table(target_table regclass ) RETURNS void AS $body$
	DECLARE
	stm_targets text = 'INSERT OR UPDATE OR DELETE OR TRUNCATE';
	_q_txt text;
	_ignored_cols_snip text = '';
	BEGIN
	    --Temporary disable the NOTICE messages
	    SET client_min_messages TO WARNING;

	    EXECUTE 'DROP TRIGGER IF EXISTS audit_trigger_row ON ' || target_table;

	    _q_txt = 'CREATE TRIGGER audit_trigger_row AFTER INSERT OR UPDATE OR DELETE ON ' || target_table || ' FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func( );';

	    RAISE NOTICE '%',_q_txt ;

	    EXECUTE _q_txt;

	    stm_targets = 'TRUNCATE' ;

	    -- Allow NOTICE logs to show
	    SET client_min_messages TO NOTICE;

	END;
$body$
language 'plpgsql';

