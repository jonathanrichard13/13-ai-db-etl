SELECT 
  u.*,
  a.email,
  ur.role,
  ud.division_name,
  COALESCE(ul.log_count, 0) as log_count,
  COALESCE(urr.role_count, 0) as role_count,
  COALESCE(udd.division_count, 0) as division_count
FROM users u
LEFT JOIN auth a ON u.auth_id = a.id
LEFT JOIN user_roles ur ON u.id = ur.user_id
LEFT JOIN user_divisions ud ON u.id = ud.user_id
LEFT JOIN (
  SELECT user_id, COUNT(*) as log_count 
  FROM user_logs 
  WHERE user_id = 1001
  GROUP BY user_id
) ul ON u.id = ul.user_id
LEFT JOIN (
  SELECT user_id, COUNT(*) as role_count 
  FROM user_roles 
  WHERE user_id = 1001
  GROUP BY user_id
) urr ON u.id = urr.user_id
LEFT JOIN (
  SELECT user_id, COUNT(*) as division_count 
  FROM user_divisions 
  WHERE user_id = 1001
  GROUP BY user_id
) udd ON u.id = udd.user_id
WHERE u.id = 1001