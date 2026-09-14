-- ================= --
-- Create Raw Tables --
-- ================= --

CREATE TABLE IF NOT EXISTS portofolio.phishing_email_detection_raw
(
email_id INT,
sender_email VARCHAR(250),
subject VARCHAR(250),
has_link BOOLEAN,
has_attachment BOOLEAN,
urgency_score INT,
spelling_errors INT,
email_length_words INT,
is_phishing BOOLEAN
)
;

TRUNCATE TABLE portofolio.phishing_email_detection_raw;


-- ============================ --
-- Loading Data Into Raw Tables --
-- ============================ --

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/phishing_email_detection.csv'
INTO TABLE
portofolio.phishing_email_detection_raw
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
email_id,
sender_email,
subject,
has_link,
has_attachment,
urgency_score,
spelling_errors,
email_length_words,
is_phishing
)
;

-- This configuration path depends on your Operating System and MySql Upload Directory 
-- Change this path according to your MySQL upload directory.
-- The source CSV uses UTF-8 encoding and Unix-style LF line endings. Therefore, the ingestion process was configured using FIELDS TERMINATED BY ',' and LINES TERMINATED BY '\n' to correctly parse the source file.


-- ================== --
-- Audit Data Quality --
-- ================== --

create table if not exists portofolio.phishing_email_detection_audit_log
(
audit_id bigint unsigned not null auto_increment,
audit_ts timestamp not null default current_timestamp,
check_id VARCHAR(20) NOT NULL,
check_name varchar(100) NOT NULL,
status ENUM('PASS', 'FAIL') NOT NULL,		-- pass / fail
expected_value DECIMAL(18,4) null,
actual_value DECIMAL(18,4) null,
notes varchar(500) null,
primary key (audit_id),
key idx_audit_ts (audit_ts),
key idx_check_id (check_id),
key idx_status (status)
)
;


SELECT
	COUNT(*) as duplicate_check
FROM
(
	SELECT
		email_id
	FROM
		portofolio.phishing_email_detection_raw
	GROUP BY
		email_id
	HAVING COUNT(*) > 1 
) as duplicate_check
;


-- ==================== --
-- DQ-01 - Completeness --
-- ==================== --

INSERT INTO portofolio.phishing_email_detection_audit_log
(
	check_id,
    check_name,
    status,
    expected_value,
    actual_value,
    notes
)
select
	'DQ-01' as check_id,
    'record completeness' as check_name,
    
    case
		when count(*) = 1500 then 'PASS' else 'FAIL'
	end as status,
    
    1500 as expected_value,
    count(*) as actual_value,
    
    CASE
		WHEN COUNT(*) = 1500 
        THEN 'Source record count matches raw table record count.'
        ELSE 'Source record count does not match raw table record count.'
    END AS Notes
from
	portofolio.phishing_email_detection_raw
;


-- ==================== --
-- CEK DUPLICATE RECORD --
-- ==================== --

-- Pre Check Value --

SELECT
    email_id,
    COUNT(*) AS occurrence_count
FROM
	portofolio.phishing_email_detection_raw
GROUP BY
	email_id
HAVING COUNT(*) > 1;


-- =============== --
-- Duplicate Check --
-- =============== --

SELECT COUNT(*) AS duplicate_email_id_count
FROM
(
    SELECT email_id
    FROM portofolio.phishing_email_detection_raw
    GROUP BY email_id
    HAVING COUNT(*) > 1
) AS duplicate_check
;


-- ======================= --
-- DQ-02 - Uniqueness Data -- 
-- ======================= --

insert into portofolio.phishing_email_detection_audit_log
(
	check_id,
    check_name,
    status,
    expected_value,
    actual_value,
    notes
)
select
	'DQ-02' as check_id,
    'duplicate email id' as check_name,
    
    case
		when count(*) = 0 then 'PASS' else 'FAIL'
	end as status,
    
    0 as expected_duplicate_id,
    count(*) as actual_value,
    
    CASE
		WHEN COUNT(*) = 0 
        THEN 'No Duplicate email_id detected.'
        ELSE 'Duplicate email_id detected. Further investigation required.'
    END AS Notes
from
(
	SELECT
		email_id
	FROM
		portofolio.phishing_email_detection_raw
	GROUP BY
		email_id
	HAVING COUNT(*) > 1
) AS duplicate_check
;


SELECT
	*
FROM
	portofolio.phishing_email_detection_audit_log
ORDER BY
	audit_id
;


SELECT
	SUM(CASE WHEN email_id IS NULL THEN 1 ELSE 0 END) as null_email_id,
    SUM(CASE WHEN sender_email IS NULL THEN 1 ELSE 0 END) as null_sender_email,
    SUM(CASE WHEN subject IS NULL THEN 1 ELSE 0 END) as null_subject,
    SUM(CASE WHEN has_link IS NULL THEN 1 ELSE 0 END) as null_has_link,
    SUM(CASE WHEN has_attachment IS NULL THEN 1 ELSE 0 END) as null_has_attachment,
    SUM(CASE WHEN urgency_score IS NULL THEN 1 ELSE 0 END) as null_urgency_score,
    SUM(CASE WHEN spelling_errors IS NULL THEN 1 ELSE 0 END) as null_spelling_errors,
    SUM(CASE WHEN email_length_words IS NULL THEN 1 ELSE 0 END) as null_email_length_words,
    SUM(CASE WHEN is_phishing IS NULL THEN 1 ELSE 0 END) as null_is_phishing
FROM
	portofolio.phishing_email_detection_raw
;

-- =================================== --
-- DQ-03 - Null Completeness Of Fields --
-- =================================== --


INSERT INTO portofolio.phishing_email_detection_audit_log
(
	check_id,
    check_name,
    status,
    expected_value,
    actual_value,
    notes
)

WITH
	dq_result AS
(
	SELECT
		SUM(CASE WHEN email_id IS NULL THEN 1 ELSE 0 END)
		+
        SUM(CASE WHEN sender_email IS NULL THEN 1 ELSE 0 END)
        +
        SUM(CASE WHEN subject IS NULL THEN 1 ELSE 0 END)
        +
        SUM(CASE WHEN has_link IS NULL THEN 1 ELSE 0 END)
        +
        SUM(CASE WHEN has_attachment IS NULL THEN 1 ELSE 0 END)
        +
        SUM(CASE WHEN urgency_score IS NULL THEN 1 ELSE 0 END)
        +
        SUM(CASE WHEN spelling_errors IS NULL THEN 1 ELSE 0 END)
        +
        SUM(CASE WHEN email_length_words IS NULL THEN 1 ELSE 0 END)
        +
        SUM(CASE WHEN is_phishing IS NULL THEN 1 ELSE 0 END)
		AS null_count
	
    FROM
		portofolio.phishing_email_detection_raw
)

SELECT
	'DQ-03' AS check_id,
    
    'NULL value check' AS check_name,
    
    CASE
		WHEN null_count = 0 THEN 'PASS'
        ELSE 'FAIL'
	END AS status,

	0 as expected_value,

	null_count AS actual_value,
    
    CASE
		WHEN null_count = 0
			THEN 'No Null value detected across required fields.'
		ELSE 'Null values detected. Further investigation required.'
	END AS notes

FROM
	dq_result
;


-- ================ --
-- DQ-04 - Validity --
-- ================ --

-- =================== --
-- Boolean Value Check --
-- =================== --

select
	has_link,
    has_attachment,
    is_phishing
FROM
	portofolio.phishing_email_detection_raw
;


-- =========== --
-- Check Field --
-- =========== --

SELECT
    COUNT(CASE WHEN has_link NOT IN (0, 1) THEN 1 END) AS invalid_has_link_count,
    COUNT(CASE WHEN has_attachment NOT IN (0, 1) THEN 1 END) AS invalid_has_attachment_count,
    COUNT(CASE WHEN is_phishing NOT IN (0, 1) THEN 1 END) AS invalid_is_phishing_count
FROM portofolio.phishing_email_detection_raw
;


-- ===================== --
-- Total Invalid Boolean --
-- ===================== --

SELECT
	COUNT(*) as total_invalid_boolean
FROM
    portofolio.phishing_email_detection_raw
WHERE
	has_link NOT IN (0, 1)
    OR has_attachment NOT IN (0, 1)
    OR is_phishing NOT IN (0, 1)
;


-- ================================= --
-- INSERT DQ-04 INTO AUDIT LOG TABEL --
-- ================================= --

INSERT INTO portofolio.phishing_email_detection_audit_log
(
check_id,
check_name,
status,
expected_value,
actual_value,
notes
)

WITH invalid_boolean_check AS
( 
	SELECT
		COUNT(*) AS invalid_count
	FROM
		portofolio.phishing_email_detection_raw
	WHERE has_link NOT IN (0,1)
		OR has_attachment NOT IN (0,1)
        OR is_phishing NOT IN (0,1)
)	
SELECT
	'DQ-04' AS check_id,
    'Boolean validity check' AS check_name,
    CASE WHEN invalid_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    0 AS expected_value,
    invalid_count AS actual_value,
    CASE
		WHEN invalid_count = 0 THEN 'All boolean fields contain valid binary value'
        ELSE 'Invalid non-binary values detected in boolean fields'
	END AS notes
FROM
	invalid_boolean_check
;


-- ================================= --
-- DQ-05 Domain Range Validity Check --
-- ================================= --

INSERT INTO portofolio.phishing_email_detection_audit_log
(
	check_id,
	check_name,
	status,
	expected_value,
	actual_value,
	notes
)

WITH range_check AS
(
	SELECT
		COUNT(*) AS invalid_range_count
	FROM
		portofolio.phishing_email_detection_raw
	WHERE
		urgency_score NOT BETWEEN 1 AND 10
		OR spelling_errors < 0
		OR email_length_words < 0
)

SELECT
	'DQ-05' AS check_id,
    'Numeric range validity' AS check_name,
    CASE WHEN invalid_range_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    0 AS expected_value,
    invalid_range_count AS actual_value,
    CASE
		WHEN invalid_range_count = 0 THEN 'All numeric fields fall within valid expected ranges.'
        ELSE 'Out-of-range numeric values detected.'
	END AS notes
FROM range_check
;

-- urgency_score is expected to be within 1-10
-- based on the dataset's defined scoring scale.


-- ===================================================== --
-- Check Total Email and Proporsi Phishing and Legitimate --
-- ===================================================== --

SELECT
	COUNT(*) AS total_email,
    SUM(is_phishing),
    COUNT(*) - SUM(is_phishing) AS total_legit,
    round(AVG(is_phishing)* 100,2) AS pct_phishing
FROM
	portofolio.phishing_email_detection_raw
;


-- ==================================================== --
-- Compare phishing vs legitimate email characteristics --
-- ==================================================== --

SELECT
	is_phishing,
    COUNT(*) AS total_email,
    ROUND(AVG(urgency_score), 2) AS avg_urgency,
    ROUND(AVG(spelling_errors), 2) AS avg_spelling_errors,
    ROUND(AVG(email_length_words), 2) AS avg_email_length,
    ROUND(AVG(has_link) * 100, 2) AS pct_has_link,
    ROUND(AVG(has_attachment) * 100, 2) AS pct_has_attachment
FROM
	portofolio.phishing_email_detection_raw
GROUP BY
	is_phishing
;


-- ======================================== --
-- Rate of phishing according email subject --
-- ======================================== --

SELECT
	subject,
    COUNT(*) AS total_email,
    SUM(is_phishing) AS phishing_count,
    ROUND(AVG(is_phishing) * 100, 2) AS phishing_rate,
    ROUND(AVG(urgency_score), 2) AS avg_urgency
FROM
	portofolio.phishing_email_detection_raw
GROUP BY
	subject
HAVING COUNT(*) >= 10
ORDER BY
	phishing_rate DESC,
    total_email DESC
;


-- ==================================== --
-- Rule-Based email risk classification --
-- ==================================== --

SELECT
	email_id,
    sender_email,
    subject,
    urgency_score,
    spelling_errors,
    email_length_words,
    has_link,
    is_phishing,
    
CASE
	WHEN urgency_score >= 7 
		AND spelling_errors >= 3 
		AND email_length_words <= 120 
		THEN 'High Risk'
	WHEN urgency_score >= 5 
		OR has_link = 1 
		THEN 'Medium Risk'
	ELSE 'Low Risk'
END AS risk_category

FROM
	portofolio.phishing_email_detection_raw
;

