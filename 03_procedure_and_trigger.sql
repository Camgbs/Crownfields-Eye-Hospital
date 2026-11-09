-- Crownfield Eye Hospital Part C: B5-B6 and validation
-- MySQL 8.0.16+ / 8.4, InnoDB tables, shared eleven-table Part B schema.
-- Run AFTER 02_individual_queries.sql, in a fresh connection with no pending
-- work: routine/trigger DDL implicitly commits. Run the WHOLE file as a script
-- in MySQL Workbench so DELIMITER is processed, not as individual statements.
-- Requires routine/trigger creation rights and SELECT/INSERT/UPDATE/DELETE and temporary-table privileges.
-- Reruns replace only the partner's named routines and trigger below.
-- Validation uses invented transactional records; ROLLBACK removes them.
-- Auto-increment gaps may remain. Expected rejections are caught and reported
-- as PASS/FAIL rows, so there are no intentional error stops in the script.
USE crownfield_eye_hospital;

-- B5 | Stored procedure with input parameter
-- Question: How can a clinic's appointment schedule be retrieved by its ID?
-- INVOKER uses the caller's access rights; the parameter filters one clinic.
DROP PROCEDURE IF EXISTS sp_b_clinic_schedule;
DELIMITER $$
CREATE PROCEDURE sp_b_clinic_schedule(IN p_clinic_id INT UNSIGNED)
SQL SECURITY INVOKER
READS SQL DATA
BEGIN
    SELECT a.appointment_id, a.clinic_id, a.appointment_date,
           a.appointment_time, a.patient_id,
           CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
           CONCAT(c.first_name, ' ', c.last_name) AS clinician_name
    FROM appointment AS a
    INNER JOIN patient AS p ON p.patient_id = a.patient_id
    INNER JOIN clinician AS c ON c.clinician_id = a.clinician_id
    WHERE a.clinic_id = p_clinic_id
    ORDER BY a.appointment_date, a.appointment_time, a.appointment_id;
END$$
DELIMITER ;

SET @partner_clinic_id = (SELECT MIN(clinic_id) FROM appointment);
CALL sp_b_clinic_schedule(@partner_clinic_id);
SELECT @partner_clinic_id AS chosen_clinic,
       COUNT(*) AS expected_schedule_rows
FROM appointment WHERE clinic_id = @partner_clinic_id;
-- NULL cannot match a clinic: expected empty result, no exception.
CALL sp_b_clinic_schedule(NULL);

-- B6 | Protect attribution of clinical history
-- Question: Can a visit be reassigned after a diagnosis or prescription exists?
-- Added prototype rule: reject patient reassignment once either exists.
-- Adaptation: diagnoses are linked through appointment_diagnosis in Part B.
-- Follow-up alone does not lock the patient. This is an UPDATE rule, not a
-- complete clinical correction or concurrent-records management system.
DROP TRIGGER IF EXISTS trg_b_protect_visit_patient;
DELIMITER $$
CREATE TRIGGER trg_b_protect_visit_patient
BEFORE UPDATE ON appointment
FOR EACH ROW
BEGIN
    IF NOT (NEW.patient_id <=> OLD.patient_id)
       AND (
           EXISTS (SELECT 1 FROM appointment_diagnosis AS d
                   WHERE d.appointment_id = OLD.appointment_id)
           OR EXISTS (SELECT 1 FROM prescription AS r
                      WHERE r.appointment_id = OLD.appointment_id)
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Patient locked by clinical visit records';
    END IF;
END$$
DELIMITER ;

-- MEMORY preserves the validation log when fixture data is rolled back.
DROP TEMPORARY TABLE IF EXISTS partner_c_validation;
CREATE TEMPORARY TABLE partner_c_validation (
    test_no INT PRIMARY KEY,
    test_name VARCHAR(100) NOT NULL,
    outcome VARCHAR(10) NOT NULL,
    detail VARCHAR(512) NOT NULL
) ENGINE = MEMORY;

DROP PROCEDURE IF EXISTS sp_b_validate_part_c;
DELIMITER $$
CREATE PROCEDURE sp_b_validate_part_c()
SQL SECURITY INVOKER
MODIFIES SQL DATA
BEGIN
    DECLARE v_tag VARCHAR(32);
    DECLARE v_p1 VARCHAR(10);
    DECLARE v_p2 VARCHAR(10);
    DECLARE v_specialty INT UNSIGNED;
    DECLARE v_clinic INT UNSIGNED;
    DECLARE v_clinician INT UNSIGNED;
    DECLARE v_diag INT UNSIGNED;
    DECLARE v_visit INT UNSIGNED;
    DECLARE v_rx INT UNSIGNED;
    DECLARE v_med INT UNSIGNED;
    DECLARE v_n INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_message VARCHAR(512) DEFAULT '';
    DECLARE v_state CHAR(5) DEFAULT '00000';
    DECLARE v_patient VARCHAR(10);
    -- Unexpected failures are visible as FAIL, never reported as success.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET STACKED DIAGNOSTICS CONDITION 1
            v_errno = MYSQL_ERRNO, v_message = MESSAGE_TEXT;
        ROLLBACK;
        INSERT INTO partner_c_validation VALUES
          (99, 'Unexpected validation error', 'FAIL',
           CONCAT('Error ', v_errno, ': ', v_message));
    END;

    START TRANSACTION;
    SET v_tag = REPLACE(UUID(), '-', '');
    SET v_p1 = CONCAT('B1', LEFT(v_tag, 8));
    SET v_p2 = CONCAT('B2', LEFT(v_tag, 8));
    INSERT INTO patient(patient_id, first_name, last_name, postcode)
    VALUES (v_p1, 'PartnerTest', 'One', 'M1 1AA'),
           (v_p2, 'PartnerTest', 'Two', 'M1 1AA');
    INSERT INTO specialty(specialty_name) VALUES (CONCAT('Part C test ', v_tag));
    SET v_specialty = LAST_INSERT_ID();
    INSERT INTO clinic(clinic_name) VALUES (CONCAT('Part C test ', v_tag));
    SET v_clinic = LAST_INSERT_ID();
    INSERT INTO clinician(first_name, last_name, specialty_id)
    VALUES ('PartnerTest', 'Clinician', v_specialty);
    SET v_clinician = LAST_INSERT_ID();

    -- Deterministic optional-relationship check before creating a visit.
    SELECT COUNT(*) INTO v_n
    FROM clinician AS c LEFT JOIN appointment AS a
      ON a.clinician_id = c.clinician_id
    WHERE c.clinician_id = v_clinician AND a.appointment_id IS NULL;
    INSERT INTO partner_c_validation VALUES
      (1, 'B3: clinician with no appointments', IF(v_n = 1, 'PASS', 'FAIL'),
       CONCAT('Expected 1 missing-relationship row; observed ', v_n));

    INSERT INTO appointment(patient_id, clinician_id, clinic_id,
                            appointment_date, appointment_time, notes)
    VALUES (v_p1, v_clinician, v_clinic, '2030-01-01', '09:00:00',
            'Temporary Part C validation visit');
    SET v_visit = LAST_INSERT_ID();

    -- B5: this separate fixture clinic has exactly one appointment.
    SELECT 'B5 fixture schedule: expect exactly one row' AS evidence;
    CALL sp_b_clinic_schedule(v_clinic);

    UPDATE appointment SET patient_id = v_p2 WHERE appointment_id = v_visit;
    SELECT patient_id INTO v_patient FROM appointment WHERE appointment_id = v_visit;
    INSERT INTO partner_c_validation VALUES
      (2, 'B6: reassignment without clinical records',
       IF(v_patient = v_p2, 'PASS', 'FAIL'),
       CONCAT('Expected ', v_p2, '; stored ', v_patient));
    UPDATE appointment SET patient_id = v_p1 WHERE appointment_id = v_visit;

    INSERT INTO diagnosis(diagnosis_name) VALUES (CONCAT('Part C test ', v_tag));
    SET v_diag = LAST_INSERT_ID();
    INSERT INTO appointment_diagnosis(appointment_id, diagnosis_id)
    VALUES (v_visit, v_diag);

    -- A diagnosis-only rejection; capture the actual trigger message.
    SET v_errno = 0;
    SET v_message = '';
    SET v_state = '00000';
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            GET STACKED DIAGNOSTICS CONDITION 1
                v_errno = MYSQL_ERRNO, v_message = MESSAGE_TEXT,
                v_state = RETURNED_SQLSTATE;
        UPDATE appointment SET patient_id = v_p2 WHERE appointment_id = v_visit;
    END;
    SELECT patient_id INTO v_patient FROM appointment WHERE appointment_id = v_visit;
    INSERT INTO partner_c_validation VALUES
      (3, 'B6: diagnosis-only rejection and unchanged patient',
       IF(v_errno = 1644 AND v_state = '45000'
          AND v_message = 'Patient locked by clinical visit records'
          AND v_patient = v_p1, 'PASS', 'FAIL'),
       CONCAT('Error ', v_errno, '; ', v_message, '; stored ', v_patient));

    -- Remove only the test diagnosis link to isolate the prescription path.
    DELETE FROM appointment_diagnosis
    WHERE appointment_id = v_visit AND diagnosis_id = v_diag;
    INSERT INTO prescription(appointment_id) VALUES (v_visit);
    SET v_rx = LAST_INSERT_ID();
    INSERT INTO medicine(medicine_name) VALUES (CONCAT('Part C test ', v_tag));
    SET v_med = LAST_INSERT_ID();
    INSERT INTO prescription_item
      (prescription_id, medicine_id, dose, route, frequency, duration_text)
    VALUES (v_rx, v_med, 'TEST ONLY', 'TEST ONLY', 'TEST ONLY', 'TEST ONLY');

    SET v_errno = 0;
    SET v_message = '';
    SET v_state = '00000';
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            GET STACKED DIAGNOSTICS CONDITION 1
                v_errno = MYSQL_ERRNO, v_message = MESSAGE_TEXT,
                v_state = RETURNED_SQLSTATE;
        UPDATE appointment SET patient_id = v_p2 WHERE appointment_id = v_visit;
    END;
    SELECT patient_id INTO v_patient FROM appointment WHERE appointment_id = v_visit;
    INSERT INTO partner_c_validation VALUES
      (4, 'B6: prescription-only rejection and unchanged patient',
       IF(v_errno = 1644 AND v_state = '45000'
          AND v_message = 'Patient locked by clinical visit records'
          AND v_patient = v_p1, 'PASS', 'FAIL'),
       CONCAT('Error ', v_errno, '; ', v_message, '; stored ', v_patient));

    -- Other fields may still be corrected when the patient is unchanged.
    UPDATE appointment SET notes = 'Temporary corrected test note'
    WHERE appointment_id = v_visit;
    SELECT COUNT(*) INTO v_n FROM appointment
    WHERE appointment_id = v_visit AND notes = 'Temporary corrected test note'
      AND patient_id = v_p1;
    INSERT INTO partner_c_validation VALUES
      (5, 'B6: notes correction with unchanged patient',
       IF(v_n = 1, 'PASS', 'FAIL'), 'Notes update should succeed');

    ROLLBACK;
    SELECT COUNT(*) INTO v_n FROM patient WHERE patient_id IN (v_p1, v_p2);
    INSERT INTO partner_c_validation VALUES
      (6, 'Fixture rollback', IF(v_n = 0, 'PASS', 'FAIL'),
       CONCAT('Expected zero test patients remaining; observed ', v_n));
END$$
DELIMITER ;

CALL sp_b_validate_part_c();
SELECT test_no, test_name, outcome, detail
FROM partner_c_validation ORDER BY test_no;
SELECT CASE WHEN COUNT(*) = 6 AND SUM(outcome = 'FAIL') = 0
            THEN 'PASS: all automated checks completed'
            ELSE 'FAIL: inspect validation details above' END AS validation_summary
FROM partner_c_validation;

-- Show the installed feature definitions for screenshots.
SHOW CREATE PROCEDURE sp_b_clinic_schedule;
SHOW CREATE TRIGGER trg_b_protect_visit_patient;
-- The helper is not an assessed feature; retain only B5 and B6 permanently.
DROP PROCEDURE IF EXISTS sp_b_validate_part_c;
