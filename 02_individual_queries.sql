-- Crownfield Eye Hospital | Partner | Part C: B1-B4
-- MySQL 8.0.16+ / 8.4. Run AFTER the shared Part B schema and data.
-- Target: the eleven-table, lower_case Part B schema.
-- Execute this entire file as a script. Read-only: no data is changed.
-- Capture each result with its SQL; explain YOUR actual results.
USE crownfield_eye_hospital;

-- B1 | Aggregate with GROUP BY and HAVING
-- Question: Which medicines appear in at least two prescription items?
-- The composite item key is (prescription_id, medicine_id); there is no
-- prescription_item_id. COUNT(*) counts item occurrences, not patients.
-- Validation: manually count matching prescription_item rows for one medicine.
-- Change >= 2 to >= 3 for a boundary comparison when making screenshots.
SELECT m.medicine_id, m.medicine_name, COUNT(*) AS item_count
FROM medicine AS m
INNER JOIN prescription_item AS i ON i.medicine_id = m.medicine_id
GROUP BY m.medicine_id, m.medicine_name
HAVING COUNT(*) >= 2
ORDER BY item_count DESC, m.medicine_id;

-- B2 | INNER JOIN across four tables
-- Question: Which appointment, patient and medicine belong to each item?
-- Both item-key columns are displayed so every row is identifiable.
-- Validation: output row count should equal COUNT(*) FROM prescription_item
-- when the foreign keys are intact. Multiple items per visit are legitimate.
SELECT i.prescription_id, i.medicine_id,
       a.appointment_id, a.patient_id, m.medicine_name,
       i.dose, i.route, i.frequency, i.duration_text
FROM prescription_item AS i
INNER JOIN prescription AS r ON r.prescription_id = i.prescription_id
INNER JOIN appointment AS a ON a.appointment_id = r.appointment_id
INNER JOIN medicine AS m ON m.medicine_id = i.medicine_id
ORDER BY i.prescription_id, i.medicine_id;

SELECT COUNT(*) AS expected_B2_rows FROM prescription_item;

-- B3 | LEFT JOIN revealing a missing optional relationship
-- Question: Which clinicians have no appointments recorded?
-- Adaptation: the supplied practice pack asked for missing specialties,
-- but specialty_id is NOT NULL in the shared Part B schema. A clinician
-- can still have zero appointments, so this optional relationship is used.
-- Validation: each returned clinician must have zero appointment rows.
-- An empty result is valid if every clinician has an appointment.
SELECT c.clinician_id,
       CONCAT(c.first_name, ' ', c.last_name) AS clinician_name,
       a.appointment_id
FROM clinician AS c
LEFT JOIN appointment AS a ON a.clinician_id = c.clinician_id
WHERE a.appointment_id IS NULL
ORDER BY c.clinician_id;

-- B4 | Common table expression (CTE)
-- Question: Which outstanding follow-ups were overdue on 1 April 2030?
-- Adaptation: Part B stores due_date directly, with Pending/Scheduled
-- outstanding statuses. It has no follow_up_interval_weeks or Planned status.
-- A plan due ON the review date is not overdue; Completed/Cancelled excluded.
-- Validation: compare dates/statuses with follow_up_plan. Repeat with an
-- existing due_date as the review date to demonstrate the strict < boundary.
SET @partner_review_date = CAST('2030-04-01' AS DATE);
WITH FollowUpDue AS (
    SELECT f.follow_up_id, a.patient_id, f.priority, f.status, f.due_date
    FROM follow_up_plan AS f
    INNER JOIN appointment AS a ON a.appointment_id = f.appointment_id
)
SELECT follow_up_id, patient_id, priority, status, due_date,
       @partner_review_date AS review_date
FROM FollowUpDue
WHERE status IN ('Pending', 'Scheduled')
  AND due_date < @partner_review_date
ORDER BY due_date, follow_up_id;
