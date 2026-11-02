
-- 后续需要将对应的状态优化下。
select e.sql_execute_id ,s.sql_content from sql_execute e  inner  join sql_content s on  s.sql_content_id = e.sql_content_id  where e.cloud_code = 'qifeng' and
s.db_id = 48 and s.execute_cloud = 'all'  and execute_status !='RELEASE_SUCCESS' order by s.add_time ;
;
