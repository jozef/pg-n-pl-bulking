-- create table
DROP TABLE IF EXISTS pg_n_pl_bulking;
CREATE TABLE pg_n_pl_bulking (
    id SERIAL,
    ident TEXT NOT NULL,
    title TEXT NOT NULL,
    num INT NOT NULL,
    created TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    meta JSONB NOT NULL
);
CREATE UNIQUE INDEX pg_n_pl_bulking_ident_idx ON pg_n_pl_bulking USING btree (ident);
CREATE INDEX pg_n_pl_bulking_num_idx ON pg_n_pl_bulking USING btree (num);


-- updated timestamp function
CREATE OR REPLACE FUNCTION set_updated_now_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated := current_timestamp;
    RETURN NEW;
END;
$$;

-- updated timestamp trigger
DROP TRIGGER IF EXISTS pg_n_pl_bulking_updated_trg ON pg_n_pl_bulking;
CREATE TRIGGER pg_n_pl_bulking_updated_trg BEFORE UPDATE ON pg_n_pl_bulking FOR EACH ROW EXECUTE PROCEDURE set_updated_now_func();
