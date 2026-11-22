CREATE EXTENSION IF NOT EXISTS pgcrypto

CREATE TABLE draws (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title             TEXT NOT NULL,
    admin_token_hash  TEXT NOT NULL,          -- organiser's secret, stored hashed
    status            TEXT NOT NULL DEFAULT 'open'
                      CHECK (status IN ('open', 'drawn')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    drawn_at          TIMESTAMPTZ
);

CREATE TABLE participants (
    id                 BIGSERIAL PRIMARY KEY,
    draw_id            UUID NOT NULL REFERENCES draws(id) ON DELETE CASCADE,
    name               TEXT NOT NULL,
    session_token_hash TEXT UNIQUE,           -- NULL until someone claims this name
    claimed_at         TIMESTAMPTZ,
    assigned_to        BIGINT REFERENCES participants(id),

    UNIQUE (draw_id, name),                   -- no duplicate names in a draw
    UNIQUE (draw_id, assigned_to),            -- nobody is picked twice
    CHECK (assigned_to IS NULL OR assigned_to <> id)  -- nobody gets themselves
);

CREATE INDEX ON participants (draw_id);

UPDATE participants
SET session_token_hash = $1, claimed_at = now()
WHERE draw_id = $2 AND name = $3 AND session_token_hash IS NULL
RETURNING id;

SELECT me.name AS you, them.name AS got
FROM participants me
JOIN participants them ON them.id = me.assigned_to
WHERE me.session_token_hash = $1;

BEGIN;
UPDATE participants SET assigned_to = $2 WHERE id = $1;  -- repeat for each person
UPDATE draws SET status = 'drawn', drawn_at = now() WHERE id = $3;
COMMIT;

UPDATE participants SET session_token_hash = NULL, claimed_at = NULL
WHERE id = $1 AND draw_id = $2;