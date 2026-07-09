CREATE TABLE salaries AS select * FROM read_parquet('https://assets.getwren.ai/sample_data/employees/salaries.parquet');
CREATE TABLE titles AS select * FROM read_parquet('https://assets.getwren.ai/sample_data/employees/titles.parquet');
CREATE TABLE dept_emp AS select * FROM read_parquet('https://assets.getwren.ai/sample_data/employees/dept_emp.parquet');
CREATE TABLE departments AS select * FROM read_parquet('https://assets.getwren.ai/sample_data/employees/departments.parquet');
CREATE TABLE employees AS select * FROM read_parquet('https://assets.getwren.ai/sample_data/employees/employees.parquet');
CREATE TABLE dept_manager AS select * FROM read_parquet('https://assets.getwren.ai/sample_data/employees/dept_manager.parquet');