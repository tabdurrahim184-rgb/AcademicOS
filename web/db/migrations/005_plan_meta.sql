-- Son plan üretiminin zamanı ve plana sığmayan görevlerin özeti (kullanıcıya dürüstçe gösterilir)
ALTER TABLE planner_settings ADD COLUMN last_generated_on date;
ALTER TABLE planner_settings ADD COLUMN last_unplaced jsonb NOT NULL DEFAULT '[]';
