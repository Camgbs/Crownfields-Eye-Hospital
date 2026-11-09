-- 04_security.sql Crownfield Eye Hospital | Part D
-- MySQL 8.0.16+ / 8.4; eleven-table lower_case Part B schema; InnoDB.
-- Run AFTER the shared schema/data and your Part C files.
-- Use a NEW administrator/root connection with no unfinished transaction.
-- Execute the WHOLE file as a script in MySQL Workbench, including DELIMITER.
-- No manual pauses or intentional unhandled error tests are included.
-- Missing schema, insufficient setup privileges or server configuration issues
-- can still stop execution. Do not ignore genuine setup errors.
-- Setup requires CREATE USER/ROLE, role administration, GRANT OPTION for the
-- assigned rights, DDL/routine rights and permission to name another DEFINER
-- (SET_ANY_DEFINER on MySQL 8.4; SET_USER_ID/SUPER as applicable on MySQL 8.0).
-- Use the local teaching database; inherited powerful mandatory roles would
-- undermine least privilege and will be exposed by the negative tests.
--
-- Scope: resets ONLY this file's dedicated rf_* lab accounts and roles;
-- recreates its own views/probes; retains shared tables and Part C features.
-- rf_booking_status adds the appointment status missing from Part B.
-- rf_patient_login_demo stores a DEMONSTRATION verifier, never a real login.
-- Accounts remain locked: automated tests use restricted DEFINER contexts.
-- This tests server privileges, NOT successful client authentication. No
-- password changes, account unlocking or reconnects are required to run it.
--
-- Evidence: capture grants, each PASS/FAIL grid, protection and transaction
-- results. Explain actual results independently. MySQL execution was NOT
-- available during file preparation. Python PBKDF2 generation/self-tests ran.
USE crownfield_eye_hospital;
SELECT VERSION() AS mysql_version, CURRENT_USER() AS setup_account;

-- Remove our objects before dropping their definers (safe rerun order).
DROP PROCEDURE IF EXISTS rf_test_reception;
DROP PROCEDURE IF EXISTS rf_test_doctor;
DROP PROCEDURE IF EXISTS rf_test_patient001;
DROP PROCEDURE IF EXISTS rf_test_patient002;
DROP PROCEDURE IF EXISTS rf_test_admin;
DROP PROCEDURE IF EXISTS rf_test_insert_grant;
DROP PROCEDURE IF EXISTS rf_test_transactions;
DROP VIEW IF EXISTS rf_v_op001;
DROP VIEW IF EXISTS rf_v_op002;
DROP USER IF EXISTS 'rf_admin'@'localhost', 'rf_doctor'@'localhost',
 'rf_reception'@'localhost', 'rf_p001'@'localhost', 'rf_p002'@'localhost',
 'rf_view_owner'@'localhost';
DROP ROLE IF EXISTS 'rf_administrator', 'rf_clinician', 'rf_receptionist',
 'rf_patient001', 'rf_patient002';

CREATE TABLE IF NOT EXISTS rf_booking_status (
 appointment_id INT UNSIGNED PRIMARY KEY,
 status VARCHAR(20) NOT NULL DEFAULT 'Scheduled',
 CONSTRAINT rf_fk_booking FOREIGN KEY (appointment_id)
   REFERENCES appointment(appointment_id) ON DELETE CASCADE,
 CONSTRAINT rf_chk_booking CHECK (status IN ('Scheduled','Completed','Cancelled'))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rf_patient_login_demo (
 patient_id VARCHAR(10) PRIMARY KEY,
 password_verifier VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 CONSTRAINT rf_fk_login FOREIGN KEY (patient_id)
   REFERENCES patient(patient_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- D1: four user types, with a separate role/view for each of two patients.
CREATE ROLE 'rf_administrator', 'rf_clinician', 'rf_receptionist',
 'rf_patient001', 'rf_patient002';
CREATE USER 'rf_admin'@'localhost' ACCOUNT LOCK;
CREATE USER 'rf_doctor'@'localhost' ACCOUNT LOCK;
CREATE USER 'rf_reception'@'localhost' ACCOUNT LOCK;
CREATE USER 'rf_p001'@'localhost' ACCOUNT LOCK;
CREATE USER 'rf_p002'@'localhost' ACCOUNT LOCK;
CREATE USER 'rf_view_owner'@'localhost' ACCOUNT LOCK;

-- Data administrator: DML only, not account management or GRANT OPTION.
GRANT SELECT, INSERT, UPDATE, DELETE ON crownfield_eye_hospital.*
 TO 'rf_administrator';

-- Doctor: clinical read, notes correction, diagnoses/prescriptions/follow-ups.
-- No password access and no DELETE. Service-wide clinician access is an
-- explicit prototype assumption, not clinician-specific row filtering.
GRANT SELECT ON crownfield_eye_hospital.patient TO 'rf_clinician';
GRANT SELECT ON crownfield_eye_hospital.appointment TO 'rf_clinician';
GRANT SELECT ON crownfield_eye_hospital.clinic TO 'rf_clinician';
GRANT SELECT ON crownfield_eye_hospital.clinician TO 'rf_clinician';
GRANT SELECT ON crownfield_eye_hospital.specialty TO 'rf_clinician';
GRANT SELECT ON crownfield_eye_hospital.medicine TO 'rf_clinician';
GRANT SELECT ON crownfield_eye_hospital.diagnosis TO 'rf_clinician';
GRANT SELECT, INSERT ON crownfield_eye_hospital.appointment_diagnosis TO 'rf_clinician';
GRANT SELECT, INSERT ON crownfield_eye_hospital.prescription TO 'rf_clinician';
GRANT SELECT, INSERT ON crownfield_eye_hospital.prescription_item TO 'rf_clinician';
GRANT SELECT, INSERT ON crownfield_eye_hospital.follow_up_plan TO 'rf_clinician';
GRANT UPDATE (notes) ON crownfield_eye_hospital.appointment TO 'rf_clinician';
GRANT SELECT, INSERT, UPDATE (status) ON crownfield_eye_hospital.rf_booking_status
 TO 'rf_clinician';

-- Reception: column-level booking access excludes notes. A table-level SELECT
-- on appointment would expose notes, so it is deliberately not granted.
GRANT SELECT, INSERT, UPDATE (postcode)
 ON crownfield_eye_hospital.patient TO 'rf_receptionist';
GRANT SELECT (appointment_id,patient_id,clinician_id,clinic_id,
              appointment_date,appointment_time),
 INSERT (patient_id,clinician_id,clinic_id,appointment_date,appointment_time),
 UPDATE (appointment_date,appointment_time)
 ON crownfield_eye_hospital.appointment TO 'rf_receptionist';
GRANT SELECT ON crownfield_eye_hospital.clinic TO 'rf_receptionist';
GRANT SELECT ON crownfield_eye_hospital.clinician TO 'rf_receptionist';
GRANT SELECT, INSERT, UPDATE (status) ON crownfield_eye_hospital.rf_booking_status
 TO 'rf_receptionist';

-- Locked view owner has only the exact source-column reads the views need.
GRANT SELECT (appointment_id,patient_id,appointment_date,appointment_time,clinic_id)
 ON crownfield_eye_hospital.appointment TO 'rf_view_owner'@'localhost';
GRANT SELECT (clinic_id,clinic_name) ON crownfield_eye_hospital.clinic
 TO 'rf_view_owner'@'localhost';
CREATE DEFINER='rf_view_owner'@'localhost' SQL SECURITY DEFINER VIEW rf_v_op001 AS
 SELECT a.appointment_id,a.patient_id,a.appointment_date,a.appointment_time,k.clinic_name
 FROM appointment AS a INNER JOIN clinic AS k ON k.clinic_id=a.clinic_id
 WHERE a.patient_id='OP001';
CREATE DEFINER='rf_view_owner'@'localhost' SQL SECURITY DEFINER VIEW rf_v_op002 AS
 SELECT a.appointment_id,a.patient_id,a.appointment_date,a.appointment_time,k.clinic_name
 FROM appointment AS a INNER JOIN clinic AS k ON k.clinic_id=a.clinic_id
 WHERE a.patient_id='OP002';
GRANT SELECT ON crownfield_eye_hospital.rf_v_op001 TO 'rf_patient001';
GRANT SELECT ON crownfield_eye_hospital.rf_v_op002 TO 'rf_patient002';

GRANT 'rf_administrator' TO 'rf_admin'@'localhost';
GRANT 'rf_clinician' TO 'rf_doctor'@'localhost';
GRANT 'rf_receptionist' TO 'rf_reception'@'localhost';
GRANT 'rf_patient001' TO 'rf_p001'@'localhost';
GRANT 'rf_patient002' TO 'rf_p002'@'localhost';
SET DEFAULT ROLE 'rf_administrator' TO 'rf_admin'@'localhost';
SET DEFAULT ROLE 'rf_clinician' TO 'rf_doctor'@'localhost';
SET DEFAULT ROLE 'rf_receptionist' TO 'rf_reception'@'localhost';
SET DEFAULT ROLE 'rf_patient001' TO 'rf_p001'@'localhost';
SET DEFAULT ROLE 'rf_patient002' TO 'rf_p002'@'localhost';
SHOW GRANTS FOR 'rf_admin'@'localhost' USING 'rf_administrator';
SHOW GRANTS FOR 'rf_doctor'@'localhost' USING 'rf_clinician';
SHOW GRANTS FOR 'rf_reception'@'localhost' USING 'rf_receptionist';
SHOW GRANTS FOR 'rf_p001'@'localhost' USING 'rf_patient001';
SHOW GRANTS FOR 'rf_p002'@'localhost' USING 'rf_patient002';

-- D2: salted PBKDF2-HMAC-SHA256, 600000 iterations, two random 16-byte salts.
-- MySQL has no built-in PBKDF2 password-verification function. These values
-- were derived and checked with Python hashlib before generating this file.
-- This SQL provisions/retrieves the demonstration verifier; the comparisons
-- below are PRECOMPUTED test vectors, not a live SQL password-hashing service.
-- Do not use these published demonstration credentials for real accounts.
-- Published test password: Rifat-DEMO-only-2026! (never use for a real login).
-- Reproduction in Python (not a prerequisite for running this SQL file):
-- import hashlib, secrets, hmac
-- password = "Rifat-DEMO-only-2026!"
-- supplied = password  # change to a wrong password to test rejection
-- salt = secrets.token_bytes(16)
-- digest = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 600000)
-- stored = f"pbkdf2_sha256$600000${salt.hex()}${digest.hex()}"
-- alg, iterations, salt_hex, hash_hex = stored.split('$')
-- candidate = hashlib.pbkdf2_hmac('sha256', supplied.encode(),
--                              bytes.fromhex(salt_hex), int(iterations))
-- accepted = hmac.compare_digest(candidate, bytes.fromhex(hash_hex))
-- Each new verifier needs a NEW random salt. The application uses bound
-- parameters to insert it. Hashing protects passwords, not clinical records.
SET @rf_verifier = 'pbkdf2_sha256$600000$760fb5885c18b8bef730265a5107843c$d70a42822eb2caadad81c8c6adc3e7f1e44b7eb14f000ccdad91d047be0ca634';
SET @rf_salt_two = 'a64c15117c8a086ab6316e36380a7f75';
SET @rf_hash_two = 'b0a1ccb1507733dda9c59bd5cb18d92e97312ff6596bedfbf51d8e0ba351ff53';
SET @rf_correct_candidate = 'd70a42822eb2caadad81c8c6adc3e7f1e44b7eb14f000ccdad91d047be0ca634';
SET @rf_wrong_candidate = 'aaddc1981cbe627fff3a1009bd6f5af5a7314c4ea81261244dc2761e38d78d1a';
-- OP002 from Appendix 1 is used; absence is reported instead of inventing data.
INSERT INTO rf_patient_login_demo(patient_id,password_verifier)
 SELECT patient_id,@rf_verifier FROM patient WHERE patient_id='OP002'
ON DUPLICATE KEY UPDATE password_verifier=@rf_verifier;
SELECT 'D2 verifier storage' AS test,
 CASE WHEN COUNT(*)=1 THEN 'PASS' ELSE 'SKIP: OP002 is absent' END AS outcome
FROM rf_patient_login_demo WHERE patient_id='OP002';
SELECT patient_id,password_verifier,
 IF(BINARY SUBSTRING_INDEX(password_verifier,'$',-1)=BINARY @rf_correct_candidate,
    'PASS','FAIL') AS correct_password_precomputed_vector,
 IF(BINARY SUBSTRING_INDEX(password_verifier,'$',-1)<>BINARY @rf_wrong_candidate,
    'PASS','FAIL') AS wrong_password_precomputed_vector,
 IF('760fb5885c18b8bef730265a5107843c'<>@rf_salt_two AND @rf_correct_candidate<>@rf_hash_two,
    'PASS','FAIL') AS different_salts_and_hashes
FROM rf_patient_login_demo WHERE patient_id='OP002';

-- Optional secure coding: bind input separately; never concatenate it into SQL.
PREPARE rf_lookup FROM
 'SELECT patient_id,first_name,last_name FROM patient WHERE patient_id = ?';
SET @rf_input='OP002';
EXECUTE rf_lookup USING @rf_input;
SET @rf_input='OP002'' OR ''1''=''1';
EXECUTE rf_lookup USING @rf_input;
DEALLOCATE PREPARE rf_lookup;
-- Expected: OP002 (if loaded), followed by zero rows for injection-style input.

-- D1 automatic privilege probes. CURRENT_USER and CURRENT_ROLE show the
-- restricted security context. Errors 1142/1143 mean permission denied.
-- Other errors are FAIL, not successful denial. Empty-table reads still test
-- privileges; they do not establish that the patient has appointment records.

DELIMITER $$
CREATE DEFINER='rf_reception'@'localhost' PROCEDURE rf_test_reception()
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_message VARCHAR(512) DEFAULT '';
 DECLARE v_n INT DEFAULT 0;
 SELECT CURRENT_USER() AS effective_account,CURRENT_ROLE() AS active_role;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(appointment_id) INTO v_n FROM appointment;
 END;
 SELECT 'Reception can read booking fields' AS test,IF(v_errno=0,'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  UPDATE patient SET postcode=postcode WHERE patient_id='OP002';
 END;
 SELECT 'Reception can update postcode' AS test,IF(v_errno=0,'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(notes) INTO v_n FROM appointment;
 END;
 SELECT 'Reception cannot read notes' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM follow_up_plan;
 END;
 SELECT 'Reception cannot read follow-ups' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_patient_login_demo;
 END;
 SELECT 'Reception cannot read password verifiers' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  DELETE FROM patient WHERE patient_id='RF_NO_ROW' AND 1=0;
 END;
 SELECT 'Reception cannot DELETE' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
END$$
DELIMITER ;
GRANT EXECUTE ON PROCEDURE crownfield_eye_hospital.rf_test_reception TO 'rf_reception'@'localhost';

DELIMITER $$
CREATE DEFINER='rf_doctor'@'localhost' PROCEDURE rf_test_doctor()
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_message VARCHAR(512) DEFAULT '';
 DECLARE v_n INT DEFAULT 0;
 SELECT CURRENT_USER() AS effective_account,CURRENT_ROLE() AS active_role;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(notes) INTO v_n FROM appointment;
 END;
 SELECT 'Doctor can read clinical notes' AS test,IF(v_errno=0,'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_patient_login_demo;
 END;
 SELECT 'Doctor cannot read password verifiers' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  DELETE FROM patient WHERE patient_id='RF_NO_ROW' AND 1=0;
 END;
 SELECT 'Doctor cannot DELETE' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
END$$
DELIMITER ;
GRANT EXECUTE ON PROCEDURE crownfield_eye_hospital.rf_test_doctor TO 'rf_doctor'@'localhost';

DELIMITER $$
CREATE DEFINER='rf_p001'@'localhost' PROCEDURE rf_test_patient001()
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_message VARCHAR(512) DEFAULT '';
 DECLARE v_n INT DEFAULT 0;
 SELECT CURRENT_USER() AS effective_account,CURRENT_ROLE() AS active_role;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_v_op001;
 END;
 SELECT 'Patient 001 can read own view' AS test,IF(v_errno=0,'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_v_op002;
 END;
 SELECT 'Patient 001 cannot read other view' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM appointment;
 END;
 SELECT 'Patient 001 cannot read base table' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_patient_login_demo;
 END;
 SELECT 'Patient 001 cannot read password verifiers' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
END$$
DELIMITER ;
GRANT EXECUTE ON PROCEDURE crownfield_eye_hospital.rf_test_patient001 TO 'rf_p001'@'localhost';

DELIMITER $$
CREATE DEFINER='rf_p002'@'localhost' PROCEDURE rf_test_patient002()
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_message VARCHAR(512) DEFAULT '';
 DECLARE v_n INT DEFAULT 0;
 SELECT CURRENT_USER() AS effective_account,CURRENT_ROLE() AS active_role;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_v_op002;
 END;
 SELECT 'Patient 002 can read own view' AS test,IF(v_errno=0,'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_v_op001;
 END;
 SELECT 'Patient 002 cannot read other view' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM appointment;
 END;
 SELECT 'Patient 002 cannot read base table' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_patient_login_demo;
 END;
 SELECT 'Patient 002 cannot read password verifiers' AS test,IF(v_errno IN (1142,1143),'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
END$$
DELIMITER ;
GRANT EXECUTE ON PROCEDURE crownfield_eye_hospital.rf_test_patient002 TO 'rf_p002'@'localhost';

DELIMITER $$
CREATE DEFINER='rf_admin'@'localhost' PROCEDURE rf_test_admin()
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_message VARCHAR(512) DEFAULT '';
 DECLARE v_n INT DEFAULT 0;
 SELECT CURRENT_USER() AS effective_account,CURRENT_ROLE() AS active_role;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  SELECT COUNT(*) INTO v_n FROM rf_patient_login_demo;
 END;
 SELECT 'Administrator can read protected verifier' AS test,IF(v_errno=0,'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
 SET v_errno=0;
 SET v_message='';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  DELETE FROM patient WHERE patient_id='RF_NO_ROW' AND 1=0;
 END;
 SELECT 'Administrator has DELETE privilege' AS test,IF(v_errno=0,'PASS','FAIL') AS outcome,
        v_errno AS error_number,v_message AS detail;
END$$
DELIMITER ;
GRANT EXECUTE ON PROCEDURE crownfield_eye_hospital.rf_test_admin TO 'rf_admin'@'localhost';

-- No changed postcode is committed. All no-op DELETE probes affect zero rows.
START TRANSACTION;
CALL rf_test_reception();
CALL rf_test_doctor();
CALL rf_test_patient001();
CALL rf_test_patient002();
CALL rf_test_admin();
ROLLBACK;

-- Show permitted row contents; no other patient's ID may occur in either view.
SELECT * FROM rf_v_op001;
SELECT * FROM rf_v_op002;
SELECT 'Patient view filters' AS test,
 IF((SELECT COUNT(*) FROM rf_v_op001 WHERE patient_id<>'OP001')=0
 AND (SELECT COUNT(*) FROM rf_v_op002 WHERE patient_id<>'OP002')=0,
 'PASS','FAIL') AS outcome;

-- Demonstrate revocation without changing any application rows.
DELIMITER $$
CREATE DEFINER='rf_reception'@'localhost' PROCEDURE rf_test_insert_grant(IN p_allowed BOOLEAN)
SQL SECURITY DEFINER
BEGIN
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_message VARCHAR(512) DEFAULT '';
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  INSERT INTO patient(patient_id,first_name,last_name,postcode)
   SELECT patient_id,first_name,last_name,postcode FROM patient WHERE 1=0;
 END;
 SELECT 'Reception INSERT grant/revoke' AS test,p_allowed AS expected_allowed,
 IF((p_allowed AND v_errno=0) OR (NOT p_allowed AND v_errno IN (1142,1143)),
    'PASS','FAIL') AS outcome,v_errno AS error_number,v_message AS detail;
END$$
DELIMITER ;
GRANT EXECUTE ON PROCEDURE crownfield_eye_hospital.rf_test_insert_grant
 TO 'rf_reception'@'localhost';
CALL rf_test_insert_grant(TRUE);
REVOKE INSERT ON crownfield_eye_hospital.patient FROM 'rf_receptionist';
CALL rf_test_insert_grant(FALSE);
GRANT INSERT ON crownfield_eye_hospital.patient TO 'rf_receptionist';
CALL rf_test_insert_grant(TRUE);

-- Transaction and integrity tests use a dedicated invented visit, never 102
-- or an existing clinical record. Commit proof is checked after COMMIT in this
-- connection. Independent second-connection visibility is NOT claimed here.
DROP TEMPORARY TABLE IF EXISTS rf_transaction_results;
CREATE TEMPORARY TABLE rf_transaction_results (
 test_no INT PRIMARY KEY,test_name VARCHAR(100),outcome VARCHAR(10),detail VARCHAR(512)
) ENGINE=MEMORY;
DELIMITER $$
CREATE PROCEDURE rf_test_transactions()
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
 DECLARE v_tag VARCHAR(32);
 DECLARE v_patient VARCHAR(10);
 DECLARE v_specialty INT UNSIGNED;
 DECLARE v_clinic INT UNSIGNED;
 DECLARE v_clinician INT UNSIGNED;
 DECLARE v_visit INT UNSIGNED;
 DECLARE v_n INT DEFAULT 0;
 DECLARE v_errno INT DEFAULT 0;
 DECLARE v_message VARCHAR(512) DEFAULT '';
 DECLARE v_fixture_committed BOOLEAN DEFAULT FALSE;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION
 BEGIN
  GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  ROLLBACK;
  INSERT INTO rf_transaction_results VALUES
   (99,'Unexpected error','FAIL',CONCAT('Error ',v_errno,': ',v_message));
  -- If failure followed a deliberate fixture commit, identify it explicitly.
  SELECT v_fixture_committed AS fixture_may_remain,v_patient AS test_patient,
         v_visit AS test_appointment,
         'If fixture_may_remain=1, inspect and remove only these test records' AS detail;
 END;
 SET v_tag=REPLACE(UUID(),'-','');
 SET v_patient=CONCAT('RF',LEFT(v_tag,8));
 START TRANSACTION;
 INSERT INTO patient(patient_id,first_name,last_name,postcode)
  VALUES(v_patient,'RifatTest','Transaction','M1 1AA');
 INSERT INTO specialty(specialty_name) VALUES(CONCAT('Rifat test ',v_tag));
 SET v_specialty=LAST_INSERT_ID();
 INSERT INTO clinic(clinic_name) VALUES(CONCAT('Rifat test ',v_tag));
 SET v_clinic=LAST_INSERT_ID();
 INSERT INTO clinician(first_name,last_name,specialty_id)
  VALUES('RifatTest','Clinician',v_specialty);
 SET v_clinician=LAST_INSERT_ID();
 INSERT INTO appointment(patient_id,clinician_id,clinic_id,
                         appointment_date,appointment_time,notes)
  VALUES(v_patient,v_clinician,v_clinic,'2030-01-01','09:00:00','Part D temporary test');
 SET v_visit=LAST_INSERT_ID();
 INSERT INTO rf_booking_status(appointment_id,status) VALUES(v_visit,'Scheduled');
 COMMIT;
 SET v_fixture_committed=TRUE;

 -- Rollback: status change and follow-up insertion must both disappear.
 START TRANSACTION;
 UPDATE rf_booking_status SET status='Completed' WHERE appointment_id=v_visit;
 INSERT INTO follow_up_plan(appointment_id,due_date,priority,status)
  VALUES(v_visit,'2030-02-01','Routine','Pending');
 SELECT 'Before ROLLBACK' AS stage,b.status AS booking_status,f.follow_up_id
 FROM rf_booking_status b JOIN follow_up_plan f USING(appointment_id)
 WHERE b.appointment_id=v_visit;
 ROLLBACK;
 SELECT COUNT(*) INTO v_n FROM rf_booking_status b
 WHERE b.appointment_id=v_visit AND b.status='Scheduled'
 AND NOT EXISTS(SELECT 1 FROM follow_up_plan f WHERE f.appointment_id=v_visit);
 INSERT INTO rf_transaction_results VALUES
  (1,'ROLLBACK undoes both changes',IF(v_n=1,'PASS','FAIL'),
   'Expected Scheduled and no follow-up');

 -- Commit: both changes must persist beyond the transaction boundary.
 START TRANSACTION;
 UPDATE rf_booking_status SET status='Completed' WHERE appointment_id=v_visit;
 INSERT INTO follow_up_plan(appointment_id,due_date,priority,status)
  VALUES(v_visit,'2030-02-01','Routine','Pending');
 COMMIT;
 SELECT COUNT(*) INTO v_n FROM rf_booking_status b
 JOIN follow_up_plan f USING(appointment_id)
 WHERE b.appointment_id=v_visit AND b.status='Completed' AND f.status='Pending';
 INSERT INTO rf_transaction_results VALUES
  (2,'COMMIT retains both changes',IF(v_n=1,'PASS','FAIL'),
   'Expected Completed and one Pending follow-up after COMMIT');
 SELECT 'After COMMIT, before cleanup' AS stage,b.status,f.follow_up_id
 FROM rf_booking_status b JOIN follow_up_plan f USING(appointment_id)
 WHERE b.appointment_id=v_visit;

 START TRANSACTION;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  UPDATE rf_booking_status SET status='Invalid' WHERE appointment_id=v_visit;
 END;
 SELECT COUNT(*) INTO v_n FROM rf_booking_status
  WHERE appointment_id=v_visit AND status='Completed';
 INSERT INTO rf_transaction_results VALUES
  (3,'CHECK rejects invalid booking status',
   IF(v_errno=3819 AND v_n=1,'PASS','FAIL'),CONCAT('Error ',v_errno,': ',v_message));
 ROLLBACK;
 SET v_errno=0;
 SET v_message='';
 START TRANSACTION;
 BEGIN
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   GET STACKED DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO,v_message=MESSAGE_TEXT;
  DELETE FROM patient WHERE patient_id=v_patient;
 END;
 SELECT COUNT(*) INTO v_n FROM patient WHERE patient_id=v_patient;
 INSERT INTO rf_transaction_results VALUES
  (4,'Foreign key protects referenced patient',
   IF(v_errno=1451 AND v_n=1,'PASS','FAIL'),CONCAT('Error ',v_errno,': ',v_message));
 ROLLBACK;

 -- Cleanup only this run's invented records, in child-to-parent order.
 START TRANSACTION;
 DELETE FROM follow_up_plan WHERE appointment_id=v_visit;
 DELETE FROM rf_booking_status WHERE appointment_id=v_visit;
 DELETE FROM appointment WHERE appointment_id=v_visit;
 DELETE FROM patient WHERE patient_id=v_patient;
 DELETE FROM clinician WHERE clinician_id=v_clinician;
 DELETE FROM clinic WHERE clinic_id=v_clinic;
 DELETE FROM specialty WHERE specialty_id=v_specialty;
 COMMIT;
 SET v_fixture_committed=FALSE;
 SELECT COUNT(*) INTO v_n FROM patient WHERE patient_id=v_patient;
 INSERT INTO rf_transaction_results VALUES
  (5,'Committed fixture cleaned up',IF(v_n=0,'PASS','FAIL'),
   'No invented test patient remains; auto-increment gaps may remain');
END$$
DELIMITER ;
CALL rf_test_transactions();
SELECT * FROM rf_transaction_results ORDER BY test_no;
SELECT IF(COUNT(*)=5 AND SUM(outcome='FAIL')=0,'PASS','FAIL') AS transaction_summary
FROM rf_transaction_results;

-- Remove temporary testing capabilities. The roles, locked accounts, views,
-- protected verifier table and booking-status table remain for assessment.
DROP PROCEDURE rf_test_reception;
DROP PROCEDURE rf_test_doctor;
DROP PROCEDURE rf_test_patient001;
DROP PROCEDURE rf_test_patient002;
DROP PROCEDURE rf_test_admin;
DROP PROCEDURE rf_test_insert_grant;
DROP PROCEDURE rf_test_transactions;
SELECT 'Script reached the end; inspect all PASS/FAIL/SKIP grids above' AS completion;

-- ACCESS MATRIX: S=SELECT, I=INSERT, U=UPDATE, D=DELETE.
-- Administrator: S/I/U/D all database data; no GRANT OPTION.
-- Doctor: S operational/clinical data; I clinical child records and booking
-- status; U appointment notes and booking status; no D or verifier access.
-- Reception: S patient/booking columns; I patients/bookings/status;
-- U postcode/date/time/status; no clinical notes, follow-ups, credentials or D.
-- Patients: S on their own fixed appointment view only; no base-table access.
-- This prototype needs per-clinician scoping, a controlled patient-view
-- provisioning process, audit logging, backups/recovery and an application
-- login service with rate limiting before any real-world deployment.
--
-- REFERENCES (Harvard style; accessed 6 November 2026)
-- University assessment brief (n.d.) CPU4 103 Introduction to Database:
-- Summative Assessment, Part D and marking rubric. Internal teaching material.
-- Oracle (n.d.) MySQL 8.4 Reference Manual: Using Roles.
-- https://dev.mysql.com/doc/refman/8.4/en/roles.html
-- Oracle (n.d.) MySQL 8.4 Reference Manual: Stored Object Access Control.
-- https://dev.mysql.com/doc/refman/8.4/en/stored-objects-security.html
-- Oracle (n.d.) MySQL 8.4 Reference Manual: Account Locking.
-- https://dev.mysql.com/doc/refman/8.4/en/account-locking.html
-- OWASP Foundation (n.d.) Password Storage Cheat Sheet.
-- https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
