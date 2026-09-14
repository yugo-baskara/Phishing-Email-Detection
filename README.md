# Phishing Email Detection — Data Quality Audit & Risk Analysis

## 📌 Project Overview

This project demonstrates an end-to-end **SQL-based data quality, audit control, and risk analysis workflow** using a phishing email dataset containing **1,500 email records**.

Rather than focusing only on querying the data, this project approaches the dataset from a **data assurance and business analysis perspective**:

> **Can the dataset be trusted for further analysis, and what characteristics distinguish phishing emails from legitimate emails?**

The workflow begins with raw data ingestion, continues through structured data quality controls and audit logging, and concludes with exploratory business analysis and a rule-based email risk classification framework.

### Project Workflow

```text
RAW CSV DATA
     ↓
DATA INGESTION
     ↓
DATA QUALITY CONTROLS
     ├── DQ-01 Completeness
     ├── DQ-02 Uniqueness
     ├── DQ-03 NULL Validation
     ├── DQ-04 Boolean Validity
     └── DQ-05 Numeric Range Validity
     ↓
AUDIT LOG
     ↓
DATA PROFILING
     ↓
PHISHING VS LEGITIMATE ANALYSIS
     ↓
SUBJECT-LEVEL RISK ANALYSIS
     ↓
RULE-BASED EMAIL RISK CLASSIFICATION
```

---

## 🎯 Business Problem

Phishing email datasets can be useful for understanding suspicious communication patterns, but analytical results are only as reliable as the underlying data.

Before using the dataset for analysis, several questions need to be addressed:

* Was the expected number of records successfully loaded?
* Are email identifiers unique?
* Are required fields populated?
* Do Boolean fields contain valid values?
* Are numeric fields within their expected domain?
* What characteristics distinguish phishing emails from legitimate emails?
* Are certain email subjects associated with higher phishing rates?
* Can a simple rule-based framework categorize emails according to their observed risk characteristics?

This project addresses those questions using SQL.

---

## 💡 Project Objectives

The project has five primary objectives:

1. **Ingest raw phishing email data into MySQL.**
2. **Validate data quality before analytical use.**
3. **Create an audit log containing PASS/FAIL evidence for each control.**
4. **Analyze characteristics of phishing and legitimate emails.**
5. **Develop a transparent rule-based email risk classification framework.**

The objective is not to build a machine-learning model.

Instead, the project focuses on demonstrating how **SQL can be used as an analytical and data-control tool** within an auditable workflow.

---

# 🗂️ Dataset

The project uses a phishing email dataset containing **1,500 records**.

Each record represents an email and contains the following fields:

| Column               | Description                                                         |
| -------------------- | ------------------------------------------------------------------- |
| `email_id`           | Unique identifier assigned to the email                             |
| `sender_email`       | Sender email address                                                |
| `subject`            | Email subject                                                       |
| `has_link`           | Indicates whether the email contains a link                         |
| `has_attachment`     | Indicates whether the email contains an attachment                  |
| `urgency_score`      | Urgency score associated with the email                             |
| `spelling_errors`    | Number of detected spelling errors                                  |
| `email_length_words` | Number of words in the email                                        |
| `is_phishing`        | Target label indicating whether the email is classified as phishing |

Boolean fields are expected to contain binary values:

```text
0 = No / False
1 = Yes / True
```

The SQL workflow uses these fields for both data-quality validation and analytical comparison.

---

# 🛠️ Technology Stack

* **Database:** MySQL
* **Language:** SQL
* **Data Source:** CSV
* **Environment:** MySQL Server / MySQL Workbench
* **Analysis:** SQL aggregation, conditional logic, CTEs, grouping, filtering, and rule-based classification

---

# 🏗️ Data Architecture

The project separates the raw dataset from the audit evidence.

### Raw Data Table

```text
portofolio.phishing_email_detection_raw
```

This table stores the ingested source data without applying analytical transformations.

The raw table contains:

```text
email_id
sender_email
subject
has_link
has_attachment
urgency_score
spelling_errors
email_length_words
is_phishing
```

The SQL workflow creates the table first and truncates it before a new ingestion run, allowing the raw dataset to be refreshed without accumulating duplicate batches.

### Audit Log Table

```text
portofolio.phishing_email_detection_audit_log
```

The audit table records the result of each data quality control.

It contains:

| Column           | Purpose                                      |
| ---------------- | -------------------------------------------- |
| `audit_id`       | Unique audit record identifier               |
| `audit_ts`       | Timestamp when the audit result was recorded |
| `check_id`       | Data quality control identifier              |
| `check_name`     | Description of the control                   |
| `status`         | `PASS` or `FAIL`                             |
| `expected_value` | Expected control result                      |
| `actual_value`   | Observed result                              |
| `notes`          | Explanation of the control outcome           |

Indexes are also created for audit timestamp, check ID, and status to support audit-log retrieval.

---

# 📥 1. Data Ingestion

The CSV dataset is loaded into the raw MySQL table using:

```sql
LOAD DATA INFILE
```

The ingestion process specifies:

```text
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
```

The configuration reflects the source CSV structure, including comma-separated fields, quoted values, a header row, and Unix-style LF line endings.

The file path is environment-specific and should be adjusted according to the local MySQL upload directory and `secure_file_priv` configuration.

---

# 🔍 2. Data Quality Framework

The project implements five data quality controls.

```text
DQ-01 → Completeness
DQ-02 → Uniqueness
DQ-03 → NULL Validation
DQ-04 → Boolean Validity
DQ-05 → Numeric Range Validity
```

Each control follows the same general principle:

```text
Measure
   ↓
Evaluate
   ↓
PASS / FAIL
   ↓
Record Evidence
```

This allows data quality checks to become **auditable evidence**, rather than isolated SQL queries.

---

# DQ-01 — Record Completeness

### Control Objective

Verify that the number of records loaded into the raw table matches the expected source record count.

### Expected Result

```text
Expected records = 1,500
```

### Logic

```text
Actual record count = COUNT(*)
```

The control returns:

```text
PASS → Actual count = 1,500
FAIL → Actual count ≠ 1,500
```

The result is then recorded in the audit log together with the expected and actual values.

### Why It Matters

A successful `LOAD DATA INFILE` execution does not necessarily mean that the complete dataset was loaded.

Record-count reconciliation provides a basic control over ingestion completeness.

---

# DQ-02 — Uniqueness

### Control Objective

Determine whether `email_id` contains duplicate identifiers.

The investigation groups records by:

```sql
email_id
```

and identifies identifiers appearing more than once.

### Expected Result

```text
Duplicate email_id count = 0
```

### Interpretation

```text
PASS → No duplicate email_id detected
FAIL → Duplicate email_id detected
```

This control helps ensure that individual email records can be uniquely identified.

---

# DQ-03 — NULL Value Validation

### Control Objective

Identify NULL values across required fields.

The following fields are evaluated:

```text
email_id
sender_email
subject
has_link
has_attachment
urgency_score
spelling_errors
email_length_words
is_phishing
```

The control calculates the total number of NULL occurrences across these fields.

A Common Table Expression (CTE) is used to calculate the result once before evaluating the PASS/FAIL condition.

### Expected Result

```text
NULL occurrence count = 0
```

### Important Interpretation

The `null_count` represents the **total number of NULL occurrences across the required fields**, rather than the number of affected email records.

For example:

```text
1 email with 3 NULL fields
=
3 NULL occurrences
```

This distinction is important when interpreting the audit result.

---

# DQ-04 — Boolean Validity

### Control Objective

Verify that Boolean fields contain valid binary values.

The following fields are evaluated:

```text
has_link
has_attachment
is_phishing
```

Expected values are:

```text
0 or 1
```

The control identifies records containing non-binary values.

### Expected Result

```text
Invalid Boolean value count = 0
```

### Interpretation

```text
PASS → All Boolean fields contain valid binary values
FAIL → Invalid non-binary values detected
```

NULL values are handled separately by DQ-03.

This separation ensures that:

```text
DQ-03 = Is the value present?
DQ-04 = Is the value valid?
```

---

# DQ-05 — Numeric Range Validity

### Control Objective

Verify that numerical fields fall within their expected domains.

The following controls are applied:

```text
urgency_score     → 1–10
spelling_errors   → >= 0
email_length_words → >= 0
```

The expected `urgency_score` range is based on the dataset's defined scoring scale.

### Expected Result

```text
Invalid numeric range count = 0
```

### Interpretation

```text
PASS → Numeric values fall within expected ranges
FAIL → Out-of-range values detected
```

---

# 📊 3. Overall Email Classification

After the data quality controls, the dataset is profiled to determine:

* Total number of emails
* Total phishing emails
* Total legitimate emails
* Percentage of phishing emails

The analysis uses the `is_phishing` field as the observed classification label.

This provides a high-level view of the composition of the dataset before deeper analysis.

---

# 🔎 4. Phishing vs Legitimate Email Characteristics

The next analysis compares phishing and legitimate emails across several characteristics.

### Metrics

| Metric                            | Purpose                              |
| --------------------------------- | ------------------------------------ |
| Total emails                      | Compare group sizes                  |
| Average urgency                   | Identify differences in urgency      |
| Average spelling errors           | Identify writing-quality differences |
| Average email length              | Compare message length               |
| Percentage containing links       | Measure link prevalence              |
| Percentage containing attachments | Measure attachment prevalence        |

The comparison is grouped by:

```text
is_phishing
```

This allows the analysis to move beyond simple classification counts and investigate **behavioral characteristics associated with each class**.

---

# 📈 5. Phishing Rate by Email Subject

The project also evaluates phishing rates at the email-subject level.

For each subject, the analysis calculates:

```text
Total emails
Phishing count
Phishing rate
Average urgency
```

Only subjects appearing at least **10 times** are included in the final analysis.

### Why the Minimum Sample Rule?

A phishing rate based on one or two observations can be misleading.

For example:

```text
Subject A
1 email
1 phishing
= 100% phishing rate
```

Although mathematically correct, this does not provide enough observations to support a meaningful comparison.

The minimum frequency threshold helps make the subject-level analysis more robust.

---

# ⚠️ 6. Rule-Based Email Risk Classification

The final analytical component introduces a transparent rule-based risk classification.

The framework categorizes emails into:

```text
High Risk
Medium Risk
Low Risk
```

### High Risk

An email is classified as **High Risk** when all of the following conditions are met:

```text
urgency_score >= 7
AND
spelling_errors >= 3
AND
email_length_words <= 120
```

### Medium Risk

An email is classified as **Medium Risk** when:

```text
urgency_score >= 5
OR
has_link = 1
```

### Low Risk

Emails that do not meet the High or Medium Risk conditions are classified as:

```text
Low Risk
```

---

# 🧠 Important Limitation

The risk classification is a **rule-based analytical framework**.

It is **not a machine-learning model** and should not be interpreted as a production-grade phishing detection system.

The rules are transparent and easy to inspect, which makes them useful for demonstrating how business rules can be translated into SQL logic.

A production phishing detection system would require additional validation, feature engineering, model evaluation, and potentially machine-learning techniques.

---

# 🔐 Audit Perspective

One of the main objectives of this project is to demonstrate the difference between:

> **Running an analysis**

and:

> **Ensuring that the data used for the analysis is trustworthy.**

The workflow therefore separates:

### Data Quality Controls

```text
Completeness
Uniqueness
NULL validation
Boolean validity
Numeric range validity
```

from:

### Business Analysis

```text
Phishing proportion
Phishing vs legitimate characteristics
Subject-level phishing rates
Risk classification
```

This structure reflects a control-oriented approach to analytical work.

---

# 📁 Project Structure

Recommended GitHub repository structure:

```text
Phishing-Email-detection/
│
├── DATA/
│   └── Raw_data.CSV
│
├── SQL/
│   └── phishing_email_detection.sql
│
└── Readme.MD
```

The SQL script contains the complete workflow from raw table creation and data ingestion through data quality controls and business analysis.

---

# 🔄 End-to-End Process

The complete workflow can be summarized as:

```text
1. Create Raw Table
        ↓
2. Refresh Raw Table
        ↓
3. Load CSV Data
        ↓
4. Create Audit Log
        ↓
5. DQ-01 — Record Completeness
        ↓
6. DQ-02 — Uniqueness
        ↓
7. DQ-03 — NULL Validation
        ↓
8. DQ-04 — Boolean Validity
        ↓
9. DQ-05 — Numeric Range Validity
        ↓
10. Profile Dataset
        ↓
11. Compare Phishing vs Legitimate
        ↓
12. Analyze Subject-Level Phishing Rate
        ↓
13. Apply Rule-Based Risk Classification
```

---

# 💼 Business Value

This project demonstrates how SQL can support more than data retrieval.

The workflow combines:

### Data Engineering

* CSV ingestion
* Raw data staging
* Controlled data refresh

### Data Quality

* Completeness controls
* Duplicate detection
* NULL validation
* Domain validation
* Numeric range validation

### Audit & Assurance

* PASS/FAIL controls
* Expected vs actual values
* Timestamped audit evidence
* Structured audit logging

### Business Analytics

* Dataset profiling
* Group comparison
* Rate analysis
* Risk categorization

The broader objective is to establish a workflow in which:

> **Data quality is evaluated before analytical conclusions are made.**

---

# 📌 Key Takeaways

This project demonstrates an approach to analytical work based on three layers:

```text
DATA
 ↓
CONTROL
 ↓
INSIGHT
```

### Data

Raw phishing email records are ingested into MySQL.

### Control

The dataset is evaluated through five data quality controls and the results are recorded in an audit log.

### Insight

Once the data passes the relevant controls, SQL is used to analyze phishing characteristics, subject-level rates, and rule-based risk categories.

This approach helps connect **data analysis with data reliability and business decision-making**.

---

# 🚧 Limitations & Future Improvements

The current project intentionally focuses on SQL-based data quality and analytical reasoning.

Potential future enhancements include:

* Evaluating the rule-based classification against the observed phishing labels
* Calculating confusion matrix metrics such as precision, recall, and accuracy
* Introducing additional email-level features
* Building Power BI dashboards for management-level reporting
* Comparing rule-based classification with machine-learning approaches
* Implementing automated or scheduled data-quality monitoring

These enhancements are outside the scope of the current SQL workflow.

---

# 👤 Author

**Yugo Baskara**

Linkedin : https://www.linkedin.com/in/yugobaskara/

Auditor | Data Analyst | SQL | Data Engineering Enthusiast

Focus areas:

```text
Data Analytics
Business Intelligence
SQL
Data Quality
Audit & Assurance
Risk Analysis
```

This project represents my approach to combining an **audit and assurance mindset with SQL-based data analysis**, with a focus on making data reliable before using it to support analytical conclusions.

---

# ⭐ Project Summary

> **A SQL-based phishing email analysis project that combines data ingestion, data quality controls, audit logging, exploratory analysis, and rule-based risk classification.**

The core principle behind the project is simple:

> **Reliable analysis starts with reliable data.**

---

## 📄 Data Source & Attribution

The dataset used in this project was obtained from the public Kaggle dataset published by the user Prince Rajak.

This project is created strictly for educational and portfolio purposes.
All data processing, transformation logic, and analytical design are original work by the author.


---
