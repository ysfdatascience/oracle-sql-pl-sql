/* List the average salary of employees working in each department. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/

select 
    e.department_id,
    d.department_name,
    round(avg(salary), 2) as avg_salary
from employees e 
    inner join departments d on e.department_id = d.department_id
        group by e.department_id, d.department_name;

/* Find the employee with the highest salary in each department and list their name, salary, and department. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/

with cte(emp_id, fname, lname, dept_id, sal, sal_rank) as ( 
    select
        employee_id,
        first_name,
        last_name,
        department_id,
        salary,
        dense_rank() over(partition by department_id order by salary desc) as sal_rank
    --max(salary) over(partition by department_id order by salary desc) as max_sal
    from employees
)
select 
    emp_id, 
    fname, 
    lname, 
    dept_id, 
    sal 
from cte 
where sal_rank = 1;

/* Calculate the total order amount for each customer and list customers with a total order amount greater than 5000. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/

select 
    o.customer_id,
    c.cust_first_name as fname,
    c.cust_last_name as lname,
    sum(order_total) as total_sum
from oe.orders o
    inner join oe.customers c on o.customer_id = c.customer_id
        group by o.customer_id, c.cust_first_name, c.cust_last_name
            having sum(order_total) > 5000;

/* List employees whose salary is above the average salary. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/
/* Solution using subquery */
select
    employee_id,
    first_name,
    last_name,
    salary
from employees
    where salary > (select avg(salary) from employees);

/* Solution using CTE */
with cte(avg_salary) as (
    select round(avg(salary), 2) from employees
)
select
    employee_id,
    first_name,
    last_name,
    salary
from employees, cte
    where salary > cte.avg_salary;

/* Write an SQL query to find the product with the highest total sales amount using the SALES table. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/

/* Practical solution */
select
    s.prod_id,
    p.prod_name,
    sum(quantity_sold) as total_sold
from sh.sales s
    inner join sh.products p on s.prod_id = p.prod_id
    group by s.prod_id, p.prod_name
        order by total_sold desc
            fetch first 1 rows only;

/* Solution using CTE */
with cte as (
    select
        s.prod_id,
        p.prod_name as product_name,
        sum(quantity_sold) as total_sales
    from sh.sales s
        inner join sh.products p on s.prod_id = p.prod_id
        group by s.prod_id, p.prod_name
)
select
    prod_id,
    product_name,
    total_sales
from 
    (select
        prod_id,
        total_sales,
        product_name,
        row_number() over(order by total_sales desc) as rownumber
    from cte)
where
    rownumber = 1;

/* Solution using sub-query */
select
    s.prod_id,
    p.prod_name,
    sum(quantity_sold) as max_total_sale
from sh.sales s
inner join sh.products p on s.prod_id = p.prod_id
group by s.prod_id, p.prod_name
having sum(quantity_sold) = (select max(sum(quantity_sold)) from sh.sales s group by s.prod_id);

/* Solution using PL/SQL */
declare
    cursor c1 is 
        select 
            s.prod_id, 
            p.prod_name, 
            sum(quantity_sold) as total_sold
        from sh.sales s
        inner join sh.products p on s.prod_id = p.prod_id
        group by s.prod_id, p.prod_name;    
    max_total_sales sh.sales.quantity_sold%type;

begin 
    select max(sum(quantity_sold)) into max_total_sales from sh.sales s group by s.prod_id;
    
    for item in c1 loop
        if item.total_sold = max_total_sales then
            dbms_output.put_line(item.prod_id || ' - ' || item.prod_name || ' - ' || item.total_sold);
        end if;
    end loop;
end;
/


/* Update employee salaries in the employees table. If the employee's department is "Sales", increase their salary by 10%; otherwise, increase it by 5%. */                
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/  

/* Update using case statement */
update hr.employees
set salary = salary * 
    case job_id
        when 'SA_REP' then 1.10 else 1.05
    end;

/* PL/SQL solution: LOOP OVERHEAD */
declare
    v_job_id hr.employees.job_id%type := 'SA_REP';

begin
    for item in (select employee_id, job_id, salary from hr.employees) loop
        if item.job_id = v_job_id then
            update employees set salary = salary * 1.10 where employee_id = item.employee_id;
        else
            update employees set salary = salary * 1.05 where employee_id = item.employee_id;
        end if;
    end loop;
end;

/* PL/SQL solution: usage of forall for speed up to process */
declare
    type v_empid_sa_rep_type is table of hr.employees.employee_id%type;
    type v_empid_others_type is table of hr.employees.employee_id%type;
    v_empid_sa_rep v_empid_sa_rep_type; 
    v_empid_others v_empid_others_type;
begin 
    select employee_id bulk collect into v_empid_sa_rep from hr.employees where job_id = 'SA_REP';
    select employee_id bulk collect into v_empid_others from hr.employees where job_id != 'SA_REP'; 
    
    forall i in v_empid_sa_rep.first..v_empid_sa_rep.last
        update hr.employees
        set salary = salary * 1.10 where employee_id = v_empid_sa_rep(i);
    
    forall i in v_empid_others.first..v_empid_others.last
        update hr.employees
        set salary = salary * 1.05 where employee_id = v_empid_others(i); 
end;

/* Write a pivot query that shows total sales amounts for each product and year. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/       

select 
* 
from 
(select prod_id, to_char(time_id, 'YYYY') as year_date, amount_sold from sh.sales)
pivot (sum(amount_sold) for year_date in ('1998', '1999'));

/* Write a query that calculates the difference between each employee's salary and the average salary in their department. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/  

select
    employee_id,
    department_id,
    salary,
    round(avg(salary) over(partition by department_id), 2) as dept_avg_salary,
    round(salary - avg(salary) over(partition by department_id), 2) as salary_diff
from hr.employees
order by dept_avg_salary desc;

/* Write a program that finds departments with more than 5 employees using a cursor and processes the results in a PL/SQL block. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/

declare
    cursor c1 is
        select e.department_id, d.department_name, count(e.employee_id) as emp_count
        from hr.employees e
        inner join hr.departments d on e.department_id = d.department_id
        group by e.department_id, d.department_name
        having count(e.employee_id) > 5;
    
    rec c1%rowtype;    

begin 
    open c1;
    loop
        fetch c1 into rec;
        exit when c1%notfound;
        dbms_output.put_line('dept_id: ' || rec.department_id || 
        ' dept_name: ' || rec.department_name || ' emp_count: ' || rec.emp_count);
    end loop;
    close c1;
end;

/* Write a trigger that adds the old and new salary to a log table when an employee's salary is updated. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/

/* Creating log_table */
create table emp_log as
select employee_id, salary as old_salary, salary new_salary, hire_date as change_date from hr.employees;

truncate table emp_log;

/* Creating trigger */
create or replace trigger emp_salary_trigger
after update of salary on hr.employees
for each row
begin 
    if :old.salary != :new.salary then 
        insert into emp_log
        (employee_id, old_salary, new_salary, change_date)
        values(:old.employee_id, :old.salary, :new.salary, sysdate);
    end if;
end;

/* Push the trigger */
update hr.employees
set salary = salary + 102
where employee_id = 210;

/* Querying the log table */
select * from emp_log;

/* Write PL/SQL code that catches an error message when trying to insert a record with the same primary key into a table and logs the error. */
/*-----------------------------------------------------------------------------------------------------------------------------------------------*/

/* Creating sequence for log_id */
create sequence log_id_seq
start with 1
increment by 1
nocycle;

/* Creating log_table */
create table error_log(
    log_id number,
    error_message varchar2(250),
    error_time date
);

declare
    error_msg varchar2(250);

/* Attempting to insert duplicate value into the primary key constraint field employee_id */    
begin 
    insert into hr.employees
    (employee_id, first_name, last_name, email, hire_date, job_id)
    values 
    (100, 'duplicate', 'error', 'duplicate.error@example.com', sysdate, 'IT_PROG');
    
exception
    when others then
        error_msg := sqlerrm;
        insert into error_log(log_id, error_message, error_time)
        values (log_id_seq.nextval, error_msg, sysdate);
end;
