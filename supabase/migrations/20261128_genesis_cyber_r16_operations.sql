-- GENESIS CYBER WAR R16: publish only implemented campaign operations.
INSERT INTO agc_ctf_private.operation_catalog(mission,title,difficulty,ready)
VALUES (7,'Network Anomaly',7,true),(8,'Configuration Audit',8,true)
ON CONFLICT(mission) DO UPDATE SET title=excluded.title,difficulty=excluded.difficulty,ready=excluded.ready;
