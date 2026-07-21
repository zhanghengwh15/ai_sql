SELECT

        task.task_id,
        task.content,
        taskExtend.menu_module,
        taskExtend.task_type,
        taskExtend.project_number ,
         concat('https://www.teambition.com/task/', task.task_id) `TB链接`,
        taskExtend.actual_release_date `发布时间`
FROM
        teambition_task task
        LEFT JOIN teambition_task_extend taskExtend ON task.task_id = taskExtend.task_id
WHERE
        task.template_id = '6143667d4a18bafd5bfcc124'
        and  task.participants LIKE '%6273407e191ca5fba77a52a3%'
        AND task.created >= '2026-01-10 00:00:00'
        AND task.created <= NOW()
        and taskExtend.actual_release_date <= NOW()
        and taskExtend.actual_release_date >= '2026-01-10 00:00:00'
        and task.task_id not in ('6625c13b4b5e9976fb05934c','6659abbba373bd35c927dfc4','6625c0979ecd35c103531833')
and content like '%小糊涂仙%';

-- 技术支持类
SELECT
        task.task_id,
        task.content,
        taskExtend.menu_module,
        taskExtend.task_type,
        taskExtend.project_number ,
         concat('https://www.teambition.com/task/', task.task_id) `TB链接`,
        taskExtend.actual_release_date
FROM
        teambition_task task
        LEFT JOIN teambition_task_extend taskExtend ON task.task_id = taskExtend.task_id
WHERE
        task.template_id in ('6322e5d29bd3c8003fc3aa7c','5fb34e2178e9370eb86b49ce')
        and  task.participants LIKE '%6273407e191ca5fba77a52a3%'
         AND task.created >= '2026-01-10 00:00:00'
        AND task.created <= NOW()
        and taskExtend.actual_release_date <= NOW()
        and taskExtend.actual_release_date >= '2026-01-10 00:00:00'
 and task.task_id not in ('662a207f1d46fe6b8d8da202','65e536d0c822936cdc27a934');



-- 工单
SELECT
        task.task_id,
        task.content,
        taskExtend.menu_module,
        taskExtend.task_type,
        taskExtend.project_number ,
         concat('https://www.teambition.com/task/', task.task_id) `TB链接`,
        taskExtend.actual_release_date
FROM
        teambition_task task
        LEFT JOIN teambition_task_extend taskExtend ON task.task_id = taskExtend.task_id
WHERE
        task.template_id in ('5fb34e2178e9370eb86b49ce')
        and  task.participants LIKE '%6273407e191ca5fba77a52a3%'
         AND task.created >= '2026-01-10 00:00:00'
        AND task.created <= NOW()
        and taskExtend.actual_release_date <= NOW()
        and taskExtend.actual_release_date >= '2026-01-10 00:00:00'
 and task.task_id not in ('662a207f1d46fe6b8d8da202','65e536d0c822936cdc27a934')
